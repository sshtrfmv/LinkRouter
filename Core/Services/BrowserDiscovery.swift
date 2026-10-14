import AppKit
import Combine

nonisolated struct Browser: Identifiable, Hashable, Sendable {
    let bundleID: String
    let name: String
    let url: URL
    var id: String { bundleID }
}

@MainActor
final class BrowserDiscovery: ObservableObject {
    @Published private(set) var browsers: [Browser] = []

    init() {
        refresh()
    }

    /// Спрашивает у macOS, какие приложения умеют открывать https-ссылки.
    func refresh() {
        guard let probe = URL(string: "https://example.com") else { return }
        let ownID = Bundle.main.bundleIdentifier
        var seen = Set<String>()
        var found: [Browser] = []

        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probe) {
            guard let bundle = Bundle(url: appURL),
                  let id = bundle.bundleIdentifier,
                  id != ownID,
                  seen.insert(id).inserted else { continue }
            found.append(Browser(bundleID: id,
                                 name: Self.displayName(for: appURL, bundle: bundle),
                                 url: appURL))
        }
        browsers = found.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func browser(withBundleID id: String?) -> Browser? {
        guard let id else { return nil }
        return browsers.first { $0.bundleID == id }
    }

    func icon(for browser: Browser) -> NSImage {
        NSWorkspace.shared.icon(forFile: browser.url.path)
    }

    private static func displayName(for appURL: URL, bundle: Bundle) -> String {
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !name.isEmpty {
            return name
        }
        if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
            return name
        }
        return appURL.deletingPathExtension().lastPathComponent
    }
}
