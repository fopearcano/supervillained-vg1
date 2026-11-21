# SUPERVILLAINED VG1 — Godot migration milestones

The sequence is deliberately vertical: validate the highest-risk contracts first, deliver a playable slice in Milestone 2, then expand without breaking the PixiJS baseline.

## Working agreement

- The planning commit stays on `codex/godot-port-architecture`.
- Claude Code creates `godot/vg1-port` from the reported planning SHA.
- Game implementation changes are confined to `/godot`. Updates to `docs/porting/` may record evidence/approved decisions. The root PixiJS, Capacitor, and iOS implementations remain unchanged.
- Only one implementation agent writes at a time. The Lead Game Architect reviews each milestone independently before the next begins.
- No milestone is complete from screenshots alone. Its automated checks, functional acceptance, manual checks, deliverables, and source-tree guard all have to pass.
- Every commit must keep the source baseline buildable. Periodically rerun `npm test` and `npm run build`; never “fix” the source to make the port easier.

## Common gates for every implementation milestone

1. Godot editor import completes without errors or missing resources.
2. Headless test runner exits zero.
3. `git diff --check` passes.
4. No generated `.godot/`, APK/AAB, keystore, editor settings, or device data is committed.
5. A source-tree guard confirms no unapproved file outside `/godot` and `docs/porting/` changed.
6. The milestone report lists exact commands/results, known deviations, captures, and manual test device/environment.
7. Feature-matrix boxes are checked only after architectural review accepts the evidence.

Recommended test entry point:

```powershell
& 'C:\Program Files\Godot472\Godot_v4.7.2-stable_win64.exe' --headless --path godot --script res://tests/test_runner.gd --suite all
```

The runner must return a nonzero process code on any failure. Do not add a third-party test framework unless the architect approves it.

---

## M0 — Audited plan and immutable baseline

**Objective:** establish the exact source revision, current feature status, target architecture, test strategy, and implementation branch point without starting the port.

**Source systems involved**

- All requested documentation and source directories.
- Asset deliveries/manifests, maps, Android configuration, saves, tests, and automation scripts.

**Godot files to create**

- None.

**Functional acceptance criteria**

- `ARCHITECTURE.md`, `FEATURE_MATRIX.md`, `MILESTONES.md`, and `TEST_PLAN.md` agree on scope and IDs.
- Canonical scene count is 37 entries, not an obsolete 42/43 count.
- Completed, partial, planned-only, and retired source capabilities are distinguished.
- Android save migration constraints and release gates are explicit.

**Automated tests**

- Source `npm test`, `npm run build`, story smoke, and one full story autopilot run.
- Markdown/path/link and git-diff validation for the planning package.

**Manual tests**

- Document review against `docs/STORY.md`, source code, and asset manifests.

**Dependencies:** none.

**Deliverables**

- Planning-only commit and exact SHA.
- Clean working tree on `codex/godot-port-architecture`.

---

## M1 — Godot foundation, content pipeline, and migration-risk spike

**Objective:** create a reproducible Godot project and prove the data/import/save risks before gameplay work expands.

**Source systems involved**

- `src/config.ts`, `src/core/rng.ts`, `src/core/display.ts`, `src/core/storage.ts`, `src/core/settings.ts`.
- `src/assets/manifest.ts`, `src/assets/animationTiming.ts`, `src/assets/environment.ts`, placeholder generators.
- `public/sprites/`, `public/environment-ink/`, recorded audio, title art, branding, font/license.
- `src/campaign/state.ts` and v1/v2 save fixtures.
- Android package/signing/version configuration and the installed old APK.

**Godot scenes/scripts/resources to create**

