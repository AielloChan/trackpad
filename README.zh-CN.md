# Trackpad

[English](README.md) | [Français](README.fr.md)

Trackpad 是一个 Apple 平台原生项目，目标是让 iPhone 或 iPad 作为 macOS 的触控板使用。本仓库计划托管在：

```text
git@github.com:AielloChan/trackpad.git
```

当前里程碑是局域网 MVP。iOS app 提供黑色全屏触控面板，采集多点触控输入，将其归一化为平台无关事件，并发送给 macOS host app。macOS host 通过 Bonjour 广播服务，接收已配对客户端连接，将输入事件映射为 macOS 输入命令，并通过系统 API 注入光标、点击、拖拽和滚动事件。

## 当前状态

阶段一已经达到可用于局域网测试的功能水平：

- iOS/iPadOS 黑屏触控面板。
- Bonjour 自动发现，保留手动 IP 连接。
- 处理输入事件前需要六位配对码。
- 单指移动光标。
- 单指轻点左键点击。
- 轻点、快速二次按下并移动触发拖拽。
- 双指轻点右键点击。
- 双指滚动，不再由客户端生成惯性滚动。
- 右侧边缘向内滑动，并且抬起前出现过双指触点时，打开 macOS 通知中心；随后双指右扫可关闭通知中心。
- 三指上/下/左/右滑动触发 Mission Control、App Expose 和 Spaces 切换。
- 客户端展示延迟、触控采样率和发送事件率。
- 连接状态栏提供光标速度、滚动惯性和手势时序滑块。
- macOS host 支持移动、点击、拖拽、滚动 phase、momentum phase 和双击 click state 注入。
- macOS host 持久化日志写入 `~/Library/Logs/Trackpad/host.log`。

后续目标是继续把手感尽可能对齐 Apple 官方触控板体验。阶段一仍有一些人工验证项记录在 `TODOS.md` 中，尤其是真机手势调校以及安全区域内的点击、滚动验证。

## 仓库结构

```text
apps/
  ios/
    TrackpadIOS/          iOS/iPadOS app target。
    TrackpadIOSCore/      可复用 iOS 手势和客户端逻辑。
  macos/
    TrackpadHost/         macOS host Swift package 和 CLI。
    TrackpadHostApp/      原生 macOS host app。

packages/
  TrackpadKit/            共享协议、transport、安全和平台无关模型。

protocol/
  v1/                     协议文档。

docs/
  architecture.md         系统架构。
  decisions/              架构决策记录。
  ios-client-mvp.md       iOS MVP 说明和验证记录。
  macos-host-mvp.md       macOS host 说明和验证记录。

plans/
  *.md                    带进度追踪的实施计划。

TODOS.md                  当前项目进度追踪。
AGENTS.md                 本仓库 AI coding agent 工作要求。
```

## 架构

Trackpad 是一个双端控制系统：

```text
iPhone / iPad
  -> 采集触控
  -> 归一化手势
  -> 发送 TrackpadProtocol 输入事件

macOS host
  -> 接收 session frame
  -> 校验配对
  -> 将事件映射为 macOS 输入命令
  -> 注入 CGEvent 输入
```

共享协议是客户端和 host 之间的边界。iOS 触摸细节不应泄漏到 macOS 输入注入层，macOS 注入细节也不应泄漏到 iOS 手势归一化逻辑中。

Transport 需要保持抽象。MVP 使用 Bonjour 和局域网 TCP 直连。后续可以加入类似 WebRTC 的 NAT 穿透、relay fallback、Android 客户端和 Windows host，而不破坏核心输入事件模型。

## 环境要求

- 安装 Xcode 的 macOS。
- Xcode 提供的 Swift 工具链。
- 用于客户端的 iPhone/iPad 或 iOS Simulator。
- 输入注入前，需要给正在运行的 macOS host app 或 host CLI 授予辅助功能权限。

## 构建和运行

### macOS Host App

打开并运行：

```text
apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj
```

使用 `TrackpadHostApp` scheme。app 会展示当前配对码、服务状态、端口、连接数和辅助功能权限状态。

命令行构建：

```bash
xcodebuild -project apps/macos/TrackpadHostApp/TrackpadHostApp.xcodeproj -scheme TrackpadHostApp -configuration Debug build
```

### macOS Host CLI

```bash
cd apps/macos/TrackpadHost
swift run TrackpadHost status
swift run TrackpadHost request-permission
swift run TrackpadHost log-path
swift run TrackpadHost serve 123456
```

本地调试输入动作：

```bash
swift run TrackpadHost move-test
swift run TrackpadHost left-click-test
swift run TrackpadHost right-click-test
swift run TrackpadHost scroll-test
```

点击和滚动调试动作只应在安全的空白 UI 区域执行。

### iOS Client

打开并运行：

```text
apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj
```

使用 `TrackpadIOS` scheme，可以运行在模拟器或真机上。真实手感测试需要 iPhone 或 iPad 真机。

命令行模拟器构建示例：

```bash
xcodebuild -project apps/ios/TrackpadIOS/TrackpadIOS.xcodeproj -scheme TrackpadIOS -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## 测试

运行共享包测试：

```bash
cd packages/TrackpadKit
swift test
```

运行 macOS host 测试：

```bash
cd apps/macos/TrackpadHost
swift test
```

运行 iOS core 测试：

```bash
cd apps/ios/TrackpadIOSCore
swift test
```

## Roadmap

近期工作：

- 继续用真机对照 Apple 触控板行为调校手势。
- 输入事件模型稳定后，将 JSON Lines 替换为更紧凑的二进制帧格式。
- 持久化可信设备并改进配对体验。
- 增加加密会话。

长期工作：

- 通过 signaling、NAT 穿透和 relay fallback 支持远程连接。
- Android 客户端。
- Windows host。
- 跨平台协议 schema 生成。

## 开发流程

`TODOS.md` 是当前进度源。`plans/*.md` 是具体任务的实施来源。重要架构决策应记录到 `docs/decisions/`。

贡献者和 coding agent 修改代码前应先阅读 `AGENTS.md`。本项目偏好小而清晰的文件、可复用的平台无关逻辑，以及覆盖协议编码、手势状态机、事件映射和 transport 行为的测试。

## 许可证

Trackpad 使用 Apache License, Version 2.0 授权。详见 [LICENSE](LICENSE)。
