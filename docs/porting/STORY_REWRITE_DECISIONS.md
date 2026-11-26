# SUPERVILLAINED VG1 — Story rewrite decisions and open questions

Every change the rewrite makes to the draft story (`docs/STORY.md`, `src/campaign/chapters/`), with
its old→new mapping and its consequence for existing saves (format 3, campaign v2), recorded before
it is implemented. Specification: [`STORY_REWRITE_SPEC.md`](STORY_REWRITE_SPEC.md); per-scene view:
[`STORY_CONTENT_MATRIX.md`](STORY_CONTENT_MATRIX.md).

Status of this log: decisions RD-01–RD-04 and RD-28–RD-31 are the **architect's** (the M5R and
correction-31 instructions; RD-28–RD-31 record how correction report 31 implements them). Every
other decision (RD-05–RD-27; RD-23–RD-27 were recorded while implementing M5R-B) is an
**implementer proposal for the Level 1 draft**, implemented as *draft implemented,
narrative review pending*; the owner may overturn any of them in review. Open questions (OQ-nn) wait
for the owner.

## Decisions

### Authority and engine

**RD-01 — The Godot Resources are the narrative authority (architect).** The PixiJS story and
`docs/STORY.md` are draft/reference material. The authority is the versioned story Resources under
`godot/data/story/` plus the three `STORY_*` documents. Old: verbatim parity with the PixiJS prose
(CONTENT-004 snapshots of "approved source exports"). New: parity with the specification's
invariants and these decisions. Saves: none.

**RD-02 — Data-driven typed steps (architect intent; implementer design).** ARCHITECTURE.md §4.7 and
§13 said step factories in GDScript hold the scripts. New: every scene is a `StorySceneData` Resource
whose ordered steps are typed `StoryStep` Resources (data); each step class holds only execution
logic, ticked by the `StoryRunner` at the fixed 60 Hz logic rate (`begin`, `tick`, `end`, mirroring
`src/story/step.ts`), deterministic under test ticks. Real-time scene behaviour that a generic step
cannot express (the bucket's visor, Jack's gate, the cut-off path) is a small rule class
parameterised by the step's Resource fields (its lines included). Not a free-form JSON DSL: every
step type and field is validated (spec §6). Saves: none.

**RD-03 — Content schema and layout (architect requirements).** Story Resources carry stable ID,
content version, title, level, map, music, cast, ordered steps, entry conditions, persistent
effects, completion boundary, historical/source tags and review status (spec §5). Saves: none.

**RD-04 — Two status axes (architect).** Technically complete ≠ narrative approved; only the owner
sets `narrative_approved` (spec §4). Saves: none.

**RD-05 — A scene is one save transaction.** Old (PixiJS): every effect saved at once
(`StoryScene.apply` → `saveCampaign`), the Commozione fade saved at a dream scene's start, play time
saved with each save; a restart after an effect, or a force-close mid-scene, could apply a meter
change twice (the restarted scene starts from a state that already holds it). New: effects, choices
and remembered lines apply to the scene's working copy at once (with their notices) and the campaign
is saved **once at the scene's completion**, with the completion and one savedAt, in a single
SaveService transaction. Restart and force-close discard the uncommitted working copy. Story play
time accumulates in the runner (kept across a restart in the same session; lost on force-close) and
is committed with the completion. Saves: no field or format change; SAV-009's "per-effect autosave
points" become per-scene autosave points (TEST_PLAN.md); FLOW-007/008 hold in a stricter form. The
Commozione fade of Levels 2–7 will apply to the working copy at scene start (once per committed
scene).

### Level 1 content (implementer proposals, review pending)

**RD-06 — One remembered line per scene, in the dream's grammar.** Old: 1.2 had two remembered lines
("AND A DOG DREAMS LECTURES." and "THERE WAS A GATE, AND IT WAS A CHIHUAHUA."); 1.4's "THERE WAS A
GATE, AND I WAS MAGNIFICENT AT IT." breaks the "THERE WAS A …, AND IT WAS …" grammar. New: 1.2 keeps
only the gate line ("AND A DOG DREAMS LECTURES." stays as a spoken line); 1.4's becomes "THERE WAS A
GATE, AND IT WAS A STAGE." Saves: `book.remembered` is a list of strings; strings written by older
versions stay valid and are shown as they are; no migration.