- `project.godot`, `export_presets.cfg`, `/godot/.gitignore`, project README.
- Compatibility renderer, 60 Hz physics, physics interpolation, VSync, a 60 FPS release cap, Android frame pacing enabled and Swappy `pipeline_forced_on` in project settings.
- Persistent `Main.tscn` shell and four empty-but-tested autoload contracts.
- `GameConfig`, `DeterministicRng`, `IsoGrid`, data Resource classes, save DTO/validators.
- Headless `tests/test_runner.gd` with assertion/report utilities.
- Node 24.15.0/Playwright 1.63.0 source-extraction tool (with `/godot/tools/.node-version`) plus Godot editor tools for hash verification, SpriteFrames, TileSet/atlas conversion, title-frame extraction, bitmap-font export, frozen fallback export, and PCM-WAV synth output.
- Imported font/theme seed and one playable-character profile for Zampanò.
- Legacy v1/v2 JSON fixtures and a throwaway Android migration-plugin spike isolated under `/godot/platform/android/`.

**Functional acceptance criteria**

- Project opens in 4.7.2 and imports from a clean cache.
- Headless launch exits normally without a display.
- Re-running asset tools is deterministic: no diff when inputs do not change.
- Required source hashes/dimensions are recorded; archive/ZIP/reference assets are excluded from export.
- Zampanò SpriteFrames expose every required action/direction and authored timing.
- The title output has 99 frames, exact delays, frame-0-derived shared crop/margin, alpha threshold 110, source resize path, canonical 125 px maximum width, atlas page dimensions ≤2048×2048 and <12 MB uncompressed frame memory.
- The generated bitmap font matches source glyph hashes/metrics, wrapping and IPA substitutions.
- Recorded files decode; the medieval loop and 14 synthesized cues are deterministic mono 22,050 Hz signed-16-bit PCM WAV with recorded recipe/sample/output hashes.
- Save validators accept valid v1/v2 fixtures, reject/repair malformed fields as specified, and preserve raw input.
- On a controlled same-package/same-signature old→new test lineage, the migration spike either reads the five legacy keys without mutating them or produces a documented, reproducible failure that triggers the staged-Capacitor decision gate. Missing access to the user's production signing identity is recorded as an external M9 blocker, not a blocker to M2.

**Automated tests**

- `ISO-001–003`, `RNG-001–003`, `AST-001–020`, `AUD-001–008`, `SAV-013–017` fixture-level tests.
- Asset scan verifies file count, dimensions, frame regions, nonblank frames, anchors, all eight directions, hashes, and no forbidden runtime asset paths.
- Import smoke from an empty `.godot` cache.
- JSON round trips and malformed/unknown-version cases.

**Manual gameplay/tests**

- Editor preview of every Zampanò animation/direction at nearest filtering.
- Listen to recorded and generated audio cues at safe volume; compare intent with source.
- Inspect title animation common crop, first/middle/last frames, smooth title-only scaling, alpha edges, timing and memory report.
- Install a controlled signed old APK, create representative saves, upgrade to the spike build without uninstalling, and collect logs/raw result. Repeat against the actual installed lineage/two WebView versions when owner signing evidence becomes available.

**Dependencies:** M0. A controlled signing lineage is sufficient for the M1 feasibility spike; the actual installed signing identity/device data remains mandatory for M9.

**Expected deliverables**

- Reproducible project scaffold and import pipeline.
- Machine-readable source asset manifest.
- Initial headless test runner and reports.
- Written migration-spike decision: native bridge viable, or staged export release required.
- No gameplay conversion beyond diagnostic previews.

---

## M2 — Early playable vertical slice: isometric walk, touch, and one ecological loop

**Objective:** prove the shared world and game feel early with a real playable slice using final-format data and assets.

**Source systems involved**

- `src/iso/`, `src/world/`, `src/entities/entity.ts`, `src/entities/zampano.ts`, `src/entities/prop.ts`.
- `src/core/input.ts`, `src/core/display.ts`, `src/systems/needs.ts`, basic pollution/pee rules.
- Current Green Zone map and Zampanò/environment assets.

**Godot scenes/scripts/resources to create**

