# M1 migration spike: the controlled upgrade test on one emulator/device (adb), in this order:
#   1. install the old Capacitor APK (normal install) and record package, version, certificate;
#   2. seed the five keys through the old app's own WebView runtime (DevTools), let its boot
#      migrate the v1 campaign, restart it cold and read the expected raw values back
#      (-SeedMode direct, for a WebView the old game cannot boot on: the five strings of
#      -DirectSeedValues are written with setItem in the old app's page instead);
#   3. negative: a spike APK signed with a different key must fail to update the old app;
#   4. negative: a spike APK with a different package id must not see the old store;
#   5. genuine upgrade with `adb install -r` (no uninstall, no data clearing, same package);
#   6. two spike runs (two reads each): every key's raw value must equal the old app's; then
#      termination during an active (held) read, by Godot quitting and by the Activity finishing
#      (its real onDestroy): the read is cancelled, its WebView destroyed on the UI thread, nothing emitted,
#      no crash; a third run still reads the identical values;
#   7. run-as listing: no production save written, the WebView profile still present;
#   8. negative: after uninstall, a fresh install of the spike must report not_found.
# Writes every command's output under -OutDir and checks.json; exit 1 if any check fails.
param(
  [Parameter(Mandatory = $true)][string]$Adb,
  [Parameter(Mandatory = $true)][string]$Serial,
  [Parameter(Mandatory = $true)][string]$AndroidSdk,
  [Parameter(Mandatory = $true)][string]$OldApk,
  [Parameter(Mandatory = $true)][string]$SpikeApk,
  [Parameter(Mandatory = $true)][string]$WrongKeyApk,
  [Parameter(Mandatory = $true)][string]$WrongPackageApk,
  [Parameter(Mandatory = $true)][string]$WrongPackage,
  [Parameter(Mandatory = $true)][string]$OutDir,
  [int]$DevToolsPort = 9333,
  [ValidateSet('game-migration', 'direct')][string]$SeedMode = 'game-migration',
  [string]$DirectSeedValues = ''
)
$ErrorActionPreference = 'Stop'
$pkg = 'com.zampano.supervillained'
$tools = $PSScriptRoot
$tool = Join-Path $tools 'm1_spike_tool.mjs'
New-Item -ItemType Directory -Force $OutDir | Out-Null
$bt = Get-ChildItem (Join-Path $AndroidSdk 'build-tools') | Sort-Object Name | Select-Object -Last 1
$apksigner = Join-Path $bt.FullName 'apksigner.bat'
$checks = [System.Collections.Generic.List[object]]::new()
$log = Join-Path $OutDir 'commands.txt'

