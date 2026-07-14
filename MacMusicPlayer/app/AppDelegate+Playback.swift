import AppKit
import AVFoundation

extension AppDelegate {

    func play(track: Track) {
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

    @objc func togglePlay() {
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

    @objc func playPrevious() { playByOffset(-1) }
    @objc func playNext() { playByOffset(1) }

    @objc func toggleShuffle() {
        isShuffleEnabled.toggle()
        UserDefaults.standard.set(isShuffleEnabled, forKey: "shuffleEnabled")
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
        guard let next = nextTrack(offset: offset, allowStopAtEnd: false) else { return }
        play(track: next)
    }

    func nextTrack(offset: Int, allowStopAtEnd: Bool) -> Track? {
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

    func playbackQueue() -> [Track] {
        if !playlistsPage.isHidden, let playlist = selectedPlaylist() {
            let playlistTracks = PlaylistHelpers.deduplicatedTrackIDs(playlist.trackIDs, tracks: tracks)
                .compactMap { id in tracks.first(where: { $0.id == id }) }
            if !playlistTracks.isEmpty {
                return playlistTracks
            }
        }
        if !filteredTracks.isEmpty {
            return filteredTracks
        }
        if let selectedFolderID {
            return tracks.filter { $0.folderID == selectedFolderID }
        }
        return tracks
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

        guard let next = nextTrack(offset: 1, allowStopAtEnd: true) else {
            audioPlayer?.currentTime = 0
            updatePlayButtons()
            updateProgress()
            isAdvancingAtEnd = false
            return
        }
        play(track: next)
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
}