- `PixelViewportController`, `IsoWorld` in `world_2d.tscn`, Ground/Pollution TileMapLayers.
- `WorldMapModel`, ASCII loader, tile/prop catalogs.
- `IsoDepthSorter`, `IsoRenderable`, `CameraRig`.
- `PlayableDog.tscn` and core state/animation controller.
- Solid/non-solid prop scenes; minimal Treat and Poop scenes.
- `InputService` implementation and native floating joystick/RUN/PEE controls.
- `VerticalSliceScene.tscn` using an actual contiguous portion of the current Green Zone, or the full map with systems intentionally limited.
- Minimal diagnostic HUD for hunger, energy, health, and state.

**Functional acceptance criteria**

- Keyboard and floating joystick move in exactly the screen direction pressed.
- RUN is explicit and drains energy; full joystick deflection does not run.
- Walk/run acceleration, terrain slowdowns, action locks, idle/sit/sniff/tired animation and facing match source values.
- Camera follows with lag/look-ahead/sway/clamp and no subpixel shimmer.
- Player collides/slides around representative walls, trees, poles, fountains, deep water and forest; bushes remain walkable.
- Depth order is stable and walking behind a tree uses the source first-order fade (rate constant 10/s) toward 0.42, then toward 1.0 when clear.
- Player collects a real treat, digestion can be forced to warning/poop, and PEE visibly cleans the affected cells.
- Same `IsoWorld` interface can be instantiated by a dummy story scene.
- Projected native collision meets the trajectory tolerance; otherwise the approved grid solver is selected and documented here, once.

**Automated tests**

- `VIEW-001–004`, `ISO-001–004`, `MOVE-001–005`, `COLL-001–006`, `DEPTH-001–004`, `CAM-001–004`, `MAP-001–007`, `DOG-001–008`.
- Golden movement traces at 8 directions, two analog magnitudes, walk/run, and three terrain types.
- Source-vs-Godot collision fixture comparison and map reachability.
- Integration test drives the slice through InputService injection.

**Manual gameplay/tests**

- Five-minute desktop controller/keyboard play.
- Five-minute touchscreen play on one portrait Android device or touch-enabled test surface: move, simultaneous RUN, PEE, pointer ownership, left/right edges.
- Inspect occlusion at every approach angle and camera bounds at map edges.
- Confirm crisp rendering at two window/device resolutions and one noninteger native aspect.

**Dependencies:** M1 asset/data foundation. Selecting and recording the native or compatibility collision solver is an M2 exit criterion, not a prerequisite.

**Expected deliverables**

- First playable Godot build/capture.
- Movement/collision parity report with chosen solver.
- Touch video/capture and performance baseline.

---

## M3 — Complete Green Zone 1.0 and core arcade flow

**Objective:** make the entire Green Zone level playable from briefing to result/game over with all ecological systems and threats.

**Source systems involved**

- `src/systems/needs.ts`, `src/systems/rules.ts`, `src/systems/scoring.ts`, `src/systems/lives.ts`, `src/systems/placement.ts`, `src/systems/threatLogic.ts`, `src/systems/threats.ts`.
- `src/entities/items.ts`, `src/entities/critters.ts`, Green Zone sections of `src/scenes/gameScene.ts` and `src/scenes/flow.ts`.
- `src/ui/hud.ts`, `src/ui/touchControls.ts`, `src/ui/attackBanner.ts`, relevant FX/audio events.
- `src/levels/level1.ts` and Green Zone environment assets.

**Godot scenes/scripts/resources to create**

- `GreenZoneScene.tscn`, `GreenZoneController`, pure systems/directors.
- Full Treat, Poop, Cat, Ball, Bagnaskiz and exit scenes.
- Full Green Zone HUD, radar, touch controls, warning/attack banners and popups.
- Briefing, pause, level-end, game-over and Supervillained overlays.
- Green Zone audio/FX bindings.
- Deterministic Green Zone automated driver.

**Functional acceptance criteria**

