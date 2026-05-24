# Windows 上一键编译 GDExtension
#
# 前置条件:
#   1) 已装 Python 3.x 在 PATH
#   2) 已装 Visual Studio 2022 + "Desktop development with C++"(MSVC)
#      或 Visual Studio Build Tools(只装 build tools 也行,8GB)
#   3) git
#
# 用法:
#   & .\build.ps1                              # 默认 debug build
#   & .\build.ps1 -Target template_release     # release build
#   & .\build.ps1 -Clean                       # 先 clean

param(
    [string]$Target = "template_debug",         # template_debug / template_release
    [string]$Platform = "windows",
    [string]$Arch = "x86_64",
    [int]$Jobs = 8,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

# 1) 装 SCons(Python 包,跟 CMake 一个等级的构建工具)
Write-Step "Checking SCons"
$scons = Get-Command scons -ErrorAction SilentlyContinue
if (-not $scons) {
    Write-Host "Installing scons via pip..."
    python -m pip install --user scons
    # pip --user 装的 scripts 不在默认 PATH
    $userScripts = python -c "import sysconfig; print(sysconfig.get_path('scripts', f'{sysconfig.get_default_scheme()}_user'))"
    $env:Path = "$userScripts;$env:Path"
}
scons --version | Select-Object -First 1

# 2) 拉 godot-cpp(C++ binding 头文件 + 静态库)
if (-not (Test-Path "godot-cpp\SConstruct")) {
    Write-Step "Cloning godot-cpp (4.3 branch)"
    git clone --branch 4.3 --depth 1 https://github.com/godotengine/godot-cpp.git
}

# 3) 编译 godot-cpp 自身(只需要做一次)
$cppLib = "godot-cpp\bin\libgodot-cpp.windows.$Target.$Arch.lib"
if (-not (Test-Path $cppLib)) {
    Write-Step "Building godot-cpp ($Target, $Arch) - one-time, ~3min"
    Push-Location godot-cpp
    scons platform=$Platform target=$Target arch=$Arch -j$Jobs
    Pop-Location
}

# 4) 编译我们的 extension
if ($Clean) {
    Write-Step "Cleaning"
    scons platform=$Platform target=$Target arch=$Arch -c
    if (Test-Path "bin") { Remove-Item -Recurse -Force "bin" }
}

Write-Step "Building libgodotstuff ($Target, $Arch)"
scons platform=$Platform target=$Target arch=$Arch -j$Jobs

# 5) 验证
$dll = Get-ChildItem "bin\libgodotstuff.windows.$Target.$Arch.dll" -ErrorAction SilentlyContinue
if ($dll) {
    Write-Host "`n[OK] Built: $($dll.FullName)" -ForegroundColor Green
    Write-Host "`n现在打开 Godot,SineBobber 节点会出现在 Create Node 列表里。"
} else {
    Write-Host "`n[FAIL] Build finished but DLL not found" -ForegroundColor Red
    exit 1
}
