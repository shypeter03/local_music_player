import AppKit

extension AppDelegate {

    func renderPlaylists() {
        playlistCountLabel.stringValue = "\(playlists.count) 个"
        UIHelpers.clear(playlistStack)
        if playlists.isEmpty {
            playlistStack.addArrangedSubview(UIHelpers.emptyLabel("还没有播放列表。点击“新建列表”创建一个。"))
        } else {
            for playlist in playlists {
                let row = NSButton(title: "\(playlist.name)", target: self, action: #selector(playlistClicked(_:)))
                row.bezelStyle = .regularSquare
                row.isBordered = false
                row.alignment = .left
                row.font = .systemFont(ofSize: 14, weight: playlist.id == selectedPlaylistID ? .bold : .regular)
                row.contentTintColor = playlist.id == selectedPlaylistID ? Theme.accent : Theme.text
                row.identifier = NSUserInterfaceItemIdentifier(playlist.id)
                row.translatesAutoresizingMaskIntoConstraints = false
                row.heightAnchor.constraint(equalToConstant: 44).isActive = true
                playlistStack.addArrangedSubview(row)
            }
        }
        renderSelectedPlaylistTracks()
    }

    func renderSelectedPlaylistTracks() {
        UIHelpers.clear(playlistTrackStack)
        guard let playlist = selectedPlaylist() else {
            // selectedPlaylistTitle.stringValue = AppText.selectPlaylist
            selectedPlaylistCountLabel.stringValue = AppText.trackCount(0)
            playlistTrackStack.addArrangedSubview(UIHelpers.emptyLabel("在左侧选择一个播放列表查看歌曲。"))
            deletePlaylistButton.isEnabled = false
            updatePlaylistSelectionControls()
            return
        }

        deletePlaylistButton.isEnabled = true
        let playlistTracks = PlaylistHelpers.deduplicatedTrackIDs(playlist.trackIDs, tracks: tracks)
            .compactMap { id in tracks.first(where: { $0.id == id }) }
        // selectedPlaylistTitle.stringValue = playlist.name
        selectedPlaylistCountLabel.stringValue = AppText.trackCount(playlistTracks.count)
        updatePlaylistSelectionControls()
        if playlistTracks.isEmpty {
            playlistTrackStack.addArrangedSubview(UIHelpers.emptyLabel("这个播放列表还没有可用歌曲。可在音乐列表中选择歌曲加入。"))
            return
        }

        for (index, track) in playlistTracks.enumerated() {
            let row = TrackRowView()
            row.configure(
                track: track,
                index: index + 1,
                active: track.id == currentTrack?.id,
                selected: selectedPlaylistTrackIDs.contains(track.id),
                selectionMode: isSelectingPlaylistTracks
            )
            row.target = self
            row.action = #selector(trackRowClicked(_:))
            row.deleteButton.target = self
            row.deleteButton.action = #selector(deleteLocalTrack(_:))
            row.deleteButton.identifier = NSUserInterfaceItemIdentifier(track.id)
            playlistTrackStack.addArrangedSubview(row)
        }
    }

    func selectedPlaylist() -> MusicPlaylist? {
        guard let selectedPlaylistID else { return nil }
        return playlists.first { $0.id == selectedPlaylistID }
    }

    @objc func addSelectedTracksToPlaylist() {
        guard !selectedTrackIDs.isEmpty else { return }
        if playlists.isEmpty {
            guard let playlist = promptForPlaylistName() else { return }
            playlists.append(playlist)
            selectedPlaylistID = playlist.id
        }

        guard let playlistID = choosePlaylistIDForAdding() else { return }
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        let orderedSelection = filteredTracks.map(\.id).filter { selectedTrackIDs.contains($0) }
        PlaylistHelpers.appendTracks(orderedSelection, to: &playlists[index], tracks: tracks)
        selectedPlaylistID = playlists[index].id
        savePlaylists()
        selectedTrackIDs.removeAll()
        isSelectingTracks = false
        renderTracks()
        renderPlaylists()
        showPage(playlistsPage)
    }

    @objc func createPlaylist() {
        guard let playlist = promptForPlaylistName() else { return }
        playlists.append(playlist)
        selectedPlaylistID = playlist.id
        savePlaylists()
        renderPlaylists()
        showPage(playlistsPage)
    }

    @objc func deleteSelectedPlaylist() {
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

    @objc func playlistClicked(_ sender: NSButton) {
        selectedPlaylistID = sender.identifier?.rawValue
        selectedPlaylistTrackIDs.removeAll()
        isSelectingPlaylistTracks = false
        renderPlaylists()
    }

    @objc func playbackOrderChanged() {
        let isShuffleEnabled = playbackOrderPopup.indexOfSelectedItem == 1
        self.repeatMode = isShuffleEnabled ? .shuffle : .all
        updatePlaybackModeButtons()
    }

    @objc func playSelectedPlaylist() {
        guard let playlist = selectedPlaylist() else { return }
        let playlistTracks = PlaylistHelpers.deduplicatedTrackIDs(playlist.trackIDs, tracks: tracks)
            .compactMap { id in tracks.first(where: { $0.id == id }) }
        let isShuffleEnabled = playbackOrderPopup.indexOfSelectedItem == 1
        guard let first = isShuffleEnabled ? playlistTracks.randomElement() : playlistTracks.first else { return }
        resetPlaybackQueue(with: playlistTracks, startingAt: first)
        play(track: first, resetQueue: false)
        playbackOrderChanged()
    }

    @objc func togglePlaylistTrackSelection() {
        isSelectingPlaylistTracks.toggle()
        if !isSelectingPlaylistTracks { selectedPlaylistTrackIDs.removeAll() }
        renderSelectedPlaylistTracks()
    }

    @objc func removeSelectedPlaylistTracks() {
        guard let playlistID = selectedPlaylistID,
              let index = playlists.firstIndex(where: { $0.id == playlistID }),
              !selectedPlaylistTrackIDs.isEmpty
        else { return }
        playlists[index].trackIDs.removeAll { selectedPlaylistTrackIDs.contains($0) }
        selectedPlaylistTrackIDs.removeAll()
        isSelectingPlaylistTracks = false
        savePlaylists()
        renderPlaylists()
    }

    func updatePlaylistSelectionControls() {
        selectPlaylistTracksButton.title = isSelectingPlaylistTracks ? AppText.done : AppText.select
        playlistSelectionStatusLabel.stringValue = isSelectingPlaylistTracks ? AppText.selectedCount(selectedPlaylistTrackIDs.count) : AppText.noSelection
        removeSelectedPlaylistTracksButton.isEnabled = isSelectingPlaylistTracks && !selectedPlaylistTrackIDs.isEmpty
    }

    func promptForPlaylistName() -> MusicPlaylist? {
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

    func choosePlaylistIDForAdding() -> String? {
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

    func loadPlaylists() {
        if let decoded = LibraryJSONStore.load([MusicPlaylist].self, named: "playlists") {
            playlists = decoded
            selectedPlaylistID = playlists.first?.id
            renderPlaylists()
            return
        }
        guard let data = UserDefaults.standard.data(forKey: "playlists"),
              let decoded = try? JSONDecoder().decode([MusicPlaylist].self, from: data) else {
            renderPlaylists()
            return
        }
        playlists = decoded
        selectedPlaylistID = playlists.first?.id
        savePlaylists()
        renderPlaylists()
    }

    func savePlaylists() {
        LibraryJSONStore.save(playlists, named: "playlists")
    }
}
