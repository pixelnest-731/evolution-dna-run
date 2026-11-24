import SceneKit
import UIKit

/// AI社員04/08: オーナー提供のプレイ画面イメージ準拠「楽園の水辺」ワールド
/// 青空・雲・ターコイズの水面・滝のある浮島・ヤシ・岩・花・クリスタル・遠景のボス城
enum WorldJungle {
    static func build(into scene: SCNScene, length: Float) {
        scene.background.contents = FX.gradientImage(UIColor(red: 0.22, green: 0.55, blue: 0.98, alpha: 1), UIColor(red: 0.80, green: 0.93, blue: 1.0, alpha: 1))
        scene.fogColor = UIColor(red: 0.80, green: 0.92, blue: 1.0, alpha: 1)
        scene.fogStartDistance = 30; scene.fogEndDistance = 110
        let root = scene.rootNode
        let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient
        amb.light!.color = UIColor(red: 0.78, green: 0.84, blue: 0.95, alpha: 1); root.addChildNode(amb)
        let sun = SCNNode(); sun.light = SCNLight(); sun.light!.type = .directional
        sun.light!.color = UIColor(red: 1, green: 0.96, blue: 0.88, alpha: 1); sun.light!.intensity = 900
        sun.eulerAngles = SCNVector3(-0.9, 0.5, 0); root.addChildNode(sun)
        let back = SCNNode(); back.light = SCNLight(); back.light!.type = .directional
        back.light!.color = UIColor(red: 1, green: 0.85, blue: 0.7, alpha: 1); back.light!.intensity = 450
        back.eulerAngles = SCNVector3(-0.4, .pi, 0); root.addChildNode(back)

        let total = -length + 80
        let cz = -total / 2 + 30
        // 道：白〜ラベンダーの六角タイル
        let hw = WorldBuilder.laneHalfWidth
        let floorG = SCNBox(width: CGFloat(hw * 2), height: 0.5, length: CGFloat(total), chamferRadius: 0)
        let fm = SCNMaterial(); fm.lightingModel = .blinn
        fm.diffuse.contents = UIColor(red: 0.74, green: 0.73, blue: 0.88, alpha: 1)
        fm.specular.contents = UIColor(white: 0.3, alpha: 1)
        fm.shaderModifiers = [.surface: """
        float2 uv = _surface.diffuseTexcoord * float2(3.2, \(Int(total / 1.9)).0);
        float2 r = float2(1.0, 1.732);
        float2 a = fmod(uv, r) - r * 0.5; float2 b = fmod(uv - r * 0.5, r) - r * 0.5;
        float2 g = dot(a, a) < dot(b, b) ? a : b;
        float2 q = abs(g); float hexd = max(dot(q, normalize(float2(1.0, 1.732))), q.x);
        float line = smoothstep(0.44, 0.48, hexd);
        float tint = 0.5 + 0.5 * sin(dot(uv - g, float2(2.3, 1.1)));
        _surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.68, 0.66, 0.86), tint * 0.5) - float3(0.14, 0.14, 0.08) * line;
        """]
        floorG.materials = [fm]
        let floor = SCNNode(geometry: floorG); floor.position = SCNVector3(0, -0.25, cz); root.addChildNode(floor)

        // 縁石：紫と黄色のストライプ（発光）
        let curbG = SCNBox(width: 0.45, height: 0.4, length: CGFloat(total), chamferRadius: 0.15)
        let cm = SCNMaterial(); cm.lightingModel = .blinn; cm.diffuse.contents = UIColor(red: 0.62, green: 0.48, blue: 0.95, alpha: 1)
        cm.shaderModifiers = [.fragment: """
        float st = step(0.55, fract(_surface.diffuseTexcoord.y * \(Int(total / 3)).0));
        _output.color.rgb = mix(_output.color.rgb, float3(1.0, 0.92, 0.45), st);
        
        """]
        curbG.materials = [cm]
        for s in [-1, 1] as [Float] {
            let c = SCNNode(geometry: curbG); c.position = SCNVector3(s * (hw + 0.2), 0.05, cz); root.addChildNode(c)
        }

        // 水面
        let waterG = SCNPlane(width: 220, height: CGFloat(total + 100))
        let wm = SCNMaterial(); wm.lightingModel = .constant
        wm.diffuse.contents = UIColor(red: 0.10, green: 0.62, blue: 0.95, alpha: 1)
        wm.shaderModifiers = [.fragment: """
        float2 p = _surface.diffuseTexcoord * float2(70.0, 120.0); float t = scn_frame.time;
        float c = sin(p.x * 1.1 + t * 1.2) * sin(p.y * 0.8 - t) + sin((p.x + p.y) * 0.6 + t * 0.7);
        float sp = pow(saturate(0.5 + 0.3 * c), 6.0);
        _output.color.rgb = mix(_output.color.rgb, float3(0.35, 0.9, 1.0), 0.35 + 0.2 * sin(p.y * 0.05));
        _output.color.rgb += float3(1.0, 1.0, 1.0) * sp * 0.8;
        """]
        waterG.materials = [wm]
        let water = SCNNode(geometry: waterG); water.eulerAngles.x = -.pi / 2; water.position = SCNVector3(0, -0.45, cz - 40)
        root.addChildNode(water)

        var rng = SplitMix64(seed: 2024)
        // 近景：ヤシ・岩・花・クリスタル（道の両脇の小島）
        var z: Float = 20
        while z > length - 20 {
            for s in [-1, 1] as [Float] {
                let x = s * Float.random(in: hw + 2.2...hw + 7, using: &rng)
                let isle = islet(&rng); isle.position = SCNVector3(x, -0.45, z + Float.random(in: -2...2, using: &rng))
                root.addChildNode(isle)
            }
            z -= Float.random(in: 7...11, using: &rng)
        }
        // 中景・遠景：滝のある浮島・崖
        z = 0
        while z > length - 60 {
            for s in [-1, 1] as [Float] {
                let x = s * Float.random(in: 16...32, using: &rng)
                let n = floatingIsland(&rng, big: Bool.random(using: &rng))
                n.position = SCNVector3(x, Float.random(in: 2...9, using: &rng), z + Float.random(in: -6...6, using: &rng))
                root.addChildNode(n)
            }
            z -= Float.random(in: 14...20, using: &rng)
        }
        // 最奥：ボスの城がある大きな島（ゴール目印）
        let castle = floatingIsland(&rng, big: true); castle.scale = SCNVector3(2.4, 2.4, 2.4)
        castle.position = SCNVector3(4, 6, length - 45)
        let spire = SCNNode(geometry: SCNPyramid(width: 1.2, height: 4, length: 1.2)); spire.geometry!.materials = [Mat.jelly(UIColor(red: 0.85, green: 0.6, blue: 1, alpha: 1), alpha: 0.9)]
        spire.position = SCNVector3(0, 2.2, 0); castle.addChildNode(spire)
        root.addChildNode(castle)
        // 雲
        for i in 0..<10 {
            let c = cloud(&rng); c.position = SCNVector3(Float(i % 2 == 0 ? -1 : 1) * Float.random(in: 10...45, using: &rng), Float.random(in: 14...24, using: &rng), Float(-i) * 25 + 20)
            root.addChildNode(c)
        }
    }

