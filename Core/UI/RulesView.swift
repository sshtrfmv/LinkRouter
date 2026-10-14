import SwiftUI

struct RulesView: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var discovery: BrowserDiscovery

    @State private var searchText = ""
    @State private var editingRule: Rule?
    @State private var ruleToDelete: Rule?
    @State private var selectedRuleID: UUID?

    private var filteredRules: [Rule] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return store.config.rules }
        return store.config.rules.filter { rule in
            rule.pattern.localizedCaseInsensitiveContains(query)
                || browserName(for: rule).localizedCaseInsensitiveContains(query)
        }
    }

    /// Перетаскивание отключено, пока включён поиск: порядок отфильтрованного списка неоднозначен.
    private var moveAction: ((IndexSet, Int) -> Void)? {
        guard searchText.isEmpty else { return nil }
        return { source, destination in
            store.moveRules(from: source, to: destination)
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { ruleToDelete != nil },
            set: { if !$0 { ruleToDelete = nil } }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            DefaultBrowserBanner(alwaysShow: false)
            RouteTester()
            Divider()
            content
        }
        .navigationTitle("Правила")
        .searchable(text: $searchText, prompt: "Поиск правил")
        .toolbar {
            ToolbarItem {
                Button(action: startNewRule) {
                    Label("Добавить правило", systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("Добавить правило (⌘N)")
            }
        }
        .sheet(item: $editingRule) { rule in
            RuleEditor(rule: rule,
                       isNew: !store.config.rules.contains { $0.id == rule.id })
                .environmentObject(store)
                .environmentObject(discovery)
        }
        .confirmationDialog("Удалить правило?",
                            isPresented: deleteDialogBinding,
                            titleVisibility: .visible,
                            presenting: ruleToDelete) { rule in
            Button("Удалить", role: .destructive) {
                store.deleteRule(id: rule.id)
            }
            Button("Отмена", role: .cancel) {}
        } message: { rule in
            Text("Правило «\(rule.pattern)» будет удалено без возможности восстановления.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.config.rules.isEmpty {
            ContentUnavailableView {
                Label("Правил пока нет", systemImage: "arrow.triangle.branch")
            } description: {
                Text("Добавьте первое правило, например youtube.com → Google Chrome.")
            } actions: {
                Button("Добавить правило", action: startNewRule)
                    .buttonStyle(.borderedProminent)
            }
        } else if filteredRules.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            List(selection: $selectedRuleID) {
                ForEach(filteredRules) { rule in
                    RuleRow(rule: rule)
                        .tag(rule.id)
                        .onTapGesture(count: 2) { editingRule = rule }
                        .contextMenu {
                            Button("Изменить…") { editingRule = rule }
                            Button("Дублировать") { store.duplicateRule(id: rule.id) }
                            Divider()
                            Button("Удалить…", role: .destructive) { ruleToDelete = rule }
                        }
                }
                .onMove(perform: moveAction)
            }
            .onDeleteCommand {
                if let id = selectedRuleID,
                   let rule = store.config.rules.first(where: { $0.id == id }) {
                    ruleToDelete = rule
                }
            }
        }
    }

    private func startNewRule() {
        let browserID = store.config.defaultBrowserBundleID
            ?? discovery.browsers.first?.bundleID
            ?? ""
        editingRule = Rule(pattern: "", matchType: .domainWithSubdomains, browserBundleID: browserID)
    }

    private func browserName(for rule: Rule) -> String {
        discovery.browser(withBundleID: rule.browserBundleID)?.name ?? ""
    }
}

// MARK: - Строка правила

struct RuleRow: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var discovery: BrowserDiscovery

    let rule: Rule

    private var browser: Browser? {
        discovery.browser(withBundleID: rule.browserBundleID)
    }

    private var browserIcon: Image {
        if let browser {
            return Image(nsImage: discovery.icon(for: browser))
        }
        return Image(systemName: "questionmark.app")
    }

    var body: some View {
        HStack(spacing: 12) {
            browserIcon
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(rule.pattern)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(rule.matchType.title)
                    if rule.priority != 0 {
                        Text("приоритет \(rule.priority)")
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.08), in: Capsule())
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if let browser {
                Text(browser.name)
                    .foregroundStyle(.secondary)
            } else {
                Label("Браузер не найден", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Toggle("Включено", isOn: Binding(
                get: { rule.isEnabled },
                set: { store.setRuleEnabled(id: rule.id, $0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
        .padding(.vertical, 4)
        .opacity(rule.isEnabled ? 1 : 0.55)
        .contentShape(Rectangle())
    }
}
