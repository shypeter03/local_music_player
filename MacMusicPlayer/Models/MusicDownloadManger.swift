import Foundation

class MusicDownloadManager {
    
    // 统一的下载存储目录：Library/Application Support/音乐/Downloads/
    static var downloadsDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let downloadsURL = paths[0]
            .appendingPathComponent("音乐", isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
        
        // 确保 Downloads 文件夹存在
        try? FileManager.default.createDirectory(at: downloadsURL, withIntermediateDirectories: true)
        return downloadsURL
    }
    
    /// 下载歌曲并返回本地的 file:// URL
    static func downloadSong(
        from urlString: String,
        filename: String,
        completion: @escaping (URL?) -> Void
    ) {

        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        let destinationURL =
            downloadsDirectory.appendingPathComponent(filename)
        print("目标路径:", destinationURL.path)

        if FileManager.default.fileExists(
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

                try FileManager.default.moveItem(
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
}
