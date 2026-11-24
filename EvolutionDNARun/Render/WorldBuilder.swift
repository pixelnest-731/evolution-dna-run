import SceneKit
import UIKit

/// AI社員04/08: 微生物ワールド。前景・中景・遠景で奥行きを作る
enum FX {
    static let softDot: UIImage = {
        let s = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: s).image { ctx in
            let cs = CGColorSpaceCreateDeviceRGB()
            let g = CGGradient(colorsSpace: cs, colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 0.35, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0, endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
    }()

    static func burst(color: UIColor, count: CGFloat = 120, speed: CGFloat = 6, size: CGFloat = 0.18) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = softDot; p.blendMode = .additive
        p.birthRate = count; p.emissionDuration = 0.08; p.loops = false
        p.particleLifeSpan = 0.7; p.particleLifeSpanVariation = 0.3
        p.particleVelocity = speed; p.particleVelocityVariation = speed * 0.6
        p.spreadingAngle = 180; p.particleSize = size; p.particleSizeVariation = size * 0.5
        p.particleColor = color; p.particleColorVariation = SCNVector4(0.05, 0.1, 0.2, 0)
        p.dampingFactor = 2.5
        let fade = SCNParticlePropertyController(animation: {
            let a = CAKeyframeAnimation(); a.values = [1, 1, 0]; a.keyTimes = [0, 0.5, 1]; return a
        }())
        p.propertyControllers = [.opacity: fade]
        return p
    }

    static func gradientImage(_ top: UIColor, _ bottom: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 512)).image { ctx in
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: 512), options: [])
        }
    }
}

enum WorldBuilder {
    static let laneHalfWidth: Float = 3.2