function Out-Step([string]$name, $lines) {
  $text = ($lines | ForEach-Object { "$_" }) -join "`n"
  Set-Content -Encoding utf8 (Join-Path $OutDir "$name.txt") $text
  return $text
}
function Invoke-Adb([string[]]$a) {
  Add-Content -Encoding utf8 $log ("adb -s <serial> " + ($a -join ' '))
  $o = & $Adb -s $Serial @a 2>&1 | ForEach-Object { "$_" }
  Add-Content -Encoding utf8 $log "  exit $LASTEXITCODE"
  return , $o
}
function Add-Check([string]$name, [bool]$ok, $detail = $null) {
  $checks.Add([ordered]@{ name = $name; ok = $ok; detail = $detail })
  Write-Host ("{0} {1}{2}" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), $name, $(if ($null -ne $detail) { " ($detail)" } else { '' }))
}
function Invoke-Node([string[]]$a) {
  Add-Content -Encoding utf8 $log ("node m1_spike_tool.mjs " + ($a -join ' '))
  $o = & node $tool @a 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE
  Add-Content -Encoding utf8 $log "  exit $code"
  return @{ out = $o; code = $code }
}
function Get-PackageState([string]$p, [string]$name) {
  $d = Invoke-Adb @('shell', 'dumpsys', 'package', $p)
  $lines = $d | Select-String -Pattern 'versionCode=|versionName=|firstInstallTime=|lastUpdateTime=|signatures=|pkgFlags=|dataDir=' | ForEach-Object { $_.Line.Trim() }
  Out-Step $name $lines | Out-Null
  $vc = ([regex]::Match(($lines -join ' '), 'versionCode=(\d+)')).Groups[1].Value
  $fi = ([regex]::Match(($lines -join ' '), 'firstInstallTime=([0-9: -]+)')).Groups[1].Value.Trim()
  $lu = ([regex]::Match(($lines -join ' '), 'lastUpdateTime=([0-9: -]+)')).Groups[1].Value.Trim()
  return @{ versionCode = $vc; firstInstall = $fi; lastUpdate = $lu }
}
function Get-InstalledCert([string]$p, [string]$name) {
  $path = ((Invoke-Adb @('shell', 'pm', 'path', $p)) | Select-String '^package:' | Select-Object -First 1).Line.Substring(8).Trim()
  $local = Join-Path $OutDir "$name.base.apk"
  # Large APKs (the spike is ~277 MB) can fail to pull on a busy emulator transport: retry. Android 7
  # does not let adb pull read /data/app directly: from attempt 2 the APK is copied through
  # /data/local/tmp first (and removed again).
  $pullLog = @()
  for ($i = 1; $i -le 4; $i++) {
    if (Test-Path $local) { Remove-Item -Force $local }
    $pullLog += "pull attempt $i"
    if ($i -eq 1) {
      $pullLog += Invoke-Adb @('pull', $path, $local)
    } else {
      $pullLog += Invoke-Adb @('shell', 'cp', $path, '/data/local/tmp/m1_spike_base.apk')
      $pullLog += Invoke-Adb @('pull', '/data/local/tmp/m1_spike_base.apk', $local)
      $pullLog += Invoke-Adb @('shell', 'rm', '-f', '/data/local/tmp/m1_spike_base.apk')
    }
    if ((Test-Path $local) -and ((Get-Item $local).Length -gt 0)) {
      & $apksigner verify $local 2>&1 | Out-Null
      if ($LASTEXITCODE -eq 0) { break }
    }
    Start-Sleep 5
  }
  Out-Step "$name.pull" $pullLog | Out-Null
  $certs = & $apksigner verify --print-certs $local 2>&1 | ForEach-Object { "$_" }
  Out-Step $name $certs | Out-Null
  Remove-Item -Force $local
  return ([regex]::Match(($certs -join "`n"), 'certificate SHA-256 digest: ([0-9a-f]+)')).Groups[1].Value
}
function Start-OldApp([string]$label) {
  Invoke-Adb @('shell', 'am', 'force-stop', $pkg) | Out-Null
  Out-Step "$label.am_start" (Invoke-Adb @('shell', 'am', 'start', '-W', '-n', "$pkg/.MainActivity")) | Out-Null
  $appPid = ''
  for ($i = 0; $i -lt 30 -and -not $appPid; $i++) { Start-Sleep 1; $appPid = ((Invoke-Adb @('shell', 'pidof', $pkg)) -join '').Trim() }
  $sock = "webview_devtools_remote_$appPid"
  for ($i = 0; $i -lt 40; $i++) {
    if ((Invoke-Adb @('shell', 'cat', '/proc/net/unix')) -match $sock) { break }
    Start-Sleep 1
  }
  Invoke-Adb @('forward', '--remove-all') | Out-Null
  Invoke-Adb @('forward', "tcp:$DevToolsPort", "localabstract:$sock") | Out-Null
  return $appPid
}
function Invoke-Cdp([string]$script, [string]$out) {
  $path = if ([System.IO.Path]::IsPathRooted($script)) { $script } else { Join-Path $tools $script }
  for ($i = 0; $i -lt 30; $i++) {
    $r = Invoke-Node @('cdp', "$DevToolsPort", $path, $out)
    if ($r.code -eq 0) { return $r }
    Start-Sleep 1
  }
  throw "DevTools evaluation of $script failed: $($r.out -join ' ')"
}
function Stop-Gracefully([string]$p) {
  Invoke-Adb @('shell', 'input', 'keyevent', 'KEYCODE_HOME') | Out-Null
  Start-Sleep 5
  Invoke-Adb @('shell', 'am', 'force-stop', $p) | Out-Null
}
function Get-LaunchComponent([string]$p) {
  $c = ((Invoke-Adb @('shell', 'cmd', 'package', 'resolve-activity', '--brief', '-c', 'android.intent.category.LAUNCHER', $p)) | Select-Object -Last 1).Trim()
  if ($c -notmatch '^[\w.]+/[\w.$]+$') { $c = "$p/com.godot.game.GodotAppLauncher" }  # older `cmd package` without resolve-activity
  return $c
}
function Invoke-SpikeRun([string]$p, [string]$label, [string]$expectStatus) {
  Invoke-Adb @('shell', 'am', 'force-stop', $p) | Out-Null
  Invoke-Adb @('logcat', '-c') | Out-Null
  $comp = Get-LaunchComponent $p
  Out-Step "$label.am_start" (Invoke-Adb @('shell', 'am', 'start', '-W', '-n', $comp)) | Out-Null
  $done = $false
  for ($i = 0; $i -lt 120 -and -not $done; $i++) {
    Start-Sleep 1
    $done = [bool]((Invoke-Adb @('logcat', '-d', '-v', 'raw', '-s', 'godot')) -match 'M1_SPIKE_DONE')
  }
  Out-Step "$label.logcat" (Invoke-Adb @('logcat', '-d', '-v', 'threadtime', '-s', 'godot', 'SvMigrationSpike')) | Out-Null
  $raw = Join-Path $OutDir "$label.godot_raw.txt"
  Out-Step "$label.godot_raw" (Invoke-Adb @('logcat', '-d', '-v', 'raw', '-s', 'godot')) | Out-Null
  Add-Check "$label`: harness finished (M1_SPIKE_DONE)" $done
  $parsed = Join-Path $OutDir "$label.parsed.json"
  $r = Invoke-Node @('parse-log', $raw, $parsed)
  Out-Step "$label.parse" $r.out | Out-Null
  $c = Invoke-Node @('compare', (Join-Path $OutDir 'expected.json'), $parsed, $expectStatus, (Join-Path $OutDir "$label.compare.json"))
  Out-Step "$label.compare" $c.out | Out-Null
  Add-Check "$label`: every attempt $expectStatus and matches the old app's values" ($c.code -eq 0) ($c.out | Select-Object -First 1)
  return $parsed
}

