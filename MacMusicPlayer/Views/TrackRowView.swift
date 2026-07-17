import AppKit

final class TrackRowView: NSControl {
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")
    private let metaLabel = NSTextField(labelWithString: "")
    private let coverView = NSImageView()

    var trackID: String = ""

    override func mouseDown(with event: NSEvent) {
        sendAction(action, to: target)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        applyCardStyle(cornerRadius: 8)
        applyBackground(Theme.cardBackground)

        coverView.wantsLayer = true
        coverView.layer?.cornerRadius = 6
        coverView.layer?.masksToBounds = true
        coverView.imageScaling = .scaleAxesIndependently
        coverView.translatesAutoresizingMaskIntoConstraints = false

        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = Theme.text
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = Theme.secondaryText
        subtitleLabel.lineBreakMode = .byTruncatingTail
        metaLabel.font = .systemFont(ofSize: 12, weight: .medium)
        metaLabel.textColor = Theme.accent

        addSubview(coverView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(metaLabel)

        [titleLabel, subtitleLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        metaLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 58),

            coverView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            coverView.centerYAnchor.constraint(equalTo: centerYAnchor),
            coverView.widthAnchor.constraint(equalToConstant: 38),
            coverView.heightAnchor.constraint(equalToConstant: 38),

            // 两行文字共用同一条起始线，始终与封面保持固定间距。
            titleLabel.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: 12),
            subtitleLabel.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: metaLabel.leadingAnchor, constant: -12),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: metaLabel.leadingAnchor, constant: -12),
            titleLabel.bottomAnchor.constraint(equalTo: centerYAnchor, constant: -1),
            subtitleLabel.topAnchor.constraint(equalTo: centerYAnchor, constant: 2),

            metaLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            metaLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(track: Track, index: Int, active: Bool, selected: Bool = false, selectionMode: Bool = false) {
        trackID = track.id
        titleLabel.stringValue = track.title
        subtitleLabel.stringValue = "\(track.artist) "
        metaLabel.stringValue = track.ext.uppercased()

        coverView.image =
            track.embeddedArtwork
            ?? track.artworkURL.flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)

        let dimmed = selectionMode && !selected
        let background: NSColor
        if active {
            background = Theme.rowPlaying
        } else if selected {
            background = Theme.rowSelected
        } else {
            background = Theme.cardBackground
        }
        applyBackground(background)

        alphaValue = dimmed ? 0.42 : 1.0
        titleLabel.textColor = dimmed ? Theme.disabledText : Theme.text
        subtitleLabel.textColor = dimmed ? Theme.tertiaryText : Theme.secondaryText
        metaLabel.textColor = dimmed ? Theme.tertiaryText : Theme.accent
    }
}
