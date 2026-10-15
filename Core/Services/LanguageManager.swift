import AppKit

@MainActor
enum LanguageManager {
    /// Запоминает язык так, чтобы macOS применила его при следующем запуске приложения.
    static func apply(_ language: AppLanguage) {
        switch language {
        case .system:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        case .ru:
            UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
        case .en:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        }
    }

    /// Запускает приложение заново и завершает текущий экземпляр.
    /// Путь передаётся отдельным аргументом, поэтому спецсимволы в нём ничего не ломают.
    static func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
