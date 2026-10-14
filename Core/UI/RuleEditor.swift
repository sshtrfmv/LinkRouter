import SwiftUI

extension MatchType {
    var placeholder: String {
        switch self {
        case .exactDomain: return "youtube.com"
        case .domainWithSubdomains: return "google.com"
        case .urlMask: return "https://example.com/work/*"
        case .regex: return "^https://github\\.com/.+/pull/\\d+"
        }
    }

    var hint: String {
        switch self {
        case .exactDomain:
            return "Только этот домен, без поддоменов: youtube.com не совпадёт с www.youtube.com."
        case .domainWithSubdomains:
            return "Сам домен и все его поддомены. Запись *.google.com тоже подойдёт."
        case .urlMask:
            return "Знак * заменяет любой текст. Если схема не указана, подходят http и https."
        case .regex:
            return "Регулярное выражение, которое ищется в любом месте ссылки. Регистр не важен."
        }
    }
}

struct RuleEditor: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var discovery: BrowserDiscovery
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Rule
    @State private var testText = ""
    @State private var errorText: String?

    private let isNew: Bool

    init(rule: Rule, isNew: Bool) {
        _draft = State(initialValue: rule)
        self.isNew = isNew
    }

    private var browserIsMissing: Bool {
        !draft.browserBundleID.isEmpty
            && discovery.browser(withBundleID: draft.browserBundleID) == nil
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Picker("Тип совпадения", selection: $draft.matchType) {
                        ForEach(MatchType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    TextField("Шаблон", text: $draft.pattern,
                              prompt: Text(draft.matchType.placeholder))
                    Text(draft.matchType.hint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Picker("Браузер", selection: $draft.browserBundleID) {
                        ForEach(discovery.browsers) { browser in
                            Text(browser.name).tag(browser.bundleID)
                        }
                        if browserIsMissing {
                            Text("\(draft.browserBundleID) (не установлен)")
                                .tag(draft.browserBundleID)
                        }
                    }
                    Stepper("Приоритет: \(draft.priority)", value: $draft.priority, in: -100...100)
                    Text("При совпадении нескольких правил побеждает то, у которого приоритет больше.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Правило включено", isOn: $draft.isEnabled)
                }

                Section("Проверка") {
                    TextField("Ссылка для проверки", text: $testText,
                              prompt: Text("https://www.youtube.com/watch?v=…"))
                    testResult
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                if let errorText {
                    Text(errorText)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Добавить" : "Сохранить", action: save)
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
            .padding(16)
        }
        .frame(width: 500)
        .onAppear {
            if draft.browserBundleID.isEmpty {
                draft.browserBundleID = discovery.browsers.first?.bundleID ?? ""
            }
        }
    }

    @ViewBuilder
    private var testResult: some View {
        if !testText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let url = URLInput.parse(testText) {
                if draft.matches(url) {
                    Label("Совпадает", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Не совпадает", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Введите корректную ссылку http или https.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        do {
            if isNew {
                try store.addRule(draft)
            } else {
                try store.updateRule(draft)
            }
            dismiss()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
