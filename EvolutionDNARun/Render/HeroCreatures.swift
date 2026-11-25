import SceneKit
import UIKit

/// 追加キャラ（既存と同じちびキャラ・トゥーン調）。前方は -Z。
/// 水: サメ→メガロドン / 植物: 恐竜→Tレックス / 闇: 影オオカミ→フェンリル
/// シークレット(宇宙): メカドラゴン / ユニーク(光): 聖剣ドラゴン
extension AnimalFactory {
    private static func scaleFor(_ k: Int) -> Float { [1, 1.35, 1.8, 2.4][min(k, 3)] }
    private static func done(_ root: SCNNode, _ k: Int) -> SCNNode {
        let s = scaleFor(k); root.scale = SCNVector3(s, s, s); return root
    }

    // MARK: 水：サメ
    static func shark(_ k: Int) -> SCNNode {
        let root = SCNNode(); root.name = "creature"
        let body = SCNNode(); body.name = "body"; root.addChildNode(body)
        let blue = Toon.mat(k >= 2 ? UIColor(red: 0.16, green: 0.36, blue: 0.85, alpha: 1) : UIColor(red: 0.3, green: 0.58, blue: 1, alpha: 1), rim: UIColor(red: 0.6, green: 0.95, blue: 1, alpha: 1), rimStrength: 0.7)
        let belly = Toon.mat(UIColor(red: 0.95, green: 0.98, blue: 1, alpha: 1))
        let tooth = Toon.mat(.white, rimStrength: 0, shiny: 0.9)
        body.addChildNode(Toon.sphere(0.32, blue, SCNVector3(0, 0.36, 0.05), scale: SCNVector3(0.95, 0.9, 1.35)))
        body.addChildNode(Toon.sphere(0.25, belly, SCNVector3(0, 0.27, -0.12), scale: SCNVector3(0.95, 0.75, 1.1)))
        let head = SCNNode(); head.name = "head"; head.position = SCNVector3(0, 0.5, -0.3); body.addChildNode(head)
        head.addChildNode(Toon.sphere(0.24, blue, SCNVector3Zero, scale: SCNVector3(1.05, 0.9, 1.1)))
        // 口とギザギザの歯
        head.addChildNode(Toon.sphere(0.12, Toon.mat(UIColor(red: 0.6, green: 0.1, blue: 0.2, alpha: 1)), SCNVector3(0, -0.11, -0.17), scale: SCNVector3(1.3, 0.45, 0.6)))
        for i in 0..<5 {
            let x = Float(i - 2) * 0.045
            head.addChildNode(Toon.cone(0.022, 0.06, tooth, SCNVector3(x, -0.07, -0.22), euler: SCNVector3(Float.pi, 0, 0)))
        }
        for s in [-1, 1] as [Float] {
            head.addChildNode(Toon.eye(0.08, at: SCNVector3(s * 0.12, 0.06, -0.17), iris: UIColor(red: 0.1, green: 0.5, blue: 1, alpha: 1)))
            // 胸びれ
            let fin = Toon.cone(0.08, 0.26 + CGFloat(k) * 0.04, blue, SCNVector3(s * 0.3, 0.25, -0.05), euler: SCNVector3(0, 0, s * 1.9))
            body.addChildNode(fin)
            body.addChildNode(Toon.sphere(0.08, blue, SCNVector3(s * 0.15, 0.08, 0.05)))
        }
        // 背びれ（後ろから見えるシルエット）
        body.addChildNode(Toon.cone(0.11 + CGFloat(k) * 0.02, 0.34 + CGFloat(k) * 0.08, blue, SCNVector3(0, 0.72, 0.08), euler: SCNVector3(-0.35, 0, 0)))
        // 尾びれ
        let tail = SCNNode(); tail.name = "tail"; tail.position = SCNVector3(0, 0.38, 0.45); body.addChildNode(tail)
        tail.addChildNode(Toon.cone(0.09, 0.3, blue, SCNVector3(0, 0.1, 0.08), euler: SCNVector3(-0.9, 0, 0)))
        tail.addChildNode(Toon.cone(0.07, 0.22, blue, SCNVector3(0, -0.06, 0.08), euler: SCNVector3(-2.3, 0, 0)))
        tail.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0.4, z: 0, duration: 0.2), .rotateTo(x: 0, y: -0.4, z: 0, duration: 0.2)])))
        if k >= 1 { // 傷跡と水流
            for s in [-1, 1] as [Float] { body.addChildNode(Toon.sphere(0.05, Mat.glow(UIColor(red: 0.5, green: 0.95, blue: 1, alpha: 1)), SCNVector3(s * 0.27, 0.42, 0.15), scale: SCNVector3(0.4, 1.5, 0.4))) }
        }
        if k >= 3 { // メガロドン王：王冠の背びれ＋渦
            let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.42, pipeRadius: 0.03)); ring.geometry!.materials = [Mat.glow(UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 0.8))]
            ring.position = SCNVector3(0, 0.3, 0.05); body.addChildNode(ring)
            ring.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 1.2)))
            body.addChildNode(Toon.cone(0.06, 0.18, Toon.mat(UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1), shiny: 0.9), SCNVector3(0, 0.95, 0.12), euler: SCNVector3(-0.35, 0, 0)))
        }
        return done(root, k)
    }

    // MARK: 植物：恐竜→Tレックス
    static func dino(_ k: Int) -> SCNNode {
        let root = SCNNode(); root.name = "creature"
        let body = SCNNode(); body.name = "body"; root.addChildNode(body)
        let green = Toon.mat(k >= 2 ? UIColor(red: 0.2, green: 0.62, blue: 0.25, alpha: 1) : UIColor(red: 0.35, green: 0.8, blue: 0.3, alpha: 1), rim: UIColor(red: 0.85, green: 1, blue: 0.5, alpha: 1), rimStrength: 0.6)
        let cream = Toon.mat(UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1))
        let leaf = Toon.mat(UIColor(red: 1, green: 0.55, blue: 0.2, alpha: 1), shiny: 0.6)
        body.addChildNode(Toon.sphere(0.3, green, SCNVector3(0, 0.34, 0.05), scale: SCNVector3(1, 0.95, 1.15)))
        body.addChildNode(Toon.sphere(0.21, cream, SCNVector3(0, 0.3, -0.12), scale: SCNVector3(1, 1.05, 0.75)))
        let head = SCNNode(); head.name = "head"; head.position = SCNVector3(0, 0.72, -0.18); body.addChildNode(head)
        head.addChildNode(Toon.sphere(0.27, green, SCNVector3Zero, scale: SCNVector3(1, 0.9, 1.1)))
        head.addChildNode(Toon.sphere(0.16, green, SCNVector3(0, -0.08, -0.22), scale: SCNVector3(1.1, 0.7, 1.1)))
        for i in 0..<4 { // 歯
            for s in [-1, 1] as [Float] { head.addChildNode(Toon.cone(0.018, 0.05, Toon.mat(.white, rimStrength: 0), SCNVector3(s * Float(0.04 + Double(i) * 0.03), -0.15, -0.33 + Float(i) * 0.03), euler: SCNVector3(Float.pi, 0, 0))) }
        }
        for s in [-1, 1] as [Float] {
            head.addChildNode(Toon.eye(0.085, at: SCNVector3(s * 0.12, 0.07, -0.18), iris: UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1)))
            head.addChildNode(Toon.sphere(0.04, green, SCNVector3(s * 0.12, 0.17, -0.14), scale: SCNVector3(1.5, 0.6, 1))) // 眉（キリッと）
            body.addChildNode(Toon.sphere(0.06, green, SCNVector3(s * 0.2, 0.42, -0.25), scale: SCNVector3(0.8, 1.4, 0.8))) // 小さな腕
            body.addChildNode(Toon.sphere(0.12, green, SCNVector3(s * 0.18, 0.1, 0.05), scale: SCNVector3(1, 0.9, 1.3)))  // 太い脚
        }
        // 背中のトゲ（葉っぱ色のプレート）
        let n = 3 + k
        for i in 0..<n {
            let t = Float(i) / Float(max(1, n - 1))
            let y = 0.95 - t * 0.5, z = -0.05 + t * 0.45
            let plate = SCNNode(geometry: SCNPyramid(width: 0.04, height: CGFloat(0.16 + Float(k) * 0.03), length: 0.14)); plate.geometry!.materials = [leaf]
            plate.position = SCNVector3(0, y, z); plate.eulerAngles.x = 0.3 + t * 0.8; body.addChildNode(plate)
        }
        // 太いしっぽ
        let tail = SCNNode(); tail.name = "tail"; tail.position = SCNVector3(0, 0.25, 0.32); body.addChildNode(tail)
        var p = tail
        for j in 0..<3 { let seg = Toon.sphere(CGFloat(0.14 - Float(j) * 0.035), green, SCNVector3(0, j == 0 ? 0 : -0.02, j == 0 ? 0 : 0.15)); p.addChildNode(seg); p = seg }
        tail.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0.3, z: 0, duration: 0.3), .rotateTo(x: 0, y: -0.3, z: 0, duration: 0.3)])))
        if k >= 2 { // 角
            head.addChildNode(Toon.cone(0.05, 0.18, cream, SCNVector3(0, 0.06, -0.3), euler: SCNVector3(-1.1, 0, 0)))
        }
        if k >= 3 { // Tレックス王：ツタの鎧と発光する葉
            for s in [-1, 1] as [Float] { body.addChildNode(Toon.sphere(0.07, Mat.glow(UIColor(red: 0.6, green: 1, blue: 0.3, alpha: 1)), SCNVector3(s * 0.28, 0.45, 0.05))) }
        }
        return done(root, k)
    }

    // MARK: 闇：影オオカミ→フェンリル
    static func wolf(_ k: Int) -> SCNNode {
        let root = SCNNode(); root.name = "creature"
        let body = SCNNode(); body.name = "body"; root.addChildNode(body)
        let fur = Toon.mat(UIColor(red: 0.28, green: 0.2, blue: 0.45, alpha: 1), rim: UIColor(red: 0.8, green: 0.5, blue: 1, alpha: 1), rimStrength: 0.9)
        let chest = Toon.mat(UIColor(red: 0.75, green: 0.7, blue: 0.9, alpha: 1))
        let glowEye = UIColor(red: 1, green: 0.25, blue: 0.4, alpha: 1)
        let flame = Mat.glow(UIColor(red: 0.75, green: 0.35, blue: 1, alpha: 0.9))
        body.addChildNode(Toon.sphere(0.3, fur, SCNVector3(0, 0.34, 0.05), scale: SCNVector3(0.95, 0.9, 1.25)))
        body.addChildNode(Toon.sphere(0.2, chest, SCNVector3(0, 0.36, -0.18), scale: SCNVector3(1, 1, 0.7)))
        let head = SCNNode(); head.name = "head"; head.position = SCNVector3(0, 0.68, -0.22); body.addChildNode(head)
        head.addChildNode(Toon.sphere(0.24, fur, SCNVector3Zero))
        head.addChildNode(Toon.sphere(0.12, chest, SCNVector3(0, -0.07, -0.2), scale: SCNVector3(1, 0.8, 1.3)))
        head.addChildNode(Toon.sphere(0.035, Toon.mat(.black, shiny: 1), SCNVector3(0, -0.02, -0.35)))
        for s in [-1, 1] as [Float] {
            head.addChildNode(Toon.eye(0.075, at: SCNVector3(s * 0.11, 0.05, -0.18), iris: glowEye))
            head.addChildNode(Toon.cone(0.08, 0.24 + CGFloat(k) * 0.04, fur, SCNVector3(s * 0.14, 0.24, 0.02), euler: SCNVector3(0.1, 0, -s * 0.3))) // 耳
            for z in [-0.14, 0.2] as [Float] { body.addChildNode(Toon.sphere(0.09, fur, SCNVector3(s * 0.16, 0.09, z), scale: SCNVector3(1, 1, 1.2))) }
        }
        // 闇の炎のたてがみ（背中）
        for i in 0..<(3 + k) {
            let t = Float(i) / Float(2 + k)
            let c = Toon.cone(0.07, CGFloat(0.2 + Float(k) * 0.05), flame, SCNVector3(Float(i % 2 == 0 ? -0.05 : 0.05), 0.65 - t * 0.2, -0.05 + t * 0.4), euler: SCNVector3(0.5 + t, 0, 0))
            body.addChildNode(c)
            c.runAction(.repeatForever(.sequence([.scale(to: 1.2, duration: 0.2 + Double(i) * 0.03), .scale(to: 0.85, duration: 0.2)])))
        }
        // ふさふさのしっぽ
        let tail = SCNNode(); tail.name = "tail"; tail.position = SCNVector3(0, 0.42, 0.38); body.addChildNode(tail)
        tail.addChildNode(Toon.sphere(0.13, fur, SCNVector3(0, 0.08, 0.08), scale: SCNVector3(0.8, 0.8, 1.6)))
        tail.addChildNode(Toon.sphere(0.07, flame, SCNVector3(0, 0.12, 0.28)))
        tail.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0.45, z: 0, duration: 0.25), .rotateTo(x: 0, y: -0.45, z: 0, duration: 0.25)])))
        if k >= 2 { // 鎖の首輪（フェンリル）
            let collar = SCNNode(geometry: SCNTorus(ringRadius: 0.2, pipeRadius: 0.035)); collar.geometry!.materials = [Toon.mat(UIColor(red: 0.75, green: 0.75, blue: 0.85, alpha: 1), shiny: 1)]
            collar.position = SCNVector3(0, 0.55, -0.2); collar.eulerAngles.x = 1.2; body.addChildNode(collar)
        }
        if k >= 3 { // 闇の三日月
            let moon = Toon.sphere(0.09, Mat.glow(UIColor(red: 1, green: 0.9, blue: 0.5, alpha: 1)), SCNVector3(0, 0.3, -0.05))
            head.addChildNode(moon)
        }
        return done(root, k)
    }

    // MARK: シークレット（宇宙）：ギャラクシー・メカドラゴン
    static func mecha(_ k: Int) -> SCNNode {
        let root = SCNNode(); root.name = "creature"
        let body = SCNNode(); body.name = "body"; root.addChildNode(body)
        let metal = Toon.mat(UIColor(red: 0.55, green: 0.6, blue: 0.75, alpha: 1), rim: UIColor(red: 0.6, green: 0.9, blue: 1, alpha: 1), rimStrength: 1.0, shiny: 1)
        let plate = Toon.mat(UIColor(red: 0.2, green: 0.15, blue: 0.45, alpha: 1), rim: UIColor(red: 1, green: 0.5, blue: 1, alpha: 1), rimStrength: 0.9, shiny: 1)
        let gold = Toon.mat(UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1), shiny: 1)
        let neon = Mat.glow(UIColor(red: 0.3, green: 1, blue: 1, alpha: 1))
        let pink = Mat.glow(UIColor(red: 1, green: 0.4, blue: 0.9, alpha: 1))
        let torso = SCNNode(geometry: SCNBox(width: 0.5, height: 0.42, length: 0.6, chamferRadius: 0.12)); torso.geometry!.materials = [plate]
        torso.position = SCNVector3(0, 0.36, 0.05); body.addChildNode(torso)
        body.addChildNode(Toon.sphere(0.09, neon, SCNVector3(0, 0.4, -0.26)))   // 胸のリアクター
        let head = SCNNode(); head.name = "head"; head.position = SCNVector3(0, 0.74, -0.18); body.addChildNode(head)
        let hb = SCNNode(geometry: SCNBox(width: 0.42, height: 0.34, length: 0.42, chamferRadius: 0.13)); hb.geometry!.materials = [metal]; head.addChildNode(hb)
        let visor = SCNNode(geometry: SCNBox(width: 0.36, height: 0.1, length: 0.04, chamferRadius: 0.04)); visor.geometry!.materials = [neon]
        visor.position = SCNVector3(0, 0.04, -0.21); head.addChildNode(visor)
        for s in [-1, 1] as [Float] {
            head.addChildNode(Toon.sphere(0.05, Mat.glow(.white), SCNVector3(s * 0.09, 0.04, -0.23)))
            head.addChildNode(Toon.cone(0.05, 0.28, gold, SCNVector3(s * 0.13, 0.22, 0.05), euler: SCNVector3(0.7, 0, -s * 0.3)))  // アンテナ角
            for z in [-0.12, 0.22] as [Float] {
                let leg = SCNNode(geometry: SCNBox(width: 0.14, height: 0.2, length: 0.16, chamferRadius: 0.05)); leg.geometry!.materials = [metal]
                leg.position = SCNVector3(s * 0.2, 0.1, z); body.addChildNode(leg)
            }
            // ブースター
            let boost = SCNNode(geometry: SCNCylinder(radius: 0.07, height: 0.22)); boost.geometry!.materials = [metal]
            boost.position = SCNVector3(s * 0.15, 0.5, 0.36); boost.eulerAngles.x = .pi / 2; body.addChildNode(boost)
            let fire = Toon.cone(0.06, 0.25, k % 2 == 0 ? neon : pink, SCNVector3(s * 0.15, 0.5, 0.55), euler: SCNVector3(-Float.pi / 2, 0, 0))
            body.addChildNode(fire)
            fire.runAction(.repeatForever(.sequence([SCNAction.scale(to: 1.4, duration: 0.08), SCNAction.scale(to: 0.8, duration: 0.08)])))
            // 光の翼
            let span = Float([0.35, 0.5, 0.65, 0.85][min(k, 3)])
            let wing = SCNNode(geometry: SCNBox(width: CGFloat(span), height: 0.02, length: 0.22, chamferRadius: 0.01)); wing.geometry!.materials = [k >= 2 ? pink : neon]
            wing.position = SCNVector3(s * (0.25 + span / 2), 0.6, 0.1); wing.eulerAngles.z = s * 0.45; body.addChildNode(wing)
        }
        // 星のリング
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.48, pipeRadius: 0.02)); ring.geometry!.materials = [gold]
        ring.position = SCNVector3(0, 0.45, 0.05); ring.eulerAngles.x = 0.3; body.addChildNode(ring)
        ring.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 2)))
        if k >= 3 { body.addChildNode(Toon.sphere(0.12, pink, SCNVector3(0, 1.08, -0.1))) }
        return done(root, k)
    }

    // MARK: ユニーク（光）：聖剣ドラゴン〈エクスカリバー〉
    static func holyDragon(_ k: Int) -> SCNNode {
        let root = dragon(max(2, k))
        guard let body = root.childNode(withName: "body", recursively: false) else { return root }
        // 白銀の鎧色に塗り替え
        let silver = Toon.mat(UIColor(red: 0.95, green: 0.95, blue: 1, alpha: 1), rim: UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1), rimStrength: 1.1, shiny: 1)
        body.enumerateHierarchy { n, _ in
            guard let g = n.geometry, let c = g.firstMaterial?.diffuse.contents as? UIColor else { return }
            var r: CGFloat = 0, gg: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0; c.getRed(&r, green: &gg, blue: &b, alpha: &a)
            if r > 0.85 && gg < 0.5 { g.materials = [silver] }   // 赤い肌→白銀
        }
        let gold = Toon.mat(UIColor(red: 1, green: 0.82, blue: 0.3, alpha: 1), shiny: 1)
        // 背中の聖剣
        let blade = SCNNode(geometry: SCNBox(width: 0.08, height: 0.75, length: 0.03, chamferRadius: 0.01)); blade.geometry!.materials = [Mat.glow(UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 1))]
        blade.position = SCNVector3(0, 0.95, 0.28); blade.eulerAngles.x = -0.25; body.addChildNode(blade)
        let guardN = SCNNode(geometry: SCNBox(width: 0.3, height: 0.05, length: 0.06, chamferRadius: 0.02)); guardN.geometry!.materials = [gold]
        guardN.position = SCNVector3(0, 0.6, 0.36); guardN.eulerAngles.x = -0.25; body.addChildNode(guardN)
        body.addChildNode(Toon.sphere(0.05, Mat.glow(UIColor(red: 0.3, green: 0.6, blue: 1, alpha: 1)), SCNVector3(0, 0.6, 0.39)))
        // 天使の輪
        let halo = SCNNode(geometry: SCNTorus(ringRadius: 0.2, pipeRadius: 0.025)); halo.geometry!.materials = [Mat.glow(UIColor(red: 1, green: 0.9, blue: 0.4, alpha: 1))]
        if let head = body.childNode(withName: "head", recursively: false) { halo.position = SCNVector3(0, 0.38, 0.05); head.addChildNode(halo) }
        halo.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.04, z: 0, duration: 0.6), .moveBy(x: 0, y: -0.04, z: 0, duration: 0.6)])))
        return root
    }
}
