# CLAUDE.md — SUPERVILLAINED

2D isometric game (browser + Android via Capacitor), **no game engine**. **One game, one story**
(title: NEW GAME / CONTINUE / OPTIONS / QUIT), from the VG1 design PDFs ("Supervillained — VG1
implemented", then the level design revision "Supervillained VG1 — Levels implementation 2",
which wins where they differ): 8 levels, 1.0 + 42 sub-levels.
- **1.0 The Green Zone** (`SPEC.md`, the former "arcade"): Zampanò, a Maltese dog, walks through a
  park: eat treats, pee to clean, avoid pollution, bark at the bully pug. It is the first scene
  of Level 1, played by `scenes/gameScene.ts` (`SubLevelDef.greenZone`), not by a story script.
- Then the rest of Level 1, the Fourth-Crusade dream (levels 2–7) and the return (level 8):
  dialogue, dream walks, mini-games and two endings.

Decisions/deviations: `DECISIONS.md`. Sprite replacement: `ASSETS.md`. Delivered art replaces
procedural art in `public/sprites/`; **the art it replaces is never deleted**: it is kept as the
old version in `public/sprites/old/` (`npm run sprites:old`), selectable in OPTIONS > ART.

## Commands

```bash
npm install
npm run dev          # Vite dev server on the LAN (open the printed Network URL on a phone)
npm run build        # typecheck (tsc --noEmit) + production build into dist/
npm run typecheck
npm test             # Vitest (pure logic)
npm run screens      # Playwright verification screenshots → docs/screens/ (all scenarios)
npm run screens -- m1 joystick   # selected scenarios (see scripts/screenshot.mjs)
npm run smoke        # plays every story sub-level start to finish (fails on errors / missing textures)
npm run smoke -- 7.3 8.1         # selected sub-levels
npm run playtest     # the autopilot plays the whole campaign for real → report (fails if a sub-level can't be won)
npm run playtest -- --skill 0.4 --ending alpha --choice random --from 5.1 --out docs/PLAYTEST.md
npm run playtest -- --from 3.1 --to 3.4          # one level
npm run sprites:old  # freeze the procedural art of characters with delivered sheets → public/sprites/old/
npm run android:apk  # web build + cap sync + Gradle debug APK (needs JDK 21 + Android SDK 36)
```

Debug URLs: `?skip=game` (straight into the Green Zone walk, outside the story), `?story=7.3` (straight into a story
sub-level), `?auto=1` (the autopilot plays the story; `&skill=0.7&ending=knight|alpha&choice=first|last|random`), `?debug=sprites&char=zampano|bagnaskiz|cat|<cast key>`, `?art=old|new` (character art version).
`window.__sv` exposes the game for automation (`__sv.scene()` = top scene, `__sv.top()`,
`__sv.storyIds()`, `__sv.flow.story.debugPlay(id)`; a `StoryScene` has `debugState()`,
`debugSkip()`, `marker(m)`).

## Architecture (src/)

- `config.ts` — **every tuning number** (speeds, timers, radii, scores, thresholds; `STORY` for the
  campaign: walks, mini-games, Commozione costs, companion thresholds, Grace tiers, text speeds,
  autopilot). Never hardcode gameplay numbers elsewhere (per-scene values in chapter scripts are
  level data).
- `core/` — `game.ts` (services: renderer, input, scenes, loop, resize), `loop.ts` (fixed 60 Hz
  step + interpolation), `input.ts` (keyboard, floating joystick, touch buttons, taps),
  `scene.ts` (scene stack), `display.ts` (logical resolution + integer scale), `assets.ts`
  (texture registry + atlas packer), `storage.ts` (guarded localStorage), `rng.ts`.
