import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var store: UsageStore
    @AppStorage(DisplayPreferenceKeys.showClaudeUsage) private var showClaudeUsage = true
    @AppStorage(DisplayPreferenceKeys.showCodexUsage) private var showCodexUsage = true
    @AppStorage(DisplayPreferenceKeys.showOfficialLimitWarnings) private var showOfficialLimitWarnings = true
    @AppStorage(DisplayPreferenceKeys.showCodexResetPrediction) private var showCodexResetPrediction = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var body: some View {
        Form {
            Section("刷新") {
                Picker("自动刷新间隔", selection: Binding(
                    get: { store.refreshMinutes },
                    set: { store.refreshMinutes = $0; store.scheduleTimer() }
                )) {
                    Text("1 分钟").tag(1)
                    Text("5 分钟").tag(5)
                    Text("10 分钟").tag(10)
                    Text("30 分钟").tag(30)
                }
                Button("立即刷新") { store.refresh() }
                    .disabled(store.isRefreshing)
            }

            Section("显示内容") {
                Toggle("显示 Claude Code 用量", isOn: $showClaudeUsage)
                Toggle("显示 Codex 用量", isOn: $showCodexUsage)
                Toggle("显示官方限额缺失提示", isOn: $showOfficialLimitWarnings)
                Toggle("Codex 全球重置预测", isOn: $showCodexResetPrediction)
            }

            Section("手机同步") {
                LabeledContent("同步服务") {
                    if store.serverRunning {
                        Label("运行中", systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundStyle(.green)
                    } else {
                        Label("未运行（端口 \(String(SnapshotServer.port)) 可能被占用）",
                              systemImage: "antenna.radiowaves.left.and.right.slash")
                            .foregroundStyle(.orange)
                    }
                }
                LabeledContent("手动连接地址", value: SnapshotServer.manualAddress)
            }

            Section("启动") {
                Toggle("登录时自动启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do {
                            if on {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            loginItemError = nil
                        } catch {
                            loginItemError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginItemError {
                    Text(loginItemError).font(.caption).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .tint(Palette.signal)
    }
}
