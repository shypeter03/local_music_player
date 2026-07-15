import AppKit

extension AppDelegate {

    func bindActions() {
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
        enqueueSelectedButton.target = self
        enqueueSelectedButton.action = #selector(enqueueSelectedTracks)
        libraryQueueButton.target = self
        libraryQueueButton.action = #selector(toggleQueueSidebar)
        playerQueueButton.target = self
        playerQueueButton.action = #selector(toggleQueueSidebar)
        selectPlaylistTracksButton.target = self
        selectPlaylistTracksButton.action = #selector(togglePlaylistTrackSelection)
        removeSelectedPlaylistTracksButton.target = self
        removeSelectedPlaylistTracksButton.action = #selector(removeSelectedPlaylistTracks)
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
        // shuffleButton.target = self
        // shuffleButton.action = #selector(toggleShuffle)
        // detailShuffleButton.target = self
        // detailShuffleButton.action = #selector(toggleShuffle)
        repeatButton.target = self
        repeatButton.action = #selector(cycleRepeatMode)
        detailRepeatButton.target = self
        detailRepeatButton.action = #selector(cycleRepeatMode)
        playPlaylistButton.target = self
        playPlaylistButton.action = #selector(playSelectedPlaylist)
        playbackOrderPopup.target = self
        playbackOrderPopup.action = #selector(playbackOrderChanged)
        [sideSeek, miniSeek, seekBar].forEach {
            $0.target = self
            $0.action = #selector(seekChanged(_:))
        }
        playbackOrderPopup.contentTintColor = Theme.accent
        updatePlaybackModeButtons()
    }

    @objc func showLibrary() { showPage(libraryPage) }
    @objc func showFolders() { showPage(foldersPage) }
    @objc func showPlaylists() { showPage(playlistsPage) }

    @objc func openPlayerFromCurrent() {
        if currentTrack == nil, let first = tracks.first {
            play(track: first, resetQueue: true)
        }
        showPage(playerPage)
    }

    func showPage(_ page: NSView) {
        // 记录当前页面
        self.currentPage = page

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

            // 👈 确保这里没有任何 window.setFrame(...) 的调用！
    }

