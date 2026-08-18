import AppKit
import SwiftUI
import UniformTypeIdentifiers

private let playerRed = Color(red: 0.78, green: 0.10, blue: 0.17)
private let playerCanvas = Color(red: 0.965, green: 0.965, blue: 0.975)
private let playerDivider = Color.black.opacity(0.10)

struct MusicRootView: View {
    @StateObject private var state = MusicAppState()
    @State private var importingFolders = false

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "music.note").font(.title3.weight(.bold)).foregroundStyle(playerRed)
                    Text("Ocean").font(.title2.weight(.bold))
                }.padding(.horizontal, 10).padding(.bottom, 24)
                navigation("发现", icon: "music.note.list", page: .library)
                navigation("歌单", icon: "music.note.house", page: .playlists)
                navigation("文件夹", icon: "folder", page: .folders)
                Spacer(minLength: 16)
                MiniPlayer(state: state)
            }.padding(20).frame(minWidth: 240)
                .background(.ultraThinMaterial)
                .overlay(alignment: .trailing) { Rectangle().fill(playerDivider).frame(width: 1) }
        } detail: {
            ZStack {
                PlayerBackground(currentArtwork: state.currentArtwork)
                Group {
                    switch state.page {
                    case .library:
                        LibraryPage(state: state)

                    case .folders:
                        FoldersPage(
                            state: state,
                            importingFolders: $importingFolders
                        )

                    case .playlists:
                        PlaylistsPage(state: state)

                    case .player:
                        PlayerPage(state: state)
                    }
                }
            }
            .frame(minWidth: 840, minHeight: 620)
        }
        .fileImporter(isPresented: $importingFolders, allowedContentTypes: [.folder], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result { state.addFolders(urls) }
        }
        .tint(playerRed)
        .onAppear {
            setupNowPlaying()
        }
    }

    private func navigation(_ title: String, icon: String, page: MusicAppState.Page) -> some View {
        Button { state.page = page } label: {
            HStack(spacing: 10) {
                Image(systemName: icon).frame(width: 18)
                Text(title).fontWeight(state.page == page ? .semibold : .regular)
                Spacer()
            }.padding(.horizontal, 12).padding(.vertical, 10)
        }.buttonStyle(.plain).foregroundStyle(state.page == page ? playerRed : .primary)
            .background(state.page == page ? playerRed.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 10))
    }

    private func setupNowPlaying() {
        NowPlayingManager.shared.onPlay = {
            if !state.isPlaying {
                state.togglePlayback()
            }
        }

        NowPlayingManager.shared.onPause = {
            if state.isPlaying {
                state.togglePlayback()
            }
        }

        NowPlayingManager.shared.onNext = {
            state.playNext()
        }

        NowPlayingManager.shared.onPrevious = {
            state.playPrevious()
        }

        NowPlayingManager.shared.onSeek = { position in
            state.seek(to: position)
        }
    }
}

private struct LibraryPage: View {
    @ObservedObject var state: MusicAppState
    @State private var isQueueVisible = false
    @State private var playlistPickerVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("发现").font(.largeTitle.bold())
                Text("\(state.filteredTracks.count) 首歌曲").foregroundStyle(.secondary)
                Spacer()
                Button { isQueueVisible.toggle() } label: { Label("待播", systemImage: "text.line.first.and.arrowtriangle.forward") }
                Picker("来源", selection: $state.searchMode) {
                    Text("本地").tag(SearchMode.local)
                    Text("网络").tag(SearchMode.online)
                }.labelsHidden().frame(width: 90)
                    .onChange(of: state.searchMode) { _ in if state.searchMode == .online { state.searchOnline() } }
                TextField("搜索歌名、艺术家", text: $state.searchText, onCommit: { if state.searchMode == .online { state.searchOnline() } }).textFieldStyle(.roundedBorder).frame(width: 240)
            }.padding(20)
            selectionBar.padding(.horizontal, 4)
            HStack(alignment: .top, spacing: 18) {
                trackList
                if isQueueVisible { QueuePanel(state: state).frame(width: 250) }
            }
        }.padding(34)
        .confirmationDialog("加入歌单", isPresented: $playlistPickerVisible, titleVisibility: .visible) {
            ForEach(state.playlists, id: \.id) { playlist in
                Button(playlist.name) { state.addSelectedTracks(to: playlist.id) }
            }
        } message: { Text("将选中的歌曲加入哪个歌单？") }
    }

    @ViewBuilder private var selectionBar: some View {
        HStack {
            Button(state.isSelectingTracks ? "完成" : "选择") {
                state.isSelectingTracks.toggle()
                if !state.isSelectingTracks { state.selectedTrackIDs.removeAll() }
            }
            if state.isSelectingTracks {
                Text("已选 \(state.selectedTrackIDs.count) 首").foregroundStyle(.secondary)
                Button("加入歌单") { playlistPickerVisible = true }.disabled(state.selectedTrackIDs.isEmpty || state.playlists.isEmpty)
                Button("加入待播") { state.enqueueSelectedTracks() }.disabled(state.selectedTrackIDs.isEmpty)
            }
            Spacer()
            Button("重新扫描") { state.scanFolders() }
        }.controlSize(.small)
    }

    private var trackList: some View {
        List(state.filteredTracks, id: \.id) { track in
            TrackRow(track: track, active: state.currentTrack?.id == track.id, selecting: state.isSelectingTracks) {
                if state.isSelectingTracks { state.toggleTrackSelection(track) }
                else { state.select(track) }
            } selected: { state.selectedTrackIDs.contains(track.id) }
        }.listStyle(.inset).scrollContentBackground(.hidden)
            .padding(8)
    }
}

