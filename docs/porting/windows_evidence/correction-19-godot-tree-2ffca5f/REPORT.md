# Windows host evidence for correction report 19: isolated camera-snap no-reset control

Fresh clone (Windows 11 Pro N for Workstations 25H2, `core.autocrlf=true`, PowerShell 7.7.0, Godot
4.7.2 console exe, Node v24.15.0, pinned Chromium 153.0.8010.12) of the correction-19 code
(`b35d795`, folded into the correction-19 commit with the same `godot/` tree), taken before its report
text and this folder were written. The tested `godot/` tree is `2ffca5ffaf62ff0c55773fd07fd2630c23a6fe3b`, equal to
`git rev-parse <correction-19 commit>:godot`. GPU: NVIDIA GeForce RTX 3090, driver 610.47, OpenGL 3.3
Compatibility renderer; display refresh 60 Hz; VSync off for every probe run.

`exit_codes.txt` lists every step with its exit code and duration. Logs: each step's merged
stdout/stderr; ANSI codes and carriage returns stripped, trailing spaces and final blank lines
removed, the local user name and paths replaced by placeholders.

| Step | File | Result |
|---|---|---|
| a | `step_a_build_assets_check.txt` | exit 0: 206 + 55 generated outputs identical |
| b | `step_b_import.txt` | exit 0, clean import |
| c | `step_c_test_suite.txt` | exit 0: 139 passed, 0 failed, 139 total |
| d | `step_d_main_600_frames.txt` | exit 0, 600-frame Main launch, engine banner only |
| e | `step_e_pck_smoke.txt` | exit 0: 32,906,024 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| f | `step_f_focused_dog_008a.txt` | exit 0: the two DOG-008a restart cases passed |
| g, h | `step_g_pixijs_npm_test.txt`, `step_h_pixijs_npm_build.txt` | exit 0: 30 files, 248 tests; build OK |
| i, r, p | `step_i_git_status.txt`, `step_r_git_status_after_probes.txt`, `step_p_git_status_after.txt` | exit 0, empty |
| j, k | `step_j_git_diff_check.txt`, `step_k_git_show_check.txt` | exit 0, empty |
| l | `step_l_source_tree_guard.txt` | exit 0, guard OK |
| m, n | `step_m_spike_harness_selftest.txt`, `step_n_spike_tool_selftest.txt` | exit 0: 37/37, 6/6 |
| o | `step_o_rendered_probe_resets_vsync_off.txt` | exit 0: the resets section first (`--only=resets`): 12 reset records pass; 12 of 12 controls detected, `camera_snap_without_reset` at all four rates |
| q | `step_q_rendered_probe_vsync_off.txt` | exit 0: the complete probe: the stage check and 24 measured records pass, 24 of 24 negative controls detected, no engine error |
| s | `step_s_prefix_revert.txt` | the clone's `godot/iso/camera_rig.gd` reverted to `8f8dcb6`'s blob (`f13dac1…`; `git diff -U0` shown) |
| t | `step_t_prefix_focused_dog_008a.txt` | exit 1 (expected): `test_P_DOG_008a_restart_canvas_snapped_before_first_draw` fails; the older restart case passes |
| u | `step_u_prefix_rendered_probe_vsync_off.txt` | exit 1 (expected): the four `main_restart` records (30/60/90/120 FPS) failed, plus two failures the mutation cannot cause: `motion_30`'s wall-clock step metric and the per-tick fractional-camera dither control (not detected); every other record passed and every other control, including the corrected `camera_snap_without_reset`, was detected |
| v | `step_v_restore.txt` | the file restored; its hash equals `HEAD:godot/iso/camera_rig.gd` |
| w, x, y, z | `step_w_prefix_rerun_revert.txt`, `step_x_prefix_rerun_rendered_probe_vsync_off.txt`, `step_y_restore.txt`, `step_z_git_status_after_rerun.txt` | the pre-fix rerun in the same clone: exit 1 with exactly the four `main_restart` records failed; restored; status empty |

## Resets section (step o)

Environment: NVIDIA GeForce RTX 3090 (NVIDIA), 3.3.0 NVIDIA 610.47, rendering method `gl_compatibility`, driver `opengl3`, VSync mode 0, display 60.0 Hz, Godot 4.7.2.stable (ed1daf0bf), Windows 10.0.26200; physics 60 Hz, interpolation True, snap transforms/vertices True/True, default texture filter 0; Main GameViewport {'canvas_item_default_texture_filter': 0, 'snap_2d_transforms_to_pixel': True, 'snap_2d_vertices_to_pixel': True}.
Stage: 432×240, 60 markers, matches Main's GameViewport: True; dog sheet: 544 frames, 290,464 opaque texels, 0 in the background/marker colours.

