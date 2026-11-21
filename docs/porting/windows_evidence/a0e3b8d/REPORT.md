# Windows host evidence for commit a0e3b8d

Real Windows run of the documented Windows commands for the Godot port, on a fresh clone with
Git for Windows' default line endings (`core.autocrlf=true`). Run on 2026-11-21 on the project
owner's Windows PC by a local Claude Code session. **Result: every step exited 0 and matched the expected
output.** This commit adds only this folder; no code, assets or other files were changed, and the
verified tree is exactly `a0e3b8d422635453f07036def81fb65f9812527c`.

## Environment

| Item | Value |
| --- | --- |
| Windows | Windows 11 Pro N for Workstations, version 25H2, build 26200.8037 (10.0.26200) |
| PowerShell | system has only Windows PowerShell 5.1.26100.7920; `pwsh` was not installed, so steps a–e ran from the official portable PowerShell 7.7.0 (`PowerShell-7.7.0-win-x64.zip`, SHA-256 `7C74E03B20A75B59715847439D046A6214B1863EE79B187872980F139BB4A05F`, matches the release's `hashes.sha256`), first on PATH for this run only, no profile scripts |
| Git | 2.54.0.windows.1, `core.autocrlf = true` (from `C:/Program Files/Git/etc/gitconfig`, the Git for Windows default) |
| Clone | `git clone --branch claude/gallant-keller-rbvtvy https://github.com/fopearcano/supervillained-vg1` into a new folder; `git log --oneline -1` = `a0e3b8d Godot port: third M1/M2 review corrections (M1 Partial, M2 Partial)` |
| Node | v24.15.0 (installed copy, matches `godot/tools/.node-version`); npm 11.12.1 |
| Godot | `4.7.2.stable.official.ed1daf0bf`, `Godot_v4.7.2-stable_win64_console.exe` already installed on the PC (not downloaded in this run, so not re-verified against `SHA512-SUMS.txt`) |
| `npm ci` | exit 0 (150 packages, 0 vulnerabilities) |
| `npx playwright install chromium` | exit 0, no output: `chromium-1243` was already in `%LOCALAPPDATA%\ms-playwright`; Playwright 1.63.0 |
| Chromium (from step a) | `Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)` |

## Steps (from the clone root, in this order)

| Step | Command | Exit | Time | Result |
| --- | --- | --- | --- | --- |
| a | `pwsh godot/tools/build_assets.ps1 -Godot '<console exe>' -Check` | 0 | 8 s | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)` … `build_resources check (all): OK, 7 outputs identical` |
| b | `& '<console exe>' --headless --path godot --import` | 0 | 3 s | no ERROR/WARNING lines |
| c | `& '<console exe>' --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | 38 s | `110 passed, 0 failed, 110 total (37.7 s), Godot 4.7.2-stable (official)` |
| d | `& '<console exe>' --headless --path godot --quit-after 600` | 0 | 11 s | only the engine banner; no ERROR/WARNING lines |
| e | `git status --porcelain` | 0 | – | empty (also empty when re-run afterwards) |

Notes:

- Step a: no `DIFFERS`/`MISSING`/`ERROR`/`WARNING` lines. The only text match for "error" is the
  import progress line `update_scripts_classes | ErrorCapture`, which names a script class.
- Step c: no `FAIL` lines and no engine errors. The only text matches for "error"/"fail" are the
  passing tests `test_MAP_001_parser_errors_match_source` and
  `test_SLICE_future_copy_failures_are_reported_and_writes_stay_blocked`.
- Step a reported no `DIFFERS`, so the non-`-Check` diagnosis run in a second copy was not needed.

## Logs in this folder

Each step's stdout and stderr were merged (`2>&1`) and saved as the step ran. The only edits are:
ANSI colour codes and carriage returns stripped, and the local user-profile path shown as
`%USERPROFILE%`.

- `step_a_build_assets_check.txt`
- `step_b_import.txt`
- `step_c_test_suite.txt`
- `step_d_main_600_frames.txt`
- `step_e_git_status.txt` (empty: no changes)
- `exit_codes.txt` (exit code and duration per step)