**RD-07 — The 1.3 choice records both answers.** Old: offering the paw set `pawOffered: true`
(Supervillain −3); looking past him set nothing. New: the water sets `pawOffered: false`, so both
answers persist and are distinguishable from "not played". Saves: `pawOffered` is already a known
boolean (CampaignFlagSchema); a v2 save that completed 1.3 without the paw has no flag and keeps
meaning "no paw"; the v1 migration is unchanged.

**RD-08 — `longWay` is 1.3's completion marker.** Old: `docs/STORY.md` lists `pawOffered, longWay` as
if both were choices, but the draft always sets `longWay` after the walk (Jack always cuts off the
direct path). New: documented as the marker that he went home by the hedge, set at completion on
every branch; the direct path is denied in reality until 8.3. Saves: unchanged.

**RD-09 — 1.4 leaves the ball on his side, explicitly.** Old: the draft shows the ball settling "ON
HIS SIDE" but nothing says it stays. New: a narration line ("THE BALL STAYS WHERE IT IS.") makes the
8.4 setup explicit; `santinaBall: "performed"` is unchanged. Saves: unchanged.

**RD-10 — Lecture lines tightened to the cited sources.** Old 1.2 lines: "CLARI WAS OUTSIDE THE ROOM.
HE SAW EVERYTHING AND WAS TOLD NOTHING." and "NOBODY SAILS IN WINTER." New: "CLARI WAS OUTSIDE THE
ROOM. HE SAW A GREAT DEAL AND WAS TOLD VERY LITTLE." (framing of Clari XIII's "No one in the army
knew this plan, except the leaders", attested) and "THE FLEET WAS READY FIRST. THE ARMY THAT CAME TO
VENICE WAS SMALLER THAN THE FLEET." (Clari XI's claim that far fewer came; `REVIEW REQUIRED` as a
lecture paraphrase). The winter line is dropped from Level 1 (no cited basis in `STORY-SOURCES.md` for
this scene). Saves: none.

**RD-11 — Stage directions become narration.** Old: lines such as Bagnaskiz's "(HE PUTS HIS PAW OVER
THE BOWL.) SIGNOR VILLANO…" spoke the stage direction in the character's box. New: a `NarrationStep`
for the direction, then the character's line. Saves: none.

**RD-12 — No armour or dream capability in reality.** Level 1 stages always use Zampanò's plain
skin, whatever abilities the campaign holds (the source's `dreamSkin` returns the armour once `cross`
is unlocked; Level 1 forces `plain`, and so does a replay of Level 1 after 2.3). The rag cross is a
carried rag. Saves: none.

**RD-13 — The Professor is drawn as his legs.** As in the draft (the `legs` story sprite at the dog's
eye level), not the full `professor` cast sheet; his portrait in the dialogue box is the `professor`
sheet. Saves: none.

**RD-14 — Level 1 maps are kept verbatim; the study uses the Green Zone art bank.** The `neighborhood`
and `study` ASCII maps are ported unchanged from `src/story/maps.ts` (markers are script anchors).
The `study` theme's own art bank (`ch01_study`) is M8 presentation work; until then the study is
drawn with the `ch01_greenzone` bank (which holds floor, carpet, wall, desk and shelf frames). Saves:
none.

**RD-15 — Scene cards.** Each story scene 1.1–1.5 opens with its scene card (LEVEL 1, the ID and
title, the summary; "REPLAY: THE CAMPAIGN WILL NOT CHANGE" in a replay), as the draft does. The level
card before 1.0 stays skipped (M4 deviation D-22, narrowed to 1.0) until OQ-02 is answered. Saves:
none.

**RD-16 — The end of Level 1.** After 1.5's completion: the Supervillained snap, the Professor's
Level 1 aside, then the explicit "next chapter not in this build" card for 2.1 over the title.
Level 2 is not implemented. Saves: none (1.5 is complete; CONTINUE shows the 2.1 boundary).

**RD-17 — Text speed.** The OPTIONS text speed (slow/normal/fast/instant) drives the typewriter at
the draft's characters-per-second values. Saves: none.

**RD-18 — The mosque contradiction is recorded, not resolved.** `docs/STORY.md` says the mosque is
omitted (7.4) while 7.5 and `docs/STORY-SOURCES.md` keep it as the start of the fire. Resolution is
deferred to the Level 7 rewrite (OQ-07). Saves: none.