    static func palm(_ rng: inout SplitMix64) -> SCNNode {
        let n = SCNNode()
        let h = Float.random(in: 2.5...4.2, using: &rng)
        let trunkM = Toon.mat(UIColor(red: 0.62, green: 0.45, blue: 0.3, alpha: 1))
        var y: Float = 0; var x: Float = 0
        for i in 0..<6 {
            let seg = SCNNode(geometry: SCNCylinder(radius: CGFloat(0.16 - Float(i) * 0.012), height: CGFloat(h / 6 + 0.05))); seg.geometry!.materials = [trunkM]
            x += 0.06; seg.position = SCNVector3(x, y + h / 12, 0); seg.eulerAngles.z = -0.12; n.addChildNode(seg); y += h / 6
        }
        let leafM = Toon.mat(UIColor(red: 0.25, green: 0.75, blue: 0.3, alpha: 1), rim: UIColor(red: 0.8, green: 1, blue: 0.5, alpha: 1), rimStrength: 0.6)
        let crown = SCNNode(); crown.position = SCNVector3(x, y, 0); n.addChildNode(crown)
        for k in 0..<7 {
            let a = Float(k) / 7 * .pi * 2
            let leaf = SCNNode(geometry: SCNSphere(radius: 0.5)); leaf.geometry!.materials = [leafM]
            leaf.scale = SCNVector3(2.2, 0.25, 0.7)
            let piv = SCNNode(); piv.eulerAngles = SCNVector3(0, a, -0.25)
            leaf.position = SCNVector3(0.9, -0.15, 0); piv.addChildNode(leaf); crown.addChildNode(piv)
        }
        crown.runAction(.repeatForever(.sequence([.rotateBy(x: 0, y: 0, z: 0.06, duration: 1.6), .rotateBy(x: 0, y: 0, z: -0.06, duration: 1.6)])))
        return n
    }

