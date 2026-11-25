# SUPERVILLAINED VG1 — Story rewrite specification (Godot-native campaign)

- Status: **authority for the campaign's narrative content from M5R on** (architect decision recorded
  with M5R). Companion documents: [`STORY_CONTENT_MATRIX.md`](STORY_CONTENT_MATRIX.md) (one row per
  scene 1.1–8.4) and [`STORY_REWRITE_DECISIONS.md`](STORY_REWRITE_DECISIONS.md) (every change,
  its old→new mapping, its save consequences, and the open questions for the owner).
- Narrative status: every rewritten line is **draft implemented, narrative review pending** until the
  owner reviews it (§8). Nothing in this document claims owner approval of prose, tone or history.

## 1. Authority

The campaign is rewritten and implemented as native Godot content. The PixiJS story
(`src/campaign/chapters/ch1.ts`–`ch8.ts`), `docs/STORY.md` and `docs/STORY-SOURCES.md` are **draft
and reference material**: they describe the structure, the mechanics and the sources the rewrite
starts from, but their prose is not immutable and is not copied verbatim where it is incomplete,
contradictory or historically doubtful.

Order of authority for narrative content, highest first:

1. The **versioned Godot story Resources** under `godot/data/story/` (chapter, scene, cast and map
   Resources; §5). They hold every line of dialogue and narration the game shows.
2. This specification, the content matrix and the decision log (`docs/porting/STORY_*`).
3. `docs/STORY.md` and `docs/STORY-SOURCES.md` (draft/reference: structure, sources, what is attested).
4. The PixiJS chapter scripts (draft/reference: the established mechanics and current behaviour).

Reviews no longer require verbatim parity with the PixiJS prose. They require (a) the invariants of
§2, (b) the recorded decisions for every change, (c) the content schema and validation of §5–§6,
and (d) the gameplay, save and replay behaviour of §7.

Godot story data contains the final dialogue and narration; GDScript contains execution logic only.
No line the player reads in a story scene is written in a runner, step, controller or scene script.

## 2. Narrative invariants

These hold for every chapter unless a decision in `STORY_REWRITE_DECISIONS.md` explicitly records a
replacement, with its old→new mapping and migration consequences, before it is implemented.

### 2.1 Structure and identifiers

- **Eight levels**, the Fourth Crusade arc: 1 The Greenzone (reality), 2 On the edge of dreams,
  3 Venice, 4 The sea, 5 Zara, 6 The long winter, 7 Constantinople, 8 Back to the Greenzone.
- **Stable campaign IDs 1.0–8.4 and the 37-entry catalog** (1.0 plus 36 scripted scenes, the counts
  of `docs/porting/ARCHITECTURE.md` §1). IDs are save data (`campaign.completed`); they are never
  renamed, renumbered, merged or removed without a recorded migration.
- **Green Zone 1.0** stays the arcade walk ported in M3 and its CONTINUE handoff from M4.
- **Both endings**: THE KNIGHT (`oath: enforced`) and THE WITNESS (`oath: silent`, internal ending
  key `alpha` kept for save compatibility), decided only in 7.8.

### 2.2 History and setting

- The dream is **one** historical story: the Fourth Crusade, 1199/1202–1204, from the preaching in
  Champagne to the sack of Constantinople. No other crusade or dream cuts in. 1203 and 1204 are kept
  apart, and the three emperors called Alexios are kept apart (Alexios III, Alexios IV, Alexios V
  Mourtzouphlos).
- Three witnesses are kept distinct and may disagree: **Robert de Clari** (the small knight's view),
  **Geoffroi de Villehardouin** (the marshal, the leaders' room), **Niketas Choniates** (the city's
  side). Kept disagreements stay kept (`docs/STORY-SOURCES.md`, "Kept disagreements").
- Historical claims follow the repository's cited editions only (`docs/STORY-SOURCES.md`, "Editions
  consulted"). No quotation, citation or verification is invented. A fact the cited materials do not
  support is marked **`REVIEW REQUIRED`** in the content matrix and the story Resource's
  `review_notes`, and is either reworded as the Professor's framing or removed before approval.

### 2.3 Zampanò's role and point of view

- Zampanò is a small Maltese dog. In reality he is the dog who cannot walk straight to the water
  bowl. In the dream he stands **in Robert de Clari's place** (Clari's lord, brother and share), not
  as Clari himself and never as a hero of history: he is counted, told little, follows his lord,
  sees marvels, and learns how little a small knight decides.