**RD-19 — Jack's gate: success and failure/recovery.** Kept from the draft: three barks (Jack echoes
each; after the second, heads pop up along the fences; after the third the Professor's window creaks
and Jack steps aside); pushing into Jack gets "NOPE!", a hint after 3 and 8 pushes, and after 14 the
window creaks anyway (nobody stays stuck). The creak is narrated as the Professor's window. Saves:
none.

**RD-20 — 1.1 opens from the walk.** 1.0's CONTINUE (the M4 handoff, saved) launches 1.1, whose first
card says he dozes after the walk. Saves: none (the handoff is M4's).

**RD-21 — 1.2 keeps its catalog title.** The draft title "Under the Professor's desk" fits the study
but not the gate; it is kept for the catalog (titles appear in COUCH and the level list) pending
OQ-03. Saves: none (titles are not save data).

**RD-22 — The Professor sends him out (1.2).** New line: the Professor sends him out to drink ("GO AND
DRINK SOMETHING. YOU ARE PANTING ON MY NOTES."), so the move from the study to the gates is
motivated. Saves: none.

### Recorded while implementing M5R-B (implementer proposals, review pending)

**RD-23 — No SKIP SCENE in the story pause (M5R).** Old (PixiJS): the story pause offered RESUME,
RESTART SCENE and SKIP SCENE; a skip marked the scene complete (`finishSub`) with whatever effects the
attempt had already saved, and none of the effects it had not reached. Under RD-05 a skip would commit
a completion without the scene's required outcome (1.3 without `pawOffered`/`longWay`, 1.5 without
the `cross` unlock), contradicting the invariants. New: the story pause offers RESUME, RESTART SCENE
and QUIT TO TITLE; quitting discards the attempt like a force-close. FLOW-012 is **partial** (the skip
is not offered, so "unavailable where inappropriate" holds everywhere; "completes/saves as the source"
is not claimed). What a skip should commit is OQ-11. Saves: none (a skip never wrote anything the
campaign could not otherwise hold).

**RD-24 — 1.3's jokes are true on both branches.** Old: while he takes the hedge, the dogs across the
lane laugh "AND THEN HE OFFERED THE OTHER PAW!" / "THE OTHER PAW!", which is false when he looked past
Bagnaskiz instead. New: "AND THEN HE WANTED A DRINK!", "HA HA HA!", "A DRINK! FROM OUR BOWL!", "HA HA!"
— the same rhythm, true whichever answer he gave. Saves: none.

**RD-25 — The cloth cross is sewn "on their clothes".** Old 1.5 line: "...AND ONE BY ONE THEY TOOK THE
CROSS. A PIECE OF CLOTH, SEWN ON THE SHOULDER. THAT WAS ENOUGH TO BELONG." The shoulder is not itemised
in `docs/STORY-SOURCES.md` (a `REVIEW REQUIRED` item in M5R-A). New: "...A CROSS OF CLOTH, SEWN ON
THEIR CLOTHES. THAT WAS ENOUGH TO BELONG." — only what Villehardouin pp. 1–4 is cited for (the cloth
cross as the sign of those who took the cross); the 1.5 summary says the same. Resolves that `REVIEW
REQUIRED` item; the spring date stays one (OQ-10). Saves: none.

**RD-26 — Every scene opens with a StageStep.** The engine builds no stage of its own: the scene's
first step builds the map, places Zampanò and the cast, and snaps the camera, so a scene's opening is
data like the rest (it also removed a double stage build found by DOG-008b). The validator refuses a
scene whose first step is not a `StageStep` (spec §6). Saves: none.

**RD-27 — The story maps' prop tiles join the Green Zone sprite catalogue.** The story maps draw
props from the shared legend (`TileCatalog.PROP_SPRITE`: column, desk, shelf, house, tent, galley,
rock, statue, crate, palm, altar, stall, throne, vine, gate, bones, table, wicket). Their frames are
in the existing `ch01_greenzone` bank; they are now named in the generated sprite catalogue
(`data/environment/green_zone_sprites.tres`, regenerated by `tools/build_resources.gd`), so the
stages can draw them and the validator can check every sprite key. The props a scene places by
step (bowl, ball, rag) were already in it. No new art. Saves: none.

### Recorded in correction report 31

