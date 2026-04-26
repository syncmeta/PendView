import SwiftUI
import AppKit
import Combine

extension Notification.Name {
    static let pvZoomIn     = Notification.Name("pv.zoomIn")
    static let pvZoomOut    = Notification.Name("pv.zoomOut")
    static let pvZoomFit    = Notification.Name("pv.zoomFit")
    static let pvZoomActual = Notification.Name("pv.zoomActual")
}

struct ImageCanvasView: NSViewRepresentable {
    let image: NSImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = ArrowForwardingScrollView()
        scroll.allowsMagnification = true
        scroll.minMagnification = 0.02
        scroll.maxMagnification = 32.0
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = .windowBackgroundColor

        let clip = CenteringClipView()
        clip.drawsBackground = false
        scroll.contentView = clip

        let iv = PannableImageView()
        iv.imageScaling = .scaleNone
        iv.imageAlignment = .alignCenter
        iv.image = image
        iv.frame = NSRect(origin: .zero, size: image.size)
        scroll.documentView = iv

        context.coordinator.scrollView = scroll
        context.coordinator.subscribe()
        // 第一次有尺寸后再 fit
        DispatchQueue.main.async { context.coordinator.fitToWindow() }
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let iv = scrollView.documentView as? NSImageView else { return }
        if iv.image !== image {
            iv.image = image
            iv.frame = NSRect(origin: .zero, size: image.size)
            DispatchQueue.main.async { context.coordinator.fitToWindow() }
        }
    }

    final class Coordinator: NSObject {
        weak var scrollView: NSScrollView?
        private var subs = Set<AnyCancellable>()

        func subscribe() {
            let nc = NotificationCenter.default
            nc.publisher(for: .pvZoomIn)
                .sink { [weak self] _ in self?.zoom(by: 1.5) }.store(in: &subs)
            nc.publisher(for: .pvZoomOut)
                .sink { [weak self] _ in self?.zoom(by: 1.0/1.5) }.store(in: &subs)
            nc.publisher(for: .pvZoomFit)
                .sink { [weak self] _ in self?.fitToWindow() }.store(in: &subs)
            nc.publisher(for: .pvZoomActual)
                .sink { [weak self] _ in self?.actualSize() }.store(in: &subs)
        }

        func zoom(by factor: CGFloat) {
            guard let sv = scrollView else { return }
            let center = NSPoint(x: sv.contentView.bounds.midX,
                                 y: sv.contentView.bounds.midY)
            sv.setMagnification(sv.magnification * factor, centeredAt: center)
        }

        func fitToWindow() {
            guard let sv = scrollView, let doc = sv.documentView else { return }
            let viewport = sv.contentView.bounds.size
            let imageSize = doc.frame.size
            guard viewport.width > 0, viewport.height > 0,
                  imageSize.width > 0, imageSize.height > 0 else { return }
            let scale = min(viewport.width / imageSize.width,
                            viewport.height / imageSize.height,
                            1.0)
            sv.magnification = scale
            // 居中显示
            sv.contentView.scroll(to: NSPoint(
                x: (imageSize.width - viewport.width / scale) / 2,
                y: (imageSize.height - viewport.height / scale) / 2
            ))
            sv.reflectScrolledClipView(sv.contentView)
        }

        func actualSize() {
            guard let sv = scrollView else { return }
            sv.setMagnification(1.0,
                centeredAt: NSPoint(x: sv.contentView.bounds.midX,
                                    y: sv.contentView.bounds.midY))
        }
    }
}

// MARK: - 不抢方向键的滚动视图
final class ArrowForwardingScrollView: NSScrollView {
    override func keyDown(with event: NSEvent) {
        // 方向键和空格交给上游(SwiftUI .onKeyPress / 菜单快捷键)
        let forwardKeys: Set<UInt16> = [123, 124, 125, 126, 49] // L,R,D,U,Space
        if forwardKeys.contains(event.keyCode) {
            nextResponder?.keyDown(with: event)
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - 居中 ClipView(图小于视口时居中显示)
final class CenteringClipView: NSClipView {
    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        var rect = super.constrainBoundsRect(proposedBounds)
        guard let doc = documentView else { return rect }
        if rect.width > doc.frame.width {
            rect.origin.x = (doc.frame.width - rect.width) / 2
        }
        if rect.height > doc.frame.height {
            rect.origin.y = (doc.frame.height - rect.height) / 2
        }
        return rect
    }
}

// MARK: - 鼠标拖动平移
final class PannableImageView: NSImageView {
    private var dragStart: NSPoint = .zero
    private var initialOrigin: NSPoint = .zero

    override var acceptsFirstResponder: Bool { false }

    override func resetCursorRects() {
        // 鼠标进入图像区域时显示张开的手
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        guard let sv = enclosingScrollView else { return }
        dragStart = event.locationInWindow
        initialOrigin = sv.contentView.bounds.origin
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let sv = enclosingScrollView else { return }
        let now = event.locationInWindow
        let dx = now.x - dragStart.x
        let dy = now.y - dragStart.y
        var origin = initialOrigin
        origin.x -= dx / sv.magnification
        origin.y -= dy / sv.magnification
        sv.contentView.scroll(to: origin)
        sv.reflectScrolledClipView(sv.contentView)
    }

    override func mouseUp(with event: NSEvent) {
        NSCursor.openHand.set()
    }
}