- The player always plays Zampanò in the canonical campaign (other profiles are a developer
  override only, ARCHITECTURE.md §9.1).

### 2.4 Reality and dream

- **Reality**: Level 1 (1.0–1.5) and Level 8 (8.1–8.4, waking). **Dream**: Levels 2–7.
- The **sleep boundary** is the final card of 1.5: everything before it is reality, everything after
  it is dream. The waking boundary is 8.1.
- **Nothing physical comes back from the dream.** In reality there is no armour, no sword, no shield
  and no dream-only capability: the rag cross (1.5) is a real rag carried on his back; the coat of
  mail exists only in the dream (from 2.1); the arms only from 2.3.
- Reality plants what the dream uses (the bucket → the helmet, the bowl's clang → the harbour bell,
  the gates → walls, the cloth → a cross and a sail, the lecture's three voices and numbers). The
  dream may borrow reality; reality never borrows the dream's objects.

### 2.5 Recurring characters (faces)

| Reality | In the dream |
|---|---|
| Zampanò | a small knight in Robert de Clari's place |
| Confusione | Aleaume of Clari, a clerk, Robert's brother |
| Sbrimbrulòn | Pierre d'Amiens, his lord |
| Bagnaskiz | the marshal (Villehardouin); the faces of Alexios III and Alexios V |
| Watson | a Venetian sailor; a companion in the city |
| Jack | the camp's worst impulses (invented) |
| Santina | a woman on the walls (7.3); answered at her gate (8.4) |
| The Professor | himself: lecture asides at the end of each level |

### 2.6 Themes

The cost of a promise; how little a small participant decides; looking with wonder and the cost of
splendour (Meraviglia → the empty pedestal); telling the truth at one's real size; comradeship; the
direct path to the bowl (reality's problem, solved on the lawn in 8.3, never by force).

### 2.7 Canonical systems and consequences

Kept exactly unless a decision records a change:

- Meters **Commozione, Supervillain, Grace, Standing** (start 20/10/70/50, clamp 0–100), their
  meanings (`docs/STORY.md`, "Systems") and Commozione costs that lock unmoved choices.
- Abilities `cross` (1.5), `sermon` (2.2), `knight` (2.3).
- The Meraviglia book (marvels, items, values, remembered lines, shards) and its 8.2 payoff.
- Every flag of `CampaignFlagSchema` (ARCHITECTURE.md §17.1) with its current type and meaning;
  new flags require a decision and a schema update.
- The decisions that carry forward: 1.3 (the paw), 1.4 (the ball), 1.5 (the cross), 2.2 (the vow),
  5.1 (dissent), 5.3 (`zaraOwe`), 6.1 (comradeship), 6.3 (`corfu`), 7.8 (the oath: the ending),
  7.9 (the lamp), 8.2 (telling, drawing).
- Combat stays non-lethal (routing, knockdown and retry); fights only where the reference has them.

## 3. Rewrite policy

For every scene 1.1–8.4 the content matrix records: stable ID; old title and proposed title;
narrative purpose; historical event/place; gameplay interaction; characters; required setup and
payoff; persistent effects/flags; **status** (`keep`, `revise`, `replace`, `remove`); source
references; unresolved owner decision; implementation status.

- `keep`: the scene's beats and consequences stay; prose may be tightened.
- `revise`: same ID, purpose and consequences; beats, prose or interaction change (recorded).
- `replace`: same ID, a different scene serving the same structural purpose (recorded, with any
  consequence mapping).
- `remove`: not allowed for a catalog ID without a migration decision (§2.1).

A change to an ID, a state field, a choice consequence or a structural beat needs, **before** it is
implemented, an entry in `STORY_REWRITE_DECISIONS.md` with the old→new mapping and the consequence
for existing saves (format 3, campaign v2; ARCHITECTURE.md §17). Existing saves are never silently
invalidated: an ID completed in an old save stays completed; a flag value written by an old version
stays valid or is migrated explicitly.

Prose rules: pixel-font capitals; one dialogue line per box (the box grows upward for long lines);
names in the `StoryCast`; at most one **remembered line** per scene, in the dream's grammar ("THERE
WAS A …, AND IT WAS …"); period words only where `docs/STORY-SOURCES.md` lists them; the Professor's
lines are original lecture framing, never presented as quotations.

## 4. Implementation status vocabulary

Two independent axes, recorded per scene in its Resource and in the matrix:

| Technical status | Meaning |
|---|---|
| `reference_only` | only the PixiJS draft exists; nothing native |
| `specified` | the matrix row is complete; no native content |
| `implemented` | native Resource and engine support exist |
| `technically_complete` | implemented, validated by the content validator, playable start to finish by the scripted smoke and the real-input driver, saves/replays verified |

| Narrative status (`review_status`) | Meaning |
|---|---|
| `draft_reference` | PixiJS draft text, not rewritten |
| `draft_implemented_review_pending` | rewritten draft implemented; **narrative review pending** (historical accuracy, tone, characterization, every dialogue and choice, pacing, setup for both endings) |
| `narrative_approved` | the owner reviewed and approved it (never set by an implementer) |

A scene can be `technically_complete` and still `draft_implemented_review_pending`. Only the owner
moves a scene to `narrative_approved`.

## 5. Content authority: the Resources

All story content lives under `godot/data/story/`:

```text
godot/data/story/
  cast.tres                       StoryCast: speakers (name, colour, portrait frames, actor role)
  markup.tres                     StoryMarkup: the names drawn yellow on cards, the period words drawn amber in dialogue
  maps/neighborhood.tres          StoryMapData: ASCII rows, base symbol, environment bank, theme
  maps/study.tres
  chapters/ch1.tres               StoryChapterData: Level 1 metadata and its ordered scenes
  scenes/1_1.tres … 1_5.tres      StorySceneData: one scene, its ordered steps
```

### 5.1 `StorySceneData` (one catalog entry 1.1–8.4)

| Field | Meaning |
|---|---|
| `id` | stable catalog ID (`"1.3"`); must exist in `StoryCatalog` |
| `content_version` | integer, raised whenever the scene's player-visible content changes |
| `title` / `old_title` | the scene title / the PixiJS draft title (tools only) |
| `level` | chapter number |
| `summary` | the scene card text (what happens) |
| `map` | `StoryMapData` id of the first stage (each stage step names its own map) |
| `music` | `AudioService` music key |
| `cast` | speaker ids the scene uses (validated against `StoryCast` and every step) |
| `steps` | the ordered `StoryStep` Resources (§5.3) |
| `entry_conditions` | `{"requires_completed": [...ids], "requires_abilities": [...]}` — checked before the scene starts (Main never starts it; the StoryScene stops with an explicit error; RD-30) |
| `persistent_effects` | the declared effect keys the scene may write: meters, `flags.<name>`, `book.<key>`, `unlock.<ability>`; the validator rejects an undeclared write |
| `completion` | `{"boundary": "scene" | "chapter_end" | "sleep", "requires_flags": [...], "requires_abilities": [...]}` — what must be true when the scene completes |
| `reality` | `true` for reality scenes (Levels 1 and 8): plain skin, no armour, no dream capability, whatever abilities the campaign holds — the single authority for this rule (RD-30) |
| `historical_tags`, `source_refs` | the event/place tags and the references (`docs/STORY-SOURCES.md` short forms); tools only, never shown |
| `review_status`, `review_notes` | §4; notes carry every `REVIEW REQUIRED` item |
| `technical_status` | §4 (the technical axis) |

### 5.2 `StoryChapterData`

`number`, `title`, `menu_title`, `intro` (level card), `cast_note` (tools only), `music`,
`professor_aside` (the level-end aside), `scenes` (ordered `StorySceneData`), `content_version`,
`review_status`, `review_notes` — every one required and validated. The scenes' order must equal the
compatibility catalog's.

### 5.2a Display titles (RD-29)

The chapter's `title`/`menu_title` and each scene's `title` are what the game shows (Title,
CONTINUE, Couch, level and chapter lists, scene and boundary cards). `tools/build_resources.gd`
generates the runtime `StoryCatalog` from the frozen compatibility catalog
(`data/campaign/story_catalog.json`: stable IDs, order, Green Zone dispatch, draft fallback titles)
with these titles laid over it; chapters not rewritten yet keep their draft titles.

### 5.3 Steps

Every step is a typed `StoryStep` Resource with a stable `id` unique within its scene. Execution
logic is in the step's script; all player-visible text is in the Resource's fields.

| Step | Purpose | Text fields |
|---|---|---|
| `StageStep` | load a map, place the player (marker or point, facing, reality skin) and actors | — |
| `ActorStep` | spawn, despawn, move (goto/follow/idle), face, gesture an actor; `wait_arrival` with a positive `arrival_timeout` (RD-31) | — |
| `MoveStep` | scripted walk of the player to a point | — |
| `NarrationStep` | a narrator line (no speaker) | `text` |
| `DialogueStep` | a speaker's line; optional `remembered` (one per scene) and effects | `text` |
| `ChoiceStep` | a prompt and options; costs, locks, effects, follow-up steps; `once_each` mode | `prompt`, `prompt_again`, option `label`/`said` |
| `ObjectiveStep` | a walk objective: reach/collect/follow (a positive `leader_leg_timeout`, RD-31)/fight/rule, pickups (spot, shard, coin, marvel), no-run and a walking-speed modifier, the walk's own action (routed by StoryActionRouter, RD-28), a fight (`fight`, RD-33), stealth (`caught`, checkpoints), an optional scene rule (bucket visor, Jack's gate, the cut-off path, receding, lull, listen, sounder) | `objective`, `goal_label`, `action_label`/`action_text`, pickup labels/texts, leader and rule lines |
| `EffectStep` | persistent campaign effects | — |
| `CardStep` / `WaitStep` | a big centred card (timed or tap) / a pause | `big`, `small` |
| `CueStep` | sound, shake, flash, visor, a floating line | `float_text` |
| `PropStep` | place or move a story prop (bowl, ball) | `float_text` |
| `CarryStep` | carry a thing (shown on his back) or drop it | `label` |
| `MiniGameStep` | a focused minigame: parade, rowing, boat (RD-35); won/lost effects once, no retry | `lines` (title, objective, cue, hit, miss, won, lost) |
| `CompleteStep` | the scene's completion boundary (one per scene, last) | — |

## 6. Validation (automated)

`StoryValidator` checks every chapter and scene Resource and fails with an explicit message for:
unique and stable scene IDs matching the frozen compatibility catalog and its order; displayed titles
equal to the Resources' (the generated catalog is current, RD-29); every chapter field of §5.2;
positive timeouts on every wait (RD-31); unique step ids; valid step types;
known speakers, maps, markers, cast roles, sprite keys, music and sound keys; reachable choice
branches; no choice whose options can all be locked; effects limited to known meters, abilities,
book keys and `CampaignFlagSchema` flags with valid values; effects declared in
`persistent_effects`; a `StageStep` as the first step (RD-26: the engine builds no stage of its
own); exactly one final `CompleteStep` whose required state is produced by the scene on every
branch; no missing source or review metadata; no player-visible text in execution
scripts (a scan of the story scripts for string literals of player text). Missing markers, actors,
maps or resources fail explicitly at validation and at stage load.

## 7. Save, restart and replay boundaries

- A scene is a **transaction** (decision RD-05): its choices, effects and remembered lines apply at
  once to a working copy of the campaign (with their notices), and the campaign is saved **once, at
  the scene's completion boundary**, together with the completion, in one atomic SaveService
  transaction (M4 correction 28). A failed save keeps the player on the scene's last screen with the
  save-error card and applies nothing: TRY AGAIN commits the same result once, TITLE abandons the
  scene like a force-close; there is no BACK (a finished scene has nothing to go back to).
- **Restart** (story pause) discards the working copy and starts the scene again from the state it
  was entered with: no effect, meter change or reward is ever applied twice. **Quit to title** (story
  pause, or Android Back then quit) discards it the same way. The story pause offers no SKIP SCENE
  in M5R (RD-23, OQ-11).
- **Force-close** at any point inside a scene loses only that scene's uncommitted progress; the next
  launch's CONTINUE replays the scene from its start. Force-close after a completion boundary
  continues with the next scene.
- **Replay** of a finished scene runs on AppState's deep-copy session; it changes no persistent
  byte, and its completion returns to the level's scene list.
- Story play time accumulates while a scene runs (not during replays) and is committed with the
  completion.

## 8. Narrative review (owner)

Before a scene moves to `narrative_approved` the owner reviews: historical accuracy (every `REVIEW
REQUIRED` item resolved), tone and characterization, every dialogue line and choice, the level's
pacing, and the setup for both endings. The review is recorded in `STORY_REWRITE_DECISIONS.md`
(owner decisions) and in the scene Resource's `review_status`. Level 2 is not started until the
engine passes independent architectural review and the owner has reviewed the Level 1 draft.

## 9. Level 1 — rewritten draft (summary)

The full old→new comparison is in `STORY_CONTENT_MATRIX.md` ("Level 1 side by side"); the prose is in
`godot/data/story/scenes/1_1.tres`–`1_5.tres`.

| ID | Title | Purpose | Persistent effects | Boundary |
|---|---|---|---|---|
| 1.1 | A bucket on his head | from the walk to home; plants the helmet | remembered line | scene |
| 1.2 | Under the Professor's desk | the lecture's three voices and numbers; Jack's gate | three shards, remembered line | scene |
| 1.3 | The toll at the bowl | the band's toll; the paw or the water; the long way | `pawOffered` true/false, Supervillain −3 with the paw, `longWay`, remembered line | scene |
| 1.4 | Santina wants her ball back | the performance; the ball stays on his side (8.4 setup) | `santinaBall`, remembered line | scene |
| 1.5 | A cross of rag | the cloth cross; the sleep boundary | `unlock: cross` (+3 Supervillain or +3 Commozione), remembered line | sleep, then the Level 1 end |

After 1.5: the Supervillained snap, the Professor's Level 1 aside, then 2.1's scene card (M6).

## 10. Levels 2–4 — rewritten draft (summary, M6)

Prose in `godot/data/story/scenes/2_1.tres`–`4_3.tres`; every scene `draft_implemented_review_pending`
(OD-01) with its `REVIEW REQUIRED` notes; titles unchanged from the compatibility catalog.

| ID | Interaction | Persistent effects | Boundary |
|---|---|---|---|
| 2.1 | the receding gate; the helmet slips; the door names Babylon/Egypt | remembered line | scene |
| 2.2 | the vow in the sermon's lulls; the clerk's list (two answers) | `sermon`, Grace +5, `vow`, Commozione, the answer's meters, remembered line | scene |
| 2.3 | bark-only fight; sword, belt, shield; charge; sparring; follow Pierre | `knight`, Supervillain +8, remembered line | chapter_end |
| 3.1 | follow Pierre (the bell); LOOK at three marvels; MERAVIGLIA; empty berths | three marvels, Commozione +9, the book, remembered line | scene |
| 3.2 | two collections with the bowl; both counts kept | `shortfall` = 36000, remembered line | scene |
| 3.3 | kneel and weep in the trumpets' lulls | Commozione +10, `weptWell`, remembered line | scene |
| 3.4 | stealth follow; overhear; the gangplank by ear | `zaraDeal`, remembered line | chapter_end |
| 4.1 | deck walk with Watson; the parade rhythm | the fleet marvel, Commozione +8 / +2, remembered line | scene |
| 4.2 | the skiff; three horses; the bucket | Commozione +4, remembered line | scene |
| 4.3 | four rumours; Zara named; the rowing rhythm | `heardZara`, Commozione +4 / +1, remembered line | chapter_end |

After 4.3: the snap, the Level 4 aside, then the explicit "not in this build" boundary of 5.1.
