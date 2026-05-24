# Godot 4 安装指南(Windows / D 盘优先)

> 约定:所有 SDK / 工具装到 **D 盘**,避免 C 盘臃肿。

## 1. 下载 Godot 4

- 官网:https://godotengine.org/download
- 选 **Godot Engine (Standard)** 不要 .NET 版(除非你要写 C#)
- 文件类似 `Godot_v4.3-stable_win64.exe`(单文件可执行,无需安装器)

## 2. 放到 D 盘

推荐路径:

```
D:\Godot\
└── Godot_v4.3-stable_win64.exe
```

或更整洁的版本化布局:

```
D:\Godot\
├── 4.3-stable\
│   └── Godot_v4.3-stable_win64.exe
└── current.exe -> 4.3-stable\Godot_v4.3-stable_win64.exe   (可选符号链接)
```

## 3. 加入 PATH(可选)

如果想在任何终端里直接 `godot ...`:

**PowerShell(当前用户,持久化):**
```powershell
$old = [Environment]::GetEnvironmentVariable("Path","User")
[Environment]::SetEnvironmentVariable("Path", "$old;D:\Godot", "User")
```

然后**新开**一个终端,验证:
```powershell
godot --version
# 期望输出类似:4.3.stable.official.77dcf97d8
```

> 如果可执行文件名带版本号,可以建一个 `godot.cmd` 转发:
> ```
> @echo off
> "D:\Godot\Godot_v4.3-stable_win64.exe" %*
> ```

## 4. 验证能跑

```powershell
& "D:\Godot\Godot_v4.3-stable_win64.exe" --path D:\godotstuff\01_hello_world
```

应该弹出窗口,屏幕中央显示 "Hello, Godot!"。

## 5. (可选)导出模板

如果要打包成 `.exe` / `.apk` / `.ipa`:

- 编辑器内:**Editor → Manage Export Templates → Download and Install**
- 模板包大约 600MB,默认装在 `%APPDATA%\Godot\export_templates\<版本>\`
- 想搬到 D 盘:设置 `GODOT_USER_DATA_DIR` 或用 self-contained 模式(在 exe 同目录创建 `_sc_` 空文件,Godot 就把所有数据放在 exe 旁边)

**自包含模式(推荐,数据全在 D 盘):**

```powershell
New-Item -Path D:\Godot\_sc_ -ItemType File -Force
```

之后 Godot 的项目列表、导出模板、用户配置都会写到 `D:\Godot\` 下,完全脱离 `C:\Users\<you>\AppData`.

## 6. Android 导出(后续 demo 会用到)

需要装:
- **Android Studio** 或单独的 **Android SDK + NDK**(装 D 盘:`D:\Android\Sdk`)
- **OpenJDK 17**(装 D 盘:`D:\Java\jdk-17`)
- 在 Godot 里:**Editor Settings → Export → Android** 填好 SDK / Java 路径
- 生成 debug keystore:
  ```powershell
  & "D:\Java\jdk-17\bin\keytool.exe" -keyalg RSA -genkeypair -alias androiddebugkey `
    -keypass android -keystore D:\Android\debug.keystore -storepass android `
    -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
  ```

## 常见坑

| 现象 | 原因 / 解决 |
|------|------------|
| 启动后字体方块 | 系统缺 CJK 字体,或项目用了 fallback,改用 `NotoSansCJK` |
| 黑屏 / 不渲染 | 显卡驱动太老,切换 `Project Settings → Rendering → Renderer = GL Compatibility` |
| `.tscn` 报 "resource not found" | UID 失效,删掉 `.godot/` 让编辑器重生成 |
| 移动端导出黑屏 | 用 `gl_compatibility` 渲染后端,不要用 forward+ |
