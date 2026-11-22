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
xvfb-run -a godot --path godot --rendering-driver opengl3 --script res://tools/interpolation_probe.gd
godot --path godot --rendering-driver opengl3 --disable-vsync --script res://tools/interpolation_probe.gd  # desktop GPU
godot --path godot --script res://tools/audio_suspend_probe.gd    # host with an audio device
godot --path godot --rendering-driver opengl3 --script res://tools/title_capture.gd -- --out /tmp/title
```

`interpolation_probe.gd` reads back rendered frames at 30/60/90/120 FPS (no stutter, streak or
double interpolation; teleport resets; no static shimmer under the following camera). On a 60 Hz
display with VSync the 90/120 caps cannot be reached: its interpolation-off control then shows no
repeated frames and the probe exits 1 (inconclusive), so use `--disable-vsync` there.
`audio_suspend_probe.gd` checks that live music/effects pause in the background and resume, and
that a new effect requested in the background is dropped like the source's (with
`--headless` the Dummy driver reports the started playbacks as leaked at exit, F-07).
`title_capture.gd` renders the title portrait's first/middle/last frames at three logical widths.

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
