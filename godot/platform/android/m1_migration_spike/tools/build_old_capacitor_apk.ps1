# M1 migration spike: builds the controlled OLD Capacitor APK from a clean temporary clone.
# The PixiJS/Capacitor sources are not modified: the clone's web build is synced into its own
# android/ project with `npx cap sync android` and built as the stock `debug` variant (debuggable,
# so Capacitor enables WebView remote debugging, which the seeding step uses). The APK keeps the
# audited package id and versionCode (1) and is re-signed with the test upgrade key.
# Env: SV_M1_UPGRADE_PASS (dot-source <keys>\secrets.env.ps1 first).
param(
  [Parameter(Mandatory = $true)][string]$SourceRepo,
  [Parameter(Mandatory = $true)][string]$Commit,
  [Parameter(Mandatory = $true)][string]$WorkDir,
  [Parameter(Mandatory = $true)][string]$Keystore,
  [Parameter(Mandatory = $true)][string]$OutApk,
  [Parameter(Mandatory = $true)][string]$AndroidSdk,
  [Parameter(Mandatory = $true)][string]$JavaHome,
  [Parameter(Mandatory = $true)][string]$GradleUserHome,
  # Java's temp and unix-socket directory (works around "Unable to establish loopback connection").
  [Parameter(Mandatory = $true)][string]$JavaTmpDir
)
$ErrorActionPreference = 'Stop'
if (-not $env:SV_M1_UPGRADE_PASS) { throw 'SV_M1_UPGRADE_PASS is not set' }
if (Test-Path $WorkDir) { throw "$WorkDir exists; use a fresh directory" }
New-Item -ItemType Directory -Force $JavaTmpDir | Out-Null
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=$JavaTmpDir -Djava.io.tmpdir=$JavaTmpDir"
$env:JAVA_HOME = $JavaHome
$env:ANDROID_HOME = $AndroidSdk
$env:ANDROID_SDK_ROOT = $AndroidSdk
$env:GRADLE_USER_HOME = $GradleUserHome
$env:Path = "$JavaHome\bin;$env:Path"
function Invoke-Step([string]$name, [scriptblock]$body) {
  Write-Output "== $name"
  & $body
  if ($LASTEXITCODE -ne 0) { throw "$name failed (exit $LASTEXITCODE)" }
}
Invoke-Step 'git clone' { git clone --quiet $SourceRepo $WorkDir }
Set-Location $WorkDir
Invoke-Step 'git checkout' { git -c advice.detachedHead=false checkout --quiet $Commit }
Write-Output "source commit: $(git rev-parse HEAD)"
Invoke-Step 'npm ci' { npm ci --no-audit --no-fund }
Invoke-Step 'npm run build' { npm run build }
Invoke-Step 'npx cap sync android' { npx cap sync android }
Write-Output "tracked files changed by the sync (git status --porcelain, ignored outputs excluded):"
git status --porcelain
Set-Location (Join-Path $WorkDir 'android')
Invoke-Step 'gradlew assembleDebug' { .\gradlew.bat --no-daemon assembleDebug }
$built = Join-Path $WorkDir 'android\app\build\outputs\apk\debug\app-debug.apk'
$bt = Get-ChildItem (Join-Path $AndroidSdk 'build-tools') | Sort-Object Name | Select-Object -Last 1
$apksigner = Join-Path $bt.FullName 'apksigner.bat'
$aapt2 = Join-Path $bt.FullName 'aapt2.exe'
New-Item -ItemType Directory -Force (Split-Path $OutApk) | Out-Null
Invoke-Step 'apksigner sign (test upgrade key)' { & $apksigner sign --ks $Keystore --ks-pass env:SV_M1_UPGRADE_PASS --ks-key-alias sv_m1_upgrade --out $OutApk $built }
Invoke-Step 'apksigner verify' { & $apksigner verify --verbose --print-certs $OutApk }
Invoke-Step 'aapt2 dump badging' { & $aapt2 dump badging $OutApk | Select-String -Pattern '^(package|sdkVersion|targetSdkVersion|uses-permission|application-debuggable|launchable-activity)' }
Write-Output "old apk: $OutApk ($((Get-Item $OutApk).Length) bytes, sha256 $((Get-FileHash $OutApk -Algorithm SHA256).Hash.ToLower()))"
