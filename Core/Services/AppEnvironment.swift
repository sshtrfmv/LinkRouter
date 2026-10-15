import SwiftUI

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let store: ConfigStore
    let discovery: BrowserDiscovery
    let history: HistoryStore
    let router: URLRouter
    /// Язык, выбранный на момент запуска. Если в настройках он другой, нужен перезапуск.
    let launchLanguage: AppLanguage

    private init() {
        let store = ConfigStore()
        let discovery = BrowserDiscovery()
        let history = HistoryStore()
        self.store = store
        self.discovery = discovery
        self.history = history
        self.launchLanguage = store.config.settings.language
        self.router = URLRouter(store: store,
                                discovery: discovery,
                                history: history,
                                engine: RuleEngine(),
                                launcher: BrowserLauncher())
    }
}

extension View {
    /// Передаёт общие объекты приложения во все вложенные экраны.
    func withAppEnvironment(_ env: AppEnvironment) -> some View {
        self
            .environmentObject(env.store)
            .environmentObject(env.discovery)
            .environmentObject(env.history)
            .environmentObject(env.router)
    }
}