    static func build(into scene: SCNScene, length: Float) {
        scene.background.contents = FX.gradientImage(UIColor(red: 0.30, green: 0.62, blue: 1.0, alpha: 1), UIColor(red: 0.78, green: 0.93, blue: 1.0, alpha: 1))
        scene.fogColor = UIColor(red: 0.72, green: 0.9, blue: 1.0, alpha: 1)
        scene.fogStartDistance = 22; scene.fogEndDistance = 75

        let root = scene.rootNode
        // ライティング
        let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient
        amb.light!.color = UIColor(red: 0.75, green: 0.8, blue: 0.95, alpha: 1); root.addChildNode(amb)
        let key = SCNNode(); key.light = SCNLight(); key.light!.type = .directional
        key.light!.color = UIColor(red: 1, green: 0.95, blue: 0.88, alpha: 1); key.light!.intensity = 1100
        key.eulerAngles = SCNVector3(-1.0, 0.4, 0); root.addChildNode(key)
        let rimL = SCNNode(); rimL.light = SCNLight(); rimL.light!.type = .directional
        rimL.light!.color = UIColor(red: 0.3, green: 0.9, blue: 1, alpha: 1); rimL.light!.intensity = 500
        rimL.eulerAngles = SCNVector3(-0.3, .pi, 0); root.addChildNode(rimL)

        let total = -length + 60
        // 液体の床（コースティクス風に揺らめくシェーダー）
        let floorG = SCNPlane(width: CGFloat(laneHalfWidth * 2), height: CGFloat(total))
        let fm = SCNMaterial(); fm.lightingModel = .constant
        fm.diffuse.contents = UIColor(red: 0.86, green: 0.86, blue: 0.97, alpha: 1)
        fm.shaderModifiers = [.fragment: """
        float2 uv = _surface.diffuseTexcoord * float2(4.0, \(Int(total / 1.6)).0);
        float2 r = float2(1.0, 1.732);
        float2 a = fmod(uv, r) - r * 0.5; float2 b = fmod(uv - r * 0.5, r) - r * 0.5;
        float2 g = dot(a, a) < dot(b, b) ? a : b;
        float2 q = abs(g); float hexd = max(dot(q, normalize(float2(1.0, 1.732))), q.x);
        float line = smoothstep(0.44, 0.48, hexd);
        float shade = 0.94 + 0.06 * sin(dot(uv - g, float2(3.1, 1.7)));
        _output.color.rgb = _output.color.rgb * shade - float3(0.10, 0.10, 0.04) * line;
        float t = scn_frame.time;
        _output.color.rgb += float3(1.0, 1.0, 1.0) * pow(saturate(sin(uv.y * 0.35 - t * 2.0)), 40.0) * 0.08;
        """]
        floorG.materials = [fm]
        let floor = SCNNode(geometry: floorG); floor.eulerAngles.x = -.pi / 2
        floor.position = SCNVector3(0, 0, -total / 2 + 30); root.addChildNode(floor)

        // 外側の深い液体
        let deepG = SCNPlane(width: 80, height: CGFloat(total)); let dm = SCNMaterial(); dm.lightingModel = .constant
        dm.diffuse.contents = UIColor(red: 0.12, green: 0.62, blue: 0.92, alpha: 1)
        dm.shaderModifiers = [.fragment: """
        float2 p = _surface.diffuseTexcoord * float2(40.0, 300.0); float t = scn_frame.time;
        float c = sin(p.x * 1.3 + t) * sin(p.y * 0.9 - t * 1.2) + sin((p.x - p.y) * 0.7 + t * 0.6);
        _output.color.rgb += float3(0.6, 0.95, 1.0) * pow(saturate(0.5 + 0.3 * c), 4.0) * 0.7;
        """]
        deepG.materials = [dm]
        let deep = SCNNode(geometry: deepG); deep.eulerAngles.x = -.pi / 2; deep.position = SCNVector3(0, -0.6, -total / 2 + 30)
        root.addChildNode(deep)

        // 細胞膜の壁（発光チューブ）
        let tube = SCNCylinder(radius: 0.28, height: CGFloat(total)); tube.materials = [Mat.solid(UIColor(red: 0.78, green: 0.62, blue: 1.0, alpha: 1), shiny: 0.8)]
        for s in [-1, 1] as [Float] {
            let t = SCNNode(geometry: tube); t.eulerAngles.x = .pi / 2; t.position = SCNVector3(s * (laneHalfWidth + 0.1), 0.1, -total / 2 + 30)
            root.addChildNode(t)
            // 膜のコブ
            let bumpG = SCNSphere(radius: 0.45); bumpG.materials = [Mat.solid(UIColor(red: 1.0, green: 0.88, blue: 0.45, alpha: 1), shiny: 0.8)]
            var z: Float = 25
            while z > length - 30 {
                let b = SCNNode(geometry: bumpG); b.position = SCNVector3(s * (laneHalfWidth + 0.45), 0.05, z)
                b.scale = SCNVector3(0.75, 0.6, 1.4); b.position.x = s * (laneHalfWidth + 0.1); b.position.y = 0.15; root.addChildNode(b); z -= 4.8
            }
        }

        // 中景・遠景：巨大な細胞、桿菌、DNAらせん
        var rng = SplitMix64(seed: 42)
        let cellColors = [UIColor(red: 0.3, green: 0.85, blue: 0.75, alpha: 1), UIColor(red: 0.55, green: 0.45, blue: 0.95, alpha: 1), UIColor(red: 0.95, green: 0.55, blue: 0.75, alpha: 1), UIColor(red: 0.45, green: 0.75, blue: 1, alpha: 1)]
        var z: Float = 20
        while z > length - 40 {
            for s in [-1, 1] as [Float] {
                let kind = Int.random(in: 0..<3, using: &rng)
                let x = s * Float.random(in: 6...20, using: &rng)
                let y = Float.random(in: 0.5...8, using: &rng)
                let col = cellColors.randomElement(using: &rng)!
                let n: SCNNode
                switch kind {
                case 0: // 巨大細胞
                    let r = CGFloat(Float.random(in: 1.2...3.2, using: &rng))
                    n = SCNNode(geometry: SCNSphere(radius: r)); n.geometry!.materials = [Mat.jelly(col, alpha: 0.28)]
                    let nuc = SCNNode(geometry: SCNSphere(radius: r * 0.35)); nuc.geometry!.materials = [Mat.glow(col.lighter(0.3).withAlphaComponent(0.8))]
                    nuc.position = SCNVector3(Float(r) * 0.2, Float(r) * 0.1, 0); n.addChildNode(nuc)
                case 1: // 桿菌
                    n = SCNNode(geometry: SCNCapsule(capRadius: 0.5, height: CGFloat(Float.random(in: 2.5...4.5, using: &rng))))
                    n.geometry!.materials = [Mat.jelly(col, alpha: 0.45)]
                    n.eulerAngles = SCNVector3(Float.random(in: 0...3, using: &rng), 0, Float.random(in: 0...3, using: &rng))
                default: // DNAらせん
                    n = SCNNode()
                    let a = SCNSphere(radius: 0.18); a.materials = [Mat.glow(UIColor(red: 0.5, green: 0.9, blue: 1, alpha: 1))]
                    let b = SCNSphere(radius: 0.18); b.materials = [Mat.glow(UIColor(red: 1, green: 0.5, blue: 0.85, alpha: 1))]
                    let rung = SCNCylinder(radius: 0.04, height: 1.2); rung.materials = [Mat.glow(UIColor(white: 1, alpha: 0.5))]
                    for i in 0..<14 {
                        let ang = Float(i) * 0.5; let yy = Float(i) * 0.38
                        let p1 = SCNNode(geometry: a); p1.position = SCNVector3(cos(ang) * 0.6, yy, sin(ang) * 0.6)
                        let p2 = SCNNode(geometry: b); p2.position = SCNVector3(-cos(ang) * 0.6, yy, -sin(ang) * 0.6)
                        let r = SCNNode(geometry: rung); r.position = SCNVector3(0, yy, 0); r.eulerAngles = SCNVector3(0, -ang, .pi / 2)
                        n.addChildNode(p1); n.addChildNode(p2); n.addChildNode(r)
                    }
                    n.eulerAngles.z = Float.random(in: -0.6...0.6, using: &rng)
                    n.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 9)))
                }
                n.position = SCNVector3(x, y, z + Float.random(in: -4...4, using: &rng))
                let d = Double.random(in: 2...4, using: &rng)
                n.runAction(.repeatForever(.sequence([.moveBy(x: 0, y: 0.6, z: 0, duration: d), .moveBy(x: 0, y: -0.6, z: 0, duration: d)])))
                root.addChildNode(n)
            }
            z -= Float.random(in: 5...9, using: &rng)
        }
    }

    /// カメラに追従する浮遊微粒子（前景の奥行き）
    static func motes() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = FX.softDot; p.blendMode = .additive
        p.birthRate = 60; p.particleLifeSpan = 5; p.loops = true
        p.emitterShape = SCNBox(width: 24, height: 10, length: 40, chamferRadius: 0)
        p.birthLocation = .volume
        p.particleVelocity = 0.3; p.particleVelocityVariation = 0.3; p.spreadingAngle = 180
        p.particleSize = 0.08; p.particleSizeVariation = 0.06
        p.particleColor = UIColor(red: 1, green: 1, blue: 0.9, alpha: 0.8)
        p.particleColorVariation = SCNVector4(0.15, 0.2, 0.2, 0.3)
        return p
    }
}