| First frame after (stage) | FPS | frame tick − action tick | fraction | dog components / pattern mismatches / position residual | old position: dog pixels | markers (visible / position failures / pattern failures / extra) | result |
|---|---|---|---|---|---|---|---|
| spawn | 30 | 0 | 0.8642 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 30 | 0 | 0.8637 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 30 | 0 | 0.8629 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 60 | 0 | 0.86 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 60 | 0 | 0.8575 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 60 | 0 | 0.8541 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 90 | 0 | 0.1852 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 90 | 0 | 0.1846 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 90 | 0 | 0.3457 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 120 | 0 | 0.2368 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 120 | 0 | 0.2874 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 120 | 0 | 0.1407 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |

| Negative control | Detected | Failed checks (what saw it) |
|---|---|---|
| `stale_copy_after_teleport_30` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_30` | yes | dog_at_new_position |
| `camera_snap_without_reset_30` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_60` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_60` | yes | dog_at_new_position |
| `camera_snap_without_reset_60` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_90` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_90` | yes | dog_at_new_position |
| `camera_snap_without_reset_90` | yes | dog_at_new_position, markers_at_snapped_view |
| `stale_copy_after_teleport_120` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_120` | yes | dog_at_new_position, nothing_at_old_position |
| `camera_snap_without_reset_120` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |

Summary: ok = True; failures: none; engine errors: none; 12 measured records, 12 negative controls, 12 detected.

## Complete probe (step q)

Environment: NVIDIA GeForce RTX 3090 (NVIDIA), 3.3.0 NVIDIA 610.47, rendering method `gl_compatibility`, driver `opengl3`, VSync mode 0, display 60.0 Hz, Godot 4.7.2.stable (ed1daf0bf), Windows 10.0.26200; physics 60 Hz, interpolation True, snap transforms/vertices True/True, default texture filter 0; Main GameViewport {'canvas_item_default_texture_filter': 0, 'snap_2d_transforms_to_pixel': True, 'snap_2d_vertices_to_pixel': True}.
Stage: 432×240, 60 markers, matches Main's GameViewport: True; dog sheet: 544 frames, 290,464 opaque texels, 0 in the background/marker colours.

| Motion (static camera, frozen `run_e` frame 0) | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| achieved FPS / frames measured | 29.99 / 43 | 60.01 / 85 | 90.0 / 127 | 120.01 / 169 |
| dog components per frame (min–max); component failures | 1–1; 0 | 1–1; 0 | 1–1; 0 | 1–1; 0 |
| area / bbox / pattern mismatches / intensity (reference 489 px, 34×21, 0, 234,147) | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 |
| position vs interpolated physics state (failures; residual px) | 0; 0..0 | 0; 0..0 | 0; 0..0 | 0; 0..0 |
| displacement rendered / logic (error, limit 2 px) | 238 / 237.586 (0.414) | 237 / 237.578 (-0.578) | 237 / 237.585 (-0.585) | 237 / 237.578 (-0.578) |
| fitted / expected px/s (ratio, limit ±3 %) | 169.705 / 169.705 (1.0) | 169.724 / 169.705 (1.0001) | 169.697 / 169.705 (1.0) | 169.711 / 169.705 (1.0) |
| physics ticks/s | 59.99 | 60.0 | 60.0 | 60.0 |
| step RMS vs elapsed time (limit 1 px); held frames (predicted); max step; max excess (limit 2 px) | 0.476; 0 (0); 6; 0.433 | 0.385; 0 (0); 3; 0.289 | 0.323; 0 (0); 2; 0.198 | 0.514; 0 (0); 2; 0.692 |
| result | pass | pass | pass | pass |

| Camera (real CameraRig following the running dog) | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| achieved FPS / frames | 30.13 / 43 | 60.09 / 85 | 90.23 / 127 | 119.26 / 169 |
| marker samples (fully visible markers × frames); missing; extra components | 1,137; 0; 0 | 2,250; 0; 0 | 3,366; 0; 0 | 4,482; 0; 0 |
| absolute position vs interpolated camera: failures; residual x / y px; tie samples | 0; 0..0 / 0..0; 0 | 0; 0..0 / 0..0; 0 | 0; 0..0 / 0..0; 105 | 0; 0..0 / 0..0; 0 |
| common-mode jitter frames; max centroid deviation px | 0; 0.0 | 0; 0.0 | 0; 1.0 | 0; 0.0 |
| pattern / size failures; intensity (reference 24,990) | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 |
| adjacent-marker gaps px (supplemental) | 48 | 48 | 48 | 48 |
| dog: components failures / shape failures / position failures | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| result | pass | pass | pass | pass |

| First frame after (stage) | FPS | frame tick − action tick | fraction | dog components / pattern mismatches / position residual | old position: dog pixels | markers (visible / position failures / pattern failures / extra) | result |
|---|---|---|---|---|---|---|---|
| spawn | 30 | 0 | 0.4703 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 30 | 0 | 0.4698 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 30 | 0 | 0.4688 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 60 | 0 | 0.466 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 60 | 0 | 0.4635 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 60 | 0 | 0.4603 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 90 | 0 | 0.4581 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 90 | 0 | 0.4573 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 90 | 0 | 0.4998 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 120 | 0 | 0.39 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 120 | 0 | 0.4297 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 120 | 0 | 0.4217 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |

