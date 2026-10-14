import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var discovery: BrowserDiscovery

    @State private var searchText = ""
    @State private var confirmClear = false

    private var filteredEntries: [HistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return history.entries }
        return history.entries.filter {
            $0.host.localizedCaseInsensitiveContains(query)
                || $0.browserName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Group {
            if history.entries.isEmpty {
                ContentUnavailableView {
                    Label("История пуста", systemImage: "clock")
                } description: {
                    Text(store.config.settings.historyEnabled
                         ? "Здесь появятся ссылки, которые обработало приложение."
                         : "Запись истории выключена в настройках.")
                }
            } else if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredEntries) { entry in
                    row(for: entry)
                }
            }
        }
        .navigationTitle("История")
        .searchable(text: $searchText, prompt: "Поиск по истории")
        .toolbar {
            ToolbarItem {
                Button {
                    confirmClear = true
                } label: {
                    Label("Очистить историю", systemImage: "trash")
                }
                .disabled(history.entries.isEmpty)
            }
        }
        .confirmationDialog("Очистить историю?",
                            isPresented: $confirmClear,
                            titleVisibility: .visible) {
            Button("Очистить", role: .destructive) { history.clear() }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Все записи будут удалены.")
        }
    }

    private func row(for entry: HistoryEntry) -> some View {
        HStack(spacing: 12) {
            icon(for: entry)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.host).font(.headline)
                Text(subtitle(for: entry))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
    }

    private func icon(for entry: HistoryEntry) -> Image {
        if let browser = discovery.browser(withBundleID: entry.browserBundleID) {
            return Image(nsImage: discovery.icon(for: browser))
        }
        return Image(systemName: "globe")
    }

    private func subtitle(for entry: HistoryEntry) -> String {
        if let pattern = entry.rulePattern {
            return entry.usedFallback
                ? "Правило «\(pattern)», браузер не найден → \(entry.browserName)"
                : "Правило «\(pattern)» → \(entry.browserName)"
        }
        return "Без правила → \(entry.browserName)"
    }
}
