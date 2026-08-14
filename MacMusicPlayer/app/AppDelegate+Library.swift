import AppKit
import Foundation

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
        [miniVolume, detailVolume].forEach {
            $0.target = self
            $0.action = #selector(volumeChanged(_:))
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
        var scanFolders = folders
        // 调用方式
        if let newFolder = defaultFolderToSF() {
            scanFolders.append(newFolder)
        }

        for folder in scanFolders {
            let url = folder.resolvedURL()
            _ = url.startAccessingSecurityScopedResource()
            let scanned = TrackScanner.scan(folder: folder, url: url)
            url.stopAccessingSecurityScopedResource()
            folder.trackCount = scanned.count
            nextTracks.append(contentsOf: scanned)
        }
        tracks = nextTracks.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        LibraryJSONStore.save(tracks.map(TrackJSONRecord.init), named: "tracks")
        migratePlaylistsAfterScan()
        saveFolders()
        // renderFolderFilter()
        applySearch()
        renderFolders()
        renderPlaylists()
        statusLabel.stringValue = tracks.isEmpty ? "没有扫描到音乐" : AppText.loadedTrackCount(tracks.count)
    }

    func defaultFolderToSF() -> SourceFolder?{
        let fileManager = FileManager.default
        let folderURL = MusicDownloadManager.downloadsDirectory
        
        // 1. 检查目录是否存在
        var isDir: ObjCBool = false
        if !fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDir) || !isDir.boolValue {
            print("目录不存在: \(folderURL.path)")
            return nil
        }
        
        // 2. 明确类型的 BookmarkData 生成
        // 明确告诉编译器 options 是 URL.BookmarkCreationOptions 类型
        let bookmarkData = try? folderURL.bookmarkData(
            options: URL.BookmarkCreationOptions.withSecurityScope,
            includingResourceValuesForKeys: nil, // 这里在 Swift 中是可以传 nil 的
            relativeTo: nil
        )
        
        // 3. 修正变量名：这里必须使用 folderURL，之前报错是因为你用了 'url'
        let sourceFolder = SourceFolder(url: folderURL, bookmark: bookmarkData)
        
        return sourceFolder
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
            // 2. 每次输入时，取消上一个任务（如果还没执行的话）
        searchWorkItem?.cancel()
        
        // 3. 创建一个新的延迟任务
        let workItem = DispatchWorkItem { 
            // 这里放入你原本的搜索逻辑
            if self.searchMode == .online{
                print("进入netWorkSeach")
                self.netWorkSeach()
            }else{
                self.applySearch()
            }
        }
        
        // 4. 保存这个任务并延迟 0.5 秒执行
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    @objc func folderFilterChanged() {
        searchMode = folderFilterPopup.indexOfSelectedItem == 1 ? .online : .local
        UserDefaults.standard.set(self.searchMode.rawValue, forKey: "searchMode")
        print("searchMode == \(searchMode.rawValue)  flag  = \(searchMode == .online)")
        if searchMode == .online{
            print("进入netWorkSeach")
            netWorkSeach()
         }else{
            applySearch()
        }
    }

    func applySearch() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let scopedTracks: [Track]
        scopedTracks = tracks

        if query.isEmpty {
            filteredTracks = scopedTracks
        } else {
            filteredTracks = scopedTracks.filter {
                "\($0.title) \($0.artist)"
                    .lowercased()
                    .contains(query)
            }
        }
        renderTracks()
        dismissSearchFocus()
    }

    func netWorkSeach() {
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty || query.count < 2{
            print("没参数，不请求网络")
            return
        }
        guard let url = buildURL(baseURL:AppText.listURL,params: [
            "msg": query,
            "type": "json"]) 
        else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("网络请求失败: \(String(describing: error))")
                return
            }
            do {
                let decoder = JSONDecoder()
                let decodedSongs = try decoder.decode([NetworkSongListItem].self, from: data)
                
                DispatchQueue.main.async {
                                
                    // 1. 先把现有的 tracks 转换成字典，方便快速查找
                    // key 是 id，value 是对应的 Track 对象
                    let tracksDict = Dictionary(uniqueKeysWithValues: self.tracks.map { ($0.id, $0) })

                    // 2. 遍历网络返回的歌曲，进行匹配或创建
                    let temTracks = decodedSongs.map { song -> Track in
                        let newID = Track.stableID(artist: song.singerName, title: song.songTitle)
                        
                        // 如果字典里已经有了这个 ID，直接返回已有的对象
                        if let existingTrack = tracksDict[newID] {
                            return existingTrack
                        }
                        
                        // 如果没有，构建一个新的
                        return Track(
                            id: newID,
                            folderID: song.songMid,
                            url: url,
                            folderURL: MusicDownloadManager.downloadsDirectory,
                            title: song.songTitle,
                            artist: song.singerName,
                            ext: "",
                            artworkURL: nil,
                            lyricURL: nil,
                            embeddedArtwork: nil,
                            embeddedLyrics: nil,
                            source: .remote,    // 标记为网络内容
                            remoteURL: nil
                        )
                    }
            
                    self.filteredTracks = temTracks
                    self.renderTracks()
                    self.dismissSearchFocus()
                }
                
            } catch {
                print("JSON 解析失败: \(error)")
                print("data = \(String(describing: String(data: data, encoding: .utf8)))")
            }
        }.resume()
    }


    func netDetail(mid :String ,completion: @escaping (Track?) -> Void) {
        print("开始 = \(TimeHelper.now())")
        LoadingHUD.shared.show("正在加载歌曲...")
        guard let url = buildURL(baseURL:AppText.listURL,params: [
            "mid": mid,
            "type": "json"]) 
        else { 
            completion(nil)
            return 
        }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                print("url 结束 = \(TimeHelper.now())")
                let decoder = JSONDecoder()
                let song = try decoder.decode(NetworkSong.self, from: data)
                print("decode 结束 = \(TimeHelper.now())")
                let temTrack = Track(
                        id: Track.stableID(artist: song.singerName, title: song.songName),
                        folderID: song.songMid,
                        url: song.songURL,
                        folderURL: MusicDownloadManager.downloadsDirectory,
                        title: song.songName,
                        artist: song.singerName,
                        ext: song.viewExtension,
                        artworkURL: song.albumPic,
                        lyricURL: nil,
                        embeddedArtwork: nil,
                        embeddedLyrics: song.songLyric,
                        source: .local,    // 标记为网络内容
                        remoteURL: nil
                )
                await MainActor.run {
                    if let index = self.filteredTracks.firstIndex(where: { $0.id == temTrack.id }) {
                        // 2. 如果存在，直接替换
                        self.filteredTracks[index] = temTrack
                        print("已更新 ID 为 \(temTrack.id) 的轨道数据")
                        print("更新 结束 = \(TimeHelper.now())")
                    }
                    self.tracks.append(temTrack)
                    LoadingHUD.shared.hide()
                    completion(temTrack)
                    print("结束 = \(TimeHelper.now())")
                }
                print("下载开始 = \(TimeHelper.now())")
                let paths = try await MusicDownloadManager.saveTrackData(song: song)
                print("封面位置: \(paths.artwork.path)")
                print("音频位置: \(paths.audio.path)")
                print("下载结束 = \(TimeHelper.now())")

            } catch {
                // 如果出错，这里会捕获到异常
                LoadingHUD.shared.hide()
                completion(nil)
                print("failure: \(error)")
            }
        }
                
    }

    func buildURL(baseURL: String, params: [String: String]) -> URL? {
        guard var components = URLComponents(string: baseURL) else {
            return nil
        }

        var queryItems = components.queryItems ?? []

        queryItems.append(
            contentsOf: params.map { key, value in
                URLQueryItem(name: key, value: value)
            }
        )

        components.queryItems = queryItems

        return components.url
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
            row.deleteButton.target = self
            row.deleteButton.action = #selector(deleteLocalTrack(_:))
            row.deleteButton.identifier = NSUserInterfaceItemIdentifier(track.id)
            trackStack.addArrangedSubview(row)
        }
    }


    func renderFolders() {
        folderCountLabel.stringValue = "\(folders.count) 个"
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
        let targetWidth : CGFloat

        if currentPage == playerPage {
            queuePanel = playerQueuePanel
            widthConstraint = playerQueueWidthConstraint
            targetWidth = playerPage.bounds.width * 0.33

        } else {
            // 主资料库页对应的待播清单面板与约束
            queuePanel = libraryQueuePanel
            targetWidth = libraryPage.bounds.width * 0.33
            widthConstraint = libraryQueueWidthConstraint
        }

        // print("toogle before libraryPanel.frame.width = \(playerPage.frame.width)")
        // print("toogle before libraryQueuePanel.frame.width =\(playerQueuePanel.frame.width)")
        // print("toogle before lbraryMainRow.frame.width =\(libraryMainRow.frame.width)")
        queuePanel.wantsLayer = true
        
        let isCurrentlyCollapsed = widthConstraint.constant == 0

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            context.allowsImplicitAnimation = true

            // 🌟 核心：直接通过动画修改 constant 的值
            // 如果当前收起，就将其撑开到 targetWidth；如果当前展开，就将其压扁到 0
            widthConstraint.animator().constant = isCurrentlyCollapsed ? targetWidth : 0
            
            // 配合透明度，视觉效果更好
            queuePanel.animator().alphaValue = isCurrentlyCollapsed ? 1.0 : 0.0
            
            // 刷新布局，驱动动画
            self.window.contentView?.layoutSubtreeIfNeeded()
        }, completionHandler: {
        })

        // print("toggle after libraryPanel.frame.width = \(libraryPanel.frame.width)")
        // print("toggle after libraryQueuePanel.frame.width =\(libraryQueuePanel.frame.width)")
        // print("toggle after lbraryMainRow.frame.width =\(libraryMainRow.frame.width)")
        // print("toggle after targetWidth.frame.width =\(targetWidth)")
    }

    @objc func removeFolder(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        folders.removeAll { $0.id == id }
        tracks.removeAll { $0.folderID == id }
        saveFolders()
        scanFolders()
    }

    @objc func deleteLocalTrack(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue,
              let track = tracks.first(where: { $0.id == id }),
              track.source == .local
        else { return }

        let alert = NSAlert()
        alert.messageText = "删除《\(track.title)》？"
        alert.informativeText = "歌曲原文件和对应 JSON 信息将移到废纸篓，可在废纸篓中恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "移到废纸篓")
        alert.addButton(withTitle: "取消")
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        do {
            let manager = FileManager.default
            if manager.fileExists(atPath: track.url.path) {
                try manager.trashItem(at: track.url, resultingItemURL: nil)
            }
            let sidecar = track.folderURL.appendingPathComponent("songDetail", isDirectory: true)
                .appendingPathComponent(track.id).appendingPathExtension("json")
            if manager.fileExists(atPath: sidecar.path) {
                try manager.trashItem(at: sidecar, resultingItemURL: nil)
            }
            tracks.removeAll { $0.id == id }
            playbackQueue.removeAll { $0.id == id }
            recentIDs.removeAll { $0 == id }
            playlists.indices.forEach { playlists[$0].trackIDs.removeAll { $0 == id } }
            if currentTrack?.id == id {
                PlayerManager.shared.stop()
                currentTrack = nil
            }
            LibraryJSONStore.save(tracks.map(TrackJSONRecord.init), named: "tracks")
            savePlaylists()
            UserDefaults.standard.set(recentIDs, forKey: "recentTracks")
            applySearch()
            renderPlaylists()
            renderPendingQueue()
        } catch {
            statusLabel.stringValue = "删除失败：\(error.localizedDescription)"
        }
    }

    @objc func trackRowClicked(_ sender: TrackRowView) {
        guard let track = filteredTracks.first(where: { $0.id == sender.trackID }) else {
            return
        }
        if track.source == .remote && !isSelectingTracks {
            self.netDetail(mid: track.folderID){ [weak self] downloadedTrack in

            guard let self,
                  let downloadedTrack else {
                return
            }
            // 下载完成以后
            // 重新进入后续逻辑
            self.hanndleCompetionTrackClick(
                track: downloadedTrack,
                sender: sender
            )
            }

            return   //
        }
        self.hanndleCompetionTrackClick(track: track,sender:sender)
    }

    func hanndleCompetionTrackClick(track: Track,sender: TrackRowView){

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
        if let decoded = LibraryJSONStore.load([SourceFolder].self, named: "folders") {
            folders = decoded
            return
        }
        // One-time migration from builds that stored the same Codable payload
        // in UserDefaults.
        if let data = UserDefaults.standard.data(forKey: "folders"),
           let decoded = try? JSONDecoder().decode([SourceFolder].self, from: data) {
            folders = decoded
            saveFolders()
        }
    }

    func saveFolders() {
        LibraryJSONStore.save(folders, named: "folders")
    }
}
