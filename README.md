# PendView

一个极简的 macOS 图片预览器。打开任意图片后,**四个方向键(←/→/↑/↓)都能切换同目录下的上一/下一张** —— 这是 macOS 自带 Preview 不太顺手的地方,也是 PendView 唯一想解决的问题。其它都尽量保持最小。

## 功能

- 打开图片:`⌘O` / 拖入窗口 / Finder 双击(支持设为默认打开方式)
- 键盘切换:`←` `→` `↑` `↓` `Space` 切换上一/下一张,边界环绕
- 同目录扫描,Finder 自然排序(`1.jpg < 2.jpg < 10.jpg`)
- 标题栏显示 `文件名 — N/M`

## 系统要求

- macOS 14 (Sonoma) 或更新

## 构建

需要 Xcode 和 [xcodegen](https://github.com/yonsm/XcodeGen)(`brew install xcodegen`)。

```bash
xcodegen generate           # 用 project.yml 生成 PendView.xcodeproj
open PendView.xcodeproj     # 在 Xcode 里 ⌘R 运行
```

或命令行构建:
```bash
xcodebuild -project PendView.xcodeproj -scheme PendView -configuration Debug build
```

## 改图标

编辑 [icon.svg](icon.svg),然后:
```bash
swift scripts/generate_icon.swift
xcodebuild -scheme PendView build
```

脚本会把 SVG 渲染到 10 个 AppIcon 尺寸(16~1024)。

## 项目结构

```
PendView/
├── PendViewApp.swift        # @main, App scene, 菜单
├── AppDelegate.swift        # 处理 Finder 双击 / 拖到 Dock
├── ImageBrowserModel.swift  # 同目录扫描 + 索引 + 加载
├── ContentView.swift        # 顶层视图,键盘 / 拖入
├── ImageCanvasView.swift    # 显示图片
├── DropZoneView.swift       # 空状态
└── Info.plist               # CFBundleDocumentTypes
```
