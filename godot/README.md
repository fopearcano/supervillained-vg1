# SUPERVILLAINED VG1 — Godot 4.7 port

Native Godot 4.7.2 (GDScript, GL Compatibility renderer) port of the PixiJS game in the repository
root. The PixiJS/TypeScript source is untouched and remains the reference implementation
(audited commit `95b69c0`). Architecture, milestones and the test plan live in `docs/porting/`.

Current state: **M1 Partial, M2 Partial** (their manual checks deferred by the owner for prototype
development: not passed, not cancelled), **M3 prototype implemented, pending review** — the
complete Green Zone 1.0 is playable: hunger, digestion and poop, bladder and pee, marking, scoring,
cats and coins, magnet balls and the forced fetch, the three pollution waves, Under Attack with
Bagnaskiz, briefing → play ⇄ pause → Supervillained snap → level end (CONTINUE hands
`{result, time, coins}` to a stub receiver; the story is not ported) or game over → retry. See
`docs/porting/IMPLEMENTATION_LOG.md` for evidence and deviations and the status section of
`docs/porting/FEATURE_MATRIX.md` for the acceptance IDs claimed and satisfied.

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

Focused M3 suites: `--file test_threats` (threat helpers, director, the source threats run, the
forced-fetch overlap) and `--file test_green_zone_m3` (AUTO-001 real-input run, cues, radar/banner,
level end). AUTO-001 alone: `--suite integration --file test_green_zone_m3 --case AUTO_001`.

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
  --script res://tools/capture_suite.gd -- --out /tmp/captures --mode run # full real-input run (M3 shots 20-23)
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

The owner deferred the M1/M2 manual checks for prototype development (M3 report 25); the station is
kept as it is and is not extended. Its content fingerprint covers files that M3 changed
(`autoload/audio_service.gd`, `scenes/green_zone/green_zone_scene.gd`), so the committed package
would be set aside as stale and must be regenerated before any later owner review.

```bash
godot --path godot res://tools/m1_review.tscn -- --decisions <absolute dir>   # review station
godot --path godot --rendering-driver opengl3 res://tools/m1_review.tscn -- --export <absolute dir>
godot --path godot --rendering-driver opengl3 res://tools/m1_review.tscn -- --selftest <absolute dir>
```

`m1_review.tscn` presents the material of the manual M1 checks and records only the reviewer's own
PASS / FAIL / NOT EXECUTED decisions for 363 fields, saved on every change. Each save writes an
immutable generation pair `<dir>/m1_owner_decisions.<save ID>.md` and `.json` (the JSON copy records
the save ID, the generation number and the Markdown copy's SHA-256), reads both back and verifies
them, and only then replaces one small pointer, `m1_owner_decisions.active.json` (written as
`.active.json.new`, then renamed onto it), to select the new pair. The previously active pair is kept
and older generation files are pruned. A failure removes the new files, leaves (or puts back) the
earlier pointer and is shown in red as NOT SAVED. On Linux and Android the pointer rename is one atomic
step; on Windows Godot 4.7.2's `DirAccess.rename` deletes the old pointer and then moves the new one,
so the loader treats "no pointer, a valid `.active.json.new`" as that midpoint. On start the pointed
pair is resumed when both files match the pointer's SHA-256 values (computed with CRLF line ends read
as LF, so a Windows git checkout of committed copies still verifies) and the decisions schema (4), the
review contract and the content fingerprint match this station. The fingerprint is a SHA-256 over the
reviewed profile, costume resources, sheets and atlas pages, the 32 audio files, the title resources,
the station's own code, `AudioService` and the Green Zone scene script whose calls the source-use
checks compare, plus the review contract (`GameConfig.Audio`, the relevant project settings,
`AudioService`'s tables and offsets, every item's source uses and effective gains, the source-use
scope, the siren event, the title widths and the field list). When the pointer is missing or unusable,
the newest complete matching pair in the folder is recovered, whatever its files are named: copies
saved under the correction-23 names (`m1_owner_decisions.json` / `.md`, `.previous.*`, `.*.new`) are
paired by the save ID they carry. Stale decisions are set aside as `.stale-<time>` files and every
field starts NOT EXECUTED. Every tab scrolls inside the window, so the save-status line stays visible
and every control stays reachable down to 1280 x 720. Tab 1 plays every Zampanò animation of the
profile (normal and armoured costumes, which the cross costume aliases; every action including tired)
in all eight directions at once, at the authored frame timing with nearest filtering, with pause,
replay and frame step. Tab 2 plays the five recorded tracks, twelve recorded effects, the generated
medieval loop and the fourteen generated cues through `AudioService` (or the raw file from 0 s) from a
25 % master volume, with stop, previous/next, mute and volume. An effect's game path ([Enter]) uses
its source use's volume and rate (splash: the Green Zone's 0.7); where a second use was selected, [V]
plays it (splash: the story boat's 0.5; coin, warning and tired/empty: their Green Zone rate and volume
variants). These are selected representative source variants for M1 cue review, not an exhaustive
event-sequencing matrix: other call options (for example star's rate steps and delayed marking call,
click's story-minigame volumes, the cat cash delay, bark's random rate) are listed in each item's
source column but not played separately. The siren also has the source's attack event ([E]: the alarm,
then the siren after `SIREN_DELAY` at `SIREN_VOLUME`, looping until Stop) on a review-only player,
because the shipping `AudioService` has no looping effect. The station's own players pause while the
window is in the background. Tab 3 plays the title portrait at the three review widths with pause,
step, first/middle/last and the memory report. Tab 4 records the owner, date, equipment, environment and
final decision; APPROVED needs every field PASS and a nonblank owner name, date and equipment.
`--export` writes the machine-readable inventories, the content fingerprint and review contract, the
blank checklist, labelled contact sheets, title stills and screen captures (1320 x 900, and the title
tab's end at 1280 x 720), checks the layout at both sizes, verifies that each expected file exists, is
nonempty and parses, and exits 1 on any failed check, write or file (facts only, never a manual
decision). `--selftest` drives the station's own code in a scratch folder (generation saves and their
failures, the state after every save step as if the station had stopped there, torn and damaged files,
legacy split pairs, resume, stale content, schema, contract and call site, approval and attribution
refusal, the effects' source uses on `AudioService`'s players, the siren event with a real loop wrap,
pausing in the background, the layout) and exits 1 on any failure.
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
entities/    PlayableDog, props, treat/poop views, critter controllers (cat, ball, Bagnaskiz) + views
systems/     needs, Green Zone rules, threats (cats, balls, waves, attack director, Bagnaskiz, bark),
             threat helpers, scoring, lives, placement
scenes/      Green Zone scene, native overlays (briefing, pause, Supervillained snap, level end, game over)
campaign/    save migration rules; the Green Zone → 1.1 handoff contract and its stub receiver
fx/          world text, glitch shader (transition and the Under Attack look)
ui/          HUD, attack banner, touch controls, pixel text
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