private struct FoldersPage: View {
    @ObservedObject var state: MusicAppState
    @Binding var importingFolders: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("文件夹").font(.largeTitle.bold()); Spacer(); Button("添加文件夹") { importingFolders = true }; Button("重新扫描") { state.scanFolders() } }
            if state.folders.isEmpty { EmptyState(title: "还没有音乐文件夹", icon: "folder", detail: "添加一个包含音频文件的文件夹。") }
            else { List(state.folders, id: \.id) { folder in
                HStack { Label(folder.name, systemImage: "folder.fill"); Spacer(); Text("\(folder.trackCount) 首").foregroundStyle(.secondary); Button(role: .destructive) { state.removeFolder(folder) } label: { Image(systemName: "trash") }.buttonStyle(.borderless) }
            }.listStyle(.inset).scrollContentBackground(.hidden).padding(8).musicCard(cornerRadius: 18) }
        }.padding(34)
    }
}

private struct PlaylistsPage: View {
    @ObservedObject var state: MusicAppState
    @State private var newPlaylistVisible = false
    @State private var newPlaylistName = ""

    var body: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack { Text("歌单").font(.largeTitle.bold()); Spacer(); Button { newPlaylistVisible = true } label: { Image(systemName: "plus") } }
                List(selection: $state.selectedPlaylistID) { ForEach(state.playlists, id: \.id) { playlist in Text(playlist.name).tag(playlist.id) } }
                    .scrollContentBackground(.hidden).frame(minWidth: 190, maxWidth: 250)
                    .padding(8)
            }
            PlaylistDetail(state: state).frame(maxWidth: .infinity, maxHeight: .infinity).padding(12).musicCard(cornerRadius: 18)
        }.padding(34)
        .alert("新建歌单", isPresented: $newPlaylistVisible) { TextField("名称", text: $newPlaylistName); Button("创建") { let name = newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines); state.createPlaylist(named: name.isEmpty ? "新歌单" : name); newPlaylistName = "" }; Button("取消", role: .cancel) {} } message: { Text("输入歌单名称。") }
    }
}

private struct PlaylistDetail: View {
    @ObservedObject var state: MusicAppState
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let playlist = state.selectedPlaylist {
                HStack { Text(playlist.name).font(.title.bold()); Spacer(); Button("播放") { state.playSelectedPlaylist(shuffled: false) }; Button { state.playSelectedPlaylist(shuffled: true) } label: { Image(systemName: "shuffle") }; Button(role: .destructive) { state.deleteSelectedPlaylist() } label: { Image(systemName: "trash") } }
                HStack { Button(state.isSelectingPlaylistTracks ? "完成" : "选择") { state.isSelectingPlaylistTracks.toggle(); if !state.isSelectingPlaylistTracks { state.selectedPlaylistTrackIDs.removeAll() } }; if state.isSelectingPlaylistTracks { Text("已选 \(state.selectedPlaylistTrackIDs.count) 首").foregroundStyle(.secondary); Button("从歌单移除", role: .destructive) { state.removeSelectedPlaylistTracks() }.disabled(state.selectedPlaylistTrackIDs.isEmpty) }; Spacer() }.controlSize(.small)
                List(state.selectedPlaylistTracks, id: \.id) { track in TrackRow(track: track, active: state.currentTrack?.id == track.id, selecting: state.isSelectingPlaylistTracks) { if state.isSelectingPlaylistTracks { if state.selectedPlaylistTrackIDs.contains(track.id) { state.selectedPlaylistTrackIDs.remove(track.id) } else { state.selectedPlaylistTrackIDs.insert(track.id) } } else { state.select(track) } } selected: { state.selectedPlaylistTrackIDs.contains(track.id) } }.listStyle(.inset)
            } else { EmptyState(title: "选择一个歌单", icon: "music.note.list", detail: "从左侧选择歌单，或新建一个歌单。") }
        }
    }
}

