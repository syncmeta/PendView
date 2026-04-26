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
