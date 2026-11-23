# M1 migration spike: builds the Godot spike APK (gradle build, debug export) from a scratch copy
# of a godot/ project tree. The committed project is not changed: the scratch copy drops
# platform/android/.gdignore, enables the spike's editor plugin, makes the harness the main scene,
# switches the Android preset to a gradle build with x86_64 (the emulator) and, optionally, a
# different package id (negative case). The spike JAR is compiled with javac against the Android
# platform jar and the Godot 4.7.2 template library (compile-only).
# Env: the keystore password in the variable named by -PassEnv (dot-source secrets.env.ps1 first).
param(
  [Parameter(Mandatory = $true)][string]$GodotProject,
  [Parameter(Mandatory = $true)][string]$WorkDir,
  [Parameter(Mandatory = $true)][string]$GodotExe,
  [Parameter(Mandatory = $true)][string]$TemplatesDir,
  [Parameter(Mandatory = $true)][string]$AndroidSdk,
  [Parameter(Mandatory = $true)][string]$JavaHome,
  [Parameter(Mandatory = $true)][string]$GradleUserHome,
  [Parameter(Mandatory = $true)][string]$JavaTmpDir,
  [Parameter(Mandatory = $true)][string]$Keystore,
  [Parameter(Mandatory = $true)][string]$KeyAlias,
  [Parameter(Mandatory = $true)][string]$PassEnv,
  [Parameter(Mandatory = $true)][string]$OutApk,
  [string]$Package = 'com.zampano.supervillained'
)
$ErrorActionPreference = 'Stop'
$pass = [Environment]::GetEnvironmentVariable($PassEnv)
if (-not $pass) { throw "$PassEnv is not set" }
if (Test-Path $WorkDir) { throw "$WorkDir exists; use a fresh directory" }
New-Item -ItemType Directory -Force $WorkDir, $JavaTmpDir, (Split-Path $OutApk) | Out-Null
$env:JAVA_TOOL_OPTIONS = "-Djdk.net.unixdomain.tmpdir=$JavaTmpDir -Djava.io.tmpdir=$JavaTmpDir"
# No lingering Gradle daemon (it would hold Godot's output pipe open after the export).
$env:GRADLE_OPTS = '-Dorg.gradle.daemon=false'
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
$spikeRel = 'platform\android\m1_migration_spike'
$spikeSrc = Join-Path $GodotProject $spikeRel

# 1. The spike JAR (javac --release 17, compile-only against android.jar and the Godot library).
Add-Type -AssemblyName System.IO.Compression.FileSystem
$jarWork = Join-Path $WorkDir 'jar'
New-Item -ItemType Directory -Force "$jarWork\classes" | Out-Null
$zip = [System.IO.Compression.ZipFile]::OpenRead((Join-Path $TemplatesDir 'android_source.zip'))
try {
  $entry = $zip.GetEntry('libs/debug/godot-lib.template_debug.aar')
  [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, "$jarWork\godot-lib.aar", $true)
} finally { $zip.Dispose() }
$aar = [System.IO.Compression.ZipFile]::OpenRead("$jarWork\godot-lib.aar")
try {
  [System.IO.Compression.ZipFileExtensions]::ExtractToFile($aar.GetEntry('classes.jar'), "$jarWork\godot-classes.jar", $true)
} finally { $aar.Dispose() }
$androidJar = Join-Path $AndroidSdk 'platforms\android-36\android.jar'
$sources = Get-ChildItem -Recurse (Join-Path $spikeSrc 'native\src') -Filter *.java | ForEach-Object FullName
Invoke-Step 'javac' { & "$JavaHome\bin\javac.exe" --release 17 -Xlint:all -encoding UTF-8 -cp "$androidJar;$jarWork\godot-classes.jar" -d "$jarWork\classes" $sources }
$jar = Join-Path $jarWork 'sv_m1_migration_spike.jar'
Invoke-Step 'jar' { & "$JavaHome\bin\jar.exe" --create --file $jar -C "$jarWork\classes" . }
Invoke-Step 'jar list' { & "$JavaHome\bin\jar.exe" --list --file $jar }

