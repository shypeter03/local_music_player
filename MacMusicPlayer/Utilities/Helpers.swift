import AppKit
import AVFoundation
import Foundation

enum UIHelpers {

    static func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let total = max(0, Int(seconds))
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    static func symbolImage(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)?
            .tinting(with: color)
    }

    static func placeholderArtwork(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let gradient = NSGradient(colors: [Theme.accent, Theme.accent.withAlphaComponent(0.65)])!
        gradient.draw(in: rect, angle: 135)
        let symbol = symbolImage("music.note", pointSize: size * 0.33, color: .white)
        symbol?.draw(in: NSRect(x: size * 0.34, y: size * 0.34, width: size * 0.32, height: size * 0.32))
        image.unlockFocus()
        return image
    }

    /// Inset the source image so the Dock presentation has the same visual
    /// scale as a standard macOS app icon.
    static func dockIcon(from icon: NSImage, scale: CGFloat = 0.80) -> NSImage {
        let image = NSImage(size: icon.size)
        image.lockFocus()
        let width = icon.size.width * scale
        let height = icon.size.height * scale
        icon.draw(in: NSRect(x: (icon.size.width - width) / 2, y: (icon.size.height - height) / 2, width: width, height: height))
        image.unlockFocus()
        return image
    }

    static func roundedImageView(size: CGFloat) -> NSImageView {
        let imageView = NSImageView()
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 8
        imageView.layer?.masksToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: size).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: size).isActive = true
        return imageView
    }

    static func emptyLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.textColor = Theme.secondaryText
        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.heightAnchor.constraint(equalToConstant: 46).isActive = true
        return label
    }

    static func clear(_ stack: NSStackView) {
        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    static func scrollView(containing stack: NSStackView) -> NSScrollView {
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: document.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: document.widthAnchor)
        ])

        let scroll = NSScrollView()
        scroll.documentView = document
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let clipView = scroll.contentView
        document.widthAnchor.constraint(equalTo: clipView.widthAnchor).isActive = true
        scroll.contentView.postsBoundsChangedNotifications = true
        return scroll
    }
    static func lyricScrollView(containing stack: NSStackView) -> NSScrollView {
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false

        document.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24),

            // 关键：左右留边，但整个 Stack 仍然铺满宽度
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24)
        ])

        let scroll = NSScrollView()
        scroll.documentView = document

        scroll.drawsBackground = false

        // 不一直显示滚动条
        scroll.hasVerticalScroller = false
        scroll.autohidesScrollers = true

        scroll.automaticallyAdjustsContentInsets = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true

        return scroll
    }
}

enum TrackScanner {

    // static func parseFileName(_ name: String) -> (artist: String, title: String) {
    //     let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    //     let parts = cleanName.components(separatedBy: " - ")
    //     if parts.count >= 2 {
    //         let artist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
    //         let title = parts.dropFirst()
    //             .joined(separator: " - ")
    //             .trimmingCharacters(in: .whitespacesAndNewlines)
    //         return (artist, title)
    //     }
    //     return ("未知艺术家", cleanName)
    // }

    static func scan(folder: SourceFolder, url: URL) -> [Track] {
        // 1. 确保目录存在
        let detailDir = url.appendingPathComponent("songDetail", isDirectory: true)
        var songDetailCache: [String: SaveSongExt] = [:]

        // 2. 检查目录是否存在且是文件夹
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: detailDir.path, isDirectory: &isDir), isDir.boolValue {
            if let files = try? FileManager.default.contentsOfDirectory(at: detailDir, includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "json" {
                    if let data = try? Data(contentsOf: file),
                    let sse = try? JSONDecoder().decode(SaveSongExt.self, from: data) {
                        // 建议：确保 JSON 中保存的 id 确实是基于同样的算法生成的
                        songDetailCache[sse.id] = sse
                    }
                }
            }
        } else {
            // 可选：如果 scan 时发现没有 songDetail 文件夹，可以根据需求决定是否创建一个
            // try? FileManager.default.createDirectory(at: detailDir, withIntermediateDirectories: true)
        }

        let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var audioURLs: [URL] = []
        var lyricByBase: [String: URL] = [:]
        var imageByBase: [String: URL] = [:]
        var coverByFolder: [String: URL] = [:]

        for case let item as URL in enumerator {
            let ext = item.pathExtension.lowercased()
            if audioExtensions.contains(ext) {
                audioURLs.append(item)
            } else if ext == "lrc" {
                lyricByBase[item.deletingPathExtension().path.lowercased()] = item
            } else if imageExtensions.contains(ext) {
                imageByBase[item.deletingPathExtension().path.lowercased()] = item
                let name = item.deletingPathExtension().lastPathComponent.lowercased()
                if ["cover", "folder", "album"].contains(name) {
                    coverByFolder[item.deletingLastPathComponent().path.lowercased()] = item
                }
            }
        }