**RD-28 — A bark is a bark (architect, correction 31: the input contract).** Old (PixiJS): in a walk
J/X performed the action button's mode, Space the walk's own action and B a plain bark (the source's
`combat.bark`), which the 1.1 bucket and Jack's echo did not hear — only the walk's own action set
the bucket's "bow" and counted for Jack. New: the same routing (StoryActionRouter), and a plain bark
— B, a double tap bound to BARK, the action button in BARK mode — is heard by the scene rules that
react to barking: the bucket slides down (1.1) and Jack echoes it (1.2). Every walk shows the action
button (BARK when it has no action of its own, as the source). Saves: none.

**RD-29 — The Godot Resources are the display authority for titles (architect, correction 31).** Old (M5R-B): the catalog's
titles came from the PixiJS CHAPTERS and the validator required the rewritten Resources to equal
them, so a rewritten title could not be shown. New: the extracted catalog
(`data/campaign/story_catalog.json`) is kept frozen as the compatibility source of the stable IDs,
the eight chapters, the 37-entry order, the Green Zone dispatch and the draft fallback titles;
`tools/build_resources.gd` generates the runtime catalog by laying every rewritten chapter's title
and menu title and every rewritten scene's title over it (`StoryCatalog.overlay`). The validator
checks IDs and order against the compatibility catalog and the displayed titles against the
Resources. Level 1's titles are unchanged (RD-21), so nothing visible changes yet. Saves: none (IDs
and save compatibility unchanged).

**RD-30 — `reality` owns the plain appearance; entry conditions are enforced at run time (architect, correction 31).** Old: the
specification listed an entry condition `forbids_abilities_visible` that the validator rejected, and
entry conditions were checked only by the validator. New: `StorySceneData.reality` alone keeps a
reality scene plain (no armour, no dream capability, whatever abilities the campaign holds; RD-12);
the redundant key is removed from the specification. `requires_completed` and
`requires_abilities` are checked before a scene starts: Main shows the story error card and never
starts the scene, and a StoryScene entered with a failing state stops with the explicit error.
Saves: none.

**RD-31 — Arrival is distance only; every wait has a timeout (architect, correction 31).** Old: an actor blocked by a wall
counted as arrived, so `ActorStep(wait_arrival)` could silently continue with the actor far from its
target, and a follow objective's leader could walk into a wall forever. New: an actor has arrived
only within 0.05 tiles of its target; `ActorStep.arrival_timeout` (validated positive with
`wait_arrival`) and `ObjectiveStep.leader_leg_timeout` (validated positive for follow) stop the scene
with an explicit story error when exceeded. Level 1's clear paths are unchanged (4 s for Jack in 1.2,
12 s per leg of the Professor's walk). Saves: none.

### Recorded in M6 (implementer decisions, review pending)

**RD-32 — The costume follows `reality`; the arms are a separate capability.** `StorySceneData.costume()`
is "normal" in a reality scene and "armoured" in a dream scene, decided by `reality` alone; the stage
applies the profile's own mapping (Sbrimbrulòn and Bagnaskiz included). The sword and the shield are
`StoryContext.armed()`: a dream scene with `knight` held in the working copy (2.3 unlocks it after the
third pickup, mid-scene). Saves: none.

**RD-33 — Combat is the source's, non-lethal.** `CombatRules` ports `systems/combat.ts` exactly
(numbers in `GameConfig.Combat`); `CombatController` ports `story/combat.ts` into the story context.
A knockdown shows its card and resets the fight (positions, hearts, HP) with nothing persistent
touched; routed foes flee. Fights exist only where the reference has them (2.3's two in this batch).
The bark is an area (no cone), as in the source. Saves: none.

**RD-34 — Levels 2–4 are drawn with the Green Zone art bank (prototype).** Their maps are copied
verbatim from the executed-source fixture; the chapters' own banks (`ch02_*`, `ch03_venice`,
`ch04_sea`) need TileSets and sprite catalogues that are M8 work, like RD-14. Topology, markers and
collisions are unchanged. Saves: none.

**RD-35 — Three minigames, no framework, no retry.** `MiniGameStep` runs the parade (4.1), the rowing
(4.3) and the skiff (4.2) only; a result applies its exact effects once and the scene goes on;
restarting the scene is the retry path; the skiff cannot be lost (the source has no lost result).
Tug, ladders, letter, rumour ordering and the unused `weeping()` are not implemented. Saves: none.

