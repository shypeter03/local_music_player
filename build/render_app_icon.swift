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
