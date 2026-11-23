# M1 migration spike: creates two throwaway PKCS12 test keystores OUTSIDE the repository.
#   upgrade.p12   signs both the controlled old Capacitor APK and the Godot spike APK (same lineage)
#   wrongkey.p12  signs the negative-case spike APK that must fail to update the old app
# Random passwords are written to <OutDir>\secrets.env.ps1 (dot-source it before the build scripts).
# Never commit anything this script writes.
param(
  [Parameter(Mandatory = $true)][string]$OutDir,
  [Parameter(Mandatory = $true)][string]$JavaHome
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..\..')).Path
$out = [System.IO.Path]::GetFullPath($OutDir)
if ($out.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)) { throw "keystores must be created outside the repository ($repo)" }
New-Item -ItemType Directory -Force $out | Out-Null
$keytool = Join-Path $JavaHome 'bin\keytool.exe'
function New-Secret { -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) }) }
$lines = @()
foreach ($k in @(
    @{ File = 'upgrade.p12'; Alias = 'sv_m1_upgrade'; Var = 'SV_M1_UPGRADE_PASS'; DN = 'CN=SV M1 spike controlled lineage (test only), O=test' },
    @{ File = 'wrongkey.p12'; Alias = 'sv_m1_wrongkey'; Var = 'SV_M1_WRONGKEY_PASS'; DN = 'CN=SV M1 spike wrong key (test only), O=test' })) {
  $path = Join-Path $out $k.File
  if (Test-Path $path) { throw "$path already exists" }
  $pass = New-Secret
  & $keytool -genkeypair -storetype PKCS12 -keystore $path -storepass $pass -keypass $pass -alias $k.Alias `
    -keyalg RSA -keysize 2048 -validity 3650 -dname $k.DN -noprompt
  if ($LASTEXITCODE -ne 0) { throw "keytool failed for $($k.File)" }
  $lines += "`$env:$($k.Var) = '$pass'"
  Write-Output "created $($k.File) (alias $($k.Alias))"
}
$lines | Set-Content -Encoding utf8 (Join-Path $out 'secrets.env.ps1')
Write-Output 'passwords written to secrets.env.ps1 next to the keystores (not printed)'
