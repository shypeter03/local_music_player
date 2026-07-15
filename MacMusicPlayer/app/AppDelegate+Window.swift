import AppKit

extension AppDelegate {

    func buildWindow() {
        window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        window.titlebarAppearsTransparent = true

        window.titleVisibility = .hidden

        window.styleMask.insert(.fullSizeContentView)

        window.center()
        window.minSize = NSSize(width: 920, height: 620)
        buildApplicationMenu()
        root.applyBackground(Theme.windowBackground)
        window.contentView = root

        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        [sidebar, content].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            root.addSubview($0)
        }

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: root.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 300),

            content.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            content.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            content.topAnchor.constraint(equalTo: root.topAnchor),
            content.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
    }

    func buildSidebar() {
        let brandIcon = UIHelpers.roundedImageView(size: 48)
        brandIcon.image = UIHelpers.symbolImage("music.note", pointSize: 26, color: .white)
        brandIcon.applyBackground(Theme.accent)

        let brand = brandIcon

        configureNavButton(libraryButton, image: "music.note.list")
        configureNavButton(foldersButton, image: "folder")
        configureNavButton(playlistsButton, image: "music.note.house")

        configureMiniPlayer()

        let stack = NSStackView(views: [brand, libraryButton, playlistsButton, foldersButton, NSView(), miniPlayer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 50),
            stack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -24),
            brand.widthAnchor.constraint(equalTo: stack.widthAnchor),
            libraryButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            foldersButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            playlistsButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
            miniPlayer.widthAnchor.constraint(equalTo: stack.widthAnchor)
        ])
    }

    func configureMiniPlayer() {
        miniPlayer.applyCardStyle(cornerRadius: 10)
        miniPlayer.applyBackground(Theme.miniPlayerBackground)
        miniPlayer.translatesAutoresizingMaskIntoConstraints = false

        miniCover.image = UIHelpers.placeholderArtwork(size: 58)
        miniCover.imageScaling = .scaleAxesIndependently
        miniCover.wantsLayer = true
        miniCover.layer?.cornerRadius = 8
        miniCover.layer?.masksToBounds = true

        miniTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        miniTitle.textColor = Theme.text
        miniTitle.lineBreakMode = .byTruncatingTail
        miniArtist.font = .systemFont(ofSize: 12)
        miniArtist.textColor = Theme.secondaryText
        miniArtist.lineBreakMode = .byTruncatingTail
        [sideCurrentTime, sideDuration].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            $0.textColor = Theme.secondaryText
            $0.alignment = .center
        }

        let meta = NSStackView(views: [miniTitle, miniArtist])
        meta.orientation = .vertical
        meta.spacing = 4
        let top = NSStackView(views: [miniCover, meta])
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 12

        let progress = NSStackView(views: [sideCurrentTime, sideSeek, sideDuration])
        progress.orientation = .horizontal
        progress.alignment = .centerY
        progress.spacing = 8
        let controls = NSStackView(views: [ prevButton, playButton, nextButton, repeatButton])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.distribution = .gravityAreas
        controls.spacing = 10
        [ prevButton, playButton, nextButton, repeatButton].forEach(configureIconButton)
        playButton.contentTintColor = Theme.accent

        let stack = NSStackView(views: [top, progress, controls])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        miniPlayer.addSubview(stack)

        NSLayoutConstraint.activate([
            miniPlayer.heightAnchor.constraint(equalToConstant: 178),
            miniCover.widthAnchor.constraint(equalToConstant: 58),
            miniCover.heightAnchor.constraint(equalToConstant: 58),
            sideCurrentTime.widthAnchor.constraint(equalToConstant: 38),
            sideDuration.widthAnchor.constraint(equalToConstant: 38),
            stack.leadingAnchor.constraint(equalTo: miniPlayer.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: miniPlayer.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: miniPlayer.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: miniPlayer.bottomAnchor, constant: -14)
        ])

        let click = NSClickGestureRecognizer(
                target: self,
                action: #selector(openPlayerFromCurrent)
                )

        miniCover.addGestureRecognizer(click)
        let titleClick = NSClickGestureRecognizer(
                target: self,
                action: #selector(openPlayerFromCurrent)
                )
        miniTitle.addGestureRecognizer(titleClick)
    }

    func buildLibraryPage() {
        addPage(libraryPage)

        let header = makeHeader(eyebrow: "Library", title: "音乐列表")
        searchField.placeholderString = "搜索歌名、艺术家、文件夹"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        folderFilterPopup.translatesAutoresizingMaskIntoConstraints = false
        folderFilterPopup.bezelStyle = .rounded
        let refresh = NSButton(title: "刷新扫描", target: self, action: #selector(scanFoldersAction))
        refresh.bezelStyle = .rounded
        configureQueueButton(libraryQueueButton)
        let headerActions = NSStackView(views: [folderFilterPopup, searchField, refresh, libraryQueueButton])
        headerActions.orientation = .horizontal
        headerActions.spacing = 10

        let top = NSStackView(views: [header, headerActions])
        top.orientation = .horizontal
        top.alignment = .bottom
        top.distribution = .gravityAreas
        top.translatesAutoresizingMaskIntoConstraints = false
        libraryPage.addSubview(top)


        let recentPanel = makePanel(title: "最近播放", trailing: makeSmallButton("清空", action: #selector(clearRecent)))
        for row in recentStack.arrangedSubviews {
            if let constraint = row.constraints.first(where: { $0.firstAttribute == .height }) {
                constraint.constant = 36 // 从原先可能较大的高度缩减至 36
            }
        }
        configureStack(recentStack)
        recentPanel.addArrangedSubview(recentStack)

        selectTracksButton.bezelStyle = .rounded
        addSelectedButton.bezelStyle = .rounded
        addSelectedButton.contentTintColor = Theme.accent
        enqueueSelectedButton.bezelStyle = .rounded
        enqueueSelectedButton.contentTintColor = Theme.accent
        selectionStatusLabel.font = .systemFont(ofSize: 12)
        selectionStatusLabel.textColor = Theme.secondaryText
        let libraryTools = NSStackView(views: [selectionStatusLabel, libraryCountLabel, selectTracksButton, enqueueSelectedButton, addSelectedButton])
        libraryTools.orientation = .horizontal
        libraryTools.alignment = .centerY
        libraryTools.spacing = 10
        let libraryPanel = makePanel(title: "歌曲", trailing: libraryTools)
        configureStack(trackStack)
        let scroll = UIHelpers.scrollView(containing: trackStack)
        libraryPanel.addArrangedSubview(scroll)

        libraryQueuePanel = makePanel(title: "待播清单", trailing: libraryPendingCountLabel)
        configureStack(libraryPendingTrackStack)
        libraryQueuePanel.addArrangedSubview(UIHelpers.scrollView(containing: libraryPendingTrackStack))
        libraryQueuePanel.isHidden = true
        libraryQueueWidthConstraint = libraryQueuePanel.widthAnchor.constraint(equalToConstant: 280)

        let dashboard = NSStackView(views: [recentPanel])
        dashboard.orientation = .horizontal
        dashboard.spacing = 18
        dashboard.distribution = .fillEqually
        dashboard.translatesAutoresizingMaskIntoConstraints = false

        libraryLeftColumn = NSStackView(views: [dashboard, libraryPanel])
        libraryLeftColumn.orientation = .vertical
        libraryLeftColumn.spacing = 18
        libraryLeftColumn.translatesAutoresizingMaskIntoConstraints = false

        libraryMainRow = NSStackView(views: [libraryLeftColumn, libraryQueuePanel])
        libraryMainRow.orientation = .horizontal
        libraryMainRow.spacing = 18
        libraryMainRow.alignment = .top
        libraryMainRow.translatesAutoresizingMaskIntoConstraints = false

        libraryPage.addSubview(libraryMainRow)

        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: libraryPage.leadingAnchor, constant: 34),
            top.trailingAnchor.constraint(equalTo: libraryPage.trailingAnchor, constant: -34),
            top.topAnchor.constraint(equalTo: libraryPage.topAnchor, constant: 34),
            folderFilterPopup.widthAnchor.constraint(equalToConstant: 180),
            searchField.widthAnchor.constraint(equalToConstant: 280),

            libraryMainRow.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            libraryMainRow.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            libraryMainRow.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 24),
            libraryMainRow.bottomAnchor.constraint(equalTo: libraryPage.bottomAnchor, constant: -34),

            dashboard.heightAnchor.constraint(equalToConstant: 290),

            libraryQueuePanel.heightAnchor.constraint(equalTo: libraryLeftColumn.heightAnchor)
        ])
    }

    func configureNowCard() {
        nowCard.applyCardStyle(cornerRadius: 10)
        nowCard.applyBackground(Theme.nowPlayingBackground)
        nowCard.translatesAutoresizingMaskIntoConstraints = false
        nowCover.image = UIHelpers.placeholderArtwork(size: 58)
        nowCover.imageScaling = .scaleAxesIndependently
        nowCover.wantsLayer = true
        nowCover.layer?.cornerRadius = 8
        nowCover.layer?.masksToBounds = true

        nowTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        nowTitle.textColor = Theme.text
        nowTitle.lineBreakMode = .byTruncatingTail
        nowArtist.font = .systemFont(ofSize: 12)
        nowArtist.textColor = Theme.secondaryText
        nowArtist.lineBreakMode = .byTruncatingTail
        [miniCurrentTime, miniDuration].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            $0.textColor = Theme.secondaryText
            $0.alignment = .center
        }

        let meta = NSStackView(views: [nowTitle, nowArtist])
        meta.orientation = .vertical
        meta.spacing = 4
        let top = NSStackView(views: [nowCover, meta])
        top.orientation = .horizontal
        top.alignment = .centerY
        top.spacing = 12
        let progress = NSStackView(views: [miniCurrentTime, miniSeek, miniDuration])
        progress.orientation = .horizontal
        progress.alignment = .centerY
        progress.spacing = 8
        let stack = NSStackView(views: [top, progress])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        nowCard.addSubview(stack)

        NSLayoutConstraint.activate([
            nowCard.heightAnchor.constraint(equalToConstant: 150),
            nowCover.widthAnchor.constraint(equalToConstant: 58),
            nowCover.heightAnchor.constraint(equalToConstant: 58),
            miniCurrentTime.widthAnchor.constraint(equalToConstant: 38),
            miniDuration.widthAnchor.constraint(equalToConstant: 38),
            stack.leadingAnchor.constraint(equalTo: nowCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: nowCard.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: nowCard.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: nowCard.bottomAnchor, constant: -14)
        ])

        nowCard.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(openPlayerFromCurrent)))
        nowCover.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(openPlayerFromCurrent)))
        nowTitle.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(openPlayerFromCurrent)))
    }

    func buildFoldersPage() {
        addPage(foldersPage)

        let header = makeHeader(eyebrow: "Sources", title: "文件夹管理")
        configurePrimaryButton(addFolderButton)
        rescanButton.bezelStyle = .rounded
        let actions = NSStackView(views: [addFolderButton, rescanButton])
        actions.orientation = .horizontal
        actions.spacing = 10

        let top = NSStackView(views: [header, actions])
        top.orientation = .horizontal
        top.alignment = .bottom
        top.distribution = .gravityAreas
        top.translatesAutoresizingMaskIntoConstraints = false

        let intro = makePanel(title: "可同时引入本地文件夹和 iCloud 文件夹", trailing: nil)
        let introText = NSTextField(labelWithString: "可一次选择多个文件夹，也可多次添加。iCloud Drive 中已同步到本机的音乐文件会被扫描。")
        introText.textColor = Theme.secondaryText
        introText.lineBreakMode = .byWordWrapping
        intro.addArrangedSubview(introText)

        let folderPanel = makePanel(title: "已引入文件夹", trailing: folderCountLabel)
        configureStack(folderStack)
        folderPanel.addArrangedSubview(UIHelpers.scrollView(containing: folderStack))

        foldersPage.addSubview(top)
        foldersPage.addSubview(intro)
        foldersPage.addSubview(folderPanel)

        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: foldersPage.leadingAnchor, constant: 34),
            top.trailingAnchor.constraint(equalTo: foldersPage.trailingAnchor, constant: -34),
            top.topAnchor.constraint(equalTo: foldersPage.topAnchor, constant: 34),

            intro.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            intro.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            intro.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 24),

            folderPanel.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            folderPanel.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            folderPanel.topAnchor.constraint(equalTo: intro.bottomAnchor, constant: 18),
            folderPanel.bottomAnchor.constraint(equalTo: foldersPage.bottomAnchor, constant: -34)
        ])
    }

    func buildPlaylistsPage() {
        addPage(playlistsPage)

        let header = makeHeader(eyebrow: "Playlists", title: "播放列表")
        configurePrimaryButton(newPlaylistButton)
        deletePlaylistButton.bezelStyle = .rounded
        deletePlaylistButton.contentTintColor = Theme.destructive
        playbackOrderPopup.addItems(withTitles: ["顺序播放", "随机播放"])
        playbackOrderPopup.selectItem(at: isShuffleEnabled ? 1 : 0)
        playbackOrderPopup.bezelStyle = .rounded
        let actions = NSStackView(views: [playbackOrderPopup, playPlaylistButton, newPlaylistButton, deletePlaylistButton])
        actions.orientation = .horizontal
        actions.spacing = 10

        let top = NSStackView(views: [header, actions])
        top.orientation = .horizontal
        top.alignment = .bottom
        top.distribution = .gravityAreas
        top.translatesAutoresizingMaskIntoConstraints = false

        let listPanel = makePanel(title: "列表", trailing: playlistCountLabel)
        configureStack(playlistStack)
        listPanel.addArrangedSubview(UIHelpers.scrollView(containing: playlistStack))

        selectPlaylistTracksButton.bezelStyle = .rounded
        removeSelectedPlaylistTracksButton.bezelStyle = .rounded
        removeSelectedPlaylistTracksButton.contentTintColor = Theme.destructive
        playlistSelectionStatusLabel.font = .systemFont(ofSize: 12)
        playlistSelectionStatusLabel.textColor = Theme.secondaryText
        let titleStack = NSStackView(views: [selectedPlaylistTitle, selectedPlaylistCountLabel])
        titleStack.orientation = .vertical
        titleStack.spacing = 2
        selectedPlaylistTitle.font = .systemFont(ofSize: 16, weight: .bold)
        selectedPlaylistTitle.textColor = Theme.text
        selectedPlaylistCountLabel.font = .systemFont(ofSize: 12)
        selectedPlaylistCountLabel.textColor = Theme.secondaryText
        let playlistTools = NSStackView(views: [playlistSelectionStatusLabel, selectPlaylistTracksButton, removeSelectedPlaylistTracksButton, titleStack])
        playlistTools.orientation = .horizontal
        playlistTools.alignment = .centerY
        playlistTools.spacing = 8
        let tracksPanel = makePanel(title: "歌曲", trailing: playlistTools)
        configureStack(playlistTrackStack)
        tracksPanel.addArrangedSubview(UIHelpers.scrollView(containing: playlistTrackStack))

        playlistsPage.addSubview(top)
        playlistsPage.addSubview(listPanel)
        playlistsPage.addSubview(tracksPanel)

        NSLayoutConstraint.activate([
            top.leadingAnchor.constraint(equalTo: playlistsPage.leadingAnchor, constant: 34),
            top.trailingAnchor.constraint(equalTo: playlistsPage.trailingAnchor, constant: -34),
            top.topAnchor.constraint(equalTo: playlistsPage.topAnchor, constant: 34),

            listPanel.leadingAnchor.constraint(equalTo: top.leadingAnchor),
            listPanel.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 24),
            listPanel.bottomAnchor.constraint(equalTo: playlistsPage.bottomAnchor, constant: -34),
            listPanel.widthAnchor.constraint(equalTo: playlistsPage.widthAnchor, multiplier: 0.34),

            tracksPanel.leadingAnchor.constraint(equalTo: listPanel.trailingAnchor, constant: 18),
            tracksPanel.trailingAnchor.constraint(equalTo: top.trailingAnchor),
            tracksPanel.topAnchor.constraint(equalTo: listPanel.topAnchor),
            tracksPanel.bottomAnchor.constraint(equalTo: listPanel.bottomAnchor)
        ])
    }

    func buildPlayerPage() {
        addPage(playerPage)
        backButton.bezelStyle = .inline
        backButton.contentTintColor = Theme.accent
        backButton.translatesAutoresizingMaskIntoConstraints = false

        playerAlbumPanel = NSStackView()
        let albumPanel = playerAlbumPanel!
        albumPanel.orientation = .vertical
        albumPanel.alignment = .centerX
        albumPanel.spacing = 18
        albumPanel.applyCardStyle(cornerRadius: 12)
        albumPanel.applyBackground(Theme.nowPlayingBackground)
        albumPanel.translatesAutoresizingMaskIntoConstraints = false
        albumPanel.setContentHuggingPriority(.required, for: .horizontal)
        albumPanel.edgeInsets = NSEdgeInsets(top: 30, left: 28, bottom: 30, right: 28)

        detailCover.image = UIHelpers.placeholderArtwork(size: 360)
        detailCover.imageScaling = .scaleAxesIndependently
        detailCover.wantsLayer = true
        detailCover.layer?.cornerRadius = 12
        detailCover.layer?.masksToBounds = true

        detailTitle.font = .systemFont(ofSize: 30, weight: .bold)
        detailTitle.textColor = Theme.text
        detailTitle.alignment = .center
        detailTitle.lineBreakMode = .byTruncatingTail
        detailArtist.font = .systemFont(ofSize: 15)
        detailArtist.textColor = Theme.secondaryText
        detailArtist.alignment = .center
        detailFolder.font = .systemFont(ofSize: 12)
        detailFolder.textColor = Theme.secondaryText
        detailFolder.alignment = .center
        detailFolder.lineBreakMode = .byTruncatingMiddle

        let controls = NSStackView(views: [detailPrevButton, detailPlayButton, detailNextButton, detailRepeatButton])
        controls.orientation = .horizontal
        controls.spacing = 14
        [detailPrevButton, detailPlayButton, detailNextButton, detailRepeatButton].forEach(configureIconButton)
        detailPlayButton.contentTintColor = Theme.accent

        [currentTime, durationTime].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            $0.textColor = Theme.secondaryText
        }
        let seek = NSStackView(views: [currentTime, seekBar, durationTime])
        seek.orientation = .horizontal
        seek.alignment = .centerY
        seek.spacing = 8

        [detailCover, detailTitle, detailArtist, detailFolder, controls, seek].forEach { albumPanel.addArrangedSubview($0) }

        playerQueuePanel = makePanel(title: "待播清单", trailing: pendingCountLabel)
        configureStack(pendingTrackStack)
        playerQueuePanel.addArrangedSubview(UIHelpers.scrollView(containing: pendingTrackStack))
        playerQueuePanel.isHidden = true
        playerQueuePanel.setContentHuggingPriority(.required, for: .horizontal)
        playerQueueWidthConstraint = playerQueuePanel.widthAnchor.constraint(equalToConstant: 280)

        playerLyricsPanel = makePanel(title: "歌词", trailing: lyricsStatus)
        configureStack(lyricsStack)
        playerLyricsPanel.addArrangedSubview(UIHelpers.scrollView(containing: lyricsStack))
        playerLyricsPanel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        configureQueueButton(playerQueueButton)
        let playerHeader = NSStackView(views: [backButton, NSView(), playerQueueButton])
        playerHeader.orientation = .horizontal
        playerHeader.alignment = .centerY
        playerHeader.spacing = 12
        playerHeader.translatesAutoresizingMaskIntoConstraints = false

        let playerContent = NSStackView(views: [albumPanel, playerLyricsPanel, playerQueuePanel])
        playerContent.orientation = .horizontal
        playerContent.spacing = 18
        playerContent.alignment = .top
        playerContent.translatesAutoresizingMaskIntoConstraints = false

        playerPage.addSubview(playerHeader)
        playerPage.addSubview(playerContent)

        playerAlbumWidthConstraint = albumPanel.widthAnchor.constraint(equalTo: playerPage.widthAnchor, multiplier: 0.42)

        NSLayoutConstraint.activate([
            playerHeader.leadingAnchor.constraint(equalTo: playerPage.leadingAnchor, constant: 34),
            playerHeader.trailingAnchor.constraint(equalTo: playerPage.trailingAnchor, constant: -34),
            playerHeader.topAnchor.constraint(equalTo: playerPage.topAnchor, constant: 28),

            playerContent.leadingAnchor.constraint(equalTo: playerPage.leadingAnchor, constant: 34),
            playerContent.trailingAnchor.constraint(equalTo: playerPage.trailingAnchor, constant: -34),
            playerContent.topAnchor.constraint(equalTo: playerHeader.bottomAnchor, constant: 36),
            playerContent.bottomAnchor.constraint(equalTo: playerPage.bottomAnchor, constant: -34),

            playerAlbumWidthConstraint,

            detailCover.widthAnchor.constraint(equalToConstant: 300),
            detailCover.heightAnchor.constraint(equalTo: detailCover.widthAnchor),
            seek.widthAnchor.constraint(equalTo: albumPanel.widthAnchor, constant: -56),
            currentTime.widthAnchor.constraint(equalToConstant: 42),
            durationTime.widthAnchor.constraint(equalToConstant: 42),

            playerQueuePanel.heightAnchor.constraint(equalTo: playerContent.heightAnchor),
            playerLyricsPanel.heightAnchor.constraint(equalTo: playerContent.heightAnchor)
        ])
    }

    func updatePlayerAlbumWidth() {
        playerAlbumWidthConstraint.isActive = false
        let multiplier: CGFloat = isQueueSidebarVisible ? 0.30 : 0.42
        playerAlbumWidthConstraint = playerAlbumPanel.widthAnchor.constraint(
            equalTo: playerPage.widthAnchor,
            multiplier: multiplier
        )
        playerAlbumWidthConstraint.isActive = true
    }

    func addPage(_ page: NSView) {
        page.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(page)
        let constraints = [
            page.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            page.topAnchor.constraint(equalTo: content.topAnchor),
            page.bottomAnchor.constraint(equalTo: content.bottomAnchor)
        ]
        pageConstraints[ObjectIdentifier(page)] = constraints
        NSLayoutConstraint.activate(constraints)
    }

    func configureNavButton(_ button: NSButton, image: String) {
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.alignment = .left
        button.image = UIHelpers.symbolImage(image, pointSize: 16, color: Theme.text)
        button.imagePosition = .imageLeading
        button.contentTintColor = Theme.accent
        button.font = .systemFont(ofSize: 14, weight: .semibold)
        button.setButtonType(.toggle)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.heightAnchor.constraint(equalToConstant: 42).isActive = true
    }

    func configureIconButton(_ button: NSButton) {
        button.bezelStyle = .circular
        button.font = .systemFont(ofSize: 16, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
    }

    func configureQueueButton(_ button: NSButton) {
        button.image = UIHelpers.symbolImage("list.bullet", pointSize: 16, color: Theme.accent)
        button.toolTip = "显示待播清单"
        configureIconButton(button)
        button.contentTintColor = Theme.accent
    }

    func configurePrimaryButton(_ button: NSButton) {
        button.bezelStyle = .rounded
        button.contentTintColor = Theme.accent
        button.font = .systemFont(ofSize: 13, weight: .semibold)
    }

    func makeSmallButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .inline
        button.contentTintColor = Theme.accent
        return button
    }

    func makeHeader(eyebrow: String, title: String) -> NSStackView {
        let eyebrowLabel = NSTextField(labelWithString: eyebrow)
        eyebrowLabel.font = .systemFont(ofSize: 12, weight: .medium)
        eyebrowLabel.textColor = Theme.secondaryText
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 38, weight: .bold)
        titleLabel.textColor = Theme.text
        let stack = NSStackView(views: [eyebrowLabel, titleLabel])
        stack.orientation = .vertical
        stack.spacing = 4
        return stack
    }

    func makePanel(title: String, trailing: NSView?) -> NSStackView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 16, weight: .bold)
        titleLabel.textColor = Theme.text
        let headerViews = trailing.map { [titleLabel, NSView(), $0] } ?? [titleLabel]
        let header = NSStackView(views: headerViews)
        header.orientation = .horizontal
        header.alignment = .centerY
        header.distribution = .gravityAreas

        let stack = NSStackView(views: [header])
        stack.orientation = .vertical
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        stack.applyPanelStyle()
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    func configureStack(_ stack: NSStackView) {
        stack.orientation = .vertical
        stack.spacing = 8
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
    }
}
