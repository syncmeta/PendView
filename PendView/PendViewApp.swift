import SwiftUI

@main
struct PendViewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = ImageBrowserModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 480, minHeight: 320)
                .onAppear { appDelegate.model = model }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open…") { openViaPanel() }
                    .keyboardShortcut("o", modifiers: [.command])
            }
            CommandMenu("Image") {
                Button("Next") { model.next() }
                    .keyboardShortcut(.rightArrow, modifiers: [])
                Button("Previous") { model.previous() }
                    .keyboardShortcut(.leftArrow, modifiers: [])
            }
            CommandMenu("View") {
                Button("Zoom In") {
                    NotificationCenter.default.post(name: .pvZoomIn, object: nil)
                }
                .keyboardShortcut("=", modifiers: [.command])
                Button("Zoom Out") {
                    NotificationCenter.default.post(name: .pvZoomOut, object: nil)
                }
                .keyboardShortcut("-", modifiers: [.command])
                Divider()
                Button("Fit to Window") {
                    NotificationCenter.default.post(name: .pvZoomFit, object: nil)
                }
                .keyboardShortcut("0", modifiers: [.command])
                Button("Actual Size") {
                    NotificationCenter.default.post(name: .pvZoomActual, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command])
            }
        }
    }

    private func openViaPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]
        if panel.runModal() == .OK, let url = panel.url {
            model.open(url: url)
        }
    }
}
