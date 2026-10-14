import Foundation

nonisolated enum URLInput {
    /// "youtube.com/watch" → https://youtube.com/watch
    static func parse(_ text: String) -> URL? {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.contains("://") { s = "https://" + s }
        guard let url = URL(string: s), RuleEngine.isWebURL(url) else { return nil }
        return url
    }
}
