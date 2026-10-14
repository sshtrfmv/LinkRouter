import XCTest
@testable import LinkRouter

final class RuleEngineTests: XCTestCase {

    private let engine = RuleEngine()

    private func rule(_ pattern: String,
                      _ type: MatchType,
                      browser: String = "chrome",
                      priority: Int = 0,
                      enabled: Bool = true) -> Rule {
        Rule(pattern: pattern, matchType: type, browserBundleID: browser,
             priority: priority, isEnabled: enabled)
    }

    private func url(_ s: String) -> URL { URL(string: s)! }

    // MARK: - Домены

    func testExactDomainMatchesOnlyThatHost() {
        let rules = [rule("youtube.com", .exactDomain)]
        XCTAssertNotNil(engine.match(url: url("https://youtube.com/watch?v=1"), rules: rules))
        XCTAssertNotNil(engine.match(url: url("https://YouTube.com/"), rules: rules))
        XCTAssertNil(engine.match(url: url("https://www.youtube.com/"), rules: rules))
    }

    func testDomainWithSubdomains() {
        let rules = [rule("google.com", .domainWithSubdomains)]
        XCTAssertNotNil(engine.match(url: url("https://google.com"), rules: rules))
        XCTAssertNotNil(engine.match(url: url("https://mail.google.com/inbox"), rules: rules))
        XCTAssertNil(engine.match(url: url("https://notgoogle.com"), rules: rules))
        XCTAssertNil(engine.match(url: url("https://google.com.evil.org"), rules: rules))
    }

    func testWildcardPrefixInSubdomainRule() {
        let rules = [rule("*.google.com", .domainWithSubdomains)]
        XCTAssertNotNil(engine.match(url: url("https://mail.google.com"), rules: rules))
        XCTAssertNotNil(engine.match(url: url("https://google.com"), rules: rules))
    }

    func testPatternPastedAsFullURLIsNormalized() {
        let rules = [rule("https://github.com/", .exactDomain)]
        XCTAssertNotNil(engine.match(url: url("https://github.com/apple"), rules: rules))
    }

    // MARK: - Маски

    func testURLMaskWithPath() {
        let rules = [rule("https://example.com/work/*", .urlMask)]
        XCTAssertNotNil(engine.match(url: url("https://example.com/work/doc?id=1"), rules: rules))
        XCTAssertNil(engine.match(url: url("https://example.com/personal/x"), rules: rules))
        XCTAssertNil(engine.match(url: url("http://example.com/work/x"), rules: rules))
    }

    func testURLMaskWithoutSchemeMatchesAnyScheme() {
        let rules = [rule("example.com/work/*", .urlMask)]
        XCTAssertNotNil(engine.match(url: url("http://example.com/work/a"), rules: rules))
        XCTAssertNotNil(engine.match(url: url("https://example.com/work/a"), rules: rules))
    }

    func testQuestionMarkIsLiteralInMask() {
        let rules = [rule("https://example.com/search?q=*", .urlMask)]
        XCTAssertNotNil(engine.match(url: url("https://example.com/search?q=cats"), rules: rules))
        XCTAssertNil(engine.match(url: url("https://example.com/searchXq=cats"), rules: rules))
    }

    // MARK: - Regex

    func testRegex() {
        let rules = [rule("^https://github\\.com/[^/]+/[^/]+/pull/\\d+", .regex)]
        XCTAssertNotNil(engine.match(url: url("https://github.com/apple/swift/pull/123"), rules: rules))
        XCTAssertNil(engine.match(url: url("https://github.com/apple/swift/issues/123"), rules: rules))
    }

    // MARK: - Конфликты

    func testDisabledRuleIsIgnored() {
        let rules = [rule("youtube.com", .exactDomain, enabled: false)]
        XCTAssertNil(engine.match(url: url("https://youtube.com"), rules: rules))
    }

