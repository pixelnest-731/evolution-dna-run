// AI社員04: 参考イラストの指定範囲から被写体を自動切り抜き（macOS Vision 前景マスク）
// usage: swift cutout.swift <input.png> <output.png> x y w h   （左上原点のピクセル座標）
import Foundation
import Vision
import CoreImage
import AppKit

let a = CommandLine.arguments
let src = CIImage(contentsOf: URL(fileURLWithPath: a[1]))!
let H = src.extent.height
let x = Double(a[3])!, y = Double(a[4])!, w = Double(a[5])!, h = Double(a[6])!
let rect = CGRect(x: x, y: H - y - h, width: w, height: h)
let crop = src.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
if a.count > 7 && a[7] == "raw" {   // 背景用：切り抜かずにそのままトリミング
    let cg = CIContext().createCGImage(crop, from: CGRect(x: 0, y: 0, width: w, height: h))!
    try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
    print(a[2], "raw"); exit(0)
}
let handler = VNImageRequestHandler(ciImage: crop)
let req = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([req])
guard let obs = req.results?.first, !obs.allInstances.isEmpty else { print("NO SUBJECT \(a[2])"); exit(1) }
// 中央に最も近いインスタンスを主役として採用（＋重なる小片も含める）
let buf = try obs.generateMaskedImage(ofInstances: obs.allInstances, from: handler, croppedToInstancesExtent: true)
let img = CIImage(cvPixelBuffer: buf)
let ctx = CIContext()
let cg = ctx.createCGImage(img, from: img.extent)!
try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))
print(a[2].split(separator: "/").last!, cg.width, cg.height, "instances:", obs.allInstances.count)