private struct TrackRow: View {
    let track: Track; let active: Bool; let selecting: Bool; let action: () -> Void; let selected: () -> Bool
    var body: some View { Button(action: action) { HStack(spacing: 12) { if selecting { Image(systemName: selected() ? "checkmark.circle.fill" : "circle").foregroundStyle(selected() ? playerRed : .secondary) }; CoverArt(track: track, side: 36); VStack(alignment: .leading) { Text(track.title).lineLimit(1); Text(track.artist).font(.caption).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); Text(track.ext.uppercased()).font(.caption).foregroundStyle(.secondary); if active { Image(systemName: "speaker.wave.2.fill").foregroundStyle(playerRed) } } }.buttonStyle(.plain).padding(.vertical, 3) }
}

private struct EmptyState: View {
    let title: String; let icon: String; let detail: String
    var body: some View { VStack(spacing: 10) { Image(systemName: icon).font(.system(size: 32)).foregroundStyle(.secondary); Text(title).font(.headline); Text(detail).foregroundStyle(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity) }
}

private extension View {
    func musicCard(cornerRadius: CGFloat) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(.primary.opacity(0.06), lineWidth: 1))
    }
}

private struct MiniPlayer: View {
    @ObservedObject var state: MusicAppState
    var body: some View {
        VStack(spacing: 11) {
            Button { state.page = .player } label: {
                HStack(spacing: 12) {
                    CoverArt(track: state.currentTrack, side: 67)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(state.currentTrack?.title ?? "还没有播放歌曲").font(.headline).lineLimit(1)
                        Text(state.currentTrack?.artist ?? "从文件夹导入音乐开始").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        // Text(playbackModeTitle).font(.caption2.weight(.medium)).foregroundStyle(playerRed)
                    }
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
            HStack(spacing: 7) {
                Text(time(state.progress)).frame(width: 31, alignment: .leading)
                ProgressSlider(state: state)
                Text(time(state.duration)).frame(width: 31, alignment: .trailing)
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack(spacing: 13) {
                CircleControl(icon: "backward.fill") { state.playPrevious() }
                CircleControl(icon: state.isPlaying ? "pause.fill" : "play.fill", emphasized: true) { state.togglePlayback() }
                CircleControl(icon: "forward.fill") { state.playNext() }
                CircleControl(icon: repeatIcon, dimmed: state.repeatMode == .off) { state.cycleRepeatMode() }
            }
            HStack(spacing: 7) {
                Image(systemName: "speaker.wave.2").foregroundStyle(playerRed)
                Slider(value: Binding(get: { state.volume }, set: { state.setVolume($0) }), in: 0...1).tint(playerRed)
            }
        }.padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(.primary.opacity(0.06), lineWidth: 1))
    }

    private var repeatIcon: String { switch state.repeatMode { case .off, .all: return "repeat"; case .one: return "repeat.1"; case .shuffle: return "shuffle" } }
    private var playbackModeTitle: String { switch state.repeatMode { case .off: return "顺序播放"; case .all: return "列表循环"; case .one: return "单曲循环"; case .shuffle: return "随机播放" } }
}

private struct CircleControl: View {
    let icon: String
    var emphasized = false
    var dimmed = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: emphasized ? 12 : 9, weight: .bold))
                .frame(
                        width: emphasized ? 34 : 29,
                        height: emphasized ? 34 : 29
                        )
                .foregroundStyle(
                        emphasized
                        ? .white
                        : dimmed
                        ? .secondary
                        : playerRed
                        )
                .background(
                        emphasized
                        ? playerRed
                        : dimmed
                        ? Color.secondary.opacity(0.12)
                        : playerRed.opacity(0.12),
                        in: Circle()
                        )
        }
        .buttonStyle(.plain)
    }
}

