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
    let newPlaylistButton = NSButton(title: "新建列表", target: nil, action: nil)
    let deletePlaylistButton = NSButton(title: "删除列表", target: nil, action: nil)

    let miniPlayer = NSView()
    let miniCover = NSImageView()
    let miniTitle = NSTextField(labelWithString: "还没有播放歌曲")
    let miniArtist = NSTextField(labelWithString: "从文件夹导入音乐开始")
    let sideCurrentTime = NSTextField(labelWithString: "0:00")
    let sideDuration = NSTextField(labelWithString: "0:00")
    let sideSeek = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)

    let nowCard = NSView()
    let nowCover = NSImageView()
    let nowTitle = NSTextField(labelWithString: "请选择一首歌")
    let nowArtist = NSTextField(labelWithString: "支持 mp3、m4a、aac、wav、flac、ogg")
    let miniCurrentTime = NSTextField(labelWithString: "0:00")
    let miniDuration = NSTextField(labelWithString: "0:00")
    let miniSeek = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)

    let detailCover = NSImageView()
    let detailTitle = NSTextField(labelWithString: "还没有播放歌曲")
    let detailArtist = NSTextField(labelWithString: "在音乐列表中选择一首歌")
    let detailFolder = NSTextField(labelWithString: "未选择来源")
    let currentTime = NSTextField(labelWithString: "0:00")
    let durationTime = NSTextField(labelWithString: "0:00")
    let seekBar = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
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
    var isShuffleEnabled = UserDefaults.standard.bool(forKey: "shuffleEnabled")
    var repeatMode: RepeatMode = .off
    var isAdvancingAtEnd = false

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
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
        // observeAppearanceChanges()
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

    // private func observeAppearanceChanges() {
    //     NotificationCenter.default.addObserver(
    //             self,
    //             selector: #selector(appearanceDidChange),
    //             name: NSApplication.didChangeEffectiveAppearanceNotification,
    //             object: nil
    //             )
    // }

    // @objc private func appearanceDidChange() {
    //     applyTheme()
    // }

    func applyTheme() {
        root.applyBackground(Theme.windowBackground)
        miniPlayer.applyBackground(Theme.miniPlayerBackground)
        nowCard.applyBackground(Theme.nowPlayingBackground)
        renderTracks()
        renderRecent()
        renderFolders()
        renderPlaylists()
        updatePlaybackModeButtons()
    }

}
