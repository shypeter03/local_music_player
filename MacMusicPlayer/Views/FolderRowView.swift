import AppKit

final class FolderRowView: NSView {
    let removeButton = NSButton(title: "移除", target: nil, action: nil)

    init(folder: SourceFolder) {
        super.init(frame: .zero)
        applyCardStyle(cornerRadius: 8)
        applyBackground(Theme.cardBackground)
        translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: folder.name)
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        nameLabel.textColor = Theme.text
        let pathLabel = NSTextField(labelWithString: "\(folder.path) · \(folder.trackCount) 首")
        pathLabel.font = .systemFont(ofSize: 12)
        pathLabel.textColor = Theme.secondaryText
        pathLabel.lineBreakMode = .byTruncatingMiddle

        let textStack = NSStackView(views: [nameLabel, pathLabel])
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        removeButton.bezelStyle = .rounded
        removeButton.contentTintColor = Theme.destructive
        removeButton.translatesAutoresizingMaskIntoConstraints = false

        addSubview(textStack)
        addSubview(removeButton)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 64),
            textStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: removeButton.leadingAnchor, constant: -12),
            removeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            removeButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
