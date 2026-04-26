import SwiftUI

struct DropZoneView: View {
    @EnvironmentObject private var model: ImageBrowserModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.secondary)
            Text("把图片拖到这里")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("或按 ⌘O 打开 · 用 ←/→/↑/↓ 切换同目录图片")
                .font(.callout)
                .foregroundStyle(.tertiary)
            if let err = model.lastError {
                Text(err)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.top, 8)
            }
        }
        .padding(32)
    }
}
