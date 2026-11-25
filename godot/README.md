# SUPERVILLAINED VG1 — Godot 4.7 port

Native Godot 4.7.2 (GDScript, GL Compatibility renderer) port of the PixiJS game in the repository
root. The PixiJS/TypeScript source is untouched and remains the reference implementation
(audited commit `95b69c0`). Architecture, milestones and the test plan live in `docs/porting/`.

Current state: **M1 Partial, M2 Partial** (not accepted) — Level 1 / Green Zone playable from
briefing to result card. See `docs/porting/IMPLEMENTATION_LOG.md` for evidence and deviations and
the status section of `docs/porting/FEATURE_MATRIX.md` for the acceptance IDs actually satisfied.

## Requirements

- Godot **4.7.2 stable** (standard, not .NET). Linux x86_64 build used for validation:
  `Godot_v4.7.2-stable_linux.x86_64` (SHA-512 checked against the official `SHA512-SUMS.txt`).
- Asset regeneration/check only: Node **exactly** v24.15.0 (`tools/.node-version`; the extractor
  refuses any other version), the root `npm ci` (Playwright 1.63.0) and the Chromium build that
  playwright-core pins (`npx playwright install chromium`: 153.0.8010.12, revision 1243). The
  extractor launches that full `chromium` channel and refuses any other version (exit 6).

## Run

```bash
godot --path godot                      # desktop window 432×864 (logical 216×432 at 2×)
godot --path godot -- --as=sbrimbrulon  # developer playable-profile override: zampano, sbrimbrulon, bagnaskiz
```

Controls: WASD/arrows move, Shift or K run, Space pee, J/X or B bark, Esc/P menu. With a mouse the
touch controls are emulated (left side: floating joystick; right: PEE / BARK / RUN; MENU top-right).

## Tests

A clean clone needs one import first (it registers the global script classes):

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/test_runner.gd -- --suite all
```

On Windows use the console build so output and the exit code reach the terminal:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path godot --import
Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://tests/test_runner.gd -- --suite all
```

Suites: `unit`, `content`, `integration`, `all`; filters `--file <substring>` and
`--case <substring>`; `--repeat <n>`. The runner fails on assertion failures, engine
errors/warnings, orphan nodes and timeouts, writes `test-results/results.json` and `junit.xml`
(git-ignored) and exits non-zero on failure. The integration suite exports the Android preset as
a PCK with the same binary and starts it as a packed runtime (`test_export_pack.gd`). Every case runs isolated (input, audio, a per-case
save directory, app state and renderable IDs are reset first).

Case naming: `test_<ID>_…` only when every clause of that TEST_PLAN acceptance ID is exercised;
`test_P_<ID>_…` is partial evidence and never satisfies the ID; `test_SLICE_…` checks port behaviour
with no plan ID.

Reference fixtures in `tests/fixtures/` were produced by executing the audited TypeScript
(`tools/source_extract`); they must never be regenerated to hide a Godot mismatch.

## Visual captures (needs a renderer)

```bash
xvfb-run -a godot --path godot --rendering-driver opengl3 \
  --script res://tools/capture_suite.gd -- --out /tmp/captures            # scripted tour
xvfb-run -a godot --path godot --rendering-driver opengl3 \
  --script res://tools/capture_suite.gd -- --out /tmp/captures --mode run # full real-input run
xvfb-run -a godot --path godot --rendering-driver opengl3 --resolution 800x600 \
  --script res://tools/capture_suite.gd -- --out /tmp/captures --mode diagnostic --size 800x600
```

Renderer and audio probes (exit 1 on failure):

```bash
godot --path godot --rendering-driver opengl3 --disable-vsync \
  --script res://tools/rendered_presentation_probe.gd -- --out=/tmp/rendered   # desktop GPU
godot --path godot --script res://tools/audio_suspend_probe.gd    # host with an audio device
godot --path godot --rendering-driver opengl3 --script res://tools/title_capture.gd -- --out /tmp/title
```

