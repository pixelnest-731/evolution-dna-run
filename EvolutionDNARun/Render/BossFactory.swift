import SceneKit
import UIKit

/// AI社員04: 参考画像 Bosses.png 準拠の大型ボス（プレイヤー側 = +Z を向く。足元 y=0）
/// 0 クリスタルゴリラ / 1 溶岩ドラゴン / 2 王冠クジラ / 3 クリスタル岩ガメ / 4 クラーケン / 5 光の蛾
enum BossKind: Int, CaseIterable, Codable {
    case gorilla, lavaDragon, whale, rockTurtle, kraken, moth

    var name: String {
        switch self {
        case .gorilla: return "Gorrumble"
        case .lavaDragon: return "Magmaw"
        case .whale: return "Tidalord"
        case .rockTurtle: return "Crystortoise"
        case .kraken: return "Krakulus"
        case .moth: return "Lumimoth"
        }
    }
    /// プレイヤーが使える3属性で相性を設定
    var weakness: Element {
        switch self {
        case .gorilla, .moth: return .fire
        case .lavaDragon, .rockTurtle: return .ice
        case .whale, .kraken: return .thunder
        }
    }
    var resist: Element {
        switch self {
        case .gorilla, .kraken: return .ice
        case .lavaDragon, .whale: return .fire
        case .rockTurtle, .moth: return .thunder
        }
    }
}

enum BossFactory {
    static func build(_ kind: BossKind) -> SCNNode {
        let n: SCNNode
        switch kind {
        case .gorilla: n = gorilla()
        case .lavaDragon: n = lavaDragon()
        case .whale: n = whale()
        case .rockTurtle: n = rockTurtle()
        case .kraken: n = kraken()
        case .moth: n = moth()
        }
        n.name = "boss"
        return n
    }

