# 文档站 (HTML) 说明

`build_site.ps1` 把每个 demo 的 `README.md` + 全部源码渲染成静态 HTML,生成一个可发布到 **GitHub Pages** 的文档站。

## 产物

```
index.html              ← 总目录(40 张卡片 + 实时搜索,按分类分组)
readme.html             ← 根 README 渲染页
install.html            ← 安装指南渲染页
NN_xxx/index.html       ← 每个 demo 一页:
                            · 📖 文档 tab(README 渲染,带表格/代码高亮)
                            · 每个源文件一个 tab(.gd/.tscn/.glsl/... 语法高亮)
.nojekyll               ← 让 GitHub Pages 原样 serve(不走 Jekyll)
.github/workflows/pages.yml  ← 自动部署 workflow
```

## 重新生成

加了新 demo 或改了 README/源码后,重跑一次:

```powershell
& D:\godotstuff\build_site.ps1
```

> 注:脚本含中文,PowerShell 5.1 需要 **UTF-8 BOM** 才能正确读取。若编辑器另存为无 BOM 的 UTF-8 导致中文乱码,先转一次:
> ```powershell
> $c = Get-Content -LiteralPath build_site.ps1 -Raw -Encoding UTF8
> [IO.File]::WriteAllText('build_site.ps1', $c, (New-Object Text.UTF8Encoding($true)))
> ```

## 技术要点

- **源码以 Base64 内嵌**,浏览器端 `atob` + `TextDecoder` 解码。好处:零转义问题(源码里的 `</script>`、引号、中文都不会破坏 HTML),且避免 PS 5.1 `ConvertTo-Json` 在大段中文上极慢的坑。
- **marked.js + highlight.js 走 CDN**(jsDelivr),运行时加载,无需本地构建工具链。
- 每页自包含(CSS 内联),`file://` 双击也能看;CDN 资源需要联网才有 markdown 渲染 / 高亮,离线时降级为纯文本。

## 本地预览

```powershell
# 直接双击 index.html(注意:部分浏览器对 file:// 的 fetch 有限制,但本站用内嵌数据,无 fetch,OK)
# 或起个本地服务器:
cd D:\godotstuff
python -m http.server 8000
# 浏览器打开 http://localhost:8000
```

## 发布到 GitHub Pages

### 方式 A — 从分支直接发布(最简单,无需 CI)

1. 把整个 `godotstuff` 目录推到 GitHub 仓库(含生成好的 `*.html`)
   ```powershell
   cd D:\godotstuff
   git init
   git add .
   git commit -m "Godot 学习仓 + 文档站"
   git branch -M main
   git remote add origin https://github.com/<你>/godotstuff.git
   git push -u origin main
   ```
2. 仓库 **Settings → Pages** → Source 选 **Deploy from a branch** → Branch = `main` / `(root)` → Save
3. 等 1-2 分钟,访问 `https://<你>.github.io/godotstuff/`

### 方式 B — 用 Actions 自动部署(已内置 workflow)

1. 推代码到 main
2. **Settings → Pages** → Source 选 **GitHub Actions**
3. `.github/workflows/pages.yml` 会自动跑:重新生成站点 + 部署
4. 之后每次 push 自动更新

> workflow 里那步 "Regenerate site" 用 `pwsh`(PowerShell Core,Linux runner 自带)重跑 `build_site.ps1`,保证 HTML 与最新源码一致。不想要可以删掉那步(仓库里已 commit 的 HTML 也能直接发)。

## 用户怎么用这个站

- 打开 `index.html` → 看到 40 个 demo 卡片,按分类分组,顶部可搜索
- 点任意卡片 → 进入该 demo 页
  - **📖 文档** tab:渲染后的 README(怎么跑 / 学什么 / 改造 / 踩坑)
  - **源文件** tab:每个 `.gd` / `.tscn` / `.glsl` 等带语法高亮,直接读代码
- 顶部"← 目录"返回总览;"总览 README""安装指南"看全局文档

文档浏览和源码阅读都在网页里,无需 clone 或装 Godot 即可学习;想真正运行某个 demo 再按其文档用 Godot 打开对应文件夹。