// MARK: - 増殖ゲート
enum GateBuilder {
    static func color(_ g: GateKind) -> UIColor {
        switch g {
        case .sub, .div: return UIColor(red: 1, green: 0.28, blue: 0.38, alpha: 1)
        case .add: return UIColor(red: 0.25, green: 0.85, blue: 1, alpha: 1)
        case .mul: return UIColor(red: 0.35, green: 1, blue: 0.55, alpha: 1)
        case .evolve(let e): return Palette.color(e)
        case .fuse: return UIColor(red: 0.85, green: 0.5, blue: 1, alpha: 1)
        }
    }

    static func gate(_ g: GateKind, width: Float) -> SCNNode {
        let c = color(g)
        let root = SCNNode()
        let panelG = SCNPlane(width: CGFloat(width), height: 2.0)
        let pm = SCNMaterial(); pm.lightingModel = .constant; pm.isDoubleSided = true
        pm.diffuse.contents = FX.gradientImage(c.lighter(0.15).withAlphaComponent(0.9), c.withAlphaComponent(0.55))
        pm.writesToDepthBuffer = false
        panelG.materials = [pm]; panelG.cornerRadius = 0.5
        let panel = SCNNode(geometry: panelG); panel.name = "panel"; panel.position = SCNVector3(0, 1.0, 0); panel.renderingOrder = 5
        root.addChildNode(panel)
        // フレーム
        let post = SCNCapsule(capRadius: 0.2, height: 2.4); post.materials = [Mat.solid(c.darker(0.15), shiny: 0.9)]
        for s in [-1, 1] as [Float] {
            let p = SCNNode(geometry: post); p.position = SCNVector3(s * width / 2, 1.1, 0); root.addChildNode(p)
            let orb = SCNNode(geometry: SCNSphere(radius: 0.22)); orb.geometry!.materials = [Mat.glow(.white)]
            orb.position = SCNVector3(s * width / 2, 2.35, 0); root.addChildNode(orb)
            orb.runAction(.repeatForever(.sequence([.fadeOpacity(to: 0.5, duration: 0.5), .fadeOpacity(to: 1, duration: 0.5)])))
        }
        let bar = SCNCapsule(capRadius: 0.2, height: CGFloat(width)); bar.materials = [Mat.solid(c.darker(0.15), shiny: 0.9)]
        let b = SCNNode(geometry: bar); b.eulerAngles.z = .pi / 2; b.position = SCNVector3(0, 2.2, 0); root.addChildNode(b)
        // ラベル
        let text = SCNText(string: g.label, extrusionDepth: 0.15)
        text.font = UIFont.systemFont(ofSize: 1.0, weight: .black).rounded()
        text.flatness = 0.02; text.chamferRadius = 0.03
        let tm = Mat.glow(.white); let side = Mat.glow(c.darker(0.45))
        text.materials = [tm, side, tm, side, side]
        let tn = SCNNode(geometry: text)
        let (mn, mx) = tn.boundingBox
        tn.pivot = SCNMatrix4MakeTranslation((mx.x + mn.x) / 2, (mx.y + mn.y) / 2, 0)
        let fit = min(1.0, (width - 0.5) / max(0.01, mx.x - mn.x))
        tn.scale = SCNVector3(fit, fit, fit)
        tn.position = SCNVector3(0, 1.05, 0.12); tn.name = "label"; tn.renderingOrder = 10
        root.addChildNode(tn)
        return root
    }
}

extension UIFont {
    func rounded() -> UIFont {
        guard let d = fontDescriptor.withDesign(.rounded) else { return self }
        return UIFont(descriptor: d, size: pointSize)
    }
}
