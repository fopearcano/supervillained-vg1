# Windows host evidence for commit d12bedd

Fresh `git clone` of `d12bedd` (cloned from the local repository before the push; the commit SHA is
the one on the branch) with Git for Windows' default line endings (`core.autocrlf=true`), on the
project owner's Windows PC, run by a local Claude Code session on 2026-11-21. **Result: every
check step exited 0.** The tested tree is exactly
`d12bedd`; the commit that adds this folder changes only `docs/porting/`.

## Environment

| Item | Value |
|---|---|
| Windows | Windows 11 Pro N for Workstations 25H2, build 26200.8037 |
| GPU / audio | NVIDIA GeForce RTX 3090, driver 610.47, OpenGL 3.3 Compatibility; default WASAPI output device |
| PowerShell | official portable PowerShell 7.7.0 (SHA-256 verified), first on PATH for the run |
| Git | 2.54.0.windows.1, `core.autocrlf = true` |
| Node / npm | v24.15.0 / 11.12.1 (matches `godot/tools/.node-version`) |
| Godot | `4.7.2.stable.official.ed1daf0bf`, `Godot_v4.7.2-stable_win64_console.exe` |
| Playwright / Chromium | 1.63.0 / 153.0.8010.12 (revision 1243, pinned) |

## Steps (from the clone root, in this order)

| Step | Command | Exit | Result |
|---|---|---|---|
| a | `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | 0 | `asset check OK: 206 outputs identical (72 copies) ...`; `build_resources check (all): OK, 55 outputs identical` |
| b | `<console exe> --headless --path godot --import` | 0 | no ERROR/WARNING lines |
| c | `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | **128 passed, 0 failed** |
| d | `<console exe> --headless --path godot --quit-after 600` | 0 | engine banner only |
| e | `git status --porcelain` | 0 | empty |
| f | `<console exe> --path godot --rendering-driver opengl3 --script res://tools/interpolation_probe.gd` | 0 | VSync on: 30 and 60 FPS measured; the 90/120 caps run at about 60 FPS on this 60 Hz display, so this step is **not** a 90/120 measurement (on the identical run for `401e8e4` the probe's interpolation-off control showed no repeated frames at 60 FPS and the probe exited 1: inconclusive by design) |
| g | same with `--disable-vsync` | 0 | **30.0 / 60.0 / 90.4 / 120.6 FPS achieved, 0 repeated frames, no streak or double interpolation, teleport resets**; control (interpolation off, 120 FPS) shows the expected repeated frames; static markers stay 40 px apart under the following camera at 90 and 120 FPS |
| h | `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` | 0 | real audio device: live music and effects pause in the background, a late effect starts paused, everything resumes; clean exit |
| i | `npm test` (PixiJS source) | 0 | 30 files, **248 tests passed** |
| j | `npm run build` (PixiJS source) | 0 | TypeScript + Vite build OK |
| k | `git status --porcelain` after every step | 0 | empty |
| l | `bash godot/tools/source_tree_guard.sh` (Git Bash) | 0 | only `/godot` and `docs/porting` differ from `95b69c0` |
| m | `git diff --check 95b69c0 HEAD` | 0 | clean |

## Logs in this folder

Each step's merged stdout/stderr as it ran. The only edits: ANSI colour codes and carriage returns
stripped, trailing spaces and final blank lines removed, and the local user name, profile and
temporary paths replaced by placeholders (`%USERPROFILE%`, `<user>`, `<scratch>`).
`exit_codes.txt` has the exit code and duration of every step.
