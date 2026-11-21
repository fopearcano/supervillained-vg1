# Linux host evidence for commit d12bedd

Fresh `git clone` of `d12bedd` inside WSL 2 (Ubuntu 26.04 LTS) on the project owner's Windows PC,
run by a local Claude Code session on 2026-11-21. **Result: every step exited 0.** The tested tree
is exactly `d12bedd`.

## Environment

| Item | Value |
|---|---|
| Linux | Ubuntu 26.04 LTS, kernel 6.18.33.2-microsoft-standard-WSL2, x86_64 (WSL 2) |
| Git | distro git, `core.autocrlf` unset (LF checkout) |
| Godot | official `Godot_v4.7.2-stable_linux.x86_64` (4.7.2.stable.official.ed1daf0bf), portable copy in the user's home, SHA-512 checked against the release's `SHA512-SUMS.txt` |
| Node / npm | official `node-v24.15.0-linux-x64` tarball (SHA-256 checked against `SHASUMS256.txt`), npm 11.12.1 |
| Playwright / Chromium | 1.63.0 / 153.0.8010.12 (revision 1243, pinned), installed by `npx playwright install chromium` |
| Chromium system libraries | the distro had no `libnss3`, `libnspr4`, `libasound2t64`; the distro's own packages were fetched with `apt-get download` (package lists refreshed into a private directory, no root) and unpacked into the user's home, then given to the asset step via `LD_LIBRARY_PATH`. Nothing was installed on the system. |

## Steps (from the clone root, in this order)

| Step | Command | Exit | Result |
|---|---|---|---|
| a | `godot/tools/build_assets.sh --check <godot>` | 0 | `asset check OK: 206 outputs identical (72 copies) ...`; `build_resources check (all): OK, 55 outputs identical` (the same bytes as the Windows run, title atlas and synthesized WAVs included) |
| b | `<godot> --headless --path godot --import` | 0 | no ERROR/WARNING lines |
| c | `<godot> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | **128 passed, 0 failed** |
| d | `<godot> --headless --path godot --quit-after 600` | 0 | engine banner only |
| e | `git status --porcelain` | 0 | empty |
| guard | `bash godot/tools/source_tree_guard.sh` | 0 | only `/godot` and `docs/porting` differ from `95b69c0` |

Not run on Linux here: the rendered probes (no display in this WSL setup; they ran on the Windows
GPU) and the PixiJS checks (run on Windows for this commit).

## Logs in this folder

Each step's merged stdout/stderr as it ran; ANSI codes and carriage returns stripped, trailing
spaces and final blank lines removed, the user name and paths replaced by placeholders.
