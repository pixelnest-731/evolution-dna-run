import SceneKit
import SwiftUI
import QuartzCore

/// AI社員02: ランナー本体。論理(Swarm)と描画(最大表示数)を分離
@MainActor
final class GameController: NSObject, ObservableObject {
    enum Phase { case ready, running, boss, won, lost }

    @Published var phase: Phase = .ready
    @Published var displayCount = 1
    @Published var progress: Float = 0
    @Published var bossHP: Double = 1
    @Published var popups: [Popup] = []
    @Published var abilityReady = false
    @Published var evolvedName: String?
    @Published var dnaCollected = 0
    @Published var element: Element = .none
    @Published var sizeClass = 0
    private var pickups: [(node: SCNNode, z: Float, x: Float, taken: Bool)] = []

    struct Popup: Identifiable { let id = UUID(); let text: String; let color: Color }

    let scene = SCNScene()
    let view = SCNView()
    private(set) var stage: StageDef
    private(set) var swarm = Swarm()

    private let camera = SCNNode()
    private let swarmNode = SCNNode()
    private let countLabel = SCNNode()
    private var units: [SCNNode] = []
    private var gateNodes: [(row: Int, left: SCNNode, right: SCNNode)] = []
    private var obstacles: [(def: ObstacleDef, node: SCNNode, hit: Bool)] = []
    private var nextRow = 0
    private var bossNode: SCNNode?
    private var link: CADisplayLink?
    private var last: CFTimeInterval = 0
    private var z: Float = 0
    private var x: Float = 0
    private var targetX: Float = 0
    private var dragStartX: Float = 0
    private var shake: Float = 0
    private var battleT: Double = 0
    private var bossMax: Double = 1
    private var playerPower: Double = 0
    private var abilityBonus = 1.0
    let speed: Float = 9.5
    let maxVisible = 70

    init(stageIndex: Int) {
        stage = StageGenerator.stage(stageIndex)
        super.init()
        setupScene()
    }

