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

## M2 — Core loop and HUD

- **Zone health** is literally "clean playable tiles / playable tiles" (a tile is clean while its
  dirt < 0.3). Because Level 1 has ~1,700 playable tiles, the stars use a zoomed-in scale:
  80 % clean → 0 stars, 99.5 % → 5 stars (`ZONE` in config), **floored** to half stars so even
  one path poop is visible in the HUD.
- **Pollution**: poops stamp dirt with a radial falloff (max-blend, never additive). Footprint by
  surface: bush/tall grass = small, grass = medium, path = large. Unattended poops slowly
  **spread** (radius ×1.45 over 35 s) until a pee neutralizes the pile (+100 "CLEAN!").
- **Pee** spreads outward over its duration like paint (Splatoon-style), cleaning dirt and leaving
  a short "re-greened" highlight. Marking = a vertical object (tree/pole/bush/fountain) within
  ~1 tile: bigger radius, leg-lift, +150. With no charges the button just shows "EMPTY!".
- **Digestion**: the poop happens when the 3 s warning expires, but waits while Zampanò is busy
  (peeing, drinking) so actions never overlap. Overflow from extra treats carries over.
- **Drinking** is automatic when stepping on a puddle or next to a fountain and a charge is missing
  (short animation, 1.5 s cooldown).
- **Lives**: starving costs a life, refills hunger to 50 and gives 2 s of invulnerability.
- **Events**: gameplay emits typed events (`core/events.ts`); FX (and later audio) subscribe, so
  rules stay free of presentation code.
- **HUD**: drawn with crisp 1 px rects (no stroked shapes). Text uses a 1 px self-colored glow plus
  a dark drop shadow for readability over bright grass (a 2 px glow smeared the 8 px font).
  Radar is screen-aligned (dots are screen offsets), exit shown on the rim when out of range.

## M3 — Scenes

- **Flow** (`scenes/flow.ts`): the GameScene always sits at the bottom of the scene stack; Title,
  Briefing, Pause, Level End and Game Over are overlays pushed on top (the level stays visible
  underneath, as in the video). The Title blurs the frozen level (`BlurFilter`), the Briefing shows
  the HUD dimmed behind the rules text.
- **Glitch filter** written now (one custom GLSL filter: slices, RGB split, scanlines, sepia,
  flash) because the title needs a glitch entrance. Used full-screen for transitions and attached
  only while a transition plays. Note: uniforms shared with the vertex shader are declared `highp`
  in the fragment (precision mismatch otherwise breaks the program on some GPUs).
- **Briefing text** is the spec's sentences, one colored paragraph each (orange / green / red /
  cyan / yellow), fully justified *including* paragraph ends like the video, at 2x scale when it
  fits, else 1x.
- **Level end**: "GOOD BOY!" + stats, stars popping one by one, time bonus, star bonus, total;
  tap skips the animation. Final health applies the PEES < POOPS penalty before computing stars.
  With a single level, NEXT is replaced by TITLE (the flow already supports more levels).
- **Records**: per level best score, best stars and best time are kept independently; coins
  accumulate across runs (also on game over) for the future shop.
- **Auto-pause** on `visibilitychange` (hidden) and window `blur`. Esc / MENU toggle pause.
- Scene changes clear queued input so the key that confirmed a menu can't also trigger a pee.

## M4 — Threats and bonuses

- **Cats** sit until Zampanò is within 5 tiles, then flee: every 0.18 s they score 16 directions
  (moving away + momentum + open space ahead − blocked tiles) — simple, cheap, and they slide
  around trees. Cats run faster than Zampanò walks but slower than he runs; barking at a cat
  startles it (it freezes and hops for 0.8 s), which is the trick to catch one. +5 coins, +250.
- **Balls**: pull strength falls off with distance; walking can't escape near the ball, running
  can. Touching it starts a 2 s uncontrolled fetch run, −8 hunger and +5 s on the timer.
  A pulsing ring converging on the ball shows the magnet area.
- **Spawns** are timed per level (`spawns.cats/balls`: first, interval range, max) and placed
  4–8 tiles from Zampanò, preferably *ahead* on the walk (closer to the exit).
- **Under attack** (`AttackDirector`, pure logic): starts when health < 95 % (cooldown 25 s) or once
  at 55 % of the walk (scripted, level metadata). Ends only when Bagnaskiz has fled **and** health
  is back above the threshold (+0.4 % hysteresis); until then the HUD says "PEE TO HEAL THE ZONE!".
  Effect intensity = 0.35 + deficit / 8 % (capped at 1): sepia/brown palette shift, scanlines and
  random glitch bursts on the world layer only (HUD stays readable).
- **Bagnaskiz** retargets every 2.5 s to the cleanest spot near Zampanò (sampled), stamping a
  pollution trail every 0.22 s. Bumping into Zampanò knocks him back and costs 6 hunger. Barks hit
  when the wave reaches him (range 2.8 tiles, ±43° cone in the facing direction); 3 hits → he flees
  (+400) and fades out.
