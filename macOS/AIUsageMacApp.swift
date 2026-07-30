import SwiftUI

@main
struct AIUsageMacApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "gauge.with.needle")
                Text(store.menuBarTitle)
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
    }
}
