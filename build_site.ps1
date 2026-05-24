# ============================================================================
#  build_site.ps1 — generate a static HTML doc site from all demos
#
#  Output:
#    index.html                 catalog (cards + search)
#    readme.html / install.html rendered root README / INSTALL
#    NN_xxx/index.html          one page per demo (doc tab + one tab per file)
#    .nojekyll                  let GitHub Pages serve as-is
#
#  Deps: marked.js + highlight.js (CDN, loaded at runtime)
#  Run:  & .\build_site.ps1
#
#  NOTE: file contents are embedded as Base64 (fast + zero escaping issues),
#  decoded in-browser. Avoids PS 5.1 ConvertTo-Json slowness on CJK text.
# ============================================================================

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
if (-not $root) { $root = (Get-Location).Path }

function B64([string]$s) {
    if ($null -eq $s) { $s = "" }
    return [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($s))
}
function JsStr([string]$s) {
    if ($null -eq $s) { $s = "" }
    return '"' + $s.Replace('\','\\').Replace('"','\"') + '"'
}
function Html-Escape([string]$s) {
    if ($null -eq $s) { return "" }
    return $s.Replace("&","&amp;").Replace("<","&lt;").Replace(">","&gt;").Replace('"',"&quot;")
}

function Get-Lang([string]$name) {
    if ($name -eq "project.godot") { return "ini" }
    switch ([System.IO.Path]::GetExtension($name).ToLower()) {
        ".gd"          { return "python" }
        ".gdshader"    { return "c" }
        ".glsl"        { return "c" }
        ".cpp"         { return "cpp" }
        ".h"           { return "cpp" }
        ".json"        { return "json" }
        ".tscn"        { return "ini" }
        ".godot"       { return "ini" }
        ".cfg"         { return "ini" }
        ".gdextension" { return "ini" }
        ".csv"         { return "plaintext" }
        ".yml"         { return "yaml" }
        ".yaml"        { return "yaml" }
        ".ps1"         { return "powershell" }
        ".svg"         { return "xml" }
        ".md"          { return "markdown" }
        default        { return "plaintext" }
    }
}
function Get-Rank([string]$name) {
    if ($name -eq "project.godot") { return 80 }
    switch ([System.IO.Path]::GetExtension($name).ToLower()) {
        ".gd"          { return 0 }
        ".gdshader"    { return 10 }
        ".glsl"        { return 10 }
        ".tscn"        { return 20 }
        ".cpp"         { return 25 }
        ".h"           { return 26 }
        ".json"        { return 30 }
        ".csv"         { return 31 }
        ".cfg"         { return 40 }
        ".gdextension" { return 41 }
        ".yml"         { return 50 }
        ".ps1"         { return 60 }
        ".svg"         { return 90 }
        default        { return 55 }
    }
}
function Get-Category([int]$n) {
    if     ($n -le 6)  { return "Basics" }
    elseif ($n -le 11) { return "2D / 3D / Export" }
    elseif ($n -le 17) { return "Intermediate Systems" }
    elseif ($n -le 19) { return "Release and CI" }
    elseif ($n -le 21) { return "3D Advanced" }
    elseif ($n -le 25) { return "Engineering" }
    elseif ($n -le 29) { return "GPGPU and Platform" }
    elseif ($n -le 33) { return "Advanced Topics" }
    else               { return "Systems and Optimization" }
}

$css = @'
:root{--bg:#0d1017;--panel:#161b24;--border:#252c38;--fg:#c9d1d9;--muted:#8b949e;--accent:#58a6ff;--accent2:#56d364}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font-family:-apple-system,Segoe UI,Roboto,"Microsoft YaHei",sans-serif;line-height:1.65}
a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}
header{position:sticky;top:0;background:rgba(13,16,23,.92);backdrop-filter:blur(8px);border-bottom:1px solid var(--border);padding:14px 24px;display:flex;align-items:center;gap:14px;z-index:10}
header .num{font-weight:700;color:var(--accent2);font-family:ui-monospace,Consolas,monospace}
header h1{font-size:18px;margin:0;font-weight:600}
.wrap{max-width:1000px;margin:0 auto;padding:24px}
.tabs{display:flex;flex-wrap:wrap;gap:6px;border-bottom:1px solid var(--border);margin-bottom:18px}
.tab{padding:8px 14px;border:1px solid transparent;border-bottom:none;border-radius:8px 8px 0 0;cursor:pointer;color:var(--muted);font-size:13px;font-family:ui-monospace,Consolas,monospace}
.tab:hover{color:var(--fg)}
.tab.active{background:var(--panel);color:var(--fg);border-color:var(--border)}
.panel{display:none}.panel.active{display:block}
pre{background:#0b0e14;border:1px solid var(--border);border-radius:8px;padding:16px;overflow:auto}
code{font-family:ui-monospace,Consolas,"Cascadia Code",monospace;font-size:13px}
.md h1,.md h2,.md h3{border-bottom:1px solid var(--border);padding-bottom:6px;margin-top:30px}
.md table{border-collapse:collapse;width:100%;margin:14px 0;font-size:14px}
.md th,.md td{border:1px solid var(--border);padding:6px 10px;text-align:left}
.md th{background:var(--panel)}
.md :not(pre)>code{background:#1f2530;padding:2px 6px;border-radius:4px;font-size:12.5px}
.md pre code{background:none;padding:0}
.md blockquote{border-left:3px solid var(--accent);margin:0 0 14px;padding:2px 14px;color:var(--muted);background:#11151d}
.md img{max-width:100%}
.hero{padding:46px 24px 34px;text-align:center;border-bottom:1px solid var(--border)}
.hero h1{font-size:34px;margin:0 0 10px}
.hero p{color:var(--muted);margin:4px 0}
.hero .links{margin-top:14px;font-size:14px}
.hero .links a{margin:0 10px}
.search{width:100%;max-width:440px;padding:11px 16px;margin:20px auto 0;display:block;background:var(--panel);border:1px solid var(--border);border-radius:10px;color:var(--fg);font-size:14px;outline:none}
.search:focus{border-color:var(--accent)}
.cat{margin:36px 0 12px;font-size:12px;letter-spacing:1.5px;color:var(--accent2);text-transform:uppercase;font-weight:700}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(258px,1fr));gap:14px}
.card{background:var(--panel);border:1px solid var(--border);border-radius:12px;padding:16px;transition:.15s;display:block}
.card:hover{border-color:var(--accent);transform:translateY(-2px);text-decoration:none}
.card .n{font-family:ui-monospace,monospace;color:var(--accent2);font-size:12px}
.card h3{margin:6px 0;font-size:16px;color:var(--fg)}
.card p{margin:0;color:var(--muted);font-size:13px}
.foot{text-align:center;color:var(--muted);padding:34px;font-size:12px;border-top:1px solid var(--border);margin-top:30px}
'@

$hlCss = '<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/styles/github-dark.min.css">'
$hlJs  = '<script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script><script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"></script>'

$pageTpl = @'
<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>@@TITLE@@ - godotstuff</title>@@HLCSS@@<style>@@CSS@@</style></head><body>
<header><a href="@@HOME@@">&larr; 目录</a><span class="num">@@NUM@@</span><h1>@@NAME@@</h1></header>
<div class="wrap"><div class="tabs" id="tabs"></div><div id="panels"></div></div>
<script type="application/json" id="demodata">@@DATA@@</script>
@@HLJS@@
<script>
function dec(b){return new TextDecoder().decode(Uint8Array.from(atob(b),function(c){return c.charCodeAt(0);}));}
var R=JSON.parse(document.getElementById("demodata").textContent);
var D={readme:dec(R.readme),files:R.files.map(function(f){return {name:f.name,lang:f.lang,code:dec(f.code)};})};
var tabs=document.getElementById("tabs"),panels=document.getElementById("panels");
function addTab(label,build,active){
 var t=document.createElement("div");t.className="tab"+(active?" active":"");t.textContent=label;
 var p=document.createElement("div");p.className="panel"+(active?" active":"");build(p);
 tabs.appendChild(t);panels.appendChild(p);
 t.onclick=function(){document.querySelectorAll(".tab").forEach(function(x){x.classList.remove("active");});document.querySelectorAll(".panel").forEach(function(x){x.classList.remove("active");});t.classList.add("active");p.classList.add("active");};
}
if(window.marked){marked.setOptions({gfm:true});}
addTab("📖 文档",function(p){p.classList.add("md");if(window.marked){p.innerHTML=marked.parse(D.readme||"(no README)");}else{var pr=document.createElement("pre");pr.textContent=D.readme;p.appendChild(pr);}},true);
D.files.forEach(function(f){addTab(f.name,function(p){var pre=document.createElement("pre");var c=document.createElement("code");c.className="language-"+f.lang;c.textContent=f.code;pre.appendChild(c);p.appendChild(pre);});});
if(window.hljs){document.querySelectorAll("pre code").forEach(function(b){try{hljs.highlightElement(b);}catch(e){}});}
</script></body></html>
'@

$indexTpl = @'
<!DOCTYPE html><html lang="zh"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Godot 学习仓 - godotstuff</title><style>@@CSS@@</style></head><body>
<div class="hero"><h1>🎮 Godot 学习仓</h1>
<p>@@COUNT@@ 个独立可运行的 Godot 4 学习 demo · 点卡片看文档与源码</p>
<p class="links"><a href="readme.html">总览 README</a> · <a href="install.html">安装指南</a> · <a href="https://godotengine.org/">Godot 官网 &#8599;</a></p>
<input class="search" id="q" placeholder="搜索 demo（标题 / 编号 / 关键词）…"></div>
<div class="wrap" id="cats">@@CATS@@</div>
<div class="foot">godotstuff · 全部 demo 0 外部美术依赖 · 本页由 build_site.ps1 自动生成</div>
<script>
var q=document.getElementById("q");
q.addEventListener("input",function(){var v=q.value.toLowerCase();
 document.querySelectorAll(".card").forEach(function(c){c.style.display=c.dataset.s.indexOf(v)>=0?"":"none";});
 document.querySelectorAll(".cat").forEach(function(h){var g=h.nextElementSibling;var any=[].slice.call(g.children).some(function(c){return c.style.display!=="none";});h.style.display=any?"":"none";g.style.display=any?"":"none";});
});
</script></body></html>
'@

function Build-Data($readme, $fileObjs) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('{"readme":"'); [void]$sb.Append((B64 $readme)); [void]$sb.Append('","files":[')
    $first = $true
    foreach ($f in $fileObjs) {
        if (-not $first) { [void]$sb.Append(',') }
        $first = $false
        [void]$sb.Append('{"name":'); [void]$sb.Append((JsStr $f.name))
        [void]$sb.Append(',"lang":'); [void]$sb.Append((JsStr $f.lang))
        [void]$sb.Append(',"code":"'); [void]$sb.Append((B64 $f.code)); [void]$sb.Append('"}')
    }
    [void]$sb.Append(']}')
    return $sb.ToString()
}

function Write-Page($title, $name, $num, $homeLink, $dataJson, $outPath) {
    $html = $pageTpl.Replace("@@TITLE@@", (Html-Escape $title)).Replace("@@NAME@@", (Html-Escape $name)).
        Replace("@@NUM@@", $num).Replace("@@HOME@@", $homeLink).
        Replace("@@HLCSS@@", $hlCss).Replace("@@HLJS@@", $hlJs).
        Replace("@@CSS@@", $css).Replace("@@DATA@@", $dataJson)
    [System.IO.File]::WriteAllText($outPath, $html, (New-Object System.Text.UTF8Encoding($false)))
}

$demos = Get-ChildItem $root -Directory | Where-Object { $_.Name -match '^\d{2}_' } | Sort-Object Name
$catalog = New-Object System.Collections.ArrayList

foreach ($d in $demos) {
    $dir = $d.FullName
    $folder = $d.Name
    $num = ($folder -split '_')[0]

    $files = Get-ChildItem $dir -Recurse -File | Where-Object {
        $_.Name -ne "README.md" -and $_.Name -ne "index.html" -and $_.Extension -ne ".import"
    }
    $tmp = New-Object System.Collections.ArrayList
    foreach ($f in $files) {
        $rel = $f.FullName.Substring($dir.Length).TrimStart('\','/').Replace('\','/')
        $code = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
        if ($null -eq $code) { $code = "" }
        [void]$tmp.Add([pscustomobject]@{ name=$rel; lang=(Get-Lang $f.Name); code=$code; rank=(Get-Rank $f.Name) })
    }
    $sorted = @($tmp | Sort-Object rank, name)

    $readmePath = Join-Path $dir "README.md"
    $readme = if (Test-Path $readmePath) { Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8 } else { "" }

    $pg = Join-Path $dir "project.godot"
    $name = $folder; $desc = ""
    if (Test-Path $pg) {
        $txt = Get-Content -LiteralPath $pg -Raw -Encoding UTF8
        if ($txt -match 'config/name="([^"]*)"') { $name = $matches[1] }
        if ($txt -match 'config/description="([^"]*)"') { $desc = $matches[1] }
    }
    $displayName = ($name -replace '^\d+\s*', '')

    $data = Build-Data $readme $sorted
    Write-Page $name $name $num "../index.html" $data (Join-Path $dir "index.html")

    [void]$catalog.Add([pscustomobject]@{ num=[int]$num; folder=$folder; name=$displayName; desc=$desc; cat=(Get-Category ([int]$num)) })
    Write-Host ("  page  {0,-26} {1} files" -f $folder, $sorted.Count)
}

$catsHtml = New-Object System.Text.StringBuilder
$lastCat = ""
foreach ($item in ($catalog | Sort-Object num)) {
    if ($item.cat -ne $lastCat) {
        if ($lastCat -ne "") { [void]$catsHtml.Append("</div>") }
        [void]$catsHtml.Append('<div class="cat">' + (Html-Escape $item.cat) + '</div><div class="grid">')
        $lastCat = $item.cat
    }
    $numStr = "{0:D2}" -f $item.num
    $s = (("$numStr " + $item.name + " " + $item.desc + " " + $item.folder).ToLower())
    [void]$catsHtml.Append('<a class="card" href="' + $item.folder + '/index.html" data-s="' + (Html-Escape $s) + '">' +
        '<div class="n">' + $numStr + '</div><h3>' + (Html-Escape $item.name) + '</h3><p>' + (Html-Escape $item.desc) + '</p></a>')
}
if ($lastCat -ne "") { [void]$catsHtml.Append("</div>") }

$indexHtml = $indexTpl.Replace("@@CSS@@", $css).Replace("@@COUNT@@", $catalog.Count.ToString()).Replace("@@CATS@@", $catsHtml.ToString())
[System.IO.File]::WriteAllText((Join-Path $root "index.html"), $indexHtml, (New-Object System.Text.UTF8Encoding($false)))

function Write-DocPage($mdPath, $title, $outName) {
    if (-not (Test-Path $mdPath)) { return }
    $md = Get-Content -LiteralPath $mdPath -Raw -Encoding UTF8
    $data = Build-Data $md @()
    Write-Page $title $title "" "index.html" $data (Join-Path $root $outName)
}
Write-DocPage (Join-Path $root "README.md")  "总览 README" "readme.html"
Write-DocPage (Join-Path $root "INSTALL.md") "安装指南"    "install.html"

[System.IO.File]::WriteAllText((Join-Path $root ".nojekyll"), "", (New-Object System.Text.UTF8Encoding($false)))

Write-Host ""
Write-Host ("[OK] generated {0} demo pages + index.html + readme.html + install.html" -f $catalog.Count) -ForegroundColor Green