- Full 96×96 topology, props, canonical treat placement and three pollution waves match source data.
- Hunger, digestion, poop surfaces/spread, bladder/refill, pee expansion, marking-once, zone health, half-stars, end penalty, score, time, lives and run energy match source rules.
- Cats, coins, magnet balls/fetch, under-attack triggers/hysteresis, Bagnaskiz pollution/bump/bark/flee all work.
- Briefing → play → pause/resume/restart → level end/game over flows work.
- Level-end CONTINUE can call a stubbed campaign handoff without losing time/coins; actual persistence lands in M4.
- HUD/radar remain readable in safe area and both handed layouts.
- No obsolete `1:arcade` floor composition is applied.

**Automated tests**

- `GZ-001–045`, `UI-001–006`, `FLOW-001–005`, `AUTO-001`.
- Port every applicable source needs/rules/scoring/threat/balance invariant.
- Seeded full-level automation reaches exit, eats, poops, pees, handles attack, and produces deterministic summary.
- Scene restart clears transient state; pause freezes simulation.

**Manual gameplay/tests**

- Complete at least three runs: healthy/high-star, deliberately polluted, and game-over/starvation.
- Catch a cat using bark, escape/catch a ball, mark the same object twice, empty/refill bladder, trigger both health and scripted attacks.
- Portrait phone check with right- and left-hand controls; background/resume during warning, attack, and result screen.

**Dependencies:** M2.

**Expected deliverables**

- Playable Green Zone APK/desktop build.
- Deterministic run reports and result screenshots.
- Current balance table copied from source without retuning.

---

## M4 — Save system, title shell, settings, records, replay shell

**Objective:** replace localStorage with a robust native save and complete the non-story product shell.

**Source systems involved**

- `src/core/settings.ts`, `src/core/storage.ts`, `src/campaign/state.ts`, `src/campaign/summary.ts`.
- `src/scenes/flow.ts`, `src/scenes/overlays.ts`, `src/scenes/couchScene.ts`, `src/scenes/glossaryScene.ts`.
- Title art/animation, settings/control screens, Green Zone records and coin handoff.

**Godot scenes/scripts/resources to create**

- Production `SaveService` and `AppState`; format-3 DTOs, validators, atomic writer/recovery.
- Title, New Game confirmation, Couch, Options, Controls, Glossary, Goodbye/quit overlays.
- Record/campaign handoff from Green Zone plus passive preservation of the unused legacy standalone coin key.
- Replay selection shell and non-persistent session support.
- Legacy JSON import converter; native Android acquisition remains gated to M9 after the M1 spike.

**Functional acceptance criteria**

- Title flow and menu availability match source.
- Settings persist and immediately affect input/audio/text speed/lives.
- Independent best score/stars/time records persist.
- Legacy standalone coins remain separate, import-only preservation data; current gameplay never mutates them.
- Green Zone records save at completion, while campaign time/coins and 1.0 completion save only on result-screen CONTINUE; retry, quit and game over do not hand them off.
- Valid v1 saves migrate exactly, raw v1 is backed up, and the notice is shown once.
- Corrupt current save recovers from backup; an unknown future version is preserved and reported, not overwritten.
- Replays use a deep copy and never change persistent state.
- New Game over progress requires confirmation and creates the exact default campaign.

**Automated tests**

- `SAV-001–022`, fixture/converter and simulated-failure-UI portions of `MIG-006–010`, `UI-007–022`, `FLOW-006–012` shell tests. Actual WebView acquisition and missing-store proof remain M9 work.
- Crash-window tests at each atomic-write stage using injected file operations.
- Deep-copy/replay diff test.
- Deterministic Couch summary fixture.

**Manual gameplay/tests**

- Change every option, restart app, verify exact state.
- Generate three different Green Zone records and confirm independent best fields.
- Import valid, malformed, v1, v2, and unknown-version fixtures through debug UI/CLI.
- Force-close during save and verify recovery on next launch.
- Exercise Android Back through every title overlay when a development Android build is available.

**Dependencies:** M3 and M1 save schema/import fixtures.

**Expected deliverables**

