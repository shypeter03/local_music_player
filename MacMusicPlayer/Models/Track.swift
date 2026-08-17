import CryptoKit
import Foundation


enum TrackSource {
    case local
    case remote
}

struct Track {
    let id: String
    let folderID: String
    let url: URL
    let folderURL: URL
    let title: String
    let artist: String
    let album: String?
    let ext: String
    let artworkURL: URL?
    let lyricURL: URL?
    let embeddedArtwork: Data?
    let embeddedLyrics: String?

    var source: TrackSource = .local
        /// 网络歌曲第一次没有
    var remoteURL: URL?
    // var duration: TimeInterval

    var dedupeKey: String {
        Self.dedupeKey(artist: artist, title: title)
    }

    static func dedupeKey(artist: String, title: String) -> String {
        "\(normalize(artist))|\(normalize(title))"
    }

    static func threedupeKey(artist: String, title: String,album: String) -> String {
        "\(normalize(artist))|\(normalize(title))|\(normalize(album))"
    }

    static func stableID(artist: String, title: String) -> String {
        let key = dedupeKey(artist: artist, title: title)
        let digest = SHA256.hash(data: Data(key.utf8))
        return "t:" + digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    static func stableIDWithAlbum(artist: String, title: String,album: String) -> String {
        let key = threedupeKey(artist: artist, title: title,album: album)
        let digest = SHA256.hash(data: Data(key.utf8))
        return "t:" + digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
    var playURL: URL {
        // if self.source == .local {
            return self.url // 存在本地，返回本地 URL
        // }
        // return self.remoteURL // 不存在，返回远程 URL
    }
}
