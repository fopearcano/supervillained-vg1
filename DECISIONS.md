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

## Playability and systems pass

- **Autopilot** (`story/autopilot.ts`): an in-game player for automated playtests. It plays through
  the same inputs a person uses (movement vector override and injected taps on `Input`, never by
  calling game logic): confirm on dialogue, a policy for choices (first / last / random; a prompt
  seen again gets the next option, so loops end), Dijkstra paths that avoid what guards can see
  (it waits on a safe tile while a cone passes), hostile animals and fire, walking pace for pace
  walks, scrambled-control compensation after a human-like reaction delay. Each mini-game has its
  own strategy with `skill`-based error (rhythm timing noise and wrong gestures, tapping rate,
  ladder dodges, catapult timing). Steps opt in with an optional `pilot()` method.
- **`npm run playtest`** plays the whole campaign (1.1 → ending) at accelerated speed and writes a
  report (`docs/PLAYTEST.md`): game seconds, restarts, times caught, nerve broken, mini-game
  results and the meters after each sub-level. It fails if a sub-level cannot be finished.
  `StoryScene.metrics` counts restarts for every player, not only the bot.
- **What the first playtests showed**: everything was winnable, but Commozione reached 100 by 3.3
  and stayed there, ladders took 4-5 s, and 2.1 (the beasts) was the only walk that kept
  restarting. Fixes:
  - **The feeling fades**: every dream sub-level (levels 2-7) starts with 2 less Commozione;
    weeping gives 1 per correct beat, the weeping rounds 6, marvels 3 (5 in 7.8).
  - **An unmoved Zampanò cannot act**: the big actions cost Commozione and are locked without it
    ("TOO UNMOVED: NEEDS 10 COMMOZIONE"): atoning at the emir's table (8), speaking up at Zara
    (10), serving the saint unpaid (10), the vigil at the wake (8), defying the emperors (10),
    each bark at Jack at the sack (5; the 7.8 marvels refill exactly enough). A choice never
    dead-ends: if every option is out of reach, the costly ones open.
  - **Standing decides who walks beside him**: in 7.3 Sbrimbrulon always, the count of Saint-Pol
    from Standing 45, Flanders (shamed back to the front) from 65; on the lawn in 8.3 Confusione
    always, Sbrimbrulon from 35, Watson crosses over from 60. Each companion beside him removes
    some of the pace pressure.
  - **Grace shows**: the 8.2 altar glows (≥70), is crooked (≥40) or is made of chew toys, and
    the ending card adds a Grace line and a Standing line.
  - **Ladders**: 18 rungs (5.2) and 30 (7.2), stones every 0.55 s in the real assault, at most one
    rung per 0.12 s however fast he taps.
  - **2.1**: checkpoints after the first stretch and near the end; the bear and the hound are a
    little slower.
  - Result: two full runs (skill 0.7 / knight / first choices, and skill 0.4 / alpha / random
    choices) finish all 42 sub-levels with at most one restart each; Commozione now moves
    between roughly 10 and 60.
- **Tuning moved to `config.ts`** (`STORY`): sight cones, pace, thirst, scramble, fire, rhythm,
  weeping and parade, ladders, tug of war, calm, catapult, rumour, costs, companion thresholds,
  Grace tiers, text speeds, autopilot. Per-scene numbers (a walk's pressure, a ladder's rungs)
  stay in the chapter scripts, which are level data like the maps.
- **Quality of life**: text speed (slow / normal / fast / instant) in the story pause menu, saved
  with the settings; a level's sub-level list from the story menu, where any finished scene can
  be replayed on a copy of the campaign (nothing is saved, the card says so); the Meraviglia book
  pages by real text height, with an icon per section and an "AT HOME" section first.
- **Bugs found on the way**: changing stage inside a sub-level destroyed the scene's own particle
  and popup layers (crash at the next burst; it surfaced as soon as the bot played everything);
  a catapult shot could break every glass with shots to spare and the game then waited forever.
