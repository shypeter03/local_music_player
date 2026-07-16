import AppKit
import AVFoundation

extension AppDelegate :AVAudioPlayerDelegate {

    func play(track: Track, resetQueue: Bool = true) {
        do {
            if resetQueue {
                resetPlaybackQueue(with: filteredTracks.isEmpty ? tracks : filteredTracks, startingAt: track)
            }
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.delegate = self

            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            currentTrack = track
            currentIndex = playbackQueue.firstIndex(where: { $0.id == track.id }) ?? -1
            isAdvancingAtEnd = false
            addRecent(track.id)
            loadLyrics(for: track)
            updateCurrentUI()
            startTimer()

            savePlaybackQueue()// 保存播放状态
        } catch {
            statusLabel.stringValue = AppText.playbackFailed
        }
    }

    @objc func togglePlay() {
        // 如果当前已经有静默加载好的歌曲（冷启动恢复的）
        if let player = audioPlayer {
            if player.isPlaying {
                // 如果正在播，直接暂停
                player.pause()
                updatePlayButtons()
            } else {
                // 如果处于暂停状态：
                if player.currentTime > 0 {
                    // 🌟 核心修复：如果已经播放了一部分，直接继续播放，不重头载入！
                    player.play()
                    startTimer()
                    updatePlayButtons()
                } else {
                    // 🌟 只有在冷启动（时间为 0 且从未播放过）时，才走规范的 play(track) 去激活全套逻辑
                    if let track = currentTrack {
                        play(track: track, resetQueue: false)
                    } else {
                        player.play()
                        startTimer()
                        updatePlayButtons()
                    }
                }
            }
            return
        }

        // 如果完全没有载入过歌曲，才默认播放第一首
        if audioPlayer == nil, let first = tracks.first {
            play(track: first, resetQueue: true)
                return
        }
    }

    @objc func playPrevious() {
        guard let previous = playbackHistory.popLast() else { return }
        print("<<正在播放上一首歌 \(previous.title)>>")
        renderPendingQueue()
        play(track: previous, resetQueue: false)
    }

    @objc func playNext() { 
        switch self.repeatMode {
        case .all, .off,.one: // 🔁 列表循环 / 顺序播放
            self.playNextTrack()
        case .shuffle: // 🔀 随机播放
            self.playRandomTrack()
        }
    }


    @objc func cycleRepeatMode() {
        switch self.repeatMode {
        case .off:
            self.repeatMode = .all
        case .all:
            self.repeatMode = .one
        case .one:
            self.repeatMode = .shuffle
        case .shuffle: // 🌟 安全兜底
            self.repeatMode = .off
        }
        updatePlaybackModeButtons()
    }


    /// 用新的来源重建待播清单。当前歌曲位于队首，结束后才会从清单移除。
    func resetPlaybackQueue(with source: [Track], startingAt track: Track) {
        let unique = source.reduce(into: [Track]()) { result, candidate in
            if !result.contains(where: { $0.id == candidate.id }) { result.append(candidate) }
        }
        guard let index = unique.firstIndex(where: { $0.id == track.id }) else {
            playbackQueue = [track]
            renderPendingQueue()
            return
        }
        playbackQueue = Array(unique[index...]) + Array(unique[..<index])
        playbackHistory = []
        renderPendingQueue()
        savePlaybackQueue() 
    }

    /// 将歌曲追加到当前待播队列，不改变正在播放的歌曲或既有顺序。
    func enqueueTracks(_ tracksToAppend: [Track]) {
        for track in tracksToAppend where !playbackQueue.contains(where: { $0.id == track.id }) {
            playbackQueue.append(track)
        }
        renderPendingQueue()
    }


    @objc func seekChanged(_ sender: NSSlider) {
        guard let player = audioPlayer, player.duration > 0 else { return }
        isAdvancingAtEnd = false
        player.currentTime = (sender.doubleValue / 100) * player.duration
        updateProgress()
    }

    func addRecent(_ id: String) {
        recentIDs.removeAll { $0 == id }
        recentIDs.insert(id, at: 0)
        recentIDs = Array(recentIDs.prefix(20))
        UserDefaults.standard.set(recentIDs, forKey: "recentTracks")
    }

    func updateCurrentUI() {
        guard let track = currentTrack else { return }
        miniTitle.stringValue = track.title
        nowTitle.stringValue = track.title
        detailTitle.stringValue = track.title
        miniArtist.stringValue = track.artist
        nowArtist.stringValue = "\(track.artist) · \(track.ext.uppercased())"
        detailArtist.stringValue = track.artist
        detailFolder.stringValue = "\(track.folderURL.lastPathComponent) / \(track.url.lastPathComponent)"

        let image = ArtworkLoader.artwork(for: track)
        [miniCover, nowCover, detailCover].forEach { $0.image = image }
        updatePlayButtons()
        updateProgress()
        renderTracks()
        // renderRecent()
        renderSelectedPlaylistTracks()
        renderPendingQueue()
    }