`rendered_presentation_probe.gd` (checks in `rendered_presentation_probe_impl.gd`, loaded once the
autoloads exist) is the renderer-backed evidence for the rendered clauses of VIEW-004, CAM-004 and
DOG-008a, outside the headless suite. At 30/60/90/120 FPS it reads back every measured frame after
`RenderingServer.frame_post_draw`: the real PlayableDog with a frozen frame (one component, exact
pixels, the position the interpolated physics state predicts, displacement and velocity against the
logic), static pixel-art markers under the real CameraRig (absolute position, pattern, intensity),
the first frame after spawn, teleport, camera snap and the real Main RESTART, and negative controls
(interpolation off, doubled displacement, ghosts, missing resets, fractional and subpixel cameras)
that must all be detected. It prints one `PROBE {json}` line per record and exits 1 on any failure.
Achieved rates are checked against the requested ones, so on a 60 Hz display use `--disable-vsync`
(with VSync only `--rates=30,60` can be reached). `--out=<dir>` saves representative frames.
`audio_suspend_probe.gd` checks that live music/effects pause in the background and resume, and
that a new effect requested in the background is dropped like the source's (with
`--headless` the Dummy driver reports the started playbacks as leaked at exit, F-07).
`title_capture.gd` renders the title portrait's first/middle/last frames at three logical widths.
Run as a `--script`, its portraits get `_ready()` (which starts playback) only at the first process
frame, so it sets the frames only once every portrait is ready and exits 1 if a portrait is not on the
requested frame or an image cannot be saved. Before correction report 22 it set frame 0 too early
and its first image showed a later frame. Its three images are byte-identical to the stills of
`m1_review.tscn --export` (`docs/porting/manual_evidence/m1-godot-tree-2ffca5f/README.md`).

## M1 manual review (development only; needs a renderer and audio output)

```bash
godot --path godot res://tools/m1_review.tscn -- --decisions <absolute dir>   # review station
godot --path godot --rendering-driver opengl3 res://tools/m1_review.tscn -- --export <absolute dir>
godot --path godot --rendering-driver opengl3 res://tools/m1_review.tscn -- --selftest <absolute dir>
```

`m1_review.tscn` presents the material of the manual M1 checks and records only the reviewer's own
PASS / FAIL / NOT EXECUTED decisions for 363 fields (`<dir>/m1_owner_decisions.json` and `.md`, saved
on every change; a failed save is shown in red as NOT SAVED). Saved decisions carry a schema version
and a content fingerprint (SHA-256 over the reviewed profile, costume resources, sheets and atlas
pages, the 32 audio files and the title resources); they are resumed only when both match, otherwise
they are set aside as `.stale-<time>` files and every field starts NOT EXECUTED. Tab 1 plays every
Zampanò animation of the profile (normal and armoured costumes, which the cross costume aliases; every
action including tired) in all eight directions at once, at the authored frame timing with nearest
filtering, with pause, replay and frame step. Tab 2 plays the five recorded tracks, twelve recorded
effects, the generated medieval loop and the fourteen generated cues through `AudioService` (or the
raw file from 0 s) from a 25 % master volume, with stop, previous/next, mute and volume; the siren also
has the source's attack event ([E]: the alarm, then the siren after `SIREN_DELAY` at `SIREN_VOLUME`,
looping until Stop) on a review-only player, because the shipping `AudioService` has no looping
effect. The station's own players pause while the window is in the background. Tab 3 plays the title
portrait at the three review widths with pause, step, first/middle/last and the memory report. Tab 4
records the owner, date, equipment, environment and final decision; APPROVED needs every field PASS
and a nonblank owner name, date and equipment. `--export` writes the machine-readable inventories,
the content fingerprint, the blank checklist, labelled contact sheets, title stills and screen
captures, verifies that each expected file exists, is nonempty and parses, and exits 1 on any failed
check, write or file (facts only, never a manual decision). `--selftest` drives the station's own
code in a scratch folder (save/resume, stale content and old schema, save failures, approval and
attribution refusal, the siren event, pausing in the background) and exits 1 on any failure.
`tools/` is excluded from every export preset.