- Native title/settings/save shell.
- Save format specification and fixture corpus.
- Recovery/import report; resolved standalone-coin policy recorded.

---

## M5 — Story engine and Level 1 reality (1.1–1.5)

**Objective:** prove the campaign framework, native story UI, replay semantics, actors, and reality-to-dream boundary on a complete chapter.

**Source systems involved**

- `src/campaign/types.ts`, `src/campaign/state.ts`, `src/campaign/summary.ts`, `src/campaign/chapters/ch1.ts`, chapter helpers.
- `src/story/step.ts`, `src/story/steps.ts`, `src/story/storyScene.ts`, `src/story/storyFlow.ts`, `src/story/walk.ts`, `src/story/ui.ts`, `src/story/screens.ts`, `src/story/carry.ts`, `src/story/names.ts`, dialogue gestures.
- Neighborhood map/theme and current Level 1 text/source metadata.

**Godot scenes/scripts/resources to create**

- `CampaignCatalog`, typed chapter/sublevel definitions and `CampaignState` integration.
- `StoryScene`, `StoryRunner`, `StoryContext`, core step classes.
- Dialogue box/typewriter, choice wheel, cards, story HUD/notices, story pause/menu/chapter list/book.
- Actor scene/behavior controller, carry presenter, marker/objective Areas.
- Chapter 1 script and maps; Professor aside and chapter-end Supervillained flow.
- Story smoke driver and input-level autopilot foundation.

**Functional acceptance criteria**

- 1.0 hands off to 1.1; 1.1–1.5 play in canonical order with exact reality/dream boundary.
- Dialogue, choices, costly/locked policy, effects, flags, scraps, remembered lines, carry, actor movement, gate puzzle and cards match source.
- Save occurs after effects/completion; restart does not double-fade/apply effects.
- Story pause/menu/book/text speed/skip/replay behavior matches source.
- Finished-scene replay changes no persisted byte.
- Names/period-word markup infrastructure works even though most period words arrive later.

**Automated tests**

- `CAMP-001–014`, `DLG-001–009`, `WALK-001–009`, `NPC-001–007`, `CONTENT-001–005` for Level 1.
- `STY-101–105` scripted smoke and real-input completion.
- Map marker validation and “missing marker fails” test.
- Restart/replay/persistence and sleep-boundary tests.

**Manual gameplay/tests**

- Play 1.0–1.5 without skips; take both 1.3 choices across runs.
- Solve and deliberately fail/push Jack's gate puzzle.
- Pause/restart/replay at every step family.
- Verify final 1.5 card is the sleep boundary and no armour appears in reality.

**Dependencies:** M4, M2 shared world.

**Expected deliverables**

- Complete Level 1 campaign flow.
- Reusable story engine/API documentation.
- Story smoke and input-autopilot reports for 1.1–1.5.

---

## M6 — Dream foundation and Levels 2–4

**Objective:** complete the reusable dream mechanics, first combat, stealth, Meraviglia, and early minigames across Levels 2–4.

**Source systems involved**

- `src/campaign/chapters/ch2.ts`–`ch4.ts`, story maps/themes, helpers.
- `src/story/combat.ts`, `src/systems/combat.ts`.
- Current Parade/Rowing portions of `src/story/minigames/rhythm.ts` and Boat portion of `src/story/minigames/action.ts`; exclude the unused `weeping()` factory.
- Sight/stealth/follow/lull/pickup/carry portions of `src/story/walk.ts`.
- Dream costumes, recorded Levels 2–4 music, medieval fallback behavior.

**Godot scenes/scripts/resources to create**

- Chapters 2–4 scripts/maps/resources.
- Dream costume mapping, armour appearance/arms capability split.
- `CombatRules`, `CombatController`, attack/hurt Areas and timing presentation.
- Sight cones/LOS/bush hiding, follow/lull helpers.
- Parade/rowing RhythmGame and Boat minigame scenes. Tug belongs to M7.
- Meraviglia opening/book population and early marvel/pickup visuals.

**Functional acceptance criteria**

