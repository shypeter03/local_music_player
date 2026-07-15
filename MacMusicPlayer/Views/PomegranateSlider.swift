import AppKit

/// 使用应用主色绘制进度条，避免受 macOS 系统蓝色强调色影响。
final class PomegranateSlider: NSSlider {
    override func draw(_ dirtyRect: NSRect) {
        // ==================== 在这里调整红点的大小 ====================
        let knobSize: CGFloat = 16  // 之前是 10，现在调大到 16（你可以根据喜好改成 14, 18 等）
        // ============================================================
        
        // 动态计算安全边距（正好是红点半径），防止大红点滑到两端时被切掉
        let padding: CGFloat = knobSize / 2 
        let trackWidth = bounds.width - (padding * 2)
        
        // 1. 绘制灰色背景轨道（高度为 4 保持精细，位置根据 padding 缩进）
        let track = NSRect(x: padding, y: bounds.midY - 2, width: trackWidth, height: 4)
        NSColor.separatorColor.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: track, xRadius: 2, yRadius: 2).fill()

        // 计算进度比例
        let range = maxValue - minValue
        let fraction = range > 0 ? CGFloat((doubleValue - minValue) / range) : 0
        let clampedFraction = min(max(fraction, 0), 1)
        
        // 2. 绘制已经播放的红色彩条进度
        let progressWidth = trackWidth * clampedFraction
        let progress = NSRect(x: track.minX, y: track.minY, width: progressWidth, height: track.height)
        Theme.accent.setFill()
        NSBezierPath(roundedRect: progress, xRadius: 2, yRadius: 2).fill()

        // 3. 绘制大红点（滑块），完美的居中计算
        let knobX = track.minX + progressWidth
        let knob = NSRect(
            x: knobX - padding, 
            y: bounds.midY - padding, 
            width: knobSize, 
            height: knobSize
        )
        Theme.accent.setFill()
        NSBezierPath(ovalIn: knob).fill()
    }
}
