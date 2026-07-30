# AI 用量（AIUsage）

跨平台查看 **Claude Code 与 Codex** 的用量、成本与官方限额，并集成 [codex-reset.com](https://codex-reset.com/) 的全球重置预测。

| 平台 | 形态 | 技术 | 数据来源 |
|---|---|---|---|
| macOS 14+ | 菜单栏常驻 + 统计主窗口 | SwiftUI | 本地解析 + 局域网服务端 |
| iOS 17+ | App + 主屏幕/锁屏小组件 | SwiftUI + WidgetKit | 局域网同步 |
| Windows 10+ | 桌面窗口应用 | Flutter | 本地解析 + 局域网服务端 |
| Android 8+ | App + 主屏幕小组件 | Flutter + AppWidget | 局域网同步 |

**不需要付费开发者账号**：iPhone 同步走局域网（Bonjour/UDP 自动发现），免费 Apple ID 即可真机安装。

## 功能

- **官方限额（与 ChatGPT / Claude 应用内显示一致）**
  - Codex：会话日志内记录的 `rate_limits` 官方快照（used_percent / resets_at / 套餐）。
  - Claude：Claude Code 的 OAuth 凭据调用 `api.anthropic.com/api/oauth/usage`（macOS 读钥匙串，Windows 读 `~/.claude/.credentials.json`）。
- **用量统计**：解析 `~/.claude/projects/**/*.jsonl` 与 `~/.codex/sessions/**/*.jsonl`，按天 / 模型 / 项目 / 会话汇总 token 与成本（LiteLLM 在线价格表 + 内置兜底价，缓存 24 小时）。
- **官方窗口**：Codex 的 5 小时窗口与周度窗口并行展示；两者独立恢复，不互相替代。
- **全球重置预测**：codex-reset.com 的 `/api/forecast`，显示未来 24/48 小时预测，可在设置中关闭。
- **双风格小组件**：iOS 提供 App 风格与 iOS 26 液态玻璃风格并支持锁屏；Android 提供 App 风格与 Material You 系统风格。
- **局域网同步**：桌面端（Mac/Windows）内置只读快照服务（HTTP 48764；Bonjour `_aiusage._tcp` + UDP 48765 发现应答），手机端自动发现拉取，离线显示上次缓存。原始会话内容不出本机，同步的只有汇总数。

## 下载安装

到 [Releases](../../releases) 下载：

- `AIUsage-macOS.dmg` / `.zip` — 未签名，首次打开需右键 →「打开」，或运行 `xattr -cr /Applications/AIUsage.app`
- `AIUsage-Windows-Setup.exe` — 安装版；`AIUsage-Windows-portable.zip` — 免安装版
- `AIUsage-Android.apk` — 直接安装（允许未知来源）
- `AIUsage-iOS-unsigned.ipa` — 未签名，需 AltStore / Sideloadly 等自签安装；或用 Xcode 免费账号自行构建（见下）

## 从源码构建

### macOS / iOS（Swift）

依赖 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：

```bash
brew install xcodegen
xcodegen generate
open AIUsage.xcodeproj
```

- 跑 Mac 端：scheme `AIUsage` → My Mac，⌘R。首次会弹两个系统询问：钥匙串读取 Claude 凭据（选「始终允许」）、防火墙监听（选「允许」）。
- 跑 iPhone 端：Xcode → Settings → Accounts 登录普通 Apple ID，`AIUsageiOS` 的 Signing 选 Personal Team，选真机/模拟器 ⌘R。免费签名 7 天有效，过期重跑一次。
- Bundle ID 前缀 `com.zhange` 与 App Group `group.com.zhange.aiusage` 可在 `project.yml` 中改，改完重新 `xcodegen generate`。

### Windows / Android（Flutter）

```bash
cd flutter
flutter build windows --release   # 在 Windows 上执行
flutter build apk --release
```

Android 使用仓库内的自签名 keystore（`flutter/android/app/upload-keystore.jks`，个人分发用途）。

## Release 自动构建

打 tag 即触发 GitHub Actions 构建全部平台安装包并发布 Release：

```bash
git tag v1.0.0 && git push origin v1.0.0
```

## 已知说明

- 成本为**按 API 定价的估算值**，订阅套餐（Pro/Max/Plus）实际不按此计费，仅用于衡量用量规模。
- Claude 官方限额需要本机有 Claude Code 的登录凭据；只装了 Claude Desktop 时其余功能不受影响。
- 手机端自动发现失败时，在「设置」页手动填桌面端地址（Mac 显示在设置页，如 `my-mac.local:48764`；Windows 用局域网 IP）。
- codex-reset.com 的全球重置概率是社区预测，不替代 Codex 官方提供的个人 5 小时与周度倒计时。
