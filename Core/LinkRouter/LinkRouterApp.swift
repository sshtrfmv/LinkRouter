import SwiftUI

@main
struct LinkRouterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    var body: some Scene {
        let env = AppEnvironment.shared

        Window("Link Router", id: "main") {
            MainView()
                .withAppEnvironment(env)
        }
        .defaultSize(width: 900, height: 620)

        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarContent()
                .withAppEnvironment(env)
        } label: {
            MenuBarLabel(store: env.store)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .withAppEnvironment(env)
                .frame(width: 520, height: 600)
        }
    }
}
