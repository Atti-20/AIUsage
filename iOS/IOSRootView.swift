import SwiftUI

struct IOSRootView: View {
    @EnvironmentObject var store: IOSStore

    var body: some View {
        TabView {
            NavigationStack {
                Group {
                    if let snapshot = store.snapshot {
                        VStack(spacing: 0) {
                            if let error = store.syncError {
                                SyncBanner(text: error)
                            }
                            OverviewView(snapshot: snapshot)
                        }
                    } else {
                        EmptySyncView()
                    }
                }
                .navigationTitle("~/AIUsage")
                .navigationBarTitleDisplayMode(.inline)
                .refreshable { await store.refresh() }
            }
            .tabItem { Label("用量", systemImage: "terminal") }

            NavigationStack {
                ResetsView(events: store.resets)
                    .navigationTitle("重置动态")
                    .navigationBarTitleDisplayMode(.inline)
                    .refreshable { await store.refresh() }
            }
            .tabItem { Label("重置动态", systemImage: "arrow.counterclockwise.circle") }

            NavigationStack {
                SyncInfoView()
                    .navigationTitle("同步")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("同步", systemImage: "wifi") }
        }
        .tint(Palette.signal)
        .toolbarBackground(Palette.canvas, for: .tabBar)
    }
}

struct SyncBanner: View {
    var text: String

    var body: some View {
        Label(text, systemImage: "wifi.exclamationmark")
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(Palette.warning)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Palette.warning.opacity(0.08))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.warning.opacity(0.35)).frame(height: 1)
            }
    }
}

struct EmptySyncView: View {
    @EnvironmentObject var store: IOSStore

    var body: some View {
        ZStack {
            Palette.canvas.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                TerminalEyebrow(text: "waiting for desktop")
                Image(systemName: "wifi.router")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Palette.signal)
                Text(store.isRefreshing ? "正在寻找 Mac…" : "未连接到 Mac")
                    .font(.system(size: 25, weight: .bold, design: .monospaced))
                    .foregroundStyle(Palette.ink)
                Text(store.syncError ?? "在 Mac 上运行 AIUsage，并让 iPhone 与 Mac 连接同一 Wi-Fi。用量快照会自动同步，原始会话不会离开电脑。")
                    .font(.callout)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await store.refresh() }
                } label: {
                    Text(store.isRefreshing ? "SEARCHING…" : "> RETRY DISCOVERY")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Palette.signal)
                .foregroundStyle(Palette.canvas)
                .disabled(store.isRefreshing)
            }
            .padding(24)
            .frame(maxWidth: 460)
        }
    }
}

struct SyncInfoView: View {
    @EnvironmentObject var store: IOSStore
    @State private var addressDraft: String = ""

    var body: some View {
        List {
            Section("同步状态") {
                LabeledContent("数据快照") {
                    if let s = store.snapshot {
                        Text("来自 \(s.deviceName)")
                    } else {
                        Text("暂无").foregroundStyle(.secondary)
                    }
                }
                if let s = store.snapshot {
                    LabeledContent("生成时间", value: Fmt.dateTime(s.generatedAt))
                }
                if let at = store.lastSyncAt {
                    LabeledContent("上次同步", value: Fmt.dateTime(at))
                }
                if let error = store.syncError {
                    Text(error).font(.footnote).foregroundStyle(.orange)
                }
                Button(store.isRefreshing ? "同步中…" : "立即同步") {
                    Task { await store.refresh() }
                }
                .disabled(store.isRefreshing)
            }

            Section("手动地址（自动发现失败时）") {
                TextField("如 my-mac.local:48764", text: $addressDraft)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .onSubmit { saveAddress() }
                HStack {
                    Button("保存并连接") { saveAddress() }
                    if !store.manualAddress.isEmpty {
                        Spacer()
                        Button("清除，改用自动发现", role: .destructive) {
                            store.manualAddress = ""
                            addressDraft = ""
                            Task { await store.refresh() }
                        }
                    }
                }
                Text("地址显示在 Mac 端「设置 → iPhone 同步」里。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("说明") {
                Text("用量数据由 Mac 端解析本地 Claude Code 与 Codex 日志后经局域网同步，离线时显示上次缓存；重置动态来自 codex-resets.com，可独立在线刷新。")
                    .font(.footnote)
                Text("添加桌面小组件：长按主屏幕 → 添加小组件 → AI 用量。")
                    .font(.footnote)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .tint(Palette.signal)
        .onAppear { addressDraft = store.manualAddress }
    }

    private func saveAddress() {
        store.manualAddress = addressDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { await store.refresh() }
    }
}
