import SceneKit
import UIKit

/// AI社員04: プロシージャル生命体。形状・器官・動きが進化で変わる（色違いだけにしない）
enum Palette {
    static func color(_ e: Element) -> UIColor {
        switch e {
        case .none: return UIColor(red: 0.35, green: 0.95, blue: 0.80, alpha: 1)
        case .fire: return UIColor(red: 1.00, green: 0.45, blue: 0.20, alpha: 1)
        case .ice: return UIColor(red: 0.55, green: 0.85, blue: 1.00, alpha: 1)
        case .thunder: return UIColor(red: 1.00, green: 0.88, blue: 0.25, alpha: 1)
        case .poison: return UIColor(red: 0.65, green: 1.00, blue: 0.30, alpha: 1)
        case .water: return UIColor(red: 0.25, green: 0.55, blue: 1.00, alpha: 1)
        case .plant: return UIColor(red: 0.40, green: 0.90, blue: 0.40, alpha: 1)
        case .rock: return UIColor(red: 0.75, green: 0.60, blue: 0.45, alpha: 1)
        case .dark: return UIColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1)
        case .light: return UIColor(red: 1.00, green: 0.95, blue: 0.75, alpha: 1)
        case .cosmic: return UIColor(red: 0.85, green: 0.45, blue: 1.00, alpha: 1)
        }
    }
}

enum Mat {
    static func rimShader(_ c: UIColor, power: Float = 2.2, strength: Float = 1.2) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return """
        float rim = 1.0 - saturate(dot(_surface.normal, normalize(_surface.view)));
        _output.color.rgb += float3(\(r), \(g), \(b)) * pow(rim, \(power)) * \(strength);
        """
    }
    /// 半透明のゼリー状ボディ（リムライト付き）
    static func jelly(_ c: UIColor, alpha: CGFloat = 0.9) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = c.withAlphaComponent(alpha)
        m.specular.contents = UIColor.white
        m.shininess = 0.6
        m.emission.contents = c.withAlphaComponent(1).darker(0.82)
        m.transparencyMode = .dualLayer
        m.shaderModifiers = [.fragment: rimShader(c.lighter(0.4), strength: 0.7)]
        return m
    }
    static func glow(_ c: UIColor) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = c; return m
    }
    static func solid(_ c: UIColor, shiny: CGFloat = 0.4) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .blinn; m.diffuse.contents = c
        m.specular.contents = UIColor(white: shiny, alpha: 1); m.shininess = 0.5; return m
    }
}

extension UIColor {
    func lighter(_ t: CGFloat) -> UIColor { blend(.white, t) }
    func darker(_ t: CGFloat) -> UIColor { blend(.black, t) }
    func blend(_ o: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1); o.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1)
    }
}

enum CreatureFactory {
    private static var cache: [String: SCNNode] = [:]

    /// 同一形態はテンプレートを clone() → ジオメトリ共有で描画バッチ化
    static func unit(element: Element, sizeClass: Int) -> SCNNode {
        let key = "\(element.rawValue)-\(sizeClass)"
        if cache[key] == nil { cache[key] = build(element: element, sizeClass: sizeClass) }
        let n = cache[key]!.clone()
        animateIdle(n, sizeClass: sizeClass)
        return n
    }

