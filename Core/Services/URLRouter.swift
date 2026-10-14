import Foundation
import Combine
import OSLog

nonisolated struct RouteDecision: Sendable {
    let url: URL
    let rule: Rule?
    let browser: Browser?
    let usedFallback: Bool
    let explanation: String
}

@MainActor
final class URLRouter: ObservableObject {
    @Published private(set) var lastDecision: RouteDecision?
    @Published private(set) var lastError: String?

    private let store: ConfigStore
    private let discovery: BrowserDiscovery
    private let history: HistoryStore
    private let engine: RuleEngine
    private let launcher: BrowserLauncher
    private let logger = Logger(subsystem: "LinkRouter", category: "router")

    init(store: ConfigStore,
         discovery: BrowserDiscovery,
         history: HistoryStore,
         engine: RuleEngine,
         launcher: BrowserLauncher) {
        self.store = store
        self.discovery = discovery
        self.history = history
        self.engine = engine
        self.launcher = launcher
    }

    /// Вызывается, когда система передала нам ссылку.
    func handle(_ url: URL) async {
        guard RuleEngine.isWebURL(url) else {
            lastError = String(localized: "Ссылка не поддерживается (нужен http или https).")
            logger.notice("Skipped URL with unsupported scheme")
            return
        }

        discovery.refresh()
        let decision = decide(url)
        lastDecision = decision

        guard let browser = decision.browser else {
            lastError = String(localized: "Не найден ни один браузер для открытия ссылки.")
            logger.error("No browsers available")
            return
        }

        do {
            try await launcher.open(url, in: browser)
            lastError = nil
            let host = url.host(percentEncoded: false) ?? ""
            logger.info("Opened in \(browser.bundleID, privacy: .public), host \(host, privacy: .private)")

            let settings = store.config.settings
            if settings.historyEnabled {
                history.add(HistoryEntry(date: Date(),
                                         host: host,
                                         rulePattern: decision.rule?.pattern,
                                         browserBundleID: browser.bundleID,
                                         browserName: browser.name,
                                         usedFallback: decision.usedFallback),
                            limit: settings.historyLimit)
            }
        } catch {
            lastError = String(localized: "Не удалось открыть ссылку в «\(browser.name)»: \(error.localizedDescription)")
            logger.error("Browser launch failed \(browser.bundleID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Только решает, куда отправить ссылку, ничего не открывая.
    func decide(_ url: URL) -> RouteDecision {
        if store.config.rulesPaused {
            let fallback = fallbackBrowser()
            let target = fallback?.name ?? String(localized: "браузер не найден")
            return RouteDecision(url: url, rule: nil, browser: fallback, usedFallback: true,
                                 explanation: String(localized: "Правила приостановлены. Все ссылки открываются в: \(target)."))
        }

        let evaluation = engine.evaluate(url: url, rules: store.config.rules)

        if let rule = evaluation.winner {
            if let browser = discovery.browser(withBundleID: rule.browserBundleID) {
                return RouteDecision(url: url, rule: rule, browser: browser, usedFallback: false,
                                     explanation: String(localized: "Сработало правило «\(rule.pattern)» → \(browser.name)."))
            }
            let fallback = fallbackBrowser()
            let target = fallback?.name ?? String(localized: "браузер не найден")
            return RouteDecision(url: url, rule: rule, browser: fallback, usedFallback: true,
                                 explanation: String(localized: "Браузер из правила «\(rule.pattern)» не установлен. Запасной вариант: \(target)."))
        }

        let fallback = fallbackBrowser()
        let target = fallback?.name ?? String(localized: "браузер не найден")
        return RouteDecision(url: url, rule: nil, browser: fallback, usedFallback: true,
                             explanation: String(localized: "Подходящих правил нет. Браузер по умолчанию: \(target)."))
    }

    /// Порядок: выбранный в приложении → Safari → первый найденный.
    /// Само приложение в списке браузеров отсутствует, поэтому ссылка не вернётся к нам.
    private func fallbackBrowser() -> Browser? {
        if let chosen = discovery.browser(withBundleID: store.config.defaultBrowserBundleID) {
            return chosen
        }
        if let safari = discovery.browser(withBundleID: "com.apple.Safari") {
            return safari
        }
        return discovery.browsers.first
    }
}
