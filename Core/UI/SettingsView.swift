import SwiftUI
import AppKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var history: HistoryStore

    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    @State private var launchAtLogin = false
    @State private var needsApproval = false
    @State private var loginMessage: String?
    @State private var confirmClear = false

    // MARK: - Привязки

    private var pausedBinding: Binding<Bool> {
        Binding(get: { store.config.rulesPaused },
                set: { store.setRulesPaused($0) })
    }

    private var hideDockBinding: Binding<Bool> {
        Binding(get: { store.config.settings.hideDockWhenClosed },
                set: { newValue in store.updateSettings { $0.hideDockWhenClosed = newValue } })
    }

    private var historyEnabledBinding: Binding<Bool> {
        Binding(get: { store.config.settings.historyEnabled },
                set: { newValue in store.updateSettings { $0.historyEnabled = newValue } })
    }

    private var historyLimitBinding: Binding<Int> {
        Binding(get: { store.config.settings.historyLimit },
                set: { newValue in store.updateSettings { $0.historyLimit = newValue } })
    }

    private var launchBinding: Binding<Bool> {
        Binding(get: { launchAtLogin },
                set: { setLaunchAtLogin($0) })
    }

    // MARK: - Интерфейс

    var body: some View {
        Form {
            Section("Правила") {
                Toggle("Приостановить все правила", isOn: pausedBinding)
                Text("Пока включена пауза, все ссылки открываются в браузере по умолчанию.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Запуск") {
                Toggle("Запускать при входе в систему", isOn: launchBinding)
                if needsApproval {
                    Text("Подтвердите в Системных настройках → Основные → Объекты входа.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let loginMessage {
                    Text(loginMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Отображение") {
                Toggle("Показывать в строке меню", isOn: $showMenuBarIcon)
                Toggle("Убирать из Dock, когда окно закрыто", isOn: hideDockBinding)
                    .disabled(!showMenuBarIcon)
                Text("Приложение продолжит работать в строке меню. Вернуть иконку в Dock можно пунктом «Открыть Link Router» в этом меню. Если значок в строке меню выключен, иконка остаётся в Dock.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("История") {
                Toggle("Вести историю", isOn: historyEnabledBinding)
                Stepper("Хранить записей: \(store.config.settings.historyLimit)",
                        value: historyLimitBinding, in: 50...1000, step: 50)
                    .disabled(!store.config.settings.historyEnabled)
                Text("Сохраняется только домен ссылки, без пути и параметров.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Очистить историю…", role: .destructive) {
                    confirmClear = true
                }
                .disabled(history.entries.isEmpty)
            }

            Section("Данные") {
                Button("Показать файл настроек в Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([ConfigStore.defaultFileURL])
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Настройки")
        .onAppear(perform: refreshLoginState)
        .onChange(of: showMenuBarIcon) { _, _ in
            NotificationCenter.default.post(name: .activationPolicyNeedsUpdate, object: nil)
        }
        .onChange(of: store.config.settings.historyLimit) { _, newValue in
            history.trim(to: newValue)
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

    private func refreshLoginState() {
        let status = SMAppService.mainApp.status
        launchAtLogin = (status == .enabled)
        needsApproval = (status == .requiresApproval)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginMessage = nil
        } catch {
            loginMessage = "Не удалось изменить автозапуск: \(error.localizedDescription). Попробуйте из приложения, лежащего в папке «Программы»."
        }
        refreshLoginState()
    }
}