    private func setupScene() {
        view.scene = scene
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.rendersContinuously = true
        if stage.index <= 10 { WorldJungle.build(into: scene, length: stage.length) }  // オーナー指定のプレイ画面イメージ
        else { WorldBuilder.build(into: scene, length: stage.length) }

        let cam = SCNCamera(); cam.fieldOfView = 58; cam.zFar = 140
        cam.wantsHDR = true; cam.wantsExposureAdaptation = false; cam.exposureOffset = 0.15
        cam.bloomIntensity = 0.6; cam.bloomThreshold = 0.92; cam.bloomBlurRadius = 8
        cam.colorFringeStrength = 0; cam.saturation = 1.2; cam.contrast = 0.1
        camera.camera = cam
        scene.rootNode.addChildNode(camera); view.pointOfView = camera
        let bd = WorldJungle.backdrop(stage.index <= 10 ? "bg_paradise" : "bg_world_cells", aspectHint: 2.8)
        bd.position = SCNVector3(0, 9.6, -24); bd.scale = SCNVector3(1.12, 1.12, 1); camera.addChildNode(bd)
        let motes = SCNNode(); motes.position = SCNVector3(0, 0, -15); motes.addParticleSystem(WorldBuilder.motes()); camera.addChildNode(motes)
        // 走行時の土煙
        let dust = SCNParticleSystem(); dust.particleImage = FX.softDot; dust.birthRate = 18; dust.particleLifeSpan = 0.7
        dust.particleSize = 0.45; dust.particleSizeVariation = 0.2; dust.particleColor = UIColor(white: 1, alpha: 0.55)
        dust.emitterShape = SCNBox(width: 1.2, height: 0.1, length: 0.3, chamferRadius: 0); dust.birthLocation = .volume
        dust.particleVelocity = 1.2; dust.spreadingAngle = 25; dust.emittingDirection = SCNVector3(0, 0.4, 1)
        dust.propertyControllers = [.opacity: SCNParticlePropertyController(animation: { let a = CAKeyframeAnimation(); a.values = [0.8, 0]; return a }())]
        let dustNode = SCNNode(); dustNode.name = "dust"; dustNode.position = SCNVector3(0, 0.1, 0.6); dustNode.addParticleSystem(dust)
        swarmNode.addChildNode(dustNode)

        scene.rootNode.addChildNode(swarmNode)
        let glow = SCNNode(geometry: SCNPlane(width: 3, height: 3))
        let gm = SCNMaterial(); gm.lightingModel = .constant; gm.diffuse.contents = FX.softDot; gm.blendMode = .add
        gm.multiply.contents = UIColor(red: 0.4, green: 1, blue: 0.9, alpha: 0.6); gm.writesToDepthBuffer = false
        glow.geometry!.materials = [gm]; glow.eulerAngles.x = -.pi / 2; glow.position.y = 0.02; glow.name = "glow"
        swarmNode.addChildNode(glow)

        countLabel.constraints = [SCNBillboardConstraint()]
        swarmNode.addChildNode(countLabel)

        for (i, r) in stage.rows.enumerated() {
            let w = WorldBuilder.laneHalfWidth - 0.15
            let l = GateBuilder.gate(r.left, width: w); l.position = SCNVector3(-w / 2 - 0.05, 0, r.z)
            let rr = GateBuilder.gate(r.right, width: w); rr.position = SCNVector3(w / 2 + 0.05, 0, r.z)
            scene.rootNode.addChildNode(l); scene.rootNode.addChildNode(rr)
            gateNodes.append((i, l, rr))
        }
        for o in stage.obstacles {
            let n = CreatureFactory.virus(); n.position = SCNVector3(o.x, 0.7, o.z)
            if o.sweep > 0 {
                n.runAction(.repeatForever(.sequence([.moveBy(x: CGFloat(o.sweep), y: 0, z: 0, duration: 1.1), .moveBy(x: CGFloat(-o.sweep * 2), y: 0, z: 0, duration: 2.2), .moveBy(x: CGFloat(o.sweep), y: 0, z: 0, duration: 1.1)])))
            }
            scene.rootNode.addChildNode(n); obstacles.append((o, n, false))
        }
        // DNA収集アイテム：ゲート間に一列、左右交互
        let gz = [Float(-4)] + stage.rows.map(\.z)
        for i in 0..<(gz.count - 1) {
            let lane: Float = (i % 2 == 0 ? -1 : 1) * 1.3
            for k in 0..<4 {
                let z0 = gz[i] - 4 - Float(k) * 1.8
                if z0 < gz[i + 1] + 2 { break }
                let h = Helix.node(); h.position = SCNVector3(lane, 1.0, z0); h.eulerAngles.z = -0.5
                h.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 1.6)))
                scene.rootNode.addChildNode(h); pickups.append((h, z0, lane, false))
            }
        }
        let boss = BossFactory.build(BossKind(rawValue: stage.boss.kind) ?? .gorilla); boss.position = SCNVector3(0, 0, stage.length - 4)
        scene.rootNode.addChildNode(boss); bossNode = boss
        bossMax = stage.boss.hp; bossHP = 1

        rebuildUnits(animated: false)
        updateLabel()
        updateCamera(dt: 1)

    }

    func start() {
        guard phase == .ready else { return }
        phase = .running
        AudioEngine.shared.comboStep = 0
        AudioEngine.shared.startBGM()
        last = CACurrentMediaTime()
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
    }

    func stop() { link?.invalidate(); link = nil; AudioEngine.shared.stop() }

    private var dragging = false
    func drag(dx: CGFloat, width: CGFloat) {
        if phase == .ready { start() }
        if !dragging { dragging = true; dragStartX = targetX }
        let tx = Float(dx / max(1, width)) * 9
        targetX = max(-WorldBuilder.laneHalfWidth + 0.6, min(WorldBuilder.laneHalfWidth - 0.6, dragStartX + tx))
    }
    func endDrag() { dragging = false }

    @objc private func tick() {
        let now = CACurrentMediaTime(); let dt = Float(min(0.05, now - last)); last = now
        switch phase {
        case .running: runStep(dt)
        case .boss: bossStep(Double(dt))
        default: break
        }
        updateFormation(dt)
        updateCamera(dt: dt)
    }

    // MARK: - 走行
    private func runStep(_ dt: Float) {
        z -= speed * dt
        x += (targetX - x) * min(1, dt * 12)
        swarmNode.position = SCNVector3(x, 0, z)
        progress = min(1, z / (stage.length + 8))

        for i in pickups.indices where !pickups[i].taken && abs(z - pickups[i].z) < 0.7 && abs(x - pickups[i].x) < 0.8 + spread * 0.7 {
            pickups[i].taken = true; dnaCollected += 1
            let n = pickups[i].node
            n.runAction(.sequence([.group([.move(by: SCNVector3(0, 1.5, 0), duration: 0.25), .scale(to: 0.01, duration: 0.25)]), .removeFromParentNode()]))
            scene.addParticleSystem(FX.burst(color: UIColor(red: 0.7, green: 0.6, blue: 1, alpha: 1), count: 40, speed: 3, size: 0.15), transform: SCNMatrix4MakeTranslation(n.position.x, 1, n.position.z))
            AudioEngine.shared.pop(scale: 0); Haptics.shared.tap(0.3, sharp: 0.9)
        }
        if nextRow < stage.rows.count, z <= stage.rows[nextRow].z {
            let r = stage.rows[nextRow]; let gn = gateNodes[nextRow]
            let left = x < 0
            passGate(left ? r.left : r.right, node: left ? gn.left : gn.right, other: left ? gn.right : gn.left)
            nextRow += 1
        }
        for i in obstacles.indices where !obstacles[i].hit {
            let o = obstacles[i]
            if abs(z - o.def.z) < 0.6 {
                let ox = o.node.presentation.position.x
                if abs(ox - x) < 0.6 + spread * 0.6 {
                    obstacles[i].hit = true
                    swarm.hit(o.def)
                    AudioEngine.shared.play("obstacle"); Haptics.shared.tap(0.9, sharp: 0.9)
                    AudioEngine.shared.comboStep = 0
                    popup("−\(o.def.kills)", .red); shake = 0.35
                    o.node.runAction(.sequence([.scale(to: 1.4, duration: 0.08), .scale(to: 1, duration: 0.15)]))
                    afterCountChange(old: displayCount)
                    if swarm.count == 0 { lose(); return }
                }
            }
        }
        if z <= stage.length + 8 { beginBoss() }
    }

    private var spread: Float { Float(sqrt(Double(min(swarm.count, maxVisible)))) * 0.28 * unitScale }
    private var unitScale: Float { swarm.element == .none ? [1, 1.5, 2.1, 2.8][min(swarm.sizeClass, 3)] : [1.1, 1.5, 2.1, 2.8][min(swarm.sizeClass, 3)] }

    private func passGate(_ g: GateKind, node: SCNNode, other: SCNNode) {
        let old = swarm.count; let oldClass = swarm.sizeClass; let oldEl = swarm.element
        swarm.apply(g)
        node.runAction(.sequence([.group([.scale(to: 1.25, duration: 0.12), .fadeOut(duration: 0.3)]), .removeFromParentNode()]))
        other.runAction(.sequence([.fadeOpacity(to: 0.0, duration: 0.25), .removeFromParentNode()]))
        let c = GateBuilder.color(g)
        scene.addParticleSystem(FX.burst(color: c, count: g.isHarmful ? 60 : 160), transform: SCNMatrix4MakeTranslation(x, 1, z))

        switch g {
        case .sub, .div:
            AudioEngine.shared.play("gate_bad"); AudioEngine.shared.comboStep = 0
            Haptics.shared.tap(0.6, sharp: 0.2); popup(g.label, .red); shake = 0.2
        case .add(let n):
            AudioEngine.shared.pop(scale: n >= 50 ? 2 : 1); Haptics.shared.tap(0.5); popup(g.label, .cyan)
        case .mul(let n):
            AudioEngine.shared.pop(scale: n >= 5 ? 3 : 2); Haptics.shared.tap(n >= 5 ? 1 : 0.7); popup(g.label, .green)
            if n >= 5 { shake = 0.15 }
        case .evolve(let e):
            if e != oldEl { evolveFX(e) }
        case .fuse:
            if swarm.sizeClass != oldClass { fuseFX() } else { popup(String(localized: "融合には10体必要"), .gray) }
        }
        if swarm.count == 0 { lose(); return }
        if case .evolve = g { return }
        if case .fuse = g { return }
        afterCountChange(old: old)
    }

    private func afterCountChange(old: Int) {
        let target = swarm.count
        AudioEngine.shared.setIntensity(target >= 200 ? 2 : (target >= 20 ? 1 : 0))
        rebuildUnits(animated: target > old)
        // カウントアップ
        let steps = 10
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.035) { [weak self] in
                guard let self else { return }
                self.displayCount = old + (target - old) * i / steps
                self.updateLabel()
            }
        }
    }

    private func evolveFX(_ e: Element) {
        let audio = AudioEngine.shared
        audio.play("evolve"); audio.duck(true)
        Haptics.shared.rumble(0.8, intensity: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) { Haptics.shared.tap(1, sharp: 0.8); audio.duck(false) }
        for u in units {
            u.runAction(.sequence([.group([.scale(to: 0.2, duration: 0.35), .rotateBy(x: 0, y: .pi * 2, z: 0, duration: 0.35)])]))
        }
        evolvedName = CreatureCatalog.name(element: e, sizeClass: swarm.sizeClass)
        element = e; Progress.shared.discover(e, swarm.sizeClass)
        // DNAの二重らせんが群れを包む
        let ring = SCNNode(); ring.position = SCNVector3(0, 0, 0); swarmNode.addChildNode(ring)
        for k in 0..<3 {
            let h = Helix.node(); let a = Float(k) / 3 * .pi * 2
            h.position = SCNVector3(cos(a) * (1.2 + spread), 1.2, sin(a) * (1.2 + spread)); h.scale = SCNVector3(1.4, 1.4, 1.4); ring.addChildNode(h)
        }
        ring.runAction(.sequence([.group([.rotateBy(x: 0, y: .pi * 3, z: 0, duration: 0.9), .sequence([.wait(duration: 0.6), .fadeOut(duration: 0.3)])]), .removeFromParentNode()]))
        let flash = SCNNode(); flash.light = SCNLight(); flash.light!.type = .omni; flash.light!.color = Palette.color(e); flash.light!.intensity = 0
        flash.position = SCNVector3(0, 2, 0); swarmNode.addChildNode(flash)
        flash.runAction(.sequence([.customAction(duration: 0.9) { n, t in n.light?.intensity = 3000 * sin(CGFloat.pi * t / 0.9) }, .removeFromParentNode()]))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.scene.addParticleSystem(FX.burst(color: Palette.color(e), count: 300, speed: 8, size: 0.25), transform: SCNMatrix4MakeTranslation(self.x, 0.6, self.z))
            self.rebuildUnits(animated: true, force: true)
            self.updateLabel()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in self?.evolvedName = nil }
    }

    private func fuseFX() {
        AudioEngine.shared.play("fuse"); Haptics.shared.rumble(0.55, intensity: 0.4)
        // 中心へ吸い寄せ → 凝縮 → 誕生
        for u in units { u.runAction(.group([.move(to: SCNVector3(0, 0.4, 0), duration: 0.45), .scale(to: 0.3, duration: 0.45)])) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            Haptics.shared.tap(1, sharp: 0.3); self.shake = 0.3
            self.scene.addParticleSystem(FX.burst(color: UIColor(red: 0.85, green: 0.5, blue: 1, alpha: 1), count: 280, speed: 9, size: 0.3), transform: SCNMatrix4MakeTranslation(self.x, 0.8, self.z))
            self.rebuildUnits(animated: true, force: true)
            self.sizeClass = self.swarm.sizeClass; Progress.shared.discover(self.swarm.element, self.swarm.sizeClass)
            self.displayCount = self.swarm.count; self.updateLabel()
            self.popup("MERGE!", .purple)
            self.evolvedName = CreatureCatalog.name(element: self.swarm.element, sizeClass: self.swarm.sizeClass)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in self?.evolvedName = nil }
        }
    }

    // MARK: - 群体描画（最大 maxVisible 体。論理数とは独立）
    private var builtKey = ""
    private func rebuildUnits(animated: Bool, force: Bool = false) {
        let cap = maxVisible   // 動物形態はノード数が多いので描画上限を下げる
        let visible = max(0, min(swarm.count, swarm.sizeClass >= 2 ? 12 : cap))
        let key = "\(swarm.element.rawValue)-\(swarm.sizeClass)"
        if force || key != builtKey { units.forEach { $0.removeFromParentNode() }; units.removeAll(); builtKey = key }
        while units.count > visible { units.removeLast().runAction(.sequence([.scale(to: 0, duration: 0.15), .removeFromParentNode()])) }
        while units.count < visible {
            let n = CreatureFactory.unit(element: swarm.element, sizeClass: swarm.sizeClass)
            n.position = units.first?.position ?? SCNVector3Zero
            if animated { let s = n.scale; n.scale = SCNVector3(0.01, 0.01, 0.01); n.runAction(.sequence([.wait(duration: Double(units.count) * 0.004), .scale(to: CGFloat(s.x) * 1.0, duration: 0.25)])) }
            swarmNode.addChildNode(n); units.append(n)
        }
    }

    private func updateFormation(_ dt: Float) {
        let golden: Float = .pi * (3 - sqrt(5))
        let gap: Float = 0.42 * unitScale
        for (i, u) in units.enumerated() {
            let r = gap * sqrt(Float(i)); let a = Float(i) * golden
            let tgt = SCNVector3(cos(a) * r, 0.35 * unitScale, sin(a) * r * 0.8)
            let p = u.position; let k = min(1, dt * 7)
            u.position = SCNVector3(p.x + (tgt.x - p.x) * k, p.y + (tgt.y - p.y) * k, p.z + (tgt.z - p.z) * k)
        }
        countLabel.position = SCNVector3(0, 1.4 * unitScale + spread * 0.3, 0)
    }

    private func updateLabel() {
        let t = SCNText(string: "\(displayCount)", extrusionDepth: 0.1)
        t.font = UIFont.systemFont(ofSize: 0.8, weight: .heavy).rounded(); t.flatness = 0.05
        let m = Mat.glow(.white); t.materials = [m]
        countLabel.geometry = t
        let (mn, mx) = countLabel.boundingBox
        countLabel.pivot = SCNMatrix4MakeTranslation((mx.x + mn.x) / 2, mn.y, 0)
        if countLabel.childNodes.isEmpty {
            let bgP = SCNPlane(width: 1, height: 0.9); bgP.cornerRadius = 0.45; let bg = SCNNode(geometry: bgP)
            bg.geometry!.materials = [{ let m = Mat.glow(UIColor(red: 0.05, green: 0.15, blue: 0.25, alpha: 0.75)); m.writesToDepthBuffer = false; return m }()]
            bg.name = "bg"; bg.renderingOrder = -1; countLabel.addChildNode(bg)
        }
        let w = CGFloat(mx.x - mn.x) + 0.6
        (countLabel.childNode(withName: "bg", recursively: false)?.geometry as? SCNPlane)?.width = w
        countLabel.childNode(withName: "bg", recursively: false)?.position = SCNVector3((mx.x + mn.x) / 2, mn.y + 0.42, -0.06)
    }

    private func updateCamera(dt: Float) {
        let back: Float = phase == .boss || phase == .won ? 13 : 9.5 + spread * 0.8
        let up: Float = phase == .boss || phase == .won ? 6 : 6.5 + spread * 0.5
        var sx: Float = 0, sy: Float = 0
        if shake > 0 { shake = max(0, shake - dt); sx = Float.random(in: -1...1) * shake * 0.6; sy = Float.random(in: -1...1) * shake * 0.6 }
        let target = SCNVector3(x * 0.55 + sx, up + sy, z + back)
        let p = camera.position; let k = min(1, dt * 5)
        camera.position = SCNVector3(p.x + (target.x - p.x) * k, p.y + (target.y - p.y) * k, p.z + (target.z - p.z) * k)
        camera.look(at: SCNVector3(x * 0.4, 0.5, z - 9))
    }

    // MARK: - ボス戦（自動進行 + 任意発動アビリティ）
    private func beginBoss() {
        phase = .boss; battleT = 0
        targetX = 0
        playerPower = swarm.power(against: stage.boss)
        abilityReady = true
        AudioEngine.shared.play("boss_roar"); AudioEngine.shared.setIntensity(2)
        Haptics.shared.rumble(1.0, intensity: 0.7); shake = 0.5
    }

    func useAbility() {
        guard abilityReady, phase == .boss else { return }
        abilityReady = false; abilityBonus = 1.25
        AudioEngine.shared.play("gate_big"); Haptics.shared.tap(1)
        scene.addParticleSystem(FX.burst(color: Palette.color(swarm.element == .none ? .light : swarm.element), count: 400, speed: 14, size: 0.35), transform: SCNMatrix4MakeTranslation(0, 2, stage.length))
        popup(String(localized: "DNAバースト!"), .yellow)
    }

    private func bossStep(_ dt: Double) {
        x += (0 - x) * Float(min(1, dt * 4)); swarmNode.position = SCNVector3(x, 0, z)
        battleT += dt
        let duration = 3.0
        let dealt = playerPower * abilityBonus * min(1, battleT / duration)
        bossHP = max(0, 1 - dealt / bossMax)
        // 攻撃の視覚化：ユニットが突進
        if Int(battleT * 10) != Int((battleT - dt) * 10), let u = units.randomElement(), let boss = bossNode {
            let shot = SCNNode(geometry: SCNSphere(radius: 0.18)); shot.geometry!.materials = [Mat.glow(Palette.color(swarm.element).lighter(0.4))]
            shot.position = SCNVector3(x + u.position.x, 0.8, z + u.position.z)
            scene.rootNode.addChildNode(shot)
            let bp = boss.presentation.position
            shot.runAction(.sequence([.move(to: SCNVector3(bp.x + Float.random(in: -1...1), bp.y + 2.5, bp.z + 2), duration: 0.3), .removeFromParentNode()]))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self, self.phase == .boss else { return }
                AudioEngine.shared.play("hit", volume: 0.6); Haptics.shared.tap(0.4, sharp: 0.8)
                self.scene.addParticleSystem(FX.burst(color: .white, count: 30, speed: 4, size: 0.15), transform: SCNMatrix4MakeTranslation(bp.x, bp.y + 2.5, bp.z + 2))
                boss.runAction(.sequence([.scale(to: 0.94, duration: 0.05), .scale(to: 1, duration: 0.1)]))
            }
        }
        if bossHP <= 0 { win() }
        else if battleT >= duration { // 力不足：ボスの反撃で全滅
            lose()
        }
    }

    private func win() {
        phase = .won; abilityReady = false
        AudioEngine.shared.stop()
        // 一瞬の静寂 → インパクト → スローモーション → ファンファーレ
        scene.physicsWorld.speed = 0.3
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, let boss = self.bossNode else { return }
            AudioEngine.shared.play("boss_down"); Haptics.shared.rumble(0.6, intensity: 1); self.shake = 0.8
            self.scene.addParticleSystem(FX.burst(color: UIColor(red: 1, green: 0.6, blue: 0.8, alpha: 1), count: 900, speed: 16, size: 0.5), transform: SCNMatrix4MakeTranslation(boss.position.x, boss.position.y + 2.5, boss.position.z))
            boss.runAction(.sequence([.group([.scale(to: 1.6, duration: 0.5), .fadeOut(duration: 0.5)]), .removeFromParentNode()]))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { AudioEngine.shared.play("win") }
        }
        Progress.shared.clear(stage: stage.index, dna: 20 + stage.index * 5 + dnaCollected, element: swarm.element, sizeClass: swarm.sizeClass)
    }

    private func lose() {
        phase = .lost; abilityReady = false
        AudioEngine.shared.stop(); AudioEngine.shared.play("gate_bad")
        Haptics.shared.rumble(0.4, intensity: 0.6)
    }

    private func popup(_ s: String, _ c: Color) {
        let p = Popup(text: s, color: c); popups.append(p)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self] in self?.popups.removeAll { $0.id == p.id } }
    }
}
