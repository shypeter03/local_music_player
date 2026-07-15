#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_NAME="本地音乐器"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
# 模块缓存是编译临时产物，不应污染仓库中的构建输出。
MODULE_CACHE_DIR="${TMPDIR:-/private/tmp}/local-music-player-module-cache"
SOURCE_DIR="$ROOT_DIR/MacMusicPlayer"
ICON_SOURCE="$SOURCE_DIR/Assets/AppIcon.svg"

rm -rf "$APP_DIR" "$MODULE_CACHE_DIR"
mkdir -p "$MACOS_DIR" "$MODULE_CACHE_DIR"

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
NSColor(calibratedRed: 0.73, green: 0.10, blue: 0.18, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size), xRadius: size * 0.215, yRadius: size * 0.215).fill()
let config = NSImage.SymbolConfiguration(pointSize: size * 0.54, weight: .bold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
let note = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)!.withSymbolConfiguration(config)!
note.draw(in: NSRect(x: size * 0.23, y: size * 0.21, width: size * 0.54, height: size * 0.58), from: .zero, operation: .sourceOver, fraction: 1)
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
  iconutil -c icns "$ICONSET_DIR" -o "$CONTENTS_DIR/AppIcon.icns"
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
  <string>本地音乐器</string>
  <key>CFBundleIdentifier</key>
  <string>local.music.player.native</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>本地音乐器</string>
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
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
