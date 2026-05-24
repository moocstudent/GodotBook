# Demo 19 — CI: GitHub Actions 自动构建

每次 push 自动 headless 构建多平台包,上传 artifact / itch.io / Steam。**0 本地 Mac 也能出 iOS 包**(用 macOS runner)。

## 文件

```
19_ci_github_actions/
├── README.md
├── workflows/
│   ├── godot-build.yml          # 三平台并行打包,push 触发
│   ├── godot-build-itch.yml     # 推 itch.io(butler)
│   └── godot-build-ios.yml      # iOS 单独,需要 secrets
└── docs/
    └── secrets.md               # GitHub Secrets 填什么
```

## 怎么用

1. 把 `workflows/` 整个目录复制到你仓库根:`.github/workflows/`
2. 在 `Settings → Secrets and variables → Actions` 配置 secret(见 [secrets.md](docs/secrets.md))
3. `git push origin main` → Actions 自动跑

## 学到什么

### 1. Godot Headless 命令行结构
```bash
godot --headless                  # 不开窗口
      --path <project_dir>        # 项目根目录
      --export-release <preset>   # 用预设名导出(release)
      <output_path>               # 输出文件路径
```
配合 export_presets.cfg 提交进仓库,**整个构建是声明式的**,无 GUI 依赖。

### 2. 多平台并行(matrix)
```yaml
strategy:
  matrix:
    include:
      - name: Linux
        os: ubuntu-latest
        preset: "Linux/X11"
        output: build/game.x86_64
      - name: Windows
        os: ubuntu-latest          # Linux 也能跨平台导 Windows
        preset: "Windows Desktop"
        output: build/game.exe
      - name: macOS
        os: macos-latest           # 仅 mac 能签 macOS app
        preset: "macOS"
        output: build/game.zip
```

### 3. iOS / Android 需要 secrets
- **iOS**:必须 macOS runner,且需要 .p12 证书 + provisioning profile(base64 编码后存 secret)
- **Android**:debug build 用 debug.keystore(可 commit 进仓库);release 必须用上传过 Play 的 keystore(secret)

### 4. itch.io 自动发布(butler)
```yaml
- name: Push to itch.io
  uses: KikimoraGames/itch-publish@v0.0.3
  with:
    butlerApiKey: ${{ secrets.BUTLER_API_KEY }}
    gameData: ./build/
    itchUsername: yourname
    itchGameId: mygame
    buildChannel: windows
```
butler 增量上传 → 用户客户端只下变化的字节。

### 5. Tag-based release
```yaml
on:
  push:
    tags: ['v*']                  # 仅 v0.1.0 这种 tag 触发
```
配合 GitHub Releases:
```yaml
- uses: softprops/action-gh-release@v1
  with:
    files: build/*.zip
```
打 `git tag v0.1.0 && git push --tags` → 自动生成 Release + 附件 + changelog。

## 易踩坑

- **Godot 模板版本**:CI 上的 godot 二进制版本必须 ≥ 项目版本。模板用 `barichello/godot-ci:4.3` 这种带版本的 docker image 锁版本。
- **export_presets.cfg 里的路径**:用相对路径 `build/x.exe`,不要 `D:\...`(CI 是 Linux/macOS)。
- **隐私字段**:不要 commit `release.keystore` 密码,放 secret + 在 workflow 里 sed 替换 export_presets.cfg。
- **artifact 体积**:GitHub 免费仓库 artifact 90 天后清,500MB 限制,大包(>200MB)别走 actions,改 itch.io。
- **macOS runner 每分钟约 0.08 美元**(免费额度有限);iOS 完整构建约 8 分钟。
