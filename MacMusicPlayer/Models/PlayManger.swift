import Foundation
import AVFoundation

class PlayerManager: NSObject {
    static let shared = PlayerManager()
    
    // 使用 AVPlayer，支持本地和远程
    var player: AVPlayer?
    
    /// 播放音频（支持本地 fileURL 和 远程 httpURL）
    func play(urlString: String) {
        guard let url = URL(string: urlString) else { return }
        
        // AVPlayer 可以自动识别 URL 类型
        // 如果是本地路径，它会直接读取磁盘
        // 如果是 http 地址，它会自动开启流媒体加载
        let playerItem = AVPlayerItem(url: url)
        
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }
        
        player?.play()
    }
    
    func pause() {
        player?.pause()
    }
}