**RD-36 — Story hiding spots.** The maps are verbatim (the Lido has no bush), so 3.4 places two bush
props marked as hiding spots (`PropStep.hides`); `StorySight` treats them like a map bush. Saves: none.

**RD-37 — A scene's randomness is seeded.** The lull's talk and quiet lengths come from a generator
seeded by the scene ID (a run and its restart draw the same); wandering and cornered fleeing actors
use one seeded by their handle; the rhythm games are deterministic. Saves: none.

**RD-38 — The Meraviglia book viewer.** The level list's and OPTIONS's MERAVIGLIA BOOK opens a paged
viewer of the committed campaign (meters, things, marvels, values, scraps, remembered lines), as the
source's BookScene; replays never add to it. Saves: none.

### Recorded in M7 (implementer decisions, review pending)

**RD-39 — Levels 5–8 use the Green Zone art bank (prototype).** As RD-34: the maps are copied from
the executed-source fixture; their own banks are M8. Saves: none.

**RD-40 — Branches read the campaign when reached.** `BranchStep` (`cases` with a `when` condition,
`otherwise`) decides from the working copy at the moment it runs; `StoryConditions` holds flag,
meter (`gte`/`lt`), ability, book (`has`/`gte`), `all` and `any`. Every readback of Levels 5–8 is a
case (the cloth at 7.7 and 7.9, comradeship at 7.7, the oath, the lamp and the letter at 8.2,
`vanguard` at 8.4, the telling tier). Saves: none.

**RD-41 — Four more minigames, still no framework and no retry.** Ladders (5.2: 16 rungs, the input
cap, a stone's warning, hit and slide, never a lost result), the letter (5.4: the two accounts kept
apart), the rumour (6.2: the pieces in order, only twelve swear) and the tug (7.1, 7.7). The tug has
no won result (`NEVER_WON`): its lost effect is its only result, applied once, and the scene goes on.
Saves: none.

**RD-42 — The sword's cost at Zara (5.3).** Each landed sword blow costs Grace once per swing with its
line; misses, barks, blocks and parries are free; a restart, a replay or a knockdown never charges
twice or refunds. Saves: none.

**RD-43 — A hold is a timed survive (7.2).** `objective_kind = survive` with `survive` seconds; the
fight needs no rout (`rout` 0); a knockdown shows its card and starts the clock again with nothing
applied. Saves: none.

**RD-44 — Companions are real followers.** 7.3 (`ShoulderRule`): nerve while level with Pierre,
ahead/behind/aside notices, OUT OF STEP sends both back to the start; Saint-Pol follows Pierre
(`ActorStep.target_actor`), Flanders falls in beside him at 45 %. 8.3 (`CompanionsRule`): his friends
follow at his sides, wait (turned to him) when he flinches for 0.6 s, and fall in again. Saves: none.

**RD-45 — 7.5's fire is seeded and has a failure path.** The draft's fire spreads with
`Math.random` and only pushes back. The port draws from the scene's seeded generator, never burns
the goal, the start or a checkpoint, and adds THE SMOKE: three burns send him back to the last
checkpoint with the woman beside him and the fire out (WALK-021). Nothing persists before the scene
completes. Saves: none.

**RD-46 — 7.6: running restarts the walk at its own start.** The draft puts him back on marker S,
which is the goal of the walk out (a draft defect not ported). Running stays possible (the walk does
not take it away) and stops the walk with YOU RAN. Saves: none.

**RD-47 — 7.7: the oath is said, not chosen.** The draft's one-answer ask becomes Zampanò's line
"SO HELP ME GOD." with Grace +5 and `sworn` (a one-option choice fails validation). Saves: none.

**RD-48 — 7.8's call costs Commozione 5, or all he has left.** The draft spends nothing when he has
less than 5 and says "IT TAKES ALL HE HAS LEFT"; the port takes what is left (the line's meaning).
Sixteen seconds of silence from the walk's start: Niketas calls the oath (`oath` silent, THE
WITNESS). Saves: none.

