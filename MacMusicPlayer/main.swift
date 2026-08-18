import SwiftUI
import AppKit


final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                window.delegate = self
            }
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
        return true
    }

}

@main
struct LocalMusicPlayerApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            MusicRootView()
        }
        .windowStyle(.hiddenTitleBar)
    }
}
