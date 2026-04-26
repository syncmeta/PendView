#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
let outURL = scriptURL.deletingLastPathComponent().appendingPathComponent("dmg-background.png")

// 窗口逻辑尺寸 540 x 380(在 build_dmg.sh 里要一致)
// 输出 2x 密度(1080 x 760)以便 Retina 也清晰
let logicalW: CGFloat = 540
let logicalH: CGFloat = 380
let scale: CGFloat = 2
let pxW = Int(logicalW * scale)
let pxH = Int(logicalH * scale)

let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(
    data: nil, width: pxW, height: pxH,
    bitsPerComponent: 8, bytesPerRow: 0, space: cs,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else { fatalError("ctx") }
ctx.scaleBy(x: scale, y: scale)

// 白底
ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
ctx.fill(CGRect(x: 0, y: 0, width: logicalW, height: logicalH))

// CG 是 Y-up,Finder 显示是 Y-down(从顶往下)
// 我们在 build 脚本里把图标放在 y=180(距窗口顶部 180)
// 对应 CG y = logicalH - 180 = 200
let iconRowCGY: CGFloat = logicalH - 180

// 中间的箭头,短一点,灰色
let arrowMidX: CGFloat = 270
let shaftHalf: CGFloat = 24
let shaftStartX: CGFloat = arrowMidX - shaftHalf
let shaftEndX: CGFloat = arrowMidX + shaftHalf

ctx.setStrokeColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 1.0)
ctx.setLineWidth(3.0)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// 杆
ctx.move(to: CGPoint(x: shaftStartX, y: iconRowCGY))
ctx.addLine(to: CGPoint(x: shaftEndX, y: iconRowCGY))
ctx.strokePath()

// 箭头头
let headLen: CGFloat = 9
ctx.move(to: CGPoint(x: shaftEndX - headLen, y: iconRowCGY + headLen))
ctx.addLine(to: CGPoint(x: shaftEndX, y: iconRowCGY))
ctx.addLine(to: CGPoint(x: shaftEndX - headLen, y: iconRowCGY - headLen))
ctx.strokePath()

guard let img = ctx.makeImage() else { fatalError("cg") }

// 用 NSImage + 显式逻辑尺寸,这样 Finder 会按 2x 渲染
let rep = NSBitmapImageRep(cgImage: img)
rep.size = NSSize(width: logicalW, height: logicalH)
let data = rep.representation(using: .png, properties: [:])!
try data.write(to: outURL)
print("✓ \(outURL.lastPathComponent) (\(pxW)x\(pxH) @2x of \(Int(logicalW))x\(Int(logicalH)))")
