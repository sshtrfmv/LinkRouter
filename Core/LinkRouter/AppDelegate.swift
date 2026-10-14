import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = AppEnvironment.shared.store

        // Значок ⏸ на иконке в Dock, пока правила на паузе
        // (работает при переключении из Dock, строки меню или окна).
        store.$config
            .map(\.rulesPaused)
            .removeDuplicates()
            .sink { paused in NSApp.dockTile.badgeLabel = paused ? "⏸" : nil }
            .store(in: &cancellables)

        // Показывать ли приложение в Dock.
        store.$config
            .map(\.settings.showInDock)
            .removeDuplicates()
            .sink { show in NSApp.setActivationPolicy(show ? .regular : .accessory) }
            .store(in: &cancellables)
    }

    /// Закрытие окна не завершает приложение: оно продолжает работать в фоне.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            Task { await AppEnvironment.shared.router.handle(url) }
        }
    }

    // MARK: - Меню в Dock

    /// Меню собирается заново при каждом правом щелчке, поэтому всегда актуально.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let env = AppEnvironment.shared
        env.discovery.refresh()
        let config = env.store.config
        let menu = NSMenu()

        // Открыть окно
        menu.addItem(item("Открыть Link Router", #selector(showMainWindow)))
        menu.addItem(.separator())

        // Пауза
        menu.addItem(item(config.rulesPaused ? "Возобновить правила" : "Приостановить правила",
                          #selector(togglePause)))

        // Браузер по умолчанию
        let browserMenu = NSMenu()
        let auto = item("Автоматически", #selector(selectDefaultBrowser(_:)), represented: "")
        auto.state = config.defaultBrowserBundleID == nil ? .on : .off
        browserMenu.addItem(auto)
        if !env.discovery.browsers.isEmpty { browserMenu.addItem(.separator()) }
        for browser in env.discovery.browsers {
            let entry = item(browser.name, #selector(selectDefaultBrowser(_:)), represented: browser.bundleID)
            entry.state = config.defaultBrowserBundleID == browser.bundleID ? .on : .off
            browserMenu.addItem(entry)
        }
        let browserParent = NSMenuItem(title: "Браузер по умолчанию", action: nil, keyEquivalent: "")
        browserParent.submenu = browserMenu
        menu.addItem(browserParent)

        // Правила
        let rulesMenu = NSMenu()
        if config.rules.isEmpty {
            let empty = NSMenuItem(title: "Правил пока нет", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            rulesMenu.addItem(empty)
        }
        for rule in config.rules {
            let browserName = env.discovery.browser(withBundleID: rule.browserBundleID)?.name ?? "браузер не найден"
            let entry = item("\(rule.pattern) → \(browserName)", #selector(toggleRule(_:)), represented: rule.id)
            entry.state = rule.isEnabled ? .on : .off
            rulesMenu.addItem(entry)
        }
        let rulesParent = NSMenuItem(title: "Правила", action: nil, keyEquivalent: "")
        rulesParent.submenu = rulesMenu
        menu.addItem(rulesParent)

        return menu
    }

    private func item(_ title: String, _ action: Selector, represented: Any? = nil) -> NSMenuItem {
        let menuItem = NSMenuItem(title: title, action: action, keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = represented
        return menuItem
    }

    // MARK: - Действия меню

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "Link Router" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func togglePause() {
        let store = AppEnvironment.shared.store
        store.setRulesPaused(!store.config.rulesPaused)
        updateDockBadge()
    }

    @objc private func selectDefaultBrowser(_ sender: NSMenuItem) {
        let id = sender.representedObject as? String ?? ""
        AppEnvironment.shared.store.setDefaultBrowser(id.isEmpty ? nil : id)
    }

    @objc private func toggleRule(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        let store = AppEnvironment.shared.store
        guard let rule = store.config.rules.first(where: { $0.id == id }) else { return }
        store.setRuleEnabled(id: id, !rule.isEnabled)
    }

    /// Значок ⏸ на иконке, пока правила на паузе.
    private func updateDockBadge() {
        NSApp.dockTile.badgeLabel = AppEnvironment.shared.store.config.rulesPaused ? "⏸" : nil
    }
}
