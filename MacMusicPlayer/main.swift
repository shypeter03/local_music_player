import AppKit
import AVFoundation

let audioExtensions: Set<String> = ["mp3", "m4a", "aac", "wav", "flac", "ogg"]
let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp"]

struct Track {
    let id: String
    let url: URL
    let folderURL: URL
    let title: String
    let artist: String
    let ext: String
    let artworkURL: URL?
    let lyricURL: URL?

    let embeddedArtwork: NSImage?
}

struct LyricLine {
    let time: TimeInterval
    let text: String
}

enum RepeatMode: Int {
    case off
    case all
    case one
}

struct MusicPlaylist: Codable {
    let id: String
    var name: String
    var trackIDs: [String]

    init(id: String = UUID().uuidString, name: String, trackIDs: [String] = []) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
    }
}

final class SourceFolder: Codable {
    let id: String
    let name: String
    let bookmark: Data?
    let path: String
    var trackCount: Int

    init(id: String = UUID().uuidString, url: URL, bookmark: Data?, trackCount: Int = 0) {
        self.id = id
        self.name = url.lastPathComponent
        self.bookmark = bookmark
        self.path = url.path
        self.trackCount = trackCount
    }

    func resolvedURL() -> URL {
        if let bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &stale) {
                return url
            }
        }
        return URL(fileURLWithPath: path)
    }
}

final class TrackRowView: NSControl {
    // private let indexLabel = NSTextField(labelWithString: "")
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
        wantsLayer = true
        layer?.cornerRadius = 8


        coverView.wantsLayer = true
        coverView.layer?.cornerRadius = 6
        coverView.layer?.masksToBounds = true
        coverView.imageScaling = .scaleAxesIndependently
        coverView.translatesAutoresizingMaskIntoConstraints = false


        layer?.backgroundColor = NSColor.systemPink.withAlphaComponent(0.10).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.font = .systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        metaLabel.font = .systemFont(ofSize: 12, weight: .medium)
        metaLabel.textColor = NSColor.systemPink

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(coverView)
        // addSubview(indexLabel)
        addSubview(textStack)
        addSubview(metaLabel)

        [coverView, metaLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 58),

            coverView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            coverView.centerYAnchor.constraint(equalTo: centerYAnchor),
            coverView.widthAnchor.constraint(equalToConstant: 38),
            coverView.heightAnchor.constraint(equalToConstant: 38),

            textStack.leadingAnchor.constraint(equalTo: coverView.trailingAnchor, constant: 12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: metaLabel.leadingAnchor, constant: -12),

            metaLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            metaLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(track: Track, index: Int, active: Bool, selected: Bool = false, selectionMode: Bool = false) {
        trackID = track.id
        // indexLabel.stringValue = selectionMode ? (selected ? "✓" : "") : "\(index)"
        titleLabel.stringValue = track.title
        subtitleLabel.stringValue = "\(track.artist) · \(track.folderURL.lastPathComponent)"
        metaLabel.stringValue = track.ext.uppercased()

        coverView.image =
        track.embeddedArtwork
        ?? track.artworkURL.flatMap {
            NSImage(contentsOf:$0)
        }
        ?? NSImage(
                systemSymbolName:"music.note",
                accessibilityDescription:nil
                )
        layer?.backgroundColor = (active || selected) ? NSColor.systemPink.withAlphaComponent(0.11).cgColor : NSColor.white.withAlphaComponent(0.72).cgColor
    }
}

final class FolderRowView: NSView {
    let removeButton = NSButton(title: "移除", target: nil, action: nil)