    @objc func addFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "选择"
        if panel.runModal() == .OK {
            for url in panel.urls {
                let bookmark = try? url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                if folders.contains(where: { $0.path == url.path }) { continue }
                folders.append(SourceFolder(url: url, bookmark: bookmark))
            }
            saveFolders()
            scanFolders()
            showPage(foldersPage)
        }
    }

    @objc func scanFoldersAction() { scanFolders() }

    func scanFolders() {
        statusLabel.stringValue = "正在扫描…"
        var nextTracks: [Track] = []
        for folder in folders {
            let url = folder.resolvedURL()
            _ = url.startAccessingSecurityScopedResource()
            let scanned = TrackScanner.scan(folder: folder, url: url)
            url.stopAccessingSecurityScopedResource()
            folder.trackCount = scanned.count
            nextTracks.append(contentsOf: scanned)
        }
        tracks = nextTracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        migratePlaylistsAfterScan()
        saveFolders()
        if let selectedFolderID, !folders.contains(where: { $0.id == selectedFolderID }) {
            self.selectedFolderID = nil
            UserDefaults.standard.removeObject(forKey: "selectedFolderID")
        }
        renderFolderFilter()
        applySearch()
        renderFolders()
        renderPlaylists()
        statusLabel.stringValue = tracks.isEmpty ? "没有扫描到音乐" : AppText.loadedTrackCount(tracks.count)
    }

    private func migratePlaylistsAfterScan() {
        var changed = false
        for index in playlists.indices {
            let before = playlists[index].trackIDs
            PlaylistHelpers.migratePlaylist(&playlists[index], tracks: tracks)
            if playlists[index].trackIDs != before {
                changed = true
            }
        }
        recentIDs = PlaylistHelpers.deduplicatedTrackIDs(recentIDs, tracks: tracks)
            .filter { id in tracks.contains(where: { $0.id == id }) }
        if changed {
            savePlaylists()
        }
        UserDefaults.standard.set(recentIDs, forKey: "recentTracks")
    }

    @objc func searchChanged() {
        applySearch()
    }

    @objc func folderFilterChanged() {
        selectedFolderID = folderFilterPopup.selectedItem?.representedObject as? String
        if let selectedFolderID {
            UserDefaults.standard.set(selectedFolderID, forKey: "selectedFolderID")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedFolderID")
        }
        applySearch()
    }

    func applySearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scopedTracks: [Track]
        if let selectedFolderID {
            scopedTracks = tracks.filter { $0.folderID == selectedFolderID }
        } else {
            scopedTracks = tracks
        }

        if query.isEmpty {
            filteredTracks = scopedTracks
        } else {
            filteredTracks = scopedTracks.filter {
                "\($0.title) \($0.artist) \($0.folderURL.lastPathComponent) \($0.url.lastPathComponent)"
                    .lowercased()
                    .contains(query)
            }
        }
        renderTracks()
        // renderRecent()
    }

    func renderTracks() {
        libraryCountLabel.stringValue = AppText.trackCount(filteredTracks.count)
        updateSelectionControls()
        UIHelpers.clear(trackStack)
        if filteredTracks.isEmpty {
            trackStack.addArrangedSubview(UIHelpers.emptyLabel(AppText.noMusics))
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

    // func renderRecent() {
    //     UIHelpers.clear(recentStack)
    //     let recent = recentIDs.compactMap { id in tracks.first(where: { $0.id == id }) }.prefix(5)
    //     if recent.isEmpty {
    //         recentStack.addArrangedSubview(UIHelpers.emptyLabel("播放后会出现在这里"))
    //         return
    //     }
    //     for track in recent {
    //         let row = TrackRowView()
    //         row.configure(track: track, index: 0, active: false)
    //         row.target = self
    //         row.action = #selector(trackRowClicked(_:))
    //         recentStack.addArrangedSubview(row)
    //     }
    // }

    func renderFolders() {
        folderCountLabel.stringValue = "\(folders.count) 个"
        renderFolderFilter()
        UIHelpers.clear(folderStack)
        if folders.isEmpty {
            folderStack.addArrangedSubview(UIHelpers.emptyLabel("尚未添加文件夹，可一次选择多个本地和 iCloud 文件夹。"))
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

    func renderFolderFilter() {
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

    func updateSelectionControls() {
        selectTracksButton.title = isSelectingTracks ? AppText.done : AppText.select
        selectionStatusLabel.stringValue = isSelectingTracks ? AppText.selectedCount(selectedTrackIDs.count) : AppText.noSelection
        addSelectedButton.isEnabled = isSelectingTracks && !selectedTrackIDs.isEmpty
        enqueueSelectedButton.isEnabled = isSelectingTracks && !selectedTrackIDs.isEmpty
    }

    @objc func enqueueSelectedTracks() {
        let selection = filteredTracks.filter { selectedTrackIDs.contains($0.id) }
        guard !selection.isEmpty else { return }
        enqueueTracks(selection)
        selectedTrackIDs.removeAll()
        isSelectingTracks = false
        renderTracks()
        savePlaybackQueue() // 👈 【新增】保存状态
    }

    @objc func toggleQueueSidebar() {
        // 1. 根据当前正在展示的页面，动态决定操作哪一个侧边栏及约束
        let queuePanel: NSStackView
        let widthConstraint: NSLayoutConstraint

        if currentPage == playerPage {
            queuePanel = playerQueuePanel
                widthConstraint = playerQueueWidthConstraint
        } else {
            // 主资料库页对应的待播清单面板与约束
            queuePanel = libraryQueuePanel
                widthConstraint = libraryQueueWidthConstraint
        }

        // 1. 确保开启了 Layer 支持
        queuePanel.wantsLayer = true
        
        // 2. 物理宽度直接锁死在 150，不再通过动画动态去变它
        // widthConstraint.constant = 150 
        widthConstraint.isActive = true
        
        // 3. 判断当前是否是隐藏状态
        let isCurrentlyHidden = queuePanel.isHidden || queuePanel.alphaValue == 0

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2 // 稍微缩短时间，让淡入淡出显得更干脆利落
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

            if isCurrentlyHidden {
                // 🌟 展开：先让透明度归零，解除隐藏，然后优雅淡入到 1.0
                queuePanel.alphaValue = 0
                queuePanel.isHidden = false
                queuePanel.animator().alphaValue = 1.0
            } else {
                // 🌟 收起：动画让透明度变到 0.0
                queuePanel.animator().alphaValue = 0.0
            }
            
            // 刷新布局
            self.window.contentView?.layoutSubtreeIfNeeded()
        }, completionHandler: {
            // 4. 动画结束：如果是收起，彻底将其 setHidden，释放渲染开销
            if !isCurrentlyHidden {
                queuePanel.isHidden = true
            }
        })
    }

    @objc func removeFolder(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        folders.removeAll { $0.id == id }
        tracks.removeAll { $0.folderID == id }
        if selectedFolderID == id {
            selectedFolderID = nil
            UserDefaults.standard.removeObject(forKey: "selectedFolderID")
        }
        saveFolders()
        scanFolders()
    }

    @objc func trackRowClicked(_ sender: TrackRowView) {
        guard let track = tracks.first(where: { $0.id == sender.trackID }) else { return }
        if !playlistsPage.isHidden, isSelectingPlaylistTracks {
            if selectedPlaylistTrackIDs.contains(track.id) {
                selectedPlaylistTrackIDs.remove(track.id)
            } else {
                selectedPlaylistTrackIDs.insert(track.id)
            }
            renderSelectedPlaylistTracks()
            return
        }
        if isSelectingTracks {
            if selectedTrackIDs.contains(track.id) {
                selectedTrackIDs.remove(track.id)
            } else {
                selectedTrackIDs.insert(track.id)
            }
            renderTracks()
            return
        }
        if !playlistsPage.isHidden, let playlist = selectedPlaylist() {
            let playlistTracks = PlaylistHelpers.deduplicatedTrackIDs(playlist.trackIDs, tracks: tracks)
                .compactMap { id in tracks.first(where: { $0.id == id }) }
            play(track: track, resetQueue: false)
            resetPlaybackQueue(with: playlistTracks, startingAt: track)
        } else {
            play(track: track, resetQueue: true)
        }
    }

    @objc func toggleTrackSelection() {
        isSelectingTracks.toggle()
        if !isSelectingTracks {
            selectedTrackIDs.removeAll()
        }
        renderTracks()
    }

    // @objc func clearRecent() {
    //     recentIDs = []
    //     UserDefaults.standard.removeObject(forKey: "recentTracks")
    //     // renderRecent()
    // }

    func loadFolders() {
        guard let data = UserDefaults.standard.data(forKey: "folders"),
              let decoded = try? JSONDecoder().decode([SourceFolder].self, from: data)
        else { return }
        folders = decoded
    }

    func saveFolders() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: "folders")
        }
    }
}
