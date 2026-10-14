import SwiftUI

struct BrowsersView: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var discovery: BrowserDiscovery

    private var defaultBinding: Binding<String> {
        Binding(
            get: { store.config.defaultBrowserBundleID ?? "" },
            set: { store.setDefaultBrowser($0.isEmpty ? nil : $0) }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DefaultBrowserBanner(alwaysShow: true)

            List {
                Section("Для ссылок без правил") {
                    Picker("Браузер по умолчанию в приложении", selection: defaultBinding) {
                        Text("Автоматически (Safari или первый найденный)").tag("")
                        ForEach(discovery.browsers) { browser in
                            Text(browser.name).tag(browser.bundleID)
                        }
                    }
                }

                Section("Установленные браузеры: \(discovery.browsers.count)") {
                    if discovery.browsers.isEmpty {
                        Text("Браузеры не найдены")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(discovery.browsers) { browser in
                        HStack(spacing: 12) {
                            Image(nsImage: discovery.icon(for: browser))
                                .resizable()
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(browser.name).font(.headline)
                                Text(browser.bundleID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.config.defaultBrowserBundleID == browser.bundleID {
                                Text("Основной")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.15), in: Capsule())
                            } else {
                                Button("Сделать основным") {
                                    store.setDefaultBrowser(browser.bundleID)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
        }
        .navigationTitle("Браузеры")
        .toolbar {
            ToolbarItem {
                Button {
                    discovery.refresh()
                } label: {
                    Label("Обновить список", systemImage: "arrow.clockwise")
                }
                .keyboardShortcut("r", modifiers: .command)
                .help("Обновить список браузеров (⌘R)")
            }
        }
    }
}
