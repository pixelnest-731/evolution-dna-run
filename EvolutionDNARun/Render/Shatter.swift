import SceneKit
import UIKit

/// AI社員02/04: イラストのボスを「厚みのある立体の破片」に分割して物理演算で砕け散らせる
/// （平面が倒れるのではなく、3D の塊として崩れ落ちる見え方を作る）
enum Shatter {
    static func explode(_ plane: SCNNode, in scene: SCNScene, toward cam: SCNVector3, cols: Int = 11, rows: Int = 11) {
        guard let geo = plane.geometry as? SCNPlane,
              let img = geo.firstMaterial?.diffuse.contents as? UIImage, let cg = img.cgImage else { return }
        // 各マスの不透明度と平均色を取得（透明なマスは破片にしない）
        let sw = cols * 4, sh = rows * 4
        var px = [UInt8](repeating: 0, count: sw * sh * 4)
        let ctx = CGContext(data: &px, width: sw, height: sh, bitsPerComponent: 8, bytesPerRow: sw * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: sw, height: sh))
        func cell(_ c: Int, _ r: Int) -> (alpha: CGFloat, color: UIColor) {
            var a: CGFloat = 0, rr: CGFloat = 0, gg: CGFloat = 0, bb: CGFloat = 0
            for y in 0..<4 { for x in 0..<4 {
                // CGContext は下原点なので行を反転
                let i = (((rows - 1 - r) * 4 + y) * sw + c * 4 + x) * 4
                a += CGFloat(px[i + 3]); rr += CGFloat(px[i]); gg += CGFloat(px[i + 1]); bb += CGFloat(px[i + 2])
            } }
            let n: CGFloat = 16
            let al = a / n / 255
            let div = max(a, 1)
            return (al, UIColor(red: rr / div, green: gg / div, blue: bb / div, alpha: 1))
        }

        let W = geo.width, H = geo.height
        let pw = W / CGFloat(cols), ph = H / CGFloat(rows)
        let pres = plane.presentation
        let center = pres.convertPosition(SCNVector3Zero, to: nil)
        let depth = min(pw, ph) * 0.6
        // 破片が跳ねる見えない地面
        let ground = SCNNode(geometry: SCNBox(width: 30, height: 0.2, length: 30, chamferRadius: 0))
        ground.opacity = 0; ground.position = SCNVector3(center.x, -0.1, center.z)
        let gb = SCNPhysicsBody(type: .static, shape: nil); gb.categoryBitMask = 2; gb.collisionBitMask = 1; gb.restitution = 0.4
        ground.physicsBody = gb; scene.rootNode.addChildNode(ground)
        ground.runAction(.sequence([.wait(duration: 4), .removeFromParentNode()]))
        for r in 0..<rows {
            for c in 0..<cols {
                let info = cell(c, r)
                guard info.alpha > 0.35 else { continue }
                // 正面＝イラストの該当部分、側面＝その部分の色を暗くした厚み
                let box = SCNBox(width: pw, height: ph, length: depth, chamferRadius: 0)
                let front = SCNMaterial(); front.lightingModel = .constant; front.diffuse.contents = img
                let t = SCNMatrix4Translate(SCNMatrix4MakeScale(1 / Float(cols), 1 / Float(rows), 1), Float(c) / Float(cols), Float(r) / Float(rows), 0)
                front.diffuse.contentsTransform = t
                front.shaderModifiers = [.fragment: "if (_output.color.a < 0.3) discard_fragment();"]
                let side = SCNMaterial(); side.lightingModel = .blinn; side.diffuse.contents = info.color.darker(0.35)
                side.emission.contents = UIColor.black
                box.materials = [front, side, side, side, side, side]
                let piece = SCNNode(geometry: box)
                let local = SCNVector3(Float(-W / 2 + pw * (CGFloat(c) + 0.5)), Float(H / 2 - ph * (CGFloat(r) + 0.5)), 0)
                piece.position = pres.convertPosition(local, to: nil)
                piece.orientation = pres.worldOrientation
                scene.rootNode.addChildNode(piece)
                // 中心から外へ＋カメラ方向へ（奥行き）＋上へ
                let wp = piece.position
                var dir = SCNVector3(wp.x - center.x, wp.y - center.y + 1.5, 0)
                let toCam = SCNVector3(cam.x - wp.x, 0, cam.z - wp.z)
                let tl = max(0.001, sqrt(toCam.x * toCam.x + toCam.z * toCam.z))
                let spd = Float.random(in: 4...9)
                dir = SCNVector3(dir.x * 1.4 + toCam.x / tl * spd * 0.15, dir.y * 0.8 + Float.random(in: 3...7), toCam.z / tl * spd * 0.2 + Float.random(in: -3...1))
                let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(geometry: box, options: nil))
                body.mass = 1; body.damping = 0.05; body.angularDamping = 0.1
                body.categoryBitMask = 1; body.collisionBitMask = 2; body.restitution = 0.45; body.friction = 0.6
                piece.physicsBody = body
                body.velocity = dir
                body.angularVelocity = SCNVector4(Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: -1...1), Float.random(in: 4...12))
                piece.runAction(.sequence([.wait(duration: Double.random(in: 2.2...2.8)), .fadeOut(duration: 0.6), .removeFromParentNode()]))
            }
        }
    }
}
