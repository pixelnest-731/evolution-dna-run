import SceneKit
import UIKit

/// AI社員04: 参考画像（characters / Evolution / Collection）に基づく進化ライン
/// 炎: 子ドラゴン→翼竜→角竜→巨竜 / 氷: 白クマ / 雷: ヒヨコ→雷鳥
/// 前方は -Z（ランナーとしてカメラに背中を見せる）。正面表示は y 回転で行う。
enum Toon {
    static func mat(_ c: UIColor, rim: UIColor = .white, rimStrength: Float = 0.45, shiny: CGFloat = 0.25) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .blinn
        m.diffuse.contents = c
        m.specular.contents = UIColor(white: shiny, alpha: 1)
        m.shininess = 0.35
        m.shaderModifiers = [.fragment: Mat.rimShader(rim, power: 2.6, strength: rimStrength)]
        return m
    }
    static func sphere(_ r: CGFloat, _ m: SCNMaterial, _ p: SCNVector3, scale: SCNVector3 = SCNVector3(1, 1, 1)) -> SCNNode {
        let g = SCNSphere(radius: r); g.segmentCount = 24; g.materials = [m]
        let n = SCNNode(geometry: g); n.position = p; n.scale = scale; return n
    }
    static func cone(_ r: CGFloat, _ h: CGFloat, _ m: SCNMaterial, _ p: SCNVector3, euler: SCNVector3) -> SCNNode {
        let g = SCNCone(topRadius: 0, bottomRadius: r, height: h); g.radialSegmentCount = 12; g.materials = [m]
        let n = SCNNode(geometry: g); n.position = p; n.eulerAngles = euler; return n
    }
    /// 大きな瞳＋ハイライト2つのアニメ調の目（-Z向き）
    static func eye(_ r: CGFloat, at p: SCNVector3, iris: UIColor) -> SCNNode {
        let e = sphere(r, mat(.white, rimStrength: 0, shiny: 0.9), p)
        let ir = sphere(r * 0.78, mat(iris, rimStrength: 0, shiny: 1), SCNVector3(0, -Float(r) * 0.05, -Float(r) * 0.42))
        let pu = sphere(r * 0.5, mat(UIColor(red: 0.08, green: 0.04, blue: 0.08, alpha: 1), rimStrength: 0, shiny: 1), SCNVector3(0, 0, -Float(r) * 0.35))
        let h1 = sphere(r * 0.22, Mat.glow(.white), SCNVector3(Float(r) * 0.25, Float(r) * 0.3, -Float(r) * 0.42))
        let h2 = sphere(r * 0.1, Mat.glow(.white), SCNVector3(-Float(r) * 0.2, -Float(r) * 0.25, -Float(r) * 0.45))
        ir.addChildNode(pu); ir.addChildNode(h1); ir.addChildNode(h2); e.addChildNode(ir)
        return e
    }
}

enum AnimalFactory {
    static func build(element: Element, sizeClass: Int) -> SCNNode {
        switch element {
        case .fire: return dragon(sizeClass)
        case .ice: return bear(sizeClass)
        case .thunder: return bird(sizeClass)
        default: return SCNNode()
        }
    }

