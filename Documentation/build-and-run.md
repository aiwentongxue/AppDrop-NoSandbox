# 构建、签名与分发

## 环境

- macOS 14+；本项目在 macOS 27.2、Xcode 27.0、Swift 6.4 上验证。
- XcodeGen：`brew install xcodegen`
- 签名身份：由签名脚本自动选择本机第一个 Apple Development 证书，也可通过 `SIGNING_IDENTITY` 或第三个参数指定。
- Bundle ID：`com.appdrop.nosandbox`
- Helper Bundle ID：`com.appdrop.nosandbox.helper`

## 单元测试

```bash
swift test --package-path SharedKit \
  --scratch-path /private/tmp/AppDrop-NoSandbox-SwiftPM
```

将 SwiftPM scratch path 放在 `/private/tmp` 可避免 Documents 的 File Provider 扩展属性干扰测试 bundle 签名。

## Release 构建

```bash
xcodegen generate
xcodebuild -project AppDrop.xcodeproj -scheme AppDrop -configuration Release \
  -derivedDataPath /private/tmp/AppDrop-NoSandbox-DD \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
```

构建阶段禁用 Xcode 签名，随后按 Helper → 主 App 的顺序使用本机证书签名。

## 签名与安装

```bash
Scripts/make-signed-build.sh \
  "/private/tmp/AppDrop-NoSandbox-DD/Build/Products/Release/AppDrop No Sandbox.app" \
  "/Applications/AppDrop No Sandbox.app"
```

脚本会：

1. 在 `/private/tmp` 中完成签名，避免 Documents 的 File Provider 元数据导致签名失败；
2. 删除全部 `embedded.provisionprofile`；
3. 使用无 sandbox、无 App Group 的签名配置；
4. 对 Helper 和主 App 执行 `codesign --verify --deep --strict`；
5. 校验 `arm64 + x86_64`；
6. 复制到目标位置后再次验证。

## 打包

```bash
Scripts/package-no-sandbox.sh "/Applications/AppDrop No Sandbox.app" 1.0.3
```

输出：

- `dist/AppDrop-NoSandbox-1.0.3-macOS-universal.zip`
- `dist/AppDrop-NoSandbox-1.0.3-macOS-universal.dmg`
- 对应 `.sha256` 文件

## 验证

```bash
codesign --verify --deep --strict --verbose=2 "/Applications/AppDrop No Sandbox.app"
codesign -d --entitlements :- "/Applications/AppDrop No Sandbox.app"
lipo -info "/Applications/AppDrop No Sandbox.app/Contents/MacOS/AppDrop No Sandbox"
"/Applications/AppDrop No Sandbox.app/Contents/MacOS/AppDrop No Sandbox" --store-diagnose
"/Applications/AppDrop No Sandbox.app/Contents/MacOS/AppDrop No Sandbox" --backend-status
```

正常结果：

- 签名身份为 Apple Development；
- entitlements 中不存在 `com.apple.security.app-sandbox` 或 App Groups；
- 没有内嵌描述文件；
- 存储根目录为 `~/Library/Application Support/AppDropNoSandbox`；
- 主 App 与 Helper 的存储路径一致；
- Helper 服务标签为 `com.appdrop.nosandbox.helper`。

## 开发工具 `appdropctl`

```bash
swift build --package-path SharedKit --product appdropctl \
  --scratch-path /private/tmp/AppDrop-NoSandbox-SwiftPM

CTL=$(find /private/tmp/AppDrop-NoSandbox-SwiftPM -type f -name appdropctl -perm -111 | head -1)
"$CTL" store-path
"$CTL" info
"$CTL" add-test-entry --track-id 497799835 --country us \
  --price 9.99 --currency USD --formatted '$9.99'
"$CTL" simulate-drop --track-id 497799835 --country us
"$CTL" records --track-id 497799835 --country us
"$CTL" clear-runs
```

## 分发边界

当前只使用 Apple Development 证书，未做 Developer ID 签名和公证。其他 Mac 首次启动时仍可能被 Gatekeeper 拦截，需要右键选择“打开”。该版本不要求完全磁盘访问权限，但通知和后台登录项仍需按系统提示授权。
