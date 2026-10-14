import SwiftUI

// MARK: - Проверка ссылки

struct RouteTester: View {
    @EnvironmentObject private var store: ConfigStore
    @EnvironmentObject private var discovery: BrowserDiscovery
    @EnvironmentObject private var router: URLRouter

    @State private var text = ""

    private var url: URL? { URLInput.parse(text) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundStyle(.secondary)
                TextField("Вставьте ссылку, чтобы проверить, куда она откроется", text: $text)
                    .textFieldStyle(.plain)
                    .onSubmit(openCurrent)
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Button("Открыть", action: openCurrent)
                    .disabled(url == nil)
            }
            .padding(10)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

            if !text.isEmpty {
                resultView
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var resultView: some View {
        if let url {
            let decision = router.decide(url)
            HStack(spacing: 10) {
                if let browser = decision.browser {
                    Image(nsImage: discovery.icon(for: browser))
                        .resizable()
                        .frame(width: 22, height: 22)
                }
                Text(decision.explanation)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 4)
        } else {
            Label("Введите корректную ссылку http или https.", systemImage: "exclamationmark.circle")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func openCurrent() {
        guard let url else { return }
        Task { await router.handle(url) }
    }
}

// MARK: - Баннер «браузер по умолчанию»

struct DefaultBrowserBanner: View {
    /// true — показывать всегда (страница «Браузеры»); false — только если не назначен.
    let alwaysShow: Bool

    @StateObject private var monitor = SystemDefaultMonitor()

    var body: some View {
        Group {
            if monitor.isDefault {
                if alwaysShow {
                    banner(icon: "checkmark.circle.fill",
                           color: .green,
                           title: "Link Router — браузер по умолчанию",
                           detail: "Ссылки из других приложений приходят сюда и распределяются по правилам.",
                           showButton: false)
                }
            } else {
                banner(icon: "exclamationmark.triangle.fill",
                       color: .orange,
                       title: "Link Router не назначен браузером по умолчанию",
                       detail: "Пока это не сделано, ссылки из других приложений не проходят через правила.",
                       showButton: true)
            }
        }
        .onAppear { monitor.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            monitor.refresh()
        }
    }

    private func banner(icon: String, color: Color, title: String, detail: String, showButton: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let error = monitor.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            if showButton {
                Button("Назначить") {
                    Task { await monitor.makeDefault() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}
