# Windows host checks: M1 review station hardened (correction 23), `godot/` tree `c9de0e5`

Correction report 23 (`docs/porting/IMPLEMENTATION_LOG.md`). A fresh clone (`core.autocrlf=true`) of
the commit with this correction's development-tool changes (local commit `eb0a372`, later folded into
the correction-23 commit with the same `godot/` tree `c9de0e5e662edd739f3969d40bbf0c97ee2a2323`) ran
every step below; each log is the step's complete output, with local paths replaced by
`%USERPROFILE%` or `<scratch>`. `exit_codes.txt` lists every exit code and duration. Steps n2 and n3
are failure controls: their exit code 1 is the expected result.

Host: Windows 11 Pro N for Workstations 25H2 (10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47),
OpenGL 3.3 Compatibility renderer, 60 Hz display; Godot 4.7.2 console build; portable PowerShell
7.7.0; Node 24.15.0; the pinned Chromium.

| Step | Log | Result |
|---|---|---|
| npm ci; playwright install | `npm_ci.txt`, `playwright_install.txt` | exit 0 |
| a deterministic asset check | `step_a_build_assets_check.txt` | exit 0: 206 + 55 outputs identical |
| b clean import; b2 `git status --porcelain` after it | `step_b_import.txt`, `step_b2_git_status_after_import.txt` | exit 0, no ERROR/WARNING line; status empty |
| c full suite | `step_c_test_suite.txt` | exit 0: 139 passed, 0 failed, 139 total |
| d 600-frame headless Main launch | `step_d_main_600_frames.txt` | exit 0, engine banner only |
| e hermetic PCK smoke | `step_e_pck_smoke.txt` | exit 0: 32,906,024 bytes, 254 runtime resources, 512 packed files, 18 source-only paths unresolved (control resolved 18); the case asserts that no `tools/`, `tests/`, `platform/`, JSON or docs file is packed, so the review tools stay excluded |
| g, h PixiJS baseline | `step_g_pixijs_npm_test.txt`, `step_h_pixijs_npm_build.txt` | exit 0: 30 files, 248 tests passed; build OK |
| i `git status --porcelain`; j `git diff --check 95b69c0 HEAD`; k `git show --check HEAD` | `step_i_…`, `step_j_…`, `step_k_…` | exit 0, all empty |
| l source-tree guard | `step_l_source_tree_guard.txt` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| m `godot/` changes since `6dc585a` | `step_m_godot_diff_vs_6dc585a.txt` | only `M godot/README.md`, `M godot/tools/m1_review.gd` |
| n review station export | `step_n_m1_review_export.txt` | exit 0: `"ok":true`, 25 checks, none failed (including the layout at 1320 x 900 and 1280 x 720 and the captures' sizes), 363 fields, 26 expected files verified (`artifact_problems` and `write_errors` empty), content fingerprint `67cf406c…1d4d`; its files are the package in `docs/porting/manual_evidence/m1-godot-tree-2ffca5f/` |
| n2 failure control: the export target is a file | `step_n2_export_failure_target_is_a_file.txt` | **exit 1 (expected)**: `"ok":false`, write error "cannot create the folder … (the path exists and is not a folder)", `export FAILED` |
| n3 failure control: a file named `contact_sheets` in the export folder | `step_n3_export_failure_contact_sheets_blocked.txt` | **exit 1 (expected)**: `"ok":false`, one write error and the 12 contact sheets reported missing; the other 14 files were written and verified |
| n4 station self-test | `step_n4_station_selftest.txt`, `station_selftest.json` | exit 0: `M1SELFTEST` 59 checks, none failed, schema 3, review contract `2fa10012…6404`. Seven ERROR records from the six expected save-failure checks, announced in the log: one "decisions NOT saved" from each check, plus the engine's "Could not create directory" in the folder-creation check. The real siren wrap: started 0.3 s before the end (3.1746 s of 3.4746 s), wrapped after 0.317 s, at 0.608 s when sampling ended (0.901 s) |
| o `tools/title_capture.gd` | `step_o_title_capture.txt` | exit 0: three images, each with the portraits on the requested frame (0, 49, 98) |
| o2 title capture vs the station's stills | `step_o2_title_hash_compare.txt` | exit 0: all three byte-identical (SHA-256 `728ff267…615f`, `95840694…6712`, `c0f46e0f…7aa4`) |
| p review station start-up smoke (`--quit-after 600`) | `step_p_station_smoke.txt` | exit 0, engine banner only; nothing decided, so no decisions folder was created |
| p2 station start-up with a correction-22 decisions pair (schema 2) | `step_p2_station_old_format.txt` | exit 0; both files were renamed to `m1_owner_decisions.stale-<time>.json` / `.md` and nothing was resumed or saved |
| q `git status --porcelain` after all steps | `step_q_git_status_after.txt` | empty |

No manual check was executed: nobody watched the animations, listened to the audio or judged the
title for a decision; the self-test plays with the master bus at volume 0. Not run here: Linux,
Android, the rendered probe (no rendering, camera, interpolation or presentation file changed).
