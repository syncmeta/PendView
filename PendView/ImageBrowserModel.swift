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
            currentImage = img
            lastError = nil
        } else {
            currentImage = nil
            lastError = "无法加载: \(url.lastPathComponent)"
        }
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
