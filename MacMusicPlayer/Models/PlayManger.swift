import Foundation
import AVFoundation

class PlayerManager: NSObject {
    static let shared = PlayerManager()
    
    // 使用 AVPlayer，支持本地和远程
    var player: AVPlayer?

    var isPlaying: Bool {
        player?.timeControlStatus != .paused
    }

    var currentTime: Double {
        guard let player else { return 0 }
        let time = player.currentTime().seconds
        return time.isFinite ? time : 0
    }

    var duration: Double {
        guard let player else { return 0 }
        let duration = player.currentItem?.duration.seconds ?? 0
        return duration.isFinite ? duration : 0
    }

    var hasPlayer: Bool {
        player != nil
    }

    var volume: Float {
        get { player?.volume ?? Float(UserDefaults.standard.double(forKey: "playbackVolume")) }
        set {
            player?.volume = newValue
            UserDefaults.standard.set(Double(newValue), forKey: "playbackVolume")
        }
    }
    func pause() {
        player?.pause()
    }

    func resume() {
        player?.play()
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
    }

    /// 只加载，不播放
    func load(url: URL) {
        let item = AVPlayerItem(url: url)
        // 移除旧监听
        NotificationCenter.default.removeObserver(
            self,
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )

        // 注册新监听
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidPlayToEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        if player == nil {
            player = AVPlayer(playerItem: item)
        } else {
            player?.replaceCurrentItem(with: item)
        }
        let saved = UserDefaults.standard.object(forKey: "playbackVolume") as? Double ?? 1
        player?.volume = Float(saved)
    }

    /// 开始播放当前已加载的内容
    func play() {
        player?.play()
    }   

    func loadAndPlay(url: URL) {
        load(url: url)
        play()
    }

    func seek(progress: Double) {
        guard let player,
            let item = player.currentItem else {
            return
        }

        let duration = item.duration.seconds
        guard duration.isFinite, duration > 0 else {
            return
        }

        let seconds = progress * duration

        player.seek(to: CMTime(seconds: seconds,preferredTimescale: 600))
    }   


    @objc private func itemDidPlayToEnd(_ notification: Notification) {
        print("🎵 播放结束")

        NotificationCenter.default.post(
            name: .playerDidFinishPlaying,
            object: nil
        )
    }

   deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
