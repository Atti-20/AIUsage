import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var store: UsageStore
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

            Section("iPhone 同步（局域网）") {
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
                Text("iPhone 与 Mac 连同一 Wi-Fi，打开 iOS 端会自动发现本机；找不到时在 iPhone 的「同步」页填上面的地址。若 macOS 弹出防火墙询问，请选择「允许」。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Section("数据来源") {
                LabeledContent("Claude 用量", value: "~/.claude/projects/**/*.jsonl")
                LabeledContent("Codex 用量", value: "~/.codex/sessions/**/*.jsonl")
                LabeledContent("Claude 官方限额", value: "钥匙串 OAuth → api.anthropic.com")
                LabeledContent("Codex 官方限额", value: "会话日志内 rate_limits 快照")
                LabeledContent("重置动态", value: "codex-resets.com（非官方）")
                Text("成本按各模型 API 定价估算（在线同步 LiteLLM 价格表，缓存 24 小时），订阅套餐实际不另收费，仅供衡量用量规模。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
