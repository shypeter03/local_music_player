import AppKit

enum Theme {

    // MARK: - Accent

    /// 石榴红：用于品牌和主要操作。
    static let accent = NSColor(calibratedRed: 0.73, green: 0.10, blue: 0.18, alpha: 1)
    static let accentText = NSColor.white

    // MARK: - Background

    static var windowBackground: NSColor {
        .windowBackgroundColor
    }

    static var pageBackground: NSColor {
        .controlBackgroundColor
    }

    static var sidebarBackground: NSColor {
        .underPageBackgroundColor
    }

    static var panelBackground: NSColor {
        .controlBackgroundColor
    }

    static var cardBackground: NSColor {
        NSColor.controlBackgroundColor.withAlphaComponent(0.90)
    }

    static var cardHoverBackground: NSColor {
        accent.withAlphaComponent(0.06)
    }

    static var cardSelectedBackground: NSColor {
        accent.withAlphaComponent(0.12)
    }

    static var playingBackground: NSColor {
        accent.withAlphaComponent(0.18)
    }

    static var heroBackground: NSColor {
        accent.withAlphaComponent(0.14)
    }

    // MARK: - Border

    static var border: NSColor {
        .separatorColor
    }

    static var divider: NSColor {
        .separatorColor
    }

    // MARK: - Text

    static var text: NSColor {
        .labelColor
    }

    static var secondaryText: NSColor {
        .tertiaryLabelColor
    }

    static var tertiaryText: NSColor {
        .tertiaryLabelColor
    }

    static var disabledText: NSColor {
        .disabledControlTextColor
    }

    // MARK: - Row

    static var rowNormal: NSColor {
        cardBackground
    }

    static var rowSelected: NSColor {
        cardSelectedBackground
    }

    static var rowPlaying: NSColor {
        playingBackground
    }

    // MARK: - Player

    static var miniPlayerBackground: NSColor {
        .controlBackgroundColor
    }

    static var nowPlayingBackground: NSColor {
        .textBackgroundColor
    }

    // MARK: - Button

    static var destructive: NSColor {
        .systemRed
    }

    static var success: NSColor {
        .systemGreen
    }

    // MARK: - Shadow

    static var shadow: NSColor {
        NSColor.black.withAlphaComponent(
            NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? 0.35
            : 0.12
        )
    }

    static var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}
