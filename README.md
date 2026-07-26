# AI 用量（AIUsage）

Mac 菜单栏 + iOS App/小组件，查看 Claude Code 与 Codex 的用量、成本与官方限额，并集成 [codex-resets.com](https://codex-resets.com/) 的限额重置动态。**不需要付费开发者账号**：iPhone 同步走局域网（Bonjour 自动发现），免费 Apple ID 即可真机安装。

## 功能

- **Mac 菜单栏常驻**：今日成本 + 关键限额环一眼可见；主窗口含总览 / Claude / Codex / 重置动态 / 设置五个页面。
- **官方限额**（与 App 内显示一致）：
  - Claude：读取钥匙串中 Claude Code 的 OAuth 令牌，调用 `api.anthropic.com/api/oauth/usage` 获取 5 小时窗口与周限额进度（首次会弹出钥匙串授权，选"始终允许"）。
  - Codex：直接取会话日志内记录的 `rate_limits` 官方快照（used_percent / resets_at / 套餐）。
- **用量统计**：解析 `~/.claude/projects/**/*.jsonl` 与 `~/.codex/sessions/**/*.jsonl`，按天 / 模型 / 项目 / 会话汇总 token 与成本（LiteLLM 在线价格表 + 内置兜底价，缓存 24 小时）。
- **重置动态**：codex-resets.com 的 `/api/resets`（重置总数、平均间隔、最长等待、公告列表）。
- **局域网同步**：Mac 端内置只读快照服务（端口 48764，Bonjour `_aiusage._tcp`），iPhone 同一 Wi-Fi 下自动发现拉取，离线显示上次缓存；iOS 桌面小组件（小 / 中）显示限额环与今日成本。

## 构建

依赖 [xcodegen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）：

```bash
cd AIUsage
xcodegen generate
open AIUsage.xcodeproj
```

三个 target：

| Target | 平台 | 说明 |
|---|---|---|
| `AIUsage` | macOS 14+ | 菜单栏 App（LSUIElement，不占 Dock） |
| `AIUsageiOS` | iOS 17+ | iPhone/iPad App |
| `AIUsageWidget` | iOS 17+ | 桌面小组件扩展 |

## 首次运行前（免费 Apple ID 即可）

1. **签名**：Xcode → Settings → Accounts 登录你的普通 Apple ID，各 target 的 Signing & Capabilities 里选择自动生成的 Personal Team。
2. **Mac 端**：直接 Run 即可（菜单栏出现仪表图标）。首次会有两个系统弹窗：钥匙串读取 Claude 登录凭据（选「始终允许」）、防火墙是否允许监听（选「允许」，否则 iPhone 连不上）。
3. **iOS 端**：真机安装需在 iPhone 的 设置 → 通用 → VPN 与设备管理 里信任你的开发者证书；免费账号签名 **7 天过期**，过期后重新 Run 一次即可。用模拟器则无任何限制。
4. **App Group**：iOS App 与小组件共用 `group.com.zhange.aiusage`（免费账号支持）；如冲突可全局替换为自己的 group ID。
5. Bundle ID 前缀 `com.zhange` 可在 `project.yml` 中改成自己的，改完重新 `xcodegen generate`。

## 已知说明

- 成本为**按 API 定价的估算值**，订阅套餐（Pro/Max/Plus）实际不按此计费，仅用于衡量用量规模。
- Claude 官方限额需要本机装有已登录的 Claude Code；令牌过期时在终端跑一次 `claude` 即可刷新。
- 所有解析都在本机完成，原始会话内容不出 Mac；局域网同步的只有汇总数（每日成本、项目/会话名称与金额、限额百分比），服务只读、仅监听局域网。
- iPhone 自动发现失败时，在 iOS「同步」页手动填 Mac 端设置页显示的地址（如 `my-mac.local:48764`）。
- codex-resets.com 为非官方数据源（监测 OpenAI 产品负责人 @thsottiaux 的推文）。
