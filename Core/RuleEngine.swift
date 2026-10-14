import Foundation

/// Результат проверки URL: победившее правило и все подходящие правила по порядку приоритета.
/// Список кандидатов пригодится для кнопки «Проверить URL».
nonisolated struct RuleEvaluation: Equatable, Sendable {
    let winner: Rule?
    let candidates: [Rule]
}

nonisolated struct RuleEngine: Sendable {

    /// Порядок выбора:
    /// 1. только включённые правила, подходящие под URL;
    /// 2. больший приоритет раньше;
    /// 3. при равном приоритете более конкретный тип (маска URL, точный домен, домен с поддоменами, regex);
    /// 4. при полном равенстве — правило, стоящее выше в списке.
    func evaluate(url: URL, rules: [Rule]) -> RuleEvaluation {
        let matched = rules.enumerated().filter { $0.element.isEnabled && $0.element.matches(url) }

        let sorted = matched.sorted { a, b in
            if a.element.priority != b.element.priority {
                return a.element.priority > b.element.priority
            }
            let sa = a.element.matchType.specificity
            let sb = b.element.matchType.specificity
            if sa != sb { return sa < sb }
            return a.offset < b.offset
        }.map(\.element)

        return RuleEvaluation(winner: sorted.first, candidates: sorted)
    }

    func match(url: URL, rules: [Rule]) -> Rule? {
        evaluate(url: url, rules: rules).winner
    }

    /// Мы обрабатываем только http и https со непустым хостом.
    static func isWebURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        guard let host = url.host(percentEncoded: false), !host.isEmpty else { return false }
        return true
    }
}