- **Review fixes**: RESTART SCENE no longer fades Commozione a second time (only a fresh visit
  does); only companions who actually fell in beside him (following him) ease the pace pressure,
  not bystanders on the path who stayed back for lack of Standing; the autopilot's `skill` URL
  parameter is clamped, its timers use the real step length, and its tuning lives in
  `STORY.PILOT`; the Meraviglia book builds each line's text once; scene titles in the level list
  keep a complete last word when shortened.
- **Title screen**: SUPERVILLAINED is the logo, always on one line, as big as fits. It is drawn
  with its own bold 6×7 pixel lettering (`ui/logo.ts`, same chunky style as the game font but
  narrower), so it fits at double size on ~200-px phones (186 px) and grows on wider screens;
  outline, drop shadow, soft glow and a small vertical gradient. CRUSADER is the edition title
  under it (the story menu reads "SUPERVILLAINED: CRUSADER"). The footer reads
  SUPERVOID EDITIONS, dimmed, at the pixel font's smallest crisp size.
- **App icon and logo**: the logo supplied by the user (a blue pixel brush shape) replaces the
  generated Zampanò face. Its cream background was white-balanced to pure white and it was
  cropped to the shape (`branding/logo.png`); every launcher icon, the splash screens (now white
  with the logo in the middle) and the web icons are derived from it by
  `scripts/gen-android-assets.mjs`, still dependency-free (a small PNG decoder and an
  area-average resize). The whole shape is always visible: it fits the square icon, the circle of
  the round icon and the adaptive icon's safe zone.
- **Recorded music and sounds** (uploaded to `assets/` on `main`) replace the synthesized ones they
  correspond to, and the old chiptune loop is removed (table in `ASSETS.md`). This departs from the
  SPEC's "zero mandatory assets": the files ship in the repo, so the game still runs offline right
  after cloning. Sound effects are decoded once into buffers (leading silence skipped); the two
  music tracks are streamed through an `<audio>` element routed into WebAudio (decoding the 4-minute
  track whole would take ~80 MB on a phone), so mute, volume and ducking still apply; music pauses
  in the background. Readings where the file name left a choice: `pees-drop` is the pee itself and
  `pees-collect` the refill at water ("collect" like `food-collect`); `water` is stepping into a
  puddle; `siren` loops under the "under attack" alarm until the attack ends (and is the fire alarm
  in 7.4); `laser-eyes` is Bagnaskiz's hit on Zampanò. There was no file for the dream, so levels
  2-7 keep the synthesized medieval loop. Capacitor already lets media play without a fresh tap,
  so music changes work inside the app, and there the audio starts at launch so the intro music
  plays on the title without a tap. Browsers forbid sound before the first tap, so on the web it
  still starts with the first touch or key.
- **RUN is a button, and it costs energy.** Running used to happen by pushing the joystick all
  the way (or holding Shift). Now it is a third touch button, RUN (above PEE and BARK; Shift or K
  on a keyboard), held while moving. Running spends an energy meter drawn as a ring around the
  button (`ENERGY` in `config.ts`: a 5-second sprint from full). It refills while walking or
  standing, slower in the arcade while Zampanò is hungry, and once it is empty he is "TIRED!" and
  can't run until it is back to 35%. The joystick now only walks, at any push. In the story the
  button is hidden in walking-pace scenes, scripted runs in cutscenes cost nothing, and the
  autopilot holds RUN when it wants to run; the full playtest still wins every sub-level.
- **Faster Zampanò, more treats.** Walking 2.2 → 3.4 and running 3.8 → 5.8 tiles/s (in two
  steps). What depends on those speeds keeps its meaning: the ball's pull still beats walking near
  the ball but not running, Bagnaskiz chases slower than a walk, cats (3.9) still need a run to
  catch, and hunger drains in proportion, so a tile walked costs the same as before and not eating
  at all still loses a life. Level 1 has 44 treats instead of 30 (closer spacing). The shortest
  walk is about 48 s instead of 74 s, and food is much easier to find.

## VG1 level design, revision 2 ("Supervillained VG1 — Levels implementation 2")

The second PDF rewrites every sub-level (same 8 levels, 42 sub-levels). The scripts in
`campaign/chapters/` now follow it scene by scene; where it supersedes the first PDF, it wins.

