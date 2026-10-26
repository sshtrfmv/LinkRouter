# LinkRouter

Native macOS app that opens links in different browsers according to your rules.

## Install

The current source targets macOS 14.6 or later.

```sh
brew tap sshtrfmv/tap
brew install --cask linkrouter
```

Or download `LinkRouter.dmg` from [Releases](https://github.com/sshtrfmv/LinkRouter/releases), then drag the app into Applications.
The app is not notarized: on first launch, macOS may require approval in System Settings → Privacy & Security.

Set LinkRouter as your default browser in its settings, then choose a fallback browser and add rules.
Only links passed to the system default browser are routed; links navigating inside a browser are unaffected.

## Rules

| Type | Example | Matches |
| --- | --- | --- |
| Exact domain | `example.com` | The domain itself |
| Domain with subdomains | `*.example.com` | Base domain and its subdomains |
| URL mask | `example.com/work/*` | Links under the work path |
| Regular expression | `^https://example[.]com/` | URLs matching the expression |

Higher priority wins. At equal priority: URL mask, exact domain, domain with subdomains, then regex.
Ties use the order in the list. Disabled rules are skipped.
If no rule matches or its browser is unavailable, the fallback browser is used.

## Privacy

History can be disabled or cleared in Settings. It stores the visited domain, time, selected browser,
fallback status, and matching rule pattern. A rule pattern can itself contain a path or query;
full visited URLs are not stored in history.

## Development

Open `LinkRouter.xcodeproj` in a current Xcode with Swift 6.2 or later.
CI builds the app without signing and checks the routing engine.

```sh
swiftc Core/Rule.swift Core/RuleEngine.swift Tests/RuleChecks.swift -o /tmp/linkrouter-rule-checks
/tmp/linkrouter-rule-checks
xcodebuild -project LinkRouter.xcodeproj -target LinkRouter -configuration Release CODE_SIGNING_ALLOWED=NO build
```

## License

MIT; see [LICENSE](LICENSE).
