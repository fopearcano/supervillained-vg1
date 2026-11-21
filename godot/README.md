# SUPERVILLAINED VG1 — Godot 4.7 port

Native Godot 4.7.2 (GDScript, GL Compatibility renderer) port of the PixiJS game in the repository
root. The PixiJS/TypeScript source is untouched and remains the reference implementation
(audited commit `95b69c0`). Architecture, milestones and the test plan live in `docs/porting/`.

Current state: **M1 foundation (partial) + M2 vertical slice** — Level 1 / Green Zone playable from
briefing to result card. See `docs/porting/IMPLEMENTATION_LOG.md` for evidence and deviations.

## Requirements

- Godot **4.7.2 stable** (standard, not .NET). Linux x86_64 build used for validation:
  `Godot_v4.7.2-stable_linux.x86_64` (SHA-512 checked against the official `SHA512-SUMS.txt`).
- Asset regeneration only: Node 24 (pinned `tools/.node-version`) and Playwright 1.63 Chromium.

## Run

```bash
godot --path godot                      # desktop window 432×864 (logical 216×432 at 2×)
godot --path godot -- --as=zampano      # developer playable-profile override (Zampanò only for now)
```

Controls: WASD/arrows move, Shift or K run, Space pee, J/X or B bark, Esc/P menu. With a mouse the
touch controls are emulated (left side: floating joystick; right: PEE / BARK / RUN; MENU top-right).

## Tests

A clean clone needs one import first (it registers the global script classes):

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/test_runner.gd -- --suite all
```

Suites: `unit`, `content`, `integration`, `all`; filters `--file <substring>` and
`--case <substring>`; `--repeat <n>`. The runner fails on assertion failures, engine
errors/warnings, orphan nodes and timeouts, writes `test-results/results.json` and `junit.xml`
(git-ignored) and exits non-zero on failure.

Reference fixtures in `tests/fixtures/` were produced by executing the audited TypeScript
(`tools/source_extract`); they must never be regenerated to hide a Godot mismatch.

## Visual captures (needs a renderer)

```bash
xvfb-run -a godot --path godot --rendering-driver opengl3 \
  --script res://tools/capture_suite.gd -- --out /tmp/captures            # scripted tour
xvfb-run -a godot --path godot --rendering-driver opengl3 \
  --script res://tools/capture_suite.gd -- --out /tmp/captures --mode run # full real-input run
```

## Regenerating assets

From the repository root:

```bash
godot/tools/build_assets.sh /path/to/godot
```

1. `tools/source_extract/extract.mjs` (Node) copies the runtime-authoritative files byte-for-byte,
   freezes the source's procedural sprites by executing `src/assets/placeholders/*.ts`, rasterizes
   the bitmap font by executing `src/ui/pixelFont.ts` in Chromium, writes reference fixtures and
   `data/source_asset_manifest.json` (SHA-256, sizes, use, provenance). `--check` verifies hashes.
2. `tools/build_resources.gd` (Godot, headless) builds the ground tile atlas, the TileSet with
   phase-rotated animated alternatives, the sprite catalogue, Zampanò's SpriteFrames (authored
   holds) and his PlayableCharacterProfile.

Both steps only rewrite files whose bytes change; a second run produces no diff.

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