- **New engine pieces** (all reusable): `followLeader()` (he follows his father, Sbrimbrulon, the
  bread seller, a bolt of cloth, the Doge's banner; the leader waits when he lags), `lullWalk()`
  (a voice fills the air, then pauses: only what he does in the lull is heard — 2.3 Fulk, 3.3 the
  trumpets of San Marco, 7.8 the looting; the PDF's "learn to wait for another voice"),
  `carry()` (a label over his head: red cloth, the collecting bowl, the vote, a message, the
  sail, a crate), hidden goals found by ear (`goal.hidden` + `sounder()`: 7.5 the previous room,
  7.7 the rattle of mail), scene overlays (`visor` for 1.1's slipping helmet, `fog` for 7.4's
  smoke, `bleach` for 6.4's desert and 7.1's saturated city), a boat mini-game (4.2), a rowing
  rhythm (4.5), the tug game reused for rowing the prince (7.1).
- **The neighborhood** (`neighborhood` map, levels 1 and 8): home and study, Jack's garden gates,
  the common lawn and the band's water bowl, Jack's next opening, the hedge with its gaps and the
  longer lower lane, Santina's garden gate. New art: a garden gate prop (`J`) and the water bowl.
- **Removed or changed from the first version**: the memory shards no longer unlock later levels
  (levels open in order); 1.2's sniffed "scraps of the lecture" live in the book in their place.
  Standing no longer decides who walks beside him (7.3 and 8.3 follow the PDF: Pierre, Saint-Pol
  and Flanders in 7.3, Sbrimbrulon and Confusione in 8.3); it still shapes the ending notes. 7.3's
  nerve gauge now measures staying level with Pierre's shoulder. The 6.1 catapult is now about
  whisking the glass away before the shot lands. 8.1 has no chasing hound.
- **Hard cuts** (4.3–4.5, 6.3–6.5, 7.5) keep the black-hole cards and their values.
- **Endings**: 7.8 is "call the oath in a lull" or "stand silent while Niketas calls it". Both
  leave the girl with her family; the book records his own words or Niketas's, and 8.2 reads it
  back. Internally the endings are still `knight` / `alpha`; the screen now says THE KNIGHT or
  THE WITNESS (staying silent is not villainy in this version: Bagnaskiz steps aside either way).
- **8.4 ends on a cut**: no answer wheel; the PDF says to cut before he finds an answer.
- The autopilot plays all of it (`npm run playtest`, new `--to` option for one level); three full
  runs (both endings; first, last and random choices; skill 0.4–0.9) finish every sub-level.

## One game: the Green Zone walk is Level 1, not a separate mode

The arcade "Green Zone" and the story were two modes on the title screen. They are one game now:
the dog walks the Green Zone, falls asleep, dreams the crusade and wakes up supervillained, no
longer bullied in the Green Zone.

- **1.0 The Green Zone**: the SPEC walk is the first scene of Level 1 (`greenZone: 1` on the
  sub-level; `StoryFlow` hands it to `Flow.playGreenZone`). Briefing → walk → level end with
  CONTINUE into 1.1, which opens with him dozing off on the lawn after the walk. RETRY replays the
  walk; game over offers RETRY. Coins from the walk go to the story's purse. Numbered 1.0 so the
  PDF's 1.1–1.5 keep their numbers. Saves made before this count 1.0 as done if 1.1 is.
- **Title**: NEW GAME (asks before wiping a saved story), CONTINUE (the next unfinished scene; the
  label under the menu says which; always yellow, and with no save it starts the story), OPTIONS (sound, volume, text speed,
  LEVELS for replays, the Meraviglia book), QUIT. The story's pause menu now quits to the title.
- **QUIT**: on Android it closes the app through a tiny local Capacitor plugin (`QuitPlugin.java`,
  registered in `MainActivity`; `src/core/native.ts` uses `@capacitor/core`, already a
  dependency). A browser tab cannot close itself, so the web version shows a goodbye card. The
  phone's back button on the title also quits.
- The autopilot does not play the walk (it marks 1.0 as done and goes on); the screenshot
  scenarios m1–m6 play it, now starting from NEW GAME.
- **Music follows what the player is doing**: the intro music plays on every screen meant for
  reading (title, cards, briefing, score, the Professor, the ending); a level's own music (Green
  Zone or medieval) starts only when the play starts. Each track resumes where it was paused
  instead of restarting from the top.
- **Title page**: the SUPERVILLAINED logo and CRUSADER sit at the top; Zampanò's portrait
  (`assets/starting-page-images`) over the buttons, 1/3 of the screen wide (the "You've been
  supervillained" logo that sat under them moved to the end of the levels: see below); the
  blurred Green Zone behind is an old dirty film (fine grain, a slight brightness flicker, faded
  warm colors, darker edges, two thin vertical scratches that stay put, drift and break up, dust
  specks that change every film frame, the picture jumping a pixel now and then) that glitches
  only now and then (every 3.5 to 8 s, short and mild: a constant strong glitch was annoying),
  mostly vertically (`fx/titleGlitchFilter.ts`: columns tearing up and down, a vertical RGB
  split, rolling, tall corrupted blocks, vertical bars, a few horizontal tears). Tuning:
  `TITLE.GLITCH_*` and `TITLE.FILM`. The stack
  is laid out as below ("Title page layout").
  The pictures are scaled in the browser (step-by-step halving, crisp alpha) to the logical
  resolution, so they match the pixel art at any screen size.


## Sprite update 1: delivered character art, the old art kept

`Supervillained-vg1-sprite-update-1.zip` (uploaded to main, kept at the repo root as delivered)
brings sheets for Zampanò (new run), Bagnaskiz, Sbrimbrulon, Jack, Watson and Confusione, a
`tired` animation for Zampanò and a RUN icon. Wired as its README asks (sheets in
`public/sprites/`, `sheet:` in the manifest), with these choices:

- **The replaced art is kept as the old version, never deleted.** `public/sprites/old/` holds the
  procedural art each sheet replaced, frozen as PNGs in the same layout by
  `npm run sprites:old` (it draws them with the game's own generator, which stays in
  `src/assets/placeholders/`). OPTIONS > ART: NEW / OLD switches between them at once and is
  saved; `?art=old|new` for tests. The old art keeps its RUN chevrons and its dialogue name
  colors; the new art gets name colors that match it (Sbrimbrulon rust, Jack pink, Confusione
  orange).
- **Tired**: Zampanò pants (the delivered `tired`, its own sheet via `animSheets`) while he
  stands still with the energy emptied, until RUN is available again. It is new-only: the old art
  (and a sheet without the rows) shows the idle frames.
- Every character with a sheet is loaded at boot (≈150 KB of PNGs), because a sheet loads
  asynchronously and a story scene spawns its actors at once; the rest of the cast is still
  generated on demand.
- The costumes (`zampanoCross`, `zampanoKnight`, `bagnaskizMarshal`, `bagnaskizEmperor`) were not
  in the update and stay procedural in both versions.
- `tests/sprites.test.ts` checks every sheet's size against the manifest layout, the old ones
  included.

## "You've been supervillained" at the end of every level

The logo left the title page. It now marks the end of each level, before the level's final info:

- **When**: the Green Zone walk (1.0) before its score card, and every story level (1 to 8) before
  the Professor's aside (so Level 1 has it twice: after the walk and after 1.5). Not for replays
  of a single scene, not for the autopilot.
- **How**: it appears at once, over the frozen last frame (dimmed): twice its size snapping down
  to it in 0.12 s with a decaying thump, a white flash, a shake, the glitch sound with a bark, and
  a burst of sparkle and star sprites flying out of it; a pale halo pulses behind. It holds 2.4 s
  (a tap skips it after 0.45 s), then the final info. All numbers in `config.ts` (`SUPERVILLAINED`).
- The title page keeps its portrait, buttons and glitch; with the logo gone the stack sits a bit
  lower.

## Title page: the animated portrait

The portrait over the title's buttons is now `Zampano-Samemala-2.gif` (44 frames, about 2 s,
1024 × 1536), animated. A browser draws only one frame of a GIF into a canvas, so the frames are
decoded with WebCodecs' `ImageDecoder` (built into Chromium and the Android WebView; no new
dependency), halved down to 256 px, cropped to the dog (the union of the frames' opaque areas, so
it fills the same width as the old portrait), scaled to the title's width with crisp edges and
packed into one texture; each frame keeps its GIF delay. Decoding starts at boot and takes a few
hundred ms; until then the title keeps the portrait's place (`TITLE.DOG_ASPECT`) so nothing moves
when it appears. Where `ImageDecoder` is missing the first frame is shown still. The old portrait
is kept as the old art (OPTIONS > ART: OLD), like the replaced sprites. SUPERVOID EDITIONS is
green.

