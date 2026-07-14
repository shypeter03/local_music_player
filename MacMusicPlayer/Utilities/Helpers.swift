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
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        return scroll
    }
}

enum TrackScanner {

    static func parseName(_ name: String) -> (artist: String, title: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = cleanName.components(separatedBy: " - ")
        if parts.count >= 2 {
            let artist = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let title = parts.dropFirst()
                .joined(separator: " - ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (artist, title)
        }
        return ("未知艺术家", cleanName)
    }

    static func scan(folder: SourceFolder, url: URL) -> [Track] {
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

        return audioURLs.map { fileURL in
            let parsed = parseName(fileURL.deletingPathExtension().lastPathComponent)
            let base = fileURL.deletingPathExtension().path.lowercased()
            let folderPath = fileURL.deletingLastPathComponent().path.lowercased()
            return Track(
                id: Track.stableID(artist: parsed.artist, title: parsed.title),
                folderID: folder.id,
                url: fileURL,
                folderURL: url,
                title: parsed.title,
                artist: parsed.artist,
                ext: fileURL.pathExtension,
                artworkURL: imageByBase[base] ?? coverByFolder[folderPath],
                lyricURL: lyricByBase[base],
                embeddedArtwork: ArtworkLoader.loadEmbedded(from: fileURL)
            )
        }
    }
}

enum ArtworkLoader {

    static func loadEmbedded(from url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        for item in asset.commonMetadata where item.commonKey == .commonKeyArtwork {
            if let data = item.value as? Data {
                return NSImage(data: data)
            }
            if let data = item.dataValue {
                return NSImage(data: data)
            }
        }
        return nil
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
