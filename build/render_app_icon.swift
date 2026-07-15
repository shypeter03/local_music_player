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