## Title page: GLOSSARY and the publisher link

- **GLOSSARY** (violet, before QUIT) opens a floating paper card over the title (which keeps
  animating behind it, without input): the dictionary entry of "supervillain, supervillained" as
  given (headword, pronunciation, a) noun, b) verb). The b) verb ("to grow up strong; to get
  character"), the sense the game is about, is circled by hand in red, as in the source image: the
  ring draws itself when the card opens; the noun is in a faded ink. The text follows the game's
  uppercase rule except the pronunciation, which stays lowercase IPA: Press Start 2P has no IPA,
  so the pixel font borrows ' and : for the stress and length marks and makes the schwa from its
  own "e" turned upside down. It closes with CLOSE, a tap outside it, Enter or back. Tuning:
  `GLOSSARY` in `config.ts`.
- **SUPERVOID EDITIONS** (now green and underlined) opens https://supervoideditions.com/: in the
  phone's browser on Android (a new `openUrl` method on the app's own plugin, `QuitPlugin.java`, an
  ACTION_VIEW intent: the game stays open behind), in a new tab in a browser.

## Title page: COUCH, the saved story at a glance

There are no accounts (the game is offline and saves on the device), so the "account" is the
save itself: **COUCH** (orange, after CONTINUE; his couch is where the story starts and ends)
opens a floating paper card like GLOSSARY, read-only:

