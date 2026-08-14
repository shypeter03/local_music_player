import Foundation

/// JSON is the durable source of truth for the imported library.  Keeping it
/// in Application Support avoids writing application state into the user's
/// music folders (song sidecars are written separately by `TrackScanner`).
enum LibraryJSONStore {
    private static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LocalMusicPlayer", isDirectory: true)
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static func file(_ name: String) -> URL {
        directory.appendingPathComponent(name).appendingPathExtension("json")
    }

    static func load<T: Decodable>(_ type: T.Type, named name: String) -> T? {
        guard let data = try? Data(contentsOf: file(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, named name: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try encoder.encode(value).write(to: file(name), options: .atomic)
        } catch {
            NSLog("Could not save \(name).json: \(error.localizedDescription)")
        }
    }
}

/// A portable snapshot of a scanned song. It intentionally contains paths and
/// metadata only; images are reloaded from disk when the app starts.
struct TrackJSONRecord: Codable {
    let id: String
    let folderID: String
    let path: String
    let folderPath: String
    let title: String
    let artist: String
    let ext: String
    let artworkPath: String?
    let lyricPath: String?

    init(_ track: Track) {
        id = track.id
        folderID = track.folderID
        path = track.url.path
        folderPath = track.folderURL.path
        title = track.title
        artist = track.artist
        ext = track.ext
        artworkPath = track.artworkURL?.path
        lyricPath = track.lyricURL?.path
    }
}
