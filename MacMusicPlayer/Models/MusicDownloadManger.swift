import Foundation

class MusicDownloadManager {


    static let fileManager = FileManager.default
    
    // 统一的下载存储目录：Library/Application Support/音乐/Downloads/
    static var downloadsDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let downloadsURL = paths[0]
            .appendingPathComponent("音乐", isDirectory: true)
            .appendingPathComponent("已下载", isDirectory: true)
        
        // 确保 Downloads 文件夹存在
        try? fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
        return downloadsURL
    }
    static var rootDirectory: URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let downloadsURL = paths[0]
            .appendingPathComponent("音乐", isDirectory: true)
        
        // 确保 Downloads 文件夹存在
        try? fileManager.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
        return downloadsURL
    }
    
    /// 下载歌曲并返回本地的 file:// URL
    static func downloadSong(
        from urlString: String,
        filename: String,
        songDetail: NetworkSong? = nil,
        completion: @escaping (URL?) -> Void
    ) {

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let destinationURL =
            downloadsDirectory.appendingPathComponent(filename)
        print("目标路径:", destinationURL.path)

        if fileManager.fileExists(
            atPath: destinationURL.path
        ) {
            completion(destinationURL)
            return
        }


        var request = URLRequest(url: url)

        request.setValue(
            "Mozilla/5.0",
            forHTTPHeaderField: "User-Agent"
        )


        URLSession.shared.downloadTask(
            with: request
        ) { tempURL, response, error in


            guard let tempURL,
                error == nil
            else {
                print(error ?? "")
                completion(nil)
                return
            }


            do {

                try fileManager.moveItem(
                    at: tempURL,
                    to: destinationURL
                )

                completion(destinationURL)

            } catch {

                print(error)
                completion(nil)
            }

        }.resume()
    }
    static func saveTrackData(song: NetworkSong) async throws -> (artwork: URL, audio: URL) {
        // 先判断文件是否存在，存在就不下载了
        let newID = Track.stableID(artist: song.singerName, title: song.songName)
        let artID = Track.stableIDWithAlbum(artist: song.singerName, title: song.songName,album: song.albumName ?? "")
        let artworkDir = rootDirectory.appendingPathComponent("artworks")
        let artworkURL = artworkDir.appendingPathComponent("\(artID).jpg")
        let songURL = downloadsDirectory.appendingPathComponent("\(newID).\(song.fileExtension)")
        if FileManager.default.fileExists(atPath: artworkURL.path) && 
            FileManager.default.fileExists(atPath: songURL.path) {
            print("资源已存在，无需下载: \(newID) name = \(song.songName)")
            return (artwork: artworkURL, audio: songURL)
        }
        // 1. 保存封面图
        let artworkData = try? await download(url: song.albumPic )
        try fileManager.createDirectory(at: artworkDir, withIntermediateDirectories: true)
        try artworkData?.write(to: artworkURL)
        // 2.保存音源文件
        let songData = try? await download(url: song.songURL )
        try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        try songData?.write(to: songURL)

        // 2. 构造 Track 对象
        let sse = SaveSongExt(
             id: newID,
             title: song.songName,
             artist: song.singerName,
             albumName: song.albumName ?? "",
             songQrc: song.songLyric ?? "",
             artworkPath: artworkURL ,// 封面
             songFilePath : songURL, //文件
             originMid: song.songMid
        )

        // 3. 将 Track 保存为 JSON
        let jsonDir = downloadsDirectory.appendingPathComponent("songDetail")
        try fileManager.createDirectory(at: jsonDir, withIntermediateDirectories: true)
        let jsonURL = jsonDir.appendingPathComponent("\(newID).json")
        let data = try JSONEncoder().encode(sse)
        try data.write(to: jsonURL)
        return (artwork: artworkURL, audio: songURL)
    }
        // 假设你有一个下载封面图的函数
    static func download(url: URL?) async throws -> Data? {
        guard let url = url else {
            print("URL 为空，跳过下载")
            return nil
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return data // 这里返回的就是 artworkData
    }
}
