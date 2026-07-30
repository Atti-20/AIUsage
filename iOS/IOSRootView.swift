import SwiftUI
import WidgetKit

struct IOSRootView: View {
    @EnvironmentObject var store: IOSStore
    @AppStorage(
        DisplayPreferenceKeys.showClaudeUsage,
        store: UserDefaults(suiteName: SyncStore.appGroupID)
    ) private var showClaudeUsage = true
    @AppStorage(
        DisplayPreferenceKeys.showCodexUsage,
        store: UserDefaults(suiteName: SyncStore.appGroupID)
    ) private var showCodexUsage = true
    @AppStorage(
        DisplayPreferenceKeys.showOfficialLimitWarnings,
        store: UserDefaults(suiteName: SyncStore.appGroupID)
    ) private var showOfficialLimitWarnings = true
    @AppStorage(
        DisplayPreferenceKeys.showCodexResetPrediction,
        store: UserDefaults(suiteName: SyncStore.appGroupID)
    ) private var showCodexResetPrediction = true

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    if let snapshot = store.snapshot {
                        VStack(spacing: 0) {
                            if let error = store.syncError {
                                SyncBanner(text: error)
                            }
                            OverviewView(
                                snapshot: snapshot,
                                showClaudeUsage: showClaudeUsage,
                                showCodexUsage: showCodexUsage,
                                showOfficialLimitWarnings: showOfficialLimitWarnings,
                                showCodexResetPrediction: showCodexResetPrediction,
                                dismissOfficialLimitWarnings: {
                                    showOfficialLimitWarnings = false
                                }
                            )
                        }
                    } else {
                        EmptySyncView()
                    }
                }
                .navigationTitle("AI 用量")
                .refreshable { await store.refresh() }
            }
            .tabItem { Label("用量", systemImage: "gauge.with.dots.needle.67percent") }

            NavigationStack {
                SettingsView()
                    .navigationTitle("设置")
            }
            .tabItem { Label("设置", systemImage: "gearshape") }
        }
        .tint(Palette.signal)
        .toolbarBackground(Palette.canvas, for: .tabBar)
    }
}

private struct SyncBanner: View {
    var text: String

    var body: some View {
        Label(text, systemImage: "wifi.exclamationmark")
            .font(.caption)
            .foregroundStyle(Palette.warning)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Palette.warning.opacity(0.08))
    }
}

private struct EmptySyncView: View {
    @EnvironmentObject var store: IOSStore

    var body: some View {
        ContentUnavailableView {
            Label("未连接到电脑", systemImage: "wifi")
        } description: {
            if let error = store.syncError {
                Text(error)
            }
        } actions: {
            Button(store.isRefreshing ? "正在连接…" : "重新连接") {
                Task { await store.refresh() }
            }
            .disabled(store.isRefreshing)
        }
        .background(Palette.canvas)
    }
}

private struct SettingsView: View {
    @EnvironmentObject var store: IOSStore
    @AppStorage(
        DisplayPreferenceKeys.showClaudeUsage,
        store: UserDefaults(suiteName: SyncStore.appGroupID)
    ) private var showClaudeUsage = true
    @AppStorage(
        DisplayPreferenceKeys.showCodexUsage,
        store: UserDefaults(suiteName: SyncStore.appGroupID)
    ) private var showCodexUsage = true
    @AppStorage(
        DisplayPreferenceKeys.showOfficialLimitWarnings,
        store: UserDefaults(suiteName: SyncStore.appGroupID)
    ) private var showOfficialLimitWarnings = true
    @AppStorage(
        DisplayPreferenceKeys.showCodexResetPrediction,
        store: UserDefaults(suiteName: SyncStore.appGroupID)
    ) private var showCodexResetPrediction = true
    @State private var addressDraft = ""

    var body: some View {
        List {
            Section("显示") {
                Toggle("Claude Code", isOn: $showClaudeUsage)
                Toggle("Codex", isOn: $showCodexUsage)
                Toggle("限额读取提示", isOn: $showOfficialLimitWarnings)
                Toggle("Codex 全球重置预测", isOn: $showCodexResetPrediction)
            }

            Section("连接") {
                if let snapshot = store.snapshot {
                    LabeledContent("数据来源", value: snapshot.deviceName)
                }
                TextField("电脑地址，例如 192.168.1.10:48764", text: $addressDraft)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .onSubmit { saveAddress() }
                Button("保存并连接") { saveAddress() }
                if !store.manualAddress.isEmpty {
                    Button("使用自动发现") {
                        store.manualAddress = ""
                        addressDraft = ""
                        Task { await store.refresh() }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .tint(Palette.signal)
        .onAppear { addressDraft = store.manualAddress }
        .onChange(of: showClaudeUsage) { _, _ in reloadWidgets() }
        .onChange(of: showCodexUsage) { _, _ in reloadWidgets() }
    }

    private func saveAddress() {
        store.manualAddress = addressDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await store.refresh() }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