    // MARK: 炎ドラゴン
    static func dragon(_ k: Int) -> SCNNode {
        let root = SCNNode(); root.name = "creature"
        let body = SCNNode(); body.name = "body"; root.addChildNode(body)
        let red = k >= 2 ? UIColor(red: 0.92, green: 0.30, blue: 0.18, alpha: 1) : UIColor(red: 1.0, green: 0.45, blue: 0.22, alpha: 1)
        let skin = Toon.mat(red, rim: UIColor(red: 1, green: 0.8, blue: 0.5, alpha: 1))
        let cream = Toon.mat(UIColor(red: 1, green: 0.92, blue: 0.80, alpha: 1))
        let gold = Toon.mat(UIColor(red: 1, green: 0.80, blue: 0.35, alpha: 1), shiny: 0.8)

        body.addChildNode(Toon.sphere(0.3, skin, SCNVector3(0, 0.32, 0.02), scale: SCNVector3(1, 0.95, 1.1)))
        body.addChildNode(Toon.sphere(0.23, cream, SCNVector3(0, 0.28, -0.12), scale: SCNVector3(1, 1.05, 0.8)))
        let head = SCNNode(); head.name = "head"; head.position = SCNVector3(0, 0.7 + Float(k) * 0.04, -0.12 - Float(k) * 0.03)
        body.addChildNode(head)
        head.addChildNode(Toon.sphere(0.3, skin, SCNVector3Zero, scale: SCNVector3(1.05, 0.95, 1)))
        head.addChildNode(Toon.sphere(0.13, cream, SCNVector3(0, -0.12, -0.22), scale: SCNVector3(1.25, 0.65, 0.9 + Float(k) * 0.2)))
        for s in [-1, 1] as [Float] { head.addChildNode(Toon.sphere(0.018, Toon.mat(UIColor(red: 0.4, green: 0.15, blue: 0.1, alpha: 1)), SCNVector3(s * 0.05, -0.08, -0.33))) }
        for s in [-1, 1] as [Float] { head.addChildNode(Toon.sphere(0.05, Mat.glow(UIColor(red: 1, green: 0.55, blue: 0.5, alpha: 0.9)), SCNVector3(s * 0.2, -0.08, -0.21), scale: SCNVector3(1, 0.6, 0.4))) }
        for s in [-1, 1] as [Float] {
            head.addChildNode(Toon.eye(0.1, at: SCNVector3(s * 0.12, 0.04, -0.21), iris: UIColor(red: 0.95, green: 0.6, blue: 0.15, alpha: 1)))
            head.addChildNode(Toon.cone(0.055 + CGFloat(k) * 0.01, 0.2 + CGFloat(k) * 0.07, gold, SCNVector3(s * 0.14, 0.22, 0.05), euler: SCNVector3(0.6, 0, -s * 0.35)))
            if k >= 2 { head.addChildNode(Toon.cone(0.04, 0.16, gold, SCNVector3(s * 0.24, 0.1, 0.1), euler: SCNVector3(0.9, 0, -s * 1.0))) }
            // 脚
            for z in [-0.12, 0.16] as [Float] {
                body.addChildNode(Toon.sphere(0.09, skin, SCNVector3(s * 0.17, 0.08, z), scale: SCNVector3(1, 0.9, 1.2)))
            }
        }
        // 背中のトゲ（後方カメラから見える主要シルエット）
        // 頭頂〜背中〜腰に沿って並ぶトゲ（球面上に配置して外向きに）
        let spine: [(Float, Float, Float, Float)] = [(0.98, -0.08, 0.075, 0.2), (0.93, 0.08, 0.07, 0.18), (0.62, 0.12, 0.065, 0.16), (0.56, 0.26, 0.06, 0.15), (0.45, 0.35, 0.05, 0.13)]
        for (y, z, r, h) in spine {
            let c = Toon.cone(CGFloat(r) * (1 + CGFloat(k) * 0.15), CGFloat(h) * (1 + CGFloat(k) * 0.2), gold, SCNVector3(0, y, z), euler: SCNVector3(0.35 + z * 1.5, 0, 0))
            body.addChildNode(c)
        }
        // 背中のウロコ模様（濃い色の斑点）
        let scaleM = Toon.mat(red.darker(0.18))
        for (x, y, z) in [(-0.12, 0.45, 0.25), (0.12, 0.45, 0.25), (0, 0.38, 0.31), (-0.18, 0.33, 0.22), (0.18, 0.33, 0.22)] as [(Float, Float, Float)] {
            body.addChildNode(Toon.sphere(0.06, scaleM, SCNVector3(x, y, z), scale: SCNVector3(1, 0.8, 0.35)))
        }
        // クリーム色のお尻
        body.addChildNode(Toon.sphere(0.2, cream, SCNVector3(0, 0.2, 0.2), scale: SCNVector3(1.15, 0.9, 0.8)))
        // 尻尾＋炎
        let tail = SCNNode(); tail.name = "tail"; tail.position = SCNVector3(0, 0.25, 0.3); body.addChildNode(tail)
        var p = tail
        for j in 0..<3 {
            let seg = Toon.sphere(CGFloat(0.12 - Float(j) * 0.025), skin, SCNVector3(0, Float(j == 0 ? 0 : 0.05), Float(j == 0 ? 0 : 0.14)))
            p.addChildNode(seg); p = seg
        }
        let flame = SCNNode(); flame.position = SCNVector3(0, 0.14, 0.12); flame.scale = SCNVector3(1.5, 1.5, 1.5)
        flame.addChildNode(Toon.cone(0.11, 0.3, Mat.glow(UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)), SCNVector3Zero, euler: SCNVector3(0.3, 0, 0)))
        flame.addChildNode(Toon.cone(0.06, 0.2, Mat.glow(UIColor(red: 1, green: 0.95, blue: 0.5, alpha: 1)), SCNVector3(0, -0.02, 0.0), euler: SCNVector3(0.3, 0, 0)))
        p.addChildNode(flame)
        flame.runAction(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.15), .scale(to: 0.85, duration: 0.18)])))
        tail.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0.35, z: 0, duration: 0.35), .rotateTo(x: 0, y: -0.35, z: 0, duration: 0.35)])))
        // 翼（k>=1）：段階ごとに大きく
        do {
            let span = Float([0.32, 0.45, 0.62, 0.8][min(k, 3)])
            let memb = Toon.mat(UIColor(red: 1, green: 0.62, blue: 0.25, alpha: 0.95), rim: UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1), rimStrength: 0.8)
            memb.isDoubleSided = true
            for s in [-1, 1] as [Float] {
                let pivot = SCNNode(); pivot.position = SCNVector3(s * 0.2, 0.52, 0.05)
                let path = UIBezierPath()
                path.move(to: .zero)
                path.addLine(to: CGPoint(x: CGFloat(span), y: CGFloat(span) * 0.55))
                path.addQuadCurve(to: CGPoint(x: CGFloat(span) * 0.95, y: -CGFloat(span) * 0.2), controlPoint: CGPoint(x: CGFloat(span) * 0.8, y: CGFloat(span) * 0.15))
                path.addQuadCurve(to: CGPoint(x: CGFloat(span) * 0.55, y: -CGFloat(span) * 0.25), controlPoint: CGPoint(x: CGFloat(span) * 0.75, y: -CGFloat(span) * 0.05))
                path.addQuadCurve(to: CGPoint(x: CGFloat(span) * 0.2, y: -CGFloat(span) * 0.18), controlPoint: CGPoint(x: CGFloat(span) * 0.38, y: -CGFloat(span) * 0.05))
                path.close()
                let shape = SCNShape(path: path, extrusionDepth: 0.02); shape.materials = [memb]
                let w = SCNNode(geometry: shape); w.scale = SCNVector3(s, 1, 1); w.eulerAngles = SCNVector3(0, -.pi / 2 * 0.2 * s, 0)
                let bone = SCNNode(geometry: SCNCapsule(capRadius: 0.025, height: CGFloat(span) * 1.1)); bone.geometry!.materials = [skin]
                bone.position = SCNVector3(s * span * 0.5, span * 0.28, 0.01); bone.eulerAngles.z = -s * (Float.pi / 2 - 0.5)
                pivot.addChildNode(w); pivot.addChildNode(bone); body.addChildNode(pivot)
                pivot.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0, z: CGFloat(s) * 0.35, duration: 0.22), .rotateTo(x: 0, y: 0, z: CGFloat(-s) * 0.25, duration: 0.22)])))
            }
        }
        if k >= 3 { // 巨竜：胸の発光コア
            body.addChildNode(Toon.sphere(0.07, Mat.glow(UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1)), SCNVector3(0, 0.38, -0.32)))
        }
        return finish(root, k)
    }

    // MARK: 氷：白クマ
    static func bear(_ k: Int) -> SCNNode {
        let root = SCNNode(); root.name = "creature"
        let body = SCNNode(); body.name = "body"; root.addChildNode(body)
        let fur = Toon.mat(UIColor(red: 0.96, green: 0.97, blue: 1, alpha: 1), rim: UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 1), rimStrength: 0.7)
        let ice = Mat.jelly(UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1), alpha: 0.85)
        let navy = Toon.mat(UIColor(red: 0.15, green: 0.25, blue: 0.5, alpha: 1), shiny: 0.8)
        body.addChildNode(Toon.sphere(0.32, fur, SCNVector3(0, 0.32, 0.03), scale: SCNVector3(1.05, 0.95, 1.15)))
        let head = SCNNode(); head.name = "head"; head.position = SCNVector3(0, 0.62, -0.18); body.addChildNode(head)
        head.addChildNode(Toon.sphere(0.25, fur, SCNVector3Zero))
        head.addChildNode(Toon.sphere(0.11, fur, SCNVector3(0, -0.07, -0.2), scale: SCNVector3(1.2, 0.85, 1)))
        head.addChildNode(Toon.sphere(0.04, navy, SCNVector3(0, -0.03, -0.31)))
        for s in [-1, 1] as [Float] {
            head.addChildNode(Toon.sphere(0.08, fur, SCNVector3(s * 0.18, 0.18, 0.02)))
            head.addChildNode(Toon.eye(0.07, at: SCNVector3(s * 0.1, 0.05, -0.2), iris: UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)))
            for z in [-0.14, 0.18] as [Float] { body.addChildNode(Toon.sphere(0.1, fur, SCNVector3(s * 0.18, 0.09, z))) }
        }
        // 背中の氷結晶：段階で本数と大きさ増
        let n = [0, 3, 5, 7][min(k, 3)]
        for i in 0..<n {
            let t = n == 1 ? 0 : Float(i) / Float(n - 1) - 0.5
            let crystal = SCNNode(geometry: SCNPyramid(width: 0.1, height: CGFloat(0.22 + Float(k) * 0.05 - abs(t) * 0.1), length: 0.1))
            crystal.geometry!.materials = [ice]
            crystal.position = SCNVector3(t * 0.3, 0.55, 0.08 + abs(t) * 0.1); crystal.eulerAngles = SCNVector3(0.3, 0, -t * 1.2)
            body.addChildNode(crystal)
        }
        if k >= 2 { // 氷の鎧
            let armor = Toon.sphere(0.27, Toon.mat(UIColor(red: 0.3, green: 0.55, blue: 0.95, alpha: 1), shiny: 0.9), SCNVector3(0, 0.42, -0.12), scale: SCNVector3(1.1, 0.5, 0.6))
            body.addChildNode(armor)
        }
        body.addChildNode(Toon.sphere(0.06, fur, SCNVector3(0, 0.3, 0.38)))
        return finish(root, k)
    }

    // MARK: 雷：ヒヨコ→雷鳥
    static func bird(_ k: Int) -> SCNNode {
        let root = SCNNode(); root.name = "creature"
        let body = SCNNode(); body.name = "body"; root.addChildNode(body)
        let yellow = Toon.mat(UIColor(red: 1, green: 0.86, blue: 0.3, alpha: 1), rim: UIColor(red: 1, green: 1, blue: 0.7, alpha: 1))
        let white = Toon.mat(UIColor(red: 1, green: 0.98, blue: 0.92, alpha: 1))
        let orange = Toon.mat(UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1), shiny: 0.6)
        let blue = Toon.mat(UIColor(red: 0.35, green: 0.6, blue: 1, alpha: 1))
        body.addChildNode(Toon.sphere(0.33, k >= 2 ? white : yellow, SCNVector3(0, 0.38, 0), scale: SCNVector3(1, 1.0, 1.05)))
        body.addChildNode(Toon.sphere(0.24, white, SCNVector3(0, 0.33, -0.15), scale: SCNVector3(1, 1, 0.7)))
        let head = SCNNode(); head.name = "head"; head.position = SCNVector3(0, 0.62, -0.12); body.addChildNode(head)
        for s in [-1, 1] as [Float] {
            head.addChildNode(Toon.eye(0.075, at: SCNVector3(s * 0.12, 0.0, -0.22), iris: UIColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1)))
            for z in [0.0] as [Float] { body.addChildNode(Toon.cone(0.05, 0.12, orange, SCNVector3(s * 0.12, 0.05, z - 0.05), euler: SCNVector3(Float.pi, 0, 0))) }
        }
        head.addChildNode(Toon.cone(0.06, 0.13, orange, SCNVector3(0, -0.06, -0.33), euler: SCNVector3(-Float.pi / 2, 0, 0)))
        // 冠羽
        for i in 0..<(3 + k) {
            let a = Float(i) - Float(2 + k) / 2
            head.addChildNode(Toon.cone(0.04, 0.16 + CGFloat(k) * 0.05, k >= 1 ? orange : yellow, SCNVector3(a * 0.04, 0.2, 0.02 + abs(a) * 0.02), euler: SCNVector3(0.5, 0, -a * 0.35)))
        }
        // 翼
        let span = Float([0.2, 0.35, 0.55, 0.75][min(k, 3)])
        for s in [-1, 1] as [Float] {
            let pivot = SCNNode(); pivot.position = SCNVector3(s * 0.28, 0.45, 0.05)
            for f in 0..<(2 + k) {
                let feather = Toon.sphere(0.1, f == 0 ? (k >= 1 ? blue : yellow) : white, SCNVector3(s * (span * 0.4 + Float(f) * span * 0.18), -Float(f) * 0.04, Float(f) * 0.03), scale: SCNVector3(span * 4.5 - Float(f) * 0.3, 0.35, 1.0))
                pivot.addChildNode(feather)
            }
            body.addChildNode(pivot)
            pivot.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0, z: CGFloat(s) * 0.55, duration: 0.12), .rotateTo(x: 0, y: 0, z: CGFloat(-s) * 0.3, duration: 0.12)])))
        }
        if k >= 1 { // 尾羽と稲妻
            for i in 0..<(2 + k) {
                body.addChildNode(Toon.sphere(0.07, i % 2 == 0 ? blue : orange, SCNVector3(Float(i - 1) * 0.07, 0.35, 0.35 + Float(k) * 0.05), scale: SCNVector3(0.6, 0.4, 2.5 + Float(k))))
            }
            let bolt = Toon.cone(0.05, 0.25, Mat.glow(UIColor(red: 1, green: 1, blue: 0.6, alpha: 1)), SCNVector3(0, 0.95, 0.1), euler: SCNVector3(0, 0, 0.5))
            body.addChildNode(bolt)
            bolt.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.3, duration: 0.1), .fadeOpacity(to: 1, duration: 0.1), .wait(duration: 0.4)])))
        }
        return finish(root, k)
    }

    private static func finish(_ root: SCNNode, _ k: Int) -> SCNNode {
        let s = Float([1, 1.35, 1.8, 2.4][min(k, 3)])
        root.scale = SCNVector3(s, s, s)
        return root
    }

    /// 走行アニメ（体の上下動＋前後の揺れ）
    static func animateRun(_ n: SCNNode) {
        guard let body = n.childNode(withName: "body", recursively: false) else { return }
        let ph = Double.random(in: 0...0.3)
        let hop = SCNAction.sequence([.moveBy(x: 0, y: 0.06, z: 0, duration: 0.14), .moveBy(x: 0, y: -0.06, z: 0, duration: 0.14)])
        hop.timingMode = .easeInEaseOut
        body.runAction(.sequence([.wait(duration: ph), .repeatForever(.group([hop, .sequence([.rotateTo(x: 0, y: 0, z: 0.07, duration: 0.14), .rotateTo(x: 0, y: 0, z: -0.07, duration: 0.14)])]))]))
    }
}