| Real Main → Green Zone → pause → RESTART | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| start frame: canvas origin (expected) ; dog bbox ; texel mismatches | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 |
| old run: dog / camera before RESTART | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] |
| replacement added after draw / first frame (seq) | 3434 / 3435 | 3594 / 3595 | 3825 / 3826 | 4128 / 4129 |
| first frame after RESTART: canvas origin (expected) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) |
| camera / dog at (expected spawn) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) |
| dog components; bbox (expected); area (reference); texel mismatches | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 |
| dogs / rigs in tree; redraw px differing from the frame | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 |
| old position (rect, visible px): dog pixels; dog pixels elsewhere | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 |
| failing checks | — | — | — | — |
| result | pass | pass | pass | pass |

| Negative control | Detected | Failed checks (what saw it) |
|---|---|---|
| `ghost_trail_3px` | yes | shape_exact |
| `ghost_trail_1px` | yes | shape_exact |
| `ghost_separate_60px` | yes | shape_exact, single_component |
| `stale_copy_60px` | yes | shape_exact, single_component |
| `interpolation_off_90` | yes | model_position, no_unexpected_holds, step_rms |
| `interpolation_off_120` | yes | model_position, no_unexpected_holds, step_rms |
| `doubled_displacement_30` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_60` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_90` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_120` | yes | displacement, max_step, model_position, step_rms, velocity |
| `fractional_camera_dither_120` | yes | dog_position, marker_pattern_exact, marker_position_exact, no_stale_or_extra_markers |
| `subpixel_camera_linear_120` | yes | dog_shape_exact, dog_single_component, marker_intensity_exact, marker_pattern_exact, marker_position_exact, no_stale_or_extra_markers |
| `stale_copy_after_teleport_30` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_30` | yes | dog_at_new_position |
| `camera_snap_without_reset_30` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_60` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_60` | yes | dog_at_new_position |
| `camera_snap_without_reset_60` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_90` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_90` | yes | dog_at_new_position |
| `camera_snap_without_reset_90` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_120` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_120` | yes | dog_at_new_position |
| `camera_snap_without_reset_120` | yes | dog_at_new_position, marker_pattern_exact, markers_at_snapped_view, no_stale_markers |

Summary: ok = True; failures: none; engine errors: none; 24 measured records, 24 negative controls, 24 detected.

## Pre-fix `CameraRig.snap()` mutation (steps u and x)

The clone's `godot/iso/camera_rig.gd` was reverted to `8f8dcb6`'s blob (`f13dac1…`, `step_s`: `CameraRig.snap()` without `force_update_scroll()`), the focused cases and the complete probe were run, and the file was restored (`step_v`: hash = `HEAD:godot/iso/camera_rig.gd`). `test_P_DOG_008a_restart_canvas_snapped_before_first_draw` failed (`expected (108.0, -1112.0), got (0.0, 0.0)`); the probe exited 1: the four `main_restart` records (30/60/90/120 FPS) failed, plus two failures the mutation cannot cause: `motion_30`'s wall-clock step metric and the per-tick fractional-camera dither control (not detected); every other record passed and every other control, including the corrected `camera_snap_without_reset`, was detected (see the probe weaknesses below). A rerun in the same clone (steps w–z: reverted again, the complete probe, restored, `git status` empty) failed exactly the four `main_restart` records and passed every other record and control. This is the RESTART defect of correction report 18, separate from the missing-reset control (frame `prefix_main_60_first_frame_after_restart.png`, from the rerun). The rerun:

| Real Main → Green Zone → pause → RESTART | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| start frame: canvas origin (expected) ; dog bbox ; texel mismatches | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 |
| old run: dog / camera before RESTART | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] |
| replacement added after draw / first frame (seq) | 3437 / 3438 | 3598 / 3599 | 3828 / 3829 | 4130 / 4131 |
| first frame after RESTART: canvas origin (expected) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) |
| camera / dog at (expected spawn) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) |
| dog components; bbox (expected); area (reference); texel mismatches | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 |
| dogs / rigs in tree; redraw px differing from the frame | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 |
| old position (rect, visible px): dog pixels; dog pixels elsewhere | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 |
| failing checks | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component |
| result | FAIL | FAIL | FAIL | FAIL |

## Frames (`docs/porting/captures/m2_rendered/godot-tree-2ffca5f/`)

- `camera_follow_120_mid.png`
- `main_60_first_frame_after_restart.png`
- `main_60_first_frame_after_restart_world_redraw.png`
- `motion_120_mid.png`
- `prefix_main_60_first_frame_after_restart.png`
- `reset_teleport_without_reset_120.png`
- `resets_camera_snap_120.png`
- `resets_camera_snap_30.png`
- `resets_camera_snap_60.png`
- `resets_camera_snap_90.png`
- `resets_camera_snap_without_reset_120.png`
- `resets_camera_snap_without_reset_30.png`
- `resets_camera_snap_without_reset_60.png`
- `resets_camera_snap_without_reset_90.png`
