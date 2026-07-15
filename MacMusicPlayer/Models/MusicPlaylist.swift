import Foundation

struct MusicPlaylist: Codable {
    let id: String
    var name: String
    var trackIDs: [String]

    init(id: String = UUID().uuidString, name: String, trackIDs: [String] = []) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
    }
}