function Invoke-LifecycleTest([string]$label, [string]$flag, [string]$how) {
  Invoke-Adb @('shell', 'am', 'force-stop', $pkg) | Out-Null
  Out-Step "$label.flag_create" (Invoke-Adb @('shell', 'run-as', $pkg, 'touch', "files/$flag")) | Out-Null
  Invoke-Adb @('logcat', '-c') | Out-Null
  Out-Step "$label.am_start" (Invoke-Adb @('shell', 'am', 'start', '-W', '-n', (Get-LaunchComponent $pkg))) | Out-Null
  $active = $false
  for ($i = 0; $i -lt 60 -and -not $active; $i++) { Start-Sleep 1; $active = [bool]((Invoke-Adb @('logcat', '-d', '-v', 'raw', '-s', 'godot')) -match 'M1_SPIKE_LIFECYCLE_ACTIVE') }
  $cancelled = $false
  for ($i = 0; $i -lt 30 -and -not $cancelled; $i++) { Start-Sleep 1; $cancelled = [bool]((Invoke-Adb @('logcat', '-d', '-v', 'raw', '-s', 'SvMigrationSpike')) -match 'cancelled active read') }
  Start-Sleep 23  # past the 20 s hold: a late page or script callback would show now
  $godot = Out-Step "$label.godot_raw" (Invoke-Adb @('logcat', '-d', '-v', 'raw', '-s', 'godot'))
  $plugin = Out-Step "$label.plugin_raw" (Invoke-Adb @('logcat', '-d', '-v', 'raw', '-s', 'SvMigrationSpike'))
  Out-Step "$label.logcat" (Invoke-Adb @('logcat', '-d', '-v', 'threadtime', '-s', 'godot', 'SvMigrationSpike', 'AndroidRuntime')) | Out-Null
  $crash = Out-Step "$label.crash_buffer" (Invoke-Adb @('logcat', '-d', '-b', 'crash'))
  Out-Step "$label.flag_remove" (Invoke-Adb @('shell', 'run-as', $pkg, 'rm', '-f', "files/$flag")) | Out-Null
  $reason = ([regex]::Match($plugin, '(godot_terminating|activity_destroy): cancelled active read')).Groups[1].Value
  Add-Check "$label`: the harness started a held read that was still active" ($active -and ($godot -match '"result_received":false'))
  Add-Check "$label`: the plugin cancelled the active read on termination ($how)" $cancelled $reason
  Add-Check "$label`: timeout cancelled and WebView destroyed on the UI (main) thread" ($plugin -match 'teardown of generation \d+ \(lifecycle (godot_terminating|activity_destroy)\): timeout cancelled, WebView destroyed on thread main')
  Add-Check "$label`: nothing emitted for the cancelled read, no result reached GDScript" (-not ($plugin -match 'emit attempt') -and -not ($godot -match 'M1_SPIKE_LIFECYCLE_RESULT_RECEIVED|M1_SPIKE_DONE'))
  Add-Check "$label`: no crash (crash buffer has no $pkg entry)" (-not ($crash -match [regex]::Escape($pkg)))
  Out-Step "$label.late_callbacks" ($plugin -split "`n" | Select-String 'ignored late|no active read' | ForEach-Object { $_.Line }) | Out-Null
}

