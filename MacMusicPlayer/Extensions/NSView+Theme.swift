import AppKit

extension NSView {

    func applyBackground(_ color: NSColor) {
        wantsLayer = true
        layer?.backgroundColor = color.cgColor
    }

    func applyCardStyle(cornerRadius: CGFloat = 12) {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
    }

    func applyPanelStyle() {
        applyCardStyle(cornerRadius: 12)
        applyBackground(Theme.panelBackground)
    }
}
