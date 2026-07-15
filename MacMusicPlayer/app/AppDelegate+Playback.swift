import AppKit
import AVFoundation

extension AppDelegate {

    func play(track: Track, resetQueue: Bool = true) {
        do {
            if resetQueue {
                resetPlaybackQueue(with: filteredTracks.isEmpty ? tracks : filteredTracks, startingAt: track)
            }
            audioPlayer = try AVAudioPlayer(contentsOf: track.url)
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
                player.pause()
            } else {
                player.play()
                    startTimer() // 启动进度条定时器
            }
            updatePlayButtons()
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
        playbackQueue.removeAll { $0.id == previous.id }
        playbackQueue.insert(previous, at: 0)
        renderPendingQueue()
        play(track: previous, resetQueue: false)
    }
    @objc func playNext() { playByOffset(1) }

    @objc func toggleShuffle() {
        isShuffleEnabled.toggle()
        UserDefaults.standard.set(isShuffleEnabled, forKey: "shuffleEnabled")
        reorderPendingQueue()
        updatePlaybackModeButtons()
    }

    @objc func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
        updatePlaybackModeButtons()
    }

    func playByOffset(_ offset: Int) {
        guard offset > 0 else { return }
        guard let next = consumeCurrentAndNext(allowStopAtEnd: false) else { return }
        play(track: next, resetQueue: false)
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
        reorderPendingQueue()
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

    /// 随机播放只重排尚未播放的歌曲，队首的当前歌曲不会变化。
    func reorderPendingQueue() {
        guard playbackQueue.count > 2 else { return }
        let current = playbackQueue.removeFirst()
        if isShuffleEnabled {
            playbackQueue.shuffle()
        }
        playbackQueue.insert(current, at: 0)
    }

    /// 当前曲结束（或手动下一首）时，将它从待播清单中消费并返回下一首。
    func consumeCurrentAndNext(allowStopAtEnd: Bool) -> Track? {
        if let currentTrack {
            playbackQueue.removeAll { $0.id == currentTrack.id }
            playbackHistory.append(currentTrack)
        }
        guard !playbackQueue.isEmpty else {
            renderPendingQueue()
            return nil
        }
        if isShuffleEnabled, playbackQueue.count > 1 {
            let index = Int.random(in: 0..<playbackQueue.count)
            let selected = playbackQueue.remove(at: index)
            playbackQueue.insert(selected, at: 0)
        }
        renderPendingQueue()
        return playbackQueue.first
    }

    func advanceAfterTrackEnded() {
        guard !isAdvancingAtEnd else { return }
        isAdvancingAtEnd = true

        if repeatMode == .one, let player = audioPlayer {
            player.currentTime = 0
            player.play()
            isAdvancingAtEnd = false
            updateProgress()
            return
        }

        guard let next = consumeCurrentAndNext(allowStopAtEnd: true) else {
            audioPlayer?.currentTime = 0
            updatePlayButtons()
            updateProgress()
            isAdvancingAtEnd = false
            return
        }
        play(track: next, resetQueue: false)
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
        renderRecent()
        renderSelectedPlaylistTracks()
        renderPendingQueue()
    }

    func updatePlayButtons() {
        let title = audioPlayer?.isPlaying == true ? "⏸" : "▶"
        playButton.title = title
        detailPlayButton.title = title
    }

    func updatePlaybackModeButtons() {
        // [shuffleButton, detailShuffleButton].forEach {
        //     $0.image = UIHelpers.symbolImage(
        //         "shuffle",
        //         pointSize: 15,
        //         color: isShuffleEnabled ? Theme.accent : Theme.secondaryText
        //     )
        //     $0.toolTip = isShuffleEnabled ? "随机播放已开启" : "随机播放"
        //     $0.contentTintColor = isShuffleEnabled ? Theme.accent : Theme.secondaryText
        // }

        let repeatSymbol = repeatMode == .one ? "repeat.1" : "repeat"
        let repeatColor: NSColor = repeatMode == .off ? Theme.secondaryText : Theme.accent
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
            $0.image = UIHelpers.symbolImage(repeatSymbol, pointSize: 15, color: repeatColor)
            $0.toolTip = repeatTip
            $0.contentTintColor = repeatColor
        }
        playbackOrderPopup.selectItem(at: isShuffleEnabled ? 1 : 0)
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
        if !player.isPlaying, player.currentTime >= player.duration, player.duration > 0 {
            advanceAfterTrackEnded()
        }
    }

    func loadLyrics(for track: Track) {
        lyrics = []
        UIHelpers.clear(lyricsStack)
        let externalLyrics = track.lyricURL.flatMap { try? String(contentsOf: $0) }
        guard let text = externalLyrics ?? track.embeddedLyrics else {
            lyricsStatus.stringValue = AppText.noLyrics
            lyricsStack.addArrangedSubview(UIHelpers.emptyLabel(AppText.lyricsExternalHint))
            return
        }
        lyrics = LyricParser.parseLRC(text)
        if lyrics.isEmpty, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lyrics = [LyricLine(time: 0, text: text)]
        }
        lyricsStatus.stringValue = lyrics.isEmpty ? AppText.lyricsFileEmpty : "\(lyrics.count) 行歌词"
        lyricLabels = lyrics.map {
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
        lyricLabels.forEach { lyricsStack.addArrangedSubview($0) }
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
            audioPlayer?.prepareToPlay() // 仅准备，不 play()
            
            currentTrack = track
            currentIndex = playbackQueue.firstIndex(where: { $0.id == track.id }) ?? -1
            isAdvancingAtEnd = false
            
            // 加载歌词与更新 UI（这时播放按钮应该显示为“播放”图标，而不是“暂停”图标）
            loadLyrics(for: track)
            updateCurrentUI()
            updatePlayButtons() // 确保按钮状态是“暂停/未播放”
        } catch {
            print("静默载入歌曲失败: \(error)")
        }
    }
}