**RD-49 — 8.1's scrambled legs.** Every 2.6 s the joystick turns by 90, 180, −90 or 135 degrees
(drawn from the scene's seeded generator; the draft uses `Math.random`) until he is within 30 % of
the way; then the controls settle. The test driver is not given the angle: it learns the turn from
where his legs take him. The draft's goal is the map's exit tile (not a marker): the Resource names
its point. Saves: none.

**RD-50 — 8.2's study, drawings and readbacks.** The four study objects are what the dream made of
them only for the marvels he saw (the draft's home mapping, written into the Resource); the
drawings are locked by a condition (`StoryChoiceOption.requires`), the bowl always open; the oath,
the lamp and (new, REVIEW REQUIRED) 5.4's letter are read back; Grace 70/40 sets `tellingTier`.
Saves: none.

**RD-51 — The Commozione fade (RD-05's plan) is implemented.** Every dream scene of Levels 2–7
starts with 2 less Commozione (never below 0) on the working copy, with its notice; a restart starts
again from the entry state, so it fades once per committed scene; a replay fades only its copy.
M6 and M7 snapshots compare against the faded entry. Saves: the committed Commozione of every dream
scene is 2 lower than before M7 (no field or format change).

**RD-52 — The ending.** After Level 8's aside: the ending card (THE KNIGHT or THE WITNESS by 7.8
alone, its account, the Grace and Standing lines, the book's counts, Supervillain and Grace, THE
END), then the title with the level list. The texts are in `data/shell/shell_text.tres`. A replay
never reaches the level end or the ending. Saves: none.

**RD-53 — Full Supervillain is shown, not played.** The draft's `unshakeable` (Supervillain at
100) softens only the generic pace walk, which no current scene uses (FEATURE_MATRIX: excluded unless
reused); 7.3's and 8.3's walks are their own rules, as in the draft. The port has
`CampaignRules.unshakeable` and the book's "SUPERVILLAIN 100 (FULL)" (correction report 34).
Saves: none.

**RD-54 — 8.3 follows the source: Bagnaskiz steps aside.** The M7 instruction lists Bagnaskiz
among those who fall in on the lawn; the draft and `docs/STORY.md` have Sbrimbrulòn and Confusione
fall in while Bagnaskiz steps aside. The Resource keeps the source; the owner may decide otherwise.
Saves: none.

## Owner decisions

- **OD-01 (2026-11-25) — Level 1 draft: DEFER NARRATIVE APPROVAL FOR PROTOTYPE DEVELOPMENT.** The
  owner chose the third outcome of the Level 1 review package
  (`docs/porting/manual_evidence/m5r_level1_narrative_review/README.md`). This is **not** narrative
  approval: Level 1 and every later scene's prose stay `draft_implemented_review_pending` and are
  release-blocking until reviewed; the open questions below stay open. Narrative review no longer
  blocks prototype implementation: M6 (Levels 2–4) proceeds on this decision. The Godot story
  Resources remain the narrative authority; the PixiJS source is reference material for mechanics,
  state consequences and historical sources, not wording to copy.

## Open questions for the owner

| ID | Question | Where |
|---|---|---|
| OQ-01 | Should 1.3's paw (or its refusal) pay off later, for example in 8.3? Today it only costs Supervillain 3. | 1.3, 8.3 |
| OQ-02 | Show the Level 1 card (the chapter intro) before 1.0, as the draft does? M4 skips it (D-22). | 1.0 |
| OQ-03 | Every lecture fragment of 1.2 and 1.5 (historical accuracy, tone); is "Under the Professor's desk" still the right title for 1.2? | 1.2, 1.5 |
| OQ-04 | "THERE WAS A GATE, AND IT WAS A CHIHUAHUA." — is Jack a chihuahua in the cast? | 1.2 |
| OQ-05 | Santina's friend ("A LADY" in the draft): keep, name, or remove? | 1.4 |
| OQ-06 | 1.5's two answers both unlock the cross; keep Supervillain +3 vs Commozione +3? | 1.5 |
| OQ-07 | The mosque: omitted (STORY.md 7.4) or the fire's start (7.5, STORY-SOURCES)? | 7.4, 7.5 |
| OQ-08 | Should the story show the walk's coins and time when 1.1 starts? (Today the result card shows them.) | 1.0 → 1.1 |
| OQ-09 | The Professor's Level 1 aside says Clari was "from Picardy": confirm or reword (`REVIEW REQUIRED`). | Level 1 aside |
| OQ-10 | "IN THE SPRING THEY SET OFF FOR VENICE": confirm or reword (`REVIEW REQUIRED`). The cloth cross "on the shoulder" was reworded by RD-25; confirm the new line. | 1.5 |
| OQ-11 | Should the story pause offer SKIP SCENE again (RD-23), and if so what does a skipped scene commit: nothing but its completion, or one branch's effects (which branch)? | all story scenes |

## REVIEW REQUIRED items (Level 1)

| Item | Scene | Basis in the repository |
|---|---|---|
| "NIKETAS WAS INSIDE THE WALLS, WATCHING THEM COME." | 1.2 | lecture framing; no scene-level citation in `STORY-SOURCES.md` |
| "THE FLEET WAS READY FIRST. THE ARMY THAT CAME TO VENICE WAS SMALLER THAN THE FLEET." | 1.2 | Clari XI's claim (attested as a claim) — paraphrase to review |
| ~~"A PIECE OF CLOTH, SEWN ON THE SHOULDER."~~ — resolved by RD-25 ("A CROSS OF CLOTH, SEWN ON THEIR CLOTHES.") | 1.5 | Villehardouin pp. 1–4 for the cloth cross |
| "IN THE SPRING THEY SET OFF FOR VENICE." | 1.5 | not itemised |
| "CLARI … A SMALL KNIGHT FROM PICARDY" (Level 1 aside) | Level 1 | Clari 120 ("Robert of Clari, knight"); Picardy not itemised |

### REVIEW REQUIRED items (Levels 2–4, M6)

| Item | Scene | Basis in the repository |
|---|---|---|
| "(BEHIND A DOOR) ...BABYLON FIRST. EGYPT. KEEP IT FROM THE MEN..." | 2.1 | Villehardouin p. 8 (the council's objective); compressed |
| Fulk preaching on the tournament field | 2.2 | Villehardouin pp. 1–4 has the preaching and the tourney separately |
| "A KNIGHT OF PICARDY" | 2.2 | as OQ-09 |
| Level 2 aside: "ONE OF THE SIX MEN WHO SIGNED FOR THE SHIPS" | Level 2 | Villehardouin pp. 4–7 |
| "WINTER IS COMING. TAKE BACK ZARA FOR VENICE, AND THE DEBT CAN WAIT." (card) | 3.4 | Clari XIII; Villehardouin p. 16 (paraphrase, not a quotation) |
| "THE TRUMPETS ANSWER FROM SHIP TO SHIP" | 4.1 | Clari 13 (trumpets) |
| "KEEP THE HOST TOGETHER. THAT IS THE WHOLE ART." | 4.3 | the marshal's view, not a quotation |

Attested (as listed in `docs/STORY-SOURCES.md`, not re-verified in M5R): the fleet contract of
85,000 marks (Villehardouin pp. 6–7); Villehardouin among the six envoys (pp. 1–4); "No one in the
army knew this plan, except the leaders" (Clari XIII).

### REVIEW REQUIRED items (Levels 5–8, M7)

| Item | Scene | Basis in the repository |
|---|---|---|
| The mosque and the fire (OQ-07): 7.5 follows Barbero's lecture; `docs/STORY.md` 7.4 omits it | 7.4, 7.5 | Barbero's lecture on the Fourth Crusade |
| Boniface's framing (the cook's line, the tents) is the camp's talk | 6.2 | Clari XVII |
| The deaths of Alexios IV and Isaac II, kept as two accounts; page references and the dating (the draft says January 1204; Mourtzouphlos was crowned in early February) | 7.6 | Villehardouin pp. 53–56; Clari 61–62 |
| LI RIKE HOMME / LI POVRE CHEVALIER (Clari's Old French terms as the draft gives them): spelling | 7.9 | Clari 81, 105 |
| The Professor's "HOME TO PICARDY" | 8.2 | as OQ-09 |
| The letter readback (5.4's `letter`), new to the rewrite | 8.2 | none in the draft |

The attested quotations used in Levels 5–8 are those `docs/STORY-SOURCES.md` lists ("more than
forty people told him", "copper pots and with pestles", "turn back one step", "it seemed as if our
warriors were angels", "portrayed and written", "Thus was there division between the Greeks and the
Franks", "no mischief was done to poor or to rich", "No one was without a share in the grief", "the
strict truth"); no quotation or citation was invented.
