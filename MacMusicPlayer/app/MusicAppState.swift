import AppKit
import AVFoundation
import Foundation
import SwiftUI

@MainActor
final class MusicAppState: NSObject, ObservableObject {
    enum Page: Hashable { case library, folders, playlists, player }

    @Published var page: Page = .library
    @Published var folders: [SourceFolder] = []
    @Published var tracks: [Track] = []
    @Published var playlists: [MusicPlaylist] = []
    @Published var currentTrack: Track?
    @Published var playbackQueue: [Track] = []
    @Published var lyrics: [LyricLine] = []
    @Published var progress: Double = 0
    @Published var duration: Double = 0
    @Published var isPlaying = false
    @Published var volume: Double = UserDefaults.standard.object(forKey: "playbackVolume") as? Double ?? 1
    @Published var searchText = ""
    @Published var searchMode: SearchMode = SearchMode(rawValue: UserDefaults.standard.integer(forKey: "searchMode")) ?? .local {
        didSet { UserDefaults.standard.set(searchMode.rawValue, forKey: "searchMode") }
    }
    @Published var onlineTracks: [Track] = []
    @Published var isSearchingOnline = false
    @Published var selectedTrackIDs = Set<String>()
    @Published var selectedPlaylistID: String?
    @Published var selectedPlaylistTrackIDs = Set<String>()
    @Published var isSelectingTracks = false
    @Published var isSelectingPlaylistTracks = false
    @Published var isQueueVisible = false
    @Published var repeatMode: RepeatMode = RepeatMode(rawValue: UserDefaults.standard.integer(forKey: "repeatMode")) ?? .off
    @Published var recentIDs: [String] = UserDefaults.standard.stringArray(forKey: "recentTracks") ?? []

    @Published var currentArtwork: NSImage?

    private var timer: Timer?
    private var keyMonitor: Any?

    override init() {
        super.init()
        folders = LibraryJSONStore.load([SourceFolder].self, named: "folders") ?? []
        playlists = LibraryJSONStore.load([MusicPlaylist].self, named: "playlists") ?? []
        selectedPlaylistID = playlists.first?.id
        NotificationCenter.default.addObserver(
            self, selector: #selector(playerFinished),
            name: .playerDidFinishPlaying, object: nil
        )
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.isEditingText else { return event }
            return self.handlePlaybackShortcut(event) ? nil : event
        }
        scanFolders()

