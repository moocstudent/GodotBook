# Demo 18 — iOS 导出

跟 demo 11 (Android) 是一对。**iOS 导出强制需要 macOS + Xcode**,Windows / Linux 上**只能改代码、不能签名打包**。本文档把所有路径走通,你需要一台 Mac(或 Mac mini / 云租用 Mac)。

## 路线总览

```
你的 Windows 主开发机 (D:\godotstuff\...)
    │
    ├─[git push]─→  GitHub repo
    │                    │
    │                    └─[git pull]─→ Mac
    │                                     │
    │                                     ├─ Godot for macOS
    │                                     ├─ Xcode (Command Line Tools)
    │                                     ├─ Apple Developer 账号($99/年)
    │                                     └─ → .ipa
```

## Step 1 — Apple Developer 账号(绕不开)

- 免费账号:可签**自己一台机器**,7 天到期要重签,不能上 App Store
- 付费 $99/年(个人):TestFlight 内测、最多 100 台机器、App Store 上架
- 公司账号 $299/年:多人协作

注册:https://developer.apple.com

## Step 2 — Mac 上装环境

```bash
# 1) Command Line Tools(包含 git、make、clang)
xcode-select --install

# 2) 完整 Xcode(从 App Store 装)— 必须,Godot 调 xcodebuild 签名
#    装完打开一次同意协议:
sudo xcodebuild -license accept

# 3) Godot macOS 版
#    https://godotengine.org/download/macos
#    拖到 /Applications/Godot.app

# 4) 导出模板
#    Godot → Editor → Manage Export Templates → Download and Install
```

## Step 3 — 在 Mac 上克隆项目

```bash
git clone https://github.com/<you>/godotstuff
cd godotstuff/01_hello_world      # 或任何一个 demo
open project.godot                # 用 Godot 打开
```

## Step 4 — iOS 预设(Project → Export → Add → iOS)

关键字段:

| 字段 | 值 |
|------|-----|
| **App Store Team ID** | Apple Developer 后台 "Membership" 里的 10 位 ID |
| **Bundle Identifier** | `com.yourorg.yourgame`(必须全球唯一,App Store Connect 注册) |
| **Code Sign Identity Debug** | `iPhone Developer: Your Name (XXXXXXXXXX)` |
| **Code Sign Identity Release** | `iPhone Distribution: Your Org (XXXXXXXXXX)` |
| **Provisioning Profile UUID** | Debug + Release 各一个 |
| **Targeted Device Family** | 1=iPhone, 2=iPad, 3=Both |

证书与 profile 在 https://developer.apple.com/account/resources 创建。

## Step 5 — 一键导出

**编辑器**:Project → Export → iOS → **Export Project** → 输出 `.xcodeproj` 目录。然后:
```bash
cd build/
xcodebuild -project HelloAndroid.xcodeproj -scheme HelloAndroid \
           -configuration Release -archivePath HelloAndroid.xcarchive archive

xcodebuild -exportArchive -archivePath HelloAndroid.xcarchive \
           -exportPath . -exportOptionsPlist ExportOptions.plist
```

**命令行**(CI 用):
```bash
/Applications/Godot.app/Contents/MacOS/Godot \
    --headless \
    --path . \
    --export-release "iOS" \
    "build/HelloAndroid.xcodeproj"

# 然后用 xcodebuild 打 .ipa 同上
```

## Step 6 — 装机测试

USB 接上 iPhone,Mac 打开 Xcode → Window → Devices and Simulators → 拖 `.ipa` 到设备。
或 Wireless Debugging:Window → Devices → 选机器 → "Connect via network"。

也可用免费 `ideviceinstaller`(brew install):
```bash
ideviceinstaller -i HelloAndroid.ipa
```

## Step 7 — TestFlight 发内测

1. App Store Connect 创建 App 记录(Bundle ID 要先在 Developer 后台注册)
2. Xcode Organizer → Distribute App → App Store Connect → Upload
3. 等 5-30 分钟处理,在 TestFlight 加测试人员
4. 测试人员手机装 TestFlight app,扫码 / 链接即可装你的游戏

## 远程 Mac 方案(没 Mac 怎么办)

- **MacStadium**:租 Mac mini,约 $79/月起
- **MacInCloud**:按小时,$1/h 起
- **GitHub Actions macOS runner**:CI 用,有月免费额度
- **Hackintosh**:可行但违反 EULA,只做开发自用

## 常见坑速查

| 报错 | 原因 / 修复 |
|------|------------|
| `Code Signing Error: No matching provisioning profiles` | Bundle ID 没在 Apple 后台注册 profile;或 Team ID 填错 |
| `Could not find Xcode` | `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer` |
| `ld: framework not found` | Godot 4.3+ 默认链 `GameController.framework` 等,Xcode 版本太老 |
| `arm64 only`? 我有老设备 | Godot 4 已弃 armv7,只支持 arm64(iOS 11+);跑不了 iPhone 5 等 |
| App icon missing | Project Settings → iOS Bundle 设置 icon path,iOS 要 1024×1024 PNG **不带 alpha** |
| Crashes on launch | Mac 上 `idevicesyslog | grep <bundle>` 看真机日志 |
| TestFlight 上传被拒 "ITMS-XXXX" | 99% 是 Info.plist 缺 NSXxxUsageDescription,Godot 导出预设 Capabilities 里加 |

## Windows 上你能做的(预备)

虽然不能签名,但可以:
1. 项目里加 `[platform.iphone]` 段到 `project.godot`(竖屏锁定、splash 等)
2. 在 `export_presets.cfg` 里**预填**所有 iOS preset 字段(Team ID 暂留空)
3. icon、launch screen PNG 准备好放在 `ios/` 子目录
4. 写好 CI 脚本(见 demo 19),让 GitHub Actions 的 macOS runner 自动出包

iOS 预设字段 cheat sheet:

```ini
[preset.1]
name="iOS"
platform="iOS"
runnable=false
export_path="build/HelloAndroid.xcodeproj"

[preset.1.options]
application/app_store_team_id="ABCD123456"
application/bundle_identifier="com.yourorg.helloandroid"
application/short_version="0.1.0"
application/version="1"
application/code_sign_identity_debug=""
application/code_sign_identity_release=""
application/provisioning_profile_uuid_debug=""
application/provisioning_profile_uuid_release=""
application/targeted_device_family=2
capabilities/access_wifi=false
capabilities/push_notifications=false
storyboard/use_launch_screen_storyboard=true
storyboard/image_scale_mode=0
```

## 与 demo 11 的对比

| | Android | iOS |
|---|---------|-----|
| 开发机 | Windows / macOS / Linux 都行 | **必须 macOS**(签名/上架) |
| 工具链 | JDK + Android SDK + Gradle | Xcode + xcodebuild |
| 签名 | debug.keystore 通用 | 必须 Apple Developer 账号 + profile |
| 测试装机 | adb install,任意 USB | TestFlight 或 Xcode 配对 |
| 上架 | Google Play $25 一次性 | App Store $99/年 |

## 推荐学习顺序

1. 先把游戏在 Android 上跑通(demo 11)
2. 注册 Apple Developer 账号(等审核)
3. 借/租一台 Mac,**只**做"导出 + 签名 + 装 TestFlight"
4. 后续在 Windows 上开发,push 触发 GitHub Actions macOS runner 自动出包(demo 19 实现)
