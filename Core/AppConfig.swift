import Foundation

/// Настройки поведения приложения.
nonisolated struct AppSettings: Codable, Equatable, Sendable {
    var hideDockWhenClosed = true
    var showMenuBarIcon = true
    var historyEnabled = true
    var historyLimit = 200

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hideDockWhenClosed = try c.decodeIfPresent(Bool.self, forKey: .hideDockWhenClosed) ?? true
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        historyEnabled = try c.decodeIfPresent(Bool.self, forKey: .historyEnabled) ?? true
        historyLimit = try c.decodeIfPresent(Int.self, forKey: .historyLimit) ?? 200
    }
}

/// Всё, что сохраняется на диск. Поле schemaVersion позволит мигрировать формат в будущем.
nonisolated struct AppConfig: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var rules: [Rule]
    /// Браузер для ссылок, под которые нет правил. nil — выберем автоматически.
    var defaultBrowserBundleID: String?
    /// Пауза: правила игнорируются, всё открывается в браузере по умолчанию.
    var rulesPaused: Bool
    var settings: AppSettings

    init(schemaVersion: Int = AppConfig.currentSchemaVersion,
         rules: [Rule] = [],
         defaultBrowserBundleID: String? = nil,
         rulesPaused: Bool = false,
         settings: AppSettings = AppSettings()) {
        self.schemaVersion = schemaVersion
        self.rules = rules
        self.defaultBrowserBundleID = defaultBrowserBundleID
        self.rulesPaused = rulesPaused
        self.settings = settings
    }

    // Мягкое чтение: отсутствующие поля не ломают загрузку старого файла.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        rules = try c.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        defaultBrowserBundleID = try c.decodeIfPresent(String.self, forKey: .defaultBrowserBundleID)
        rulesPaused = try c.decodeIfPresent(Bool.self, forKey: .rulesPaused) ?? false
        settings = try c.decodeIfPresent(AppSettings.self, forKey: .settings) ?? AppSettings()
    }
}