private struct QueuePanel: View {
    @ObservedObject var state: MusicAppState
    var body: some View { VStack(alignment: .leading) { HStack { Text("待播队列").font(.headline); Spacer(); Button("清空") { state.clearQueue() }.controlSize(.small) }; List(state.pendingTracks, id: \.id) { track in HStack { VStack(alignment: .leading) { Text(track.title).lineLimit(1); Text(track.artist).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button { state.removeFromQueue(track) } label: { Image(systemName: "minus.circle") }.buttonStyle(.borderless) } }.listStyle(.plain) }.padding(14) }
}

private struct PlayerPage: View {
    @ObservedObject var state: MusicAppState
    var activeLyric: Int { state.lyrics.lastIndex(where: { $0.time <= state.progress }) ?? 0 }
    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width - 18
            let coverWidth = availableWidth * 2 / 5
            let lyricWidth = availableWidth * 3 / 5
            let artworkSide = min(coverWidth - 56, geometry.size.height * 0.53)
            HStack(alignment: .center, spacing: 18) {
                albumPanel(artworkSide: max(200, artworkSide))
                    .frame(width: coverWidth, height: geometry.size.height)
                lyricsPanel
                    .frame(width: lyricWidth, height: geometry.size.height)
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.padding(34)
    }

    private func albumPanel(artworkSide: CGFloat) -> some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            CoverArt(track: state.currentTrack, side: artworkSide)
            Text(state.currentTrack?.title ?? "请选择一首歌").font(.title.bold()).lineLimit(1)
            Text(state.currentTrack?.artist ?? "").foregroundStyle(.secondary)
            HStack {
                Text(time(state.progress)).frame(width: 31, alignment: .leading)
                ProgressSlider(state: state)
                Text(time(state.duration)).frame(width: 31, alignment: .trailing)
            }.font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            HStack(spacing: 18) {
                CircleControl(icon: "backward.fill") { state.playPrevious() }
                CircleControl(icon: state.isPlaying ? "pause.fill" : "play.fill", emphasized: true) { state.togglePlayback() }
                CircleControl(icon: "forward.fill") { state.playNext() }
                CircleControl(icon: repeatIcon, dimmed: state.repeatMode == .off) { state.cycleRepeatMode() }
            }
            HStack { Image(systemName: "speaker.wave.2").foregroundStyle(playerRed); Slider(value: Binding(get: { state.volume }, set: { state.setVolume($0) }), in: 0...1).tint(playerRed) }
            Spacer(minLength: 0)
        }.padding(28)
    }

    private var lyricsPanel: some View {
        VStack(spacing: 12) {
            // HStack { Text("歌词").font(.headline); Spacer(); Text("\(state.lyrics.count) 行").font(.caption).foregroundStyle(.secondary) }
            if state.lyrics.isEmpty {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "quote.bubble").font(.title2).foregroundStyle(playerRed)
                    Text("暂无歌词").font(.headline)
                    Text("播放带内嵌歌词的歌曲，或添加同名 .lrc 文件。")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 18) {
                            ForEach(Array(state.lyrics.enumerated()), id: \.offset) { index, line in
                                Text(line.text)
                                    .font(.title3)
                                    .foregroundStyle(index == activeLyric ? playerRed : .secondary)
                                    .scaleEffect(index == activeLyric ? 1.25 : 1.0)
                                    .multilineTextAlignment(.center)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .id(index)
                            }
                        }.frame(maxWidth: .infinity, minHeight: 1, alignment: .center)
                    }.onChange(of: activeLyric) { index in withAnimation { proxy.scrollTo(index, anchor: .center) } }
                }
            }
        }.padding(28)
    }
    private var repeatIcon: String { switch state.repeatMode { case .off, .all: return "repeat"; case .one: return "repeat.1"; case .shuffle: return "shuffle" } }
}

private struct ProgressSlider: View {
    @ObservedObject var state: MusicAppState
    var body: some View { Slider(value: Binding(get: { state.progress }, set: { state.seek(to: $0) }), in: 0...max(state.duration, 1)).tint(playerRed) }
}

private struct CoverArt: View {
    let track: Track?; let side: CGFloat
    var body: some View { Group { if let track, let data = ArtworkLoader.artworkData(for: track), let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFill() } else { Image(systemName: "music.note").resizable().scaledToFit().padding(side * 0.25).foregroundStyle(playerRed) } }.frame(width: side, height: side).background(playerRed.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: max(8, side * 0.08))) }
}

private struct PB: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color.white.opacity(0.025),
                        playerRed.opacity(0.035),
                        Color.clear
                    ]
                    : [
                        Color.black.opacity(0.025),
                        playerRed.opacity(0.025),
                        Color.clear
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private func time(_ seconds: Double) -> String {
    guard seconds.isFinite else { return "0:00" }

    let total = Int(seconds.rounded())

    return String(
        format: "%d:%02d",
        total / 60,
        total % 60
    )
}
