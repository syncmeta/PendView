import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var model: ImageBrowserModel?

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        Task { @MainActor in
            model?.open(url: first)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
