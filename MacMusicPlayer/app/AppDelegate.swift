import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let root = NSView()
    let sidebar = NSVisualEffectView()
    let content = NSView()
    let libraryPage = NSView()
    let foldersPage = NSView()
    let playlistsPage = NSView()
    let playerPage = NSView()
    var pageConstraints: [ObjectIdentifier: [NSLayoutConstraint]] = [:]

    let libraryButton = NSButton(title: "音乐列表", target: nil, action: nil)
    let foldersButton = NSButton(title: "文件夹", target: nil, action: nil)
    let playlistsButton = NSButton(title: "播放列表", target: nil, action: nil)
    let addFolderButton = NSButton(title: "选择文件夹", target: nil, action: nil)
    let rescanButton = NSButton(title: "重新扫描", target: nil, action: nil)
    let backButton = NSButton(title: "‹ 返回资料库", target: nil, action: nil)
    let selectTracksButton = NSButton(title: "选择", target: nil, action: nil)
    let addSelectedButton = NSButton(title: "加入列表", target: nil, action: nil)
    let enqueueSelectedButton = NSButton(title: "加入待播", target: nil, action: nil)

    let searchField = NSSearchField()
    let folderFilterPopup = NSPopUpButton()
    let statusLabel = NSTextField(labelWithString: "待播放")
    let libraryCountLabel = NSTextField(labelWithString: "0 首")
    let selectionStatusLabel = NSTextField(labelWithString: "未选择")
    let folderCountLabel = NSTextField(labelWithString: "0 个")
    let playlistCountLabel = NSTextField(labelWithString: "0 个")
    let selectedPlaylistTitle = NSTextField(labelWithString: "选择一个播放列表")
    let selectedPlaylistCountLabel = NSTextField(labelWithString: "0 首")
    let trackStack = NSStackView()
    let recentStack = NSStackView()
    let folderStack = NSStackView()
    let playlistStack = NSStackView()
    let playlistTrackStack = NSStackView()
    let pendingTrackStack = NSStackView()
    let libraryPendingTrackStack = NSStackView()
    let pendingCountLabel = NSTextField(labelWithString: "0 首")
    let libraryPendingCountLabel = NSTextField(labelWithString: "0 首")
    let newPlaylistButton = NSButton(title: "新建列表", target: nil, action: nil)
    let deletePlaylistButton = NSButton(title: "删除列表", target: nil, action: nil)
    let playPlaylistButton = NSButton(title: "播放", target: nil, action: nil)
    let playbackOrderPopup = NSPopUpButton()
    let selectPlaylistTracksButton = NSButton(title: "选择", target: nil, action: nil)
    let removeSelectedPlaylistTracksButton = NSButton(title: "移除歌曲", target: nil, action: nil)
    let playlistSelectionStatusLabel = NSTextField(labelWithString: "未选择")
    let libraryQueueButton = NSButton(title: "", target: nil, action: nil)
    let playerQueueButton = NSButton(title: "", target: nil, action: nil)
    var libraryQueuePanel: NSStackView!
    var playerQueuePanel: NSStackView!
    var playerLyricsPanel: NSStackView!
    var libraryQueueWidthConstraint: NSLayoutConstraint!
    var playerQueueWidthConstraint: NSLayoutConstraint!

    let miniPlayer = NSView()
    let miniCover = NSImageView()
    let miniTitle = NSTextField(labelWithString: "还没有播放歌曲")
    let miniArtist = NSTextField(labelWithString: "从文件夹导入音乐开始")
    let sideCurrentTime = NSTextField(labelWithString: "0:00")
    let sideDuration = NSTextField(labelWithString: "0:00")
    let sideSeek = PomegranateSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)

    let nowCard = NSView()
    let nowCover = NSImageView()
    let nowTitle = NSTextField(labelWithString: "请选择一首歌")
    let nowArtist = NSTextField(labelWithString: "支持 mp3、m4a、aac、wav、flac、ogg")
    let miniCurrentTime = NSTextField(labelWithString: "0:00")
    let miniDuration = NSTextField(labelWithString: "0:00")
    let miniSeek = PomegranateSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)

    let detailCover = NSImageView()
    let detailTitle = NSTextField(labelWithString: "还没有播放歌曲")
    let detailArtist = NSTextField(labelWithString: "在音乐列表中选择一首歌")
    let detailFolder = NSTextField(labelWithString: "未选择来源")
    let currentTime = NSTextField(labelWithString: "0:00")
    let durationTime = NSTextField(labelWithString: "0:00")
    let seekBar = PomegranateSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
    let lyricsStack = NSStackView()
    let lyricsStatus = NSTextField(labelWithString: "自动匹配同名 .lrc")

    let playButton = NSButton(title: "▶", target: nil, action: nil)
    let prevButton = NSButton(title: "⏮", target: nil, action: nil)
    let nextButton = NSButton(title: "⏭", target: nil, action: nil)
    let detailPlayButton = NSButton(title: "▶", target: nil, action: nil)
    let detailPrevButton = NSButton(title: "⏮", target: nil, action: nil)
    let detailNextButton = NSButton(title: "⏭", target: nil, action: nil)
    // let shuffleButton = NSButton(title: "", target: nil, action: nil)
    let repeatButton = NSButton(title: "", target: nil, action: nil)
    // let detailShuffleButton = NSButton(title: "", target: nil, action: nil)
    let detailRepeatButton = NSButton(title: "", target: nil, action: nil)

    var folders: [SourceFolder] = []
    var playlists: [MusicPlaylist] = []
    var tracks: [Track] = []
    var filteredTracks: [Track] = []
    var recentIDs: [String] = UserDefaults.standard.stringArray(forKey: "recentTracks") ?? []
    var currentTrack: Track?
    var currentIndex = -1
    var audioPlayer: AVAudioPlayer?
    var timer: Timer?
    var lyrics: [LyricLine] = []
    var lyricLabels: [NSTextField] = []
    var selectedFolderID: String? = UserDefaults.standard.string(forKey: "selectedFolderID")
    var selectedPlaylistID: String?
    var selectedTrackIDs = Set<String>()
    var isSelectingTracks = false
    var selectedPlaylistTrackIDs = Set<String>()
    var isSelectingPlaylistTracks = false
    var isQueueSidebarVisible = false
    var isShuffleEnabled = UserDefaults.standard.bool(forKey: "shuffleEnabled")
    var repeatMode: RepeatMode = .off
    var isAdvancingAtEnd = false
    /// 队首始终是当前曲目；其余项目即为待播清单。
    var playbackQueue: [Track] = []
    var playbackHistory: [Track] = []

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        buildWindow()
        buildSidebar()
        buildLibraryPage()
        buildFoldersPage()
        buildPlaylistsPage()
        buildPlayerPage()
        bindActions()
        configureAppearance()
        observeAppearanceChanges()
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

    func showMainWindow() {
        if window == nil {
            buildWindow()
        }
        window.deminiaturize(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func observeAppearanceChanges() {
        NotificationCenter.default.addObserver(
                self,
                selector: #selector(appearanceDidChange),
                name: NSNotification.Name("AppleInterfaceThemeChangedNotification"), // 👈 监听 macOS 核心主题切换
                object: nil
                )
    }

    @objc private func appearanceDidChange() {
        applyTheme()
    }

    func applyTheme() {
        root.applyBackground(Theme.windowBackground)
        miniPlayer.applyBackground(Theme.miniPlayerBackground)
        nowCard.applyBackground(Theme.nowPlayingBackground)
        renderTracks()
        renderRecent()
        renderFolders()
        renderPlaylists()
        renderPendingQueue()
        updatePlaybackModeButtons()
    }

}
