# 后台 Helper

## 组件

```text
AppDrop No Sandbox.app/Contents/Library/LoginItems/AppDropHelper.app
AppDrop No Sandbox.app/Contents/Library/LaunchAgents/com.appdrop.nosandbox.helper.plist
```

| 字段 | 值 |
| --- | --- |
| Label | `com.appdrop.nosandbox.helper` |
| Bundle ID | `com.appdrop.nosandbox.helper` |
| AssociatedBundleIdentifiers | `com.appdrop.nosandbox` |
| ProgramArguments | `--scheduled` |
| RunAtLoad | `true` |
| StartInterval | `86400` |

## 运行方式

- 主 App 使用 `SMAppService.agent(plistName: "com.appdrop.nosandbox.helper.plist")` 注册服务。
- Helper 与主 App 使用同一个 Application Support 数据库。
- Helper 完成查询、写库和通知后退出，不常驻、不轮询。
- 距上次尝试不足 20 小时时，`--scheduled` 会跳过；`--run-now` 可强制运行。

## 验证命令

```bash
"/Applications/AppDrop No Sandbox.app/Contents/MacOS/AppDrop No Sandbox" --backend-status
launchctl print "gui/$(id -u)/com.appdrop.nosandbox.helper"
launchctl kickstart -k "gui/$(id -u)/com.appdrop.nosandbox.helper"

"/Applications/AppDrop No Sandbox.app/Contents/Library/LoginItems/AppDropHelper.app/Contents/MacOS/AppDropHelper" \
  --store-diagnose

tail -20 "$HOME/Library/Application Support/AppDropNoSandbox/helper.log"
```

若 Helper 因 20 小时限制没有执行，可先用 `appdropctl clear-runs` 清空运行记录，再执行 `launchctl kickstart`。

## 通知

Helper 拥有独立的通知身份。首次运行时可能弹出 “AppDrop No Sandbox Helper” 的通知授权；拒绝授权不会影响价格写入，只会跳过后台通知。

## 权限

本版本不访问 `~/Library/Group Containers`，不需要给 App 或 Helper 授予完全磁盘访问权限。
