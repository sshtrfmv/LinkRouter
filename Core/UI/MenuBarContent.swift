import SwiftUI
import AppKit

struct MenuBarLabel: View {
    @ObservedObject var store: ConfigStore

    var body: some View {
        Image(systemName: store.config.rulesPaused ? "pause.circle" : "arrow.triangle.branch")
    }
}

struct MenuBarContent: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var discovery: BrowserDiscovery
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var pausedBinding: Binding<Bool> {
        Binding(get: { store.config.rulesPaused },
                set: { store.setRulesPaused($0) })
    }

    private var defaultBrowserBinding: Binding<String> {
        Binding(get: { store.config.defaultBrowserBundleID ?? "" },
                set: { store.setDefaultBrowser($0.isEmpty ? nil : $0) })
    }

    private func enabledBinding(for rule: Rule) -> Binding<Bool> {
        Binding(get: { rule.isEnabled },
                set: { store.setRuleEnabled(id: rule.id, $0) })
    }

    var body: some View {
        Button("Открыть Link Router") {
            NSApp.setActivationPolicy(.regular)
            openWindow(id: "main")
            NSApp.activate()
        }

        Divider()

        Toggle("Приостановить правила", isOn: pausedBinding)

        Menu("Браузер по умолчанию") {
            Picker("Браузер по умолчанию", selection: defaultBrowserBinding) {
                Text("Автоматически").tag("")
                ForEach(discovery.browsers) { browser in
                    Text(browser.name).tag(browser.bundleID)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        }

        Menu("Правила") {
            if store.config.rules.isEmpty {
                Text("Правил пока нет")
            }
            ForEach(store.config.rules) { rule in
                let browserName = discovery.browser(withBundleID: rule.browserBundleID)?.name ?? "браузер не найден"
                Toggle("\(rule.pattern) → \(browserName)", isOn: enabledBinding(for: rule))
            }
        }

        Divider()

        Button("Настройки…") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Выйти из Link Router") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
