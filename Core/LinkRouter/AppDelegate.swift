import AppKit
import Combine

extension Notification.Name {
    /// Просьба пересчитать, нужна ли иконка в Dock.
    static let activationPolicyNeedsUpdate = Notification.Name("LinkRouter.activationPolicyNeedsUpdate")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Запуск

    func applicationDidFinishLaunching(_ notification: Notification) {
        let store = AppEnvironment.shared.store
        let center = NotificationCenter.default

        // Значок ⏸ в Dock, пока правила на паузе.
        store.$config
            .map(\.rulesPaused)
            .removeDuplicates()
            .sink { paused in NSApp.dockTile.badgeLabel = paused ? "⏸" : nil }
            .store(in: &cancellables)

        // Изменили настройку «Убирать из Dock». dropFirst: на старте ничего не пересчитываем,
        // пока окно ещё не появилось. Task откладывает пересчёт: $config публикует значение до записи.
        store.$config
            .map(\.settings.hideDockWhenClosed)
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] _ in
                Task { self?.updateActivationPolicy() }
            }
            .store(in: &cancellables)

        // Окно стало главным: показываем иконку в Dock.
        center.publisher(for: NSWindow.didBecomeMainNotification)
            .sink { [weak self] _ in
                Task { self?.updateActivationPolicy() }
            }
            .store(in: &cancellables)

        // Окно закрывается: через мгновение проверяем, остались ли окна.
        center.publisher(for: NSWindow.willCloseNotification)
            .sink { [weak self] _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    self?.updateActivationPolicy()
                }
            }
            .store(in: &cancellables)

        // Явная просьба из настроек (например, включили или выключили значок в строке меню).
        center.publisher(for: .activationPolicyNeedsUpdate)
            .sink { [weak self] _ in
                Task { self?.updateActivationPolicy() }
            }
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

    // MARK: - Иконка в Dock

    private func updateActivationPolicy() {
        let settings = AppEnvironment.shared.store.config.settings
        let menuBarVisible = UserDefaults.standard.object(forKey: "showMenuBarIcon") as? Bool ?? true

        // Свёрнутое окно живёт в Dock, поэтому тоже считается открытым.
        let hasWindow = NSApp.windows.contains {
            ($0.isVisible || $0.isMiniaturized) && $0.canBecomeMain
        }

        // Если значок в строке меню скрыт, из Dock не уходим: иначе до приложения не добраться.
        let wantsDock = hasWindow || !settings.hideDockWhenClosed || !menuBarVisible
        let desired: NSApplication.ActivationPolicy = wantsDock ? .regular : .accessory

        if NSApp.activationPolicy() != desired {
            NSApp.setActivationPolicy(desired)
        }
    }

    // MARK: - Меню в Dock

    /// Меню собирается заново при каждом правом щелчке, поэтому всегда актуально.
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let env = AppEnvironment.shared
        env.discovery.refresh()
        let config = env.store.config
        let menu = NSMenu()

        menu.addItem(item("Открыть Link Router", #selector(showMainWindow)))
        menu.addItem(.separator())

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
        NSApp.activate()
        if let window = NSApp.windows.first(where: { $0.title == "Link Router" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func togglePause() {
        let store = AppEnvironment.shared.store
        store.setRulesPaused(!store.config.rulesPaused)
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
}
