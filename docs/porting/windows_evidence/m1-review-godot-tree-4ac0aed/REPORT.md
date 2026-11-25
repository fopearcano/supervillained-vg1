# Windows host checks: M1 manual-review station, `godot/` tree `4ac0aed`

Progress report 21 (`docs/porting/IMPLEMENTATION_LOG.md`). A fresh clone (`core.autocrlf=true`) of
the commit that added the development-only review station (local commit `3894186`, later folded into
the progress-report-21 commit with the same `godot/` tree `4ac0aedb41e2c4e07b8e486f886b98142aeea571`)
ran every step below; each log is the step's complete output, with local paths replaced by
`%USERPROFILE%` or `<scratch>`. `exit_codes.txt` lists every exit code and duration.

Host: Windows 11 Pro N for Workstations 25H2 (10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47),
OpenGL 3.3 Compatibility renderer, 60 Hz display; Godot 4.7.2 console build; portable PowerShell
7.7.0; Node 24.15.0; the pinned Chromium.

| Step | Log | Result |
|---|---|---|
| npm ci; playwright install | `npm_ci.txt`, `playwright_install.txt` | exit 0 |
| a deterministic asset check | `step_a_build_assets_check.txt` | exit 0: 206 + 55 outputs identical |
| b clean import; b2 `git status --porcelain` after it | `step_b_import.txt`, `step_b2_git_status_after_import.txt` | exit 0, no ERROR/WARNING line; status empty (the committed `m1_review.gd.uid` and `.tscn` are what the import expects) |
| c full suite | `step_c_test_suite.txt` | exit 0: 139 passed, 0 failed, 139 total |
| d 600-frame headless Main launch | `step_d_main_600_frames.txt` | exit 0, engine banner only |
| e hermetic PCK smoke | `step_e_pck_smoke.txt` | exit 0: 32,906,024 bytes, 254 runtime resources, 512 packed files, 18 source-only paths unresolved (control resolved 18); the case asserts that no `tools/`, `tests/`, `platform/`, JSON or docs file is packed, so the review station is excluded |
| g, h PixiJS baseline | `step_g_pixijs_npm_test.txt`, `step_h_pixijs_npm_build.txt` | exit 0: 30 files, 248 tests passed; build OK |
| i `git status --porcelain`; j `git diff --check 95b69c0 HEAD`; k `git show --check HEAD` | `step_i_…`, `step_j_…`, `step_k_…` | exit 0, all empty |
| l source-tree guard | `step_l_source_tree_guard.txt` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| m `godot/` changes since the accepted `e0e6052` | `step_m_godot_diff_vs_accepted.txt` | only `M godot/README.md`, `A godot/tools/m1_review.gd`, `A godot/tools/m1_review.gd.uid`, `A godot/tools/m1_review.tscn` |
| n review station export | `step_n_m1_review_export.txt` | exit 0: `M1REVIEW {"checks":18,"failed":[],"fields":362,"ok":true}`; its files are the package in `docs/porting/manual_evidence/m1-godot-tree-2ffca5f/` |
| o unchanged `tools/title_capture.gd` | `step_o_title_capture.txt` | exit 0; images identified in `manual_evidence/m1-godot-tree-2ffca5f/title_capture_check/identified_captures.txt` (first image = rendered frame 1; middle and last exact) |
| p review station start-up smoke (`--quit-after 600`) | `step_p_station_smoke.txt` | exit 0, engine banner only; nothing decided, so no decisions file was written |
| q `git status --porcelain` after all steps | `step_q_git_status_after.txt` | empty |

No manual check was executed: nobody watched the animations, listened to the audio or judged the
title for a decision. Not run here: Linux, Android. The M2 rendered probe was not rerun because no shipping/runtime camera, interpolation or presentation file changed.\*\*

\*\* Corrected in correction report 24: this paragraph first said the rendered probe was not run because "no rendering, camera, interpolation or presentation file changed"; the review tools under `godot/tools/` did change, so the reason is stated for shipping/runtime files only. The logs are unchanged.