- 2.1–4.3 complete with exact state effects, flags, sources, music, maps and failure/retry rules.
- Armour is visible from 2.1; sword/shield capability begins only at 2.3.
- Bark-only road fight, arms pickups, sword/shield/parry tutorial and non-lethal reset work.
- Venice stealth and current minigames are winnable through real inputs and test driver.
- Both chronicler debt counts remain intentionally distinct.
- Meraviglia opens at 3.1 and records exact marvels.

**Automated tests**

- `STY-201–203`, `STY-301–304`, `STY-401–403`.
- `COM-001–014`, `WALK-010–017`, `MINI-001–005`.
- Full scripted smoke 1.1–4.3 plus real-input autopilot from 2.1–4.3.
- Costume/capability and music-routing tests.

**Manual gameplay/tests**

- Complete all Levels 2–4 without skip.
- Lose the current rhythm games and verify their loss effects continue the story; separately restart their scenes from pause. Lose/retry fights and verify no deaths.
- Trigger stealth detection and recover; verify bush hiding.
- Inspect all eight directions for normal/armoured player and key actors.

**Dependencies:** M5 and M1 audio/animation pipeline.

**Expected deliverables**

- Complete Levels 2–4.
- First full dream combat and minigame set.
- Autopilot/playthrough report through 4.3.

---

## M7 — Levels 5–8, both endings, and complete campaign

**Objective:** port all remaining canonical content, advanced walks, companions, minigames, and both endings.

**Source systems involved**

- `src/campaign/chapters/ch5.ts`–`ch8.ts`, remaining maps/themes/helpers.
- Letter, Rumour, Ladders, Tug minigames.
- Zara/Constantinople fights, fire/checkpoints, scramble, bespoke 7.3/8.3 controllers.
- Ending, Professor aside, home-object, summary, and final flow.

**Godot scenes/scripts/resources to create**

- Chapters 5–8 scripts/maps/resources.
- Current 5.2 Ladders, 7.1/7.7 Tug, Letter, and Rumour minigame scenes; exclude the dormant hard-assault Ladders branch.
- Fire/checkpoint, scramble, Zara Grace-hit, 7.2 survival, 7.3 and 8.3 bespoke controllers.
- 7.8 ending decision, 7.9 common pile, 8.2 conditional telling/drawing, both ending cards/notes.
- Complete campaign smoke/autopilot policies for Knight/Witness and varied choices.

**Functional acceptance criteria**

- Every entry 5.1–8.4 completes with exact current content/state effects.
- Zara sword hits cost Grace; other fight outcomes remain non-lethal.
- Comradeship setup/readback, oath, declared/hidden lamp, empty pedestal, conditional home objects/drawing, and accessible final bowl all match source.
- 7.8 action produces THE KNIGHT; silence produces THE WITNESS (`alpha`).
- Both endings include exact Grace/Standing notes and reach 8.4.
- All 37 campaign entries are addressable, sequentially unlockable, replayable where allowed, and represented in Couch/story menus.

**Automated tests**

- `STY-501–505`, `STY-601–603`, `STY-701–707`, `STY-708A`, `STY-708B`, `STY-709`, `STY-801–804`.
- `WALK-018–021`, `MINI-006–012`, remaining `COM`/`NPC` cases, `END-001–004`.
- Complete scripted smoke with no page/resource/marker error.
- At least three full real-input autopilot policies: Knight/first, Witness/last, mixed/random lower skill.
- Campaign count/order/source metadata and every awarded marvel→home-object mapping.

**Manual gameplay/tests**

- One complete Knight campaign and one complete Witness campaign without debug skips.
- Exercise both 5.1, 5.3, 6.1, 6.3, 7.8 and 7.9 meaningful branches.
- Exercise every remaining fight/walk failure and scene-restart path; verify intended minigame losses continue and 5.2 ladder hits slide rather than return a lost result.
- Confirm nothing physical returns from dream; inspect 8.2 conditional objects/drawings and 8.3 companion/bowl behavior.