    init(folder: SourceFolder) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        layer?.backgroundColor = NSColor.systemPink.withAlphaComponent(0.10).cgColor
        translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: folder.name)
        nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        let pathLabel = NSTextField(labelWithString: "\(folder.path) · \(folder.trackCount) 首")
        pathLabel.font = .systemFont(ofSize: 12)
        pathLabel.textColor = .secondaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle

        let textStack = NSStackView(views: [nameLabel, pathLabel])
        textStack.orientation = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        removeButton.bezelStyle = .rounded
        removeButton.contentTintColor = .systemRed
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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let root = NSView()
    private let sidebar = NSVisualEffectView()
    private let content = NSView()
    private let libraryPage = NSView()
    private let foldersPage = NSView()
    private let playlistsPage = NSView()
    private let playerPage = NSView()
    private var pageConstraints: [ObjectIdentifier: [NSLayoutConstraint]] = [:]

    private let libraryButton = NSButton(title: "音乐列表", target: nil, action: nil)
    private let foldersButton = NSButton(title: "文件夹", target: nil, action: nil)
    private let playlistsButton = NSButton(title: "播放列表", target: nil, action: nil)
    private let addFolderButton = NSButton(title: "选择文件夹", target: nil, action: nil)
    private let rescanButton = NSButton(title: "重新扫描", target: nil, action: nil)
    private let backButton = NSButton(title: "‹ 返回资料库", target: nil, action: nil)
    private let selectTracksButton = NSButton(title: "选择", target: nil, action: nil)
    private let addSelectedButton = NSButton(title: "加入列表", target: nil, action: nil)

    private let searchField = NSSearchField()
    private let folderFilterPopup = NSPopUpButton()
    private let statusLabel = NSTextField(labelWithString: "待播放")
    private let libraryCountLabel = NSTextField(labelWithString: "0 首")
    private let selectionStatusLabel = NSTextField(labelWithString: "未选择")
    private let folderCountLabel = NSTextField(labelWithString: "0 个")
    private let playlistCountLabel = NSTextField(labelWithString: "0 个")
    private let selectedPlaylistTitle = NSTextField(labelWithString: "选择一个播放列表")
    private let selectedPlaylistCountLabel = NSTextField(labelWithString: "0 首")
    private let trackStack = NSStackView()
    private let recentStack = NSStackView()
    private let folderStack = NSStackView()
    private let playlistStack = NSStackView()
    private let playlistTrackStack = NSStackView()
    private let newPlaylistButton = NSButton(title: "新建列表", target: nil, action: nil)
    private let deletePlaylistButton = NSButton(title: "删除列表", target: nil, action: nil)

    private let miniPlayer = NSView()
    private let miniCover = NSImageView()
    private let miniTitle = NSTextField(labelWithString: "还没有播放歌曲")
    private let miniArtist = NSTextField(labelWithString: "从文件夹导入音乐开始")
    private let sideCurrentTime = NSTextField(labelWithString: "0:00")
    private let sideDuration = NSTextField(labelWithString: "0:00")
    private let sideSeek = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)

    private let nowCard = NSView()
    private let nowCover = NSImageView()
    private let nowTitle = NSTextField(labelWithString: "请选择一首歌")
    private let nowArtist = NSTextField(labelWithString: "支持 mp3、m4a、aac、wav、flac、ogg")
    private let miniCurrentTime = NSTextField(labelWithString: "0:00")
    private let miniDuration = NSTextField(labelWithString: "0:00")
    private let miniSeek = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)

    private let detailCover = NSImageView()
    private let detailTitle = NSTextField(labelWithString: "还没有播放歌曲")
    private let detailArtist = NSTextField(labelWithString: "在音乐列表中选择一首歌")
    private let detailFolder = NSTextField(labelWithString: "未选择来源")
    private let currentTime = NSTextField(labelWithString: "0:00")
    private let durationTime = NSTextField(labelWithString: "0:00")
    private let seekBar = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    private let lyricsStack = NSStackView()
    private let lyricsStatus = NSTextField(labelWithString: "自动匹配同名 .lrc")

    private let playButton = NSButton(title: "▶", target: nil, action: nil)
    private let prevButton = NSButton(title: "⏮", target: nil, action: nil)
    private let nextButton = NSButton(title: "⏭", target: nil, action: nil)
    private let detailPlayButton = NSButton(title: "▶", target: nil, action: nil)
    private let detailPrevButton = NSButton(title: "⏮", target: nil, action: nil)
    private let detailNextButton = NSButton(title: "⏭", target: nil, action: nil)
    private let shuffleButton = NSButton(title: "", target: nil, action: nil)
    private let repeatButton = NSButton(title: "", target: nil, action: nil)
    private let detailShuffleButton = NSButton(title: "", target: nil, action: nil)
    private let detailRepeatButton = NSButton(title: "", target: nil, action: nil)

    private var folders: [SourceFolder] = []
    private var playlists: [MusicPlaylist] = []
    private var tracks: [Track] = []
    private var filteredTracks: [Track] = []
    private var recentIDs: [String] = UserDefaults.standard.stringArray(forKey: "recentTracks") ?? []
    private var currentTrack: Track?
    private var currentIndex = -1
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private var lyrics: [LyricLine] = []
    private var lyricLabels: [NSTextField] = []
    private var selectedFolderID: String? = UserDefaults.standard.string(forKey: "selectedFolderID")
    private var selectedPlaylistID: String?
    private var selectedTrackIDs = Set<String>()
    private var isSelectingTracks = false
    private var isShuffleEnabled = UserDefaults.standard.bool(forKey: "shuffleEnabled")
    private var repeatMode = RepeatMode(rawValue: UserDefaults.standard.integer(forKey: "repeatMode")) ?? .off
    private var isAdvancingAtEnd = false

    func applicationSupportsSecureRestorableState(
        _ app: NSApplication
    ) -> Bool {
        return true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildWindow()
        buildSidebar()
        buildLibraryPage()
        buildFoldersPage()
        buildPlaylistsPage()
        buildPlayerPage()
        bindActions()
        loadFolders()
        loadPlaylists()
        showPage(libraryPage)
        scanFolders()
        showMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    private func showMainWindow() {
        if window == nil {
            buildWindow()
        }
        window.deminiaturize(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "本地音乐器"
        window.center()
        window.minSize = NSSize(width: 920, height: 620)
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1).cgColor
        window.contentView = root

        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        [sidebar, content].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview($0)
        }

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 300),

            content.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            content.topAnchor.constraint(equalTo: root.topAnchor),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
    }

    private func buildSidebar() {
        let brandIcon = roundedImageView(size: 48)
        brandIcon.image = symbolImage("music.note", pointSize: 26, color: .white)
        brandIcon.layer?.backgroundColor = NSColor.systemPink.cgColor

        let title = NSTextField(labelWithString: "本地音乐器")
        title.font = .systemFont(ofSize: 20, weight: .bold)
        let subtitle = NSTextField(labelWithString: "Local Music")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let titleStack = NSStackView(views: [title, subtitle])
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        let brand = NSStackView(views: [brandIcon, titleStack])
        brand.orientation = .horizontal
        brand.alignment = .centerY
        brand.spacing = 14

        configureNavButton(libraryButton, image: "music.note.list")
        configureNavButton(foldersButton, image: "folder")
        configureNavButton(playlistsButton, image: "music.note.house")

        configureMiniPlayer()

        let stack = NSStackView(views: [brand, libraryButton, foldersButton, playlistsButton, NSView(), miniPlayer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -24),
            brand.widthAnchor.constraint(equalTo: stack.widthAnchor),
            libraryButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            foldersButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            playlistsButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            miniPlayer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    private func configureMiniPlayer() {
        miniPlayer.wantsLayer = true
        miniPlayer.layer?.cornerRadius = 10
        miniPlayer.layer?.backgroundColor = NSColor.systemPink.withAlphaComponent(0.10).cgColor
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false

        miniCover.image = placeholderArtwork(size: 58)
        miniCover.imageScaling = .scaleAxesIndependently
        miniCover.wantsLayer = true
        miniCover.layer?.cornerRadius = 8
        miniCover.layer?.masksToBounds = true

        miniTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        miniTitle.lineBreakMode = .byTruncatingTail
        miniArtist.font = .systemFont(ofSize: 12)
        miniArtist.textColor = .secondaryLabelColor
        miniArtist.lineBreakMode = .byTruncatingTail
        [sideCurrentTime, sideDuration].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            $0.textColor = .secondaryLabelColor
            $0.alignment = .center
        }

        let meta = NSStackView(views: [miniTitle, miniArtist])
        meta.orientation = .vertical
        meta.spacing = 4
        let top = NSStackView(views: [miniCover, meta])
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 12

        let progress = NSStackView(views: [sideCurrentTime, sideSeek, sideDuration])
        progress.orientation = .horizontal
        progress.alignment = .centerY
        progress.spacing = 8
        let controls = NSStackView(views: [shuffleButton, prevButton, playButton, nextButton, repeatButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.distribution = .gravityAreas
        controls.spacing = 10
        [shuffleButton, prevButton, playButton, nextButton, repeatButton].forEach(configureIconButton)
        playButton.contentTintColor = .systemPink

        let stack = NSStackView(views: [top, progress, controls])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        miniPlayer.addSubview(stack)

        NSLayoutConstraint.activate([
            miniPlayer.heightAnchor.constraint(equalToConstant: 178),
            miniCover.widthAnchor.constraint(equalToConstant: 58),
            miniCover.heightAnchor.constraint(equalToConstant: 58),
            sideCurrentTime.widthAnchor.constraint(equalToConstant: 38),
            sideDuration.widthAnchor.constraint(equalToConstant: 38),
            stack.leadingAnchor.constraint(equalTo: miniPlayer.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: miniPlayer.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: miniPlayer.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: miniPlayer.bottomAnchor, constant: -14)
        ])

        miniPlayer.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(openPlayerFromCurrent)))
    }

    private func buildLibraryPage() {
        addPage(libraryPage)

        let header = makeHeader(eyebrow: "Library", title: "音乐列表")
        searchField.placeholderString = "搜索歌名、艺术家、文件夹"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        folderFilterPopup.translatesAutoresizingMaskIntoConstraints = false
        folderFilterPopup.bezelStyle = .rounded
        let refresh = NSButton(title: "刷新扫描", target: self, action: #selector(scanFoldersAction))
        refresh.bezelStyle = .rounded
        let headerActions = NSStackView(views: [folderFilterPopup, searchField, refresh])
        headerActions.orientation = .horizontal
        headerActions.spacing = 10

        let top = NSStackView(views: [header, headerActions])
        top.orientation = .horizontal
        top.alignment = .bottom
        top.distribution = .gravityAreas
        top.translatesAutoresizingMaskIntoConstraints = false
        libraryPage.addSubview(top)

        let nowPanel = makePanel(title: "当前播放", trailing: statusLabel)
        configureNowCard()
        nowPanel.addArrangedSubview(nowCard)

        let recentPanel = makePanel(title: "最近播放", trailing: makeSmallButton("清空", action: #selector(clearRecent)))
        configureStack(recentStack)
        recentPanel.addArrangedSubview(recentStack)

        selectTracksButton.bezelStyle = .rounded
        addSelectedButton.bezelStyle = .rounded
        addSelectedButton.contentTintColor = .systemPink
        selectionStatusLabel.font = .systemFont(ofSize: 12)
        selectionStatusLabel.textColor = .secondaryLabelColor
        let libraryTools = NSStackView(views: [selectionStatusLabel, libraryCountLabel, selectTracksButton, addSelectedButton])
        libraryTools.orientation = .horizontal
        libraryTools.alignment = .centerY
        libraryTools.spacing = 10
        let libraryPanel = makePanel(title: "歌曲", trailing: libraryTools)
        configureStack(trackStack)
        let scroll = scrollView(containing: trackStack)
        libraryPanel.addArrangedSubview(scroll)

        let dashboard = NSStackView(views: [nowPanel, recentPanel])
        dashboard.orientation = .horizontal
        dashboard.spacing = 18
        dashboard.distribution = .fillEqually
        dashboard.translatesAutoresizingMaskIntoConstraints = false

        libraryPage.addSubview(dashboard)
        libraryPage.addSubview(libraryPanel)

        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: libraryPage.leadingAnchor, constant: 34),
            top.trailingAnchor.constraint(equalTo: libraryPage.trailingAnchor, constant: -34),
            top.topAnchor.constraint(equalTo: libraryPage.topAnchor, constant: 34),
            folderFilterPopup.widthAnchor.constraint(equalToConstant: 180),
            searchField.widthAnchor.constraint(equalToConstant: 280),

            dashboard.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            dashboard.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            dashboard.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 24),
            dashboard.heightAnchor.constraint(equalToConstant: 210),

            libraryPanel.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            libraryPanel.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            libraryPanel.topAnchor.constraint(equalTo: dashboard.bottomAnchor, constant: 18),
            libraryPanel.bottomAnchor.constraint(equalTo: libraryPage.bottomAnchor, constant: -34)
        ])
    }

    private func configureNowCard() {
        nowCard.wantsLayer = true
        nowCard.layer?.cornerRadius = 10
        nowCard.layer?.backgroundColor = NSColor.systemPink.cgColor
        nowCover.image = placeholderArtwork(size: 112)
        nowCover.imageScaling = .scaleAxesIndependently
        nowCover.wantsLayer = true
        nowCover.layer?.cornerRadius = 8
        nowCover.layer?.masksToBounds = true

        nowTitle.font = .systemFont(ofSize: 18, weight: .bold)
        nowArtist.font = .systemFont(ofSize: 13)
        nowArtist.textColor = .secondaryLabelColor
        [miniCurrentTime, miniDuration].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            $0.textColor = .secondaryLabelColor
        }

        let meta = NSStackView(views: [nowTitle, nowArtist])
        meta.orientation = .vertical
        meta.spacing = 6
        let progress = NSStackView(views: [miniCurrentTime, miniSeek, miniDuration])
        progress.orientation = .horizontal
        progress.alignment = .centerY
        progress.spacing = 8
        let right = NSStackView(views: [meta, progress])
        right.orientation = .vertical
        right.spacing = 20
        let row = NSStackView(views: [nowCover, right])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 16
        row.translatesAutoresizingMaskIntoConstraints = false
        nowCard.addSubview(row)

        NSLayoutConstraint.activate([
            nowCover.widthAnchor.constraint(equalToConstant: 112),
            nowCover.heightAnchor.constraint(equalToConstant: 112),
            miniCurrentTime.widthAnchor.constraint(equalToConstant: 42),
            miniDuration.widthAnchor.constraint(equalToConstant: 42),
            row.leadingAnchor.constraint(equalTo: nowCard.leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(equalTo: nowCard.trailingAnchor, constant: -12),
            row.topAnchor.constraint(equalTo: nowCard.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: nowCard.bottomAnchor, constant: -12)
        ])

        nowCard.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(openPlayerFromCurrent)))
    }

    private func buildFoldersPage() {
        addPage(foldersPage)

        let header = makeHeader(eyebrow: "Sources", title: "文件夹管理")
        configurePrimaryButton(addFolderButton)
        rescanButton.bezelStyle = .rounded
        let actions = NSStackView(views: [addFolderButton, rescanButton])
        actions.orientation = .horizontal
        actions.spacing = 10

        let top = NSStackView(views: [header, actions])
        top.orientation = .horizontal
        top.alignment = .bottom
        top.distribution = .gravityAreas
        top.translatesAutoresizingMaskIntoConstraints = false

        let intro = makePanel(title: "可同时引入本地文件夹和 iCloud 文件夹", trailing: nil)
        let introText = NSTextField(labelWithString: "可一次选择多个文件夹，也可多次添加。iCloud Drive 中已同步到本机的音乐文件会被扫描。")
        introText.textColor = .secondaryLabelColor
        introText.lineBreakMode = .byWordWrapping
        intro.addArrangedSubview(introText)

        let folderPanel = makePanel(title: "已引入文件夹", trailing: folderCountLabel)
        configureStack(folderStack)
        folderPanel.addArrangedSubview(scrollView(containing: folderStack))

        foldersPage.addSubview(top)
        foldersPage.addSubview(intro)
        foldersPage.addSubview(folderPanel)

        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: foldersPage.leadingAnchor, constant: 34),
            top.trailingAnchor.constraint(equalTo: foldersPage.trailingAnchor, constant: -34),
            top.topAnchor.constraint(equalTo: foldersPage.topAnchor, constant: 34),

            intro.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            intro.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            intro.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 24),

            folderPanel.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            folderPanel.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            folderPanel.topAnchor.constraint(equalTo: intro.bottomAnchor, constant: 18),
            folderPanel.bottomAnchor.constraint(equalTo: foldersPage.bottomAnchor, constant: -34)
        ])
    }

    private func buildPlaylistsPage() {
        addPage(playlistsPage)

        let header = makeHeader(eyebrow: "Playlists", title: "播放列表")
        configurePrimaryButton(newPlaylistButton)
        deletePlaylistButton.bezelStyle = .rounded
        deletePlaylistButton.contentTintColor = .systemRed
        let actions = NSStackView(views: [newPlaylistButton, deletePlaylistButton])
        actions.orientation = .horizontal
        actions.spacing = 10

        let top = NSStackView(views: [header, actions])
        top.orientation = .horizontal
        top.alignment = .bottom
        top.distribution = .gravityAreas
        top.translatesAutoresizingMaskIntoConstraints = false

        let listPanel = makePanel(title: "列表", trailing: playlistCountLabel)
        configureStack(playlistStack)
        listPanel.addArrangedSubview(scrollView(containing: playlistStack))

        let titleStack = NSStackView(views: [selectedPlaylistTitle, selectedPlaylistCountLabel])
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        selectedPlaylistTitle.font = .systemFont(ofSize: 16, weight: .bold)
        selectedPlaylistCountLabel.font = .systemFont(ofSize: 12)
        selectedPlaylistCountLabel.textColor = .secondaryLabelColor
        let tracksPanel = makePanel(title: "歌曲", trailing: titleStack)
        configureStack(playlistTrackStack)
        tracksPanel.addArrangedSubview(scrollView(containing: playlistTrackStack))

        playlistsPage.addSubview(top)
        playlistsPage.addSubview(listPanel)
        playlistsPage.addSubview(tracksPanel)

        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: playlistsPage.leadingAnchor, constant: 34),
            top.trailingAnchor.constraint(equalTo: playlistsPage.trailingAnchor, constant: -34),
            top.topAnchor.constraint(equalTo: playlistsPage.topAnchor, constant: 34),

            listPanel.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            listPanel.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 24),
            listPanel.bottomAnchor.constraint(equalTo: playlistsPage.bottomAnchor, constant: -34),
            listPanel.widthAnchor.constraint(equalTo: playlistsPage.widthAnchor, multiplier: 0.34),

            tracksPanel.leadingAnchor.constraint(equalTo: listPanel.trailingAnchor, constant: 18),
            tracksPanel.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            tracksPanel.topAnchor.constraint(equalTo: listPanel.topAnchor),
            tracksPanel.bottomAnchor.constraint(equalTo: listPanel.bottomAnchor)
        ])
    }

    private func buildPlayerPage() {
        addPage(playerPage)
        backButton.bezelStyle = .inline
        backButton.contentTintColor = .systemPink
        backButton.translatesAutoresizingMaskIntoConstraints = false

        let albumPanel = NSStackView()
        albumPanel.orientation = .vertical
        albumPanel.alignment = .centerX
        albumPanel.spacing = 18
        albumPanel.wantsLayer = true
        albumPanel.layer?.cornerRadius = 12
        albumPanel.layer?.backgroundColor = NSColor.systemPink.cgColor
        albumPanel.translatesAutoresizingMaskIntoConstraints = false

        detailCover.image = placeholderArtwork(size: 360)
        detailCover.imageScaling = .scaleAxesIndependently
        detailCover.wantsLayer = true
        detailCover.layer?.cornerRadius = 12
        detailCover.layer?.masksToBounds = true

        detailTitle.font = .systemFont(ofSize: 30, weight: .bold)
        detailTitle.alignment = .center
        detailTitle.lineBreakMode = .byTruncatingTail
        detailArtist.font = .systemFont(ofSize: 15)
        detailArtist.textColor = .secondaryLabelColor
        detailArtist.alignment = .center
        detailFolder.font = .systemFont(ofSize: 12)
        detailFolder.textColor = .secondaryLabelColor
        detailFolder.alignment = .center
        detailFolder.lineBreakMode = .byTruncatingMiddle

        let controls = NSStackView(views: [detailShuffleButton, detailPrevButton, detailPlayButton, detailNextButton, detailRepeatButton])
        controls.orientation = .horizontal
        controls.spacing = 14
        [detailShuffleButton, detailPrevButton, detailPlayButton, detailNextButton, detailRepeatButton].forEach(configureIconButton)
        detailPlayButton.contentTintColor = .systemPink

        [currentTime, durationTime].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            $0.textColor = .secondaryLabelColor
        }
        let seek = NSStackView(views: [currentTime, seekBar, durationTime])
        seek.orientation = .horizontal
        seek.alignment = .centerY
        seek.spacing = 8

        [detailCover, detailTitle, detailArtist, detailFolder, controls, seek].forEach { albumPanel.addArrangedSubview($0) }

        let lyricsPanel = makePanel(title: "歌词", trailing: lyricsStatus)
        configureStack(lyricsStack)
        lyricsPanel.addArrangedSubview(scrollView(containing: lyricsStack))

        playerPage.addSubview(backButton)
        playerPage.addSubview(albumPanel)
        playerPage.addSubview(lyricsPanel)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: playerPage.leadingAnchor, constant: 34),
            backButton.topAnchor.constraint(equalTo: playerPage.topAnchor, constant: 28),

            albumPanel.leadingAnchor.constraint(equalTo: playerPage.leadingAnchor, constant: 34),
            albumPanel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            albumPanel.bottomAnchor.constraint(equalTo: playerPage.bottomAnchor, constant: -34),
            albumPanel.widthAnchor.constraint(equalTo: playerPage.widthAnchor, multiplier: 0.42),

            detailCover.widthAnchor.constraint(equalToConstant: 360),
            detailCover.heightAnchor.constraint(equalToConstant: 360),
            seek.widthAnchor.constraint(equalTo: albumPanel.widthAnchor, constant: -56),
            currentTime.widthAnchor.constraint(equalToConstant: 42),
            durationTime.widthAnchor.constraint(equalToConstant: 42),

            lyricsPanel.leadingAnchor.constraint(equalTo: albumPanel.trailingAnchor, constant: 22),
            lyricsPanel.trailingAnchor.constraint(equalTo: playerPage.trailingAnchor, constant: -34),
            lyricsPanel.topAnchor.constraint(equalTo: albumPanel.topAnchor),
            lyricsPanel.bottomAnchor.constraint(equalTo: albumPanel.bottomAnchor)
        ])
    }

    private func addPage(_ page: NSView) {
        page.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(page)
        let constraints = [
            page.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            page.topAnchor.constraint(equalTo: content.topAnchor),
            page.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ]
        pageConstraints[ObjectIdentifier(page)] = constraints
        NSLayoutConstraint.activate(constraints)
    }

    private func bindActions() {
        libraryButton.target = self
        libraryButton.action = #selector(showLibrary)
        foldersButton.target = self
        foldersButton.action = #selector(showFolders)
        playlistsButton.target = self
        playlistsButton.action = #selector(showPlaylists)
        addFolderButton.target = self
        addFolderButton.action = #selector(addFolders)
        rescanButton.target = self
        rescanButton.action = #selector(scanFoldersAction)
        backButton.target = self
        backButton.action = #selector(showLibrary)
        selectTracksButton.target = self
        selectTracksButton.action = #selector(toggleTrackSelection)
        addSelectedButton.target = self
        addSelectedButton.action = #selector(addSelectedTracksToPlaylist)
        newPlaylistButton.target = self
        newPlaylistButton.action = #selector(createPlaylist)
        deletePlaylistButton.target = self
        deletePlaylistButton.action = #selector(deleteSelectedPlaylist)
        searchField.target = self
        searchField.action = #selector(searchChanged)
        folderFilterPopup.target = self
        folderFilterPopup.action = #selector(folderFilterChanged)
        playButton.target = self
        playButton.action = #selector(togglePlay)
        detailPlayButton.target = self
        detailPlayButton.action = #selector(togglePlay)
        prevButton.target = self
        prevButton.action = #selector(playPrevious)
        detailPrevButton.target = self
        detailPrevButton.action = #selector(playPrevious)
        nextButton.target = self
        nextButton.action = #selector(playNext)
        detailNextButton.target = self
        detailNextButton.action = #selector(playNext)
        shuffleButton.target = self
        shuffleButton.action = #selector(toggleShuffle)
        detailShuffleButton.target = self
        detailShuffleButton.action = #selector(toggleShuffle)
        repeatButton.target = self
        repeatButton.action = #selector(cycleRepeatMode)
        detailRepeatButton.target = self
        detailRepeatButton.action = #selector(cycleRepeatMode)
        [sideSeek, miniSeek, seekBar].forEach {
            $0.target = self
            $0.action = #selector(seekChanged(_:))
        }
        updatePlaybackModeButtons()
    }

    @objc private func showLibrary() { showPage(libraryPage) }
    @objc private func showFolders() { showPage(foldersPage) }
    @objc private func showPlaylists() { showPage(playlistsPage) }
    @objc private func openPlayerFromCurrent() {
        if currentTrack == nil, let first = tracks.first {
            play(track: first)
        }
        showPage(playerPage)
    }

    private func showPage(_ page: NSView) {
        for view in [libraryPage, foldersPage, playlistsPage, playerPage] {
            let constraints = pageConstraints[ObjectIdentifier(view)] ?? []
            if view === page {
                NSLayoutConstraint.activate(constraints)
                view.isHidden = false
            } else {
                view.isHidden = true
                NSLayoutConstraint.deactivate(constraints)
            }
        }
        libraryButton.state = page === libraryPage ? .on : .off
        foldersButton.state = page === foldersPage ? .on : .off
        playlistsButton.state = page === playlistsPage ? .on : .off
    }

    @objc private func addFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "选择"
        if panel.runModal() == .OK {
            for url in panel.urls {
                let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
                if folders.contains(where: { $0.path == url.path }) { continue }
                folders.append(SourceFolder(url: url, bookmark: bookmark))
            }
            saveFolders()
            scanFolders()
            showPage(foldersPage)
        }
    }

    @objc private func scanFoldersAction() { scanFolders() }

    private func scanFolders() {
        statusLabel.stringValue = "正在扫描…"
        var nextTracks: [Track] = []
        for folder in folders {
            let url = folder.resolvedURL()
            _ = url.startAccessingSecurityScopedResource()
            let scanned = scan(folder: folder, url: url)
            url.stopAccessingSecurityScopedResource()
            folder.trackCount = scanned.count
            nextTracks.append(contentsOf: scanned)
        }
        tracks = nextTracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        saveFolders()
        if let selectedFolderID, !folders.contains(where: { $0.id == selectedFolderID }) {
            self.selectedFolderID = nil
            UserDefaults.standard.removeObject(forKey: "selectedFolderID")
        }
        renderFolderFilter()
        applySearch()
        renderFolders()
        renderPlaylists()
        statusLabel.stringValue = tracks.isEmpty ? "没有扫描到音乐" : "已载入 \(tracks.count) 首"
    }

    private func scan(folder: SourceFolder, url: URL) -> [Track] {
        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: resourceKeys, options: [.skipsHiddenFiles]) else {
            return []
        }

        var audioURLs: [URL] = []
        var lyricByBase: [String: URL] = [:]
        var imageByBase: [String: URL] = [:]
        var coverByFolder: [String: URL] = [:]

        for case let item as URL in enumerator {
            let ext = item.pathExtension.lowercased()
            if audioExtensions.contains(ext) {
                audioURLs.append(item)
            } else if ext == "lrc" {
                lyricByBase[item.deletingPathExtension().path.lowercased()] = item
            } else if imageExtensions.contains(ext) {
                imageByBase[item.deletingPathExtension().path.lowercased()] = item
                let name = item.deletingPathExtension().lastPathComponent.lowercased()
                if ["cover", "folder", "album"].contains(name) {
                    coverByFolder[item.deletingLastPathComponent().path.lowercased()] = item
                }
            }
        }

        return audioURLs.map { fileURL in
            let parsed = parseName(fileURL.deletingPathExtension().lastPathComponent)
            let base = fileURL.deletingPathExtension().path.lowercased()
            let folderPath = fileURL.deletingLastPathComponent().path.lowercased()
            return Track(
                id: "\(folder.id):\(fileURL.path)",
                url: fileURL,
                folderURL: url,
                title: parsed.title,
                artist: parsed.artist,
                ext: fileURL.pathExtension,
                artworkURL: imageByBase[base] ?? coverByFolder[folderPath],
                lyricURL: lyricByBase[base],

                embeddedArtwork: loadEmbeddedArtwork(fileURL)
            )
        }
    }

    private func parseName(_ name: String) -> (artist: String, title: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let parts = name.components(separatedBy: " - ")
        print("Paringing name: \(name),parts:\(parts)")
        if parts.count >= 2 {
            let artist = parts[0]
                .trimmingCharacters(in: .whitespacesAndNewlines)

                let title = parts.dropFirst()
                .joined(separator: " - ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

                return (artist, title)
        }
        return ("未知艺术家", cleanName)
    }

    @objc private func searchChanged() {
        applySearch()
    }

    @objc private func folderFilterChanged() {
        selectedFolderID = folderFilterPopup.selectedItem?.representedObject as? String
        if let selectedFolderID {
            UserDefaults.standard.set(selectedFolderID, forKey: "selectedFolderID")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedFolderID")
        }
        applySearch()
    }

    private func applySearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scopedTracks: [Track]
        if let selectedFolderID {
            scopedTracks = tracks.filter { $0.id.hasPrefix("\(selectedFolderID):") }
        } else {
            scopedTracks = tracks
        }

        if query.isEmpty {
            filteredTracks = scopedTracks
        } else {
            filteredTracks = scopedTracks.filter {
                "\($0.title) \($0.artist) \($0.folderURL.lastPathComponent) \($0.url.lastPathComponent)".lowercased().contains(query)
            }
        }
        renderTracks()
        renderRecent()
    }

    private func renderTracks() {
        libraryCountLabel.stringValue = "\(filteredTracks.count) 首"
        updateSelectionControls()
        clear(trackStack)
        if filteredTracks.isEmpty {
            trackStack.addArrangedSubview(emptyLabel("还没有音乐。前往“文件夹”页面选择本地或 iCloud 文件夹。"))
            return
        }
        for (index, track) in filteredTracks.enumerated() {
            let row = TrackRowView()
            row.configure(
                track: track,
                index: index + 1,
                active: track.id == currentTrack?.id,
                selected: selectedTrackIDs.contains(track.id),
                selectionMode: isSelectingTracks
            )
            row.target = self
            row.action = #selector(trackRowClicked(_:))
            trackStack.addArrangedSubview(row)
        }
    }

    private func renderRecent() {
        clear(recentStack)
        let recent = recentIDs.compactMap { id in tracks.first(where: { $0.id == id }) }.prefix(5)
        if recent.isEmpty {
            recentStack.addArrangedSubview(emptyLabel("播放后会出现在这里"))
            return
        }
        for track in recent {
            let row = TrackRowView()
            row.configure(track: track, index: 0, active: false)
            row.target = self
            row.action = #selector(trackRowClicked(_:))
            recentStack.addArrangedSubview(row)
        }
    }

    private func renderFolders() {
        folderCountLabel.stringValue = "\(folders.count) 个"
        renderFolderFilter()
        clear(folderStack)
        if folders.isEmpty {
            folderStack.addArrangedSubview(emptyLabel("尚未添加文件夹，可一次选择多个本地和 iCloud 文件夹。"))
            return
        }
        for folder in folders {
            let row = FolderRowView(folder: folder)
            row.removeButton.target = self
            row.removeButton.action = #selector(removeFolder(_:))
            row.removeButton.identifier = NSUserInterfaceItemIdentifier(folder.id)
            folderStack.addArrangedSubview(row)
        }
    }

    private func renderPlaylists() {
        playlistCountLabel.stringValue = "\(playlists.count) 个"
        clear(playlistStack)
        if playlists.isEmpty {
            playlistStack.addArrangedSubview(emptyLabel("还没有播放列表。点击“新建列表”创建一个。"))
        } else {
            for playlist in playlists {
                let row = NSButton(title: "\(playlist.name) · \(playlist.trackIDs.count) 首", target: self, action: #selector(playlistClicked(_:)))
                row.bezelStyle = .regularSquare
                row.isBordered = false
                row.alignment = .left
                row.font = .systemFont(ofSize: 14, weight: playlist.id == selectedPlaylistID ? .bold : .regular)
                row.contentTintColor = playlist.id == selectedPlaylistID ? .systemPink : .labelColor
                row.identifier = NSUserInterfaceItemIdentifier(playlist.id)
                row.translatesAutoresizingMaskIntoConstraints = false
                row.heightAnchor.constraint(equalToConstant: 44).isActive = true
                playlistStack.addArrangedSubview(row)
            }
        }
        renderSelectedPlaylistTracks()
    }

    private func renderSelectedPlaylistTracks() {
        clear(playlistTrackStack)
        guard let playlist = selectedPlaylist() else {
            selectedPlaylistTitle.stringValue = "选择一个播放列表"
            selectedPlaylistCountLabel.stringValue = "0 首"
            playlistTrackStack.addArrangedSubview(emptyLabel("在左侧选择一个播放列表查看歌曲。"))
            deletePlaylistButton.isEnabled = false
            return
        }

        deletePlaylistButton.isEnabled = true
        let playlistTracks = playlist.trackIDs.compactMap { id in tracks.first(where: { $0.id == id }) }
        selectedPlaylistTitle.stringValue = playlist.name
        selectedPlaylistCountLabel.stringValue = "\(playlistTracks.count) 首"
        if playlistTracks.isEmpty {
            playlistTrackStack.addArrangedSubview(emptyLabel("这个播放列表还没有可用歌曲。可在音乐列表中选择歌曲加入。"))
            return
        }

        for (index, track) in playlistTracks.enumerated() {
            let row = TrackRowView()
            row.configure(track: track, index: index + 1, active: track.id == currentTrack?.id)
            row.target = self
            row.action = #selector(trackRowClicked(_:))
            playlistTrackStack.addArrangedSubview(row)
        }
    }

    private func renderFolderFilter() {
        let currentSelection = selectedFolderID
        folderFilterPopup.removeAllItems()
        folderFilterPopup.addItem(withTitle: "全部文件夹")
        folderFilterPopup.item(at: 0)?.representedObject = nil

        for folder in folders {
            folderFilterPopup.addItem(withTitle: folder.name)
            folderFilterPopup.lastItem?.representedObject = folder.id
        }

        if let currentSelection,
           folders.contains(where: { $0.id == currentSelection }),
           let index = folderFilterPopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == currentSelection }) {
            folderFilterPopup.selectItem(at: index)
            selectedFolderID = currentSelection
        } else {
            folderFilterPopup.selectItem(at: 0)
            selectedFolderID = nil
        }
    }

    private func selectedPlaylist() -> MusicPlaylist? {
        guard let selectedPlaylistID else { return nil }
        return playlists.first { $0.id == selectedPlaylistID }
    }

    private func updateSelectionControls() {
        selectTracksButton.title = isSelectingTracks ? "完成" : "选择"
        selectionStatusLabel.stringValue = isSelectingTracks ? "已选择 \(selectedTrackIDs.count) 首" : "未选择"
        addSelectedButton.isEnabled = isSelectingTracks && !selectedTrackIDs.isEmpty
    }

    @objc private func removeFolder(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        folders.removeAll { $0.id == id }
        tracks.removeAll { $0.id.hasPrefix("\(id):") }
        if selectedFolderID == id {
            selectedFolderID = nil
            UserDefaults.standard.removeObject(forKey: "selectedFolderID")
        }
        saveFolders()
        scanFolders()
    }

    @objc private func trackRowClicked(_ sender: TrackRowView) {
        print("clicked:", sender.trackID)
        guard let track = tracks.first(where: { $0.id == sender.trackID }) else { return }
        if isSelectingTracks {
            if selectedTrackIDs.contains(track.id) {
                selectedTrackIDs.remove(track.id)
            } else {
                selectedTrackIDs.insert(track.id)
            }
            renderTracks()
            return
        }
        play(track: track)
    }

    @objc private func toggleTrackSelection() {
        isSelectingTracks.toggle()
        if !isSelectingTracks {
            selectedTrackIDs.removeAll()
        }
        renderTracks()
    }

    @objc private func addSelectedTracksToPlaylist() {
        guard !selectedTrackIDs.isEmpty else { return }
        if playlists.isEmpty {
            guard let playlist = promptForPlaylistName() else { return }
            playlists.append(playlist)
            selectedPlaylistID = playlist.id
        }

        guard let playlistID = choosePlaylistIDForAdding() else { return }
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        let orderedSelection = filteredTracks.map(\.id).filter { selectedTrackIDs.contains($0) }
        for id in orderedSelection where !playlists[index].trackIDs.contains(id) {
            playlists[index].trackIDs.append(id)
        }
        selectedPlaylistID = playlists[index].id
        savePlaylists()
        selectedTrackIDs.removeAll()
        isSelectingTracks = false
        renderTracks()
        renderPlaylists()
        showPage(playlistsPage)
    }

    @objc private func createPlaylist() {
        guard let playlist = promptForPlaylistName() else { return }
        playlists.append(playlist)
        selectedPlaylistID = playlist.id
        savePlaylists()
        renderPlaylists()
        showPage(playlistsPage)
    }

    @objc private func deleteSelectedPlaylist() {
        guard let selectedPlaylistID,
              let index = playlists.firstIndex(where: { $0.id == selectedPlaylistID })
        else { return }
        let alert = NSAlert()
        alert.messageText = "删除播放列表？"
        alert.informativeText = "不会删除原始音乐文件，只会移除这个列表。"
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        playlists.remove(at: index)
        self.selectedPlaylistID = playlists.first?.id
        savePlaylists()
        renderPlaylists()
    }

    @objc private func playlistClicked(_ sender: NSButton) {
        selectedPlaylistID = sender.identifier?.rawValue
        renderPlaylists()
    }

    private func promptForPlaylistName() -> MusicPlaylist? {
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        field.placeholderString = "例如：通勤、收藏、练习"
        let alert = NSAlert()
        alert.messageText = "新建播放列表"
        alert.informativeText = "输入一个列表名称。"
        alert.accessoryView = field
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return MusicPlaylist(name: name)
    }

    private func choosePlaylistIDForAdding() -> String? {
        if playlists.count == 1 {
            return playlists[0].id
        }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 28))
        for playlist in playlists {
            popup.addItem(withTitle: playlist.name)
            popup.lastItem?.representedObject = playlist.id
        }
        if let selectedPlaylistID,
           let index = popup.itemArray.firstIndex(where: { ($0.representedObject as? String) == selectedPlaylistID }) {
            popup.selectItem(at: index)
        }

        let alert = NSAlert()
        alert.messageText = "加入播放列表"
        alert.informativeText = "选择要加入的列表。"
        alert.accessoryView = popup
        alert.addButton(withTitle: "加入")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return popup.selectedItem?.representedObject as? String
    }

    private func play(track: Track) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            currentTrack = track
            currentIndex = tracks.firstIndex(where: { $0.id == track.id }) ?? -1
            isAdvancingAtEnd = false
            addRecent(track.id)
            loadLyrics(for: track)
            updateCurrentUI()
            startTimer()
        } catch {
            statusLabel.stringValue = "播放失败"
        }
    }

    @objc private func togglePlay() {
        if audioPlayer == nil, let first = tracks.first {
            play(track: first)
            return
        }
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        updatePlayButtons()
    }

    @objc private func playPrevious() { playByOffset(-1) }
    @objc private func playNext() { playByOffset(1) }

    @objc private func toggleShuffle() {
        isShuffleEnabled.toggle()
        UserDefaults.standard.set(isShuffleEnabled, forKey: "shuffleEnabled")
        updatePlaybackModeButtons()
    }

    @objc private func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
        updatePlaybackModeButtons()
    }

    private func playByOffset(_ offset: Int) {
        guard let next = nextTrack(offset: offset, allowStopAtEnd: false) else { return }
        play(track: next)
    }

    private func nextTrack(offset: Int, allowStopAtEnd: Bool) -> Track? {
        let queue = playbackQueue()
        guard !queue.isEmpty else { return nil }

        if isShuffleEnabled, queue.count > 1 {
            var candidates = queue
            if let currentTrack {
                candidates.removeAll { $0.id == currentTrack.id }
            }
            return candidates.randomElement() ?? queue.randomElement()
        }

        let base = currentTrack.flatMap { track in queue.firstIndex(where: { $0.id == track.id }) } ?? (offset > 0 ? -1 : 0)
        let proposed = base + offset
        if allowStopAtEnd, repeatMode == .off, (proposed < 0 || proposed >= queue.count) {
            return nil
        }
        return queue[(proposed + queue.count) % queue.count]
    }

    private func playbackQueue() -> [Track] {
        if !playlistsPage.isHidden, let playlist = selectedPlaylist() {
            let playlistTracks = playlist.trackIDs.compactMap { id in tracks.first(where: { $0.id == id }) }
            if !playlistTracks.isEmpty {
                return playlistTracks
            }
        }
        if !filteredTracks.isEmpty {
            return filteredTracks
        }
        if let selectedFolderID {
            return tracks.filter { $0.id.hasPrefix("\(selectedFolderID):") }
        }
        return tracks
    }

    private func advanceAfterTrackEnded() {
        guard !isAdvancingAtEnd else { return }
        isAdvancingAtEnd = true

        if repeatMode == .one, let player = audioPlayer {
            player.currentTime = 0
            player.play()
            isAdvancingAtEnd = false
            updateProgress()
            return
        }

        guard let next = nextTrack(offset: 1, allowStopAtEnd: true) else {
            audioPlayer?.currentTime = 0
            updatePlayButtons()
            updateProgress()
            isAdvancingAtEnd = false
            return
        }
        play(track: next)
    }

    @objc private func seekChanged(_ sender: NSSlider) {
        guard let player = audioPlayer, player.duration > 0 else { return }
        isAdvancingAtEnd = false
        player.currentTime = (sender.doubleValue / 100) * player.duration
        updateProgress()
    }

    private func addRecent(_ id: String) {
        recentIDs.removeAll { $0 == id }
        recentIDs.insert(id, at: 0)
        recentIDs = Array(recentIDs.prefix(20))
        UserDefaults.standard.set(recentIDs, forKey: "recentTracks")
    }

    @objc private func clearRecent() {
        recentIDs = []
        UserDefaults.standard.removeObject(forKey: "recentTracks")
        renderRecent()
    }

    private func updateCurrentUI() {
        guard let track = currentTrack else { return }
        miniTitle.stringValue = track.title
        nowTitle.stringValue = track.title
        detailTitle.stringValue = track.title
        miniArtist.stringValue = track.artist
        nowArtist.stringValue = "\(track.artist) · \(track.ext.uppercased())"
        detailArtist.stringValue = track.artist
        detailFolder.stringValue = "\(track.folderURL.lastPathComponent) / \(track.url.lastPathComponent)"

        let image = artwork(for: track)
        [miniCover, nowCover, detailCover].forEach { $0.image = image }
        updatePlayButtons()
        updateProgress()
        renderTracks()
        renderRecent()
        renderSelectedPlaylistTracks()
    }

    private func updatePlayButtons() {
        let title = audioPlayer?.isPlaying == true ? "⏸" : "▶"
        playButton.title = title
        detailPlayButton.title = title
    }

    private func updatePlaybackModeButtons() {
        [shuffleButton, detailShuffleButton].forEach {
            $0.image = symbolImage("shuffle", pointSize: 15, color: isShuffleEnabled ? .systemPink : .secondaryLabelColor)
            $0.toolTip = isShuffleEnabled ? "随机播放已开启" : "随机播放"
            $0.contentTintColor = isShuffleEnabled ? .systemPink : .secondaryLabelColor
        }

        let repeatSymbol = repeatMode == .one ? "repeat.1" : "repeat"
        let repeatColor: NSColor = repeatMode == .off ? .secondaryLabelColor : .systemPink
        let repeatTip: String
        switch repeatMode {
        case .off:
            repeatTip = "循环关闭"
        case .all:
            repeatTip = "列表循环"
        case .one:
            repeatTip = "单曲循环"
        }
        [repeatButton, detailRepeatButton].forEach {
            $0.image = symbolImage(repeatSymbol, pointSize: 15, color: repeatColor)
            $0.toolTip = repeatTip
            $0.contentTintColor = repeatColor
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    private func updateProgress() {
        guard let player = audioPlayer else {
            [currentTime, miniCurrentTime, sideCurrentTime].forEach { $0.stringValue = "0:00" }
            [durationTime, miniDuration, sideDuration].forEach { $0.stringValue = "0:00" }
            [seekBar, miniSeek, sideSeek].forEach { $0.doubleValue = 0 }
            return
        }
        if player.duration > 0 {
            let percent = (player.currentTime / player.duration) * 100
            [seekBar, miniSeek, sideSeek].forEach { $0.doubleValue = percent }
        }
        [currentTime, miniCurrentTime, sideCurrentTime].forEach { $0.stringValue = formatTime(player.currentTime) }
        [durationTime, miniDuration, sideDuration].forEach { $0.stringValue = formatTime(player.duration) }
        highlightLyric(at: player.currentTime)
        if !player.isPlaying, player.currentTime >= player.duration, player.duration > 0 {
            advanceAfterTrackEnded()
        }
    }

    private func loadLyrics(for track: Track) {
        lyrics = []
        clear(lyricsStack)
        guard let url = track.lyricURL, let text = try? String(contentsOf: url) else {
            lyricsStatus.stringValue = "未找到同名 .lrc"
            lyricsStack.addArrangedSubview(emptyLabel("将同名 .lrc 文件放在歌曲旁边即可显示歌词。"))
            return
        }
        lyrics = parseLRC(text)
        lyricsStatus.stringValue = lyrics.isEmpty ? "歌词文件为空" : "\(lyrics.count) 行歌词"
        lyricLabels = lyrics.map {
            let label = NSTextField(labelWithString: $0.text)
            label.font = .systemFont(ofSize: 17, weight: .regular)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            label.wantsLayer = true
            label.layer?.cornerRadius = 8
            label.translatesAutoresizingMaskIntoConstraints = false
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
            return label
        }
        lyricLabels.forEach { lyricsStack.addArrangedSubview($0) }
    }

    private func parseLRC(_ text: String) -> [LyricLine] {
        text.components(separatedBy: .newlines).flatMap { line -> [LyricLine] in
            let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, range: range)
            let content = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return [] }
            return matches.compactMap { match in
                guard
                    let mRange = Range(match.range(at: 1), in: line),
                    let sRange = Range(match.range(at: 2), in: line)
                else { return nil }
                let minutes = Double(line[mRange]) ?? 0
                let seconds = Double(line[sRange]) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound, let fRange = Range(match.range(at: 3), in: line) {
                    fraction = Double("0.\(line[fRange])") ?? 0
                }
                return LyricLine(time: minutes * 60 + seconds + fraction, text: content)
            }
        }.sorted { $0.time < $1.time }
    }

    private func highlightLyric(at time: TimeInterval) {
        guard !lyrics.isEmpty else { return }
        var active = 0
        for (index, line) in lyrics.enumerated() where time >= line.time {
            active = index
        }
        for (index, label) in lyricLabels.enumerated() {
            let isActive = index == active
            label.textColor = isActive ? .systemPink : .secondaryLabelColor
            label.font = .systemFont(ofSize: isActive ? 19 : 17, weight: isActive ? .bold : .regular)
            label.layer?.backgroundColor = isActive ? NSColor.systemPink.withAlphaComponent(0.10).cgColor : NSColor.clear.cgColor
        }
        lyricLabels[safe: active]?.scrollToVisible(lyricLabels[safe: active]?.bounds ?? .zero)
    }

    private func artwork(for track: Track) -> NSImage {
        // 第一优先：文件内部封面
        if let image = track.embeddedArtwork {
            return image
        }

        // 第二优先：同名图片
        if let artworkURL = track.artworkURL,
            let image = NSImage(contentsOf: artworkURL) {
                return image
            }
        // if let artworkURL = track.artworkURL, let image = NSImage(contentsOf: artworkURL) {
        //     return image
        // }
        return placeholderArtwork(size: 360)
    }

    private func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: "folders"),
              let decoded = try? JSONDecoder().decode([SourceFolder].self, from: data)
        else { return }
        folders = decoded
    }

    private func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: "folders")
        }
    }

    private func loadPlaylists() {
        guard let data = UserDefaults.standard.data(forKey: "playlists"),
              let decoded = try? JSONDecoder().decode([MusicPlaylist].self, from: data)
        else {
            renderPlaylists()
            return
        }
        playlists = decoded
        selectedPlaylistID = playlists.first?.id
        renderPlaylists()
    }

    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: "playlists")
        }
    }

    private func configureNavButton(_ button: NSButton, image: String) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.alignment = .left
        button.image = symbolImage(image, pointSize: 16, color: .labelColor)
        button.imagePosition = .imageLeading
        button.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setButtonType(.toggle)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
    }

    private func configureIconButton(_ button: NSButton) {
        button.bezelStyle = .circular
        button.font = .systemFont(ofSize: 16, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }

    private func configurePrimaryButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.contentTintColor = .systemPink
        button.font = .systemFont(ofSize: 13, weight: .semibold)
    }

    private func makeSmallButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .inline
        button.contentTintColor = .systemPink
        return button
    }

    private func makeHeader(eyebrow: String, title: String) -> NSStackView {
        let eyebrowLabel = NSTextField(labelWithString: eyebrow)
        eyebrowLabel.font = .systemFont(ofSize: 12, weight: .medium)
        eyebrowLabel.textColor = .secondaryLabelColor
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 38, weight: .bold)
        let stack = NSStackView(views: [eyebrowLabel, titleLabel])
        stack.orientation = .vertical
        stack.spacing = 4
        return stack
    }

    private func makePanel(title: String, trailing: NSView?) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        let headerViews = trailing.map { [titleLabel, NSView(), $0] } ?? [titleLabel]
        let header = NSStackView(views: headerViews)
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .gravityAreas

        let stack = NSStackView(views: [header])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.wantsLayer = true
        stack.layer?.cornerRadius = 12
        stack.layer?.backgroundColor = NSColor.systemPink.withAlphaComponent(0.10).cgColor
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private func configureStack(_ stack: NSStackView) {
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
    }

    private func scrollView(containing stack: NSStackView) -> NSScrollView {
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: document.widthAnchor)
        ])
        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        return scroll
    }

    private func clear(_ stack: NSStackView) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func emptyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return label
    }

    private func roundedImageView(size: CGFloat) -> NSImageView {
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: size).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: size).isActive = true
        return imageView
    }

    private func symbolImage(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)?
            .tinting(with: color)
    }

    private func placeholderArtwork(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let gradient = NSGradient(colors: [.systemPink, .systemOrange])!
        gradient.draw(in: rect, angle: 135)
        let symbol = symbolImage("music.note", pointSize: size * 0.33, color: .white)
        symbol?.draw(in: NSRect(x: size * 0.34, y: size * 0.34, width: size * 0.32, height: size * 0.32))
        image.unlockFocus()
        return image
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    private func loadEmbeddedArtwork(_ url: URL) -> NSImage? {

        let asset = AVAsset(url: url)

        for item in asset.commonMetadata {

            if item.commonKey == .commonKeyArtwork {

                if let data = item.value as? Data {
                    return NSImage(data: data)
                }

                if let data = item.dataValue {
                    return NSImage(data: data)
                }
            }
        }

        return nil
    }
}

@main
enum LocalMusicPlayerApp {
    private static var appDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        appDelegate = AppDelegate()
        app.delegate = appDelegate
        app.run()
    }
}

private extension NSImage {
    func tinting(with color: NSColor) -> NSImage {
        let image = copy() as! NSImage
        image.lockFocus()
        color.set()
        NSRect(origin: .zero, size: image.size).fill(using: .sourceAtop)
        image.unlockFocus()
        return image
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

final class FlippedView: NSView {
    override var isFlipped: Bool {
        true
    }
}
