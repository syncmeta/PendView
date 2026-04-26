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
        iv.frame = NSRect(origin: .zero, size: imageDocSize(image))
        scroll.documentView = iv

        context.coordinator.scrollView = scroll
        context.coordinator.bind()
        return scroll
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let iv = scrollView.documentView as? NSImageView else { return }
        if iv.image !== image {
            iv.image = image
            iv.frame = NSRect(origin: .zero, size: imageDocSize(image))
            context.coordinator.markFittedAndFit()
        }
    }

    /// 优先用像素尺寸,避免 EXIF/@2x 让 NSImage.size 给出"逻辑半值"
    private func imageDocSize(_ image: NSImage) -> NSSize {
        if let rep = image.representations.first,
           rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return NSSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return image.size
    }

    final class Coordinator: NSObject {
        weak var scrollView: NSScrollView?
        private var subs = Set<AnyCancellable>()
        private var observers: [NSObjectProtocol] = []
        /// true = 当前处于"适应窗口"状态;窗口缩放时自动重新 fit
        private var isFitted: Bool = true

        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func bind() {
            let nc = NotificationCenter.default
            nc.publisher(for: .pvZoomIn)
                .sink { [weak self] _ in self?.zoom(by: 1.5) }.store(in: &subs)
            nc.publisher(for: .pvZoomOut)
                .sink { [weak self] _ in self?.zoom(by: 1.0/1.5) }.store(in: &subs)
            nc.publisher(for: .pvZoomFit)
                .sink { [weak self] _ in self?.markFittedAndFit() }.store(in: &subs)
            nc.publisher(for: .pvZoomActual)
                .sink { [weak self] _ in self?.actualSize() }.store(in: &subs)

            guard let sv = scrollView else { return }
            sv.contentView.postsFrameChangedNotifications = true
            let obs = nc.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: sv.contentView, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                if self.isFitted { self.fitToWindow() }
            }
            observers.append(obs)

            // 初次布局完成后再 fit
            DispatchQueue.main.async { [weak self] in self?.fitToWindow() }
        }

        func zoom(by factor: CGFloat) {
            guard let sv = scrollView else { return }
            let center = NSPoint(x: sv.contentView.bounds.midX,
                                 y: sv.contentView.bounds.midY)
            sv.setMagnification(sv.magnification * factor, centeredAt: center)
            isFitted = false
        }

        /// 切换图片时调用:即使上次用户手动放大过,新图回到 fit
        func markFittedAndFit() {
            isFitted = true
            fitToWindow()
        }

        func fitToWindow() {
            guard let sv = scrollView, let doc = sv.documentView else { return }
            // 视口要用屏幕点(frame.size),不用文档坐标(bounds.size)
            let viewport = sv.contentView.frame.size
            let imageSize = doc.frame.size
            guard viewport.width > 0, viewport.height > 0,
                  imageSize.width > 0, imageSize.height > 0 else { return }
            let scale = min(viewport.width / imageSize.width,
                            viewport.height / imageSize.height,
                            1.0)
            sv.magnification = scale
            // CenteringClipView 自动负 origin 居中;不要手动 scroll
            isFitted = true
        }

        func actualSize() {
            guard let sv = scrollView else { return }
            sv.setMagnification(1.0,
                centeredAt: NSPoint(x: sv.contentView.bounds.midX,
                                    y: sv.contentView.bounds.midY))
            isFitted = false
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
