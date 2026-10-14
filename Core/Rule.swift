import Foundation

/// Тип сопоставления шаблона с URL.
nonisolated enum MatchType: String, Codable, CaseIterable, Identifiable, Sendable {
    case urlMask               // маска URL со знаком * (например https://example.com/work/*)
    case exactDomain           // точный домен (youtube.com, но не www.youtube.com)
    case domainWithSubdomains  // домен и все его поддомены (google.com, mail.google.com)
    case regex                 // регулярное выражение, ищется в любом месте URL

    var id: String { rawValue }

    var title: String {
        switch self {
        case .urlMask: return "Маска URL"
        case .exactDomain: return "Точный домен"
        case .domainWithSubdomains: return "Домен с поддоменами"
        case .regex: return "Регулярное выражение"
        }
    }

    /// Чем меньше число, тем конкретнее тип. Нужно для разрешения конфликтов.
    var specificity: Int {
        switch self {
        case .urlMask: return 0
        case .exactDomain: return 1
        case .domainWithSubdomains: return 2
        case .regex: return 3
        }
    }
}

/// Ошибки проверки правила. Тексты показываются пользователю.
nonisolated enum RuleValidationError: LocalizedError, Equatable, Sendable {
    case emptyPattern
    case invalidDomain
    case wildcardInExactDomain
    case invalidRegex(String)
    case missingBrowser

    var errorDescription: String? {
        switch self {
        case .emptyPattern:
            return "Шаблон не может быть пустым."
        case .invalidDomain:
            return "Некорректный домен. Пример: example.com"
        case .wildcardInExactDomain:
            return "Знак * нельзя использовать в точном домене. Выберите «Домен с поддоменами»."
        case .invalidRegex(let details):
            return "Некорректное регулярное выражение: \(details)"
        case .missingBrowser:
            return "Выберите браузер для правила."
        }
    }
}

/// Правило маршрутизации: «ссылки, подходящие под шаблон, открывать в этом браузере».
nonisolated struct Rule: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var pattern: String
    var matchType: MatchType
    /// Bundle ID браузера, например "com.google.Chrome" или "com.apple.Safari".
    var browserBundleID: String
    /// Больше число — выше приоритет.
    var priority: Int = 0
    var isEnabled: Bool = true

    // MARK: - Проверка правила

    func validate() throws {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RuleValidationError.emptyPattern }
        guard !browserBundleID.isEmpty else { throw RuleValidationError.missingBrowser }

        switch matchType {
        case .exactDomain:
            if trimmed.hasPrefix("*") { throw RuleValidationError.wildcardInExactDomain }
            guard Rule.isValidDomain(Rule.normalizedDomain(trimmed)) else {
                throw RuleValidationError.invalidDomain
            }
        case .domainWithSubdomains:
            guard Rule.isValidDomain(Rule.subdomainBase(trimmed)) else {
                throw RuleValidationError.invalidDomain
            }
        case .urlMask:
            break
        case .regex:
            do {
                _ = try NSRegularExpression(pattern: trimmed, options: [.caseInsensitive])
            } catch {
                throw RuleValidationError.invalidRegex(error.localizedDescription)
            }
        }
    }

    // MARK: - Сопоставление

    func matches(_ url: URL) -> Bool {
        let p = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return false }

        switch matchType {
        case .exactDomain:
            guard let host = Rule.host(of: url) else { return false }
            return host == Rule.normalizedDomain(p)

        case .domainWithSubdomains:
            guard let host = Rule.host(of: url) else { return false }
            let base = Rule.subdomainBase(p)
            guard !base.isEmpty else { return false }
            return host == base || host.hasSuffix("." + base)

        case .urlMask:
            return Rule.globMatches(mask: p, in: url.absoluteString)

        case .regex:
            guard let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else {
                return false
            }
            let string = url.absoluteString
            let range = NSRange(string.startIndex..., in: string)
            return regex.firstMatch(in: string, range: range) != nil
        }
    }

    // MARK: - Вспомогательные функции

    /// Хост URL в нижнем регистре, без точки в конце.
    static func host(of url: URL) -> String? {
        guard var host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else { return nil }
        while host.hasSuffix(".") { host.removeLast() }
        return host
    }

    /// Приводит ввод пользователя к чистому домену: убирает схему, путь, пробелы, регистр.
    /// "https://YouTube.com/watch" → "youtube.com"
    static func normalizedDomain(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let range = s.range(of: "://") { s = String(s[range.upperBound...]) }
        if let end = s.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) {
            s = String(s[..<end])
        }
        while s.hasSuffix(".") { s.removeLast() }
        return s
    }

    /// Основа для правила «домен с поддоменами»: "*.google.com" и "google.com" дают "google.com".
    static func subdomainBase(_ raw: String) -> String {
        var d = normalizedDomain(raw)
        if d.hasPrefix("*.") { d.removeFirst(2) }
        return d
    }

    static func isValidDomain(_ domain: String) -> Bool {
        guard !domain.isEmpty, !domain.hasPrefix("."), !domain.contains("..") else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._"))
        return domain.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Сопоставление маски со знаком * (любое количество любых символов).
    /// Остальные символы, включая ?, понимаются буквально.
    /// Если в маске нет схемы, подходит любая схема: "example.com/work/*" → "*://example.com/work/*".
    static func globMatches(mask: String, in string: String) -> Bool {
        var m = mask
        if !m.contains("://") { m = "*://" + m }

        var pattern = "^"
        for ch in m {
            if ch == "*" {
                pattern += ".*"
            } else {
                pattern += NSRegularExpression.escapedPattern(for: String(ch))
            }
        }
        pattern += "$"

        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }
}
