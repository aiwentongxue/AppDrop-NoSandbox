# AppDrop No Sandbox 测试报告

验证日期：2026-10-18（Asia/Shanghai）

环境：macOS 27.2（26B5112a）/ Xcode 27.0（27A266a）/ Apple Silicon

基线：原仓库 `162be3cb0ae451c1c78a15b14fbb48d79c0ffb0b`（`v1.0.3`）

## 1. 单元测试

```bash
swift test --package-path SharedKit \
  --scratch-path /private/tmp/AppDrop-NoSandbox-SwiftPM
```

结果：**83 个测试、12 个 suite 全部通过**。

新增验证：

- 存储根目录固定解析到 Application Support；
- 主 App 与 Helper 的数据库和锁/日志路径一致；
- 存储路径不包含 `Group Containers`；
- 本地目录可通过真实写探针；
- Bundle ID、Helper Bundle ID 和 LaunchAgent 名称使用无沙盒独立身份。

## 2. 构建与签名

| 项 | 结果 |
| --- | --- |
| Release 构建 | ✅ `BUILD SUCCEEDED` |
| 架构 | ✅ Universal：`x86_64 + arm64` |
| 主 App Bundle ID | `com.appdrop.nosandbox` |
| Helper Bundle ID | `com.appdrop.nosandbox.helper` |
| 签名身份 | 本机 Apple Development 证书 |
| 深层签名校验 | ✅ `codesign --verify --deep --strict` |
| Sandbox entitlement | ✅ 不存在 |
| App Groups entitlement | ✅ 不存在 |
| 内嵌 provisioning profile | ✅ 不存在 |

安装位置：`/Applications/AppDrop No Sandbox.app`

## 3. 存储与权限

主 App 和 Helper 的诊断结果一致：

```text
sandbox container id: -
storage root: ~/Library/Application Support/AppDropNoSandbox
storeURL: ~/Library/Application Support/AppDropNoSandbox/AppDrop.store
local storage write: OK
ModelContainer: OK
```

分别清除主 App 与 Helper 的 `SystemPolicyAllFiles` 授权后，主 App 仍可正常启动、打开数据库并显示界面。无沙盒版本不要求完全磁盘访问权限。

## 4. Computer Use 实机验证

在 `/Applications` 安装环境中通过真实 UI 操作验证：

- 首次启动与完整 Onboarding；
- 主应用通知授权和 Helper 独立通知授权；
- 后台 Helper 注册成功，状态为 `enabled`；
- App Store 搜索添加（Mac 目录）；
- App Store 链接添加；
- 同一区域重复添加提示；
- 网格/列表切换、名称/最近检查排序、17 区域筛选；
- 心愿单关键词搜索；
- 今日降价视图、历史新低视图；
- 详情页、首次价格记录、阶梯图单记录兜底；
- 单应用更换区域；
- 设置默认区域和全部应用批量换区；
- 多选模式与选择状态；
- 停止追踪确认弹窗（验证后取消）；
- Wishdrop 导出为有效 JSON；
- Wishdrop 文件选择导入：新增 1、已存在 1、无效 1；
- 在访达中双击 `.wishdrop`：新增 0、已存在 2、无效 1；
- 设置页显示真实本地数据库路径，“在访达中显示”可打开目标目录；
- 退出并重新启动后，数据、默认区域和 Onboarding 状态保持；
- 原版沙盒 AppDrop 与无沙盒版可同时启动，主界面布局与工具栏一致。

## 5. 后台任务与通知

```bash
AppDrop No Sandbox --backend-status
```

结果：`enabled`。

`launchctl print` 显示服务：

- Label：`com.appdrop.nosandbox.helper`
- Parent Bundle：`com.appdrop.nosandbox`
- 运行参数：`--scheduled`
- 最近一次退出码：`0`

清空测试运行记录后执行 `launchctl kickstart -k`，Helper 在 launchd 上下文中完成真实查价：

```text
[refresh] run finished: outcome=success checked=2 changed=0 failed=0 notified=0
```

主 App 与 Helper 的数据库计数和最近运行状态同步。

通知链路验证：

- 主应用通知权限：已授权；
- Helper 通知权限：已授权；
- 模拟价格下降后手动刷新，价格记录写入 `decrease` 并带 `notified` 标记；
- 相同价格变化重复检查不会重复通知。

## 6. 交付归档验证

| 文件 | SHA-256 |
| --- | --- |
| `AppDrop-NoSandbox-1.0.3-macOS-universal.zip` | `6462ca5e49e7ad2ffb0b135a36407985df2e041c6f29440b122d325df7795974` |
| `AppDrop-NoSandbox-1.0.3-macOS-universal.dmg` | `9d19d4700176b314190810b21615b2f398e16611fa25f3994a61b82d68c73705` |

- ZIP 解压后重新执行深层签名校验：通过；
- DMG 挂载、Applications 快捷方式、App 深层签名校验：通过；
- ZIP 解压后的 App 与 Helper 均可打开同一本地数据库；
- 两种归档内主程序均为 Universal。

## 7. 边界

- 当前只有 Apple Development 证书，未做 Developer ID 签名与 Apple 公证；其他 Mac 首次打开仍需右键选择“打开”。
- 本次未在第二台物理 Mac 上进行分发测试。
- 通知权限与后台登录项仍属于正常 macOS 用户授权范围。
- 测试创建的追踪项目和临时 Wishdrop 文件已清理；交付数据库为空。