    static func build(element: Element, sizeClass: Int) -> SCNNode {
        let c = Palette.color(element)
        let root = SCNNode(); root.name = "creature"
        let body = SCNNode(); body.name = "body"; root.addChildNode(body)

        // ボディ：微生物は丸、進化形は属性ごとに形状変化
        let r: CGFloat = 0.32
        let shell = SCNNode(geometry: SCNSphere(radius: r))
        (shell.geometry as! SCNSphere).segmentCount = 28
        shell.geometry!.materials = [Mat.jelly(c)]
        switch element {
        case .fire: shell.scale = SCNVector3(1.0, 0.92, 1.15)
        case .ice: shell.scale = SCNVector3(0.95, 1.05, 0.95)
        case .thunder: shell.scale = SCNVector3(1.1, 0.85, 1.05)
        default: break
        }
        body.addChildNode(shell)

        // 発光する核
        let nucleus = SCNNode(geometry: SCNSphere(radius: r * 0.38))
        nucleus.geometry!.materials = [Mat.glow(c.lighter(0.55))]
        nucleus.position = SCNVector3(0.05, -0.04, 0.05)
        body.addChildNode(nucleus)
        nucleus.runAction(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.6), .scale(to: 0.9, duration: 0.6)])))

        // 目（カメラ側＝+Z、やや上向き）。巨大個体は3つ目
        let eyeCount = sizeClass >= 2 ? 3 : 2
        let eyes = SCNNode(); eyes.name = "eyes"; body.addChildNode(eyes)
        for i in 0..<eyeCount {
            let t = eyeCount == 2 ? (i == 0 ? -1.0 : 1.0) : Double(i - 1)
            let er: CGFloat = eyeCount == 3 && i == 1 ? 0.105 : 0.088
            let eye = SCNNode(geometry: SCNSphere(radius: er))
            eye.geometry!.materials = [Mat.solid(.white, shiny: 0.9)]
            eye.position = SCNVector3(Float(t) * 0.13, 0.13 + (eyeCount == 3 && i == 1 ? 0.06 : 0), 0.24)
            let pupil = SCNNode(geometry: SCNSphere(radius: er * 0.58))
            pupil.geometry!.materials = [Mat.solid(UIColor(red: 0.08, green: 0.05, blue: 0.15, alpha: 1), shiny: 1)]
            pupil.position = SCNVector3(0, 0.0, Float(er) * 0.62)
            let hl = SCNNode(geometry: SCNSphere(radius: er * 0.22))
            hl.geometry!.materials = [Mat.glow(.white)]
            hl.position = SCNVector3(Float(er) * 0.25, Float(er) * 0.3, Float(er) * 0.5)
            pupil.addChildNode(hl); eye.addChildNode(pupil); eyes.addChildNode(eye)
        }

        // 器官：属性ごとに異なるパーツ
        switch element {
        case .none:
            let cilia = SCNNode(); cilia.name = "cilia"
            let g = SCNCapsule(capRadius: 0.025, height: 0.22); g.materials = [Mat.glow(c.lighter(0.2))]
            for k in 0..<10 {
                let a = Float(k) / 10 * .pi * 2
                let n = SCNNode(geometry: g)
                n.position = SCNVector3(cos(a) * Float(r) * 1.02, -0.05, sin(a) * Float(r) * 1.02)
                n.eulerAngles = SCNVector3(sin(a) * 1.2, 0, -cos(a) * 1.2)
                cilia.addChildNode(n)
            }
            body.addChildNode(cilia)
            cilia.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 3)))
        case .fire:
            let horn = SCNCone(topRadius: 0, bottomRadius: 0.06, height: 0.22); horn.materials = [Mat.solid(UIColor(red: 1, green: 0.85, blue: 0.5, alpha: 1))]
            for s in [-1, 1] as [Float] {
                let h = SCNNode(geometry: horn); h.position = SCNVector3(s * 0.15, 0.27, 0.0); h.eulerAngles = SCNVector3(-0.3, 0, -s * 0.45)
                body.addChildNode(h)
            }
            let flame = SCNCone(topRadius: 0, bottomRadius: 0.13, height: 0.42); flame.materials = [Mat.glow(UIColor(red: 1, green: 0.6, blue: 0.15, alpha: 0.9))]
            let tail = SCNNode(geometry: flame); tail.name = "tail"; tail.position = SCNVector3(0, 0.05, -0.36); tail.eulerAngles = SCNVector3(-.pi / 2 - 0.4, 0, 0)
            body.addChildNode(tail)
            tail.runAction(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.18), .scale(to: 0.85, duration: 0.22)])))
        case .ice:
            let spike = SCNPyramid(width: 0.12, height: 0.3, length: 0.12); spike.materials = [Mat.jelly(UIColor(red: 0.8, green: 0.95, blue: 1, alpha: 1), alpha: 0.8)]
            for k in 0..<5 {
                let a = Float(k - 2) * 0.42
                let s = SCNNode(geometry: spike); s.position = SCNVector3(sin(a) * 0.2, 0.22, -0.08 - abs(sin(a)) * 0.05)
                s.eulerAngles = SCNVector3(-0.5, 0, -a); body.addChildNode(s)
            }
        case .thunder:
            let wingG = SCNSphere(radius: 0.22); wingG.materials = [Mat.jelly(UIColor(red: 1, green: 0.95, blue: 0.5, alpha: 1), alpha: 0.55)]
            for s in [-1, 1] as [Float] {
                let pivot = SCNNode(); pivot.position = SCNVector3(s * 0.22, 0.12, -0.05)
                let w = SCNNode(geometry: wingG); w.scale = SCNVector3(1.4, 0.12, 0.8); w.position = SCNVector3(s * 0.26, 0, 0)
                pivot.addChildNode(w); body.addChildNode(pivot)
                pivot.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0, z: CGFloat(s) * 0.6, duration: 0.09), .rotateTo(x: 0, y: 0, z: CGFloat(-s) * 0.3, duration: 0.09)])))
            }
            let bolt = SCNNode(geometry: SCNBox(width: 0.04, height: 0.2, length: 0.04, chamferRadius: 0.01))
            bolt.geometry!.materials = [Mat.glow(.white)]; bolt.position = SCNVector3(0, 0.36, 0); bolt.eulerAngles.z = 0.4
            body.addChildNode(bolt)
        default: break
        }

        // 融合個体：王冠状の突起と周回する発光体
        if sizeClass >= 1 {
            let crown = SCNNode()
            let g = SCNCone(topRadius: 0, bottomRadius: 0.05, height: 0.16); g.materials = [Mat.glow(c.lighter(0.4))]
            for k in 0..<(4 + sizeClass * 2) {
                let a = Float(k) / Float(4 + sizeClass * 2) * .pi * 2
                let n = SCNNode(geometry: g); n.position = SCNVector3(cos(a) * 0.18, 0.3, sin(a) * 0.18)
                n.eulerAngles = SCNVector3(sin(a) * 0.5, 0, -cos(a) * 0.5); crown.addChildNode(n)
            }
            body.addChildNode(crown)
            let orbit = SCNNode()
            for k in 0..<3 {
                let m = SCNNode(geometry: SCNSphere(radius: 0.05)); m.geometry!.materials = [Mat.glow(c.lighter(0.6))]
                let a = Float(k) / 3 * .pi * 2; m.position = SCNVector3(cos(a) * 0.5, 0.1, sin(a) * 0.5); orbit.addChildNode(m)
            }
            root.addChildNode(orbit)
            orbit.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 2)))
            let s = Float([1, 1.9, 2.8, 3.8][min(sizeClass, 3)])
            root.scale = SCNVector3(s, s, s)
        }
        return root
    }

    static func animateIdle(_ n: SCNNode, sizeClass: Int) {
        guard let body = n.childNode(withName: "body", recursively: false) else { return }
        let ph = Double.random(in: 0...0.5)
        let breathe = SCNAction.sequence([.wait(duration: ph), .repeatForever(.sequence([
            .group([.scale(to: 1.07, duration: 0.42), .moveBy(x: 0, y: 0.07, z: 0, duration: 0.42)]),
            .group([.scale(to: 0.95, duration: 0.42), .moveBy(x: 0, y: -0.07, z: 0, duration: 0.42)]),
        ]))])
        breathe.timingMode = .easeInEaseOut
        body.runAction(breathe)
        if let eyes = body.childNode(withName: "eyes", recursively: false) {
            eyes.runAction(.repeatForever(.sequence([
                .wait(duration: Double.random(in: 1.8...4.0)),
                .customAction(duration: 0.12) { node, t in node.scale.y = Float(max(0.1, abs(1 - 2 * t / 0.12))) },
                .run { $0.scale.y = 1 },
            ])))
        }
    }

    // MARK: - ボス：多葉アメーバ型（触手・複眼・脈動する核）
    static func boss(_ def: BossDef) -> SCNNode {
        let root = SCNNode(); root.name = "boss"
        let c = UIColor(red: 0.85, green: 0.25, blue: 0.55, alpha: 1)
        let core = SCNNode(geometry: SCNSphere(radius: 2.0)); core.geometry!.materials = [Mat.jelly(c, alpha: 0.72)]
        root.addChildNode(core)
        let heart = SCNNode(geometry: SCNSphere(radius: 0.8)); heart.geometry!.materials = [Mat.glow(UIColor(red: 1, green: 0.5, blue: 0.75, alpha: 1))]
        root.addChildNode(heart)
        heart.runAction(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.35), .scale(to: 0.95, duration: 0.5)])))
        for k in 0..<6 {
            let a = Float(k) / 6 * .pi * 2
            let lobe = SCNNode(geometry: SCNSphere(radius: 1.0)); lobe.geometry!.materials = [Mat.jelly(c.darker(0.15), alpha: 0.7)]
            lobe.position = SCNVector3(cos(a) * 1.7, sin(a) * 1.3, -0.4)
            root.addChildNode(lobe)
            lobe.runAction(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.7 + Double(k) * 0.05), .scale(to: 0.92, duration: 0.7)])))
            // 触手
            let tent = SCNNode(); tent.position = SCNVector3(cos(a) * 2.4, sin(a) * 1.8 - 0.3, -0.2)
            var parent = tent
            for j in 0..<5 {
                let seg = SCNNode(geometry: SCNSphere(radius: CGFloat(0.32 - Float(j) * 0.05)))
                seg.geometry!.materials = [Mat.jelly(c.lighter(0.1), alpha: 0.8)]
                seg.position = j == 0 ? SCNVector3Zero : SCNVector3(cos(a) * 0.42, sin(a) * 0.42 - 0.1, 0.05)
                parent.addChildNode(seg); parent = seg
                seg.runAction(.repeatForever(.sequence([.rotateBy(x: 0.25, y: 0, z: 0.3, duration: 0.6 + Double(j) * 0.1), .rotateBy(x: -0.25, y: 0, z: -0.3, duration: 0.6 + Double(j) * 0.1)])))
            }
            root.addChildNode(tent)
        }
        // 怒った複眼
        for (i, p) in [(-0.7, 0.6, 0.32), (0.7, 0.6, 0.32), (0, 1.05, 0.22)].enumerated() {
            let eye = SCNNode(geometry: SCNSphere(radius: CGFloat(p.2))); eye.geometry!.materials = [Mat.solid(UIColor(red: 1, green: 0.95, blue: 0.6, alpha: 1), shiny: 1)]
            eye.position = SCNVector3(Float(p.0), Float(p.1), 1.85)
            let pupil = SCNNode(geometry: SCNSphere(radius: CGFloat(p.2 * 0.55))); pupil.geometry!.materials = [Mat.solid(.black, shiny: 1)]
            pupil.position = SCNVector3(0, -0.03, Float(p.2) * 0.6); pupil.scale = SCNVector3(0.55, 1, 1)
            eye.addChildNode(pupil)
            if i < 2 {
                let brow = SCNNode(geometry: SCNBox(width: 0.6, height: 0.1, length: 0.1, chamferRadius: 0.05))
                brow.geometry!.materials = [Mat.solid(c.darker(0.5))]
                brow.position = SCNVector3(Float(p.0), Float(p.1) + 0.38, 1.95); brow.eulerAngles.z = i == 0 ? -0.4 : 0.4
                root.addChildNode(brow)
            }
            root.addChildNode(eye)
        }
        let mouth = SCNNode(geometry: SCNTorus(ringRadius: 0.45, pipeRadius: 0.08)); mouth.geometry!.materials = [Mat.solid(c.darker(0.6))]
        mouth.position = SCNVector3(0, -0.35, 1.85); mouth.eulerAngles.x = .pi / 2; mouth.scale = SCNVector3(1, 1, 0.5)
        root.addChildNode(mouth)
        root.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.3, z: 0, duration: 1.1), .moveBy(x: 0, y: -0.3, z: 0, duration: 1.1)])))
        return root
    }

    // MARK: - 障害物：トゲ付きウイルス
    static func virus() -> SCNNode {
        let root = SCNNode()
        let c = UIColor(red: 0.75, green: 0.2, blue: 0.95, alpha: 1)
        let core = SCNNode(geometry: SCNSphere(radius: 0.55)); core.geometry!.materials = [Mat.jelly(c, alpha: 0.85)]
        root.addChildNode(core)
        let spikeG = SCNCone(topRadius: 0.07, bottomRadius: 0.1, height: 0.45); spikeG.materials = [Mat.solid(c.lighter(0.2))]
        let tipG = SCNSphere(radius: 0.1); tipG.materials = [Mat.glow(UIColor(red: 1, green: 0.4, blue: 0.7, alpha: 1))]
        let golden = Float.pi * (3 - sqrt(5))
        for i in 0..<18 {
            let y = 1 - Float(i) / 17 * 2; let rr = sqrt(1 - y * y); let th = golden * Float(i)
            let dir = SCNVector3(cos(th) * rr, y, sin(th) * rr)
            let s = SCNNode(geometry: spikeG); s.position = SCNVector3(dir.x * 0.7, dir.y * 0.7, dir.z * 0.7)
            s.look(at: SCNVector3(dir.x * 2, dir.y * 2, dir.z * 2), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
            let tip = SCNNode(geometry: tipG); tip.position = SCNVector3(0, 0.24, 0); s.addChildNode(tip)
            core.addChildNode(s)
        }
        core.runAction(.repeatForever(.rotateBy(x: 1, y: 2, z: 0, duration: 2)))
        return root
    }
}