    static func rock(_ rng: inout SplitMix64, size: Float) -> SCNNode {
        let g = SCNBox(width: CGFloat(size), height: CGFloat(size * 0.6), length: CGFloat(size * 0.8), chamferRadius: CGFloat(size * 0.25))
        g.materials = [Toon.mat(UIColor(red: 0.62, green: 0.64, blue: 0.70, alpha: 1), rimStrength: 0.25)]
        let n = SCNNode(geometry: g); n.eulerAngles.y = Float.random(in: 0...3, using: &rng)
        let moss = SCNNode(geometry: SCNBox(width: CGFloat(size * 0.95), height: CGFloat(size * 0.15), length: CGFloat(size * 0.75), chamferRadius: CGFloat(size * 0.07)))
        moss.geometry!.materials = [Toon.mat(UIColor(red: 0.35, green: 0.78, blue: 0.35, alpha: 1))]
        moss.position.y = size * 0.3; n.addChildNode(moss)
        return n
    }

    static func flower(_ c: UIColor) -> SCNNode {
        let n = SCNNode()
        let pm = Toon.mat(c, rimStrength: 0.4)
        for k in 0..<5 {
            let a = Float(k) / 5 * .pi * 2
            let p = SCNNode(geometry: SCNSphere(radius: 0.13)); p.geometry!.materials = [pm]
            p.scale = SCNVector3(1, 0.3, 0.6); p.position = SCNVector3(cos(a) * 0.13, 0, sin(a) * 0.13); p.eulerAngles.y = -a
            n.addChildNode(p)
        }
        let c2 = SCNNode(geometry: SCNSphere(radius: 0.07)); c2.geometry!.materials = [Mat.glow(UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1))]
        n.addChildNode(c2)
        return n
    }

    static func crystal(_ c: UIColor, h: Float) -> SCNNode {
        let n = SCNNode()
        let g = SCNPyramid(width: CGFloat(h * 0.35), height: CGFloat(h), length: CGFloat(h * 0.35))
        g.materials = [Mat.jelly(c, alpha: 0.85)]
        for k in 0..<3 {
            let p = SCNNode(geometry: g); p.scale = SCNVector3(1, 1 - Float(k) * 0.25, 1)
            p.eulerAngles = SCNVector3(0, Float(k) * 1.3, Float(k - 1) * 0.35); p.position.x = Float(k - 1) * h * 0.15
            n.addChildNode(p)
        }
        return n
    }

    /// 道脇の小島
    static func islet(_ rng: inout SplitMix64) -> SCNNode {
        let n = SCNNode()
        let r = Float.random(in: 1.4...2.4, using: &rng)
        let base = SCNNode(geometry: SCNCylinder(radius: CGFloat(r), height: 0.7)); base.geometry!.materials = [Toon.mat(UIColor(red: 0.6, green: 0.62, blue: 0.7, alpha: 1), rimStrength: 0.2)]
        n.addChildNode(base)
        let grass = SCNNode(geometry: SCNCylinder(radius: CGFloat(r * 0.95), height: 0.2)); grass.geometry!.materials = [Toon.mat(UIColor(red: 0.38, green: 0.82, blue: 0.35, alpha: 1), rim: UIColor(red: 0.9, green: 1, blue: 0.6, alpha: 1))]
        grass.position.y = 0.42; n.addChildNode(grass)
        switch Int.random(in: 0..<4, using: &rng) {
        case 0, 1:
            let p = palm(&rng); p.position.y = 0.5; n.addChildNode(p)
        case 2:
            let c = crystal([UIColor(red: 0.8, green: 0.55, blue: 1, alpha: 1), UIColor(red: 0.5, green: 0.85, blue: 1, alpha: 1)].randomElement(using: &rng)!, h: Float.random(in: 0.9...1.6, using: &rng))
            c.position.y = 0.9; n.addChildNode(c)
        default:
            let rk = rock(&rng, size: Float.random(in: 0.9...1.5, using: &rng)); rk.position.y = 0.75; n.addChildNode(rk)
        }
        let cols = [UIColor(red: 1, green: 0.45, blue: 0.75, alpha: 1), UIColor(red: 1, green: 0.75, blue: 0.3, alpha: 1), UIColor(red: 0.75, green: 0.5, blue: 1, alpha: 1)]
        for _ in 0..<3 {
            let f = flower(cols.randomElement(using: &rng)!); let a = Float.random(in: 0...6.28, using: &rng)
            f.position = SCNVector3(cos(a) * r * 0.7, 0.55, sin(a) * r * 0.7); n.addChildNode(f)
        }
        return n
    }

    /// 滝のある浮島
    static func floatingIsland(_ rng: inout SplitMix64, big: Bool) -> SCNNode {
        let n = SCNNode()
        let r = big ? Float.random(in: 3...5, using: &rng) : Float.random(in: 1.8...3, using: &rng)
        let under = SCNNode(geometry: SCNCone(topRadius: CGFloat(r), bottomRadius: CGFloat(r * 0.25), height: CGFloat(r * 1.3)))
        under.geometry!.materials = [Toon.mat(UIColor(red: 0.58, green: 0.55, blue: 0.62, alpha: 1), rimStrength: 0.2)]
        under.position.y = -r * 0.65; n.addChildNode(under)
        let top = SCNNode(geometry: SCNCylinder(radius: CGFloat(r * 1.02), height: 0.35)); top.geometry!.materials = [Toon.mat(UIColor(red: 0.35, green: 0.8, blue: 0.35, alpha: 1), rim: UIColor(red: 0.9, green: 1, blue: 0.6, alpha: 1))]
        n.addChildNode(top)
        for _ in 0..<(big ? 4 : 2) {
            let p = palm(&rng); let a = Float.random(in: 0...6.28, using: &rng)
            p.position = SCNVector3(cos(a) * r * 0.6, 0.15, sin(a) * r * 0.6); n.addChildNode(p)
        }
        if big || Bool.random(using: &rng) {
            // 滝：流れるシェーダー＋しぶき
            let fallH = r * 2.2
            let fallG = SCNPlane(width: CGFloat(r * 0.45), height: CGFloat(fallH))
            let fm = SCNMaterial(); fm.lightingModel = .constant; fm.isDoubleSided = true
            fm.diffuse.contents = UIColor(red: 0.75, green: 0.95, blue: 1, alpha: 0.85)
            fm.shaderModifiers = [.fragment: """
            float v = fract(_surface.diffuseTexcoord.y * 3.0 - scn_frame.time * 1.5 + sin(_surface.diffuseTexcoord.x * 20.0) * 0.1);
            _output.color.rgb = mix(float3(0.55, 0.88, 1.0), float3(1.0, 1.0, 1.0), smoothstep(0.6, 1.0, v));
            _output.color.a = 0.9;
            """]
            fallG.materials = [fm]
            let fall = SCNNode(geometry: fallG); fall.position = SCNVector3(0, -fallH / 2, r * 0.95); n.addChildNode(fall)
            let mist = SCNParticleSystem(); mist.particleImage = FX.softDot; mist.birthRate = 12; mist.particleLifeSpan = 1.2
            mist.particleSize = 0.6; mist.particleColor = UIColor(white: 1, alpha: 0.5); mist.spreadingAngle = 60; mist.particleVelocity = 0.8
            let mn = SCNNode(); mn.position = SCNVector3(0, -fallH, r * 0.95); mn.addParticleSystem(mist); n.addChildNode(mn)
        }
        if Int.random(in: 0..<3, using: &rng) == 0 {
            let c = crystal(UIColor(red: 0.8, green: 0.6, blue: 1, alpha: 1), h: r * 0.6); c.position.y = r * 0.3; n.addChildNode(c)
        }
        n.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.4, z: 0, duration: 3), .moveBy(x: 0, y: -0.4, z: 0, duration: 3)])))
        return n
    }

    static func cloud(_ rng: inout SplitMix64) -> SCNNode {
        let n = SCNNode(); let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = UIColor(white: 1, alpha: 0.95)
        for _ in 0..<5 {
            let s = SCNNode(geometry: SCNSphere(radius: CGFloat(Float.random(in: 1.2...2.4, using: &rng)))); s.geometry!.materials = [m]
            s.position = SCNVector3(Float.random(in: -3...3, using: &rng), Float.random(in: -0.5...0.8, using: &rng), Float.random(in: -1...1, using: &rng)); s.scale.y = 0.7
            n.addChildNode(s)
        }
        return n
    }
}