- the next scene (or, once it is finished, the ending his choices lead to: THE KNIGHT or THE
  WITNESS), the scenes done out of 43 with a percentage, and one cell per level filled with its
  share of scenes (green when done);
- the four meters (Commozione, Supervillain, Grace, Standing) as bars with their values;
- the Meraviglia book (values, marvels, things carried home, shards), coins, the costume
  (none / rag cross / armour), the Green Zone best (score, stars, time);
- play time and when it was last saved. Both are new in the save (`playTime`, `savedAt`; older
  saves start at 0 / never): story scenes add their time while they run (not replays), the Green
  Zone walk adds its time when it is over, and every save stamps the date.

`campaign/summary.ts` (`progressSummary`, pure and tested) builds what the card shows. With six
buttons the title's stack could overflow a short screen (a desktop window), so the portrait now
shrinks to the room left. Measuring text uses `textWidth`/`textHeight` (a PixelText sprite is
padded and rounded up to 16 px), which also centers GLOSSARY's ring and the footer's underline
exactly.

## Title page layout, the title's glitch, the publisher's glow

- **Layout**: SUPERVILLAINED and CRUSADER sit near the top (their top at 7% of the screen height,
  `TITLE.TOP`), the buttons (and where CONTINUE goes) one button's space above SUPERVOID
  EDITIONS (`TITLE.BOTTOM_GAP`), and the animated portrait in the middle of the space between them
  (smaller if that space is short).
- **The title glitches** (`fx/textGlitchFilter.ts`, on the title and CRUSADER together): short
  bursts every 1.8 to 4.5 s in which horizontal slices of the letters jump sideways, the colors
  split and rows flicker; a faint shiver in between. It touches only the letters (premultiplied
  colors are clamped to their alpha), never the space around them.
- **SUPERVOID EDITIONS** lost its underline (it is still a link) and glows slowly: a blurred,
  outlined pale-green copy behind it breathes in and out (about 5 s per breath).
  Tuning: `TITLE.TEXT_GLITCH_*`, `TITLE.FOOTER_GLOW_*`.

