import AppKit

extension NSImage {
    func tinting(with color: NSColor) -> NSImage {
        // 1. 克隆图片
        let image = copy() as! NSImage

            // 2. 关键核心：必须告诉系统这是一张模板图片，否则源图的 Alpha 通道在混合时会失效
            image.isTemplate = true

            image.lockFocus()
            color.set()

            // 3. 建议使用 .sourceIn，它会完全替换原图颜色；
            // .sourceAtop 会保留原图的非透明区域，但如果原图有颜色，可能会与新颜色混合。
            NSRect(origin: .zero, size: image.size).fill(using: .sourceIn)

            image.unlockFocus()

            // 4. 解除模板状态。如果你希望它从此保持这个固定的纯色，不再受系统（如暗黑模式）的二次调色影响，就设为 false
            image.isTemplate = false 

            return image
    }
}
