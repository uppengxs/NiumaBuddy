#!/bin/bash
# 打包成可分享的 dist/牛马搭子-<版本>.dmg（拖拽安装）和 .zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="牛马搭子"
VERSION="$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)"
APP="$ROOT/build/$APP_NAME.app"
STAGE="$ROOT/build/dmg-stage"
DIST="$ROOT/dist"
DMG="$DIST/$APP_NAME-$VERSION.dmg"
ZIP="$DIST/$APP_NAME-$VERSION.zip"

./scripts/build.sh

echo "==> 准备 DMG 内容"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"
ditto "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/应用程序"
cp packaging/首次打开说明.txt THIRD_PARTY_NOTICES.md "$STAGE/"

echo "==> 生成 DMG"
# 先建空白镜像、挂载后用 ditto 拷进去，再压缩成只读格式。
# 不用 hdiutil create -srcfolder（受限环境里会报「资源忙」），
# 也不用 makehybrid（会给 App 加 FinderInfo 属性，签名严格校验不过，对方可能提示「已损坏」）
RW="$ROOT/build/rw.dmg"
MNT="$ROOT/build/dmg-mount"
rm -f "$DMG" "$RW"
rm -rf "$MNT"
mkdir -p "$MNT"
trap 'hdiutil detach "$MNT" -force > /dev/null 2>&1 || true' EXIT
SIZE_MB=$(( $(du -sm "$STAGE" | cut -f1) + 20 ))
hdiutil create -size "${SIZE_MB}m" -fs HFS+ -volname "$APP_NAME" -type UDIF "$RW" > /dev/null
hdiutil attach "$RW" -nobrowse -noautoopen -mountpoint "$MNT" > /dev/null
ditto "$STAGE" "$MNT"
hdiutil detach "$MNT" > /dev/null
trap - EXIT
hdiutil convert "$RW" -format UDZO -o "$DMG" > /dev/null
rm -f "$RW"
rmdir "$MNT"

echo "==> 生成 zip"
rm -f "$ZIP"
# 用 ditto 压缩，才能保住 .app 里的签名和权限；Finder「压缩」也可以
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

rm -rf "$STAGE"
echo "完成："
ls -lh "$DMG" "$ZIP"