    func updatePlayButtons() {
        let title = audioPlayer?.isPlaying == true ? "⏸" : "▶"
        playButton.title = title
        detailPlayButton.title = title
    }

    func updatePlaybackModeButtons() {

        let repeatSymbol: String
        let repeatColor: NSColor = self.repeatMode == .off ? Theme.secondaryText : Theme.accent
        let repeatTip: String
        switch self.repeatMode {
        case .off:
            repeatTip = "循环关闭"
            repeatSymbol = "repeat"
        case .all:
            repeatTip = "列表循环"
            repeatSymbol = "repeat"
        case .one:
            repeatTip = "单曲循环"
            repeatSymbol = "repeat.1"
        case .shuffle: // 🌟 安全兜底
            repeatTip = "随机播放"
            repeatSymbol = "shuffle"
        }
        [repeatButton, detailRepeatButton].forEach {
            $0.image = UIHelpers.symbolImage(repeatSymbol, pointSize: 15, color: repeatColor)
            $0.toolTip = repeatTip
            $0.contentTintColor = repeatColor
        }

        UserDefaults.standard.set(self.repeatMode.rawValue, forKey: "repeatMode")
    }

    func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateProgress()
        }
    }

    func updateProgress() {
        guard let player = audioPlayer else {
            [currentTime, miniCurrentTime, sideCurrentTime].forEach { $0.stringValue = AppText.zeroDuration }
            [durationTime, miniDuration, sideDuration].forEach { $0.stringValue = AppText.zeroDuration }
            [seekBar, miniSeek, sideSeek].forEach { $0.doubleValue = 0 }
            return
        }
        if player.duration > 0 {
            let percent = (player.currentTime / player.duration) * 100
            [seekBar, miniSeek, sideSeek].forEach { $0.doubleValue = percent }
        }
        [currentTime, miniCurrentTime, sideCurrentTime].forEach { $0.stringValue = UIHelpers.formatTime(player.currentTime) }
        [durationTime, miniDuration, sideDuration].forEach { $0.stringValue = UIHelpers.formatTime(player.duration) }
        highlightLyric(at: player.currentTime)
    }

    func loadLyrics(for track: Track) {
        // 1. 初始化清理
        self.lyrics = []
        UIHelpers.clear(self.lyricsStack)
        self.lyricsStatus.stringValue = "正在加载歌词..."

        // 2. 尝试寻找同名外部 .lrc 文件
        let audioPath = track.url.path
        let lrcPath = (audioPath as NSString).deletingPathExtension + ".lrc"
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: lrcPath) {
            do {
                let lrcContent = try String(contentsOfFile: lrcPath, encoding: .utf8)
                self.renderLyricText(lrcContent, isEmbedded: false)
                return
            } catch {
                print("⚠️ 读取外部歌词失败: \(error)")
            }
        }

        // 3. 外部歌词不存在，异步读取媒体文件的内嵌歌词（支持 FLAC & M4A）
        let safeURL = URL(fileURLWithPath: track.url.path)
        let asset = AVAsset(url: safeURL)
        
        asset.loadValuesAsynchronously(forKeys: ["metadata", "commonMetadata"]) { [weak self] in
            guard let self = self else { return }
            
            var error: NSError? = nil
            let metadataStatus = asset.statusOfValue(forKey: "metadata", error: &error)
            
            if metadataStatus == .failed {
                print("❌ AVAsset 读取音频文件元数据失败: \(error?.localizedDescription ?? "未知错误")")
                DispatchQueue.main.async {
                    self.lyricsStatus.stringValue = AppText.noLyrics
                    self.lyricsStack.addArrangedSubview(UIHelpers.emptyLabel(AppText.lyricsExternalHint))
                }
                return
            }
            
            var lyricsText: String? = nil
            
            // 🌟 【M4A / iTunes 格式歌词匹配】
            // 匹配 identifier 为 "itsk/%A9lyr" (即 AVMetadataIdentifier.itunesMetadataLyrics)
            // 🌟 仅保留 identifier.rawValue 的安全字符串比对，彻底解决不同 SDK 版本的编译冲突
            if let m4aLyricItem = asset.metadata.first(where: { item in
                    return item.identifier?.rawValue == "itsk/%A9lyr"
                    }) {
                lyricsText = m4aLyricItem.stringValue
            }
            // 🌟 【FLAC / Vorbis 格式歌词匹配】
            // 如果 M4A 没匹配到，匹配 FLAC 的 LYRICS / UNSYNCEDLYRICS 标签
            if lyricsText == nil {
                for item in asset.metadata {
                    if let keyString = item.key as? String {
                        let upperKey = keyString.uppercased()
                        if upperKey == "LYRICS" || upperKey == "UNSYNCEDLYRICS" || upperKey == "UNSYNCED LYRICS" {
                            lyricsText = item.stringValue
                            break
                        }
                    }
                }
            }
            
            // 🌟 【通用格式歌词匹配】
            // 🌟 修复：直接对比 commonKey 的 rawValue，彻底避开 SDK 命名空间推断报错
            if lyricsText == nil, let commonLyricItem = asset.commonMetadata.first(where: { item in
                    if let commonKey = item.commonKey {
                    return commonKey.rawValue == "lyrics" || commonKey.rawValue == "lld3"
                    }
                    return false
                    }) {
                lyricsText = commonLyricItem.stringValue
            }

            // 返回主线程解析并渲染 UI
            DispatchQueue.main.async {
                if let text = lyricsText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.renderLyricText(text, isEmbedded: true)
                } else {
                    // 彻底没有歌词
                    self.lyricsStatus.stringValue = AppText.noLyrics
                    self.lyricsStack.addArrangedSubview(UIHelpers.emptyLabel(AppText.lyricsExternalHint))
                }
            }
        }
    }

    /// 统一渲染歌词的私有辅助方法
    private func renderLyricText(_ text: String, isEmbedded: Bool) {
        // 使用原有的 LyricParser 解析歌词
        self.lyrics = LyricParser.parseLRC(text)
        
        // 如果是无时间戳的纯文本歌词，整段作为一个单行显示
        if self.lyrics.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.lyrics = [LyricLine(time: 0, text: text)]
        }
        
        self.lyricsStatus.stringValue = isEmbedded ? "内嵌歌词 (\(self.lyrics.count)行)" : "外部歌词 (\(self.lyrics.count)行)"
        
        // 生成 UI 标签
        self.lyricLabels = self.lyrics.map {
            let label = NSTextField(labelWithString: $0.text)
            label.font = .systemFont(ofSize: 17, weight: .regular)
            label.textColor = Theme.secondaryText
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
            label.wantsLayer = true
            label.layer?.cornerRadius = 8
            label.translatesAutoresizingMaskIntoConstraints = false
            label.heightAnchor.constraint(greaterThanOrEqualToConstant: 36).isActive = true
            return label
        }
        
        // 添加到 StackView
        self.lyricLabels.forEach { self.lyricsStack.addArrangedSubview($0) }
        
        // 重新高亮当前进度的歌词
        if let player = self.audioPlayer {
            self.highlightLyric(at: player.currentTime)
        }
    }

    /// 辅助方法：将歌词解析并渲染到界面上
    private func parseAndShowLyrics(_ content: String) {
        // 这里调用你原本用于解析并把歌词填入 lyricsStack 的方法
        // 假设你原本的解析逻辑会把歌词分行填入 lyricsStack 里
        UIHelpers.clear(self.lyricsStack)

            let lines = content.components(separatedBy: .newlines)
            var hasValidLines = false

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { continue }

                // 解析时间轴 [00:12.34] 歌词文本
                // 如果是无时间轴的歌词，直接展示文本
                let displayText = parseLrcLine(trimmed)

                    let label = NSTextField(labelWithString: displayText)
                    label.font = .systemFont(ofSize: 16, weight: .regular)
                    label.textColor = Theme.text
                    label.alignment = .center
                    label.lineBreakMode = .byWordWrapping
                    label.translatesAutoresizingMaskIntoConstraints = false

                    self.lyricsStack.addArrangedSubview(label)
                    hasValidLines = true
            }

        if !hasValidLines {
            showNoLyrics()
        }
    }

    /// 简单 LRC 时间标签过滤辅助
    private func parseLrcLine(_ line: String) -> String {
        // 如果包含 [00:00.00] 格式，将其去掉只保留文字
        if line.hasPrefix("[") {
            if let rightBracketIndex = line.firstIndex(of: "]") {
                let indexAfter = line.index(after: rightBracketIndex)
                    return String(line[indexAfter...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return line
    }

    /// 辅助方法：展示无歌词提示
    private func showNoLyrics() {
        UIHelpers.clear(self.lyricsStack)
            let tipLabel = NSTextField(labelWithString: AppText.noLyrics)
            tipLabel.font = .systemFont(ofSize: 14)
            tipLabel.textColor = Theme.secondaryText
            tipLabel.alignment = .center
            self.lyricsStack.addArrangedSubview(tipLabel)
            self.lyricsStatus.stringValue = ""
    }

    func highlightLyric(at time: TimeInterval) {
        guard !lyrics.isEmpty else { return }
        var active = 0
        for (index, line) in lyrics.enumerated() where time >= line.time {
            active = index
        }
        for (index, label) in lyricLabels.enumerated() {
            let isActive = index == active
            label.textColor = isActive ? Theme.accent : Theme.secondaryText
            label.font = .systemFont(ofSize: isActive ? 19 : 17, weight: isActive ? .bold : .regular)
            label.applyBackground(isActive ? Theme.cardSelectedBackground : .clear)
        }
    }

    func renderPendingQueue() {
        pendingCountLabel.stringValue = AppText.trackCount(playbackQueue.count)
        libraryPendingCountLabel.stringValue = AppText.trackCount(playbackQueue.count)
        UIHelpers.clear(pendingTrackStack)
        UIHelpers.clear(libraryPendingTrackStack)
        if playbackQueue.isEmpty {
            let text = AppText.emptyQueueTip
            pendingTrackStack.addArrangedSubview(UIHelpers.emptyLabel(text))
            libraryPendingTrackStack.addArrangedSubview(UIHelpers.emptyLabel(text))
            return
        }
        for (index, track) in playbackQueue.enumerated() {
            [pendingTrackStack, libraryPendingTrackStack].forEach { stack in
                let row = TrackRowView()
                row.configure(track: track, index: index + 1, active: track.id == currentTrack?.id)
                stack.addArrangedSubview(row)
            }
        }
    }
    
    /// 保存当前的待播清单 ID 列表
    func savePlaybackQueue() {
        let queueIDs = playbackQueue.map { $0.id }
        UserDefaults.standard.set(queueIDs, forKey: "savedPlaybackQueueIDs")
        
        // 顺便记录当前播放的那首歌的 ID
        if let currentID = currentTrack?.id {
            UserDefaults.standard.set(currentID, forKey: "savedCurrentTrackID")
        } else {
            UserDefaults.standard.removeObject(forKey: "savedCurrentTrackID")
        }
    }
    
    /// 恢复上一次保存的待播清单
    func restorePlaybackQueue() {
        guard let savedIDs = UserDefaults.standard.stringArray(forKey: "savedPlaybackQueueIDs"),
              !savedIDs.isEmpty else { 
            return 
        }
        
        // 从全局的 tracks 库中恢复对应的 Track 对象
        let restoredQueue = savedIDs.compactMap { id in
            tracks.first(where: { $0.id == id })
        }
        
        if !restoredQueue.isEmpty {
            self.playbackQueue = restoredQueue
            
            // 尝试恢复上一次播放的歌曲，如果找不到，就默认用待播清单的第一首
            let savedCurrentID = UserDefaults.standard.string(forKey: "savedCurrentTrackID")

            let targetTrack = restoredQueue.first(where: { $0.id == savedCurrentID }) ?? restoredQueue.first
            
            if let trackToLoad = targetTrack {
                // 【核心】：仅加载到播放器并准备（Prepare），不调用 .play() 保持暂停
                loadTrackWithoutPlaying(trackToLoad)
            }
        }
    }
    
    /// 将一首歌静默加载到 miniplayer，准备好播放状态但不直接播放（保持暂停）
    func loadTrackWithoutPlaying(_ track: Track) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay() // 仅准备，不 play()
            
            currentTrack = track
            currentIndex = playbackQueue.firstIndex(where: { $0.id == track.id }) ?? -1
            isAdvancingAtEnd = false
            
            // 加载歌词与更新 UI（这时播放按钮应该显示为“播放”图标，而不是“暂停”图标）
            loadLyrics(for: track)
            updateCurrentUI()
            updatePlayButtons() // 确保按钮状态是“暂停/未播放”
            updatePlaybackModeButtons()
        } catch {
            print("静默载入歌曲失败: \(error)")
        }
    }
    /// 当歌曲自然播放结束时，系统会自动回调这个方法
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // 🌟 1. 打印黄金分界线，确认这个函数到底有没有被执行！
        print("🚨🚨🚨 [DEBUG] 系统触发了 audioPlayerDidFinishPlaying 回调！successfully = \(flag)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            print("🎵 歌曲播放完成，准备切换...")
            
            // 根据当前的播放模式来决定下一步
            switch self.repeatMode {
            case .one: // 🔂 单曲循环模式
                self.handleSingleLoop()
            case .all, .off: // 🔁 列表循环 / 顺序播放
                // playbackHistory.append(track)
                self.playNextTrack()
            case .shuffle: // 🔀 随机播放
                // playbackHistory.append(track)
                self.playRandomTrack()
            }
        }
    }
    // 加上这个方法测试！
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌❌❌ 播放器解码出错啦！ Error: \(String(describing: error))")
    }
}
