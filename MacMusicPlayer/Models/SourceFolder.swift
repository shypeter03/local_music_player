import Foundation

final class SourceFolder: Codable {
    let id: String
    let name: String
    let bookmark: Data?
    let path: String
    var trackCount: Int

    init(id: String = UUID().uuidString, url: URL, bookmark: Data?, trackCount: Int = 0) {
        self.id = id
        self.name = url.lastPathComponent
        self.bookmark = bookmark
        self.path = url.path
        self.trackCount = trackCount
    }

    func resolvedURL() -> URL {
        if let bookmark {
            var stale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) {
                return url
            }
        }
        return URL(fileURLWithPath: path)
    }
}