**Dependencies:** M6.

**Expected deliverables**

- Feature-complete campaign and both endings.
- Full smoke/autopilot reports and state diffs.
- Updated feature matrix covering all 37 entries.

---

## M8 — Visual, audio, UI, FX, and alternate-profile parity

**Objective:** replace diagnostic presentation with release-quality parity using only validated runtime assets.

**Source systems involved**

- `src/ui/`, `src/fx/`, full asset/environment manifests, title animation, recorded/generated audio.
- Current debug sprite viewer and `?as=` alternate player support.
- Reference captures in `docs/screens/` as human comparison targets.

**Godot scenes/scripts/resources to create or finish**

- Final Theme and all UI layouts/states.
- Title film/glitch/text/shine, story/transition glitches, Supervillained snap.
- Particles, popups, bark arcs, screen shake, terrain accents.
- Audio bus mixing, track position resume, gain trims, ducking, background handling.
- Sbrimbrulòn and Bagnaskiz playable profiles plus internal launch/debug selector.
- Sprite/environment/audio viewer and deterministic capture suite.

**Functional acceptance criteria**

- No runtime-generated placeholder or missing-key fallback remains.
- All required assets pass manifest validation and are referenced; forbidden archive/original/ZIP material is not exported.
- Every playable profile/costume/action/direction renders with correct anchor/timing.
- Title, HUD, story UI, book, Couch, menus and overlays are readable at minimum/target/maximum logical widths and safe-area extremes.
- Audio cues, music per chapter, resume positions, mute/volume/ducking and pause/background behavior match source intent.
- Alternate profiles can run relevant story/combat scenes through developer launch options; campaign text/state stays Zampanò's.

**Automated tests**

- `UI-001–030`, `AST-001–020`, `AUD-001–013`, `FX-001–012`, `ALT-001–003`.
- Deterministic capture suite at 192, 216, and 270 logical widths.
- Structural image checks plus reviewed side-by-side comparisons; no blind exact-pixel requirement across engines.
- Export-content audit for unexpected files and total footprint.

**Manual gameplay/tests**

- Review every generated capture against current source screenshots and live source behavior.
- Listen through every cue/track transition with mute/volume changes.
- Sprite viewer sweep of all directions/actions/profiles/cast.
- Full campaign spot-check on two aspect ratios and both handed layouts.

**Dependencies:** M3–M7 complete functionality, M1 production asset pipeline.

**Expected deliverables**

- Visual/audio release candidate on desktop.
- Approved capture/contact sheets and audio checklist.
- Clean export manifest with size breakdown.

---

## M9 — Native Android export, signed upgrade, migration, and on-device verification

**Objective:** prove the actual native deliverable, not merely desktop behavior or an unsigned debug export.

**Source systems involved**

- Current Capacitor package ID/version/signature behavior, Android portrait/fullscreen/back/keep-awake/quit/link behavior, legacy WebView saves.
- Entire Godot project and export configuration.

**Godot scenes/scripts/resources to create or finish**

- Android export preset(s), icons/splash/adaptive assets, version metadata.
- Custom Gradle/plugin integration only if required for save migration/platform behavior.
- Production legacy-import handshake, raw backup, migration-complete marker, user-visible failure/recovery copy.
- Device diagnostic screen/log export disabled from release UI but available in development builds.

**Functional acceptance criteria**

- Debug APK and release-signed APK/AAB export reproducibly.
- Application ID remains `com.zampano.supervillained`; min 24 and target/compile 36 are recorded; versionCode exceeds the actually installed artifact (repository baseline is 1).
- A signed old Capacitor APK updates in place to Godot without uninstall; signing certificate matches.
- The five legacy keys import exactly once, raw payload remains backed up, v1→v2→v3 conversion is correct, and repeated launch is idempotent.
- If automatic import is impossible, the previously approved staged-export path is executed; there is no silent save loss.
- Portrait, safe area, immersive bars, Back, quit, external link, keep-awake, background pause/audio, touch, offline cold start and asset decoding pass on device.
- Ten-minute worst-case Green Zone and representative story/minigame/combat sessions meet CPU/GPU work-time, presented-interval, missed-slot/jank and memory budgets without Swappy silently lowering the target or thermal-collapse caveats being hidden.