## Story cards: no design notes, one Green Zone page, names in yellow

- The level card no longer shows `CAST: ...`: the chapter's `cast` field is design information
  (who plays whom), kept in the data and the bible, not shown in the game.
- The Green Zone walk (1.0) has a single presentation page: LEVEL 1, THE GREENZONE and what the
  walk is (the scene's text), then the rules briefing. The level's own intro and the separate 1.0
  card (with its SOURCE line) are not shown for it.
- Names in the card texts (level intros, scene cards, the Professor, the ending) are yellow:
  the cast and the historical people, not places (`story/names.ts`, `NAMES`).

## The Green Zone page's text, the third title portrait

- The Green Zone page (1.0) reads: ZAMPANO WAKES ON THE COMMON LAWN. THE WAY HOME RUNS THROUGH A
  NEIGHBORHOOD WHERE EVERY OTHER DOG CAN WALK STRAIGHT TO THE WATER BOWL. EAT TREATS AGAINST
  HUNGER, PEE TO CLEAN WHAT THE POOPS SPOIL, CATCH CATS FOR COINS, IGNORE THE BALLS, AND BARK AWAY
  AT BAGNASKIZ WHEN HE POLLUTES THE ZONE. AT THE END OF THE WALK, TIRED, HE LIES DOWN ON THE LAWN.
  (ZAMPANO without the accent: the pixel font has no ò, like everywhere else in the game.)
- The title portrait is `Zampano-Samemala-3.gif` (99 frames, about 4 s, 6.6 MB). Frames are
  reduced to 192 px before cropping (256 before) to keep memory low while 99 frames are packed;
  the previous GIFs stay in the folder.

## Sprite update 2: the complete Zampanò, a third art version

`Supervillained-vg1-sprite-update-2.zip` (uploaded to main, kept at the repo root) brings the
complete new Zampanò and, for the first time, his two dream costumes as sheets (rag cross,
armour), each with a tired sheet. Its other six files are byte-identical to update 1. Its README
mentions source changes made on Codex's local copy; they were not delivered, so the integration is
done here, with these choices:

- **Three art versions**, cycled by OPTIONS > ART: NEW (update 2), UPDATE 1, OLD. The update-1
  Zampanò it replaces moved to `public/sprites/v1/`; the procedural costumes it replaces were
  frozen into `public/sprites/old/` by `npm run sprites:old` (the other old PNGs came out
  byte-identical). Saved settings keep working ('new' / 'old'; 'v1' is new).
- The manifest's `sheet` / `oldSheet` / `animSheets` became `sheets`: sets tagged with the version
  that introduced them; a version shows the newest set at or before it. So the band keeps update
  1 under NEW, and the costumes show the procedural art under UPDATE 1, as that version did.
- The costumes gained the `tired` animation (from their own sheets); with older art it shows idle.
- Every character with a sheet in any version loads at boot (now about 450 KB of PNGs), as
  before, so story scenes never spawn a character before its textures exist.

## Title: the portrait moves at once, INSERT BRAIN; no SOURCE lines

- The animated portrait used to wait for all 99 GIF frames to be decoded and scaled (about 5 s in
  a test browser, a few seconds on a phone), showing the first frame still meanwhile. Now each
  frame plays as soon as it is decoded (`TitlePlayer` holds a frame if playback catches up with
  the decoder; decoding runs faster than the GIF plays): the dog moves about a second after the
  title appears. The crop is fixed from the first frame (its dog plus a margin) instead of the
  union of all frames, and frames are scaled with the browser's resizing `createImageBitmap`
  instead of step-by-step halving (about twice as fast).
- Under the buttons, the line saying where CONTINUE goes is replaced by a blinking INSERT BRAIN
  (an arcade INSERT COIN), centered, nearer the buttons than the publisher line
  (`TITLE.INSERT_BRAIN_AT`). Where CONTINUE goes is in COUCH.
- The scene cards no longer show `SOURCE: ...` (the conference or board reference): like CAST, it
  is design information, kept in the chapter data and the bible.
- The buttons and INSERT BRAIN then rose by one more button's space (`TITLE.BUTTONS_RAISE`), towards
  the portrait, which stays where it was (it only shrinks or moves up if a short screen leaves no
  room).

## Music for levels 2, 3 and 4

Three recorded tracks (uploaded to main, `assets/music/Level-N_...mp3`) play while the scenes of
their level are played, like the Green Zone track in levels 1 and 8; the reading screens keep the
intro music and levels 5 to 7 the synthesized medieval loop. They are mastered louder than the
Green Zone track (by 4.7, 1.5 and 6 dB on average), so each gets a gain trim
(`AUDIO.MUSIC_FILE_GAIN`) through its own gain node. They are long (about 6 minutes) and came at up
to 320 kbit/s (38 MB, a 59 MB APK), so the game bundles copies re-encoded as MP3 VBR at about
130 kbit/s (`ffmpeg -codec:a libmp3lame -q:a 5`, 18.8 MB; same loudness, so the trims stand); the
uploaded files are kept untouched in `assets/music/originals/`, which nothing imports.

## A smaller app

The debug APK had reached 59 MB. What changed (originals always kept in the repo, unbundled):

- **Music**: every track is bundled as MP3 VBR at about 130 kbit/s (`ffmpeg -q:a 5`; the level
  tracks came at up to 320 kbit/s); same loudness, so the gain trims stand. Uploads stay in
  `assets/music/originals/`.
- **Title portrait**: the 6.6 MB GIF is bundled as a lossless animated WebP (2.3 MB), checked
  frame by frame and delay by delay against the GIF; `ImageDecoder` decodes WebP like GIF.
- **Old still portrait** (ART: OLD): a 384-px copy (0.2 MB) instead of the 1024-px original.
- **Release build** (`npm run android:release`): R8 shrinks and optimizes the code (about 8.6 MB of
  dex in the debug build, 0.8 MB here). Capacitor's own ProGuard rules keep its plugins and their
  `@PluginMethod` methods (QuitPlugin's `quit` and `openUrl` checked in the dex), Android's default
  rules keep the WebView's `@JavascriptInterface` bridge. It is signed with the debug key so it
  installs from a file like the debug APK; publishing on the Play Store needs an upload key kept by
  the publisher (never in the repo), set in `android/app/build.gradle`.

## Faster dog; lives for speed

- Zampanò walks at 3.9 tiles/s and runs at 6.7 (were 3.4 and 5.8), everywhere he is played. The
  Green Zone's hunger drain while walking and running grows in proportion (2.64 and 4.04 per
  second), so hunger per tile walked is unchanged and finishing the walk without eating is still
  not viable; the balance test's floor for the shortest walk drops from 45 to 40 seconds.
- **INSERT BRAIN [Nx]**: the title's counter, right of INSERT BRAIN, sets the lives of the Green
  Zone walk (the only part of the game with lives): from 2 (the old default) up to 9, a tap (or
  RIGHT) adds one and wraps back to 2, LEFT takes one off. It is saved. Each life above 2 costs 5%
  of his speed in the walk (9 lives: 65%) - **SPEED FOR LIVES**, the blinking light-grey line
  under it, two lines of space above SUPERVOID EDITIONS. The dream walks have no lives (they
  restart), so the speed cost stays in the Green Zone. Tuning: `LIVES.MAX`, `LIVES.SPEED_COST`
  (`systems/lives.ts`, tested).
- Faster again at the base 2 lives: walk 4.4, run 7.5 tiles/s (hunger drain 2.98 and 4.52 per
  second, same hunger per tile). The balance test now checks the shortest walk in tiles (over 150)
  instead of seconds, so it does not move with the speed. The full playtest passes.
- Title layout: the block under the title (portrait, buttons, INSERT BRAIN, SPEED FOR LIVES) is
  centered between CRUSADER and SUPERVOID EDITIONS, measured from the dog's visible top (the
  frame's transparent crop margin is left out): the same space above and below it, the title
  where it was. On short screens the portrait shrinks to keep at least `TITLE.BLOCK_MIN_MARGIN`.
