import SwiftUI

@main
struct AIUsageMacApp: App {
    @StateObject private var store = UsageStore()
    @AppStorage(DisplayPreferenceKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(DisplayPreferenceKeys.showCodexUsage) private var showCodexUsage = true

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.needle")
                Text(store.menuBarTitle(
                    showClaude: showClaudeUsage,
                    showCodex: showCodexUsage
                ))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .task { store.startIfNeeded() }
        }
        .menuBarExtraStyle(.window)

        Window("AI 用量", id: "main") {
            MainWindow()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 760, minHeight: 520)
        }
        .defaultSize(width: 900, height: 640)

        Settings {
            SettingsView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 520, minHeight: 460)
        }
    }
}
