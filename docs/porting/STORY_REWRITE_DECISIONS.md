# SUPERVILLAINED VG1 — Story rewrite decisions and open questions

Every change the rewrite makes to the draft story (`docs/STORY.md`, `src/campaign/chapters/`), with
its old→new mapping and its consequence for existing saves (format 3, campaign v2), recorded before
it is implemented. Specification: [`STORY_REWRITE_SPEC.md`](STORY_REWRITE_SPEC.md); per-scene view:
[`STORY_CONTENT_MATRIX.md`](STORY_CONTENT_MATRIX.md).

Status of this log: decisions RD-01–RD-04 are the **architect's** (M5R instruction). Every other
decision is an **implementer proposal for the Level 1 draft**, implemented as *draft implemented,
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
| OQ-10 | "IN THE SPRING THEY SET OFF FOR VENICE" and the cloth cross "on the shoulder": confirm or reword (`REVIEW REQUIRED`). | 1.5 |

## REVIEW REQUIRED items (Level 1)

| Item | Scene | Basis in the repository |
|---|---|---|
| "NIKETAS WAS INSIDE THE WALLS, WATCHING THEM COME." | 1.2 | lecture framing; no scene-level citation in `STORY-SOURCES.md` |
| "THE FLEET WAS READY FIRST. THE ARMY THAT CAME TO VENICE WAS SMALLER THAN THE FLEET." | 1.2 | Clari XI's claim (attested as a claim) — paraphrase to review |
| "A PIECE OF CLOTH, SEWN ON THE SHOULDER." | 1.5 | Villehardouin pp. 1–4 for the cloth cross; "shoulder" not itemised |
| "IN THE SPRING THEY SET OFF FOR VENICE." | 1.5 | not itemised |
| "CLARI … A SMALL KNIGHT FROM PICARDY" (Level 1 aside) | Level 1 | Clari 120 ("Robert of Clari, knight"); Picardy not itemised |

Attested (as listed in `docs/STORY-SOURCES.md`, not re-verified in M5R): the fleet contract of
85,000 marks (Villehardouin pp. 6–7); Villehardouin among the six envoys (pp. 1–4); "No one in the
army knew this plan, except the leaders" (Clari XIII).
