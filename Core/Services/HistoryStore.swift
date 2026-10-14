import Foundation
import Combine
import OSLog

nonisolated struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var date: Date
    /// Только домен: путь и параметры ссылки не сохраняются.
    var host: String
    var rulePattern: String?
    var browserBundleID: String
    var browserName: String
    var usedFallback: Bool
}

@MainActor
final class HistoryStore: ObservableObject {
    /// Новые записи — в начале.
    @Published private(set) var entries: [HistoryEntry]

    private let fileURL: URL
    private let logger = Logger(subsystem: "LinkRouter", category: "history")

    nonisolated static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent("LinkRouter", isDirectory: true)
            .appendingPathComponent("history.json")
    }

    init(fileURL: URL = HistoryStore.defaultFileURL) {
        self.fileURL = fileURL
        self.entries = HistoryStore.load(from: fileURL)
    }

    func add(_ entry: HistoryEntry, limit: Int) {
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries.removeLast(entries.count - limit)
        }
        save()
    }

    func trim(to limit: Int) {
        guard entries.count > limit else { return }
        entries.removeLast(entries.count - limit)
        save()
    }

    func clear() {
        entries.removeAll()
        save()
    }

    private static func load(from url: URL) -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([HistoryEntry].self, from: data)) ?? []
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(entries).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Ошибка сохранения истории: \(error.localizedDescription, privacy: .public)")
        }
    }
}
