import Foundation
import Combine
import OSLog

@MainActor
final class ConfigStore: ObservableObject {
    @Published private(set) var config: AppConfig
    /// Сообщение о проблеме при загрузке (например, файл был повреждён).
    @Published private(set) var loadMessage: String?
    /// Сообщение о проблеме при сохранении.
    @Published private(set) var saveError: String?

    private let fileURL: URL
    private let logger = Logger(subsystem: "LinkRouter", category: "config")

    nonisolated static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("LinkRouter", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    init(fileURL: URL = ConfigStore.defaultFileURL) {
        self.fileURL = fileURL
        let result = ConfigStore.load(from: fileURL)
        self.config = result.config
        self.loadMessage = result.message
    }

    // MARK: - Правила

    func addRule(_ rule: Rule) throws {
        var rule = rule
        rule.pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        try rule.validate()
        config.rules.append(rule)
        save()
    }

    func updateRule(_ rule: Rule) throws {
        var rule = rule
        rule.pattern = rule.pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        try rule.validate()
        guard let index = config.rules.firstIndex(where: { $0.id == rule.id }) else { return }
        config.rules[index] = rule
        save()
    }

    func deleteRule(id: UUID) {
        config.rules.removeAll { $0.id == id }
        save()
    }

    func duplicateRule(id: UUID) {
        guard let index = config.rules.firstIndex(where: { $0.id == id }) else { return }
        var copy = config.rules[index]
        copy.id = UUID()
        config.rules.insert(copy, at: index + 1)
        save()
    }

    func setRuleEnabled(id: UUID, _ enabled: Bool) {
           guard let index = config.rules.firstIndex(where: { $0.id == id }),
                 config.rules[index].isEnabled != enabled else { return }
           config.rules[index].isEnabled = enabled
           save()
       }

    /// Перестановка правил (для перетаскивания в списке).
    func moveRules(from source: IndexSet, to destination: Int) {
        var rules = config.rules
        let sorted = source.sorted()
        let moving = sorted.map { rules[$0] }
        let removedBefore = sorted.filter { $0 < destination }.count
        for index in sorted.reversed() { rules.remove(at: index) }
        rules.insert(contentsOf: moving, at: destination - removedBefore)
        config.rules = rules
        save()
    }

    // MARK: - Остальные настройки

    func setDefaultBrowser(_ bundleID: String?) {
            guard config.defaultBrowserBundleID != bundleID else { return }
            config.defaultBrowserBundleID = bundleID
            save()
        }

    func setRulesPaused(_ paused: Bool) {
            guard config.rulesPaused != paused else { return }
            config.rulesPaused = paused
            save()
        }

    func updateSettings(_ change: (inout AppSettings) -> Void) {
            var settings = config.settings
            change(&settings)
            guard settings != config.settings else { return }
            config.settings = settings
            save()
        }

    // MARK: - Диск

    private static func load(from url: URL) -> (config: AppConfig, message: String?) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return (AppConfig(), nil)
        }
        do {
            let data = try Data(contentsOf: url)
            var loaded = try JSONDecoder().decode(AppConfig.self, from: data)
            loaded = migrate(loaded)
            return (loaded, nil)
        } catch {
            // Файл повреждён: сохраняем его копию и начинаем с чистой конфигурации.
            let stamp = Int(Date().timeIntervalSince1970)
            let backup = url.deletingLastPathComponent()
                .appendingPathComponent("config.corrupt-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: backup)
            return (AppConfig(),
                    "Файл настроек повреждён. Он сохранён как \(backup.lastPathComponent), начата чистая конфигурация.")
        }
    }

    /// Место для будущих миграций формата.
    private static func migrate(_ config: AppConfig) -> AppConfig {
        var result = config
        if result.schemaVersion < AppConfig.currentSchemaVersion {
            result.schemaVersion = AppConfig.currentSchemaVersion
        }
        return result
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: fileURL, options: .atomic)
            saveError = nil
        } catch {
            saveError = "Не удалось сохранить настройки: \(error.localizedDescription)"
            logger.error("Ошибка сохранения конфигурации: \(error.localizedDescription, privacy: .public)")
        }
    }
}
