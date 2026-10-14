import SwiftUI

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let store: ConfigStore
    let discovery: BrowserDiscovery
    let history: HistoryStore
    let router: URLRouter

    private init() {
        let store = ConfigStore()
        let discovery = BrowserDiscovery()
        let history = HistoryStore()
        self.store = store
        self.discovery = discovery
        self.history = history
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