        let tracks = audioURLs.map { fileURL in
            let flacMetadata = fileURL.pathExtension.lowercased() == "flac" ? FLACMetadataReader.read(from: fileURL) : nil
            let title = flacMetadata?.title?.nonEmpty ?? fileURL.deletingPathExtension().lastPathComponent
            let artist = flacMetadata?.artist?.nonEmpty ?? "未知艺术家"
            let provisionalID = Track.stableID(artist: artist, title: title)
            let cachedDetail = songDetailCache[provisionalID]
                ?? songDetailCache[fileURL.deletingPathExtension().lastPathComponent]

            let base = fileURL.deletingPathExtension().path.lowercased()
            let folderPath = fileURL.deletingLastPathComponent().path.lowercased()
            let finalTitle = cachedDetail?.title ?? title
            let finalArtist = cachedDetail?.artist ?? artist
            let currentStableID = Track.stableID(artist: finalArtist, title: finalTitle)

            return Track(
                id: currentStableID,
                folderID: folder.id,
                url: fileURL,
                folderURL: url,
                title: finalTitle,
                artist: finalArtist,
                ext: fileURL.pathExtension,
                artworkURL: cachedDetail?.artworkPath ?? imageByBase[base] ?? coverByFolder[folderPath],
                lyricURL: lyricByBase[base],
                embeddedArtwork: flacMetadata?.artwork ?? ArtworkLoader.loadEmbedded(from: fileURL),
                embeddedLyrics: cachedDetail?.songQrc ?? flacMetadata?.lyrics
            )
        }
        saveSongSidecars(tracks, in: detailDir)
        return tracks
    }

    private static func saveSongSidecars(_ tracks: [Track], in directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            for track in tracks {
                let file = directory.appendingPathComponent(track.id).appendingPathExtension("json")
                guard !FileManager.default.fileExists(atPath: file.path) else { continue }
                let detail = SaveSongExt(id: track.id, title: track.title, artist: track.artist, albumName: nil, songQrc: track.embeddedLyrics, artworkPath: track.artworkURL, songFilePath: track.url, originMid: nil)
                try encoder.encode(detail).write(to: file, options: .atomic)
            }
        } catch {
            NSLog("Could not write song JSON sidecars: \(error.localizedDescription)")
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// 读取 FLAC 原生元数据块：Vorbis Comment 中的演唱者/歌词，以及 Picture 中的封面。
enum FLACMetadataReader {
    struct Metadata {
        var title: String?
        var artist: String?
        var lyrics: String?
        var artwork: NSImage?
    }

    static func read(from url: URL) -> Metadata? {
        guard let data = try? Data(contentsOf: url), data.count >= 4,
              String(data: data.prefix(4), encoding: .ascii) == "fLaC"
        else { return nil }

        var metadata = Metadata()
        var offset = 4
        var isLast = false
        while !isLast, offset + 4 <= data.count {
            let header = data[offset]
            isLast = (header & 0x80) != 0
            let type = header & 0x7F
            let length = Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
            offset += 4
            guard length >= 0, offset + length <= data.count else { break }
            let block = data.subdata(in: offset..<(offset + length))
            switch type {
            case 4:
                let comments = parseVorbisComments(block)
                metadata.title = comments["TITLE"]?.nonEmpty
                metadata.artist = (comments["ARTIST"] ?? comments["ALBUMARTIST"] ?? comments["PERFORMER"])?.nonEmpty
                metadata.lyrics = lyricValue(from: comments)
                if metadata.artwork == nil, let encodedPicture = comments["METADATA_BLOCK_PICTURE"],
                   let pictureData = Data(base64Encoded: encodedPicture) {
                    metadata.artwork = parsePicture(pictureData)
                }
            case 6:
                metadata.artwork = metadata.artwork ?? parsePicture(block)
            default:
                break
            }
            offset += length
        }
        return metadata
    }

    private static func parseVorbisComments(_ data: Data) -> [String: String] {
        var offset = 0
        guard let vendorLength = littleEndianUInt32(data, offset: &offset),
              vendorLength >= 0, offset + vendorLength <= data.count
        else { return [:] }
        offset += vendorLength
        guard let count = littleEndianUInt32(data, offset: &offset) else { return [:] }
        var result: [String: String] = [:]
        for _ in 0..<count {
            guard let length = littleEndianUInt32(data, offset: &offset), offset + length <= data.count else { break }
            let item = String(data: data.subdata(in: offset..<(offset + length)), encoding: .utf8)
            offset += length
            guard let item, let separator = item.firstIndex(of: "=") else { continue }
            let key = String(item[..<separator]).uppercased()
            let value = String(item[item.index(after: separator)...])
            if result[key] == nil { result[key] = value }
        }
        return result
    }

    private static func lyricValue(from comments: [String: String]) -> String? {
        ["LYRICS", "UNSYNCEDLYRICS", "UNSYNCED LYRICS", "SYNCEDLYRICS", "LYRIC", "COMMENT"]
            .compactMap { comments[$0]?.nonEmpty }
            .first
    }

    private static func parsePicture(_ data: Data) -> NSImage? {
        var offset = 0
        guard bigEndianUInt32(data, offset: &offset) != nil,
              let mimeLength = bigEndianUInt32(data, offset: &offset), offset + mimeLength <= data.count
        else { return nil }
        offset += mimeLength
        guard let descriptionLength = bigEndianUInt32(data, offset: &offset), offset + descriptionLength <= data.count else { return nil }
        offset += descriptionLength
        for _ in 0..<4 {
            guard bigEndianUInt32(data, offset: &offset) != nil else { return nil }
        }
        guard let imageLength = bigEndianUInt32(data, offset: &offset), offset + imageLength <= data.count else { return nil }
        return NSImage(data: data.subdata(in: offset..<(offset + imageLength)))
    }

    private static func littleEndianUInt32(_ data: Data, offset: inout Int) -> Int? {
        guard offset + 4 <= data.count else { return nil }
        let value = Int(data[offset]) | Int(data[offset + 1]) << 8 | Int(data[offset + 2]) << 16 | Int(data[offset + 3]) << 24
        offset += 4
        return value
    }

    private static func bigEndianUInt32(_ data: Data, offset: inout Int) -> Int? {
        guard offset + 4 <= data.count else { return nil }
        let value = Int(data[offset]) << 24 | Int(data[offset + 1]) << 16 | Int(data[offset + 2]) << 8 | Int(data[offset + 3])
        offset += 4
        return value
    }
}

enum ArtworkLoader {

    private final class ArtworkResult: @unchecked Sendable {
        var image: NSImage?
    }

    static func loadEmbedded(from url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let semaphore = DispatchSemaphore(value: 0)
        let result = ArtworkResult()
        Task {
            defer { semaphore.signal() }
            guard let metadata = try? await asset.load(.commonMetadata) else { return }
            for item in metadata where item.commonKey == .commonKeyArtwork {
                if let data = try? await item.load(.dataValue), let image = NSImage(data: data) {
                    result.image = image
                    return
                }
            }
        }
        semaphore.wait()
        return result.image
    }

    static func artwork(for track: Track) -> NSImage {
        if let image = track.embeddedArtwork {
            return image
        }
        if let artworkURL = track.artworkURL, let image = NSImage(contentsOf: artworkURL) {
            return image
        }
        return UIHelpers.placeholderArtwork(size: 360)
    }
}

enum LyricParser {

    static func parseLRC(_ text: String) -> [LyricLine] {
        text.components(separatedBy: .newlines).flatMap { line -> [LyricLine] in
            let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            let matches = regex.matches(in: line, range: range)
            let content = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { return [] }
            return matches.compactMap { match in
                guard
                    let mRange = Range(match.range(at: 1), in: line),
                    let sRange = Range(match.range(at: 2), in: line)
                else { return nil }
                let minutes = Double(line[mRange]) ?? 0
                let seconds = Double(line[sRange]) ?? 0
                var fraction = 0.0
                if match.range(at: 3).location != NSNotFound, let fRange = Range(match.range(at: 3), in: line) {
                    fraction = Double("0.\(line[fRange])") ?? 0
                }
                return LyricLine(time: minutes * 60 + seconds + fraction, text: content)
            }
        }.sorted { $0.time < $1.time }
    }
}

enum PlaylistHelpers {

    static func deduplicatedTrackIDs(_ ids: [String], tracks: [Track]) -> [String] {
        var seenKeys = Set<String>()
        var result: [String] = []
        for id in ids {
            guard let track = tracks.first(where: { $0.id == id }) else { continue }
            guard !seenKeys.contains(track.dedupeKey) else { continue }
            seenKeys.insert(track.dedupeKey)
            result.append(id)
        }
        return result
    }

    static func remappedTrackID(_ storedID: String, tracks: [Track]) -> String? {
        if tracks.contains(where: { $0.id == storedID }) {
            return storedID
        }
        if let colonIndex = storedID.firstIndex(of: ":") {
            let path = String(storedID[storedID.index(after: colonIndex)...])
            if let track = tracks.first(where: { $0.url.path == path }) {
                return track.id
            }
        }
        return nil
    }

    static func migratePlaylist(_ playlist: inout MusicPlaylist, tracks: [Track]) {
        var migrated: [String] = []
        for storedID in playlist.trackIDs {
            guard let resolved = remappedTrackID(storedID, tracks: tracks) else { continue }
            migrated.append(resolved)
        }
        playlist.trackIDs = deduplicatedTrackIDs(migrated, tracks: tracks)
    }

    static func appendTracks(
        _ trackIDs: [String],
        to playlist: inout MusicPlaylist,
        tracks: [Track]
    ) {
        var existingKeys = Set(
            playlist.trackIDs.compactMap { id in
                tracks.first(where: { $0.id == id })?.dedupeKey
            }
        )
        for id in trackIDs {
            guard let track = tracks.first(where: { $0.id == id }) else { continue }
            guard !existingKeys.contains(track.dedupeKey) else { continue }
            existingKeys.insert(track.dedupeKey)
            playlist.trackIDs.append(id)
        }
    }
}
enum TimeHelper {

    private static let logFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            return formatter
    }()

    static func now() -> String {
        logFormatter.string(from: Date())
    }
}