/// 虹色のDNAらせん（収集アイテム・ゲートアイコン・進化演出で共用）
enum Helix {
    static let rainbow: [UIColor] = [UIColor(red: 1, green: 0.3, blue: 0.4, alpha: 1), UIColor(red: 1, green: 0.65, blue: 0.2, alpha: 1), UIColor(red: 1, green: 0.9, blue: 0.3, alpha: 1), UIColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 1), UIColor(red: 0.35, green: 0.7, blue: 1, alpha: 1), UIColor(red: 0.7, green: 0.45, blue: 1, alpha: 1)]
    private static var template: SCNNode?
    static func node() -> SCNNode {
        if template == nil {
            let n = SCNNode()
            let strandA = Toon.mat(UIColor(red: 0.3, green: 0.55, blue: 1, alpha: 1), rim: .white, rimStrength: 0.8, shiny: 0.9)
            let strandB = Toon.mat(UIColor(red: 0.75, green: 0.55, blue: 1, alpha: 1), rim: .white, rimStrength: 0.8, shiny: 0.9)
            let bead = SCNSphere(radius: 0.085)
            for i in 0..<16 {
                let t = Float(i) / 15; let a = t * .pi * 2.2; let y = t * 1.3 - 0.65
                let p1 = SCNNode(geometry: bead.copy() as? SCNGeometry); p1.geometry!.materials = [strandA]; p1.position = SCNVector3(cos(a) * 0.28, y, sin(a) * 0.28)
                let p2 = SCNNode(geometry: bead.copy() as? SCNGeometry); p2.geometry!.materials = [strandB]; p2.position = SCNVector3(-cos(a) * 0.28, y, -sin(a) * 0.28)
                n.addChildNode(p1); n.addChildNode(p2)
                if i % 2 == 0 {
                    let rung = SCNNode(geometry: SCNCylinder(radius: 0.035, height: 0.5)); rung.geometry!.materials = [Toon.mat(rainbow[(i / 2) % rainbow.count], rimStrength: 0.5, shiny: 0.8)]
                    rung.position = SCNVector3(0, y, 0); rung.eulerAngles = SCNVector3(0, -a, .pi / 2); n.addChildNode(rung)
                }
            }
            template = n
        }
        return template!.clone()
    }
}
