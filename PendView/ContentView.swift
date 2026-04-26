import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var model: ImageBrowserModel
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            if let image = model.currentImage {
                ImageCanvasView(image: image)
            } else {
                DropZoneView()
            }
        }
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.leftArrow)  { model.previous(); return .handled }
        .onKeyPress(.rightArrow) { model.next();     return .handled }
        .onKeyPress(.upArrow)    { model.previous(); return .handled }
        .onKeyPress(.downArrow)  { model.next();     return .handled }
        .onKeyPress(.space)      { model.next();     return .handled }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .navigationTitle(titleString)
        .navigationSubtitle(subtitleString)
    }

    private var titleString: String {
        model.currentURL?.lastPathComponent ?? "PendView"
    }

    private var subtitleString: String {
        guard !model.siblings.isEmpty else { return "" }
        return "\(model.index + 1) / \(model.siblings.count)"
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                model.open(url: url)
            }
        }
        return true
    }
}
