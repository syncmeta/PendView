#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

// 脚本位于 <repo>/scripts/generate_icon.swift,projectRoot 是上一级
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
    .resolvingSymlinksInPath()
let projectRoot = scriptURL.deletingLastPathComponent().deletingLastPathComponent().path
let svgURL = URL(fileURLWithPath: "\(projectRoot)/icon.svg")
let outDir = "\(projectRoot)/PendView/Assets.xcassets/AppIcon.appiconset"

guard let svgImage = NSImage(contentsOf: svgURL) else {
    fputs("无法加载 \(svgURL.path)\n", stderr); exit(1)
}
// 让 NSImage 知道这是矢量,缩放时按目标尺寸重渲染
svgImage.size = NSSize(width: 1024, height: 1024)

func renderPNG(px: Int) -> Data {
    let size = CGFloat(px)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil, width: px, height: px,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { fatalError("ctx") }

    ctx.interpolationQuality = .high

    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    svgImage.draw(
        in: NSRect(x: 0, y: 0, width: size, height: size),
        from: .zero,
        operation: .sourceOver,
        fraction: 1.0
    )
    NSGraphicsContext.restoreGraphicsState()

    guard let cg = ctx.makeImage() else { fatalError("cg") }
    let rep = NSBitmapImageRep(cgImage: cg)
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("icon_16x16.png",     16),
    ("icon_16x16@2x.png",  32),
    ("icon_32x32.png",     32),
    ("icon_32x32@2x.png",  64),
    ("icon_128x128.png",   128),
    ("icon_128x128@2x.png",256),
    ("icon_256x256.png",   256),
    ("icon_256x256@2x.png",512),
    ("icon_512x512.png",   512),
    ("icon_512x512@2x.png",1024),
]

for (name, px) in sizes {
    let data = renderPNG(px: px)
    let url = URL(fileURLWithPath: "\(outDir)/\(name)")
    try data.write(to: url)
    print("✓ \(name)  \(px)x\(px)  \(data.count) bytes")
}
print("Done.")
