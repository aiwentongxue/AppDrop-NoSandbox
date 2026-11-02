# AppDrop

<p>
  <a href="README.md">简体中文</a> | <a href="README_EN.md">English</a>
</p>

> 面向 macOS 用户的 App Store 价格追踪工具。追踪多商店区域的应用价格，查看历史走势与历史新低，并在降价时通过系统通知提醒你。

本仓库是 **AppDrop No Sandbox** 独立版本：无 App Sandbox、无 App Group、无需「完全磁盘访问权限」，数据直接保存在当前用户的 Application Support 目录。

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-blue)
![Swift](https://img.shields.io/badge/swift-6-orange)
![License](https://img.shields.io/badge/license-GPL--3.0-blue)

## 功能特性

- 🔍 **多区域追踪**：支持 17 个商店区域，每个追踪项目独立对应一个区域
- 📈 **价格历史**：阶梯折线图支持3个月、6个月、12个月与全部历史，鼠标悬停查看精确价格，并统计所选范围内的连续史低次数（Swift Charts）
- 🏷️ **历史新低**：自动识别并标记历史最低价
- 🔔 **本地通知**：降价时发送系统通知（主 App 与后台 Helper 各自独立请求权限）
- 🔄 **后台自动检查**：通过 SMAppService + launchd 按天调度，执行后退出，不常驻内存
- 📋 **Wishdrop 心愿单**：通过 `.wishdrop` 文件格式导入和导出追踪列表（仓库附带预设文件 [`MacAppStore付费游戏.wishdrop`](MacAppStore付费游戏.wishdrop) 供有需要的用户手动下载导入 85 款 Mac 纯付费买断游戏）
- 🔗 **两种添加方式**：粘贴 App Store 链接 或 关键词搜索（支持 Mac / iPhone·iPad 两个目录）

## 支持的区域

「搜索添加」「更换区域」「设置默认区域」三处共用同一份区域列表，共 17 个商店区域：

| 代码 | 区域 | 货币 | 代码 | 区域 | 货币 |
|------|------|------|------|------|------|
| US | 美国 | USD | GB | 英国 | GBP |
| CN | 中国大陆 | CNY | DE | 德国 | EUR |
| HK | 中国香港 | HKD | CA | 加拿大 | CAD |
| TW | 中国台湾 | TWD | AU | 澳大利亚 | AUD |
| JP | 日本 | JPY | FR | 法国 | EUR |
| KR | 韩国 | KRW | SG | 新加坡 | SGD |
| TR | 土耳其 | TRY | NG | 尼日利亚 | NGN |
| AR | 阿根廷 | ARS | BR | 巴西 | BRL |
| IN | 印度 | INR | | | |

## 截图

![主界面](screenshots/main-window-grid.png)

## 技术栈

| 组件 | 技术 |
|------|------|
| 语言 / UI | Swift 6 + SwiftUI（macOS 14.0+）|
| 图表 | Swift Charts（`.stepEnd` 阶梯折线）|
| 持久化 | SwiftData（`~/Library/Application Support/AppDropNoSandbox`，主 App 与 Helper 共用一份数据库）|
| 后台调度 | ServiceManagement / `SMAppService.agent(plistName:)` + launchd |
| 通知 | UserNotifications |
| 网络 | URLSession（iTunes Search / Lookup API）|
| 工程 | XcodeGen（`project.yml`）+ SwiftPM 本地包 `SharedKit` |
| 测试 | Swift Testing（108 个测试用例）|

## 目录结构

```
AppDrop.xcodeproj            # 由 xcodegen 生成（勿手改，修改 project.yml 后重新生成）
project.yml                  # 工程定义（targets / 签名 / 复制阶段 / Info.plist）
AppDrop/                     # 主应用（App / Views / ViewModels / Resources / entitlements）
AppDropHelper/               # 后台助手（LSUIElement，main.swift + launchd plist）
SharedKit/                   # 共享 SwiftPM 包（Models / Services / Data / Utilities + Tests）
Scripts/                     # 辅助脚本（图标生成、独立签名和 ZIP/DMG 打包）
screenshots/                 # README 截图
```

## 快速开始

### 环境要求

- macOS 14.0 或更高版本
- Xcode 15 或更高版本（含命令行工具）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`

### 构建运行

```bash
# 1. 进入独立源码目录
cd AppDrop-NoSandbox

# 2. 生成 Xcode 工程
xcodegen generate

# 3. 运行单元测试（离线，不依赖真实价格）
swift test --package-path SharedKit --scratch-path /private/tmp/AppDrop-NoSandbox-SwiftPM

# 4. Release 构建（Universal：arm64 + x86_64；构建阶段不嵌入描述文件）
xcodebuild -project AppDrop.xcodeproj -scheme AppDrop -configuration Release \
  -derivedDataPath /private/tmp/AppDrop-NoSandbox-DD \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build

# 5. 用本机 Apple Development 证书签名并安装
Scripts/make-signed-build.sh \
  "/private/tmp/AppDrop-NoSandbox-DD/Build/Products/Release/AppDrop No Sandbox.app" \
  "/Applications/AppDrop No Sandbox.app"

# 6. 生成 ZIP、DMG 和 SHA-256
Scripts/package-no-sandbox.sh "/Applications/AppDrop No Sandbox.app" 1.0.5
```

### 权限与分发

- 不需要给 App 或 Helper 授予「完全磁盘访问权限」。
- 通知权限和后台登录项仍由用户按 macOS 标准流程授权。
- 当前产物使用 Apple Development 证书且未公证；在另一台 Mac 首次打开时需右键选择“打开”。

使用 Developer ID 证书并完成 Apple 公证后，才可以做到双击直接打开且不出现 Gatekeeper 警告。

## 后台任务工作方式

- 主 App 通过 `SMAppService.agent(plistName: "com.appdrop.nosandbox.helper.plist")` 注册 `AppDropHelper`，plist 内嵌于 `Contents/Library/LaunchAgents/`。
- Helper 默认带 `--scheduled` 参数运行：距上次尝试不足 20 小时则跳过；`--run-now` 可强制执行；完成写库与通知后正常退出，不常驻、不轮询。
- `StartInterval = 86400` 为"尽力调度"，Mac 休眠/关机期间不保证执行，醒来后由逾期判断补跑。

## 通知权限

macOS 通知权限按进程独立：

- **AppDrop No Sandbox（主应用）**：首次启动引导中申请，手动刷新触发的通知使用该权限。
- **AppDrop No Sandbox Helper（后台助手）**：首次后台运行时独立申请，launchd 触发的通知使用该权限。若被拒绝，可在「系统设置 → 通知 → AppDrop No Sandbox Helper」中开启。

## Wishdrop 格式

追踪列表可导出为 `.wishdrop` 文件（JSON），在不同设备或用户间共享。

## 本地共享数据库

- Bundle ID：`com.appdrop.nosandbox`；Helper：`com.appdrop.nosandbox.helper`
- 数据库路径：`~/Library/Application Support/AppDropNoSandbox/AppDrop.store`
- 主 App 与 Helper 使用完全一致的 ModelConfiguration；目录不可写时明确报错，不会回退到 Group Containers。
- 启动时使用真实写探针确认存储目录可写。
- 跨进程写入通过 `flock` 咨询锁串行化，价格记录含幂等标记，防止重复通知。

## 搜索说明

"添加应用 → 搜索"提供 **Mac** 与 **iPhone·iPad** 两个目录选项，默认 Mac：

- Mac 目录使用 `entity=macSoftware` + `kind` 过滤；iPhone/iPad 使用 `entity=software`。
- Apple 搜索索引存在盲区（部分新上架 Mac 游戏搜不到），此类应用请用 App Store 链接添加。

## 已知限制

| 限制 | 说明 |
|------|------|
| 签名与公证 | 当前为 Apple Development 签名，未做 Developer ID 签名与公证；其他 Mac 首次打开需右键“打开” |
| 后台调度精度 | `StartInterval` 不保证准时；休眠/关机期间可能错过或延迟检查 |
| 汇率换算 | 不做汇率换算，不合并不同区域的最低价；同一应用不同区域为独立追踪项 |
| 降价定义 | "较上次降价"基于两次有效价格之差，不是商店官方促销折扣 |
| 历史新低判定 | 基于本机记录的价格观测：当前价等于已记录最低价、且记录中出现过更高价格时才算史低；首次记录不算，不含 App Store 官方历史价格 |
| 数据迁移 | 追踪数据存于本机 Application Support，迁移请使用导出/导入心愿单功能 |

## 贡献

欢迎提交 Issue 和 Pull Request。提交 PR 前请确保 `swift test --package-path SharedKit` 通过。

## License

GNU General Public License v3.0 (GPL-3.0) — 详见 [LICENSE](LICENSE) 文件。
Copyright (C) 2026 我是艾文喵
