#!/usr/bin/env bash
set -euo pipefail

# === 配置 ===
APP_NAME="PendView"
VERSION="${VERSION:-0.1.0}"
VOLUME_NAME="$APP_NAME"
IDENTITY="${IDENTITY:-Developer ID Application: Yanze Tan (M42BKJN82S)}"
WINDOW_W=540
WINDOW_H=380
ICON_SIZE=128
APP_X=140; APP_Y=180          # 左
APPS_X=400; APPS_Y=180        # 右

# === 路径 ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
BG_PNG="$SCRIPT_DIR/dmg-background.png"
DMG_PATH="$DIST_DIR/${APP_NAME}-${VERSION}.dmg"
TMP_DMG="$DIST_DIR/${APP_NAME}-tmp-$$.dmg"

mkdir -p "$DIST_DIR"

# === 0. 找 Release build ===
echo "==> 定位 Release build"
RELEASE_APP=$(find ~/Library/Developer/Xcode/DerivedData -name "$APP_NAME.app" \
    -path "*/Build/Products/Release/*" -not -path "*/Index.noindex/*" \
    -print -quit 2>/dev/null || true)
if [ -z "$RELEASE_APP" ] || [ ! -d "$RELEASE_APP" ]; then
    echo "找不到 Release build,先跑:"
    echo "  xcodebuild -project PendView.xcodeproj -scheme PendView -configuration Release build"
    exit 1
fi
echo "    $RELEASE_APP"

# === 1. 生成背景图(若缺失) ===
if [ ! -f "$BG_PNG" ]; then
    echo "==> 生成 DMG 背景图"
    swift "$SCRIPT_DIR/generate_dmg_background.swift"
fi

# === 2. 卸载残留挂载 ===
for mp in "/Volumes/$VOLUME_NAME"*; do
    [ -d "$mp" ] && hdiutil detach "$mp" -force 2>/dev/null || true
done

# === 3. Stage 内容 ===
echo "==> 准备临时目录"
STAGE=$(mktemp -d)
cp -R "$RELEASE_APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
mkdir "$STAGE/.background"
cp "$BG_PNG" "$STAGE/.background/background.png"

# === 4. 创建可写 DMG(临时) ===
echo "==> 创建可写 DMG"
rm -f "$TMP_DMG" "$DMG_PATH"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE" -ov \
    -format UDRW -fs HFS+ "$TMP_DMG" >/dev/null

# === 5. 挂载,跑 AppleScript 设布局 ===
echo "==> 挂载并设置 Finder 视图"
MOUNT_INFO=$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG")
MOUNT_POINT=$(echo "$MOUNT_INFO" | tail -1 | awk '{for(i=3;i<=NF;i++) printf "%s%s",$i,(i<NF?" ":"")}')
echo "    $MOUNT_POINT"
sleep 2

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 150, $((200 + WINDOW_W)), $((150 + WINDOW_H))}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to $ICON_SIZE
        set text size of viewOptions to 12
        try
            set background picture of viewOptions to file ".background:background.png"
        end try
        set position of item "$APP_NAME.app" of container window to {$APP_X, $APP_Y}
        set position of item "Applications" of container window to {$APPS_X, $APPS_Y}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT

sync; sleep 1
hdiutil detach "$MOUNT_POINT" >/dev/null
sleep 1

# === 6. 转只读压缩 ===
echo "==> 转换为只读压缩 DMG"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 \
    -o "$DMG_PATH" >/dev/null
rm -f "$TMP_DMG"
rm -rf "$STAGE"

# === 7. 签名 ===
echo "==> 签名 DMG"
codesign --force --sign "$IDENTITY" --timestamp "$DMG_PATH"

# === 8. 总结 ===
echo ""
echo "完成: $DMG_PATH"
ls -lh "$DMG_PATH"
shasum -a 256 "$DMG_PATH"
