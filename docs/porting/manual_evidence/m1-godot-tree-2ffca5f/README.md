# M1 manual-validation package (Godot content tree `2ffca5f`)

**Status: waiting for the owner.** No manual decision has been made. Every field of
`M1_MANUAL_CHECKLIST.md` is NOT EXECUTED and the final decision is NOT DECIDED, so M1 stays
**Partial** (MILESTONES.md M1, "Manual gameplay/tests"). Nothing in this folder is a PASS:
inventories, hashes, contact sheets, stills and screen captures are supporting facts only.

| Item | Value |
|---|---|
| Accepted baseline | commit `e0e60522f83148af9bee7511772cee35a695bf54`, `godot/` tree `2ffca5ffaf62ff0c55773fd07fd2630c23a6fe3b` |
| Tree that adds the review station | `godot/` tree `4ac0aedb41e2c4e07b8e486f886b98142aeea571`: `2ffca5f` plus `tools/m1_review.tscn`, `tools/m1_review.gd`, `tools/m1_review.gd.uid` and a `godot/README.md` section, nothing else (`git diff --name-status e0e6052 HEAD -- godot`, in `windows_evidence/m1-review-godot-tree-4ac0aed/step_m_godot_diff_vs_accepted.txt`). The animations, sounds and title shown are therefore byte-identical to `2ffca5f`'s. |
| Host used to prepare it | Windows 11 Pro N for Workstations 25H2 (10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47), OpenGL 3.3 Compatibility renderer, 60 Hz display, Godot 4.7.2 (console build for the commands) |
| GUI and audio | Available on that host. The review station ran there (export mode, a start-up smoke and a muted temporary harness; IMPLEMENTATION_LOG.md progress report 21); nobody listened or watched for a decision. |
| Large media | None used. No video or audio recording was made or committed. |

## Why a review station

The Godot editor previews one SpriteFrames animation at a time, without the direction, the frame
number or the authored duration on screen and without the profile context; it cannot play a cue
through `AudioService` (leading silence skipped, gains, buses, mute and volume); and the title
portrait only exists at run time (linear sampling and the alpha-cut shader). The development-only
scene `godot/tools/m1_review.tscn` presents exactly the M1 material and records only the reviewer's
own PASS / FAIL / NOT EXECUTED clicks. `tools/` is excluded from every export preset, and the hermetic
PCK smoke fails if any `tools/` file reaches the pack (it passed: `step_e_pck_smoke.txt`).

## Owner: running the review (Windows PowerShell, from the repository root)

1. Once per checkout, import the project (about 10 s):

   ```powershell
   & "C:\Program Files\Godot472\Godot_v4.7.2-stable_win64_console.exe" --headless --path godot --import
   ```