- The bark sound wave is drawn as three `)` arcs (ground-plane arcs projected to the iso view)
  travelling along the facing direction.

## M5 — Polish and balancing

- **Audio**: own sfxr-style synthesizer (`core/synth.ts`, pure and unit-tested). Every SFX is a
  recipe in `fx/sounds.ts`, rendered once into an `AudioBuffer` at 22 kHz on first use, then played
  as a buffer source (cheap on phones, no audio files). The music loop (8 bars, C–Am–F–G, square
  lead + triangle bass + noise hats) is rendered once after the first tap. The `AudioContext` is
  created/resumed on the first gesture (autoplay rules) and suspended in the background. Music is
  ducked during pause, "under attack" and the level end. Master volume (25/50/70/100 %) and mute
  are in the pause menu and saved.
- **Juice**: squash & stretch spring on Zampanò (treat, poop, bark, cat), screen shake (poop, hurt,
  bark, hit), geometric particles on treats, footstep dust when running, leaves in bushes/tall
  grass, splashes in puddles, HUD values blink when they change.
- **Marking bonus is paid once per object** (re-peeing the same tree is a normal pee), otherwise
  standing next to a tree and spamming PEE was the best strategy.
- **Level 1 rebuilt bigger (96×96)**: a bot showed the first map could be crossed in ~48 s by
  cutting across lawns. Any path that only goes "up" the screen has the same grid length
  (≈ 2 × map size), so the map grew instead. Shortest walk ≈ 75 s at walking speed; with treats,
  peeing, cats and the Bagnaskiz fight a run lands at 2–3 minutes. Par time 180 s.
- **Speeds** slightly lower (walk 2.2, run 3.8 tiles/s) — a Maltese is small, and the camera has
  more time to show what's ahead. Cats (3.1) and the magnet (3.2) sit between walk and run.
- **Hunger drain raised** (idle 0.9, walk 1.5, run 2.3 per second): walking straight to the exit
  without eating now starves, so treats (and therefore poops) are part of every run.
  `tests/balance.test.ts` runs a bot through Level 1 to keep these numbers honest.
- Bagnaskiz trail slightly thinner (radius 0.95, every 0.25 s): one attack now costs about one star
  if left alone instead of two.

## M6 — Android

- **Capacitor 8** (`@capacitor/core`, `@capacitor/android`, dev `@capacitor/cli`): the official,
  minimal way to ship the Vite build as an APK; no Capacitor plugins are used.
- `appId` is `com.zampano.supervillained` (placeholder: change it before publishing anywhere).
- **Portrait lock** in the manifest; **immersive fullscreen** and **keep screen on** in
  `MainActivity.java` with AndroidX `WindowInsetsControllerCompat` (bars reappear with a swipe).
  The display cutout is left in its default mode so the HUD never sits under a camera hole.
- **Back button** without the `@capacitor/app` plugin: an `OnBackPressedCallback` in
  `MainActivity` fires a `svback` window event; the game toggles the pause menu (ignored on title
  and result screens, so Back never kills a run by accident).
- **Icons and splash**: generated pixel-art Zampanò face (legacy, round and adaptive icons, black
  splash screens) by `scripts/gen-android-assets.mjs`, a dependency-free PNG writer.
- Verified in the dev container: `assembleDebug` succeeds with JDK 21 + SDK platform 36
  (≈4 MB APK, portrait, assets and font bundled).

## VG1 — The story campaign (from "Supervillained — VG1 implemented")

The PDF is a narrative design (8 levels, 42 sub-levels, characters, systems, sources). It says
itself that it "is not a playable build"; this phase turns it into one, on the same engine.

- **Two modes**: the title menu now offers **STORY** (the VG1 campaign, "The dream of the cross")
  and **ARCADE: GREEN ZONE** (the original SPEC level, unchanged and still tested by m1–m6).
- **Shared world**: the arcade `GameScene` was refactored around `world/world.ts` (map, map
  renderer, depth-sorted layers, camera, entities). Story stages use the same class, so movement,
  collision, occlusion, camera and art are identical in both modes.
- **Stages are ASCII maps** (`story/maps.ts`, 19 maps) parsed by the same parser with two options:
  `base` (ground under props/markers) and `requireExit: false`. Legend extensions: grounds `_` floor,
  `:` stone, `-` sand, `*` snow, `~` deep water (solid), `%` wall (solid), `^` dock, `+` carpet;
  props `C` column, `D` desk, `K` shelf, `H` house, `N` tent, `G` galley, `R` rock, `U` statue,
  `X` crate, `Y` palm, `A` altar, `M` stall, `O` throne, `V` vine, `Q` gate, `Z` bones, `L` table;
  digits `0–9` are script markers. Each map names a **theme** (palette swatches per ground/prop).
- **Look**: "pastel for the Jerusalem dreams, full colour for the Greek world" — each theme is a
  palette; level atlases are rebuilt per palette and the last two are kept (memory on phones).