**Automated tests**

- `AND-001–013`, `MIG-001–010`, `LIFE-001–003`, `PERF-001–004` where automatable.
- `adb install -r` upgrade script verifies package/certificate/version and captures logcat.
- Airplane-mode cold-start automation and save checksum comparison.
- Android build-content scan confirms no secret/keystore and no forbidden asset.

**Manual gameplay/tests**

- Device matrix includes at least two Android/WebView/OS combinations for migration and one named mid-range performance device.
- Play Green Zone from title to 1.1; play representative touch-heavy scenes 2.3, 5.2, 7.2, 7.8, 8.1 and both endings where practical.
- Exercise multi-touch joystick+RUN/action, left-hand layout, system gesture edges, rotation attempt, app switch/lock/unlock, notification interruption, low-power mode, and external link return.
- Inspect migrated Couch, options, records, coins, book, completion, replay, and one-time notice.

**Dependencies:** M1 migration decision and signing identity, M8 desktop release candidate.

**Expected deliverables**

- Signed upgradeable APK, release AAB, checksums, export log.
- Device/migration/performance report with certificate fingerprints and versions (never private keys/passwords).
- User-facing migration limitation text if any.

---

## M10 — Final parity hardening and handoff

**Objective:** close every required matrix item, remove development-only leakage, and deliver an auditable release candidate.

**Source systems involved**

- Entire source baseline, all Godot systems/content, all planning acceptance criteria.

**Godot scenes/scripts/resources to finish**

- Only verified bug fixes, performance fixes, documentation, capture/test fixtures, and release metadata.
- No new feature work unless it closes an approved parity defect.

**Functional acceptance criteria**

- Every required feature-matrix box is checked with evidence.
- All 37 entries pass scripted smoke and real-input campaign automation; Green Zone 1.0 is played, not skipped.
- Knight and Witness manual campaigns complete from clean saves.
- Save corruption, replay isolation, legacy import, signed upgrade, offline mode, lifecycle and Android performance gates pass.
- No required asset is missing; no archive/source ZIP/unlicensed assumption is silently bundled.
- Root PixiJS `npm test` and `npm run build` still pass on the final branch.
- Known accepted deviations are enumerated and approved; there are no undocumented TODOs in shipped paths.

**Automated tests**

- Entire `TEST_PLAN.md` required suite.
- Clean-clone import/build/export rehearsal.
- Source-tree guard, export-content audit, secret scan, link/path validation, and save-fixture compatibility.

**Manual gameplay/tests**

- Full regression checklist on desktop and designated Android device.
- Side-by-side source/Godot review of title, Green Zone, every chapter's representative scene, menus, both endings and post-migration Couch.
- Release installation/upgrade rehearsal from distributed artifacts, not editor deploy.

**Dependencies:** M0–M9.

**Expected deliverables**

- Reviewed release-candidate commit and tag candidate.
- Signed artifacts/checksums outside git.
- Final parity, test, migration, performance, licensing and known-deviation reports.
- Claude Code handoff notes containing exact branch, commit, build commands and remaining owner-only release actions.

## Dependency summary

```text
M0 plan
 └─ M1 foundation + migration spike
     └─ M2 playable vertical slice
         └─ M3 full Green Zone
             └─ M4 save/title shell
                 └─ M5 story engine + Level 1
                     └─ M6 Levels 2–4
                         └─ M7 Levels 5–8/endings
                             └─ M8 presentation parity
                                 └─ M9 Android/upgrade/device
                                     └─ M10 final hardening
```

The sequence may not skip M1's migration/asset feasibility work, M2's collision decision, or M2's playable vertical slice. Content work can be internally batched after those gates, but review/merge remains sequential.
