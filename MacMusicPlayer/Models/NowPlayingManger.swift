import Foundation
import AppKit
import MediaPlayer

final class NowPlayingManager {

    static let shared = NowPlayingManager()

    private init() {
        setupRemoteCommands()
    }

    // MARK: - Commands

    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onNext: (() -> Void)?
    var onPrevious: (() -> Void)?
    var onSeek: ((TimeInterval) -> Void)?

    private func setupRemoteCommands() {

        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true

        center.playCommand.addTarget { [weak self] _ in
            self?.onPlay?()
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            self?.onPause?()
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNext?()
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.onPrevious?()
            return .success
        }

        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }

            self?.onSeek?(event.positionTime)
            return .success
        }
    }

    // MARK: - Now Playing

    func setTrack(
        title: String,
        artist: String?,
        album: String?,
        artwork: NSImage?,
        duration: TimeInterval
    ) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: duration
        ]

        if let artist {
            info[MPMediaItemPropertyArtist] = artist
        }

        if let album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }

        if let artwork {
            info[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                    artwork
                }
        }

        let center = MPNowPlayingInfoCenter.default()

        center.nowPlayingInfo = info
        print("🎵 NOW PLAYING TRACK")
        print("title:", title)
        print("artist:", artist ?? "nil")
        print("duration:", duration)
    }

    func updateStatus(
        elapsed: TimeInterval,
        isPlaying: Bool
    ) {
        let center = MPNowPlayingInfoCenter.default()

        var info = center.nowPlayingInfo ?? [:]

        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        info[MPNowPlayingInfoPropertyPlaybackRate] =
            isPlaying ? 1.0 : 0.0

        center.nowPlayingInfo = info
        center.playbackState = isPlaying ? .playing : .paused

        print("🎵 NOW PLAYING STATUS")
        print("elapsed:", elapsed)
        print("isPlaying:", isPlaying)
    }


    func clear() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
