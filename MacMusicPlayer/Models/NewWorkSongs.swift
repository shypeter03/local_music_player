import Foundation

struct NetworkSong: Codable {
    // 属性名必须和下面的 CodingKeys 里的一一对应
    let songName: String
    let singerName: String
    let songMid: String
    
    // 下面这些属性如果不确定 JSON 里有没有，全部设为可选类型
    let albumName: String?
    let albumPic: String?
    let songPlayTime: Int?
    let songPlayUrl: String
    let songPlayUrlSq: String?
    let songLyric: String?
    let vip: String?
    let pay: String? // JSON 里有 pay 字段，别忘了加
    let fileName: String?


    // 🌟 必须写在 struct 内部，且名称严格匹配上面的属性名
    enum CodingKeys: String, CodingKey {
        case songName = "song_title"
        case singerName = "singer_name"
        case songMid = "song_mid"
        case albumName = "album_name"     // 如果 JSON 里有这些字段，确保写对
        case albumPic = "album_pic"
        case songPlayTime = "song_play_time"
        case songPlayUrl = "song_play_url"
        case songLyric = "song_lyric"
        case vip = "vip"
        case pay = "pay"
        case fileName = "song_filename_lq"
        case songPlayUrlSq = "song_play_url_sq"
    }
    var songURL: String {
        return self.songPlayUrlSq ?? self.songPlayUrl
    }

    var isFLAC: Bool {
        guard let url = songPlayUrlSq else {
            return false
        }
        return !url.isEmpty
    }

    var fileExtension: String {
        isFLAC ? "flac" : "m4a"
    }
    var viewExtension: String {
        isFLAC ? "FLAC" : "M4A"
    }

}
struct NetworkSongListItem: Codable {
    let songTitle: String
    let pay: String
    let songMid: String
    let singerName: String

    enum CodingKeys: String, CodingKey {
        case songTitle = "song_title"
        case pay = "pay"
        case songMid = "song_mid"
        case singerName = "singer_name"
    }
}
