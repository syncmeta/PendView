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

// macOS 的 NSImage SVG 渲染器忽略 CSS 的 display:none —— 那些"在 Illustrator
// 里隐藏的辅助元素"会被照常画出。先扫一遍 CSS 找出 display:none 的 class,把
// 用了这些 class 的元素从 SVG 里剥掉再交给 NSImage。
let rawSVG = (try? String(contentsOf: svgURL, encoding: .utf8)) ?? ""
var hidden: Set<String> = []
do {
    let blockRegex = try! NSRegularExpression(
        pattern: #"([.\w,\s]+)\{([^}]*)\}"#)
    let nsCSS = rawSVG as NSString
    let matches = blockRegex.matches(
        in: rawSVG, range: NSRange(location: 0, length: nsCSS.length))
    for m in matches {
        let body = nsCSS.substring(with: m.range(at: 2))
        let normalized = body.components(separatedBy: .whitespacesAndNewlines).joined()
        guard normalized.contains("display:none") else { continue }
        let sel = nsCSS.substring(with: m.range(at: 1))
        for piece in sel.split(separator: ",") {
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix(".") {
                hidden.insert(String(trimmed.dropFirst()))
            }
        }
    }
}
var strippedSVG = rawSVG
for cls in hidden {
    let pattern = #"<[a-zA-Z]+[^>]*\bclass="\#(cls)"[^>]*/>"#
    strippedSVG = strippedSVG.replacingOccurrences(
        of: pattern, with: "", options: .regularExpression)
}
if !hidden.isEmpty {
    let list = hidden.sorted().joined(separator: ", ")
    print("剥掉隐藏 class 元素: \(list)")
}
let cleanedSVGURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("pendview-icon-\(UUID().uuidString).svg")
try strippedSVG.write(to: cleanedSVGURL, atomically: true, encoding: .utf8)
defer { try? FileManager.default.removeItem(at: cleanedSVGURL) }

guard let svgImage = NSImage(contentsOf: cleanedSVGURL) else {
    fputs("无法加载 \(svgURL.path)\n", stderr); exit(1)
}
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

    // macOS 应用图标的圆角约为图标边长的 22.37%
    let cornerRadius = size * 0.2237
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    let mask = CGPath(roundedRect: bounds,
                      cornerWidth: cornerRadius,
                      cornerHeight: cornerRadius,
                      transform: nil)
    ctx.addPath(mask)
    ctx.clip()

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