# 0. Environment.
$props = foreach ($p in 'ro.product.model', 'ro.build.version.release', 'ro.build.version.sdk', 'ro.build.fingerprint', 'ro.kernel.qemu', 'ro.product.cpu.abilist') { "$p=" + ((Invoke-Adb @('shell', 'getprop', $p)) -join '') }
Out-Step '00_device' $props | Out-Null
$wvLines = @((Invoke-Adb @('shell', 'dumpsys', 'webviewupdate')) | Select-String 'Current WebView package|Minimum targetSdkVersion|WebView package dirty' | ForEach-Object { $_.Line.Trim() })
# The active provider (Android 7 can use Chrome) and its version, then the WebView package itself.
$provider = ((Invoke-Adb @('shell', 'settings', 'get', 'global', 'webview_provider')) -join '').Trim()
$wvLines += "settings global webview_provider: $provider"
foreach ($wp in @($provider, 'com.google.android.webview') | Where-Object { $_ -match '^[\w.]+$' } | Select-Object -Unique) {
  $wvLines += "$wp " + (((Invoke-Adb @('shell', 'dumpsys', 'package', $wp)) | Select-String 'versionName=' | Select-Object -First 1).Line.Trim())
}
Out-Step '00_webview' $wvLines | Out-Null
$present = (Invoke-Adb @('shell', 'pm', 'list', 'packages')) | Select-String -Pattern "package:$([regex]::Escape($pkg))(\.|$)"
Add-Check 'precondition: no com.zampano.supervillained* package installed' (-not $present) ($present -join ', ')
if ($present) { throw 'remove the test packages from the device first' }

# 1. Old Capacitor app, normal install.
$o = Out-Step '01_install_old' (Invoke-Adb @('install', $OldApk))
Add-Check 'old APK installs (normal install)' ($o -match 'Success')
$old = Get-PackageState $pkg '01_old_package_state'
Add-Check 'old app versionCode 1' ($old.versionCode -eq '1') $old.versionCode
$oldCert = Get-InstalledCert $pkg '01_old_installed_certs'
Add-Check 'old app installed certificate recorded' ([bool]$oldCert) $oldCert

