import AppKit

@main
enum LocalMusicPlayerApp {
    private static var appDelegate: AppDelegate?

    static func main() {
        let app = NSApplication.shared
        appDelegate = AppDelegate()
        app.delegate = appDelegate
        app.run()
    }
}
