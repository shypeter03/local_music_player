#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="音乐"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
# 模块缓存是编译临时产物，不应污染仓库中的构建输出。
MODULE_CACHE_DIR="${TMPDIR:-/private/tmp}/local-music-player-module-cache"
SOURCE_DIR="$ROOT_DIR/MacMusicPlayer"
ICON_SOURCE="$SOURCE_DIR/Assets/AppIcon.icns"

rm -rf "$APP_DIR" "$MODULE_CACHE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$MODULE_CACHE_DIR"

if [[ -f "$ICON_SOURCE" ]]; then
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
let iconWidth = rectSize * 0.54
let iconHeight = rectSize * 0.58
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

SOURCES=()
while IFS= read -r file; do
  SOURCES+=("$file")
done < <(find "$SOURCE_DIR" -name "*.swift" | sort)

swiftc \
  "${SOURCES[@]}" \
  -o "$MACOS_DIR/$APP_NAME" \
  -parse-as-library \
  -target arm64-apple-macosx13.0 \
  -Xcc -fmodules-cache-path="$MODULE_CACHE_DIR" \
  -framework AppKit \
  -framework AVFoundation \
  -framework CryptoKit

cat >"$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>音乐</string>
  <key>CFBundleIdentifier</key>
  <string>local.music.player.native</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>音乐</string>
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

echo "$APP_DIR"
