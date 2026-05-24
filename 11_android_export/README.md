# Demo 11 — Android 导出实战(全程 D 盘)

把任意 Godot 项目打成 `.apk` 装到手机上,从零环境一步步走。**所有 SDK/JDK 默认装 D 盘**,符合本仓约定。

## 总览(成品路径)

```
D:\Java\jdk-17\                  ← OpenJDK 17
D:\Android\Sdk\                  ← Android SDK + NDK + build-tools + platform-tools
D:\Android\debug.keystore        ← debug 签名(任何项目都能复用)
D:\Godot\Godot_v4.x_win64.exe    ← 编辑器
D:\Godot\templates\              ← (可选)Android 导出模板,自包含模式
```

## Step 1 — 装 JDK 17(必须 17,不是 8/11/21)

下载 OpenJDK 17 / Temurin 17,解压到:
```
D:\Java\jdk-17\
├── bin\
├── lib\
└── ...
```
验证:
```powershell
& "D:\Java\jdk-17\bin\java.exe" -version
# openjdk version "17.x.x"
```

> Godot 4.3+ 要求 **JDK 17**。装 11 会在 Gradle 阶段报 "unsupported class file version"。

## Step 2 — 装 Android SDK(命令行工具最省事)

不想装整套 Android Studio?装 **command-line tools** 即可:
1. 去 https://developer.android.com/studio#command-line-tools-only 下 Windows zip
2. 解压到 `D:\Android\Sdk\cmdline-tools\latest\`
   - 这个 `latest\` 子目录是 **强制**的,否则 `sdkmanager` 报路径错
3. 用 `sdkmanager` 装必要组件(下面有 PowerShell 脚本一键搞定)

或者:直接装 Android Studio,装到 D 盘,让它把 SDK 装到 `D:\Android\Sdk`。

**Godot 4 需要的 SDK 组件**:
- `platform-tools`(adb)
- `build-tools;34.0.0`(或更新)
- `platforms;android-34`(API 34, Godot 4.3+)
- `cmdline-tools;latest`
- (可选)`ndk;23.2.8568313` —— 用 Android 自定义模块时才需要

## Step 3 — 用 helper 脚本一键准备 D 盘环境

`setup-android-env.ps1`(见同目录)自动:
- 创建目录骨架
- 接受已下载的 `commandlinetools-win-*.zip` 路径,解压到正确位置
- 接受 JDK 路径,验证版本
- 调用 `sdkmanager` 装 build-tools / platform / platform-tools
- 用 keytool 生成 debug.keystore

跑法:
```powershell
& D:\godotstuff\11_android_export\setup-android-env.ps1 `
    -CmdToolsZip "D:\Downloads\commandlinetools-win-11076708_latest.zip" `
    -JdkRoot     "D:\Java\jdk-17"
```

## Step 4 — 在 Godot 编辑器里配 Android 路径

打开 Godot → **Editor → Editor Settings → Export → Android**:

| 字段 | 值 |
|------|-----|
| Java SDK Path | `D:\Java\jdk-17` |
| Android SDK Path | `D:\Android\Sdk` |
| Debug Keystore | `D:\Android\debug.keystore` |
| Debug Keystore User | `androiddebugkey` |
| Debug Keystore Password | `android` |

(本 demo 的脚本就是按这套生成 keystore 的)

## Step 5 — 装 Android 导出模板

Godot → **Editor → Manage Export Templates → Download and Install**。
官方包约 600MB,默认装到 `%APPDATA%`。

想让模板也留在 D 盘?**开自包含模式**:
```powershell
New-Item -Path D:\Godot\_sc_ -ItemType File -Force
```
然后 Godot 会把模板装到 `D:\Godot\export_templates\<版本>\`。

## Step 6 — 给你的项目加 Android 预设

随便选本仓的某个 demo(比如 `01_hello_world`),用编辑器打开,**Project → Export → Add → Android**。

或者直接 commit 这个 `export_presets.cfg`(本目录提供模板),内容大致:
```ini
[preset.0]
name="Android"
platform="Android"
runnable=true
custom_features=""
export_path="build/MyGame.apk"
script_export_mode=2
custom_template/debug=""
custom_template/release=""
```
(完整模板见 `sample-project/export_presets.cfg`)

## Step 7 — 命令行打包(CI / AI 友好)

不用打开编辑器:
```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" `
    --headless `
    --path D:\godotstuff\01_hello_world `
    --export-debug "Android" `
    "D:\godotstuff\01_hello_world\build\hello.apk"
```
- `--headless`:不开窗口
- `--export-debug "<preset 名字>"` / `--export-release`
- 最后一个参数是输出 .apk 路径

