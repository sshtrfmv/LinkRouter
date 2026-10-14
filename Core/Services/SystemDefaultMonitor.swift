import AppKit
import Combine

@MainActor
final class SystemDefaultMonitor: ObservableObject {
    @Published private(set) var isDefault = false
    @Published var errorMessage: String?

    init() {
        refresh()
    }

    func refresh() {
        guard let probe = URL(string: "https://example.com"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: probe) else {
            isDefault = false
            return
        }
        isDefault = Bundle(url: appURL)?.bundleIdentifier == Bundle.main.bundleIdentifier
    }

    func makeDefault() async {
        errorMessage = nil
        for scheme in ["http", "https"] {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL,
                                                                   toOpenURLsWithScheme: scheme)
            } catch {
                errorMessage = "Не удалось назначить автоматически. Сделайте это вручную: Системные настройки → Рабочий стол и Dock → Браузер по умолчанию."
                break
            }
        }
        refresh()
    }
}
