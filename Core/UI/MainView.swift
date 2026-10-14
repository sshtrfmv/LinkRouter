import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case rules, browsers, history, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rules: return String(localized: "Правила")
        case .browsers: return String(localized: "Браузеры")
        case .history: return String(localized: "История")
        case .settings: return String(localized: "Настройки")
        }
    }

    var systemImage: String {
        switch self {
        case .rules: return "arrow.triangle.branch"
        case .browsers: return "safari"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct MainView: View {
    @State private var selection: SidebarItem? = .rules

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 240)
        } detail: {
            switch selection ?? .rules {
            case .rules: RulesView()
            case .browsers: BrowsersView()
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
        .frame(minWidth: 820, minHeight: 520)
    }
}