# 2. Seed through the old runtime; expected values after a cold restart.
$appPid = Start-OldApp '02_old_launch_1'
Invoke-Cdp 'legacy_read.js' (Join-Path $OutDir '02_old_read_before_seed.json') | Out-Null
$r0 = (Get-Content -Raw (Join-Path $OutDir '02_old_read_before_seed.json') | ConvertFrom-Json).value
Add-Check 'old app origin is https://localhost' ($r0.origin -eq 'https://localhost') $r0.origin
Add-Check 'fresh old app: no supervillained key before seeding' ($r0.prefixed_keys.Count -eq 0)
if ($SeedMode -eq 'direct') {
  # The old game cannot boot on this WebView (see 02_old_capacitor_logcat.txt): write the five
  # strings it produced elsewhere with setItem in the old app's own page (origin checked above).
  $vals = (Get-Content -Raw $DirectSeedValues | ConvertFrom-Json).keys
  $map = [ordered]@{}
  foreach ($k in 'settings', 'records', 'coins', 'story', 'story-v1-backup') { $map[$k] = $vals.$k.raw }
  $js = "(() => { const values = " + (ConvertTo-Json $map -Compress) + "; const keys = Object.keys(values); " +
    "if (keys.some((k) => localStorage.getItem('supervillained:' + k) !== null)) throw new Error('seed refused: a supervillained key already exists'); " +
    "for (const k of keys) localStorage.setItem('supervillained:' + k, values[k]); return { written: keys, origin: location.origin }; })()"
  $seedJs = Join-Path $OutDir '02_seed_direct.js'
  [System.IO.File]::WriteAllText($seedJs, $js, [System.Text.UTF8Encoding]::new($false))
  Invoke-Cdp $seedJs (Join-Path $OutDir '02_old_seed.json') | Out-Null
} else {
  Invoke-Cdp 'legacy_seed.js' (Join-Path $OutDir '02_old_seed.json') | Out-Null
}
Invoke-Cdp 'legacy_reload.js' (Join-Path $OutDir '02_old_reload.json') | Out-Null
Start-Sleep 12
Invoke-Cdp 'legacy_read.js' (Join-Path $OutDir '02_old_read_after_boot.json') | Out-Null
$r1 = (Get-Content -Raw (Join-Path $OutDir '02_old_read_after_boot.json') | ConvertFrom-Json).value
Out-Step '02_old_capacitor_logcat' (Invoke-Adb @('logcat', '-d', '-v', 'threadtime', '-s', 'Capacitor', 'Capacitor/Console')) | Out-Null
if ($SeedMode -eq 'direct') {
  $same = $true
  foreach ($k in $map.Keys) { if ($r1.keys.$k -cne $map[$k]) { $same = $false } }
  Add-Check 'direct seed: the five strings read back unchanged after the old app reloaded' $same
} else {
  Add-Check 'old boot migrated the campaign: story is version 2' (($r1.keys.story | ConvertFrom-Json).version -eq 2)
  Add-Check 'old boot kept the v1 campaign under story-v1-backup' (($r1.keys.'story-v1-backup' | ConvertFrom-Json).version -eq 1)
}
Add-Check 'exactly the five supervillained keys exist' (($r1.prefixed_keys -join ',') -eq 'supervillained:coins,supervillained:records,supervillained:settings,supervillained:story,supervillained:story-v1-backup') ($r1.prefixed_keys -join ',')
Start-Sleep 15
Stop-Gracefully $pkg
$appPid = Start-OldApp '02_old_launch_2_cold'
Invoke-Cdp 'legacy_read.js' (Join-Path $OutDir '02_old_read_after_cold_restart.json') | Out-Null
$r2 = (Get-Content -Raw (Join-Path $OutDir '02_old_read_after_cold_restart.json') | ConvertFrom-Json).value
Add-Check 'old values persist across a cold restart (identical)' ((ConvertTo-Json $r2.keys -Compress) -eq (ConvertTo-Json $r1.keys -Compress))
$e = Invoke-Node @('expected', (Join-Path $OutDir '02_old_read_after_cold_restart.json'), (Join-Path $OutDir 'expected.json'))
Out-Step '02_expected_hashes' $e.out | Out-Null
Add-Check 'expected values and hashes recorded' ($e.code -eq 0)
Stop-Gracefully $pkg
Invoke-Adb @('forward', '--remove-all') | Out-Null