- **Scripts are data**: a sub-level is an array of `Step`s (`story/steps.ts`: `say`, `ask`, `card`,
  `stage`, `move`, `walk`, `mini`, `branch`, `blackHoleIn/Out`, …) run by `StoryScene`. Steps can
  `interrupt` (caught by a guard, nerve broken) and `insert` (branches, runtime-built walks).
  Scripts are rebuilt on every play (closures hold per-run state).
- **Dream walk** (`story/walk.ts`): one configurable step covers reach / collect / wonder hunt /
  stealth (sight cones with line of sight; bushes hide) / chase / **pace** (7.3 and 8.3: a nerve
  meter replaces health; full stick = "do not charge", moving back = "do not turn back", standing
  still drains too; Supervillain full = "unshakeable", drains at 40 %) / **thirst** (6.4: the lake
  recedes whenever you get close) / **scramble** (8.1: controls rotate, then settle near the goal)
  / **fire** (7.4: spreading flames that push you back).
- **Mini-games** (`story/minigames/`): rhythm (3.3 weeping, 4.1 parade), ladders (5.2 rehearsal,
  7.2 real assault), calm rescue (4.2), toy catapult (6.1), tug of war meant to be lost (7.7),
  euphemism letter (5.4), rumour ordering (6.2). They hide the stage and draw their own screen.
- **Systems as rules** (`campaign/state.ts`, unit-tested): meters Commozione 20, Supervillain 10,
  Grace 70, Standing 50 (max 100). "An unmoved Zampanò cannot act": the preacher's sermon (2.3)
  spends Commozione. Forms: breaking a rule (dice, Friday meat) costs Grace even when absolved.
  Dissent costs Standing, never the level. The **Meraviglia book** (pause menu / story menu)
  lists meters, values, marvels, items, shards and the "remembered" line of each dream scene.
- **Unlocking**: level 1 is always open; a level opens when the previous one is complete *or* when
  its memory shard was picked up in the Professor's study (1.2). Progress is saved after every
  sub-level (localStorage key `story`).
- **Costumes**: plain → rag cross (1.5) → knight (2.5); the dream stages dress him with the best
  unlocked one, Greenzone stages (1.x, 8.x) in his own fur ("armour is costume").
- **Ending**: decided at 7.8 by doing, not by a menu — bark three times at Jack to enforce the oath
  ("no woman touched") or walk on to the common pile. `flags.oath === 'enforced'` → THE KNIGHT
  (Bagnaskiz turns in 8.3 and ends in the rest home); otherwise THE ALPHA-DOG (he steps aside and
  smiles: the offer stands). Both end with "YOU HAVE BEEN SUPERVILLAINED" and the 8.4 scene.
- **"The goal not reached"**: after 7.8 a JERUSALEM / LOADING… card never loads; 8.3 opens with the
  PDF's "We were going to Jerusalem … It was pastel." exchange.
- **Comradeship carries over**: not laughing at the wake (6.6) changes Confusione's line and adds
  Supervillain at the breach (7.7).
- **8.2**: each marvel in the book becomes an object at home (`campaign/home.ts`, e.g. the
  Hippodrome → "THE RUG (IT IS A RACETRACK)"); up to six are placed by hand, the rest are counted.
- **8.4**: the 1.4 dialogue wheel returns with one right option ("NOBODY. I WANTED YOU TO THINK
  SO."), shown locked — he still fails to pick it.
- **Interpretations where the PDF leaves a choice**: black holes 7.5 has no named value, so it
  gives "A dream embraces nothing"; 8.3 gives "Resistance" (board: the ending as "resistenza");
  7.3 and 7.8 give "Physical courage" and "Kept oaths" from the "being a knight" table. The
  optional Jack race ("honour against craft") is not implemented. Marvel and home-object names
  are short paraphrases of Clari's catalogue as quoted by the PDF; no outside history was added.
- **Characters**: all cast members are generated placeholders on the same quadruped drawer
  (hats, marks, costumes, eyes, topknots), built lazily on first use (`ensureCharacters`); a
  dialogue portrait for a speaker who is not on stage is generated on demand.
- **Music**: a second synthesized loop, `medieval` (modal melody over a drone), for the dream;
  `chip` stays for the Greenzone. No audio files, still offline.
- **Text**: notices and world popups now wrap to the screen width; choice rows grow with their
  wrapped labels; cards double their size only when every line fits 12 glyphs.
- **Bug fix (all modes)**: PixiJS uploads a `CanvasSource` on `resize` *before* resizing the canvas
  element, so a text that grew in one dimension and shrank in the other uploaded a stale canvas
  into a smaller texture ("GL_INVALID_VALUE: offset overflows"). `PixelText` now grows first and
  shrinks in a second call.
- **Testing**: `tests/campaign.test.ts` (state rules, 8 levels / 42 sub-levels numbering, every
  script builds, every map parses, every awarded marvel has a home object) and
  `npm run smoke`, a Playwright run that plays every sub-level start to finish by skipping steps
  (`StoryScene.debugSkip`) and fails on page errors, missing textures or GL errors.