2. Turn the computer's own volume down. The station starts at 25 % of the game's master volume.
3. Start the review station. Decisions are saved on every click into `owner_decisions/` next to this
   README and are resumed if you close and reopen it:

   ```powershell
   & "C:\Program Files\Godot472\Godot_v4.7.2-stable_win64.exe" --path godot res://tools/m1_review.tscn -- --decisions "$PWD\docs\porting\manual_evidence\m1-godot-tree-2ffca5f\owner_decisions"
   ```

   (From the Godot editor instead: open `godot/project.godot`, open `tools/m1_review.tscn`, press
   F6. Decisions then go to the station's default folder, shown at the bottom of its window.)
4. Work through the four tabs. The station never decides anything; every field starts NOT
   EXECUTED.
   - **1 Animations** (24 items: 2 costumes x 12 actions). The eight directions play at once in a
     compass (N at the top), live at the authored frame timing, nearest filtering, x3. Each cell shows
     the direction, the frame number and that frame's authored duration, and has its own
     PASS / FAIL / NOT EXECUTED field: does the animation play smoothly at that timing, face the
     right way, and have no blank, wrong or jumping frame? Keys: Space play/pause, R replay,
     Left/Right one frame, Up/Down previous/next item, B background. One-shot actions (pee, poop,
     bark) replay automatically after a short hold. After all 24 items, decide **A-FILTER** (pixels
     crisp, no blur or shimmer).
   - **2 Audio** (32 sounds in listening order: 5 recorded tracks, 12 recorded effects, the generated
     medieval loop, 14 generated cues). Each shows its cue key, file, recorded or generated
     provenance, format, channels, sample rate, duration, expected use and the game path (bus, gain,
     the leading silence the game skips). Enter plays it as the game does, W plays the raw file from
     0 s (to hear the skipped silence), L plays a music track's last 6 s into its loop, S stops, R
     replays, Up/Down moves, M mutes; the slider sets the master volume. Decide five observations
     per sound (AUDIBLE, INTENT, START, END, CLEAN) and, once, **B-MUTE** and **B-VOLUME**. Audio
     pauses while the window is not focused, like the game.
   - **3 Title** (7 observations). The portrait plays at the three review widths (88, 99 and 124 px
     for the 192, 216 and 270 px views), x2 like the game, at the authored delays. Space play/pause,
     R replay, Left/Right one frame, 1/2/3 first/middle/last frame. Compare with `title_stills/`.
   - **4 Sign-off**: your name, the date, your speakers or headphones and display (the software
     environment is recorded automatically), then the final decision. APPROVED can only be chosen
     when every field of tabs 1-3 is PASS.
5. When finished, tell Claude. `owner_decisions/m1_owner_decisions.json` and `.md` hold your exact
   decisions; they are committed only with your agreement. A FAIL stops the M1 sign-off: its exact
   reproduction steps are recorded and nothing is repaired in the same commit.

## Contents

| Path | What it is |
|---|---|
| `M1_MANUAL_CHECKLIST.md` | The blank checklist (`m1_review.tscn --export`): owner sign-off, 192 animation cells + A-FILTER, 32 x 5 audio fields + B-MUTE + B-VOLUME, 7 title fields; 362 fields, all NOT EXECUTED |
| `animation_inventory.json` | Profile, costume slots, required actions and directions; per animation: frames, loop, speed, authored ms per frame, cycle, atlas and regions |
| `audio_inventory.json` | Per sound: cue, kind, provenance, AUD IDs, resource, SHA-256 (file and manifest), bytes, format, channels, sample rate, duration (Godot and source fixture), game bus, gain and start offset, expected use, source reference |
| `title_facts.json` | Title conversion facts (below) |
| `selftest.json` | The export's automated self-checks (facts only) |
| `contact_sheets/zampano_NN_<action>.png` | One labelled sheet per action: normal and armoured costumes side by side, a row per direction, a column per frame (x2, nearest), each column headed by its authored ms |
| `title_stills/title_frame_{00,49,98}_widths_88_99_124.png` | First, middle and last title frames in `tools/title_capture.gd`'s layout (x2), written by the station's export |
| `review_ui/tab_{1,2,3}_*.png` | What the station's first three tabs look like (no decision shown) |
| `title_capture_check/` | The rerun of the unchanged `tools/title_capture.gd` on `2ffca5f` and the frame identification (below) |
| `owner_decisions/` | Created by the station when the owner reviews (not present yet) |

The verification logs of this package (fresh clone, suite, PCK smoke, export) are in
`docs/porting/windows_evidence/m1-review-godot-tree-4ac0aed/`.

## Automated facts (not manual decisions)

**Animations** (`animation_inventory.json`): the profile `res://data/characters/zampano_profile.tres`
uses two SpriteFrames resources: `zampano_frames.tres` (normal) and `zampanoKnight_frames.tres`
(armoured, which the cross costume aliases, AST-006). Each has exactly the 12 required actions
(`anim_order` of the costume sheet JSON) x 8 directions = 96 animations; 192 animations, 1,088
frames, every frame a 40 x 40 atlas region; frame counts, loop flags and authored per-frame durations
equal the source sheet JSON:

| Action | Frames | Playback | Authored ms per frame | Cycle (ms) |
|---|---|---|---|---|
| idle | 8 | loop | 100, 110, 120, 110, 100, 110, 120, 110 | 880 |
| walk | 8 | loop | 90, 80, 90, 110, 90, 80, 90, 110 | 740 |
| run | 8 | loop | 50, 60, 60, 50, 60, 50, 50, 50 | 430 |
| sniff | 2 | loop | 200, 200 | 400 |
| pee | 8 | one-shot | 120, 100, 130, 250, 360, 280, 140, 180 | 1,560 |
| poop | 8 | one-shot | 120, 130, 150, 220, 360, 220, 140, 180 | 1,520 |
| eat | 8 | loop | 110, 100, 100, 90, 180, 90, 90, 120 | 880 |
| bark | 2 | one-shot | 100, 100 | 200 |
| fetch | 4 | loop | 76.92 each | 307.69 |
| hurt | 2 | loop | 100, 100 | 200 |
| sit | 8 | loop | 120, 120, 150, 120, 120, 120, 150, 120 | 1,020 |
| tired | 2 | loop | 250, 250 (separate tired sheet) | 500 |

**Audio** (`audio_inventory.json`): the listening list is exactly `AudioService`'s 6 music tracks,
12 recorded effects and 14 synth cues: 5 recorded tracks (MP3, 44.1 kHz stereo), 12 recorded effects
(11 MP3, 1 PCM WAV; mono or stereo, 22.05 or 44.1 kHz), the generated medieval loop and 14 generated
cues (PCM WAV, mono, 22,050 Hz, 16-bit). Every file loads, its SHA-256 equals the source asset
manifest, and its Godot length equals the source fixture duration to the millisecond.

**Title** (`title_facts.json`, also asserted by `test_AST_010_title_conversion`): 99 frames; per-frame
delays equal `data/title/title_frames.json` (authored cycle 3.9 s); frame 125 x 168 px, canonical
width 125; frame 0 probed at 256 px; alpha threshold 110 (conversion) and 110/255 in the portrait
shader; one shared crop `{x 66, y 137, w 908, h 1222}` of the 1024 x 1536 source with margin
`[0.05, 0.03]`; one atlas page 2000 x 1176 (within 2048 x 2048); uncompressed frame memory
8,316,000 bytes (under 12 MB); TitlePortrait is the only linear-sampled node (alpha-cut shader).

## Title capture rerun on the accepted tree, and a defect in it (not repaired here)

On a fresh clone of `e0e6052` (`godot/` tree `2ffca5f`), the unchanged
`tools/title_capture.gd` produced middle and last images byte-identical to the committed
`docs/porting/captures/title_m1/title_frame_49…` and `…_98…`. Its "first" image is not frame 0.
Rendering all 99 frames in the same layout and matching SHA-256 values
(`title_capture_check/identified_captures.txt`) shows:

- the rerun's `title_frame_00` is rendered frame 1 (identical to frame 12);
- the committed `captures/title_m1/title_frame_00_widths_88_99_124.png` (commit `16b5619`) is
  rendered frame 3, not frame 0;
- the station's `title_stills/title_frame_00…` is frame 0, and its `…_49` and `…_98` are
  byte-identical to the committed ones (same layout, same pixels).

Cause: run as a `--script`, the SceneTree's `_initialize()` adds the portraits before the tree
runs their `_ready()`, so `title_capture.gd` sets frame 0 while `sprite_frames` is still unset
(`title_capture_check/trace_title_capture_order.log.txt`: right after `add_child` the portrait is at
frame 0, not playing, with no SpriteFrames, so the trace script stopped there with a null-call
error and its process was ended by hand). On the first `await process_frame`, `TitlePortrait._ready()` starts playback, and the
animation advances during the four frames before the first capture. The later captures call
`stop()` on running portraits and are exact.

Reproduction: on `2ffca5f`, run
`godot --path godot --rendering-driver opengl3 --script res://tools/title_capture.gd -- --out <dir>`,
then compare `<dir>/title_frame_00_widths_88_99_124.png` with the frame renders made by
`title_capture_check/render_all_frames.gd.txt`. Three runs on the host gave the same frame-1 image.

This is a defect of a development capture tool, not of the title conversion or any runtime file.
Per the instruction to record and not repair in this evidence-gathering commit, `title_capture.gd`
and `captures/title_m1/` are unchanged. The owner reviews the live portrait (tab 3) and
`title_stills/`. A one-line fix (one `await process_frame` before the first frame is set) is left
for the architect to decide.

## Status of the M1 manual checks

| Check (MILESTONES.md M1) | Status | Owner action required |
|---|---|---|
| Preview of every Zampanò animation and direction at nearest filtering | NOT EXECUTED | Tab 1: 192 cells and A-FILTER |
| Listening to the recorded and generated audio at a safe volume | NOT EXECUTED | Tab 2 on a computer with speakers or headphones: 160 fields, B-MUTE, B-VOLUME |
| Title: common crop, alpha edges, title-only scaling, first/middle/last, timing | NOT EXECUTED | Tab 3: 7 fields |
| Owner sign-off (name, date, environment, final decision) | NOT DECIDED | Tab 4 |

The M1 legacy-save spike (controlled APK lineage on emulators) was accepted by the architect on
review of `8f8dcb6` and is not part of this package. M2 manual play and M3 are not started.
