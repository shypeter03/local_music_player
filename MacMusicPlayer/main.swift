import SwiftUI

@main
struct LocalMusicPlayerApp: App {
    // SwiftUI owns the macOS application lifecycle.  The delegate remains the
    // bridge for the existing AVFoundation player and window while the UI is
    // progressively moved into SwiftUI views.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
