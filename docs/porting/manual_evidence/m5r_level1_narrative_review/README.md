# Level 1 narrative review — owner package

For the owner. Level 1 (scenes 1.1–1.5) has been rewritten as native Godot content and implemented:
it is **technically complete**, and its narrative status is **draft implemented, narrative review
pending**. Nothing here has been approved. This package holds everything a player reads in
Level 1, so the review can be done without running the game.

## What to review

For each scene (spec `STORY_REWRITE_SPEC.md` §8): historical accuracy (every `REVIEW REQUIRED`
item), tone and characterization, every dialogue line and choice, the level's pacing, and the
setup for both endings.

| Scene | Title | Open questions | REVIEW REQUIRED items |
|---|---|---|---|
| [1.1](1.1.md) | A bucket on his head | OQ-08 | 0 |
| [1.2](1.2.md) | Under the Professor's desk | OQ-03, OQ-04 | 2 |
| [1.3](1.3.md) | The toll at the bowl | OQ-01 | 0 |
| [1.4](1.4.md) | Santina wants her ball back | OQ-05 | 0 |
| [1.5](1.5.md) | A cross of rag | OQ-06, OQ-10, OQ-09 | 2 |
| [Level 1](level_1.md) | level card and the Professor's aside | OQ-02, OQ-09 | 1 |

Each scene file has: what changed from the draft (old → new), the decisions (RD) and open
questions (OQ) it involves, its `REVIEW REQUIRED` items, its captures, then the scene exactly as
implemented — title and summary, metadata (cast, effects, entry and completion, historical/source
tags), and every player-visible line in play order with its speaker, every choice with its cost,
locks and effects, the remembered lines and the objectives' lines.

## Open questions (answers wanted)

| ID | Question | Answer |
|---|---|---|
| OQ-01 | Should 1.3's paw (or its refusal) pay off later, for example in 8.3? | |
| OQ-02 | Show the Level 1 card (the chapter intro) before 1.0, as the draft does? | |
| OQ-03 | Every lecture fragment of 1.2 and 1.5 (accuracy, tone); is "Under the Professor's desk" still the right title? | |
| OQ-04 | "THERE WAS A GATE, AND IT WAS A CHIHUAHUA." — is Jack a chihuahua in the cast? | |
| OQ-05 | Santina's friend ("A LADY"): keep, name, or remove? | |
| OQ-06 | 1.5's two answers both unlock the cross: keep Supervillain +3 vs Commozione +3? | |
| OQ-07 | The mosque: omitted (STORY.md 7.4) or the fire's start (7.5)? (Level 7; not Level 1) | |
| OQ-08 | Should the story show the walk's coins and time when 1.1 starts? | |
| OQ-09 | The aside says Clari was "from Picardy": confirm or reword. | |
| OQ-10 | "IN THE SPRING THEY SET OFF FOR VENICE": confirm or reword; confirm RD-25's new cloth line. | |
| OQ-11 | Should the pause offer SKIP SCENE again, and what would a skipped scene commit? | |

## The three possible outcomes

Choose **one** for the Level 1 draft. The owner chose prototype deferral on 2026-11-25 (relayed with
the architect's M6 instruction); this is **not** narrative approval.

- [ ] **APPROVE LEVEL 1 DRAFT** — the rewritten Level 1 is approved as written (scenes become
  `narrative_approved`; any answers above are recorded as owner decisions).
- [ ] **REQUEST CHANGES** — list the changes (scene, line, what instead); they are made and this
  package is regenerated for another review.
- [x] **DEFER NARRATIVE APPROVAL FOR PROTOTYPE DEVELOPMENT** — Level 1 stays
  `draft_implemented_review_pending`; development may continue as a prototype, and the
  narrative review stays open (release-blocking).

| Owner decision record | |
|---|---|
| Outcome | DEFER NARRATIVE APPROVAL FOR PROTOTYPE DEVELOPMENT |
| Date | 2026-11-25 |
| Requested changes / notes | Not narrative approval. Level 1 and all later prose stay draft (`draft_implemented_review_pending`) and release-blocking; narrative review no longer blocks prototype implementation (M6 began on this decision). The open questions above stay unanswered. |

The decision is also recorded in `STORY_REWRITE_DECISIONS.md` (OD-01), `MILESTONES.md` (M5 status)
and `FEATURE_MATRIX.md`.

## How this package was made

The "scene as implemented" part of each file is generated from the Resources (the narrative
authority) by `godot/tools/story_review_export.tscn`
(`godot --headless --path godot res://tools/story_review_export.tscn -- --out <dir>`); the notes
above each transcript come from `STORY_CONTENT_MATRIX.md` and `STORY_REWRITE_DECISIONS.md`. The test
`test_SLICE_owner_review_package_lists_every_line` checks that every player-visible line of every
Level 1 Resource appears in its scene file. Captures: [`../../captures/m5r_level1/`](../../captures/m5r_level1/).
