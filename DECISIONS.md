# Decisions log

Short entries, newest milestone at the bottom. Anything that deviates from or extends `SPEC.md` is here.

## Plan (before M1)

- **Rendering**: PixiJS v8 forced to WebGL (`preference: 'webgl'`), used only as a sprite/graphics
  library. Pixi's ticker is off (`autoStart: false`); our own fixed-timestep loop calls
  `renderer.render()`.
- **Pixel-perfect**: the canvas backing store *is* the logical resolution (≈216 px wide, height
  follows the screen). The browser upscales it by an **integer** factor with `image-rendering: pixelated`.
  `core/display.ts` picks the factor; wide desktop windows are pillarboxed to a portrait aspect.
- **Loop**: 60 Hz fixed logic step with an accumulator, render interpolation via `prev*` positions.
- **Scenes**: a stack (`core/scene.ts`); overlays such as Pause are pushed over the game.
- **Systems**: small classes with pure logic (tested with Vitest); entities own their Pixi views.
  No ECS.

## M1 — Scaffold and movement

- **Dependencies**: runtime = `pixi.js` only. Dev = `typescript`, `vite`, `vitest`, `playwright`
  (pinned to 1.63 to match the browsers preinstalled in the dev container).
- **Font**: Press Start 2P (OFL) taken from the `@fontsource/press-start-2p` npm tarball and committed
  as `src/assets/fonts/PressStart2P.woff2` + `OFL.txt` — bundled by Vite, no runtime CDN and no
  npm dependency.
- **Pixel text**: `ui/pixelText.ts` bakes text into a small canvas texture. Glyphs are rendered once
  at 8 px and **thresholded to 1-bit alpha** (`ui/pixelFont.ts`), so text is crisp at any integer
  scale. Effects (outline, glow, shadow, per-span colors, justified paragraphs) are drawn with
  pixel offsets. Re-rendered only when the text changes.
- **Iso conventions**: tile (i, j) covers grid [i, i+1) × [j, j+1); its top vertex is
  `gridToScreen(i, j)`. Diamond textures are rasterized by pixel-center test (`insideDiamond`), which
  tessellates with no gaps or overlaps (unit-tested).
- **Movement**: the joystick vector is screen space; `screenDirToGrid` is the inverse projection, so
  on-screen motion is exactly parallel to the stick. Speed is normalized in **grid units** (world
  speed is constant; moving vertically on screen looks slower in pixels, as perspective implies).
  Analog: light tilt = slow walk, past 82 % = run. Keyboard: walk by default, **Shift = run**
  (extension, the spec lists no run key).
- **Facing**: 8 directions defined on the ground plane as seen by the camera. Diagonals (NE, SE, ...)
  are the iso grid axes (≈26.6° from horizontal on screen). Sprites are generated for all 8.
- **Depth sorting**: by `gx + gy` of the contact point + small per-object bias, tie-break by `gx`
  then stable id (`iso/depth.ts`). Applied through `zIndex` of visible objects each frame.
  Occlusion fade: a tall object drawn after Zampanò whose sprite box overlaps his fades to 42 %.
- **Level format**: ASCII rows (= gy) × columns (= gx) + metadata in a TS file (`levels/level1.ts`).
  Legend extensions: `,` tall grass, `F` drinking fountain (`W` is a puddle), space = void.
  `loadLevel()` dispatches on `source.format`; `'tiled'` is reserved and throws for now. Every
  loader returns the same `LevelData` shape.
- **Level 1 layout**: 72×72 map, start at the bottom corner and exit at the top corner, so walking
  the path goes *up* the portrait screen; the path zig-zags left/right (~160 tiles ≈ 70 s of pure
  walking, 2–3 min with gameplay). Generated once with a throwaway script, then committed as plain
  ASCII — it is meant to be hand-edited from now on.
- **Bushes are walkable** (slower), so Zampanò can poop *in* bushes as the spec suggests. Trees,
  poles and fountains are solid circles; forest `#` and void are solid squares. Collision is done
  in grid space (circle vs squares/circles) with sliding.
- **Camera**: exponential follow + look-ahead + slight sinusoidal "handheld" sway, clamped to the
  walkable area plus a 4-tile margin. The clear color is dark forest green so map edges never show
  black.
- **Placeholder art**: drawn by a tiny software rasterizer (`assets/placeholders/pixel.ts`, writes
  into an `ImageData`), then packed into 1024-wide atlases so Pixi can batch everything. Characters
  use one parametric quadruped drawer for all 8 directions × 10 animations. Zampanò's frame is
  40×40 (the dog is ~30 px wide) — bigger than the 32 px minimum for readability on phones.
- **Debug hooks**: `window.__sv` (scene access, teleport, debug state) and `?debug=sprites&char=…`
  sprite viewer. `npm run screens` drives the game with Playwright for verification screenshots.
