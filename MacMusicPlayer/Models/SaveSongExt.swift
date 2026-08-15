import Foundation
import CryptoKit
import Foundation

struct SaveSongExt : Codable{
    let id: String
    let title: String
    let artist: String
    let albumName: String?
    let songQrc: String?
    let artworkPath: URL? // 封面
    let songFilePath : URL? //文件
    let originMid: String? // 原始id
}