# 3. Negative: same package, different signing key, must not update the old app.
$o = Out-Step '03_install_wrong_key' (Invoke-Adb @('install', '-r', $WrongKeyApk))
Add-Check 'wrong-key update rejected (INSTALL_FAILED_UPDATE_INCOMPATIBLE)' (($o -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') -and -not ($o -match '(?m)^Success')) (($o -split "`n" | Select-String 'INSTALL_FAILED' | Select-Object -First 1).Line)
$afterWrong = Get-PackageState $pkg '03_package_state_after_wrong_key'
Add-Check 'old app untouched after the rejected update' (($afterWrong.versionCode -eq '1') -and ($afterWrong.lastUpdate -eq $old.lastUpdate)) "$($afterWrong.versionCode) $($afterWrong.lastUpdate)"

# 4. Negative: different package id, same key, with the old store present.
$o = Out-Step '04_install_wrong_package' (Invoke-Adb @('install', $WrongPackageApk))
Add-Check "wrong-package spike ($WrongPackage) installs beside the old app" ($o -match 'Success')
Invoke-SpikeRun $WrongPackage '04_wrong_package_run' 'not_found' | Out-Null
Out-Step '04_uninstall_wrong_package' (Invoke-Adb @('uninstall', $WrongPackage)) | Out-Null

# 5. Genuine in-place upgrade.
$o = Out-Step '05_install_r_spike' (Invoke-Adb @('install', '-r', $SpikeApk))
Add-Check 'adb install -r of the spike APK succeeds' ($o -match 'Success')
$new = Get-PackageState $pkg '05_spike_package_state'
Add-Check 'upgraded in place: versionCode 2, same firstInstallTime, new lastUpdateTime' (($new.versionCode -eq '2') -and ($new.firstInstall -eq $old.firstInstall) -and ($new.lastUpdate -ne $old.lastUpdate)) "$($new.versionCode) first $($new.firstInstall) last $($new.lastUpdate)"
$newCert = Get-InstalledCert $pkg '05_spike_installed_certs'
Add-Check 'same signing certificate before and after the upgrade' ($newCert -eq $oldCert) $newCert

# 6. Two spike runs (separate processes), two reads each.
$run1 = Invoke-SpikeRun $pkg '06_spike_run_1' 'success'
$run2 = Invoke-SpikeRun $pkg '06_spike_run_2' 'success'
$keysOf = { param($f) $j = Get-Content -Raw $f | ConvertFrom-Json; ConvertTo-Json -Compress -Depth 5 @($j.attempts.'1'.keys, $j.attempts.'2'.keys) }
Add-Check 'repeated reads identical across two processes (run 1 and run 2, four reads)' ((& $keysOf $run1) -eq (& $keysOf $run2))

# 6b. Termination during an active read, then the store is still intact.
Invoke-LifecycleTest '06b_lifecycle_quit_during_read' 'm1_lifecycle_quit.flag' 'godot_quit'
Invoke-LifecycleTest '06c_lifecycle_activity_finished_during_read' 'm1_lifecycle_finish.flag' 'activity_finish'
$run3 = Invoke-SpikeRun $pkg '06d_spike_run_3_after_lifecycle' 'success'
Add-Check 'reads after the lifecycle tests identical to run 1' ((& $keysOf $run1) -eq (& $keysOf $run3))

# 7. No production save; the WebView profile is still there.
$files = Out-Step '07_run_as_files' (Invoke-Adb @('shell', 'run-as', $pkg, 'ls', '-la', 'files'))
Add-Check 'no production save written (no save_v3 file in user://)' (-not ($files -match 'save_v3'))
$wv = Out-Step '07_run_as_webview' (Invoke-Adb @('shell', 'run-as', $pkg, 'ls', '-la', 'app_webview', 'app_webview/Default'))
Add-Check 'WebView profile with Local Storage still present after the reads' ($wv -match 'Local Storage')

# 8. Negative: fresh install (no old store) reports not_found.
Out-Step '08_uninstall' (Invoke-Adb @('uninstall', $pkg)) | Out-Null
$o = Out-Step '08_install_fresh_spike' (Invoke-Adb @('install', $SpikeApk))
Add-Check 'fresh install of the spike APK' ($o -match 'Success')
$fresh = Invoke-SpikeRun $pkg '08_fresh_install_run' 'not_found'
$fd = (Get-Content -Raw $fresh | ConvertFrom-Json).attempts.'1'.diagnostics
Add-Check 'fresh install: no WebView profile existed before the first read' ($fd.webview_data_dir_existed_before_read -eq $false) "$($fd.webview_data_dir_existed_before_read)"
Out-Step '08_uninstall_after' (Invoke-Adb @('uninstall', $pkg)) | Out-Null

$ok = -not ($checks | Where-Object { -not $_.ok })
$checks | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $OutDir 'checks.json')
Write-Output ("RESULT: {0} ({1}/{2} checks passed)" -f ($(if ($ok) { 'PASS' } else { 'FAIL' })), ($checks | Where-Object { $_.ok }).Count, $checks.Count)
if (-not $ok) { exit 1 }