## Regenerating assets

From the repository root, after `npm ci` and `npx playwright install chromium`, with the pinned
Node:

```bash
godot/tools/build_assets.sh /path/to/godot
NODE=/path/to/node-v24.15.0/bin/node godot/tools/build_assets.sh --check /path/to/godot
```

Windows (PowerShell, pinned Node on `PATH`):

```powershell
godot\tools\build_assets.ps1 -Godot C:\path\Godot_v4.7.2-stable_win64_console.exe -Check
```

Inputs are read as the audited Git blobs (`git cat-file blob 95b69c0:<path>`), so Windows
`core.autocrlf` cannot change them; generated text is LF (`godot/.gitattributes`). The extractor
refuses to run if `src/`, `public/`, `assets/`, `package.json` or `package-lock.json` differ from
the audit (exit 3), if Node is not v24.15.0 (exit 4), if Playwright/playwright-core differ from
the lockfile (exit 5) or if the launched Chromium is not the build pinned by
`playwright-core/browsers.json` (exit 6). Generated files record only the pinned toolchain; the
host browser's own version is printed (host evidence), never written.

1. `tools/source_extract/extract.mjs` (Node) copies the runtime-authoritative files byte-for-byte
   (every playable and cast sheet, the fifteen Color Ink banks, five music tracks, twelve effects,
   the font licence); freezes the source's procedural art by executing
   `src/assets/placeholders/*.ts` (items, FX, story specials and the seventeen procedural cast
   roles); rasterizes the bitmap font by executing `src/ui/pixelFont.ts` in Chromium; converts the
   99-frame title WebP by executing `src/ui/titleAnim.ts` in Chromium; renders the fourteen
   synthesized cues and the medieval loop with `src/core/synth.ts`/`src/fx/sounds.ts` to mono
   22,050 Hz 16-bit PCM WAV; writes reference fixtures (including campaign migration, story maps
   and the Green Zone decor) and `data/source_asset_manifest.json` (SHA-256, sizes, use,
   provenance, toolchain, and the hash of every generated output). `--check` regenerates in memory
   and fails on any differing or missing output.
2. `tools/build_resources.gd` (Godot, headless) builds the ground tile atlas, the TileSet with
   phase-rotated animated alternatives, the sprite catalogue, SpriteFrames for every playable skin
   and cast role (authored holds), the three PlayableCharacterProfiles, the title SpriteFrames
   and the leading-silence Resource.

Both steps only rewrite files whose bytes change; a second run produces no diff. With `--check`,
`build_resources.gd` also rebuilds in memory and compares all 55 of its outputs.

## Layout

```
main/        persistent Main (SafeArea → pixel SubViewport) and PixelViewportController
autoload/    AppState, SaveService (format-3 atomic save), InputService, AudioService
core/        GameConfig (source tuning), DeterministicRng, JsMath, resource classes
iso/         IsoGrid projection, IsoRenderable, IsoDepthSorter, CameraModel/CameraRig
world/       TileCatalog, AsciiMapLoader, WorldMapModel, IsoWorld scene, runtime TileMapLayers
entities/    PlayableDog, props, treat/poop views
systems/     needs, Green Zone rules, threats (bark + pollution waves), scoring, lives, placement
scenes/      Green Zone scene, native overlays (briefing, pause, level end, game over)
ui/          HUD, touch controls, pixel text
data/        generated Resources + layout data (from the source manifests)
assets/      runtime copies and frozen generated art (see data/source_asset_manifest.json)
tests/       first-party runner, unit/content/integration suites, fixtures, automation driver
tools/       extraction/build/capture tools, source-tree guard (not exported)
```

## Guards

```bash
godot/tools/source_tree_guard.sh   # only /godot and docs/porting may differ from 95b69c0
git diff --check
```

Asset rights: only the font has repository licensing evidence (`assets/fonts/OFL.txt`); every
other asset's distribution rights must be recorded by the owner before a public release (REL-001).
