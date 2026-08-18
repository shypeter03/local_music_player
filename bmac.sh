#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="Music"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
# 模块缓存是编译临时产物。放在本项目的 build 目录中，避免继承自
# 其他用户或进程的系统临时缓存导致无权清理。
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
SOURCE_DIR="$ROOT_DIR/MacMusicPlayer"
ICON_SOURCE="$SOURCE_DIR/Assets/AppIcon.icns"

log() {
  printf '[Music] %s\n' "$1"
}

BUILD_STARTED_AT=$SECONDS
STEP_STARTED_AT=$SECONDS

log_step_time() {
  local elapsed=$((SECONDS - STEP_STARTED_AT))
  log "  ↳ 本步骤耗时 ${elapsed}s"
}

log '1/6 清理上次构建产物…'
# Swift framework modules are expensive to rebuild. Retain their cache between
# normal builds; set CLEAN_MODULE_CACHE=1 only when a clean compiler cache is
# explicitly required.
rm -rf "$APP_DIR"
if [[ "${CLEAN_MODULE_CACHE:-0}" == "1" ]]; then
  rm -rf "$MODULE_CACHE_DIR"
fi
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"
log_step_time

# The checked-in ICNS is the canonical asset. Keeping it avoids an iconutil
# compatibility issue on current macOS releases during local builds.
if false; then
  ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
  ICON_RENDERER="$BUILD_DIR/render_app_icon"
  rm -rf "$ICONSET_DIR"
  mkdir -p "$ICONSET_DIR"
  cat >"$BUILD_DIR/render_app_icon.swift" <<'SWIFT'
import AppKit
import Foundation

let size = CGFloat(Int(CommandLine.arguments[1])!)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// 计算安全边距 (留出 9% 的空白)
let margin = size * 0.09
let rectSize = size * 0.82 // 实际绘制区域缩小为 82%
let rect = NSRect(x: margin, y: margin, width: rectSize, height: rectSize)

// 绘制符合苹果官方标准的圆角矩形底盘
NSColor(calibratedRed: 0.73, green: 0.10, blue: 0.18, alpha: 1).setFill()
NSBezierPath(roundedRect: rect, xRadius: rectSize * 0.215, yRadius: rectSize * 0.215).fill()

// 绘制音乐图标，让其根据缩放后的底盘居中
let config = NSImage.SymbolConfiguration(pointSize: rectSize * 0.54, weight: .bold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
let note = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)!.withSymbolConfiguration(config)!

// 精确计算居中坐标
let iconWidth = rectSize * 0.64
let iconHeight = rectSize * 0.68
let iconX = margin + (rectSize - iconWidth) / 2
let iconY = margin + (rectSize - iconHeight) / 2 - (rectSize * 0.02) // 微调垂直重心

note.draw(in: NSRect(x: iconX, y: iconY, width: iconWidth, height: iconHeight), from: .zero, operation: .sourceOver, fraction: 1)

image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! bitmap.representation(using: .png, properties: [:])!.write(to: output)
SWIFT
  swiftc "$BUILD_DIR/render_app_icon.swift" -o "$ICON_RENDERER" \
    -target arm64-apple-macosx13.0 \
    -Xcc -fmodules-cache-path="$MODULE_CACHE_DIR" \
    -framework AppKit
  for size in 16 32 128 256 512; do
    "$ICON_RENDERER" "$size" "$ICONSET_DIR/icon_${size}x${size}.png"
    double_size=$((size * 2))
    "$ICON_RENDERER" "$double_size" "$ICONSET_DIR/icon_${size}x${size}@2x.png"
  done
  iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
fi

STEP_STARTED_AT=$SECONDS
log '2/6 复制应用图标…'
if [[ -f "$ICON_SOURCE" ]]; then
  cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.icns"
else
  log "  ↳ 未找到图标：$ICON_SOURCE"
fi
log_step_time

SOURCES=()
while IFS= read -r file; do
  SOURCES+=("$file")
done < <(find "$SOURCE_DIR" -name "*.swift" \
  ! -path "*/app/AppDelegate*.swift" \
  ! -path "*/Views/TrackRowView.swift" \
  ! -path "*/Views/FolderRowView.swift" \
  ! -path "*/Views/FlippedView.swift" \
  ! -path "*/Views/PomegranateSlider.swift" \
  ! -path "*/Models/LoadingHDU.swift" \
  ! -path "*/Models/PlayerWindow.swift" \
  ! -path "*/Extensions/NSView+Theme.swift" \
  ! -path "*/Extensions/NSImage+Tint.swift" \
  ! -path "*/app/Theme.swift" | sort)

METAL_SOURCE="$SOURCE_DIR/Assets/AuroraBackground.metal"
METAL_AIR="$BUILD_DIR/AuroraBackground.air"
METAL_LIB="$RESOURCES_DIR/AuroraBackground.metallib"

STEP_STARTED_AT=$SECONDS
log '3/6 编译 Metal shader…'

if [[ ! -f "$METAL_SOURCE" ]]; then
  log "错误：找不到 Metal shader：$METAL_SOURCE"
  exit 1
fi

xcrun -sdk macosx metal \
  -c "$METAL_SOURCE" \
  -o "$METAL_AIR" \
  -mmacosx-version-min=13.0

xcrun -sdk macosx metallib \
  "$METAL_AIR" \
  -o "$METAL_LIB"

rm -f "$METAL_AIR"

log "  ↳ Metal library：$METAL_LIB"
log_step_time

STEP_STARTED_AT=$SECONDS
log "4/6 编译 ${#SOURCES[@]} 个 Swift 源文件…"
swiftc \
  "${SOURCES[@]}" \
  -o "$MACOS_DIR/$APP_NAME" \
  -parse-as-library \
  -target arm64-apple-macosx13.0 \
  -Xcc -fmodules-cache-path="$MODULE_CACHE_DIR" \
  -framework AppKit \
  -framework SwiftUI \
  -framework AVFoundation \
  -framework CryptoKit
log_step_time

STEP_STARTED_AT=$SECONDS
log '5/6 写入应用元数据…'
cat >"$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>Music</string>
  <key>CFBundleIdentifier</key>
  <string>local.music.player.native</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Music</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>12.0</string>
  <key>NSAppTransportSecurity</key>
  <dict>
      <key>NSAllowsArbitraryLoads</key>
      <true/>
  </dict>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST
log_step_time

STEP_STARTED_AT=$SECONDS
log "6/6 构建完成，总耗时 $((SECONDS - BUILD_STARTED_AT))s。"
log_step_time
printf '%s\n' "$APP_DIR"