    // MARK: 共通パーツ
    static func glowLine(_ c: UIColor, from a: SCNVector3, to b: SCNVector3, r: CGFloat = 0.05) -> SCNNode {
        let d = SCNVector3(b.x - a.x, b.y - a.y, b.z - a.z)
        let len = sqrt(d.x * d.x + d.y * d.y + d.z * d.z)
        let n = SCNNode(geometry: SCNCapsule(capRadius: r, height: CGFloat(len) + r * 2)); n.geometry!.materials = [Mat.glow(c)]
        n.position = SCNVector3((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
        n.look(at: b, up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
        return n
    }
    static func crystalCluster(_ c: UIColor, size: Float) -> SCNNode {
        let n = WorldJungle.crystal(c, h: size)
        n.enumerateHierarchy { k, _ in k.geometry?.materials = [Mat.jelly(c, alpha: 0.82)] }
        return n
    }
    /// 光る怒り目（+Z向き）
    static func angryEye(_ r: CGFloat, glow: UIColor, at p: SCNVector3, side: Float) -> SCNNode {
        let e = Toon.sphere(r, Mat.glow(glow), p, scale: SCNVector3(1, 0.7, 0.6))
        let pupil = Toon.sphere(r * 0.35, Mat.glow(.white), SCNVector3(0, 0, Float(r) * 0.8))
        e.addChildNode(pupil)
        e.eulerAngles.z = side * 0.25
        let halo = SCNNode(geometry: SCNPlane(width: r * 5, height: r * 5))
        let hm = SCNMaterial(); hm.lightingModel = .constant; hm.diffuse.contents = FX.softDot; hm.multiply.contents = glow; hm.blendMode = .add; hm.writesToDepthBuffer = false
        halo.geometry!.materials = [hm]; halo.position = SCNVector3(0, 0, Float(r) * 0.6); e.addChildNode(halo)
        return e
    }
    static func teeth(width: Float, count: Int, at p: SCNVector3, down: Bool) -> SCNNode {
        let n = SCNNode(); n.position = p
        let m = Toon.mat(UIColor(red: 1, green: 0.98, blue: 0.9, alpha: 1), rimStrength: 0.2)
        for i in 0..<count {
            let x = (Float(i) / Float(max(1, count - 1)) - 0.5) * width
            let big = i == 0 || i == count - 1
            n.addChildNode(Toon.cone(big ? 0.1 : 0.06, big ? 0.32 : 0.18, m, SCNVector3(x, 0, 0), euler: SCNVector3(down ? Float.pi : 0, 0, 0)))
        }
        return n
    }
    static func mouth(width: CGFloat, height: CGFloat, at p: SCNVector3, inner: UIColor) -> SCNNode {
        let m = Toon.sphere(1, Toon.mat(inner, rimStrength: 0), p, scale: SCNVector3(Float(width), Float(height), 0.35))
        m.name = "mouth"
        let tongue = Toon.sphere(0.4, Toon.mat(UIColor(red: 1, green: 0.45, blue: 0.6, alpha: 1)), SCNVector3(0, -0.45, 0.4), scale: SCNVector3(1, 0.4, 0.8))
        m.addChildNode(tongue)
        return m
    }
    static func breathe(_ n: SCNNode, amount: CGFloat = 0.04, period: Double = 1.2) {
        let a = SCNAction.sequence([.scale(by: 1 + amount, duration: period), .scale(by: 1 / (1 + amount), duration: period)])
        a.timingMode = .easeInEaseOut
        n.runAction(.repeatForever(a))
    }

    // MARK: 0 クリスタルゴリラ（紫の毛並み、発光する亀裂、肩の紫クリスタル、迫る巨大な手）
    static func gorilla() -> SCNNode {
        let root = SCNNode(); let body = SCNNode(); root.addChildNode(body)
        let fur = Toon.mat(UIColor(red: 0.34, green: 0.24, blue: 0.5, alpha: 1), rim: UIColor(red: 0.8, green: 0.5, blue: 1, alpha: 1), rimStrength: 0.9)
        let skin = Toon.mat(UIColor(red: 0.5, green: 0.38, blue: 0.62, alpha: 1), rim: UIColor(red: 0.9, green: 0.7, blue: 1, alpha: 1), rimStrength: 0.5)
        let crack = UIColor(red: 1, green: 0.35, blue: 1, alpha: 1)
        body.addChildNode(Toon.sphere(1.9, fur, SCNVector3(0, 2.6, -0.3), scale: SCNVector3(1.25, 1.1, 0.95)))   // 胴
        body.addChildNode(Toon.sphere(1.3, skin, SCNVector3(0, 2.4, 0.9), scale: SCNVector3(1.1, 1.05, 0.55)))   // 胸
        // 毛のトゲ（シルエット）
        for i in 0..<14 {
            let a = Float(i) / 13 * .pi - .pi / 2
            body.addChildNode(Toon.cone(0.3, 0.8, fur, SCNVector3(sin(a) * 2.2, 3.6 + cos(a) * 0.9, -0.6), euler: SCNVector3(-0.3, 0, -a * 0.9)))
        }
        // 頭
        let head = SCNNode(); head.position = SCNVector3(0, 4.6, 0.6); body.addChildNode(head)
        head.addChildNode(Toon.sphere(1.05, fur, SCNVector3Zero, scale: SCNVector3(1.1, 1, 1)))
        head.addChildNode(Toon.sphere(0.75, skin, SCNVector3(0, -0.35, 0.65), scale: SCNVector3(1.2, 0.85, 0.7)))  // 口吻
        head.addChildNode(Toon.sphere(0.5, fur, SCNVector3(0, 0.38, 0.7), scale: SCNVector3(2.0, 0.45, 0.6)))      // 眉骨
        for s in [-1, 1] as [Float] { head.addChildNode(angryEye(0.17, glow: crack, at: SCNVector3(s * 0.38, 0.12, 0.92), side: s)) }
        let mth = mouth(width: 0.48, height: 0.38, at: SCNVector3(0, -0.5, 1.05), inner: UIColor(red: 0.35, green: 0.08, blue: 0.2, alpha: 1)); head.addChildNode(mth)
        head.addChildNode(teeth(width: 0.75, count: 5, at: SCNVector3(0, -0.2, 1.2), down: true))
        head.addChildNode(teeth(width: 0.6, count: 4, at: SCNVector3(0, -0.82, 1.15), down: false))
        // 腕（左腕は前に伸ばして掴みかかる）
        for s in [-1, 1] as [Float] {
            let shoulder = SCNNode(); shoulder.position = SCNVector3(s * 2.1, 3.4, 0); body.addChildNode(shoulder)
            let arm = Toon.sphere(0.75, fur, SCNVector3(s * 0.4, -1.0, s < 0 ? 1.0 : 0.2), scale: SCNVector3(0.9, 1.6, 0.9))
            shoulder.addChildNode(arm)
            let fist = SCNNode(); fist.position = SCNVector3(s * 0.6, s < 0 ? -1.0 : -2.6, s < 0 ? 2.4 : 0.8); shoulder.addChildNode(fist)
            fist.addChildNode(Toon.sphere(0.75, skin, SCNVector3Zero, scale: SCNVector3(1.15, 0.9, 0.9)))
            for f in 0..<4 { fist.addChildNode(Toon.sphere(0.24, skin, SCNVector3((Float(f) - 1.5) * 0.33, -0.15, 0.62))) }
            shoulder.addChildNode(crystalCluster(UIColor(red: 0.8, green: 0.5, blue: 1, alpha: 1), size: 1.3))
            if s < 0 { shoulder.runAction(.repeatForever(.sequence([.rotateTo(x: -0.25, y: 0, z: 0, duration: 1.0), .rotateTo(x: 0.1, y: 0, z: 0, duration: 1.0)]))) }
        }
        // 背中のクリスタルと発光する亀裂
        for (x, y) in [(-1.0, 4.2), (1.1, 4.0), (0.0, 4.5)] as [(Float, Float)] {
            let c = crystalCluster(UIColor(red: 0.75, green: 0.45, blue: 1, alpha: 1), size: 1.4); c.position = SCNVector3(x, y, -1.2); c.eulerAngles.x = -0.4; body.addChildNode(c)
        }
        for (a, b) in [((-0.6, 3.4), (-0.2, 2.6)), ((-0.2, 2.6), (-0.5, 1.8)), ((0.7, 3.0), (0.3, 2.2)), ((0.3, 2.2), (0.6, 1.5))] as [((Float, Float), (Float, Float))] {
            body.addChildNode(glowLine(crack, from: SCNVector3(a.0, a.1, 1.55), to: SCNVector3(b.0, b.1, 1.5)))
        }
        for s in [-1, 1] as [Float] { body.addChildNode(Toon.sphere(0.8, fur, SCNVector3(s * 1.0, 0.6, 0), scale: SCNVector3(1, 0.8, 1.2))) }
        breathe(body)
        return root
    }

    // MARK: 1 溶岩ドラゴン（黒赤の体に溶岩の亀裂、大翼、角、火炎ブレス）
    static func lavaDragon() -> SCNNode {
        let root = SCNNode(); let body = SCNNode(); root.addChildNode(body)
        let rock = Toon.mat(UIColor(red: 0.45, green: 0.12, blue: 0.08, alpha: 1), rim: UIColor(red: 1, green: 0.5, blue: 0.1, alpha: 1), rimStrength: 1.0)
        let belly = Toon.mat(UIColor(red: 0.85, green: 0.45, blue: 0.2, alpha: 1), rim: UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1))
        let horn = Toon.mat(UIColor(red: 0.3, green: 0.22, blue: 0.2, alpha: 1), shiny: 0.8)
        let lava = UIColor(red: 1, green: 0.55, blue: 0.1, alpha: 1)
        body.addChildNode(Toon.sphere(1.6, rock, SCNVector3(0, 2.0, -0.5), scale: SCNVector3(1.1, 1, 1.3)))
        body.addChildNode(Toon.sphere(1.1, belly, SCNVector3(0, 2.0, 0.5), scale: SCNVector3(1, 1.15, 0.6)))
        for i in 0..<5 { body.addChildNode(glowLine(UIColor(red: 1, green: 0.85, blue: 0.4, alpha: 1), from: SCNVector3(-0.8, 1.2 + Float(i) * 0.35, 1.02), to: SCNVector3(0.8, 1.2 + Float(i) * 0.35, 1.02), r: 0.025)) }
        // 首と頭
        let neck = SCNNode(); neck.position = SCNVector3(0, 3.2, 0.3); body.addChildNode(neck)
        for j in 0..<4 { neck.addChildNode(Toon.sphere(CGFloat(0.65 - Float(j) * 0.05), rock, SCNVector3(0, Float(j) * 0.45, Float(j) * 0.18))) }
        let head = SCNNode(); head.position = SCNVector3(0, 2.0, 0.9); neck.addChildNode(head)
        head.addChildNode(Toon.sphere(0.75, rock, SCNVector3Zero, scale: SCNVector3(1, 0.85, 1.1)))
        head.addChildNode(Toon.sphere(0.55, rock, SCNVector3(0, -0.1, 0.75), scale: SCNVector3(0.95, 0.6, 1.2)))
        let jaw = Toon.sphere(0.45, belly, SCNVector3(0, -0.5, 0.65), scale: SCNVector3(0.9, 0.35, 1.2)); jaw.name = "jaw"; head.addChildNode(jaw)
        head.addChildNode(teeth(width: 0.7, count: 5, at: SCNVector3(0, -0.32, 1.25), down: true))
        for s in [-1, 1] as [Float] {
            head.addChildNode(angryEye(0.13, glow: UIColor(red: 1, green: 0.85, blue: 0.2, alpha: 1), at: SCNVector3(s * 0.38, 0.22, 0.62), side: s))
            head.addChildNode(Toon.cone(0.2, 1.1, horn, SCNVector3(s * 0.45, 0.55, -0.3), euler: SCNVector3(-1.0, 0, -s * 0.5)))
            head.addChildNode(Toon.cone(0.12, 0.6, horn, SCNVector3(s * 0.65, 0.1, -0.2), euler: SCNVector3(-1.2, 0, -s * 1.1)))
        }
        // 火炎ブレス
        let fire = SCNParticleSystem(); fire.particleImage = FX.softDot; fire.blendMode = .additive; fire.birthRate = 160
        fire.particleLifeSpan = 0.6; fire.particleVelocity = 7; fire.spreadingAngle = 14; fire.particleSize = 0.5; fire.particleSizeVariation = 0.3
        fire.particleColor = UIColor(red: 1, green: 0.6, blue: 0.15, alpha: 1); fire.particleColorVariation = SCNVector4(0.05, 0.2, 0, 0)
        fire.emittingDirection = SCNVector3(0, -0.35, 1)
        let fn = SCNNode(); fn.position = SCNVector3(0, -0.35, 1.3); fn.addParticleSystem(fire); head.addChildNode(fn)
        fn.runAction(.repeatForever(.sequence([.run { n in n.particleSystems?.first?.birthRate = 160 }, .wait(duration: 1.0), .run { n in n.particleSystems?.first?.birthRate = 0 }, .wait(duration: 1.4)])))
        // 大翼
        let memb = Toon.mat(UIColor(red: 0.85, green: 0.3, blue: 0.12, alpha: 1), rim: lava, rimStrength: 1.2); memb.isDoubleSided = true
        for s in [-1, 1] as [Float] {
            let pivot = SCNNode(); pivot.position = SCNVector3(s * 1.2, 3.2, -0.6); body.addChildNode(pivot)
            let p = UIBezierPath(); p.move(to: .zero)
            p.addLine(to: CGPoint(x: 2.2, y: 2.4)); p.addLine(to: CGPoint(x: 4.2, y: 1.6))
            p.addQuadCurve(to: CGPoint(x: 3.4, y: -0.6), controlPoint: CGPoint(x: 3.6, y: 0.4))
            p.addQuadCurve(to: CGPoint(x: 2.2, y: -0.4), controlPoint: CGPoint(x: 2.8, y: 0.1))
            p.addQuadCurve(to: CGPoint(x: 1.0, y: -0.8), controlPoint: CGPoint(x: 1.6, y: -0.2))
            p.close(); p.flatness = 0.01
            let w = SCNNode(geometry: SCNShape(path: p, extrusionDepth: 0.06)); w.geometry!.materials = [memb]
            w.scale = SCNVector3(s, 1, 1); w.eulerAngles.y = s * 0.35; pivot.addChildNode(w)
            for (a, b) in [((0, 0), (2.2, 2.4)), ((2.2, 2.4), (4.2, 1.6)), ((2.2, 2.4), (3.4, -0.6)), ((2.2, 2.4), (2.2, -0.4))] as [((Float, Float), (Float, Float))] {
                let bone = glowLine(UIColor(red: 0.3, green: 0.1, blue: 0.08, alpha: 1), from: SCNVector3(a.0 * s, a.1, 0.05), to: SCNVector3(b.0 * s, b.1, 0.05), r: 0.07)
                bone.geometry!.materials = [horn]; bone.eulerAngles.y += 0; pivot.addChildNode(bone)
            }
            pivot.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0, z: CGFloat(s) * 0.25, duration: 0.8), .rotateTo(x: 0, y: 0, z: CGFloat(-s) * 0.1, duration: 0.8)])))
        }
        // 溶岩の亀裂（背・脚）
        for (a, b) in [((-1.2, 2.6), (-0.6, 1.6)), ((1.1, 2.4), (0.5, 1.4)), ((-0.9, 1.4), (-1.3, 0.6)), ((1.0, 1.2), (1.4, 0.5))] as [((Float, Float), (Float, Float))] {
            body.addChildNode(glowLine(lava, from: SCNVector3(a.0, a.1, 0.6), to: SCNVector3(b.0, b.1, 0.55), r: 0.06))
        }
        for s in [-1, 1] as [Float] { body.addChildNode(Toon.sphere(0.6, rock, SCNVector3(s * 1.0, 0.55, 0.5), scale: SCNVector3(1, 0.9, 1.3))) }
        let tail = SCNNode(); tail.position = SCNVector3(0, 1.2, -2.2); body.addChildNode(tail)
        for j in 0..<5 { tail.addChildNode(Toon.sphere(CGFloat(0.55 - Float(j) * 0.09), rock, SCNVector3(Float(j) * 0.45, -Float(j) * 0.1, -Float(j) * 0.4))) }
        breathe(body, amount: 0.03)
        return root
    }

    // MARK: 2 王冠クジラ（紺と白、金のヒレ冠、水しぶき）
    static func whale() -> SCNNode {
        let root = SCNNode(); let body = SCNNode(); body.position.y = 2.2; root.addChildNode(body)
        let navy = Toon.mat(UIColor(red: 0.12, green: 0.28, blue: 0.65, alpha: 1), rim: UIColor(red: 0.4, green: 0.9, blue: 1, alpha: 1), rimStrength: 0.9, shiny: 0.7)
        let white = Toon.mat(UIColor(red: 0.95, green: 0.97, blue: 1, alpha: 1))
        let gold = Toon.mat(UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1), rim: UIColor(red: 1, green: 1, blue: 0.7, alpha: 1), shiny: 1)
        body.addChildNode(Toon.sphere(1.8, navy, SCNVector3(0, 0, -0.6), scale: SCNVector3(1.15, 0.95, 1.7)))
        body.addChildNode(Toon.sphere(1.5, white, SCNVector3(0, -0.55, 0.2), scale: SCNVector3(1.1, 0.6, 1.5)))
        // 口（大きく開いた上顎・下顎）
        let upper = Toon.sphere(1.3, navy, SCNVector3(0, 0.25, 1.6), scale: SCNVector3(1.1, 0.5, 0.9)); body.addChildNode(upper)
        let lower = Toon.sphere(1.2, white, SCNVector3(0, -0.85, 1.45), scale: SCNVector3(1.05, 0.4, 0.95)); lower.name = "jaw"; body.addChildNode(lower)
        body.addChildNode(mouth(width: 0.95, height: 0.42, at: SCNVector3(0, -0.35, 1.95), inner: UIColor(red: 0.55, green: 0.15, blue: 0.3, alpha: 1)))
        body.addChildNode(teeth(width: 1.4, count: 7, at: SCNVector3(0, -0.05, 2.45), down: true))
        for s in [-1, 1] as [Float] {
            body.addChildNode(angryEye(0.16, glow: UIColor(red: 0.4, green: 1, blue: 1, alpha: 1), at: SCNVector3(s * 1.15, 0.45, 1.3), side: s))
            body.addChildNode(Toon.sphere(0.5, navy, SCNVector3(s * 1.9, -0.5, 0.4), scale: SCNVector3(1.6, 0.25, 0.8)))  // 胸ビレ
        }
        // 金の王冠ヒレ
        for i in 0..<6 {
            let z = 1.0 - Float(i) * 0.6
            body.addChildNode(Toon.cone(0.28, CGFloat(1.2 - Float(i) * 0.1), gold, SCNVector3(0, 1.45 - Float(i) * 0.05, z), euler: SCNVector3(-0.8, 0, 0)))
        }
        for s in [-1, 1] as [Float] {
            for i in 0..<3 { body.addChildNode(Toon.cone(0.18, 0.8, gold, SCNVector3(s * 0.9, 1.1, 1.0 - Float(i) * 0.7), euler: SCNVector3(-0.7, 0, -s * 0.6))) }
        }
        // 尾ビレ
        let tail = SCNNode(); tail.position = SCNVector3(0, 0.4, -3.4); body.addChildNode(tail)
        tail.addChildNode(Toon.sphere(0.55, navy, SCNVector3Zero, scale: SCNVector3(1, 0.8, 1.5)))
        for s in [-1, 1] as [Float] { tail.addChildNode(Toon.sphere(0.6, navy, SCNVector3(s * 0.8, 0.5, -0.4), scale: SCNVector3(1.6, 0.2, 0.7))) }
        tail.runAction(.repeatForever(.sequence([.rotateTo(x: 0.35, y: 0, z: 0, duration: 0.9), .rotateTo(x: -0.25, y: 0, z: 0, duration: 0.9)])))
        // 水の渦としぶき
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 2.8, pipeRadius: 0.35)); ring.geometry!.materials = [Mat.jelly(UIColor(red: 0.4, green: 0.85, blue: 1, alpha: 1), alpha: 0.6)]
        ring.position = SCNVector3(0, 0.2, 0); ring.scale = SCNVector3(1, 0.5, 1.3); root.addChildNode(ring)
        ring.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 3)))
        let spray = SCNParticleSystem(); spray.particleImage = FX.softDot; spray.birthRate = 60; spray.particleLifeSpan = 1.2
        spray.particleVelocity = 4; spray.spreadingAngle = 30; spray.particleSize = 0.3; spray.particleColor = UIColor(white: 1, alpha: 0.8)
        spray.isAffectedByGravity = true; spray.emitterShape = SCNTorus(ringRadius: 2.6, pipeRadius: 0.2)
        let sn = SCNNode(); sn.position.y = 0.3; sn.addParticleSystem(spray); root.addChildNode(sn)
        body.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.5, z: 0, duration: 1.3), .moveBy(x: 0, y: -0.5, z: 0, duration: 1.3)])))
        return root
    }

    // MARK: 3 クリスタル岩ガメ（金の継ぎ目の岩甲羅、青いクリスタル、光る青い目）
    static func rockTurtle() -> SCNNode {
        let root = SCNNode(); let body = SCNNode(); root.addChildNode(body)
        let stone = Toon.mat(UIColor(red: 0.72, green: 0.70, blue: 0.68, alpha: 1), rim: UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 1), rimStrength: 0.4)
        let gold = Toon.mat(UIColor(red: 0.95, green: 0.75, blue: 0.25, alpha: 1), shiny: 1)
        let ice = UIColor(red: 0.55, green: 0.85, blue: 1, alpha: 1)
        // 甲羅（六角プレートの集合）
        let shell = SCNNode(); shell.position = SCNVector3(0, 2.0, -0.4); body.addChildNode(shell)
        shell.addChildNode(Toon.sphere(2.4, gold, SCNVector3Zero, scale: SCNVector3(1.1, 0.75, 1.15)))
        let golden = Float.pi * (3 - sqrt(5))
        for i in 0..<26 {
            let y = 1 - Float(i) / 25 * 1.1; let rr = sqrt(max(0, 1 - y * y)); let th = golden * Float(i)
            let dir = SCNVector3(cos(th) * rr, y, sin(th) * rr)
            let plate = SCNNode(geometry: SCNCylinder(radius: 0.55, height: 0.35)); (plate.geometry as! SCNCylinder).radialSegmentCount = 6
            plate.geometry!.materials = [stone]
            plate.position = SCNVector3(dir.x * 2.55, dir.y * 1.75, dir.z * 2.6)
            plate.look(at: SCNVector3(dir.x * 6, dir.y * 6, dir.z * 6), up: SCNVector3(0, 1, 0), localFront: SCNVector3(0, 1, 0))
            shell.addChildNode(plate)
        }
        for (x, z, h) in [(0.0, 0.0, 1.8), (-1.0, -0.6, 1.3), (1.1, -0.3, 1.4), (0.3, -1.3, 1.1), (-0.5, 0.7, 1.0)] as [(Float, Float, Float)] {
            let c = crystalCluster(ice, size: h); c.position = SCNVector3(x, 1.6, z); shell.addChildNode(c)
        }
        // 頭
        let head = SCNNode(); head.position = SCNVector3(0, 1.8, 2.3); body.addChildNode(head)
        head.addChildNode(Toon.sphere(0.95, stone, SCNVector3Zero, scale: SCNVector3(1.05, 0.85, 1.1)))
        head.addChildNode(Toon.sphere(0.55, stone, SCNVector3(0, 0.45, -0.1), scale: SCNVector3(1.6, 0.6, 1.2)))
        let jaw = Toon.sphere(0.75, stone, SCNVector3(0, -0.5, 0.35), scale: SCNVector3(1, 0.45, 1)); jaw.name = "jaw"; head.addChildNode(jaw)
        head.addChildNode(mouth(width: 0.62, height: 0.28, at: SCNVector3(0, -0.25, 0.75), inner: UIColor(red: 0.6, green: 0.2, blue: 0.3, alpha: 1)))
        head.addChildNode(teeth(width: 0.9, count: 6, at: SCNVector3(0, -0.02, 1.0), down: true))
        for s in [-1, 1] as [Float] { head.addChildNode(angryEye(0.15, glow: UIColor(red: 0.3, green: 0.85, blue: 1, alpha: 1), at: SCNVector3(s * 0.42, 0.25, 0.85), side: s)) }
        // 金の亀裂（頭・脚）
        head.addChildNode(glowLine(UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), from: SCNVector3(-0.5, 0.6, 0.7), to: SCNVector3(-0.1, 0.1, 0.95), r: 0.04))
        for (x, z) in [(-1.8, 1.4), (1.8, 1.4), (-1.8, -1.6), (1.8, -1.6)] as [(Float, Float)] {
            let leg = Toon.sphere(0.75, stone, SCNVector3(x, 0.6, z), scale: SCNVector3(1, 1.1, 1)); body.addChildNode(leg)
            body.addChildNode(glowLine(UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1), from: SCNVector3(x - 0.3, 1.0, z + 0.6), to: SCNVector3(x + 0.2, 0.3, z + 0.7), r: 0.04))
        }
        head.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: 0.2, z: 0, duration: 1.5), .rotateTo(x: 0, y: -0.2, z: 0, duration: 1.5)])))
        return root
    }

    // MARK: 4 クラーケン（半透明のクラゲ状の頭に脳、光る目、金リングの吸盤の触手）
    static func kraken() -> SCNNode {
        let root = SCNNode(); let body = SCNNode(); body.position.y = 1.4; root.addChildNode(body)
        let purple = Toon.mat(UIColor(red: 0.5, green: 0.25, blue: 0.75, alpha: 1), rim: UIColor(red: 1, green: 0.6, blue: 1, alpha: 1), rimStrength: 0.9, shiny: 0.9)
        let gold = Toon.mat(UIColor(red: 1, green: 0.8, blue: 0.35, alpha: 1), shiny: 1)
        let sucker = Toon.mat(UIColor(red: 0.9, green: 0.55, blue: 1, alpha: 1), rim: .white, rimStrength: 0.6)
        // 頭（ドーム＋脳）
        let dome = Toon.sphere(2.0, Mat.jelly(UIColor(red: 0.85, green: 0.5, blue: 1, alpha: 1), alpha: 0.5), SCNVector3(0, 2.6, -0.3), scale: SCNVector3(1, 0.85, 1))
        body.addChildNode(dome)
        for i in 0..<9 {
            let a = Float(i) / 9 * .pi * 2
            body.addChildNode(Toon.sphere(0.6, Toon.mat(UIColor(red: 0.95, green: 0.4, blue: 0.85, alpha: 1), rimStrength: 0.5), SCNVector3(cos(a) * 0.7, 2.7 + sin(a * 2) * 0.2, -0.3 + sin(a) * 0.6), scale: SCNVector3(1, 0.7, 1)))
        }
        body.addChildNode(Toon.sphere(1.5, purple, SCNVector3(0, 1.0, 0.1), scale: SCNVector3(1.15, 0.85, 1)))
        for s in [-1, 1] as [Float] { body.addChildNode(angryEye(0.28, glow: UIColor(red: 0.4, green: 1, blue: 1, alpha: 1), at: SCNVector3(s * 0.6, 1.2, 1.35), side: s)) }
        // 8本の触手
        for i in 0..<8 {
            let a = Float(i) / 8 * .pi * 2 + 0.2
            let base = SCNNode(); base.position = SCNVector3(cos(a) * 1.2, 0.3, sin(a) * 1.2 + 0.3); base.eulerAngles.y = -a + .pi / 2
            body.addChildNode(base)
            var parent = base
            for j in 0..<7 {
                let r = CGFloat(0.5 - Float(j) * 0.06)
                let seg = Toon.sphere(r, purple, j == 0 ? SCNVector3Zero : SCNVector3(0, 0.15 + Float(j) * 0.04, 0.5))
                if j % 2 == 1 {
                    let ringN = SCNNode(geometry: SCNTorus(ringRadius: r * 0.6, pipeRadius: r * 0.15)); ringN.geometry!.materials = [gold]
                    ringN.position = SCNVector3(0, -Float(r) * 0.75, 0); seg.addChildNode(ringN)
                    seg.addChildNode(Toon.sphere(r * 0.45, sucker, SCNVector3(0, -Float(r) * 0.78, 0), scale: SCNVector3(1, 0.4, 1)))
                }
                parent.addChildNode(seg); parent = seg
                let d = 0.8 + Double(j) * 0.08 + Double(i) * 0.05
                seg.runAction(.repeatForever(.sequence([.rotateBy(x: -0.18, y: 0.1, z: 0, duration: d), .rotateBy(x: 0.18, y: -0.1, z: 0, duration: d)])))
            }
            base.eulerAngles.x = -0.35
        }
        body.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.35, z: 0, duration: 1.4), .moveBy(x: 0, y: -0.35, z: 0, duration: 1.4)])))
        return root
    }

    // MARK: 5 光の蛾（白金の甲殻、金の角、半透明の4枚翼、宙に浮く）
    static func moth() -> SCNNode {
        let root = SCNNode(); let body = SCNNode(); body.position.y = 3.2; root.addChildNode(body)
        let armor = Toon.mat(UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1), rim: UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 1), rimStrength: 0.8, shiny: 0.9)
        let gold = Toon.mat(UIColor(red: 1, green: 0.82, blue: 0.4, alpha: 1), shiny: 1)
        body.addChildNode(Toon.sphere(0.8, armor, SCNVector3(0, 0, 0), scale: SCNVector3(0.9, 1.3, 0.8)))
        for i in 0..<4 { body.addChildNode(Toon.sphere(0.6, gold, SCNVector3(0, -0.4 - Float(i) * 0.38, 0.05), scale: SCNVector3(1 - Float(i) * 0.15, 0.35, 0.8 - Float(i) * 0.1))) }
        body.addChildNode(Toon.sphere(0.18, Mat.glow(UIColor(red: 0.5, green: 0.9, blue: 1, alpha: 1)), SCNVector3(0, 0.2, 0.68)))
        let head = SCNNode(); head.position = SCNVector3(0, 1.3, 0.1); body.addChildNode(head)
        head.addChildNode(Toon.sphere(0.5, armor, SCNVector3Zero, scale: SCNVector3(1, 0.9, 0.9)))
        for s in [-1, 1] as [Float] {
            head.addChildNode(angryEye(0.13, glow: UIColor(red: 0.4, green: 1, blue: 1, alpha: 1), at: SCNVector3(s * 0.2, 0.05, 0.42), side: s))
            // 金の角（カーブ）
            var p = SCNVector3(s * 0.25, 0.4, 0)
            for j in 0..<6 {
                let q = SCNVector3(p.x + s * 0.18, p.y + 0.3 - Float(j) * 0.02, p.z - 0.05 + (j > 3 ? 0.15 : 0))
                head.addChildNode(glowLine(.white, from: p, to: q, r: 0.06)); head.childNodes.last!.geometry!.materials = [gold]
                p = q
            }
            head.addChildNode(Toon.sphere(0.12, gold, p))
            // 腕（爪）
            let arm = SCNNode(); arm.position = SCNVector3(s * 0.7, 0.0, 0.3); body.addChildNode(arm)
            arm.addChildNode(Toon.sphere(0.2, armor, SCNVector3(s * 0.3, -0.4, 0.3), scale: SCNVector3(1, 2.2, 1)))
            arm.addChildNode(Toon.cone(0.12, 0.45, gold, SCNVector3(s * 0.45, -1.0, 0.55), euler: SCNVector3(2.6, 0, s * 0.3)))
            // 翼（上下2枚ずつ）
            for (k, sc) in [(0, 1.0), (1, 0.7)] as [(Int, Float)] {
                let pivot = SCNNode(); pivot.position = SCNVector3(s * 0.5, k == 0 ? 0.4 : -0.5, -0.3); body.addChildNode(pivot)
                let path = UIBezierPath(); path.move(to: .zero)
                if k == 0 {
                    path.addCurve(to: CGPoint(x: 3.6, y: 1.8), controlPoint1: CGPoint(x: 1.0, y: 2.0), controlPoint2: CGPoint(x: 2.6, y: 2.4))
                    path.addCurve(to: CGPoint(x: 0.4, y: -0.4), controlPoint1: CGPoint(x: 4.0, y: 0.4), controlPoint2: CGPoint(x: 2.0, y: -0.6))
                } else {
                    path.addCurve(to: CGPoint(x: 2.6, y: -1.8), controlPoint1: CGPoint(x: 1.6, y: 0.2), controlPoint2: CGPoint(x: 3.0, y: -0.8))
                    path.addCurve(to: CGPoint(x: 0.2, y: -0.4), controlPoint1: CGPoint(x: 1.8, y: -2.2), controlPoint2: CGPoint(x: 0.6, y: -1.4))
                }
                path.close(); path.flatness = 0.01
                let wm = Mat.jelly(UIColor(red: 0.6, green: 0.85, blue: 1, alpha: 1), alpha: 0.55); wm.isDoubleSided = true
                wm.shaderModifiers = [.fragment: Mat.rimShader(UIColor(red: 0.9, green: 0.6, blue: 1, alpha: 1), power: 1.2, strength: 0.9)]
                let w = SCNNode(geometry: SCNShape(path: path, extrusionDepth: 0.03)); w.geometry!.materials = [wm]
                w.scale = SCNVector3(s * sc, sc, 1); pivot.addChildNode(w)
                // 翼脈
                let vein = glowLine(UIColor(red: 0.8, green: 0.95, blue: 1, alpha: 1), from: SCNVector3(0, 0, 0.03), to: SCNVector3(s * (k == 0 ? 3.0 : 2.0) * sc, (k == 0 ? 1.5 : -1.4) * sc, 0.03), r: 0.03)
                pivot.addChildNode(vein)
                let d = 0.35 + Double(k) * 0.05
                pivot.runAction(.repeatForever(.sequence([.rotateTo(x: 0, y: CGFloat(s) * -0.5, z: 0, duration: d), .rotateTo(x: 0, y: CGFloat(s) * 0.3, z: 0, duration: d)])))
            }
        }
        // 鱗粉
        let dust = SCNParticleSystem(); dust.particleImage = FX.softDot; dust.blendMode = .additive; dust.birthRate = 40; dust.particleLifeSpan = 2
        dust.particleSize = 0.12; dust.particleColor = UIColor(red: 0.7, green: 0.95, blue: 1, alpha: 1); dust.emitterShape = SCNBox(width: 6, height: 3, length: 1, chamferRadius: 0)
        dust.birthLocation = .volume; dust.particleVelocity = 0.3; dust.acceleration = SCNVector3(0, -0.4, 0)
        let dn = SCNNode(); dn.addParticleSystem(dust); body.addChildNode(dn)
        body.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.6, z: 0, duration: 1.2), .moveBy(x: 0, y: -0.6, z: 0, duration: 1.2)])))
        return root
    }
}