- `iso/` — `projection.ts` (grid↔screen, screen-direction → grid, 8 directions), `depth.ts`
  (painter's sort, occlusion test), `camera.ts`.
- `world/` — `tiles.ts` (ground types, props, ASCII legend), `level.ts` (level types + ASCII parser
  + `loadLevel`), `map.ts` (runtime map: collision, pollution field, zone health, BFS distances),
  `mapRenderer.ts` (chunked ground sprites + pollution overlays).
- `levels/` — level data (`level1.ts`) and registry (`index.ts`).
- `entities/` — `Entity` base (grid position, interpolation, view), `CharacterAnimator`,
  `Zampano`, `PropEntity`, …
- `systems/` — gameplay rules as small, mostly pure classes (unit-tested).
- `ui/` — `pixelFont.ts` + `pixelText.ts` (crisp bitmap text with glow/outline), HUD, touch controls.
- `fx/` — particles, popups, screen effects, glitch filter.
- `scenes/` — `flow.ts` (title → new game / continue / options / quit; plays the 1.0 walk for the
  story), Title, Options, Confirm, Goodbye, Briefing, Game (the walk), Pause, LevelEnd, GameOver,
  `supervillainedScene.ts` (the "You've been supervillained" snap at the end of every level),
  sprite viewer. `core/native.ts`: QUIT closes the app on Android (`QuitPlugin.java`).
- `world/world.ts` — the shared isometric stage (map + renderer + layers + camera + entities),
  used by the arcade `GameScene` and by story stages.
- `campaign/` — the VG1 campaign as data: `state.ts` (meters, flags, book, unlocks, ending; pure,
  tested), `titles.ts`, `home.ts` (8.2 marvel → object at home), `chapters/ch1..ch8.ts` (one file
  per level: sub-levels with `happens`, `source`, optional `blackHole`, and a `script()` that
  returns `Step[]`), `chapters/helpers.ts` (`followLeader`, `lullWalk`, `placeObject`,
  `sounder`, `walkableNear`).
- `story/` — the story engine: `step.ts` (Step interface), `steps.ts` (script vocabulary: say, ask,
  card, stage, move, walk, mini, branch, fx, blackHoleIn/Out…), `walk.ts` (dream walk: reach,
  pickups, sight cones, pace/nerve, thirst, scramble, fire), `minigames/`, `storyScene.ts` (runs a
  script over a World stage), `ui.ts` (dialogue box + choice wheel, cards, story HUD with meters),
  `screens.ts` (story menu, level's sub-level list, cards, pause, Meraviglia book), `storyFlow.ts`
  (menu → cards → sub-level → Professor aside → ending; saves progress; replays on a copy),
  `maps.ts` (story stages + palettes/themes), `carry.ts` (what he carries, shown over his head),
  `autopilot.ts` (automated player: steps and
  mini-games implement an optional `pilot()` that drives the real inputs).
- `entities/actor.ts` — scripted characters (idle/patrol/chase/flee/follow/wander/flail/goto/fly,
  sight cones, hostile contact).
- `assets/` — `manifest.ts` (all sprites: sizes, anchors, anims, `sheet`/`oldSheet`/`animSheets`),
  `build.ts` (load PNGs of the chosen art version or generate placeholders; `setArtVersion`),
  `placeholders/*` (procedural pixel art = the old art), `fonts/`.
- Repo-root `assets/music` and `assets/sounds` — recorded audio, wired in `src/fx/audioFiles.ts`
  (table in `ASSETS.md`); `core/audio.ts` plays them (sfx decoded, music streamed) alongside the
  synthesized sounds of `fx/sounds.ts`.
- `android/` — Capacitor project (committed). Custom bits: `MainActivity.java` (immersive
  fullscreen, keep-screen-on, back button → `svback` window event), portrait lock in
  `AndroidManifest.xml`, fullscreen themes in `res/values/styles.xml`, icons/splash generated from
  `branding/logo.png` (`npm run android:icons` → `scripts/gen-android-assets.mjs`, which also writes
  the web icons in `public/`). `app/src/main/assets/public` is generated by `cap sync`.

## Conventions

- TypeScript strict, ES modules, `import type` for types (`verbatimModuleSyntax`).
- Grid space: tile (i, j) covers [i, i+1) × [j, j+1); entity positions are floats `gx, gy`.
  Screen: `sx = (gx - gy) * 16`, `sy = (gx + gy) * 8`. Map rows = gy, columns = gx.
- Directions (`Dir8`) are screen-space names: N = up on screen.
- Logic in fixed steps (`update(dt)`), visuals in `render(alpha)`; entities call `savePrev()` at
  the start of each step so rendering can interpolate.
- Everything visible in the world goes through the depth-sorted `objectLayer` (props, characters,
  items). Ground decals live in the map renderer / decal layer.
- No new runtime dependencies without a note in `DECISIONS.md`. No CDN resources (offline).
- Game text in English, uppercase pixel font. Story text is written uppercase in the scripts
  (values are stored in mixed case and uppercased for display).
- Story maps: digits are markers used by scripts (`'1'`, `ctx.marker('1')`); `S` is the start.
  A missing marker throws — run `npm run smoke` after editing maps or scripts.
- Meter rules live in `campaign/state.ts` (pure, tested): `fadeCommozione`, `graceTier`,
  `endingNotes`, `ending`. Choices that are big actions take `cost` (Commozione).
- Scripted characters walk in straight lines (no pathfinding): give `followLeader` paths whose
  segments stay on walkable ground, and test a level with `npm run playtest -- --from 3.1 --to 3.4`.
- A new walk objective the autopilot can't infer from `goal`/`pickups` gets a `pilot` hint in the
  `walk()` definition; a new mini-game gets a `pilot()` strategy. After gameplay changes run
  `npm run playtest` and read the report.
- After each milestone: `npm run build`, `npm test`, `npm run screens`, look at the PNGs, commit.
