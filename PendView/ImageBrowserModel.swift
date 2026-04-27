import AppKit
import Foundation

@MainActor
final class ImageBrowserModel: ObservableObject {
    static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "jpe",
        "png",
        "gif",
        "heic", "heif",
        "webp",
        "tiff", "tif",
        "bmp",
        "ico",
        "svg",
        "raw", "cr2", "nef", "arw", "dng"
    ]

    @Published private(set) var currentURL: URL?
    @Published private(set) var currentImage: NSImage?
    @Published private(set) var siblings: [URL] = []
    @Published private(set) var index: Int = 0
    @Published private(set) var lastError: String?

    func open(url: URL) {
        let folder = url.deletingLastPathComponent()
        let listed = listImages(in: folder)
        let sorted = listed.sorted { lhs, rhs in
            lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        siblings = sorted
        if let i = sorted.firstIndex(where: { $0.standardizedFileURL == url.standardizedFileURL }) {
            index = i
        } else {
            // 用户传入的图片不在我们的白名单里(罕见),仍然显示它本身
            siblings = [url]
            index = 0
        }
        load(url: siblings[index])
    }

    func next() { advance(by: +1) }
    func previous() { advance(by: -1) }

    private func advance(by delta: Int) {
        let n = siblings.count
        guard n > 1 else { return }
        index = ((index + delta) % n + n) % n
        load(url: siblings[index])
    }

    private func load(url: URL) {
        currentURL = url
        if let img = NSImage(contentsOf: url) {
            currentImage = rasterizeIfVector(img)
            lastError = nil
        } else {
            currentImage = nil
            lastError = "无法加载: \(url.lastPathComponent)"
        }
    }

    /// 矢量图(SVG)在 NSImageView 里只按 frame 大小栅格化一次,
    /// 之后 NSScrollView 的 magnification 会把那张位图直接拉大 → 放大就糊。
    /// 这里检测无像素尺寸的矢量图,以高分辨率预先栅格化,放大时仍然清晰。
    private func rasterizeIfVector(_ image: NSImage) -> NSImage {
        let isVector = !image.representations.isEmpty &&
            image.representations.allSatisfy { $0.pixelsWide == 0 || $0.pixelsHigh == 0 }
        guard isVector,
              image.size.width > 0, image.size.height > 0 else { return image }

        let target: CGFloat = 2048
        let scale = max(target / image.size.width, target / image.size.height, 1.0)
        let pxW = Int((image.size.width * scale).rounded())
        let pxH = Int((image.size.height * scale).rounded())
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pxW, pixelsHigh: pxH,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return image }
        bitmap.size = NSSize(width: pxW, height: pxH)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        guard let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else { return image }
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: pxW, height: pxH),
                   from: .zero, operation: .copy, fraction: 1.0)

        let out = NSImage(size: NSSize(width: pxW, height: pxH))
        out.addRepresentation(bitmap)
        return out
    }

    private func listImages(in folder: URL) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }
        return items.filter { url in
            Self.supportedExtensions.contains(url.pathExtension.lowercased())
        }
    }
}
