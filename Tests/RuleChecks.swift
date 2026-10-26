import Foundation

@main
struct RuleChecks {
    static func main() throws {
        func url(_ value: String) -> URL { URL(string: value)! }
        func rule(_ pattern: String, _ type: MatchType, priority: Int = 0, enabled: Bool = true) -> Rule {
            Rule(pattern: pattern, matchType: type, browserBundleID: "com.apple.Safari",
                 priority: priority, isEnabled: enabled)
        }
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message)
        }
        let exact = rule("example.com", .exactDomain)
        check(exact.matches(url("https://example.com/path")), "Exact domain")
        check(!exact.matches(url("https://sub.example.com")), "Exact excludes subdomains")
        check(exact.matches(url("https://EXAMPLE.COM./")), "Host normalization")
        let sub = rule("*.example.com", .domainWithSubdomains)
        check(sub.matches(url("https://example.com")), "Subdomain rule includes base")
        check(sub.matches(url("https://a.b.example.com")), "Nested subdomains")
        check(!sub.matches(url("https://evil-example.com")), "Domain boundary")
        let mask = rule("example.com/work/*", .urlMask)
        check(mask.matches(url("https://example.com/work/123")), "URL mask")
        check(!mask.matches(url("https://example.com/personal/123")), "Mask path boundary")
        let regex = rule("^https://example\\.com/", .regex)
        check(regex.matches(url("https://example.com/work")), "Regex matching")
        let engine = RuleEngine()
        let target = url("https://example.com/work/123")
        check(engine.match(url: target, rules: [sub, exact, mask])?.id == mask.id, "Specificity")
        let high = rule("example.com", .exactDomain, priority: 10)
        check(engine.match(url: target, rules: [mask, high])?.id == high.id, "Priority")
        let disabled = rule("example.com", .exactDomain, priority: 100, enabled: false)
        check(engine.match(url: target, rules: [disabled, exact])?.id == exact.id, "Disabled rule")
        let second = rule("example.com", .exactDomain)
        check(engine.match(url: target, rules: [exact, second])?.id == exact.id, "Stable ordering")
        check(engine.match(url: target, rules: []) == nil, "No matching rule")
        check(!RuleEngine.isWebURL(url("file:///tmp/test")), "Reject non-web URL")
        check(RuleEngine.isWebURL(target), "Accept HTTPS")
        do {
            try rule("[", .regex).validate()
            preconditionFailure("Invalid regex accepted")
        } catch is RuleValidationError {}
        print("Routing checks passed")
    }
}
