# Rebuilds (or with -Check verifies) every generated asset of the Godot port on Windows.
# Usage from the repository root:
#   pwsh godot/tools/build_assets.ps1 -Godot 'C:\Godot\Godot_v4.7.2-stable_win64_console.exe' [-Check]
# Needs the pinned Node (godot/tools/.node-version) on PATH and `npm ci` for Playwright.
param(
  [Parameter(Mandatory = $true)][string]$Godot,
  [switch]$Check
)
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..')
function Run([string]$exe, [string[]]$argv) {
  & $exe @argv
  if ($LASTEXITCODE -ne 0) { throw "$exe $($argv -join ' ') failed with exit code $LASTEXITCODE" }
}
$extract = @('--experimental-transform-types', '--no-warnings', '--import', './godot/tools/source_extract/register.mjs', 'godot/tools/source_extract/extract.mjs')
if ($Check) { $extract += '--check' }
Run 'node' $extract
Run $Godot @('--headless', '--path', 'godot', '--import')
if ($Check) {
  Run $Godot @('--headless', '--path', 'godot', '--script', 'res://tools/build_resources.gd', '--', '--phase', 'all', '--check')
} else {
  Run $Godot @('--headless', '--path', 'godot', '--script', 'res://tools/build_resources.gd', '--', '--phase', 'images')
  Run $Godot @('--headless', '--path', 'godot', '--import')
  Run $Godot @('--headless', '--path', 'godot', '--script', 'res://tools/build_resources.gd', '--', '--phase', 'resources')
  Run $Godot @('--headless', '--path', 'godot', '--import')
}
