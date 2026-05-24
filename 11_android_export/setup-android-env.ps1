# Godot Android 导出环境一键准备(D 盘)
#
# 用法:
#   & .\setup-android-env.ps1 `
#       -CmdToolsZip "D:\Downloads\commandlinetools-win-*.zip" `
#       -JdkRoot     "D:\Java\jdk-17"
#
# 做的事:
#   1) 验证 JDK 17
#   2) 解压 commandline-tools 到 D:\Android\Sdk\cmdline-tools\latest\
#   3) 用 sdkmanager 装 platform-tools / build-tools / platforms;android-34
#   4) 生成 D:\Android\debug.keystore(Godot 默认密码 android)
#   5) 打印需要填进 Godot Editor Settings 的路径

param(
    [Parameter(Mandatory=$true)]
    [string]$CmdToolsZip,

    [Parameter(Mandatory=$true)]
    [string]$JdkRoot,

    [string]$SdkRoot = "D:\Android\Sdk",
    [string]$Keystore = "D:\Android\debug.keystore",
    [string]$BuildToolsVersion = "34.0.0",
    [string]$Platform = "android-34"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Fail($msg) {
    Write-Host "`n[FAIL] $msg" -ForegroundColor Red
    exit 1
}

# —— 0) 前置检查 ————————————————————————————————————————

Write-Step "Checking JDK at $JdkRoot"
$javaExe = Join-Path $JdkRoot "bin\java.exe"
if (-not (Test-Path $javaExe)) { Fail "java.exe not found at $javaExe" }

$jver = & $javaExe -version 2>&1 | Out-String
if ($jver -notmatch 'version "(17|17\.\d+)') {
    Write-Host $jver
    Fail "Need JDK 17 (got above). Godot 4.3+ requires exactly 17."
}
Write-Host "JDK OK"

if (-not (Test-Path $CmdToolsZip)) { Fail "ZIP not found: $CmdToolsZip" }

# —— 1) 目录骨架 ————————————————————————————————————————

Write-Step "Creating directories under $SdkRoot"
$cmdToolsTarget = Join-Path $SdkRoot "cmdline-tools\latest"
New-Item -ItemType Directory -Force -Path $cmdToolsTarget | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $Keystore) | Out-Null

# —— 2) 解压 commandline-tools ————————————————————————

if (-not (Test-Path (Join-Path $cmdToolsTarget "bin\sdkmanager.bat"))) {
    Write-Step "Extracting $CmdToolsZip"
    # 解压到临时目录,zip 里根是 `cmdline-tools\`,我们需要它的内容直接落进 latest\
    $tmp = Join-Path $env:TEMP ("godot-cmdtools-" + (Get-Random))
    Expand-Archive -Path $CmdToolsZip -DestinationPath $tmp -Force
    $inner = Join-Path $tmp "cmdline-tools"
    if (-not (Test-Path $inner)) { Fail "Unexpected zip layout: no cmdline-tools/ inside" }
    Copy-Item -Path (Join-Path $inner "*") -Destination $cmdToolsTarget -Recurse -Force
    Remove-Item -Recurse -Force $tmp
} else {
    Write-Host "cmdline-tools already installed, skipping extraction"
}

# —— 3) sdkmanager 装包 ——————————————————————————————

$sdkmanager = Join-Path $cmdToolsTarget "bin\sdkmanager.bat"
if (-not (Test-Path $sdkmanager)) { Fail "sdkmanager.bat not found at $sdkmanager" }

# sdkmanager 要找到 java -> 临时把 JAVA_HOME 指到 JdkRoot
$env:JAVA_HOME = $JdkRoot
$env:Path = "$JdkRoot\bin;$env:Path"

Write-Step "Accepting SDK licenses"
# `y` 喂给所有 license 提示
"y`ny`ny`ny`ny`ny`ny`ny" | & $sdkmanager --sdk_root="$SdkRoot" --licenses | Out-Null

Write-Step "Installing SDK packages"
& $sdkmanager --sdk_root="$SdkRoot" `
    "platform-tools" `
    "build-tools;$BuildToolsVersion" `
    "platforms;$Platform" `
    "cmdline-tools;latest"
if ($LASTEXITCODE -ne 0) { Fail "sdkmanager install failed (exit $LASTEXITCODE)" }

# —— 4) 生成 debug.keystore ————————————————————————

if (Test-Path $Keystore) {
    Write-Host "Keystore already exists at $Keystore, skipping"
} else {
    Write-Step "Generating debug keystore at $Keystore"
    $keytool = Join-Path $JdkRoot "bin\keytool.exe"
    & $keytool -keyalg RSA -genkeypair `
        -alias androiddebugkey `
        -keypass android `
        -keystore $Keystore `
        -storepass android `
        -dname "CN=Android Debug,O=Android,C=US" `
        -validity 9999 `
        -deststoretype pkcs12
    if ($LASTEXITCODE -ne 0) { Fail "keytool failed (exit $LASTEXITCODE)" }
}

# —— 5) 总结 ————————————————————————————————————————

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "  DONE. Open Godot -> Editor Settings -> Export -> Android" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host @"

Java SDK Path             $JdkRoot
Android SDK Path          $SdkRoot
Debug Keystore            $Keystore
Debug Keystore User       androiddebugkey
Debug Keystore Password   android

Then: Editor -> Manage Export Templates -> Download and Install
And:  Project -> Export -> Add -> Android
"@