/// 3Dモデルから UI 用サムネイルを生成（図鑑・進化パネル）
enum Thumbnails {
    private static var cache: [String: UIImage] = [:]
    private static let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)

    @MainActor
    static func image(_ e: Element, _ k: Int, size: CGFloat = 220) -> UIImage {
        let key = "\(e.rawValue)-\(k)-\(Int(size))"
        if let c = cache[key] { return c }
        let scene = SCNScene()
        let node = CreatureFactory.build(element: e, sizeClass: k)
        node.removeAllActions(); node.enumerateChildNodes { n, _ in n.removeAllActions() }
        if e != .none { node.eulerAngles.y = .pi - 0.5 } else { node.eulerAngles.y = 0.3 }
        scene.rootNode.addChildNode(node)
        let (mn, mx) = node.boundingBox
        let s = node.scale.x
        let h = (mx.y - mn.y) * s; let w = max(mx.x - mn.x, mx.z - mn.z) * s
        let cam = SCNNode(); cam.camera = SCNCamera(); cam.camera!.fieldOfView = 30
        let d = max(h, w) * 2.3 + 0.5
        cam.position = SCNVector3(0, (mn.y + mx.y) / 2 * s + d * 0.15, d); cam.look(at: SCNVector3(0, (mn.y + mx.y) / 2 * s, 0))
        scene.rootNode.addChildNode(cam)
        let l = SCNNode(); l.light = SCNLight(); l.light!.type = .directional; l.light!.intensity = 1100; l.eulerAngles = SCNVector3(-0.7, 0.5, 0); scene.rootNode.addChildNode(l)
        let a = SCNNode(); a.light = SCNLight(); a.light!.type = .ambient; a.light!.intensity = 600; scene.rootNode.addChildNode(a)
        scene.background.contents = UIColor.clear
        renderer.scene = scene; renderer.pointOfView = cam
        let img = renderer.snapshot(atTime: 0, with: CGSize(width: size, height: size), antialiasingMode: .multisampling4X)
        cache[key] = img
        return img
    }
}
