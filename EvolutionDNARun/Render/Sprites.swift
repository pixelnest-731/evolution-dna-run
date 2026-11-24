import SceneKit
import UIKit

/// オーナー提供イラスト（EvolutionDNARun_DesignAssets）から切り抜いた絵をそのまま使う
enum Art {
    private static var cache: [String: UIImage] = [:]
    static func image(_ name: String) -> UIImage {
        if let c = cache[name] { return c }
        let url = Bundle.main.url(forResource: name, withExtension: "png") ?? Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art")
        let img = url.flatMap { UIImage(contentsOfFile: $0.path) } ?? UIImage()
        cache[name] = img
        return img
    }

    /// 生命体の絵（属性・段階）。図鑑・進化パネル用の正面絵
    static func creature(_ e: Element, _ k: Int) -> String {
        switch e {
        case .none: return "evo_fire_0"
        case .fire: return "evo_fire_\(min(k, 3) + 1)"
        case .ice: return "chr_wolf"
        case .thunder: return "chr_bird"
        case .water: return "chr_slime"
        case .plant: return "chr_turtle"
        case .light: return "chr_rabbit"
        case .cosmic: return "chr_jelly"
        default: return "chr_dragon"
        }
    }
    /// 走行中の絵（炎の子ドラゴンは参考画像の後ろ姿をそのまま使う）
    static func runner(_ e: Element, _ k: Int) -> String {
        if e == .fire && k == 0 { return "run_dragon_back" }
        return creature(e, k)
    }
    static func boss(_ kind: BossKind) -> String {
        switch kind {
        case .gorilla: return "boss_gorilla"
        case .lavaDragon: return "boss_lavadragon"
        case .whale: return "boss_whale"
        case .rockTurtle: return "boss_turtle"
        case .kraken: return "boss_kraken"
        case .moth: return "boss_moth"
        }
    }
}

enum Sprite {
    private static var geoCache: [String: SCNGeometry] = [:]
    /// 絵を貼った板。透明部分は破棄して深度を書く（大量表示でも前後関係が崩れない）
    static func node(_ name: String, height: CGFloat) -> SCNNode {
        let key = "\(name)-\(height)"
        if geoCache[key] == nil {
            let img = Art.image(name)
            let aspect = img.size.height > 0 ? img.size.width / img.size.height : 1
            let g = SCNPlane(width: height * aspect, height: height)
            let m = SCNMaterial(); m.lightingModel = .constant; m.diffuse.contents = img; m.isDoubleSided = true
            m.shaderModifiers = [.fragment: "if (_output.color.a < 0.45) discard_fragment();"]
            g.materials = [m]
            geoCache[key] = g
        }
        let plane = SCNNode(geometry: geoCache[key]); plane.position.y = Float(height) / 2
        let root = SCNNode(); root.addChildNode(plane)
        let bb = SCNBillboardConstraint(); bb.freeAxes = .Y
        root.constraints = [bb]
        return root
    }

    /// 走る：跳ねる＋着地でつぶれる
    static func hop(_ n: SCNNode, period: Double = 0.32) {
        guard let p = n.childNodes.first else { return }
        let base = p.position.y
        let up = SCNAction.group([.moveBy(x: 0, y: 0.18, z: 0, duration: period / 2), .scale(to: 1.0, duration: period / 2)])
        up.timingMode = .easeOut
        let down = SCNAction.sequence([.move(to: SCNVector3(0, base, 0), duration: period / 2), .customAction(duration: 0.06) { node, t in node.scale = SCNVector3(1.08, 0.92, 1) }])
        down.timingMode = .easeIn
        p.runAction(.sequence([.wait(duration: Double.random(in: 0...period)), .repeatForever(.sequence([up, down]))]))
    }
}
