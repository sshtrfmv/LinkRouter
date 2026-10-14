import AppKit

@MainActor
struct BrowserLauncher {
    func open(_ url: URL, in browser: Browser) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.open([url],
                                              withApplicationAt: browser.url,
                                              configuration: configuration)
    }
}
