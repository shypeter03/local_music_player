import AppKit

/// 使用应用主色绘制进度条，避免受 macOS 系统蓝色强调色影响。
final class PomegranateSlider: NSSlider {
    override func draw(_ dirtyRect: NSRect) {
        let track = NSRect(x: 0, y: bounds.midY - 2, width: bounds.width, height: 4)
        NSColor.separatorColor.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()

        let range = maxValue - minValue
        let fraction = range > 0 ? CGFloat((doubleValue - minValue) / range) : 0
        let progress = NSRect(x: track.minX, y: track.minY, width: track.width * min(max(fraction, 0), 1), height: track.height)
        Theme.accent.setFill()
        NSBezierPath(roundedRect: progress, xRadius: 2, yRadius: 2).fill()

        let knobX = track.minX + track.width * min(max(fraction, 0), 1)
        let knob = NSRect(x: knobX - 5, y: bounds.midY - 5, width: 10, height: 10)
        Theme.accent.setFill()
        NSBezierPath(ovalIn: knob).fill()
    }
}
