import AppKit

extension AppDelegate {

    private enum AppearancePreference: String {
        case system
        case light
        case dark
    }

    // 定义一个唯一的 tag 标识，避免用中文字符串去 find 菜单
    private var settingsMenuTag: Int { return 999 }

    func configureAppearance() {
        let rawValue = UserDefaults.standard.string(forKey: "appearancePreference")
        applyAppearance(AppearancePreference(rawValue: rawValue ?? "") ?? .system)
    }

    func buildApplicationMenu() {
        let mainMenu = NSMenu()
        
        // 1. App 核心菜单 (退出、关于等)
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu(title: AppText.appName)
        appMenu.addItem(withTitle: AppText.exitApp, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        // 2. 显示设置菜单
        let settingsItem = NSMenuItem(title: AppText.menuAppearanceSettings, action: nil, keyEquivalent: "")
        // 【关键改动】：给这个菜单项设定一个 tag，后续更新时用 tag 去找，100% 成功
        settingsItem.tag = settingsMenuTag
        
        let settingsMenu = NSMenu(title: AppText.menuAppearanceSettings)
        settingsMenu.addItem(NSMenuItem(title: AppText.menuAppearanceSystem, action: #selector(useSystemAppearance), keyEquivalent: ""))
        settingsMenu.addItem(NSMenuItem(title: AppText.menuAppearanceLight, action: #selector(useLightAppearance), keyEquivalent: ""))
        settingsMenu.addItem(NSMenuItem(title: AppText.menuAppearanceDark, action: #selector(useDarkAppearance), keyEquivalent: ""))
        
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
        window.appearance = NSApp.appearance
        UserDefaults.standard.set(preference.rawValue, forKey: "appearancePreference")
        DispatchQueue.main.async {
            self.applyTheme()
            self.updateAppearanceMenuState()
        }
        // applyTheme()
    }

    private func updateAppearanceMenuState() {
        let preference = AppearancePreference(rawValue: UserDefaults.standard.string(forKey: "appearancePreference") ?? "") ?? .system
        
        // 【核心修改】：通过我们设定的 tag 找到菜单，彻底避免中文字符串匹配不到的问题
        guard let menu = NSApp.mainMenu?.item(withTag: settingsMenuTag)?.submenu else { return }
        
        // 清除所有选中状态
        menu.items.forEach { $0.state = .off }
        
        // 匹配当前的 preference，并设置对应的勾选状态
        switch preference {
        case .system:
            if let item = menu.items.first(where: { $0.action == #selector(useSystemAppearance) }) {
                item.state = .on
            }
        case .light:
            if let item = menu.items.first(where: { $0.action == #selector(useLightAppearance) }) {
                item.state = .on
            }
        case .dark:
            if let item = menu.items.first(where: { $0.action == #selector(useDarkAppearance) }) {
                item.state = .on
            }
        }
    }
}