## Step 8 — 装机调试

手机:**设置 → 关于手机 → 连点版本号 7 次 → 开发者选项 → USB 调试 → 打开**。

```powershell
# 装到机器上
& "D:\Android\Sdk\platform-tools\adb.exe" install -r D:\godotstuff\01_hello_world\build\hello.apk

# 看日志
& "D:\Android\Sdk\platform-tools\adb.exe" logcat -s godot:*
```

`logcat -s godot:*` 只看 Godot 自家的 print/push_error,过滤掉系统噪音。

## Release 签名(上架前必做)

debug.keystore 任何机器都能装,但**应用商店不要**。生成 release 签名:
```powershell
& "D:\Java\jdk-17\bin\keytool.exe" -keyalg RSA -genkeypair `
    -alias mygame -keypass <你的密码> `
    -keystore D:\Android\release.keystore -storepass <你的密码> `
    -dname "CN=Your Name,O=Your Org,C=CN" -validity 9125 -deststoretype pkcs12
```
9125 天 = 25 年,Google Play 要求至少 2033 年后过期。
然后在 `export_presets.cfg` 里填 `keystore/release` 路径和 `keystore/release_user`、`keystore/release_password` —— **不要 commit 这些字段进 git**,放进 `.gitignore` 或用环境变量替换。

## Build AAB(Google Play 必须)

Play Store 现在只收 `.aab` 不收 `.apk`:
- 在导出预设里把 **Format** 选 `Android App Bundle (.aab)`
- 输出后用 `bundletool` 在本地装机测试:
  ```powershell
  java -jar bundletool.jar build-apks --bundle=app.aab --output=app.apks --mode=universal
  ```

## 常见坑速查

| 报错 | 原因 / 修复 |
|------|------------|
| "JAVA_HOME is set to invalid directory" | Godot 里 Java SDK Path 填的不对,要填 JDK **根目录**(里面有 `bin/`),不是 `bin/` |
| "Failed to find Build Tools revision XX" | sdkmanager 没装对应版本,`sdkmanager "build-tools;34.0.0"` |
| "Trust anchor for certification path not found" | 网络代理问题,Gradle 拿不到依赖 |
| apk 装到机器后秒退 | 99% 是 ABI 不匹配,导出预设里勾上 `armeabi-v7a` 和 `arm64-v8a` 两个 |
| 黑屏不渲染 | 项目里渲染后端选成 `forward_plus`,改成 `gl_compatibility`(本仓所有 demo 已锁) |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | 旧版本残留,`adb uninstall <package>` 再装 |
| `--export-debug` 没找到预设 | 预设名字大小写敏感,默认是 "Android" 不是 "android" |
| "Gradle build failed" | 看 logcat / 命令行尾部的真正错误,通常是 SDK 路径或 JDK 版本错 |

## 文件清单

- [README.md](README.md) — 本文
- [setup-android-env.ps1](setup-android-env.ps1) — D 盘环境一键脚本
- [sample-project/](sample-project/) — 最小可导出 Android 的 Godot 项目
  - `project.godot`
  - `main.tscn` / `main.gd` —— 屏幕显示设备信息
  - `export_presets.cfg` —— 预填好的 Android 预设模板
  - `icon.svg`

## 下一步可扩展

- iOS 导出(macOS only,需 Xcode + Apple Developer 账号)—— 后续可加一个 `12_ios_export`
- Itch.io / Steam 桌面打包
- GitHub Actions CI(headless 自动构建上传)
