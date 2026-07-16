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
    var currentPage: NSView?
    var pageConstraints: [ObjectIdentifier: [NSLayoutConstraint]] = [:]

    let libraryButton = NSButton(title: AppText.sidebarLibrary, target: nil, action: nil)
    let foldersButton = NSButton(title: AppText.sidebarFolders, target: nil, action: nil)
    let playlistsButton = NSButton(title: AppText.sidebarPlaylists, target: nil, action: nil)
    let addFolderButton = NSButton(title: AppText.sidebarAddFolder, target: nil, action: nil)
    let rescanButton = NSButton(title: AppText.sidebarRescan, target: nil, action: nil)
    let backButton = NSButton(title: AppText.backToLibrary, target: nil, action: nil)
    let selectTracksButton = NSButton(title: AppText.select, target: nil, action: nil)
    let addSelectedButton = NSButton(title: AppText.addToPlaylist, target: nil, action: nil)
    let enqueueSelectedButton = NSButton(title: AppText.enqueueNext, target: nil, action: nil)

    let searchField = NSSearchField()
    let folderFilterPopup = NSPopUpButton()
    let statusLabel = NSTextField(labelWithString: AppText.defaultStatus)
    let libraryCountLabel = NSTextField(labelWithString: AppText.trackCount(0))
    let selectionStatusLabel = NSTextField(labelWithString: AppText.noSelection)
    let folderCountLabel = NSTextField(labelWithString: "0 个")
    let playlistCountLabel = NSTextField(labelWithString: "0 个")
    // let selectedPlaylistTitle = NSTextField(labelWithString: AppText.selectPlaylist)
    let selectedPlaylistCountLabel = NSTextField(labelWithString: AppText.trackCount(0))
    let trackStack = NSStackView()
    let recentStack = NSStackView()
    let folderStack = NSStackView()
    let playlistStack = NSStackView()
    let playlistTrackStack = NSStackView()
    let pendingTrackStack = NSStackView()
    let libraryPendingTrackStack = NSStackView()
    let pendingCountLabel = NSTextField(labelWithString: AppText.trackCount(0))
    let libraryPendingCountLabel = NSTextField(labelWithString: AppText.trackCount(0))
    let newPlaylistButton = NSButton(title: AppText.newPlaylist, target: nil, action: nil)
    let deletePlaylistButton = NSButton(title: AppText.deletePlaylist, target: nil, action: nil)
    let playPlaylistButton = NSButton(title: AppText.play, target: nil, action: nil)
    let playbackOrderPopup = NSPopUpButton()
    let selectPlaylistTracksButton = NSButton(title: AppText.select, target: nil, action: nil)
    let removeSelectedPlaylistTracksButton = NSButton(title: AppText.removeSong, target: nil, action: nil)
    let playlistSelectionStatusLabel = NSTextField(labelWithString: AppText.noSelection)
    let libraryQueueButton = NSButton(title: "", target: nil, action: nil)
    let playerQueueButton = NSButton(title: "", target: nil, action: nil)
    var libraryQueuePanel: NSStackView!
    var playerQueuePanel: NSStackView!
    var playerLyricsPanel: NSStackView!
    var libraryQueueWidthConstraint: NSLayoutConstraint!
    var playerQueueWidthConstraint: NSLayoutConstraint!
    var playerAlbumWidthConstraint: NSLayoutConstraint!
    var playerAlbumPanel: NSStackView!
    // var libraryLeftColumn: NSStackView!
    var libraryMainRow: NSStackView!
    var libraryPanel: NSStackView!

    let miniPlayer = NSView()
    let miniCover = NSImageView()
    let miniTitle = NSTextField(labelWithString: AppText.noSongPlaying)
    let miniArtist = NSTextField(labelWithString: AppText.importMusicHint)
    let sideCurrentTime = NSTextField(labelWithString: AppText.zeroDuration)
    let sideDuration = NSTextField(labelWithString: AppText.zeroDuration)
    let sideSeek = PomegranateSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)

    let nowCard = NSView()
    let nowCover = NSImageView()
    let nowTitle = NSTextField(labelWithString: AppText.chooseSongHint)
    let nowArtist = NSTextField(labelWithString: "支持 mp3、m4a、aac、wav、flac、ogg")
    let miniCurrentTime = NSTextField(labelWithString: AppText.zeroDuration)
    let miniDuration = NSTextField(labelWithString: AppText.zeroDuration)
    let miniSeek = PomegranateSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)

    let detailCover = NSImageView()
    let detailTitle = NSTextField(labelWithString: AppText.noSongPlaying)
    let detailArtist = NSTextField(labelWithString: AppText.chooseSongDetailHint)
    let detailFolder = NSTextField(labelWithString: AppText.unknownSource)
    let currentTime = NSTextField(labelWithString: AppText.zeroDuration)
    let durationTime = NSTextField(labelWithString: AppText.zeroDuration)
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
    var repeatMode: RepeatMode = RepeatMode(rawValue: UserDefaults.standard.integer(forKey: "repeatMode")) ?? .off
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
        // 2. 👈 【新增】此时 tracks 已经从本地文件夹加载完毕，立刻恢复上一次的待播清单
        restorePlaybackQueue()
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
        // renderRecent()
        renderFolders()
        renderPlaylists()
        renderPendingQueue()
        updatePlaybackModeButtons()
    }
    /// 1. 🔂 单曲循环处理：原地重播当前歌曲
    func handleSingleLoop() {
        guard let current = self.currentTrack else {
            // 安全防御：如果没有当前歌，尝试播队列第一首
            self.playNextTrack()
            return
        }
        print("🔂 单曲循环：重新播放《\(current.title)》")
        // resetQueue 传入 false，防止打乱用户当前的队列
        self.play(track: current, resetQueue: false)
    }
    
    /// 2. 🔁 播放下一首（对应 .all 和 .off 的情况）
    func playNextTrack() {
        
        let nextIndex = self.currentIndex + 1
        
        if nextIndex < self.playbackQueue.count {
            // 队列里还有下一首，继续播放
            let nextTrack = self.playbackQueue[nextIndex]
            print("➡️ 自动播放下一首 [\(nextIndex + 1)/\(self.playbackQueue.count)]: \(nextTrack.title)")
            self.play(track: nextTrack, resetQueue: false)
            playbackHistory.append(nextTrack)
        } else {
            // 已经播放到最后一首了
            if self.repeatMode == .all {
                // 列表循环开启：回到第一首
                let firstTrack = self.playbackQueue[0]
                print("🔁 列表循环：已到最后一首，回到第一首: \(firstTrack.title)")
                self.play(track: firstTrack, resetQueue: false)
                playbackHistory.append(firstTrack)
            } else {
                // 顺序播放关闭（.off）：到最后一首后停止播放
                print("⏹️ 顺序播放结束：已播完列表最后一首")
                // 这里可以根据需要将进度条归 0 或停止 Timer
                self.audioPlayer?.stop()
                self.updateCurrentUI()
            }
        }
    }
    
    /// 3. 🔀 随机播放一首
    func playRandomTrack() {
        guard !self.playbackQueue.isEmpty else {
            print("⏹️ 播放队列为空，停止播放")
            self.updateCurrentUI()
            return
        }
        
        if self.playbackQueue.count == 1 {
            // 队列里只有一首歌时，随机等同于单曲循环
            self.handleSingleLoop()
            return
        }
        
        // 算法：随机生成一个不是当前 currentIndex 的索引
        var randomIndex = Int.random(in: 0..<self.playbackQueue.count)
        
        // 避免刚听完又随机到一模一样的同一首歌（如果列表大于 1 首歌）
        while randomIndex == self.currentIndex {
            randomIndex = Int.random(in: 0..<self.playbackQueue.count)
        }
        
        let randomTrack = self.playbackQueue[randomIndex]
        print("🔀 随机播放 [索引: \(randomIndex)]: \(randomTrack.title)")
        self.play(track: randomTrack, resetQueue: false)
        playbackHistory.append(randomTrack)

    }

}