    func testHigherPriorityWins() {
        let rules = [
            rule("google.com", .domainWithSubdomains, browser: "low", priority: 0),
            rule("google.com", .domainWithSubdomains, browser: "high", priority: 10)
        ]
        XCTAssertEqual(engine.match(url: url("https://google.com"), rules: rules)?.browserBundleID, "high")
    }

    func testMoreSpecificTypeWinsOnEqualPriority() {
        let rules = [
            rule("example.com", .domainWithSubdomains, browser: "domain"),
            rule("https://example.com/work/*", .urlMask, browser: "mask")
        ]
        XCTAssertEqual(engine.match(url: url("https://example.com/work/a"), rules: rules)?.browserBundleID, "mask")
        XCTAssertEqual(engine.match(url: url("https://example.com/home"), rules: rules)?.browserBundleID, "domain")

        let rules2 = [
            rule("example.com", .domainWithSubdomains, browser: "sub"),
            rule("example.com", .exactDomain, browser: "exact")
        ]
        XCTAssertEqual(engine.match(url: url("https://example.com"), rules: rules2)?.browserBundleID, "exact")
    }

    func testListOrderBreaksFullTie() {
        let rules = [
            rule("example.com", .exactDomain, browser: "first"),
            rule("example.com", .exactDomain, browser: "second")
        ]
        XCTAssertEqual(engine.match(url: url("https://example.com"), rules: rules)?.browserBundleID, "first")
    }

    func testNoMatchReturnsNil() {
        let rules = [rule("youtube.com", .exactDomain)]
        XCTAssertNil(engine.match(url: url("https://example.org"), rules: rules))
    }

    func testCandidatesAreOrdered() {
        let rules = [
            rule("example.com", .domainWithSubdomains, browser: "b", priority: 1),
            rule("example.com", .exactDomain, browser: "a", priority: 5),
            rule("other.com", .exactDomain, browser: "x")
        ]
        let result = engine.evaluate(url: url("https://example.com"), rules: rules)
        XCTAssertEqual(result.candidates.map(\.browserBundleID), ["a", "b"])
        XCTAssertEqual(result.winner?.browserBundleID, "a")
    }

    // MARK: - Допустимые URL

    func testOnlyHTTPAndHTTPSAreRoutable() {
        XCTAssertTrue(RuleEngine.isWebURL(url("https://example.com")))
        XCTAssertTrue(RuleEngine.isWebURL(url("http://example.com/a")))
        XCTAssertFalse(RuleEngine.isWebURL(url("ftp://example.com")))
        XCTAssertFalse(RuleEngine.isWebURL(url("mailto:a@b.com")))
        XCTAssertFalse(RuleEngine.isWebURL(url("https:///nohost")))
    }

    // MARK: - Валидация

    func testValidationErrors() {
        XCTAssertThrowsError(try rule("  ", .exactDomain).validate()) {
            XCTAssertEqual($0 as? RuleValidationError, .emptyPattern)
        }
        XCTAssertThrowsError(try rule("*.google.com", .exactDomain).validate()) {
            XCTAssertEqual($0 as? RuleValidationError, .wildcardInExactDomain)
        }
        XCTAssertThrowsError(try rule("exa mple.com", .exactDomain).validate()) {
            XCTAssertEqual($0 as? RuleValidationError, .invalidDomain)
        }
        XCTAssertThrowsError(try rule("(", .regex).validate()) {
            guard case .invalidRegex = ($0 as? RuleValidationError) else {
                return XCTFail("Ожидалась ошибка invalidRegex")
            }
        }
        XCTAssertThrowsError(try rule("example.com", .exactDomain, browser: "").validate()) {
            XCTAssertEqual($0 as? RuleValidationError, .missingBrowser)
        }
    }

    func testValidRulesPassValidation() throws {
        try rule("youtube.com", .exactDomain).validate()
        try rule("*.google.com", .domainWithSubdomains).validate()
        try rule("https://example.com/work/*", .urlMask).validate()
        try rule("^https://example\\.com", .regex).validate()
    }
}