        // 冷恢复上次播放状态
        NowPlayingManager.shared.setEmptyState()

    }

    deinit {
        timer?.invalidate()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        NotificationCenter.default.removeObserver(self)
    }

    var filteredTracks: [Track] {
        if searchMode == .online { return onlineTracks }
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter { $0.title.localizedCaseInsensitiveContains(searchText) || $0.artist.localizedCaseInsensitiveContains(searchText) }
    }

    func searchOnline() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { onlineTracks = []; return }
        isSearchingOnline = true
        var components = URLComponents(string: AppText.listURL)
        components?.queryItems = [URLQueryItem(name: "msg", value: query), URLQueryItem(name: "type", value: "json")]
        guard let url = components?.url else { return }
        print("Searching online for :\(query)")
        Task {
            defer { isSearchingOnline = false }
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let songs = try? JSONDecoder().decode([NetworkSongListItem].self, from: data)
            else { return }
            onlineTracks = songs.map { song in
                let id = Track.stableID(artist: song.singerName, title: song.songTitle)
                return tracks.first(where: { $0.id == id }) ?? Track(id: id, folderID: song.songMid, url: url, folderURL: MusicDownloadManager.downloadsDirectory, title: song.songTitle, artist: song.singerName, album:nil, ext: "", artworkURL: nil, lyricURL: nil, embeddedArtwork: nil, embeddedLyrics: nil, source: .remote, remoteURL: nil)
            }
        }
    }

    func select(_ track: Track) {
        guard track.source == .remote else { play(track); return }
        downloadAndPlay(track)
    }

    var selectedPlaylist: MusicPlaylist? { playlists.first { $0.id == selectedPlaylistID } }
    var selectedPlaylistTracks: [Track] {
        guard let playlist = selectedPlaylist else { return [] }
        return PlaylistHelpers.deduplicatedTrackIDs(playlist.trackIDs, tracks: tracks).compactMap { id in tracks.first { $0.id == id } }
    }
    var pendingTracks: [Track] { Array(playbackQueue.dropFirst()) }

    func addFolders(_ urls: [URL]) {
        for url in urls where !folders.contains(where: { $0.path == url.path }) {
            let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            folders.append(SourceFolder(url: url, bookmark: bookmark))
        }
        LibraryJSONStore.save(folders, named: "folders")
        scanFolders()
    }

    func removeFolder(_ folder: SourceFolder) {
        folders.removeAll { $0.id == folder.id }
        tracks.removeAll { $0.folderID == folder.id }
        LibraryJSONStore.save(folders, named: "folders")
        migrateStoredCollections()
    }

    func scanFolders() {
        var scanned: [Track] = []
        // 网络下载的音频和 sidecar JSON 位于应用托管目录。它不是用户
        // 手动添加的文件夹，因此每次冷启动都显式纳入扫描范围。
        var sources = folders
        let downloadedURL = MusicDownloadManager.downloadsDirectory
        if !sources.contains(where: { $0.path == downloadedURL.path }) {
            sources.append(SourceFolder(id: "managed-downloads", url: downloadedURL, bookmark: nil))
        }
        for folder in sources {
            let url = folder.resolvedURL()
            _ = url.startAccessingSecurityScopedResource()
            let result = TrackScanner.scan(folder: folder, url: url)
            url.stopAccessingSecurityScopedResource()
            folder.trackCount = result.count
            scanned.append(contentsOf: result)
        }
        tracks = scanned.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        LibraryJSONStore.save(tracks.map(TrackJSONRecord.init), named: "tracks")
        LibraryJSONStore.save(folders, named: "folders")
        migrateStoredCollections()
        restoreQueue()
    }

    func play(_ track: Track, resetQueue: Bool = true) {
        currentTrack = track
        print("Playing track:\(track.title) by \(track.artist)")
        if resetQueue || !playbackQueue.contains(where: { $0.id == track.id }) {
            let source = filteredTracks.isEmpty ? tracks : filteredTracks
            if let index = source.firstIndex(where: { $0.id == track.id }) {
                playbackQueue = Array(source[index...]) + Array(source[..<index])
            } else {
                playbackQueue = [track]
            }
        }
        PlayerManager.shared.loadAndPlay(url: track.playURL)
        PlayerManager.shared.volume = Float(volume)
        isPlaying = true
        recordRecent(track.id)
        saveQueue()
        loadLyrics(for: track)
        startTimer()

         // 立即同步 macOS 正在播放
        loadNowPlayingArtwork(for: track)
    }

    func togglePlayback() {
        guard PlayerManager.shared.hasPlayer else {
            if let currentTrack { play(currentTrack, resetQueue: false) }
            else if tracks.count > 0 { playNext() }
            return
        }
        isPlaying.toggle()
        isPlaying ? PlayerManager.shared.resume() : PlayerManager.shared.pause()

        updateNowPlayingStatus()
    }

    func playNext() {
        print("play next ")
        guard !playbackQueue.isEmpty else { return }
        if repeatMode == .one, let currentTrack {
            play(currentTrack, resetQueue: false)
            return
        }
        let currentIndex = currentTrack.flatMap { current in
            playbackQueue.firstIndex(where: { $0.id == current.id })
        } ?? -1
        if repeatMode == .shuffle {
            let choices = playbackQueue.enumerated().filter { $0.offset != currentIndex }.map(\.element)
            if let next = choices.randomElement() { selectNext(next) }
            return
        }
        let nextIndex = currentIndex + 1
        print("play next currentIndex \(nextIndex)")
        if nextIndex < playbackQueue.count {
            print("play next repeatMode \(repeatMode) next")
            selectNext(playbackQueue[nextIndex])
        } else if repeatMode == .all, let first = playbackQueue.first {
            print("play next repeatMode \(repeatMode) all")
            selectNext(first)
        } else {
            print("play next repeatMode \(repeatMode) else")
            togglePlayback()
        }
    }

    func playPrevious() {
        guard let id = recentIDs.dropFirst().first, let track = tracks.first(where: { $0.id == id }) else { return }
        play(track, resetQueue: false)
    }

    func cycleRepeatMode() {
        repeatMode = RepeatMode(rawValue: (repeatMode.rawValue + 1) % 4) ?? .off
        UserDefaults.standard.set(repeatMode.rawValue, forKey: "repeatMode")
    }

    func toggleTrackSelection(_ track: Track) {
        if selectedTrackIDs.contains(track.id) { selectedTrackIDs.remove(track.id) } else { selectedTrackIDs.insert(track.id) }
    }

    func enqueueSelectedTracks() { enqueue(filteredTracks.filter { selectedTrackIDs.contains($0.id) }); selectedTrackIDs.removeAll(); isSelectingTracks = false }
    func enqueue(_ newTracks: [Track]) {
        for track in newTracks where !playbackQueue.contains(where: { $0.id == track.id }) {
            playbackQueue.append(track)
        }
        saveQueue()
    }

    func addSelectedTracks(to playlistID: String) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistID }) else { return }
        PlaylistHelpers.appendTracks(filteredTracks.map(\.id).filter(selectedTrackIDs.contains), to: &playlists[index], tracks: tracks)
        savePlaylists(); selectedTrackIDs.removeAll(); isSelectingTracks = false
    }

    func removeSelectedPlaylistTracks() {
        guard let id = selectedPlaylistID, let index = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[index].trackIDs.removeAll { selectedPlaylistTrackIDs.contains($0) }
        selectedPlaylistTrackIDs.removeAll(); isSelectingPlaylistTracks = false; savePlaylists()
    }

    func deleteSelectedPlaylist() {
        guard let id = selectedPlaylistID else { return }
        playlists.removeAll { $0.id == id }; selectedPlaylistID = playlists.first?.id; savePlaylists()
    }

    func seek(to value: Double) {
        let ratio = duration > 0 ? value / duration : 0

        PlayerManager.shared.seek(progress: ratio) { [weak self] seconds in
            guard let self else { return }

            self.progress = seconds
        }
        updateNowPlayingStatus()

    }

    func setVolume(_ value: Double) { volume = value; PlayerManager.shared.volume = Float(value) }

    func createPlaylist(named name: String = "新歌单") { let playlist = MusicPlaylist(name: name); playlists.append(playlist); selectedPlaylistID = playlist.id; savePlaylists() }

    func playSelectedPlaylist(shuffled: Bool) {
        let source = selectedPlaylistTracks
        guard let first = shuffled ? source.randomElement() : source.first else { return }
        playbackQueue = source; play(first)
    }

    private func recordRecent(_ id: String) { recentIDs.removeAll { $0 == id }; recentIDs.insert(id, at: 0); recentIDs = Array(recentIDs.prefix(20)); UserDefaults.standard.set(recentIDs, forKey: "recentTracks") }
    private func savePlaylists() { LibraryJSONStore.save(playlists, named: "playlists") }

    func removeFromQueue(_ track: Track) {
        playbackQueue.removeAll { $0.id == track.id }
        if currentTrack?.id == track.id { playNext() }
        saveQueue()
    }

    func clearQueue() {
        playbackQueue = currentTrack.map { [$0] } ?? []
        saveQueue()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(updatePlaybackClock), userInfo: nil, repeats: true)
    }

    @objc private func updatePlaybackClock() {
        progress = PlayerManager.shared.currentTime
        duration = PlayerManager.shared.duration
        isPlaying = PlayerManager.shared.isPlaying
    }

    @objc private func updateNowPlayingInfo() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self else { return }

            guard let track = self.currentTrack else {
                NowPlayingManager.shared.clear()
                return
            }
            print("update info duration:", duration)
            NowPlayingManager.shared.setTrack(
                title: track.title,
                artist: track.artist,
                album: track.album,
                artwork: currentArtwork,
                duration: duration
            )
            updateNowPlayingStatus()
        }
    }

    @objc private func updateNowPlayingStatus() {
        NowPlayingManager.shared.updateStatus(
            elapsed: progress,
            isPlaying: isPlaying
        )
    }

    private func loadLyrics(for track: Track) {
        let text = track.embeddedLyrics ?? track.lyricURL.flatMap { try? String(contentsOf: $0) } ?? ""
        lyrics = LyricParser.parseLRC(text)
        if lyrics.isEmpty && !text.isEmpty { lyrics = [LyricLine(time: 0, text: text)] }
    }

    private func selectNext(_ track: Track) {
        if track.source == .remote { downloadAndPlay(track) }
        else { play(track, resetQueue: false) }
    }

    private var isEditingText: Bool {
        NSApp.keyWindow?.firstResponder is NSTextView
    }

    private func handlePlaybackShortcut(_ event: NSEvent) -> Bool {
        print("keyCode:", event.keyCode, "characters:", event.characters ?? "")
        let modifiers = event.modifierFlags

        guard !modifiers.contains(.command),
            !modifiers.contains(.option),
            !modifiers.contains(.control),
            !modifiers.contains(.shift) else {
            return false
        }
        switch event.keyCode {
        case 49: // Space
            togglePlayback()
        case 123: // Left arrow
            playPrevious()
        case 124: // Right arrow
            playNext()
        case 126: // Up arrow
            setVolume(min(volume + 0.05, 1))
        case 125: // Down arrow
            setVolume(max(volume - 0.05, 0))
        default:
            return false
        }
        return true
    }

    @objc private func playerFinished() {
        if repeatMode == .one, let currentTrack { play(currentTrack, resetQueue: false) }
        else { playNext() }
    }

    private func saveQueue() {
        UserDefaults.standard.set(playbackQueue.map(\.id), forKey: "playbackQueueIDs")
    }

    private func restoreQueue() {
        guard playbackQueue.isEmpty,
              let ids = UserDefaults.standard.stringArray(forKey: "playbackQueueIDs")
        else { return }
        playbackQueue = ids.compactMap { id in tracks.first { $0.id == id } }
    }

    private func migrateStoredCollections() {
        for index in playlists.indices { PlaylistHelpers.migratePlaylist(&playlists[index], tracks: tracks) }
        recentIDs = PlaylistHelpers.deduplicatedTrackIDs(recentIDs, tracks: tracks)
        UserDefaults.standard.set(recentIDs, forKey: "recentTracks")
        savePlaylists()
    }

    private func downloadAndPlay(_ preview: Track) {
        Task {
            print("Start downloading \(preview.title) ")
            var components = URLComponents(string: AppText.listURL)
            components?.queryItems = [URLQueryItem(name: "mid", value: preview.folderID), URLQueryItem(name: "type", value: "json")]
            guard let url = components?.url,
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let song = try? JSONDecoder().decode(NetworkSong.self, from: data),
                  let saved = try? await MusicDownloadManager.saveTrackData(song: song)
            else { return }
            let local = Track(id: Track.stableID(artist: song.singerName, title: song.songName), folderID: "downloaded", url: saved.audio, folderURL: MusicDownloadManager.downloadsDirectory, title: song.songName, artist: song.singerName,album: song.albumName, ext: song.viewExtension, artworkURL: saved.artwork, lyricURL: nil, embeddedArtwork: nil, embeddedLyrics: song.songLyric)
            if !tracks.contains(where: { $0.id == local.id }) { tracks.append(local) }
            print("End downloading \(preview.title) ")
            play(local)
        }
    }

    private func loadNowPlayingArtwork(for track: Track) {
        guard let data = ArtworkLoader.artworkData(for: track),
            let image = NSImage(data: data) else {
            currentArtwork = nil
            updateNowPlayingInfo()
            return
        }

        currentArtwork = image
        updateNowPlayingInfo()
    }
}
