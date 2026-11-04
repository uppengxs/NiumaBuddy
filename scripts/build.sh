#!/bin/bash
# 编译 release 版（Apple 芯片 + Intel 通用）并组装成 build/牛马搭子.app
# 只需要 Command Line Tools，不需要 Xcode
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="牛马搭子"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/$APP_NAME.app"
ICON_WORK="$BUILD_DIR/icon"

echo "==> 编译（Apple 芯片 + Intel）"
swift build -c release --triple arm64-apple-macosx14.0
swift build -c release --triple x86_64-apple-macosx14.0
mkdir -p "$BUILD_DIR"
lipo -create -output "$BUILD_DIR/NiumaBuddy" \
  .build/arm64-apple-macosx/release/NiumaBuddy \
  .build/x86_64-apple-macosx/release/NiumaBuddy

echo "==> 自检计算逻辑"
"$BUILD_DIR/NiumaBuddy" --selftest > /dev/null
if arch -x86_64 /usr/bin/true 2> /dev/null; then
  arch -x86_64 "$BUILD_DIR/NiumaBuddy" --selftest > /dev/null
fi

echo "==> 生成图标"
rm -rf "$ICON_WORK"
mkdir -p "$ICON_WORK/AppIcon.iconset"
swift scripts/make_icon.swift "$ICON_WORK/icon-1024.png"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ICON_WORK/icon-1024.png" --out "$ICON_WORK/AppIcon.iconset/icon_${size}x${size}.png" > /dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$ICON_WORK/icon-1024.png" --out "$ICON_WORK/AppIcon.iconset/icon_${size}x${size}@2x.png" > /dev/null
done
iconutil -c icns "$ICON_WORK/AppIcon.iconset" -o "$ICON_WORK/AppIcon.icns"

echo "==> 组装 $APP_NAME.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/zh-Hans.lproj"
mv "$BUILD_DIR/NiumaBuddy" "$APP/Contents/MacOS/NiumaBuddy"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp "$ICON_WORK/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
# 内置了 holiday-cn 的数据，按 MIT 协议要随 App 附上版权声明
cp LICENSE THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"

echo "==> 本地签名（ad-hoc）"
codesign --force --sign - "$APP"

echo "完成：$APP"
