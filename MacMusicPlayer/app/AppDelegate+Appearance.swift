import AppKit

extension AppDelegate {

    private enum AppearancePreference: String {
        case system
        case light
        case dark
    }

    func configureAppearance() {
        let rawValue = UserDefaults.standard.string(forKey: "appearancePreference")
        applyAppearance(AppearancePreference(rawValue: rawValue ?? "") ?? .system)
    }

    func buildApplicationMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: "本地音乐器")
        appMenu.addItem(withTitle: "退出本地音乐器", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let settingsItem = NSMenuItem(title: "显示设置", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu(title: "显示设置")
        settingsMenu.addItem(NSMenuItem(title: "跟随系统", action: #selector(useSystemAppearance), keyEquivalent: ""))
        settingsMenu.addItem(NSMenuItem(title: "浅色", action: #selector(useLightAppearance), keyEquivalent: ""))
        settingsMenu.addItem(NSMenuItem(title: "深色", action: #selector(useDarkAppearance), keyEquivalent: ""))
        settingsMenu.items.forEach { $0.target = self }
        settingsItem.submenu = settingsMenu
        mainMenu.addItem(settingsItem)
        NSApp.mainMenu = mainMenu
        updateAppearanceMenuState()
    }

    @objc func useSystemAppearance() { applyAppearance(.system) }
    @objc func useLightAppearance() { applyAppearance(.light) }
    @objc func useDarkAppearance() { applyAppearance(.dark) }

    private func applyAppearance(_ preference: AppearancePreference) {
        switch preference {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        UserDefaults.standard.set(preference.rawValue, forKey: "appearancePreference")
        updateAppearanceMenuState()
        applyTheme()
    }

    private func updateAppearanceMenuState() {
        let preference = AppearancePreference(rawValue: UserDefaults.standard.string(forKey: "appearancePreference") ?? "") ?? .system
        guard let menu = NSApp.mainMenu?.items.first(where: { $0.title == "显示设置" })?.submenu else { return }
        menu.items.forEach { $0.state = .off }
        let title: String
        switch preference {
        case .system: title = "跟随系统"
        case .light: title = "浅色"
        case .dark: title = "深色"
        }
        menu.item(withTitle: title)?.state = .on
    }
}
