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
        } catch {
            statusLabel.stringValue = "播放失败"
        }
    }

    @objc func togglePlay() {
        if audioPlayer == nil, let first = tracks.first {
            play(track: first, resetQueue: true)
            return
        }
        if audioPlayer?.isPlaying == true {
            audioPlayer?.pause()
        } else {
            audioPlayer?.play()
        }
        updatePlayButtons()
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
            [currentTime, miniCurrentTime, sideCurrentTime].forEach { $0.stringValue = "0:00" }
            [durationTime, miniDuration, sideDuration].forEach { $0.stringValue = "0:00" }
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
        guard let url = track.lyricURL, let text = try? String(contentsOf: url) else {
            lyricsStatus.stringValue = "未找到同名 .lrc"
            lyricsStack.addArrangedSubview(UIHelpers.emptyLabel("将同名 .lrc 文件放在歌曲旁边即可显示歌词。"))
            return
        }
        lyrics = LyricParser.parseLRC(text)
        lyricsStatus.stringValue = lyrics.isEmpty ? "歌词文件为空" : "\(lyrics.count) 行歌词"
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
        pendingCountLabel.stringValue = "\(playbackQueue.count) 首"
        libraryPendingCountLabel.stringValue = "\(playbackQueue.count) 首"
        UIHelpers.clear(pendingTrackStack)
        UIHelpers.clear(libraryPendingTrackStack)
        if playbackQueue.isEmpty {
            let text = "从歌曲列表或播放列表开始播放后，将在这里显示待播歌曲。"
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
}