# 2. Scratch copy of the project (no import cache).
$proj = Join-Path $WorkDir 'project'
robocopy $GodotProject $proj /E /XD .godot /NFL /NDL /NJH /NJS /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE)" }
Remove-Item -Force (Join-Path $proj 'platform\android\.gdignore')
New-Item -ItemType Directory -Force (Join-Path $proj "$spikeRel\editor\bin") | Out-Null
Copy-Item $jar (Join-Path $proj "$spikeRel\editor\bin\sv_m1_migration_spike.jar")

# 3. Scratch-only settings: main scene = harness, spike editor plugin enabled.
$pg = Join-Path $proj 'project.godot'
$text = [System.IO.File]::ReadAllText($pg)
if ($text.Contains('[editor_plugins]')) { throw 'project.godot already has [editor_plugins]' }
$mainOld = 'run/main_scene="res://main/main.tscn"'
if (-not $text.Contains($mainOld)) { throw 'unexpected run/main_scene' }
$text = $text.Replace($mainOld, 'run/main_scene="res://platform/android/m1_migration_spike/harness/m1_spike_harness.tscn"')
$text = $text.TrimEnd() + "`n`n[editor_plugins]`n`nenabled=PackedStringArray(`"res://platform/android/m1_migration_spike/editor/plugin.cfg`")`n"
[System.IO.File]::WriteAllText($pg, $text)

# 4. Scratch-only Android preset: gradle build, x86_64 for the emulator, package id.
$ep = Join-Path $proj 'export_presets.cfg'
$cfg = [System.IO.File]::ReadAllText($ep)
foreach ($pair in @(
    @('gradle_build/use_gradle_build=false', 'gradle_build/use_gradle_build=true'),
    @('architectures/x86_64=false', 'architectures/x86_64=true'),
    @('package/unique_name="com.zampano.supervillained"', "package/unique_name=`"$Package`""))) {
  if (-not $cfg.Contains($pair[0])) { throw "export preset lacks $($pair[0])" }
  $cfg = $cfg.Replace($pair[0], $pair[1])
}
[System.IO.File]::WriteAllText($ep, $cfg)
Write-Output 'scratch project.godot / export_presets.cfg differences from the source tree:'
git --no-pager diff --no-index --stat -- (Join-Path $GodotProject 'project.godot') $pg
git --no-pager diff --no-index -U0 -- (Join-Path $GodotProject 'export_presets.cfg') $ep | Select-String -Pattern '^[+-][a-z]'

# 5. Import, install the gradle build template, export (debug, signed with the given test key).
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PATH = $Keystore
$env:GODOT_ANDROID_KEYSTORE_DEBUG_USER = $KeyAlias
$env:GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD = $pass
Invoke-Step 'godot import' { & $GodotExe --headless --path $proj --import }
Invoke-Step 'godot export (gradle, debug)' { & $GodotExe --headless --path $proj --install-android-build-template --export-debug Android $OutApk }

# 6. What was built.
$bt = Get-ChildItem (Join-Path $AndroidSdk 'build-tools') | Sort-Object Name | Select-Object -Last 1
Invoke-Step 'apksigner verify' { & (Join-Path $bt.FullName 'apksigner.bat') verify --verbose --print-certs $OutApk }
Invoke-Step 'aapt2 dump badging' { & (Join-Path $bt.FullName 'aapt2.exe') dump badging $OutApk | Select-String -Pattern '^(package|sdkVersion|targetSdkVersion|uses-permission|application-debuggable|launchable-activity|native-code)' }
Write-Output "spike apk: $OutApk ($((Get-Item $OutApk).Length) bytes, sha256 $((Get-FileHash $OutApk -Algorithm SHA256).Hash.ToLower()))"
