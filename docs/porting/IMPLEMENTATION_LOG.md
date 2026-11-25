# SUPERVILLAINED VG1 — Godot port implementation log

Evidence record per milestone (TEST_PLAN.md §21). Feature-matrix boxes stay unchecked until the
architect accepts the evidence; the matrix carries a pending-review status section instead.

The first section is the current report. Every later section is a **historical** record of the
commit it names: where one says Windows evidence was not obtained, that was true then and is
superseded by the real Windows evidence in correction report 4 and the Windows and Linux evidence
in progress report 5. M5R report 29 is current. Erratum for the historical reports: their
"nothing accepted" in the milestone-status rows means that neither milestone completion was
accepted; individual architect decisions recorded in them (for example AST-007 / finding F-15 in
correction report 11) were accepted.

---

## M5R report 29 (M5R-A): story rewrite authority, content schema and validation (M1, M2, M3 Partial; M4 Partial; M5 in progress) — current

Scope: the first of the two M5R commits after `cd37a07` (correction report 28). The owner's M5R
instruction: the architect's decision that the campaign is rewritten as native Godot content (the
PixiJS story and `docs/STORY.md` become draft/reference material), Phase 0 (one M4 hardening edge),
Phase 1 (the rewrite authority) and the content schema and validation. No story engine and no
Chapter 1 Resources yet (M5R-B). The PixiJS, Capacitor and iOS sources are unchanged.

| Field | Value |
|---|---|
| Milestone status | **M1, M2, M3 Partial** (manual and device checks owner-deferred, release-blocking); **M4 Partial** (24 IDs claimed, pending review); **M5 (M5R) in progress**: authority, schema and validator in this commit; engine and Level 1 in M5R-B; nothing claimed here |
| Base | `cd37a07` (correction report 28; `godot/` tree `69eba9b`) |
| `godot/` tree | `9d171f3a09e8d21691b5840c3b5074a4f8bad23d` (this commit) |
| Host | Windows 11 Pro N for Workstations 25H2, Godot 4.7.2 console build |

### Phase 0 — future-format copies never overwrite an earlier copy

`SaveService._preserve_future()` kept a hash-suffixed copy name when the first copy differed, but
then wrote over that name even when it already held other or unreadable bytes, and could remove it
after a failed write. Now an earlier first copy with other or unreadable bytes is kept and the new
payload goes to its hash name; a hash name already holding other or unreadable bytes is a conflict
(`future_copy_conflict:<file>`, writes stay blocked) and nothing is written or removed; only a copy
the call itself created is removed on failure — matching the corrupt-save and legacy-backup rules.
Test: `test_SAV_022_future_copies_never_overwrite_an_earlier_copy` (four cases: a hash copy with
other bytes, an unreadable hash copy, an unreadable first copy, a different first copy); the
original future save and every earlier copy stay byte-identical. The old code fails it (it wrote
over, and once removed, the earlier hash copy).

### Phase 1 — the rewrite authority

- `docs/porting/STORY_REWRITE_SPEC.md`: authority order, narrative invariants (eight levels, IDs
  1.0–8.4 and the 37-entry catalog, both endings, history and the three witnesses, Zampanò's point
  of view, reality and dream, faces, themes, canonical systems), rewrite policy, status vocabulary
  (technical vs narrative; only the owner approves), the Resource schema, validation, save/restart/
  replay boundaries, the owner's narrative review, and the Level 1 summary.
- `docs/porting/STORY_CONTENT_MATRIX.md`: one entry per scene 1.1–8.4 (old/proposed title, purpose,
  history/place, play, cast, setup→payoff, effects, status, references, open question, technical ·
  narrative status) and the Level 1 side-by-side old→new table. Facts the repository's sources do
  not support are marked `REVIEW REQUIRED`.
- `docs/porting/STORY_REWRITE_DECISIONS.md`: RD-01–RD-04 (architect) and RD-05–RD-22 (implementer
  proposals for Level 1, review pending) with old→new mappings and save consequences; open owner
  questions OQ-01–OQ-10; the Level 1 `REVIEW REQUIRED` list. RD-05: a scene is one save
  transaction (saved once at its completion); restart and force-close never apply an effect twice.
- ARCHITECTURE.md (§1 narrative authority, §4 decisions 7 and 10, §13 the story engine and its save
  boundaries), MILESTONES.md (M5 is M5R; M6/M7 rewrite first), TEST_PLAN.md (CONTENT-001–005,
  FLOW-007/008, SAV-009, STY-101–105 and §11 follow the rewrite, not the draft's wording) and
  FEATURE_MATRIX.md (precedence and story rows) no longer require verbatim parity with the draft.

### Schema and validation

- `godot/story/data/`: `StorySceneData`, `StoryChapterData`, `StoryCast`, `StoryMapData`,
  `StoryActorSpec`, `StoryChoiceOption`, `StoryPickup`.
- `godot/story/steps/`: `StoryStep` and fourteen typed steps (stage, actor, move, narration,
  dialogue, choice, objective, effect, card, wait, cue, prop, carry, complete), data and schema
  hooks only (execution arrives in M5R-B).
- `godot/story/story_validator.gd`: IDs/titles/levels/order against the catalog, step types and
  ids, speakers, maps, markers per stage, actors placed before use, roles with SpriteFrames,
  sprite/sound/music keys, reachable choices and no all-locked state, effects (known keys,
  CampaignFlagSchema flags and values, declared writes), one final completion whose required state
  every branch produces, metadata, and a scan of the story engine's scripts for player text.
- `godot/data/story/`: `cast.tres` (Level 1 speakers, names and colours of `src/story/ui.ts`) and
  `maps/neighborhood.tres`, `maps/study.tres` (rows verbatim from the executed-source fixture).
- `tests/unit/test_story_schema.gd` (5 cases): a valid scene passes; 30 defect variants each fail
  with an explicit message (missing marker, map, actor, role, sprite, sound, music; unknown or
  out-of-cast speaker; duplicate step id; no or misplaced completion; all-locked choice and an
  unreachable locked branch; unknown effect key, unknown flag, invalid flag value, undeclared write,
  unknown ability, zero meter change; every metadata field; a branch that skips a required flag;
  a stage change inside a branch); chapter order and title; the maps equal the executed source and
  the cast has portrait art; the scan finds no player text in the engine and does find a planted line.

### Commands executed and results (local clone, before committing)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | 218 passed, 0 failed |
| `… -- --suite unit --file test_story_schema` | 5 passed |
| `… -- --suite unit --file test_save --case SAV_022` | 2 passed |
| mutation: the old hash-copy write restored | `test_SAV_022_future_copies_never_overwrite_an_earlier_copy` FAILS (copy overwritten, then removed) |
| `git diff --check`, `git show --check`, source-tree guard, clean status | clean before the commit (git diff --cached --check, source-tree guard, status); git show --check is run on the commit afterwards (report 30) |

The fresh-clone verification of the whole M5R list runs on M5R-B (report 30).

### Remaining gaps

- The story engine, Chapter 1 Resources, Level 1 tests, captures and the fresh-clone checks: M5R-B.
- Every M5R narrative item stays *draft, narrative review pending*; OQ-01–OQ-10 wait for the owner.

---

## Historical — correction report 28: M4 persistence safety — exact versions, transactional writes, atomic handoff, non-destructive recovery (`cd37a07`; M1, M2, M3 Partial; M4 Partial)

> Superseded by M5R report 29 (the current tree is its). Its M4 claims, the M3 acceptance it recorded and its gaps stand.

Scope: the owner's narrow M4 persistence-safety correction after `5c593d6`. Changed: `godot/autoload/`
(`save_service.gd`, `app_state.gd`), `godot/campaign/` (`campaign_schema.gd`, `legacy_import.gd`),
`godot/main/main.gd`, `godot/scenes/title/title_screen.gd`, `godot/data/shell/shell_text.tres`,
`godot/tools/capture_suite.gd` (one more shell shot), `godot/README.md`, the three save test files
(`tests/unit/test_save.gd`, `tests/unit/test_save_m4.gd`, `tests/integration/test_shell.gd`), this
log, FEATURE_MATRIX.md and three captures in `docs/porting/captures/m4_shell/`. The PixiJS, Capacitor
and iOS sources and every file outside `godot/` and `docs/porting/` are unchanged. No story scene,
dialogue, chapter prose, combat or minigame; no story rewrite; M5 not started.

| Field | Value |
|---|---|
| Milestone status | **M1, M2, M3 Partial** (their manual and device checks owner-deferred: not passed, not cancelled, release-blocking; M3's 21 automated IDs accepted by the architect, below); **M4 Partial**: 24 M4 acceptance IDs claimed by full suite cases, pending architect review (UI-014 moved to partial; SAV-021 claimed on the new preservation cases); MIG-005 (M4 half), MIG-006–010, SAV-009, SAV-010, UI-009, UI-014 and the shell portions of FLOW-005, FLOW-007–009 and FLOW-012 partial; M4's manual checks not executed |
| Base | `5c593d6` (M4 report 27; `godot/` tree `477f012`) |
| Current `godot/` tree | `69eba9b75fbbb08002ef92cf02e1a9a91b9b3964`; verified on a fresh Windows clone of the local verification commit `c25ea3f` (the same `godot/` tree and the three captures; this commit adds only `docs/porting/` text) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090, OpenGL 3.3 Compatibility renderer; Linux not run |
| Android | not run (no device or emulator claim) |

### Architect decision recorded

**Correction report 26's 21 M3 IDs are accepted:** GZ-001, GZ-016, GZ-017, GZ-031, GZ-032,
GZ-034–036, GZ-037, GZ-038–041, GZ-042–045, DOG-005b, FLOW-003, FLOW-004 and AUTO-001 (`57f4bf7`,
`godot/` tree `0684cc9`). With DOG-005b, the split ID DOG-005 (DOG-005a + DOG-005b) is satisfied.
**Totals: 113 by full suite cases (counting split-ID parts; 92 + 21) + 4 on combined evidence + 2 on
command evidence = 119 satisfied.** Their cases pass unchanged on the current tree. M1, M2 and M3
stay **Partial**: the M1 manual checks, the M2 desktop and touch play checks and M3's MAN-GZ runs,
portrait phone checks with both hands and background/resume checks are owner-deferred, unpassed and
release-blocking; UI-001–006 and FLOW-005 remain partial.

### Corrected

1. **Exact schema versions** (`SaveService.validate_container`, `CampaignSchema.is_version`/
   `normalize`, `LegacyImport`). The version decision compares the finite numeric value, never an
   integer cast: a container is format 3 only at exactly 3 (3.0 included); anything greater — 3.5
   and 3.0001 included — is a future format (preserved byte for byte, writes blocked); anything
   smaller is unsupported and never normalized as format 3. A campaign is accepted only at exactly
   version 2 (2.5, 2.1, 2.0000001, "2" rejected); a present campaign with any other version makes the
   whole container invalid, so it is preserved as a corrupt copy and recovered from, never silently
   reset to defaults. The legacy `story` key converts only at exactly 1 (migrated first) or 2.
   Before: `int(format_version)` read 3.5 as 3 and normalized it; `int(version)` accepted campaign
   2.5.
2. **Transactional domain writes** (`SaveService.commit`). `set_settings`, `save_record`,
   `save_campaign` and the import build a deep candidate container; `commit()` stamps
   `written_at_unix_ms`, writes it atomically and only then replaces `data`. A refused or failed
   write leaves the whole in-memory container (its `written_at_unix_ms` included) exactly as it was,
   so memory and the committed file never diverge; a future-format (or unpreserved) session is
   genuinely read-only, in memory too (before, a blocked `save_record` kept the record in memory and
   a blocked import changed the import record). A completely written, validated temp from a failed
   call is still recovered whole by the next launch (crash recovery). AppState applies a settings
   change only after it is saved; a failure emits `save_error` and Main shows the save-error card.
3. **Atomic, idempotent walk handoff** (`AppState.complete_walk`, `Main`). Coins, time and the
   completion of 1.0 are one campaign candidate with one savedAt (the source's addWalk + finishSub,
   two saves, became one: D-25). A failed or refused handoff applies none of them; a retry cannot
   double them (the live state is unchanged); once 1.0 is complete a repeated handoff adds nothing,
   and Main ignores a second CONTINUE from the same result card. Main checks every result: a failed
   NEW GAME stays on the title, a failed CONTINUE stays on the result card, each with the save-error
   card (what failed, that nothing changed, what to do: TRY AGAIN and BACK, plus TITLE on the result
   card; in a read-only session no TRY AGAIN and the update or restart advice); neither advances to
   1.1 nor starts another Green Zone. The normal path and replay isolation are unchanged.
4. **Transactional legacy import** (`LegacyImport.run`). After the raw backup and its read-back,
   every key converts into an isolated candidate; `SaveService.data` is not touched until the one
   commit succeeds. A failed final write keeps the pre-import settings, records, passive coins,
   campaign and import record exactly, reports `retryable_error` (`container_write_failed`) with no
   imported keys, and a same-session retry imports without `campaign_conflict`; coins, time and
   progress are never added twice. An existing raw backup with different bytes is moved aside and
   verified first; one that cannot be read (`backup_existing_unreadable`), whose aside name holds
   other bytes (`backup_aside_conflict`), that cannot be moved (`backup_rotate_failed`) or whose moved
   copy reads back wrong (`backup_rotate_verify_failed`) is never written over. Before, a failed
   write left the converted keys in memory and a retry hit `campaign_conflict`; an unreadable raw
   backup was overwritten.
5. **Non-destructive corrupt-save recovery** (`SaveService._read_file`, `_preserve_corrupt`). Loading
   distinguishes an absent file, readable bytes that are not a valid container, and a file whose
   bytes cannot be read. An invalid main's exact bytes are copied (`save_v3.corrupt.json`, or a
   hash-suffixed name when an earlier, different copy exists — never overwritten) and the copy is
   read back and compared BEFORE the main is removed, rotated or replaced (at load and in the
   writer). When the main cannot be read, or its copy cannot be written or verified, the main stays
   byte-for-byte untouched, the newest valid file (or the defaults) is shown read-only, every write
   is refused for the session (`write_blocked_unpreserved_save`) and the title shows a notice; the
   next healthy launch preserves and recovers as usual. Before, an unreadable main was copied as an
   empty file and deleted, and a second corrupt main overwrote the first copy.
6. **The story notice** (`AppState.take_story_notice`, `Main.continue_game`). The dream-rewritten
   notice is cleared and reported only after a successful transactional campaign save (savedAt =
   now, as the source's showNotice → saveCampaign; before, the port wrote the container without
   moving savedAt and ignored the result). On failure the notice stays in memory and on disk, Main
   gets the failure and shows the save-error card instead of the notice card and does not move on.
7. **Title input while covered** (`TitleScreen`). `activate()` and the inherited `_gui_input()` drop
   everything while `covered` is true (an overlay or a running transition), besides `_process()`,
   `on_tap()` and now `change_lives()`; Main's NEW GAME, CONTINUE and level-list starts also ignore
   requests while a transition runs, so a pending scene change is never run early or replaced.
8. **Evidence and documentation**: the named UI-007 cases now drive NEW GAME and CONTINUE through
   the title's own rows (confirmation, preselection, the notice, every destination); UI-012–014 is
   split into `test_UI_012_013_…` and the partial `test_P_UI_014_…`; FEATURE_MATRIX.md records the
   M3 acceptance and the new totals; D-21 gains the visible title behind OPTIONS.

### Deviations (new or amended)

| ID | Deviation | Planned |
|---|---|---|
| D-21 (amended) | Besides the simplified title presentation: OPTIONS, the NEW GAME confirmation and the Goodbye card are drawn over the dimmed, visible title; the source hides the title under them (`Flow.overTitle`) | M8 |
| D-24 | A refused or failed save changes nothing and the flow stops on a save-error card (TRY AGAIN where it can help); the source's `storage.set` ignores storage failures and the game goes on with the unsaved in-memory change. The card's wording is not owner-approved | — |
| D-25 | The walk's handoff is one atomic campaign save with one savedAt (the source saves twice, addWalk then finishSub; the final state and the final savedAt agree); once 1.0 is complete a repeated handoff adds nothing (unreachable in the source's flow) | — |

D-17–D-20, D-22 and D-23 are unchanged.

### Acceptance IDs

Accepted by the architect (counted above): correction report 26's 21 M3 IDs.
Claimed by full suite cases (pending review, 24): SAV-005, SAV-006, SAV-007, SAV-008, SAV-011,
SAV-012, SAV-021; UI-007, UI-008, UI-010, UI-011, UI-012, UI-013, UI-015–021, UI-022; FLOW-006,
FLOW-010, FLOW-011. SAV-021 rests on `test_SAV_021_invalid_main_copied_and_verified_before_any_repair`
(unit: exact copy and read-back before the main is touched, an earlier copy kept, main read
failure, copy write failure, two copy read-back failures, the next healthy launch) and
`test_SAV_021_corrupt_main_restored_from_backup_with_notice` (title notices, now including the
unreadable main). SAV-022 (accepted earlier) still passes, now also with the fractional future
version 3.5 in main, temp and backup and an unchanged in-memory container after the refused writes.
Moved to partial: UI-014 (`test_P_UI_014_couch_play_time_saved_date_and_ending`: the saved date uses
the device's current UTC offset for every date, not the offset in force at that date, so across a
daylight-saving or historical time-zone change it can differ from the source's local time).
Partial (`test_P_`): SAV-009, SAV-010, MIG-005 (M4 half), MIG-006, MIG-007, MIG-008, MIG-009,
MIG-010, UI-009, UI-014, FLOW-005, FLOW-007–009, FLOW-012. Not attempted: MIG-001–004 (M9). Still
satisfied: SAV-001–004, SAV-013–020, SAV-022.

Tests added or changed:
- `tests/unit/test_save.gd`: `test_SAV_021_invalid_main_copied_and_verified_before_any_repair`
  (replaces `test_P_SAV_021_corrupt_save_recovers_from_backup`); `test_SAV_022_…` (payloads 4 and
  3.5; memory read-only); `test_SLICE_exact_versions_fractional_and_nested_never_normalized`
  (validator table, nested campaign versions, a below-3 or bad-campaign main/temp/backup on disk);
  `test_SLICE_domain_writes_are_transactions_at_every_stage` (settings, a record and the campaign ×
  eleven stages: temp write, torn temp, temp read-back, backup removal, backup rotation, final
  rename, the four crash hooks, a blocked session; whole-container equality, committed bytes, a
  same-session retry); `test_SLICE_failed_call_leaves_a_recoverable_whole_temp`.
- `tests/unit/test_save_m4.gd`: `test_SLICE_walk_handoff_is_atomic_and_idempotent`,
  `test_SLICE_story_notice_taken_only_after_a_saved_clear`,
  `test_P_MIG_009_final_write_failure_leaks_nothing_and_retries`,
  `test_P_MIG_005_existing_raw_backup_preserved_or_left_alone`,
  `test_P_MIG_007_008_story_versions_must_be_exact` (the handoff, notice and final-write cases each
  run the eleven stages); `test_P_SAV_010_…` (result shape) and `test_P_FLOW_007_009_policy_shell`
  (one atomic save) updated.
- `tests/integration/test_shell.gd`: `test_UI_007_new_game_confirms_over_a_story_and_starts_the_walk`
  and `test_UI_007_continue_preselection_notice_and_destinations` (from the two SLICE cases, expanded:
  the title's own rows, no question without a story, NO/Back byte-identical, the story scene with its
  briefing, preselection both ways, the notice's savedAt, the named 1.1 boundary, the level list);
  `test_UI_012_013_…` and `test_P_UI_014_…` (split); `test_SLICE_new_game_save_failure_stays_on_the_title`
  and `test_SLICE_continue_save_failure_stays_on_the_result_card` (every stage, then TRY AGAIN applies
  once; a repeated CONTINUE adds nothing); `test_SLICE_future_blocked_session_changes_nothing` (a real
  3.5 backup: NEW GAME, the walk, CONTINUE and TITLE change no byte and no memory);
  `test_SLICE_story_notice_kept_when_its_save_fails`; `test_SLICE_settings_save_failure_keeps_the_setting`;
  `test_SLICE_title_takes_no_touch_while_a_transition_runs` (real `InputEventScreenTouch` presses and
  releases through `Input.parse_input_event`: one NEW GAME touch starts the glitch; repeated NEW
  GAME, CONTINUE, lives, publisher, COUCH, OPTIONS, GLOSSARY and QUIT touches during it run nothing,
  the burst is not restarted and its scene change runs once, at its midpoint); the SAV-021 case gains
  the unreadable-main notice.

Mutation checks (scratchpad harness; each source restored from a byte copy): the tests failed for
every injected defect — commit writing memory before the file, the handoff saved in two steps, an
import leaking its candidate on failure, no corrupt-copy preservation, the integer-cast container
version, the integer-cast campaign version, the notice taken before its save, an unreadable raw
backup overwritten, Main ignoring a failed NEW GAME, Main ignoring a failed CONTINUE, and both title
guards removed. Removing only one of the two title guards (`activate` or `_gui_input`) is not
detected, because the other still drops the touch (they are deliberate defence in depth).

### Commands executed and results

| Command | Exit | Result |
|---|---|---|
| `git clone --branch claude/gallant-keller-rbvtvy <session clone> <fresh dir>`; `npm ci`; `npx playwright install chromium` | 0 / 0 / 0 | fresh clone of the verification commit; `godot/` tree as above |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (deterministic asset check) | 0 | asset check OK: 208 outputs identical (73 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12); build_resources check (all): OK, 56 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | 0 | 0 ERROR/WARNING lines; `git status --porcelain` afterwards empty: yes |
| `… --script res://tests/test_runner.gd -- --suite all` (full suite) | 0 | 212 passed, 0 failed, 212 total (101.6 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_threats` (focused M3) | 0 | 13 passed, 0 failed, 13 total (2.8 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_green_zone_m3` (focused M3) | 0 | 7 passed, 0 failed, 7 total (8.0 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_green_zone_m3 --case AUTO_001`, twice (deterministic AUTO-001) | 0 / 0 | identical lines: yes — `complete after 60.1 s: treats 26, poops 6, pees 7, marks 1, coins 5, bark hits 3, lives 2, score 2820, health 0.9560, stars 3.5, total 6360` |
| `… -- --suite unit --file test_save_m4` (focused M4 save) | 0 | 25 passed, 0 failed, 25 total (1.7 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell` (focused M4 shell) | 0 | 23 passed, 0 failed, 23 total (9.7 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save` (the runner matches file names by substring: test_save.gd and test_save_m4.gd) | 0 | 46 passed, 0 failed, 46 total (3.5 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save --case exact_versions` (exact versions (fractional, nested campaign)) | 0 | 1 passed, 0 failed, 1 total (0.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save --case SAV_022` (SAV-022 future formats incl. 3.5, read-only memory) | 0 | 1 passed, 0 failed, 1 total (0.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save --case SAV_021` (SAV-021 corrupt-main preservation (unit)) | 0 | 1 passed, 0 failed, 1 total (0.3 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save --case transactions_at_every_stage` (transactions at every write stage) | 0 | 1 passed, 0 failed, 1 total (1.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save --case recoverable_whole_temp` (failed call leaves a whole recoverable temp) | 0 | 1 passed, 0 failed, 1 total (0.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save_m4 --case walk_handoff_is_atomic` (walk handoff atomic and idempotent) | 0 | 1 passed, 0 failed, 1 total (0.3 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save_m4 --case story_notice_taken_only` (story notice taken only after a saved clear) | 0 | 1 passed, 0 failed, 1 total (0.3 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save_m4 --case final_write_failure` (legacy import final-write failure, retry, idempotence) | 0 | 1 passed, 0 failed, 1 total (0.4 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save_m4 --case existing_raw_backup` (existing raw legacy backup preserved or left alone) | 0 | 1 passed, 0 failed, 1 total (0.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save_m4 --case story_versions_must_be_exact` (legacy story versions exact) | 0 | 1 passed, 0 failed, 1 total (0.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell --case new_game_save_failure` (NEW GAME save failures stay on the title) | 0 | 1 passed, 0 failed, 1 total (1.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell --case continue_save_failure` (CONTINUE save failures stay on the result card) | 0 | 1 passed, 0 failed, 1 total (1.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell --case future_blocked_session` (future-blocked session changes nothing) | 0 | 1 passed, 0 failed, 1 total (1.1 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell --case notice_kept_when` (notice kept when its save fails) | 0 | 1 passed, 0 failed, 1 total (0.7 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell --case settings_save_failure` (settings save failure keeps the setting) | 0 | 1 passed, 0 failed, 1 total (0.7 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell --case title_takes_no_touch` (title takes no touch during a transition (real touches)) | 0 | 1 passed, 0 failed, 1 total (1.2 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell --case SAV_021` (SAV-021 notices through the title) | 0 | 1 passed, 0 failed, 1 total (0.7 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell --case UI_007` (UI-007 named cases) | 0 | 3 passed, 0 failed, 3 total (3.0 s), Godot 4.7.2-stable (official) |
| `<console exe> --headless --path godot --quit-after 600` (600-frame Main launch) | 0 | 0 ERROR/WARNING lines |
| `<console exe> --headless --path godot --quit-after 120 --verbose`, filtered for the first scene loaded | 0 | Completed load for: 'res://scenes/title/title_screen.tscn' remapped 'res://scenes/title/title_screen.tscn' at thread -1 |
| `… -- --suite integration --file test_export_pack` (hermetic PCK smoke) | 0 | 1 passed, 0 failed, 1 total (17.3 s), Godot 4.7.2-stable (official) |
| `npm test` (PixiJS) | 0 | Tests  248 passed (248) |
| `npm run build` (PixiJS) | 0 | built in 309ms |
| `git status --porcelain` after the checks (clean status) | 0 | empty |
| `git diff --check 95b69c0 HEAD`; `git show --check --format= HEAD` | 0 / 0 | no output |
| `bash godot/tools/source_tree_guard.sh` | 0 | source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265 |
| `git diff --stat 95b69c0 HEAD -- src public assets android ios package.json package-lock.json` | 0 | empty (PixiJS untouched) |
| `git status --porcelain` after all steps | 0 | empty |

Captures (`docs/porting/captures/m4_shell/`, windowed Compatibility renderer, `capture_suite.gd
--mode shell`): `36_save_error_w192.png`, `36_save_error_w216.png`, `36_save_error_w270.png` — the
save-error card of a failed CONTINUE over the title at logical widths 192, 216 and 270. The twelve
M4 captures are unchanged.

Not run: Linux; Android (no APK, no device or emulator); any manual check (M1–M3 deferred; M4's
manual list); listening to audio; the M2 rendered presentation probe; an owner review of the
save-error card.

### Remaining gaps

- Manual: every option across a real app restart, three Green Zone records by hand, the import
  fixtures through a debug UI, a force-close during a save, Android Back through every overlay and
  the save-error card on a device, visual review of the shell at phone sizes; the save-error and
  unpreserved-save wording is not owner-approved.
- UI-014: historical UTC offsets for the saved date.
- M5: the story scenes after 1.0, the level/scene cards, the Meraviglia book, the story pause and
  SKIP SCENE, per-effect saves, story play time, the gesture recognizer, text speed in dialogue.
- M9: the Android bridge acquisition, MIG-001–004 and the M9 half of MIG-005, signed upgrade.
- M8: the title's logo lettering, film and glitch, the title hidden under OPTIONS, the confirmation
  and the Goodbye card (D-21), D-17–D-19.

### Development attempts (kept as found)

- The first run of the corrupt-copy case used invalid UTF-8 bytes; Godot printed "Unicode parsing
  error" while decoding them, so the case now uses valid UTF-8 with a NUL and CRLF (the same
  byte-exact check).
- A Variant-typed `var camp :=` in `test_save_m4.gd` failed to parse; typed explicitly.
- The first settings-failure case read `save_v3.json` after a failed final rename had moved it to
  the backup; it now reads the committed file.
- Two existing M4 cases expected the old two-save handoff and result shape; updated to the atomic
  save.

---

## Historical — M4 report 27: native save system and non-story product shell (`5c593d6`; M1, M2, M3 Partial; M4 Partial)

> Superseded by correction report 28 (the current tree, claims and counts are its): UI-014 moved to partial, SAV-021 now rests on the preservation cases, the walk handoff is one atomic save (D-25), and correction report 26's 21 M3 IDs are accepted. Its other M4 claims, deviations D-20–D-23 and gaps stand.

Scope: the owner's M4 instruction after `57f4bf7`: the format-3 save, its validators, writer and
recovery; the deterministic legacy converter with the fixture/simulated half of MIG-005; settings
and Green Zone persistence; the title, NEW GAME confirmation, COUCH, OPTIONS, CONTROLS, GLOSSARY,
Goodbye and a replay-selection shell. Changed: `godot/` (list below), this log, FEATURE_MATRIX.md
and twelve captures in `docs/porting/captures/m4_shell/`. The PixiJS, Capacitor and iOS sources and
every file outside `godot/` and `docs/porting/` are unchanged. No story scene, dialogue, chapter
prose, combat or minigame was implemented; M5 was not started.

| Field | Value |
|---|---|
| Milestone status | **M1, M2, M3 Partial** (their manual checks owner-deferred: not passed, not cancelled, release-blocking); **M4 Partial**: every M4 system implemented and automated; 25 M4 acceptance IDs claimed by full suite cases, pending architect review; MIG-005 (M4 half), MIG-006–010, SAV-009, SAV-010, UI-009 and the shell portions of FLOW-007–009/012 partial; M4's manual checks not executed |
| Base | `57f4bf7` (correction report 26; `godot/` tree `0684cc9`) |
| Current `godot/` tree | `477f012b1f3861c6ea4273dd532acf5adce34997`; verified on a fresh Windows clone of the local verification commit `1ce0330` (the same `godot/` tree; this commit adds only `docs/porting/`) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090, OpenGL 3.3 Compatibility renderer; Linux not run |
| Android | not run (no device or emulator claim) |

### Implemented

1. **Format-3 persistence** (`autoload/save_service.gd`, `campaign/campaign_schema.gd`): the exact
   `user://save_v3.json` container of ARCHITECTURE §17.1. Every section is normalized on load and on
   every write: settings (the source loadSettings/validControls rules), independent records, the
   passive `legacy_arcade_coins` `{present, value}`, the campaign v2 (catalog ids only, meters
   clamped 0–100, book/ability arrays deduplicated by first occurrence, abilities limited to
   cross/knight/sermon, coins/playTime/savedAt/notice typed) with CampaignFlagSchema (known enums,
   the nonnegative `shortfall`, the booleans, `santinaBall` any scalar, unknown scalars kept,
   unknown arrays/objects dropped), and the legacy-import metadata. `written_at_unix_ms` changes on
   every container write; `campaign.savedAt` only at a campaign save. The atomic protocol (temp
   write + flush, read-back validation, backup rotation, rename; newest-valid recovery; future
   formats preserved byte-for-byte and writes blocked for the session) now runs through one
   injectable `SaveFileOps`; a recovery from the backup or an unreadable main raises a title notice.
2. **Legacy conversion** (`campaign/legacy_import.gd`): a source hands over the five-key payload as
   received; its raw bytes and a metadata file (timestamp, SHA-256, size) are written to
   `user://legacy/` and read back before anything is parsed (an earlier, different payload is kept
   aside); then settings, records (merged as bests), the standalone coins (present/value only), the
   campaign (v1 → the existing CampaignMigration → v2 → format 3, or v2 → format 3; never over a
   campaign with progress) and the v1 backup are converted independently. Statuses: imported,
   imported_partial, not_found, retryable_error, blocked, with per-key results, attempt count, the
   payload hash and an error code; retryable_error retries, blocked waits, not_found is terminal
   unless forced, imported states are idempotent. M4 uses `FixtureSource`; the Android bridge that
   reads the old WebView store is M9 (the accepted M1 spike).
3. **AppState and the Green Zone** (`autoload/app_state.gd`, `scenes/green_zone/green_zone_scene.gd`):
   settings save on a confirmed change and apply at once (audio mute/volume, input run toggle and
   hand, the gesture bindings and switcher stored in InputService for M5's recognizer); NEW GAME
   saves the exact default campaign; the walk's record saves at level completion; CONTINUE hands the
   walk over like the source (addWalk then finishSub: coins and time, then 1.0 complete, two
   campaign saves); RETRY, result-screen TITLE/QUIT and game over hand nothing over; gameplay never
   writes `legacy_arcade_coins`.
4. **Product shell**: Main starts at `scenes/title/title_screen.tscn` (NEW GAME, CONTINUE, COUCH,
   OPTIONS, GLOSSARY, QUIT; the animated portrait; INSERT BRAIN with the lives counter; LIFE FOR
   SPEED; SUPERVOID EDITIONS), with overlays in `scenes/shell/`: the NEW GAME confirmation, OPTIONS
   (sound, volume, text speed, CONTROLS, LEVELS (REPLAY), MERAVIGLIA BOOK, BACK), CONTROLS (three
   gestures, RUN hold/toggle, switcher, hand, DEFAULTS), COUCH and GLOSSARY paper cards, the level
   and chapter lists, and a message card (Goodbye where an app cannot close; the one-time migration
   notice; save notices; the boundary). CONTINUE derives its destination from the saved campaign
   (`StoryCatalog`, generated from the source catalog's ids and titles; `CampaignFlow`); starting
   1.0 launches the Green Zone; after 1.0, 1.1 is shown as "NOT IN THIS BUILD" over the title with
   the progress kept — no story scene is invented, nothing is erased and no other run starts. Story
   words of the shell live in `data/shell/shell_text.tres`; a story rewrite edits that resource and
   the generated catalog, not the title or save code. Only the topmost overlay takes input; queued
   input is cleared when an overlay opens; Esc and Android Back close one overlay at a time and quit
   on the bare title. Developer start `-- --skip=game` (source `?skip=game`).
5. **Replay and flow policy** (`campaign/campaign_flow.gd`, `campaign/campaign_rules.gd`,
   `campaign/campaign_summary.gd`): sequential unlock (level 1 open, a level after the previous one,
   finished scenes plus the first unfinished one), replays on a deep copy with persistence off
   (no record, no campaign write), the walk's save order, the Supervillained boundaries, the
   effects rules (applyEffects/markComplete) and the Couch summary.

Tests and tools never read or write a developer's save: with a scripted main loop (the test runner,
`--script` tools) SaveService starts in memory until a directory is set explicitly (before this
report the runner's autoload start-up read the real `user://` save before each case was isolated).

### Deviations (new)

| ID | Deviation | Planned |
|---|---|---|
| D-20 | A replay of the walk saves no record (the source records a replayed walk's best); the architect's rule is that a replay changes no persistent byte | — |
| D-21 | Title presentation simplified: SUPERVILLAINED in the pixel font (source: the gradient/outline/glow logo lettering), no blurred frozen Green Zone with the film and glitch filters behind it, no lettering glitch, the footer glow approximated | M8 |
| D-22 | NEW GAME and CONTINUE into 1.0 skip the story's level-intro and scene cards (chapter prose); 1.1 onwards and the MERAVIGLIA BOOK show a "not in this build" card | M5 |
| D-23 | QUIT closes the app on desktop builds too (the source closes on Android and shows the Goodbye card in browsers and on iOS; Godot shows it where an app cannot close) | — |

D-17, D-18, D-19 and the frozen HUD remain M8 presentation debt. All saves are written at once, so
nothing is dirty when the app goes to the background (no extra flush needed).

### Acceptance IDs

Claimed by full suite cases (pending review): SAV-005, SAV-006, SAV-007, SAV-008, SAV-011, SAV-012,
SAV-021; UI-007, UI-008, UI-010, UI-011, UI-012–014, UI-015–021, UI-022; FLOW-006, FLOW-010,
FLOW-011. Still satisfied: SAV-001–004, SAV-013–020, SAV-022 (their cases pass on the new writer).
Partial (`test_P_`): SAV-009, SAV-010, MIG-005 (M4 half), MIG-006, MIG-007, MIG-008, MIG-009,
MIG-010, UI-009, FLOW-007–009 (one case), FLOW-012, FLOW-005. Not attempted: MIG-001–004 (M9).

Tests: `tests/unit/test_save_m4.gd` (20 cases) and `tests/integration/test_shell.gd` (16); updated
`test_main_and_rates.gd` (Main starts the walk with `start_target = "walk"`; FLOW-005 now checks the
saved handoff and the 1.1 card), `test_export_pack.gd` (the pack starts at the title, then the
walk), `test_assets` unchanged. Fixtures executed from the audited TypeScript and added to
`tests/fixtures/source_reference.json`: `couch` (progressSummary, formatPlayTime, formatSavedAt —
local time bound to UTC during extraction), `effects` (applyEffects, markComplete), the
TITLE/COUCH/GLOSSARY config groups; `data/campaign/story_catalog.json` (ids and titles, built into
`story_catalog.tres`). The extractor's module hook now resolves directory imports (tools only).

### Commands executed and results

| Command | Exit | Result |
|---|---|---|
| `git clone --branch claude/gallant-keller-rbvtvy <session clone> <fresh dir>`; `npm ci`; `npx playwright install chromium` | 0 / 0 / 0 | fresh clone of the verification commit; `godot/` tree as above |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (deterministic asset check) | 0 | asset check OK: 208 outputs identical (73 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12); build_resources check (all): OK, 56 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | 0 | 0 ERROR/WARNING lines; `git status --porcelain` afterwards empty: yes |
| `… --script res://tests/test_runner.gd -- --suite all` (full suite) | 0 | 197 passed, 0 failed, 197 total (94.8 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_threats` (focused M3) | 0 | 13 passed, 0 failed, 13 total (2.7 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_green_zone_m3` (focused M3) | 0 | 7 passed, 0 failed, 7 total (7.9 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_green_zone_m3 --case AUTO_001`, twice (deterministic AUTO-001) | 0 / 0 | identical lines: yes — `complete after 60.1 s: treats 26, poops 6, pees 7, marks 1, coins 5, bark hits 3, lives 2, score 2820, health 0.9560, stars 3.5, total 6360` |
| `… -- --suite unit --file test_save_m4` (focused M4) | 0 | 20 passed, 0 failed, 20 total (0.7 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_shell` (focused M4 shell) | 0 | 16 passed, 0 failed, 16 total (5.9 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_save` (M1/M2 save cases on the new writer) | 0 | 38 passed, 0 failed, 38 total (1.2 s), Godot 4.7.2-stable (official) |
| `<console exe> --headless --path godot --quit-after 600` (600-frame Main launch) | 0 | 0 ERROR/WARNING lines |
| `<console exe> --headless --path godot --quit-after 120 --verbose`, filtered for the first scene loaded | 0 | the title scene is loaded (`title_screen.tscn`); Main preloads the Green Zone scene too, so its resource load is also listed; the running first scene is the title (`test_SLICE_fresh_launch_reaches_title`, the PCK probe's `running_scene`) |
| `… -- --suite integration --file test_export_pack` (hermetic PCK smoke) | 0 | 1 passed (17.3 s): PCK 33,042,832 bytes, 285 runtime resources loaded from the pack, 573 packed files, 18 source-only paths unresolved (control 18); the packed game starts at the title, then the Green Zone loads from the pack |
| `npm test` (PixiJS) | 0 | Tests  248 passed (248) |
| `npm run build` (PixiJS) | 0 | built in 308ms |
| `git status --porcelain` after the checks (clean status) | 0 | empty |
| `git diff --check 95b69c0 HEAD`; `git show --check --format= HEAD` | 0 / 0 | no output |
| `bash godot/tools/source_tree_guard.sh` | 0 | source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265 |
| `git diff --stat 95b69c0 HEAD -- src public assets android ios package.json package-lock.json` | 0 | empty (PixiJS untouched) |
| `git status --porcelain` after all steps | 0 | empty |

These ran on the fresh clone of the verification commit. The final commit (the same `godot/` tree plus
`docs/porting/`) is checked with `git show --check`, `git status` and the source-tree guard right after
committing; those results are reported with the commit.

Captures (`docs/porting/captures/m4_shell/`, windowed Compatibility renderer, `capture_suite.gd
--mode shell`, an in-memory save after the walk with a record): the title, COUCH and GLOSSARY at
logical widths 192, 216 and 270; OPTIONS, CONTROLS and the level list at 216.

Not run: Linux; Android (no APK, no device or emulator); any manual check (M1–M3 deferred; M4's
manual list); listening to audio; the M2 rendered presentation probe (it now starts Main with
`start_target = "walk"`, not rerun).

### Remaining gaps

- Manual: every option across a real app restart, three Green Zone records by hand, the import
  fixtures through a debug UI, a force-close during a save, Android Back through every overlay on a
  device, visual review of the shell at phone sizes.
- M5: the story scenes after 1.0, the level/scene cards, the Meraviglia book, the story pause and
  SKIP SCENE, per-effect saves, story play time, the gesture recognizer, text speed in dialogue.
- M9: the Android bridge acquisition, MIG-001–004 and the M9 half of MIG-005, signed upgrade.
- M8: the title's logo lettering, film and glitch, D-17–D-19.

### Development attempts (kept as found)

- The first Couch layout captured its line counter in GDScript lambdas, which copy locals; it was
  rewritten with member state before any run.
- The first shell run found that a covered overlay still read Esc, so one press closed two
  screens; only the topmost overlay now takes input (`OverlayPanel.is_top`).
- Test fixes in the first runs: a too-short glint window, a wrong expected gesture value, a test
  lambda holding a freed scene, a wrong failure target for the final rename, the fixture's key
  names (`raw`/`migrated`), and Variant typing of untyped SaveService results.

---

## Historical — correction report 26: terminal freeze and strengthened GZ-032/043/044/045 evidence (`57f4bf7`; M1 Partial, M2 Partial, M3 Partial)

> Superseded by M4 report 27 (the current tree and counts are its). Its M3 claims, the terminal freeze and the owner deferral of the M1–M3 manual checks (unpassed, release-blocking) stand.

Scope: the architect's narrow M3 correction after `be6f9dd`: freeze the level under the terminal
presentation, strengthen four named Green Zone cases, correct the documentation. Changed:
`godot/scenes/green_zone/green_zone_scene.gd`, `godot/tests/integration/test_green_zone_m3.gd`,
`godot/tests/unit/test_threats.gd`, this log and FEATURE_MATRIX.md. No other file changed: no
shipping rule, threat, audio, asset, save, touch, Android or PixiJS change, no story content, no M4
or M8 work.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (manual checks owner-deferred for prototype development: not passed, not cancelled, not release-approved, still release-blocking); **M3 Partial** (playable prototype; 21 M3 IDs claimed by full suite cases, pending architect review; UI-001–006, FLOW-005, GZ-033 partial; MAN-GZ not executed) |
| Base | `be6f9dd` (M3 report 25; `godot/` tree `b93d332`) |
| Last architect-accepted M1/M2 baseline | `godot/` tree `21ce8a2` (correction report 24; 139 passed) — kept as the accepted baseline, not the current tree |
| Current `godot/` tree | `0684cc95bfebbaa1016fdeddf8f755696e90b340`; verified on a fresh Windows clone of the local verification commit `81d8d10` (the same `godot/` tree; this commit adds only `docs/porting/`) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090, OpenGL 3.3 Compatibility renderer; Linux not run |
| Android | not run (no device or emulator claim for the game) |

### Corrections

1. **Terminal freeze.** `GreenZoneScene._freeze_terminal()` runs first in `_on_complete()` (before
   the Supervillained snap and the result card) and in `_on_game_over()`, after the unchanged 1.1 s
   post-exit delay (`rules.ended_for() > 1.1`; during the delay the level still ticks, as before and
   as in the source). Once frozen: `tick()` returns at once (no logic tick, no rule or map timer, no
   camera step, no attack-look update, no critter or view sync), `_process()` returns at once (no
   world render pass, HUD, exit-ring pulse or magnet rings), the touch controls and MENU are off,
   and `IsoWorld` is set to `PROCESS_MODE_DISABLED` (the dog's and critters' AnimatedSprite2D, the
   score popups and the camera stop; physics interpolation is reset so nothing settles afterwards).
   The overlays are outside the world (the scene's overlay canvas, or Main's overlay host) and keep
   processing and taking input; CONTINUE, RETRY, QUIT TO TITLE and the pause menu's RESTART (only
   available while playing) are unchanged. Source note: `SceneStack` stops updating the scene below
   an overlay with `pausesBelow` but still renders it, so the source's HUD radar sweep and hunger
   blink keep animating under the dimmed overlays; here the HUD is frozen with the rest
   (presentation only; added to the M8 presentation debt below).
   Cases (SLICE: no plan ID covers the freeze): `test_SLICE_terminal_freeze_under_snap_and_result_card`
   and `test_SLICE_terminal_freeze_under_game_over` build a level with a cat, a ball, Bagnaskiz and
   the attack look running, reach the exit (or starve), check that the level still ticks and its
   sprites animate during the 1.1 s delay and that the overlay opens right after it, then compare
   the dog (position, velocity, state, timers), its AnimatedSprite2D animation/frame/progress and
   squash, every critter's position and AnimatedSprite2D frame/progress, the rule stats, exit time
   and hunger, the scene clocks, the map dirt (SHA-256), fresh timers and health, the camera (node
   position, model origin, shake), the attack director, the attack look's values and the banner
   clock, the HUD clock and the exit-ring pulse before and after 30 manual ticks and presentation
   passes plus 12 real frames with the scene ticking on its own physics callback, under the snap,
   under the result card and under GAME OVER; the overlays' own clocks advance meanwhile; confirm
   still skips the snap and the reveal; CONTINUE, RETRY and QUIT TO TITLE still emit. Mutation
   check (session script, the scene restored byte-for-byte): without the world disable, without the
   `tick()` guard and without the `_process()` guard, both cases fail.
2. **Strengthened named cases** (`tests/unit/test_threats.gd`; the former combined
   `test_GZ_042_045_…` is replaced by four cases that keep all its source-run checks):
   - `test_GZ_031_032_cat_idle_flee_startle_and_leave`: a BARK pressed through the input and
     resolved by `GreenZoneThreats.update` startles the cat 2 tiles ahead (in the ×1.3 cone; hop),
     while one 2 tiles behind and one ahead beyond the ×1.3 range are only alerted by distance (flee,
     no hop); the source predicate is checked on the fixture's cat-range cone samples; a catch pays 5
     coins and 250 once, removes the cat, and 30 more ticks pay nothing.
   - `test_GZ_042_bagnaskiz_targets_green_and_trails_like_source`: every sampled position and state
     of Bagnaskiz in the source threats run (green targeting) and the zone health (trail) equal the
     source; directly, his first roam step stamps `TRAIL_STRENGTH × (1 − 0.55 (d/TRAIL_RADIUS)²)` on
     the tile under him and picks a target within 6 tiles of the dog.
   - `test_GZ_043_bump_hunger_hurt_knockback_and_cooldown`: a touching roaming Bagnaskiz costs
     exactly BUMP_HUNGER (6), hurt 0.35 s without control, knockback 6 tiles/s straight away from
     him; held against the dog, the second bump comes BUMP_COOLDOWN (1.2 s) later and costs another
     6; no bump effect while invulnerable or leaving by the exit; the port run's single bump is on
     the source run's tick.
   - `test_GZ_044_bark_cone_travel_delay_and_ordered_hits`: the source cone predicate on the
     fixture's pug-range samples; BARK through the input queues nothing for Bagnaskiz behind the
     dog or ahead beyond 2.8 tiles (no hit ever lands); ahead at 2 tiles each hit lands after the
     wave's travel time `d / WAVE_SPEED` (the computed tick, not before), with a knockback away from
     the dog; hit counts 1, 2, 3 in order with states stunned, stunned, flee; three bark hits counted.
   - `test_GZ_045_flee_awards_flee_score_exactly_once`: the third hit raises the rules score by
     exactly FLEE_SCORE (400) with one "BYE PUG!" award and one flee event; barks at the fleeing pug
     (in cone and range) queue nothing and award nothing until he has left the stage; the source
     run's one flee award carries FLEE_SCORE.
   Mutation check (session script, `systems/green_zone_threats.gd` restored byte-for-byte): a 180°
   cat cone fails GZ-031/032; a 180° pug cone fails GZ-044; a halved wave speed fails GZ-044 (and the
   source-run cases); BUMP_HUNGER − 1 fails GZ-043 (and DOG-005b and the run cases); bumps during the
   exit fail GZ-043; a flee award on every hit after the second fails GZ-045 (and the run cases); a
   caught cat left on stage fails GZ-031/032 (and the run cases).
3. **Documentation.** FEATURE_MATRIX: the current host and export evidence names this tree and
   these counts; `21ce8a2` stays the last architect-accepted M1/M2 baseline. M3 report 25 is kept as
   historical; correction report 24's supersession note now says it no longer gates prototype
   development and that the M1 manual checks remain unpassed and release-blocking.

Prototype presentation debt, unchanged and planned for M8 (not addressed here): D-17 (Supervillained
logo halving resize and blurred halo), D-18 (siren fade-out), D-19 (glitch/sepia look compared side
by side), plus the HUD frozen under the terminal overlays (above).

### Commands executed and results

| Command | Exit | Result |
|---|---|---|
| `git clone --branch claude/gallant-keller-rbvtvy <session clone> <fresh dir>`; `npm ci`; `npx playwright install chromium` | 0 / 0 / 0 | fresh clone of the verification commit; `godot/` tree as above |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (deterministic asset check) | 0 | asset check OK: 207 outputs identical (73 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12); build_resources check (all): OK, 55 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | 0 | 0 ERROR/WARNING lines; `git status --porcelain` afterwards empty: yes |
| `… --script res://tests/test_runner.gd -- --suite all` (full suite) | 0 | 161 passed, 0 failed, 161 total (87.8 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_threats` (focused M3) | 0 | 13 passed, 0 failed, 13 total (2.7 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_green_zone_m3` (focused M3) | 0 | 7 passed, 0 failed, 7 total (8.0 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_green_zone_m3 --case AUTO_001`, twice (deterministic AUTO-001) | 0 / 0 | identical lines: yes — `complete after 60.1 s: treats 26, poops 6, pees 7, marks 1, coins 5, bark hits 3, lives 2, score 2820, health 0.9560, stars 3.5, total 6360` |
| `… -- --suite integration --file test_green_zone_m3 --case terminal_freeze` (focused terminal freeze) | 0 | 2 passed, 0 failed, 2 total (1.8 s), Godot 4.7.2-stable (official) |
| `<console exe> --headless --path godot --quit-after 600` (600-frame Main launch) | 0 | 0 ERROR/WARNING lines |
| `… -- --suite integration --file test_export_pack` (hermetic PCK smoke) | 0 | 1 passed, 0 failed, 1 total (16.5 s): PCK 32,959,440 bytes, 264 runtime resources loaded from the pack, 531 packed files, 18 source-only paths unresolved (the control with the checkout resolved 18) |
| `npm test` (PixiJS) | 0 | Tests  248 passed (248) |
| `npm run build` (PixiJS) | 0 | built in 312ms |
| `git status --porcelain` after the checks (clean status) | 0 | empty |
| `git diff --check 95b69c0 HEAD`; `git show --check --format= HEAD` | 0 / 0 | no output |
| `bash godot/tools/source_tree_guard.sh` | 0 | source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265 |
| `git diff --stat 95b69c0 HEAD -- src public assets android ios package.json package-lock.json` | 0 | empty (PixiJS untouched) |
| `git status --porcelain` after all steps | 0 | empty |

These ran on the fresh clone of the verification commit. The final commit (the same `godot/` tree plus
`docs/porting/`) is checked with `git show --check`, `git status` and the source-tree guard right after
committing; those results are reported with the commit, not recorded here.

Not run: Linux; Android (no APK of the game, no device or emulator run); any manual check (M1/M2
deferred; MAN-GZ); listening to the audio; the M2 rendered presentation probe and the capture suite
(not needed for this correction; the M3 screenshots are M3 report 25's).

### Remaining manual gaps

- MAN-GZ: no healthy, polluted or game-over run by a person on desktop or a portrait phone; no check
  of both hand layouts or the safe area on hardware; no background/resume during the warning, the
  attack or the result screen on a device.
- The M1 manual checks (363 fields, NOT EXECUTED) and the M2 desktop and touch play checks: deferred
  by the owner for prototype development, not passed, still release-blocking; the M1 package must be
  regenerated against the current tree before an owner review.
- No audio has been listened to (cue mapping, loops and ducking are checked by request counts only).
- Visual review of the M3 presentation (critter art, attack look, Supervillained snap, freeze).

### Development attempts (kept as found)

- The first GZ-044 run failed its knockback checks: the open spot chosen for the dog had scenery 2
  tiles ahead, so Bagnaskiz's knockback was blocked (the knockback velocity was set, the solver
  stopped him). The facing cases now pick the first tile with a clear corridor (3 tiles behind to
  4.5 ahead, 0.8 to either side).
- The first freeze snapshot did not include the HUD clock or the exit-ring pulse, so removing the
  `_process()` guard went unnoticed by the mutation check; both were added and the check repeated
  (all three mutations caught).

---

## Historical — M3 report 25: playable Green Zone 1.0 prototype and core arcade flow; M1/M2 manual checks owner-deferred (`be6f9dd`; M1 Partial, M2 Partial, M3 Partial)

> Corrected by correction report 26: the level now freezes under the Supervillained snap, the result card and game over; the GZ-032 and GZ-042–045 cases were strengthened (the combined `test_GZ_042_045_…` named below was replaced by four cases); the current tree and counts are correction report 26's.

Scope: the owner's M3 instruction after `d2f1c02`: implement M3 (the complete Green Zone 1.0 and the
core arcade flow) as a functional prototype on the accepted M1/M2 foundations, in one implementation
commit. Changed: the Godot project (`godot/`, list below), this log, FEATURE_MATRIX.md and five
prototype screenshots in `docs/porting/captures/m3_green_zone_prototype/`. The PixiJS source, root
`android/`, `ios/` and every file outside `godot/` and `docs/porting/` are unchanged. No story
content was implemented; M4 persistence was not started (the only save remains the M2 level record,
SAV-004).

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (manual checks owner-deferred: not passed, not cancelled, not release-approved); **M3 Partial**: every required gameplay system is implemented and playable; 21 M3 acceptance IDs claimed by full suite cases (GZ-001, GZ-016, GZ-017, GZ-031, GZ-032, GZ-034–045, DOG-005b, FLOW-003, FLOW-004, AUTO-001), pending architect review; UI-001–006 and FLOW-005 partial; MAN-GZ not executed |
| Base | `d2f1c02` (correction report 24; `godot/` tree `21ce8a2`) |
| Current `godot/` tree | `b93d332aa607d56c7ef465617688afba3ab0d57a`; verified on a fresh Windows clone of the local verification commit `0d1fe18` (the same `godot/` tree; this commit adds only `docs/porting/`) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090, OpenGL 3.3 Compatibility renderer, 60 Hz display; Linux not run |
| Android | not run (no device or emulator claim for the game) |

### Owner decision: prototype execution mode

The owner is not skipping M1 or M2: their automated implementation and the 98 accepted IDs remain
valid. The remaining M1/M2 manual checks are **explicitly deferred for prototype development**; they
are not passed, not cancelled and not release-approved. The M1 manual-review station is no longer
extended and no further evidence-tool hardening is done unless it blocks development. Its committed
package (`docs/porting/manual_evidence/m1-godot-tree-2ffca5f/`) is bound to a content fingerprint
over files this report changed (`autoload/audio_service.gd`, `scenes/green_zone/green_zone_scene.gd`):
the station would set those decisions aside as stale, so the package must be regenerated before any
later owner review. The story is an unfinished draft: no campaign prose or final story content is
implemented here; the handoff after 1.0 is data only.

### M3 systems: completed, partial, missing

Completed (playable, automated cases):
1. **Hunger and lives** (M2 port, unchanged): idle/walk/run drain, starvation life loss with refill
   to 50, hurt and 2 s invulnerability, game over at 0 lives; Green Zone-only speed for lives.
2. **Digestion and poop** (M2 port): treat digestion and overflow, the 3 s warning, postponement while
   busy, automatic poop, surface footprints, spread, cleaning and fade.
3. **Bladder and pee** (M2 port): charges, empty feedback, regeneration, puddle/fountain refill with
   the drink cooldown, expanding cleaning; **marking**: bonus once per object (GZ-016/017 cases new).
4. **Scoring and environmental health**: treat, cat (250), first mark (150), poop clean (100), flee
   (400), time and star components; half stars; pees < poops final penalty; result data
   `{score, stars, time, bonuses, total}`; the record stays the M2 SAV-004 save (no M4 persistence).
5. **Cats and coins** (new): spawn timers and spots ahead of the dog, idle → flee steering on the
   shared GridKinematicSolver, bark startle (0.8 s hop), catch (5 coins, 250), leave after 16 s with a
   1.2 s fade; meow then the cash 0.35 s later.
6. **Magnet balls and fetch** (new): the source pull curve, escape by running, forced fetch (2 s, no
   control, hunger 8, +5 s), DOG-005b overlap rules.
7. **Pollution waves**: three route-progress waves, once each, seeded placement, radius, strength,
   one cue; the one shared threat RNG is now drawn exactly in the source order by cat and ball
   timers, spots and tints, the waves, Bagnaskiz's spawn and his green targets (D-03 resolved).
8. **Under Attack** (new): health and scripted (progress 0.56) triggers, 25 s cooldown, intensity,
   flee + hysteresis end; banner (big title 2.6 s, reminder with the bark or pee hint, ZONE SAVED!),
   alarm, the siren loop after 3.9 s at 0.45, music duck 0.45, siren off on pause / back on resume,
   saved cue on the end; the sepia/scanline/glitch look.
9. **Bagnaskiz** (new): spawn 7–9 tiles away, green-target selection (14 samples, clean tiles within
   1.6), pollution trail, bump (knockback 6, hurt 0.35 s, hunger 6, 1.2 s cooldown), delayed bark
   hits inside the cone, stun, three-hit flee with FLEE_SCORE and fade-out.
10. **Complete flow**: briefing → play; pause / resume / restart; RESTART and RETRY replay at once with
    the glitch transition (source Flow.restart: no briefing); level end after the "You've been
    supervillained" snap (logo, flash, shake, sparks; skip after 0.45 s); game over → RETRY / QUIT;
    CONTINUE emits `campaign_handoff` with `CampaignHandoff.from_result()` =
    `{from: "1.0", to: "1.1", result, time, coins}`, received by `Main.campaign`
    (`CampaignHandoff.Receiver`, a stub that only records it; the briefing then stands in for the
    title). QUIT/TITLE return to the briefing until the title exists (M4).
11. **UI and controls**: the M2 HUD (stats, half stars, hunger, score, timer, lives, energy ring on
    RUN, MENU) plus radar dots for cats, balls and a blinking Bagnaskiz, the magnet rings, the attack
    banner; the existing keyboard/controller/touch paths and both handed layouts; the logical viewport
    stays inside the display safe area (M2 VIEW-003). The interface was not redesigned.

Partial: UI-001–006 (no device safe-area or hand-layout check on hardware), FLOW-005 (the 1.1
receiver is a stub), GZ-033 (no single full case), MAN-GZ (no human run). Missing: nothing among
the required gameplay systems; story content, the title scene and M4 persistence are out of scope.

New or changed files (`godot/`): `systems/threat_logic.gd` (bark cone, magnet curve, flee steering,
AttackDirector), `systems/green_zone_threats.gd` (full threats), `entities/critters/critter_controllers.gd`
(cat, ball and Bagnaskiz controllers), `entities/critters/critter_view.gd`, `ui/hud/attack_banner.gd`,
`scenes/overlays/supervillained_overlay.gd`, `fx/glitch.gdshader`, `fx/glitch_rect.gd`,
`fx/glitch_transition.gd`, `campaign/campaign_handoff.gd`, `scenes/green_zone/green_zone_scene.gd`
+ `.tscn` (wiring, cues, attack look, magnet rings, radar, flow), `main/main.gd` (transition,
restart/title/handoff), `scenes/overlays/level_end_overlay.gd` (CONTINUE, star cues),
`autoload/audio_service.gd` (looping effects: `loop`, `stop_loop`, `stop_all_loops`),
`core/game_config.gd` (CAT, BALL, ATTACK, BAGNASKIZ, SUPERVILLAINED), `assets/branding/supervillained_logo.png`
(copied by the extractor from `assets/starting-page-images/`, manifest updated),
`ui/title/title_portrait.gdshader` (comment: shared with the logo), `tools/source_extract/extract.mjs`
(logo copy, config groups, `threat_logic`, `threats_run` and `rules_fetch` fixtures),
`tools/capture_suite.gd` (M3 shots), `README.md`, tests (below). No world, movement, camera,
collision, animation, input, asset-pipeline or save foundation was rewritten.

### Deviations (new or changed)

| ID | Deviation | Planned |
|---|---|---|
| D-03 | **Resolved**: the shared threat RNG is drawn by cats, balls, waves and Bagnaskiz in the source order (fixture equality) | — |
| D-08 | **Partly resolved**: the Supervillained snap, the glitch transition and the CONTINUE handoff (stub receiver) exist; TITLE/QUIT still return to the briefing | M4 (title), M5 (1.1) |
| D-10 | **Resolved**: cats, coins, magnet balls, Bagnaskiz and Under Attack are ported | — |
| D-16 | The source steers fleeing cats and Bagnaskiz with unseeded `Math.random`; the port uses a second seeded critter RNG (seed ^ 0x2545f491), drawn once per open direction in the source order; the extractor used the same generator for the fixtures | — |
| D-17 | Supervillained logo: smooth (linear) sampling + the 110 alpha cut, like the title portrait, instead of the source's step-halving canvas resize; the halo is not blurred | M8 |
| D-18 | `stop_loop` stops the siren at once (the source fades it out over about 0.4 s) | M8 |
| D-19 | The glitch/sepia look is a screen-space shader over the world (attack) or the whole stage (transition); colours follow the source shader, but the look was not compared side by side | M8 |
| D-07, D-09 | Unchanged (text-only popups, no particles or thought sprite; gestures/switcher) | M8; M5 |

### Tests added or changed

New: `tests/unit/test_threats.gd` (10 cases: `test_SLICE_bark_cone_and_magnet_curve_match_source`,
`test_GZ_038_041_…`, `test_GZ_001_…`, `test_SLICE_threats_run_trace_matches_source`, `test_GZ_037_…`,
`test_GZ_042_045_…`, `test_DOG_005b_…`, `test_GZ_031_032_…`, `test_GZ_034_036_…`, `test_GZ_016_017_…`)
and `tests/integration/test_green_zone_m3.gd` (5: `test_AUTO_001_…`, `test_SLICE_auto_run_is_reproducible`,
`test_SLICE_threat_events_reach_source_cues`, `test_P_UI_001_…`, `test_FLOW_004_…`);
`tests/integration/test_main_and_rates.gd` gains `test_FLOW_003_restart_from_dirty_run_is_clean_and_keeps_settings`
and `test_P_FLOW_005_starvation_game_over_retry_and_continue_handoff`. Fixtures: `threat_logic`
(80 bark-cone samples, the magnet curve, a 4200-tick director script), `threats_run` (a 4800-tick
scripted Rules + Threats run: a cat caught, a ball fetched, three waves, the scripted attack, a bump,
three hits, the flee, the attack end) and `rules_fetch` (DOG-005b), all executed from the audited
TypeScript; the existing fixture entries are byte-identical apart from the five added config groups.
Changed: `test_SLICE_real_input_run_reaches_exit` (the snap precedes the result card); the two
`test_P_DOG_008a_main_restart…` cases (RESTART now replays at once after the glitch midpoint, like the
source: no briefing, Green Zone music, run clock started); `test_AST_018` (the logo is a runtime
copy) and `test_AST_010`'s linear-sampling list (the logo joins the title portrait);
`tests/automation/green_zone_driver.gd` (M3 behaviours, below).

AUTO-001 driver: InputService movement, RUN, PEE and BARK only; no teleports, no rule or threat
calls. It barks Bagnaskiz away (approach, face, bark in the cone), chases one cat at a run, walks
into the first ball (forced fetch) and runs clear of later ones, pees on its poops, marks one tree,
heals the zone after an attack, refills once at water and otherwise follows the exit distance field
with detours to treats ahead.

**AUTO-001 run (seed 20240501):** `complete after 60.1 s: treats 26, poops 6, pees 7, marks 1, coins 5, bark hits 3, lives 2, score 2820, health 0.9560, stars 3.5, total 6360` — events: 26 treats, 6 poops (all 6 cleaned by pee), 1 first mark, 2 cats spawned and 1 caught, 1 ball spawned and fetched, 3 pollution waves, 1 attack started and ended, 3 barks and 3 hits, Bagnaskiz fled, 2 drinks; the exit reached with 2 lives; the Supervillained snap, the result card (CONTINUE / RETRY) and the CONTINUE handoff `{from 1.0, to 1.1, time 60.1 s, coins 5}` followed. The same line twice on the fresh clone and in `test_SLICE_auto_run_is_reproducible`.

Restart from a dirty run (FLOW-003, through Main and the pause menu): after 32 s of real-input play
plus the dog placed past the scripted attack point (cats/balls, poops, waves, Bagnaskiz and the
siren live), RESTART gives no threats, no pollution, no poops, three waves pending, a calm director
with no cooldown, 30 treats, fresh stats with the lives setting, Green Zone music, no siren, and the
non-default settings (volume 0.5, 4 lives, left hand, RUN toggle) intact. Starvation/game over
(FLOW-005 partial): an idle dog starves through both lives (refill 50, 2 s invulnerability, hurt),
GAME OVER follows with no record, RETRY plays a clean run at once.

### Commands executed and results

| Command | Exit | Result |
|---|---|---|
| `git clone --branch claude/gallant-keller-rbvtvy <session clone> <fresh dir>`; `npm ci`; `npx playwright install chromium` | 0 / 0 / 0 | fresh clone of the verification commit; `godot/` tree as above |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (deterministic asset check) | 0 | asset check OK: 207 outputs identical (73 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12); build_resources check (all): OK, 55 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | 0 | 0 ERROR/WARNING lines; `git status --porcelain` afterwards empty: yes |
| `… --script res://tests/test_runner.gd -- --suite all` (full suite) | 0 | 156 passed, 0 failed, 156 total (86.0 s), Godot 4.7.2-stable (official) |
| `… -- --suite unit --file test_threats` (focused M3) | 0 | 10 passed, 0 failed, 10 total (2.1 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_green_zone_m3` (focused M3) | 0 | 5 passed, 0 failed, 5 total (6.5 s), Godot 4.7.2-stable (official) |
| `… -- --suite integration --file test_green_zone_m3 --case AUTO_001`, twice (deterministic AUTO-001) | 0 / 0 | identical lines: yes — `complete after 60.1 s: treats 26, poops 6, pees 7, marks 1, coins 5, bark hits 3, lives 2, score 2820, health 0.9560, stars 3.5, total 6360` |
| `<console exe> --headless --path godot --quit-after 600` (600-frame Main launch) | 0 | 0 ERROR/WARNING lines |
| `… -- --suite integration --file test_export_pack` (hermetic PCK smoke) | 0 | 1 passed, 0 failed, 1 total (16.6 s), Godot 4.7.2-stable (official) |
| `npm test` (PixiJS) | 0 | Tests  248 passed (248) |
| `npm run build` (PixiJS) | 0 | built in 318ms |
| `git status --porcelain` after the checks | 0 | empty |
| `git diff --check 95b69c0 HEAD`; `git show --check --format= HEAD` | 0 / 0 | no output |
| `bash godot/tools/source_tree_guard.sh` | 0 | source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265 |
| `git diff --stat 95b69c0 HEAD -- src public assets android ios package.json package-lock.json` | 0 | empty (PixiJS untouched) |
| `git status --porcelain` after all steps | 0 | empty |

Screenshots (`docs/porting/captures/m3_green_zone_prototype/`, windowed Compatibility renderer,
432×864, from `tools/capture_suite.gd --mode run`, the same driver): `20_green_zone_full_hud.png`
(play with the full HUD), `21_cat_or_ball.png` (a fleeing cat), `22_attack_bagnaskiz.png` (Under
Attack banner and look, Bagnaskiz and his trail), `23_supervillained.png` (the end-of-level snap),
`14_level_end_final.png` (result card with CONTINUE / RETRY). The run that produced them ended
complete with total 6360 at 60.7 s. A first capture run missed the attack shot (its trigger waited
until Bagnaskiz was within 5 tiles after the big title; the driver had already barked him away); the
trigger was changed to 1.2 s into the attack and the run repeated.

Not run: Linux; Android (no APK of the game, no device or emulator run); any manual check (M1/M2
deferred; MAN-GZ); the M2 rendered presentation probe (`tools/rendered_presentation_probe.gd`): no
camera or interpolation file changed, but its RESTART record was written for the instant M2 restart
and RESTART now plays the glitch transition first, so that record would need its wait adjusted; it
was not rerun or changed (evidence-tool hardening is out of scope unless it blocks development). The
M1 review station was not run.

### Remaining prototype limitations

- No human has played this build; balance, feel, visuals and audio are unreviewed (MAN-GZ).
- Touch, both hands and the safe area were exercised only in the logical viewport in tests; no
  phone run.
- The glitch/sepia look, the logo halo and the siren fade differ in detail from the source (D-17 to D-19).
- Popups are text-only; no particles or thought-bubble sprite (D-07); gestures/switcher not wired (D-09).
- TITLE/QUIT and the stub handoff return to the briefing; there is no title scene or story (M4/M5).
- The M1 manual package is stale against this tree and must be regenerated before an owner review.

### Development attempts (kept as found)

- The first extractor run stopped at a JavaScript syntax error (an apostrophe in the new copy
  entry's description) before writing anything; fixed and rerun.
- The first marking test chose a tree with another tree next to it, so the pee marked the
  neighbour; the test now picks an isolated tree.
- The first FLOW-005 test read the refill values inside the life-lost signal, which the rules emit
  before refilling (as the source does); it now reads them after the tick.
- A driver variable typed from a Variant failed GDScript's warnings-as-errors parse, and the word
  "placeholder" in two comments tripped AST-017's no-procedural-art scan; both fixed.
- The first capture run missed the attack shot (above).

---

## Historical — correction report 24: crash-safe M1 owner evidence and corrected scope claims (`d2f1c02`; M1 Partial, M2 Partial)

> Superseded by M3 report 25: the owner deferred the M1/M2 manual checks for prototype development, so this report's "the owner is not asked to review until … independent review" no longer gates prototype development; the M1 manual checks remain unpassed and release-blocking, and its package is stale against tree `b93d332` (see M3 report 25).

Scope: the architect's correction 24 after `9ca2ec5`: make the M1 owner evidence crash-safe and
correct the remaining scope claims, in one commit of review-tool, evidence and documentation
changes. Changed: `godot/tools/m1_review.gd`, `godot/README.md` (review section), this log,
FEATURE_MATRIX.md, the regenerated package `docs/porting/manual_evidence/m1-godot-tree-2ffca5f/`,
marked wording corrections in the evidence reports of trees `4ac0aed`, `11330ef` and `c9de0e5`, and
the host logs `docs/porting/windows_evidence/m1-review-godot-tree-21ce8a2/`. No shipping gameplay,
asset, `AudioService`, save, touch-control, Android or PixiJS file changed (`AudioService` and the
Green Zone scene script are only read and fingerprinted). All 363 human fields are NOT EXECUTED. The
owner is not asked to review until this correction passes independent review; M2 manual validation
and M3 are not started.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); every automated M1 and M2 acceptance ID is satisfied; the M1 manual checks are prepared and **not executed**; the M2 desktop and touch play checks are open |
| Base | `9ca2ec5` (correction report 23; `godot/` tree `c9de0e5`) |
| Current `godot/` tree | `21ce8a2d6e4fca5a578a3bc6931ece48309573c0` = `c9de0e5` with `tools/m1_review.gd` and `README.md` changed; every runtime, test and asset file identical to `2ffca5f`'s; verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47), OpenGL 3.3 Compatibility renderer, 60 Hz display; GUI and audio output available; Linux not rerun |
| Android | not rerun (no device claim); the accepted M1 spike evidence is correction report 17's, on emulators `sv_m1_api36` (`emulator-5554`, Android 16 / API 36), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34) and `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24); no physical device |

### Manual decisions received

**None.** No owner decision has been requested or returned: all 363 fields of
`manual_evidence/m1-godot-tree-2ffca5f/M1_MANUAL_CHECKLIST.md` are NOT EXECUTED and the final
decision is NOT DECIDED. Nothing here is a visual or audio PASS; inventories, hashes, the content
fingerprint and review contract, contact sheets, stills, screen captures and the station's self-test
are supporting facts only. The self-test's decision files exist only in its scratch folder (not
committed).

### Corrections (architect's items 1-7)

1. **Crash-safe format (decisions schema 4).** The current/previous rotation is replaced by immutable
   generation pairs `m1_owner_decisions.<save ID>.md` and `.json` (save ID
   `g<6-digit generation>-<date and time>-<engine microseconds>`; the JSON copy records the save ID,
   the generation and the Markdown copy's SHA-256). A save (1) writes the Markdown copy, (2) writes
   the JSON copy, reads both back and verifies them as a pair, (3) writes the new pointer as
   `m1_owner_decisions.active.json.new` and verifies it, (4) renames it onto
   `m1_owner_decisions.active.json`, the one small pointer that selects the active pair (with both
   files' SHA-256), and (5) prunes every generation file except the new pair and the previously
   active pair. A failure before step 4 completes removes the new files and leaves or puts back the
   earlier pointer (NOT SAVED in red). **Atomicity, as verified in Godot 4.7.2's source:** on Linux
   and Android `DirAccess.rename` is one `rename()` call, so step 4 is atomic; on Windows it deletes
   the existing pointer and then calls `MoveFileW` (`drivers/windows/dir_access_windows.cpp`), so
   step 4 has a midpoint with no pointer. The station does not depend on step 4 being atomic: the
   loader treats "no pointer and a valid `.active.json.new`" as that midpoint and resumes the pair it
   names, and the self-test reproduces that exact state. On start the pointed pair is resumed when
   its two files carry the pointer's SHA-256 values and the schema, review contract and content
   fingerprint match (these digests and the save-ID row are read with CRLF line ends as LF, because a
   Windows git checkout of `docs/` converts committed copies to CRLF; a self-test check converts the
   pointer and a pair and resumes it); otherwise the newest complete matching pair in the folder is
   recovered, whatever its files are named, and the message says which pair and why. Halves under the
   correction-23 names (`m1_owner_decisions.json` / `.md`, `.previous.*`, `.json.new` / `.md.new`)
   are paired by the save ID they carry, never by their names. Stale decisions (another schema,
   contract or content) are set aside as `.stale-<time>` files with the pointer that selects them;
   incomplete or unpaired files are left as found (and generation-named ones are pruned by a later
   save).
2. **Crash-state tests after every step.** The self-test stops a real save after each step, as if
   the station had stopped there with nothing undone, then restarts the loader: after step 1 (new
   Markdown copy only), after step 2 (new pair, old pointer) and after step 3 (old pointer, new
   `.new`) the earlier pair resumes; at the Windows midpoint of step 4 (no pointer, new `.new`; the
   self-test deletes the old pointer as Godot's Windows rename does first), after step 4 and after
   the first pruning deletion the new pair resumes. Each time nothing is set aside, the earlier pair
   is still on disk, and the next save succeeds and leaves only the pointer, the resumed pair and the
   new pair. Damage cases: a torn newest JSON copy with no pointer and a changed Markdown copy of the
   pointed pair recover the previous complete pair; a torn pointer and a torn `.new` with no pointer
   recover the newest complete pair. **The exact correction-23 failure state** (`m1_owner_decisions.md`
   = save A, `m1_owner_decisions.previous.json` = save A, `m1_owner_decisions.json` missing,
   `m1_owner_decisions.previous.md` older or missing), built with a save A that matches this station:
   save A resumes in both variants, nothing is set aside, and the next save adds a generation pair
   and the pointer without touching the old files. The same split state written by the real
   correction-23 station (schema 3, its fingerprint and contract) is of another schema and station,
   so it is set aside with the reason "schema 3" and never resumed; the unpaired older Markdown copy
   is left as found. Handled failures: folders in the way of the new Markdown copy, the new JSON copy
   and the new pointer (real write failures) and two injected pointer-switch failures (one after the
   old pointer was deleted, which the undo puts back) each leave the pointer byte-identical and the
   earlier pair resuming.
3. **Source-use scope.** The station's source uses are now described everywhere as selected
   representative source variants for M1 cue review, not an exhaustive event-sequencing matrix: the
   constant `SOURCE_USES_SCOPE` (code comments, the review contract, `audio_inventory.json`
   `source_uses_scope`, the checklist's section B), `godot/README.md` and the package README name what
   is not played separately (for example star's delayed marking call and its rate steps, click's
   story-minigame volumes and rates, the cat cash's 0.35 s delay, bark's random rate).
4. **Call site fingerprinted.** `res://scenes/green_zone/green_zone_scene.gd`, the only implemented
   call site the source-use parity check reads, is now one of the fingerprinted files (89). Self-test:
   replacing its digest with the SHA-256 of a modified copy changes the fingerprint (the contract is
   unchanged) and makes the saved pair be set aside, not resumed; undoing it restores the fingerprint.
5. **Evidence wording.** The evidence reports of trees `4ac0aed`, `11330ef` and `c9de0e5` now say
   "The M2 rendered probe was not rerun because no shipping/runtime camera, interpolation or
   presentation file changed.", each with a marked correction note (the review tools did change); the
   logs are unchanged. This report and the new evidence report use the same sentence. The historical
   log sections keep their submitted text.
6. **Package and evidence regenerated** on the verification clone; every human decision is
   NOT EXECUTED. Fingerprint `879ed918e744755b29468d703f45405d20f114e7641d113d180db161603ad3c5`, review contract `28f1ec911e3c9f5ce429e8ec3bdfa051134abd93e3001732c2a33aa1bd3bcda6`.
7. **Checks rerun** (below).

Mutation check of the self-test (session script, not committed; the tool restored byte-for-byte after
each run): ignoring the `.new` pointer when the pointer is missing, accepting a Markdown copy whose
SHA-256 does not match, pruning the previously active pair, not scanning the correction-23 names, not
fingerprinting the Green Zone call site, not putting the pointer back after a failed switch, digests
that read CRLF line ends as they are, and setting aside incomplete files like stale ones each made
`--selftest` exit 1, each with its own check among the failures (the Windows-midpoint crash check,
the changed-Markdown damage check, the pruning check, the legacy split-pair check, the call-site
binding check, the pointer-switch failure check, the line-ends check and the torn-JSON damage check).

### Commands executed and results

| Command | Result |
|---|---|
| Fresh `git clone` of the commit with the tool changes (local `d9b90aa`, `core.autocrlf=true`; tested `godot/` tree `21ce8a2d6e4fca5a578a3bc6931ece48309573c0` = `git rev-parse HEAD:godot` of this commit; only docs and the evidence folders were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import`; `git status --porcelain` | exit 0, no ERROR/WARNING line; status empty |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **139 passed, 0 failed, 139 total** |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,906,024 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18; no `tools/` file packed |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty (HEAD: `d9b90aa`, folded into this commit with the same `godot/` tree) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --name-status 9ca2ec5 HEAD -- godot` | `M godot/README.md`, `M godot/tools/m1_review.gd` |
| `<console exe> --path godot --rendering-driver opengl3 --quit-after 6000 res://tools/m1_review.tscn -- --export <dir>` (`--quit-after` only as a safety net; the tool quits itself) | exit 0: `M1REVIEW {"artifact_problems":[],"artifacts_expected":26,"checks":25,…,"failed":[],"fields":363,"ok":true,"write_errors":[]}`; content fingerprint `879ed918e744755b29468d703f45405d20f114e7641d113d180db161603ad3c5`, review contract `28f1ec911e3c9f5ce429e8ec3bdfa051134abd93e3001732c2a33aa1bd3bcda6`; layout checks and captures at 1320 x 900 and 1280 x 720 as in correction report 23; contact sheets, stills, `animation_inventory.json` and `title_facts.json` byte-identical to correction report 23's |
| the same with `--export <a regular file>` (failure control) | **exit 1 (expected)**: `"ok":false`, write error "cannot create the folder … (the path exists and is not a folder)" |
| the same into a folder holding a file named `contact_sheets` (failure control) | **exit 1 (expected)**: `"ok":false`, one write error, the 12 contact sheets reported missing, the other 14 files verified |
| `… --quit-after 8000 res://tools/m1_review.tscn -- --selftest <dir>` | exit 0: `M1SELFTEST {"checks":74,…,"failed":[],…,"ok":true,…,"schema_version":4}`, including the six stopped-save states, four damage cases, the line-ends case, two legacy split pairs and the schema-3 split pair; seven ERROR records from the six expected save-failure checks, announced in the log |
| `<console exe> --path godot --rendering-driver opengl3 --script res://tools/title_capture.gd -- --out <dir>` | exit 0; portraits on frames 0, 49 and 98; the three images byte-identical to the export's `title_stills/` (`728ff267…`, `95840694…`, `c0f46e0f…`) |
| `… --quit-after 600 res://tools/m1_review.tscn -- --decisions <empty dir>` | exit 0, engine banner only; no decisions folder created (nothing decided) |
| the same with a correction-23 pair split across its names (schema 3: `.previous.json` and `m1_owner_decisions.md`) in the folder | exit 0; both halves renamed to `m1_owner_decisions.stale-<time>.*`; nothing resumed or saved |
| `git status --porcelain` after all steps | empty |
| `git diff --cached --check 9ca2ec5` (this commit, staged) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 97 checks` |

Evidence: `docs/porting/windows_evidence/m1-review-godot-tree-21ce8a2/` (REPORT.md, every step's log,
`exit_codes.txt`, the self-test result) and the package above. Not run: Linux; Android; any manual
check. The M2 rendered probe was not rerun because no shipping/runtime camera, interpolation or
presentation file changed.

Host evidence: current tree `21ce8a2` above (139 passed). Previous Windows trees: `c9de0e5`
(correction report 23, 139 passed), `11330ef` (correction report 22, 139 passed), `4ac0aed` (progress
report 21, 139 passed), `2ffca5f` (correction report 19, 139 passed), `366eb3b` (correction report 18,
139 passed), `51ad8b3` (correction report 17, 138 passed), `591e2df` (correction report 16, 138
passed), `cd87171` (correction report 15, 138 passed), `ef6c318` (progress report 14, 138 passed),
`9bbe179` (correction report 12, 138 passed), `a06b1df` (correction report 11, 138 passed), `1532143`
(correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595` (correction
report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum, corrections 8 to 13, progress report 14, correction reports 15 to 19,
progress report 21, correction reports 22 and 23 and this report.

### Development attempts (kept as found)

- A sudden shutdown of the host interrupted the first attempt at this correction before anything was
  changed (the clone was clean at `9ca2ec5`); the work was restarted from scratch.
- The first self-test run of the new code stopped at a GDScript parse error (a two-line condition
  without a line continuation); the scene then ran without its script until `--quit-after` ended it.
  Fixed; a small session script now lists such lines before a run (none left).
- The first passing run (73 of 73) showed that the Windows-midpoint crash check would also pass
  without the loader's `.new` branch, because the folder scan finds the same pair; each crash check
  now also asserts how the pair was selected, and the mutation check confirms it.
- **First verification clone (tree `28f2435`, local commit `63b0542`), superseded:** every step had its
  expected exit code (suite 139 passed, export ok, both failure controls exit 1, self-test 73 of 73,
  title images identical), but step p2 set aside only the JSON half of the correction-23 split pair:
  its Markdown half, written by PowerShell (its Save ID row ends in CRLF), was not recognised (the
  save-ID pattern expected LF) and was left as found. Because a Windows git checkout of `docs/`
  converts committed copies to CRLF, the station now reads CRLF as LF for the save-ID row and for
  every decisions digest, a self-test check converts a pair and its pointer to CRLF and resumes it
  (74 checks), and the mutation check gained the matching mutation. The whole verification was
  repeated on a new clone of tree `21ce8a2` (local commit `d9b90aa`); its logs are the committed
  ones. The first clone's logs were kept in the session's scratch folder, not committed.
- The first redaction of the verification logs left one local scratch path in `station_selftest.json`:
  the self-test cuts a failure message to 160 characters, which cut the path before the part the
  session normalizer matched. The normalizer now also matches such cut-short paths; the logs were
  regenerated and rescanned (no user path or personal data).
- A first, malformed session mutation script failed to parse before running anything, so it never
  touched the tool file; the rewritten script ran the mutations (seven, then eight after the line-end
  change), and the tool file's SHA-256 was the same before and after them.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, accepted by the architect on review of
   `8f8dcb6`.** The throwaway native migration plugin under `/godot/platform/android/` read the five
   legacy keys of a controlled same-package/same-signature lineage on three emulators. The
   native-bridge versus staged-Capacitor decision stands: `native_bridge_viable_for_controlled_lineage`
   (controlled lineage, emulators, test key; not a production approval).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the accepted M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key, accepted by the architect on review of `8f8dcb6`; physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Independent review of this correction**, then the owner's decisions for the M1 manual checks
  (package README, "Owner: running the review"): the animation review (192 cells and A-FILTER), the
  listening review on a computer with speakers or headphones (160 fields including the siren's
  attack event and the effects' second source uses, B-MUTE, B-VOLUME), the title review (8 fields
  including C-MEMORY) and the sign-off (name, date, equipment). A FAIL is recorded with exact
  reproduction steps and stops the M1 sign-off; nothing is repaired in the evidence commit.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 23: M1 review station hardened before owner use (second pass); owner decisions not yet requested (`9ca2ec5`; M1 Partial, M2 Partial)

> Historical record of `9ca2ec5`, superseded by correction report 24 (text below kept as
> submitted). **Supersession:** its split current/previous rotation could lose a complete save when the
> station stopped between two renames; correction report 24 replaced it with immutable generation
> pairs selected by one pointer (decisions schema 4), recovery of the newest complete pair under any
> file names, crash-state tests after every save step, the Green Zone call site in the fingerprint and
> the source-use scope statement. Its evidence reports' rendered probe sentence was corrected ("The M2
> rendered probe was not rerun because no shipping/runtime camera, interpolation or presentation file
> changed."). Its current tree `c9de0e5` is superseded by `21ce8a2` (runtime files identical). No owner
> decision was returned; the owner is asked only after the independent review of correction report 24.

Scope: the architect's correction 23 after `6dc585a`: final hardening of the M1 owner-review station,
in one commit of review-tool, evidence and documentation corrections. Changed:
`godot/tools/m1_review.gd`, `godot/README.md` (review section), this log, FEATURE_MATRIX.md, the
regenerated package `docs/porting/manual_evidence/m1-godot-tree-2ffca5f/`, a marked wording
correction in `docs/porting/windows_evidence/m1-review-godot-tree-11330ef/REPORT.md` and the host
logs `docs/porting/windows_evidence/m1-review-godot-tree-c9de0e5/`. No shipping gameplay, asset,
`AudioService`, save, touch-control, Android or PixiJS file changed (`AudioService` is only read and
fingerprinted). Every human decision is NOT EXECUTED. The owner is not asked to review until this
correction passes independent review; M2 manual validation and M3 are not started.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); every automated M1 and M2 acceptance ID is satisfied; the M1 manual checks are prepared and **not executed**; the M2 desktop and touch play checks are open |
| Base | `6dc585a` (correction report 22; `godot/` tree `11330ef`) |
| Current `godot/` tree | `c9de0e5e662edd739f3969d40bbf0c97ee2a2323` = `11330ef` with `tools/m1_review.gd` and `README.md` changed; every runtime, test and asset file identical to `2ffca5f`'s; verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47), OpenGL 3.3 Compatibility renderer, 60 Hz display; GUI and audio output available; Linux not rerun |
| Android | not rerun (no device claim); the accepted M1 spike evidence is correction report 17's, on emulators `sv_m1_api36` (`emulator-5554`, Android 16 / API 36), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34) and `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24); no physical device |

### Manual decisions received

**None.** No owner decision has been requested or returned: all 363 fields of
`manual_evidence/m1-godot-tree-2ffca5f/M1_MANUAL_CHECKLIST.md` are NOT EXECUTED and the final
decision is NOT DECIDED. Nothing here is a visual or audio PASS; inventories, hashes, the content
fingerprint and review contract, contact sheets, stills, screen captures and the station's self-test
are supporting facts only. The self-test's decision files exist only in its scratch folder (not
committed).

### Corrections (architect's items 1-8)

1. **Transactional owner evidence.** `_save()` now commits `m1_owner_decisions.json` and `.md` as one
   transaction (`_commit_pair`): (1, 2) both copies are written as `.json.new` / `.md.new` and read
   back byte for byte, (3) the pair is verified (the JSON parses and both carry the same new save
   ID), (4) the current pair is kept as `m1_owner_decisions.previous.json` / `.md`, (5) the new pair
   is renamed into place. Any failure runs `_rollback`: the promoted new copies are removed, the kept
   earlier pair is renamed back, the new files that were not promoted are removed, and the status
   line and sign-off summary show NOT SAVED in red (with "ROLLBACK INCOMPLETE" if an undo step itself
   failed). On start a pair is resumed only when its schema, review contract and content fingerprint
   match and its two copies carry the same save ID; a pair whose copies disagree (a save stopped
   between its renames) is set aside and the `.previous` pair is resumed; leftover `.new` files are
   never read and are removed by the next save. Self-test (scratch folder): with an earlier valid pair
   A on disk, a JSON-first failure (a folder named `m1_owner_decisions.json.new` in the way), a
   Markdown-second failure (a folder named `m1_owner_decisions.md.new`, after the new JSON copy was
   written) and two promotion failures (the Markdown rename after the JSON rename, and the JSON
   rename; injected by the self-test because a real rename failure between two successful renames
   cannot be provoked deterministically) each leave A byte-identical, no `.new` or `.previous` file,
   NOT SAVED in red, and A (not the new pair) is what resumes; the following successful save keeps A
   byte-identical as `.previous`; a pair with mismatched save IDs is set aside and A resumed from
   `.previous`; leftover `.new` files are not resumed and are replaced. The real-obstacle failures
   from correction 22 stay: the folder cannot be created, and (now a real promotion failure) a folder
   named `m1_owner_decisions.json` blocks the rename; neither leaves a new file.
2. **Decision binding.** Decisions schema 3. The content fingerprint now also covers
   `tools/m1_review.gd`, `tools/m1_review.tscn` and `autoload/audio_service.gd` (88 files) and ends with
   the line `review-contract <SHA-256>`: the canonical review contract (JSON with sorted keys) of
   `GameConfig.Audio`'s constants, the project settings `audio/buses/default_bus_layout`,
   `audio/driver/mix_rate`, `display/window/stretch/mode` and
   `rendering/textures/canvas_textures/default_texture_filter`, `AudioService`'s music/effect/synth
   tables, restarting tracks, live leading-silence offsets, same-cue gap and pool size, every item's
   bus, start and source uses with effective gains, the siren event, the stop-loop constants, the safe
   volume, the duration tolerance, the title widths, the window sizes and the 363 field IDs. Saved
   files carry `review_contract_sha256` as well; a file whose contract differs is set aside with the
   reason "made under another review contract". Self-test: moving `AudioService`'s splash start offset
   by 0.001 s (a live playback parameter) and changing the splash game-path volume from 0.7 to 0.71
   (a source use) each change the contract and the fingerprint and make a saved pair be set aside, not
   resumed; undoing the change restores both values. A file with the right fingerprint but another
   contract digest, and files of schema 1 (progress report 21) and schema 2 (correction report 22),
   are set aside. Fingerprint of this package: `67cf406c4fb70150c2cf1739c9845dd9e017dbb6b105f20727e757d005551d4d`; review contract `2fa10012e6a4d500548bca84f9debfe6df9cc9583a3d1f3409c67e0039a06404`.
3. **Splash playback.** Enter plays an effect with its source use's volume and rate. Splash: the Green
   Zone use `play('splash', {volume: 0.7})` (effective gain 0.9 x 0.7 = 0.63), and **V** plays the
   story boat use `play('splash', {volume: 0.5})` (0.45; not in the port yet). The same table gives V
   for the other `gameAudio.ts` variants: coin (poopCleaned, volume 0.5, rate 1.5), warning
   (pollutionSurge, 0.75, 0.82) and empty (tired, rate 0.8); bark's random source rate (0.95-1.05) is
   documented and played at 1.0. `audio_inventory.json` records every item's `uses` (volume, rate,
   effective gain, source call, the port's call) and `enter_gain`; the checklist lists them. The export
   checks the gains and that every use the port has equals its call in
   `scenes/green_zone/green_zone_scene.gd`; the self-test plays each use through the station's
   controls and reads the volume and pitch of `AudioService`'s own player (splash -4.013 dB and
   -6.936 dB at pitch 1.0; coin's V at pitch 1.5).
4. **Title-tab layout.** Every tab scrolls inside the window (title and sign-off tabs whole, the
   animation and audio tabs' right-hand panels) and the status line wraps instead of widening the
   window, so it stays at the bottom. The title tab is compacted: the facts and memory report sit
   beside the portrait strip, so at 1320 x 900 it fits without scrolling. The supported minimum is
   1280 x 720 (the window's minimum size). The export and the self-test check at both sizes that the
   status line lies inside the window on all four tabs and that each of the 61 interactive controls
   can be scrolled wholly into view, naming the title tab's eight decisions (C-MEMORY included) and
   its notes. Captures regenerated at 1320 x 900, plus `tab_4_title_1280x720_end.png`.
5. **Siren loop check.** The "still looping 30 s later" check (state stepped by 30 s) is replaced by
   a real wrap test: the looping siren is played from 0.3 s before its end and sampled every frame
   for up to 1.5 s of real time; it must wrap to its loop start in mixer time and keep playing (on
   the verification clone: started at 3.1746 s of 3.4746 s, wrapped after 0.317 s of real time, at
   0.608 s when sampling ended after 0.901 s). The structural check is now named as such ("a private
   copy … has looping on …"), and the other state-machine checks say the time they step.
6. **Evidence wording.** `windows_evidence/m1-review-godot-tree-11330ef/REPORT.md` step n4 now says
   three ERROR records from the two expected save-failure checks, with a marked correction note; the
   logs are unchanged. This correction's self-test prints seven ERROR records from its six expected
   save-failure checks (one each, plus the engine's "Could not create directory" in the
   folder-creation check), announced in the log.
7. **Package and evidence regenerated** on the verification clone; every human decision is
   NOT EXECUTED.
8. **Checks rerun** (below).

Mutation check of the self-test (session script, not committed; the tool restored byte-for-byte after
each run): a rollback that does not put the earlier pair back, a rollback that leaves the new files,
not comparing the Markdown copy's save ID on resume, leaving the review contract out of the
fingerprint, playing the splash game path at volume 1.0 (correction 22's behaviour), tabs that do not
scroll, and a siren copy that does not loop each made `--selftest` exit 1, each with its own check
among the failures (respectively the promotion-failure checks, the Markdown-second and promotion
checks, the mismatched-save-ID check, both binding checks, the splash, coin, warning and empty
source-use checks, the 1280 x 720 layout check, and the real-playback wrap check with the structural
and fade checks).

### Commands executed and results

| Command | Result |
|---|---|
| Fresh `git clone` of the commit with the tool changes (local `eb0a372`, `core.autocrlf=true`; tested `godot/` tree `c9de0e5e662edd739f3969d40bbf0c97ee2a2323` = `git rev-parse HEAD:godot` of this commit; only docs and the evidence folders were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import`; `git status --porcelain` | exit 0, no ERROR/WARNING line; status empty |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **139 passed, 0 failed, 139 total** |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,906,024 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18; no `tools/` file packed |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty (HEAD: `eb0a372`, folded into this commit with the same `godot/` tree) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --name-status 6dc585a HEAD -- godot` | `M godot/README.md`, `M godot/tools/m1_review.gd` |
| `<console exe> --path godot --rendering-driver opengl3 --quit-after 6000 res://tools/m1_review.tscn -- --export <dir>` (`--quit-after` only as a safety net; the tool quits itself) | exit 0: `M1REVIEW {"artifact_problems":[],"artifacts_expected":26,"checks":25,…,"failed":[],"fields":363,"ok":true,"write_errors":[]}`; content fingerprint `67cf406c4fb70150c2cf1739c9845dd9e017dbb6b105f20727e757d005551d4d`, review contract `2fa10012e6a4d500548bca84f9debfe6df9cc9583a3d1f3409c67e0039a06404`; the captures at 1320 x 900 and the title tab's end at 1280 x 720; both layout checks: status line inside the window on every tab, 61 of 61 controls reachable, the title's 8 decisions and notes named; contact sheets, stills, `animation_inventory.json` and `title_facts.json` byte-identical to correction report 22's |
| the same with `--export <a regular file>` (failure control) | **exit 1 (expected)**: `"ok":false`, write error "cannot create the folder … (the path exists and is not a folder)" |
| the same into a folder holding a file named `contact_sheets` (failure control) | **exit 1 (expected)**: `"ok":false`, one write error, the 12 contact sheets reported missing, the other 14 files verified |
| `… res://tools/m1_review.tscn -- --selftest <dir>` | exit 0: `M1SELFTEST {"checks":59,…,"failed":[],…,"ok":true,…,"schema_version":3}`; seven ERROR records from the six expected save-failure checks, announced in the log |
| `<console exe> --path godot --rendering-driver opengl3 --script res://tools/title_capture.gd -- --out <dir>` | exit 0; portraits on frames 0, 49 and 98; the three images byte-identical to the export's `title_stills/` (`728ff267…`, `95840694…`, `c0f46e0f…`) |
| `… --quit-after 600 res://tools/m1_review.tscn -- --decisions <empty dir>` | exit 0, engine banner only; no decisions folder created (nothing decided) |
| the same with a correction-22 decisions pair (schema 2) in the folder | exit 0; both files were renamed to `m1_owner_decisions.stale-<time>.json` / `.md`; nothing resumed or saved |
| `git status --porcelain` after all steps | empty |
| `git diff --cached --check 6dc585a` (this commit, staged) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 94 checks` |

Evidence: `docs/porting/windows_evidence/m1-review-godot-tree-c9de0e5/` (REPORT.md, every step's log,
`exit_codes.txt`, the self-test result) and the package above. Not run: Linux; Android; the rendered
probe (no rendering, camera, interpolation or presentation change); any manual check.

Host evidence: current tree `c9de0e5` above (139 passed). Previous Windows trees: `11330ef`
(correction report 22, 139 passed), `4ac0aed` (progress report 21, 139 passed), `2ffca5f` (correction
report 19, 139 passed), `366eb3b` (correction report 18, 139 passed), `51ad8b3` (correction report 17,
138 passed), `591e2df` (correction report 16, 138 passed), `cd87171` (correction report 15, 138
passed), `ef6c318` (progress report 14, 138 passed), `9bbe179` (correction report 12, 138 passed),
`a06b1df` (correction report 11, 138 passed), `1532143` (correction report 10, 137 passed), `6a3c53b`
(correction report 9, 137 passed), `b1c3595` (correction report 8, 137 passed), `b8535ab` (correction
report 7 addendum, 137 passed), `81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction
report 6, 134 passed). Linux: the prior tree `d12bedd`, 128 passed (progress report 5). Correction 6
was not rerun on Linux, and neither were correction 7's addendum, corrections 8 to 13, progress
report 14, correction reports 15 to 19, progress report 21, correction report 22 and this report.

### Development attempts (kept as found)

- The first working-clone runs of the corrected station (self-test 59 of 59, export 25 checks and 26
  files) passed. Its screen captures showed that effects without a second source use repeated their
  expected use and source in a "source use 'default'" line; that line was shortened, and the audio-tab
  capture now shows the splash instead of the first track. The next working-clone self-test (59 of 59)
  and the verification clone gave the same results.
- The seven mutation runs above were made in the working clone; the tool file was restored from a byte
  copy after each and then committed unchanged as the verification commit.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, accepted by the architect on review of
   `8f8dcb6`.** The throwaway native migration plugin under `/godot/platform/android/` read the five
   legacy keys of a controlled same-package/same-signature lineage on three emulators. The
   native-bridge versus staged-Capacitor decision stands: `native_bridge_viable_for_controlled_lineage`
   (controlled lineage, emulators, test key; not a production approval).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the accepted M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key, accepted by the architect on review of `8f8dcb6`; physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Independent review of this correction**, then the owner's decisions for the M1 manual checks
  (package README, "Owner: running the review"): the animation review (192 cells and A-FILTER), the
  listening review on a computer with speakers or headphones (160 fields including the siren's
  attack event and the effects' second source uses, B-MUTE, B-VOLUME), the title review (8 fields
  including C-MEMORY) and the sign-off (name, date, equipment). A FAIL is recorded with exact
  reproduction steps and stops the M1 sign-off; nothing is repaired in the evidence commit.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 22: M1 review package hardened before owner use; owner decisions not yet requested (`6dc585a`; M1 Partial, M2 Partial)

> Historical record of `6dc585a`, superseded by correction report 23 (text below kept as
> submitted). **Supersession:** the review station was hardened again before the owner used it:
> transactional owner evidence (both copies written, verified and promoted together; the earlier pair
> kept and put back on failure), decisions schema 3 bound to a review contract and to the station's
> own code, the splash game path at the source's 0.7 with the story boat's 0.5 on [V], scrolling tabs
> with layout checks at 1280 x 720, and a real siren loop-wrap test. Its evidence report's step-n4
> wording was corrected (three ERROR records from two checks). Its current tree `11330ef` is
> superseded by `c9de0e5` (runtime files identical). No owner decision was returned; the owner is
> asked only after the independent review of correction report 23.

Scope: the architect's correction 22 after `10eec20`: harden the M1 manual-review package before the
owner uses it, in one commit of development-tool, capture, evidence and documentation corrections.
Changed: `godot/tools/m1_review.gd`, `godot/tools/title_capture.gd`, `godot/README.md` (review and
capture sections), this log, FEATURE_MATRIX.md, the regenerated package
`docs/porting/manual_evidence/m1-godot-tree-2ffca5f/`, the regenerated
`docs/porting/captures/title_m1/title_frame_00_widths_88_99_124.png` and the host logs
`docs/porting/windows_evidence/m1-review-godot-tree-11330ef/`. No shipping gameplay, asset,
`AudioService`, save, touch-control, Android or PixiJS file changed. The owner is not asked to review
until this correction is independently reviewed; M2 manual validation and M3 are not started.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); every automated M1 and M2 acceptance ID is satisfied; the M1 manual checks are prepared and **not executed**; the M2 desktop and touch play checks are open |
| Base | `10eec20` (progress report 21; `godot/` tree `4ac0aed`) |
| Current `godot/` tree | `11330efbb1ba17ca3569bc0b112fe4993321093b` = `4ac0aed` with `tools/m1_review.gd`, `tools/title_capture.gd` and `README.md` changed; every runtime, test and asset file identical to `2ffca5f`'s; verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47), OpenGL 3.3 Compatibility renderer, 60 Hz display; GUI and audio output available; Linux not rerun |
| Android | not rerun (no device claim); the accepted M1 spike evidence is correction report 17's, on emulators `sv_m1_api36` (`emulator-5554`, Android 16 / API 36), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34) and `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24); no physical device |

### Manual decisions received

**None.** No owner decision has been requested or returned: all 363 fields of
`manual_evidence/m1-godot-tree-2ffca5f/M1_MANUAL_CHECKLIST.md` are NOT EXECUTED and the final
decision is NOT DECIDED. Nothing here is a visual or audio PASS; inventories, hashes, the content
fingerprint, contact sheets, stills, screen captures and the station's self-test are supporting facts
only. The self-test's APPROVED file exists only in its scratch folder (not committed).

### Corrections (architect's items 1-9)

1. **Export and save failures are authoritative.** Every folder creation is checked with
   `DirAccess.dir_exists_absolute`, every text write checks `FileAccess.open`, `store_string` and
   `get_error` and reads the file back, and every PNG save checks `save_png` and loads the image back.
   After writing, `--export` verifies that each of the 25 expected files exists, is nonempty and parses
   (JSON object, PNG image, checklist heading), writes the result into `selftest.json` and verifies
   that file too; any failed check, write or file prints `M1REVIEW {..."ok":false...}` and exits 1.
   Interactive saves return a result: a failure shows "NOT SAVED: <reason>" in red on the status line
   and the sign-off summary, never "saved". Two reproducible failure controls exit 1: the export
   target is a file (step n2), and a file blocks `contact_sheets/` (step n3: one write error and the
   12 sheets reported missing).
2. **Siren review.** The siren has a review-only attack-event mode ([E]): the alarm through
   `AudioService.play` at once, then, after `GameConfig.Audio.SIREN_DELAY` (3.9 s) of station audio
   time, a private copy of `siren.mp3` on the SFX bus at `SFX_VOLUME x FILE_GAIN.siren x SIREN_VOLUME`
   (0.9 x 0.6 x 0.45 = 0.243) from the trimmed start (`AudioService.offsets.siren`, 0.0 s), looping
   from there to the end until Stop, which fades it like the source's `stopLoop()` (time constant
   0.08 s, stopped after 0.4 s); Stop during the delay means it never starts. The station labels it
   against the generic one-shot game path (Enter, `AudioService.play`, the story fire's use). The
   shipping `AudioService` is unchanged: the loop flag is set only on the station's own copy. The
   export checks the configuration against the source literals; the self-test checks the states (the
   alarm request, the delay frozen in the background, the loop, pause and resume, the fade, Stop
   during the delay, the one-shot path leaving the shared resource unlooped).
3. **Laser text.** Expected use: "Bagnaskiz's laser eyes hit Zampanò and knock him back." Source:
   `SOUND_FILES.laser (laser-eyes.mp3)`, event `bump` (`src/systems/threats.ts`: Bagnaskiz runs into
   Zampanò, who is knocked back and hurt). Inventories and checklist regenerated.
4. **Title coverage.** Tab 3 shows the memory report (99 frames of 125 x 168 px, 8,316,000 bytes
   uncompressed, 69.3 % of the < 12 MB limit counted as 12,000,000 bytes like
   `test_AST_010_title_conversion`; one atlas page 2000 x 1176, lossless import, no mipmaps) and the new
   human field **C-MEMORY** (fields 362 -> 363). `tools/title_capture.gd` now waits until every
   portrait is ready before setting a frame and exits 1 if a portrait is not on the requested frame
   or an image cannot be saved. Its images of frames 0, 49 and 98 are byte-identical to the station's
   stills (step o2); `captures/title_m1/title_frame_00…` was regenerated from that run and is now
   rendered frame 0 (SHA-256 `728ff267…615f`); `…_49` and `…_98` are unchanged.
5. **Decisions bound to the reviewed content.** Saved decisions carry `schema_version` 2 and
   `content_fingerprint`: SHA-256 of the sorted "<res path> <file SHA-256>" lines of 85 files (the
   profile, both costume SpriteFrames, their sheet JSONs, every atlas page they use, the 32 audio
   files, the leading-silence and bus-layout resources, the title SpriteFrames, JSON, atlas page,
   portrait script and shader, and each file's `.import`). `/godot` text files are LF in every checkout
   (`godot/.gitattributes`), so the fingerprint is the same on Windows and Linux. It is shown in tab 4,
   the JSON and the Markdown; a file of another schema (including progress report 21's) or another
   fingerprint is renamed to `m1_owner_decisions.stale-<time>.json/.md`, the reason is shown and every
   field starts NOT EXECUTED; if the rename fails, saving is disabled so the old file is never
   overwritten (that branch is not exercised by the self-test). Fingerprint of this package: `406f37285e283d40a123cbd5135f6430ea85b4f569565d900cf58eef54f24994`.
6. **Attribution before APPROVED.** APPROVED is refused unless every field is PASS and the owner
   name, date and equipment/display are nonblank (whitespace counts as blank); the refusal names what
   is missing, and clearing one later returns the final decision to NOT DECIDED. The date is no longer
   filled in automatically. `--selftest <dir>` drives the station's own code in a scratch folder: save
   and resume, a stale fingerprint, the progress-report-21 file layout, two save failures, approval
   refusal, four missing-attribution cases, acceptance and reversal, the siren event and focus pausing
   (37 checks).
7. **Background pausing.** The raw/seam player and the siren player pause on
   `NOTIFICATION_APPLICATION_FOCUS_OUT` and `NOTIFICATION_APPLICATION_PAUSED`, resume on focus in and
   resume, and start paused if played meanwhile, matching the station's wording; the siren delay does
   not advance meanwhile.
8. **Audio durations.** The check now compares unrounded Godot stream lengths with the source fixture
   durations at <= 0.001 s (previously 0.1 s on rounded values): all 32 hold, largest difference
   0.00049 s.
9. **Package and evidence regenerated** on the verification clone; every human decision is
   NOT EXECUTED.

Mutation check of the self-test (session script, not committed; the tool restored byte-for-byte
after each run): dropping the attribution requirement, not pausing the raw player, ignoring write
errors in `_save`, letting the siren delay advance in the background and skipping the fingerprint
comparison each made `--selftest` exit 1 with the matching checks failed.

### Commands executed and results

| Command | Result |
|---|---|
| Fresh `git clone` of the commit with the tool changes (local `0a57707`, `core.autocrlf=true`; tested `godot/` tree `11330efbb1ba17ca3569bc0b112fe4993321093b` = `git rev-parse HEAD:godot` of this commit; only docs, captures and the evidence folders were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import`; `git status --porcelain` | exit 0, no ERROR/WARNING line; status empty |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **139 passed, 0 failed, 139 total** |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,906,024 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18; no `tools/` file packed |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty (HEAD: `0a57707`, folded into this commit with the same `godot/` tree) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --name-status 10eec20 HEAD -- godot` | `M godot/README.md`, `M godot/tools/m1_review.gd`, `M godot/tools/title_capture.gd` |
| `<console exe> --path godot --rendering-driver opengl3 --quit-after 6000 res://tools/m1_review.tscn -- --export <dir>` (`--quit-after` only as a safety net; the tool quits itself) | exit 0: `M1REVIEW {"artifact_problems":[],"artifacts_expected":25,"checks":21,…,"failed":[],"fields":363,"ok":true,"write_errors":[]}`; content fingerprint `406f37285e283d40a123cbd5135f6430ea85b4f569565d900cf58eef54f24994`; contact sheets, stills and `animation_inventory.json` byte-identical to progress report 21's |
| the same with `--export <a regular file>` (failure control) | **exit 1 (expected)**: `"ok":false`, write error "cannot create the folder … (the path exists and is not a folder)" |
| the same into a folder holding a file named `contact_sheets` (failure control) | **exit 1 (expected)**: `"ok":false`, one write error, the 12 contact sheets reported missing |
| `… res://tools/m1_review.tscn -- --selftest <dir>` | exit 0: `M1SELFTEST {"checks":37,…,"failed":[],"ok":true,"schema_version":2}` |
| `<console exe> --path godot --rendering-driver opengl3 --script res://tools/title_capture.gd -- --out <dir>` | exit 0; portraits on frames 0, 49 and 98; the three images byte-identical to the export's `title_stills/` (`728ff267…`, `95840694…`, `c0f46e0f…`); three earlier runs in the working clone gave the same hashes |
| `… --quit-after 600 res://tools/m1_review.tscn -- --decisions <empty dir>` | exit 0, engine banner only; no decisions folder created (nothing decided) |
| the same with a progress-report-21 decisions file (no schema version) in the folder | exit 0; the file was renamed to `m1_owner_decisions.stale-<time>.json`; nothing resumed or saved |
| `git status --porcelain` after all steps | empty |
| `git diff --cached --check 10eec20` (this commit, staged) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 91 checks` |

Evidence: `docs/porting/windows_evidence/m1-review-godot-tree-11330ef/` (REPORT.md, every step's log,
`exit_codes.txt`, the self-test result) and the package above. Not run: Linux; Android; the rendered
probe (no rendering, camera, interpolation or presentation change); any manual check.

Host evidence: current tree `11330ef` above (139 passed). Previous Windows trees: `4ac0aed`
(progress report 21, 139 passed), `2ffca5f` (correction report 19, 139 passed), `366eb3b` (correction
report 18, 139 passed), `51ad8b3` (correction report 17, 138 passed), `591e2df` (correction report
16, 138 passed), `cd87171` (correction report 15, 138 passed), `ef6c318` (progress report 14, 138
passed), `9bbe179` (correction report 12, 138 passed), `a06b1df` (correction report 11, 138 passed),
`1532143` (correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595`
(correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum, corrections 8 to 13, progress report 14, correction reports 15 to 19,
progress report 21 and this report.

### Development attempts (kept as found)

- The first self-test run in the working clone stopped at a GDScript parse error (a `:=` inferred from
  a Variant comparison in the siren configuration check); the scene then ran without its script and
  was ended by `timeout` after 300 s. The variable is now typed. `--check-only --script` cannot
  compile the scene script (it uses autoloads), so the station's runs use `--quit-after` as a safety
  net.
- The first failure control in the working clone reported the reason as "(OK)", because
  `DirAccess.make_dir_recursive_absolute` returns OK when a file already has the folder's name; the
  message now says "the path exists and is not a folder". The exit code was already 1.
- The first redaction of the step logs left two JSON-escaped local paths (`C:\Users\…`) in the
  failure-control logs; the session normalizer now also handles escaped separators, and the committed
  logs were regenerated and rescanned (no user path or personal data).
- Working-clone runs before the verification commit (self-test 37 of 37; export with 21 checks and
  25 files; both failure controls exit 1; three `title_capture.gd` runs) gave the same results as the
  verification clone.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, accepted by the architect on review of
   `8f8dcb6`.** The throwaway native migration plugin under `/godot/platform/android/` read the five
   legacy keys of a controlled same-package/same-signature lineage on three emulators. The
   native-bridge versus staged-Capacitor decision stands: `native_bridge_viable_for_controlled_lineage`
   (controlled lineage, emulators, test key; not a production approval).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the accepted M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key, accepted by the architect on review of `8f8dcb6`; physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Independent review of this correction**, then the owner's decisions for the M1 manual checks
  (package README, "Owner: running the review"): the animation review (192 cells and A-FILTER), the
  listening review on a computer with speakers or headphones (160 fields including the siren's
  attack event, B-MUTE, B-VOLUME), the title review (8 fields including C-MEMORY) and the sign-off
  (name, date, equipment). A FAIL is recorded with exact reproduction steps and stops the M1
  sign-off; nothing is repaired in the evidence commit.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — progress report 21: M1 manual-validation package; owner decisions requested (`10eec20`; M1 Partial, M2 Partial)

> Historical record of `10eec20`, superseded by correction report 22 (text below kept as
> submitted). **Supersession:** its review package was hardened and regenerated before the owner
> used it: 363 fields (C-MEMORY added), the siren attack event, the corrected laser text, the content
> fingerprint and schema version, attribution before APPROVED, authoritative export and save
> failures, and the 0.001 s audio-duration check. `tools/title_capture.gd` was repaired and
> `captures/title_m1/title_frame_00…` regenerated as rendered frame 0. Its current tree `4ac0aed` is
> superseded by `11330ef` (runtime files identical). No owner decision was returned; the owner is
> asked only after the independent review of correction report 22.

Scope: the architect's instruction after `e0e6052`: prepare and conduct the M1 manual-validation
handoff, in one commit of development-only review tooling, documentation and lightweight captures.
Changed: `godot/tools/m1_review.tscn`, `godot/tools/m1_review.gd` (+ `.gd.uid`), a `godot/README.md`
section, this log, FEATURE_MATRIX.md, the package `docs/porting/manual_evidence/m1-godot-tree-2ffca5f/`
and the host logs `docs/porting/windows_evidence/m1-review-godot-tree-4ac0aed/`. No gameplay, tuning,
camera, movement, save, asset, generated resource, PixiJS, Capacitor or Android production file
changed; `tools/title_capture.gd` and `captures/title_m1/` are unchanged; M2 manual validation and M3
are not started.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); every automated M1 and M2 acceptance ID is satisfied; the M1 manual checks are prepared for the owner and **not executed**; the M2 desktop and touch play checks are open |
| Base | `e0e6052` (correction report 20; `godot/` tree `2ffca5f`) |
| Current `godot/` tree | `4ac0aedb41e2c4e07b8e486f886b98142aeea571` = `2ffca5f` plus the review station (three files under `tools/`) and the README section; every runtime, test and asset file identical; verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47), OpenGL 3.3 Compatibility renderer, 60 Hz display; GUI and audio output available; Linux not rerun |
| Android | not rerun (no device claim); the accepted M1 spike evidence is correction report 17's, on emulators `sv_m1_api36` (`emulator-5554`, Android 16 / API 36), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34) and `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24); no physical device |

### Manual decisions received

**None.** No owner decision has been returned: all 362 fields of
`manual_evidence/m1-godot-tree-2ffca5f/M1_MANUAL_CHECKLIST.md` are NOT EXECUTED and the final
decision is NOT DECIDED. Nothing here is a visual or audio PASS; inventories, hashes, contact sheets,
stills and screen captures are supporting facts only.

### Review station (development only)

The editor previews one SpriteFrames animation at a time without direction, frame number or
authored duration on screen, cannot play a cue through `AudioService` (leading silence, gains, buses,
mute, volume), and the title portrait exists only at run time, so a review scene was added under
`godot/tools/` (excluded from every export preset; the hermetic PCK smoke fails on any packed
`tools/` file and passed). `tools/m1_review.tscn` (script `m1_review.gd`):

1. **Animations:** the profile's two SpriteFrames resources (`zampano_frames.tres` normal;
   `zampanoKnight_frames.tres` armoured, aliased by the cross costume), 12 actions including tired
   x 8 directions, all eight directions at once in a compass, live at the authored frame timing,
   nearest filtering, x3; pause, replay, frame step, previous/next, background; per cell the
   direction, frame number and authored duration, and the resource, animation name, frame list and
   cycle for the item. One decision field per animation and direction (192) plus A-FILTER.
2. **Audio:** 32 sounds in listening order (5 recorded tracks, 12 recorded effects, the generated
   medieval loop, 14 generated cues), each labelled with cue key, resource, provenance, format,
   channels, sample rate, duration, expected use (source event mapping) and game path (bus, gain,
   skipped leading silence); play through `AudioService`, raw file from 0 s, a music track's last
   6 s into its loop; stop, replay, previous/next, mute and master volume from 25 %. Five fields per
   sound (AUDIBLE, INTENT, START, END, CLEAN) with notes, plus B-MUTE and B-VOLUME.
3. **Title:** the portrait at 88/99/124 px (views 192/216/270), x2, live at the authored delays;
   pause, replay, step, first/middle/last. Seven fields (C-CROP, C-ALPHA, C-SCALE, C-FIRST,
   C-MIDDLE, C-LAST, C-TIMING).
4. **Sign-off:** owner name, date, equipment, the environment recorded automatically, and the final
   decision (APPROVED only when all 362 fields are PASS).

Decisions are saved on every change to `<decisions dir>/m1_owner_decisions.json` and `.md` and are
resumed on the next start; nothing is written to the game's save files. `--export <dir>` writes the
machine-readable inventories, the blank checklist, contact sheets, title stills and screen captures
and runs 18 automated self-checks (facts only).

### The package (`docs/porting/manual_evidence/m1-godot-tree-2ffca5f/`)

`README.md` (launch and review commands, environment, contents, automated facts, the title-capture
finding, status per check), `M1_MANUAL_CHECKLIST.md` (blank, 362 fields), `animation_inventory.json`,
`audio_inventory.json`, `title_facts.json`, `selftest.json`, 12 contact sheets (one per action,
normal and armoured side by side), 3 title stills, 3 screen captures of the station and
`title_capture_check/`. 3.4 MB in all; no video or recording.

Automated facts (export self-checks, 18 of 18 hold): each costume resource has exactly the 12
required actions x 8 directions (192 animations, 1,088 frames, every frame a 40 x 40 region); frame
counts, loop flags and authored per-frame durations equal the source sheet JSON; cross and armoured
share the knight resource (AST-006). The listening list is exactly `AudioService`'s 6 tracks, 12
recorded effects and 14 synth cues (5 + 12 recorded, 1 + 14 generated); every file loads, matches the
manifest SHA-256 and the source fixture duration; the 15 generated files are mono 22,050 Hz 16-bit PCM
WAV. Title: 99 frames, delays equal `title_frames.json` (cycle 3.9 s), frame 125 x 168, canonical
width 125, alpha cut 110 (shader 110/255), one atlas page 2000 x 1176, frame memory 8,316,000 bytes
(< 12 MB).

### Title capture rerun on the accepted tree: first image is not frame 0 (recorded, not repaired)

The unchanged `tools/title_capture.gd`, rerun on a fresh clone of `e0e6052` (`2ffca5f`, three runs)
and again on `4ac0aed` (step o), gives middle and last images byte-identical to
`captures/title_m1/title_frame_49…` and `…_98…`, but its first image is rendered frame 1. Rendering all
99 frames in the same layout and matching SHA-256 values (`title_capture_check/identified_captures.txt`)
also shows that the committed `captures/title_m1/title_frame_00_widths_88_99_124.png` (commit
`16b5619`) is rendered frame 3, not frame 0. Cause: as a `--script`, the SceneTree adds the portraits
in `_initialize()` before their `_ready()` runs, so the tool sets frame 0 while the portraits have no
SpriteFrames; `TitlePortrait._ready()` then starts playback at the first `await process_frame` and
the animation advances before the first capture (`trace_title_capture_order.log.txt`). Reproduction:
on `2ffca5f`, `godot --path godot --rendering-driver opengl3 --script res://tools/title_capture.gd --
--out <dir>` and compare `<dir>/title_frame_00_widths_88_99_124.png` with the renders of
`title_capture_check/render_all_frames.gd.txt`. Not repaired here (development tool; no title asset,
extraction setting or runtime file involved): the review station's `title_stills/` hold frames 0, 49
and 98 in the same layout (49 and 98 byte-identical to the committed ones), and the owner judges the
live portrait. A one-line fix (one `await process_frame` before the first frame is set) is left for
the architect.

### Commands executed and results

| Command | Result |
|---|---|
| Fresh `git clone` of the commit adding the station (local `3894186`, `core.autocrlf=true`; tested `godot/` tree `4ac0aedb41e2c4e07b8e486f886b98142aeea571` = `git rev-parse HEAD:godot` of this commit; only docs and the evidence folders were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import`; `git status --porcelain` | exit 0, no ERROR/WARNING line; status empty |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **139 passed, 0 failed, 139 total** |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,906,024 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18; no `tools/` file packed |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty (HEAD: `3894186`, folded into this commit with the same `godot/` tree) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --name-status e0e6052 HEAD -- godot` | `M godot/README.md`, `A godot/tools/m1_review.gd`, `A godot/tools/m1_review.gd.uid`, `A godot/tools/m1_review.tscn` |
| `<console exe> --path godot --rendering-driver opengl3 res://tools/m1_review.tscn -- --export <dir>` | exit 0: `M1REVIEW {"checks":18,"failed":[],"fields":362,"ok":true}`; every file byte-identical to the first fresh-clone run's export (tree `1896a39`, below) except the checklist's removed trailing space and the live title-tab screen capture |
| `<console exe> --path godot --rendering-driver opengl3 --script res://tools/title_capture.gd -- --out <dir>` (on `4ac0aed`; and three times on a fresh clone of `e0e6052`) | exit 0; first image = rendered frame 1, middle and last byte-identical to `captures/title_m1/` |
| `<console exe> --path godot --rendering-driver opengl3 --quit-after 600 res://tools/m1_review.tscn -- --decisions <dir>` | exit 0, engine banner only; no decisions file (nothing decided) |
| `git status --porcelain` after all steps | empty |
| `git diff --cached --check e0e6052` (this commit, staged) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 89 checks` |

Evidence: `docs/porting/windows_evidence/m1-review-godot-tree-4ac0aed/` (REPORT.md, every step's log,
`exit_codes.txt`) and the package above. Not run: Linux; Android; the rendered probe (no rendering,
camera, interpolation or presentation change); any manual check.

Host evidence: current tree `4ac0aed` above (139 passed). Previous Windows trees: `2ffca5f`
(correction report 19, 139 passed), `366eb3b` (correction report 18, 139 passed), `51ad8b3`
(correction report 17, 138 passed), `591e2df` (correction report 16, 138 passed), `cd87171`
(correction report 15, 138 passed), `ef6c318` (progress report 14, 138 passed), `9bbe179`
(correction report 12, 138 passed), `a06b1df` (correction report 11, 138 passed), `1532143`
(correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595`
(correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum, corrections 8 to 13, progress report 14, correction reports 15 to 19 and
this report.

### Development attempts (kept as found)

- The first export in the working clone showed the local decisions path in the status line of the
  screen captures; export mode now shows "export mode: nothing is saved" instead.
- A temporary harness (not committed; output muted) checked that decisions are saved, that APPROVED
  is refused while fields are not PASS, that the next start resumes the saved decisions, and that all
  32 sounds in the three playback modes, the 24 animation items and the title controls run without an
  engine error.
- The title-capture trace (`title_capture_check/trace_title_capture_order.gd.txt`) stopped at its
  null call, which is the evidence that the portraits had no SpriteFrames yet; its process was ended
  by hand.
- The first fresh-clone verification ran on an earlier local commit (`godot/` tree `1896a39`): every
  step passed with the same results, but the exported blank checklist ended its "Title notes:" line
  with a space, which `git diff --check` rejects. The checklist writer now strips it; the whole
  verification was rerun on `4ac0aed` (the logs above) and the earlier tree was not committed.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, accepted by the architect on review of
   `8f8dcb6`.** The throwaway native migration plugin under `/godot/platform/android/` read the five
   legacy keys of a controlled same-package/same-signature lineage on three emulators. The
   native-bridge versus staged-Capacitor decision stands: `native_bridge_viable_for_controlled_lineage`
   (controlled lineage, emulators, test key; not a production approval).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the accepted M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key, accepted by the architect on review of `8f8dcb6`; physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Owner decisions for the M1 manual checks** (package README, "Owner: running the review"): the
  animation review (192 cells and A-FILTER), the listening review on a computer with speakers or
  headphones (160 fields, B-MUTE, B-VOLUME), the title review (7 fields) and the sign-off. A FAIL is
  recorded with exact reproduction steps and stops the M1 sign-off; nothing is repaired in the
  evidence commit.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 20: DOG-008a accepted on combined evidence; every automated M1 and M2 ID satisfied (`e0e6052`; M1 Partial, M2 Partial)

> Historical record of `e0e6052`, superseded by progress report 21 (text below kept as
> submitted). **Supersession:** its decisions and totals stand (98; every automated M1 and M2 ID
> satisfied). Its current tree `2ffca5f` is superseded by `4ac0aed` (the review station added under
> `tools/`, runtime files identical). Its manual M1 checks are prepared in progress report 21 and
> wait for the owner.

Scope: the architect's review of `386184b` (correction report 19), in one documentation-only commit
(`docs/porting/FEATURE_MATRIX.md`, `TEST_PLAN.md` and this log). No gameplay, runtime, test, tool,
asset, evidence, PixiJS, Capacitor or root `android/` file changed; M3 not started. The `godot/` tree
is still `2ffca5ffaf62ff0c55773fd07fd2630c23a6fe3b`, verified on a fresh Windows clone in correction
report 19; no engine, Node or asset command was rerun for this documentation commit.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); every automated M1 and M2 acceptance ID is satisfied; open: the manual M1 checks and the manual M2 desktop and touch play checks |
| Base | `386184b` (correction report 19) |
| Current `godot/` tree | `2ffca5ffaf62ff0c55773fd07fd2630c23a6fe3b`, unchanged; verified on a fresh Windows clone in correction report 19 |
| Host | Windows 11 Pro N for Workstations 25H2; documentation checks only |
| Android | not rerun (no rendered or device claim here); the accepted M1 spike evidence is correction report 17's, on emulators `sv_m1_api36` (`emulator-5554`, Android 16 / API 36), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34) and `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24); no physical device |

### Architect decisions recorded (review of `386184b`)

- **DOG-008a is accepted on combined evidence** for `386184b` / `godot/` tree `2ffca5f`:
  `test_CORE_002_logic_independent_of_render_rate`,
  `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state` and
  `test_P_DOG_008a_restart_canvas_snapped_before_first_draw` plus the renderer-backed probe as run in
  correction report 19 (the focused resets run and the complete probe; the pre-fix
  `CameraRig.snap()` mutation stays the separate RESTART evidence).
- **Accepted totals: 98** = 92 full-suite IDs + 4 combined (ARCH-001a, VIEW-004, CAM-004, DOG-008a)
  + 2 command (AST-019, CORE-001), superseding 97.
- **Every automated M1 and M2 acceptance ID is satisfied.** M1 and M2 stay Partial because their
  manual checks remain open.
- **Probe-reliability notes:** the two probe weaknesses that correction report 19 disclosed from its
  first pre-fix run (the wall-clock step-timing metric failing `motion_30` although every frame sat
  at its predicted position, and the per-tick fractional-camera dither control going undetected at
  120 FPS) are non-blocking false-rejection risks, not evidence failures. Correction report 19's
  notes are kept as submitted; the probe is unchanged.

### Changes

1. **FEATURE_MATRIX.md:**
   - DOG-008a moved from "pending architect acceptance (not counted)" into the combined-evidence
     list, accepted on review of `386184b`, with its suite cases, correction report 19's probe run
     and the separate pre-fix RESTART evidence; combined evidence 3 → **4**;
   - totals: **98 (92 full suite + 4 combined + 2 command)**, superseding 97;
   - the split-ID entry (DOG-008a satisfied on combined evidence) and the automated M2 line (every
     automated M1 and M2 acceptance ID satisfied; M1 and M2 Partial for their manual checks);
   - the probe paragraph names correction report 19's run as the one on which DOG-008a was accepted
     and records the architect's classification of the two probe weaknesses;
   - the Zampanò state controller row: Partial → **Slice** under the Slice legend (its listed M2 IDs
     are satisfied; DOG-005b (M3) and DOG-008b (M5) stay later parts);
   - host verification: the current tree is unchanged by this documentation commit.
2. **TEST_PLAN.md:** the combined-evidence paragraph records DOG-008a as accepted on review of
   `386184b`; the acceptance conditions and the probe requirements are unchanged.
3. **This log:** this report; correction report 19 marked historical with a supersession note (its
   text, including its probe-weakness notes, kept as submitted).

### Acceptance status (M2 IDs on combined evidence)

| ID | Status | Evidence |
|---|---|---|
| ARCH-001a | **accepted** (named static review confirmed on review of `46d7ad9`), combined evidence | suite: `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`; static: the architect's review of `f580fa4` |
| VIEW-004 | **accepted** (architect's review of `9c4cd52`), combined evidence | suite: `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`; renderer: correction report 18 (`366eb3b`), rerun in correction report 19 (`2ffca5f`) |
| CAM-004 | **accepted** (architect's review of `9c4cd52`), combined evidence | suite: whole-pixel camera origin in `test_CAM_002_camera_clamps_small_and_large_maps` and `test_P_VIEW_004_…`; renderer: as VIEW-004 |
| DOG-008a | **accepted** (architect's review of `386184b`), combined evidence | suite: `test_CORE_002_logic_independent_of_render_rate`, `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, `test_P_DOG_008a_restart_canvas_snapped_before_first_draw`; renderer: correction report 19 (`2ffca5f`: the corrected camera-snap control detected at every rate, every positive frame exact; the pre-fix mutation fails the four RESTART records) |

Totals: 98 satisfied (92 full suite + 4 combined: ARCH-001a, VIEW-004, CAM-004, DOG-008a + 2 command:
AST-019, CORE-001). Every automated M1 and M2 acceptance ID is satisfied.

### Commands executed and results (Windows 11)

Documentation checks only; no engine, Node or asset command was run for this commit (the `godot/`
tree is unchanged).

| Command | Result |
|---|---|
| Fresh `git clone` of this commit's documentation (`core.autocrlf=true`; only this results table and the check count were written after it) | exit 0; `git rev-parse HEAD:godot` = `2ffca5ffaf62ff0c55773fd07fd2630c23a6fe3b` (unchanged) |
| `git status --porcelain` (fresh clone, before and after the checks) | empty |
| `git diff --check 386184b HEAD`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, empty (HEAD: the documentation commit before this table was filled in, folded into this commit) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --name-only 386184b HEAD` | `docs/porting/FEATURE_MATRIX.md`, `docs/porting/IMPLEMENTATION_LOG.md`, `docs/porting/TEST_PLAN.md` |
| `git diff --stat 386184b HEAD -- godot src android capacitor.config.ts package.json docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/android_evidence docs/porting/captures docs/porting/MILESTONES.md` | empty: gameplay, runtime code, tests, tools, assets, the PixiJS/Capacitor source and the evidence files unchanged |
| `git diff --check` (working tree, final text) | clean |
| `python docs_consistency_check.py` (session tool, not committed; final text) | `OK: 83 checks` |

Host evidence: current `godot/` tree `2ffca5f` (correction report 19, 139 passed), unchanged by this
documentation commit. Previous Windows trees: `366eb3b` (correction report 18, 139 passed), `51ad8b3`
(correction report 17, 138 passed), `591e2df` (correction report 16, 138 passed), `cd87171`
(correction report 15, 138 passed), `ef6c318` (progress report 14, 138 passed), `9bbe179`
(correction report 12, 138 passed), `a06b1df` (correction report 11, 138 passed), `1532143`
(correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595`
(correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum, corrections 8 to 13, progress report 14 and correction reports 15 to 19.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, accepted by the architect on review of
   `8f8dcb6`.** The throwaway native migration plugin under `/godot/platform/android/` read the five
   legacy keys of a controlled same-package/same-signature lineage on three emulators. The
   native-bridge versus staged-Capacitor decision stands: `native_bridge_viable_for_controlled_lineage`
   (controlled lineage, emulators, test key; not a production approval).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the accepted M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key, accepted by the architect on review of `8f8dcb6`; physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 19: isolated camera-snap interpolation-reset control; DOG-008a pending architect acceptance (`386184b`; M1 Partial, M2 Partial)

> Historical record of `386184b`, superseded by correction report 20 (text below kept as
> submitted). **Supersession:** on review of `386184b` the architect accepted DOG-008a on its combined
> evidence (`godot/` tree `2ffca5f`). Its "pending architect acceptance" status, its total of 97 and
> its "Architect acceptance of DOG-008a" item under "Still required" are superseded; the total is 98.
> Its probe-weakness notes stand: the architect classified both weaknesses as non-blocking
> false-rejection risks, not evidence failures. Its control correction, probe runs and pre-fix
> evidence stand.

Scope: the architect's review of `9c4cd52`, in one focused commit. Changed: the probe's
camera-snap no-reset control (`godot/tools/rendered_presentation_probe_impl.gd`,
`_snap_no_reset()`), TEST_PLAN.md (evidence wording), FEATURE_MATRIX.md, this log and new evidence.
No gameplay, camera tuning, sprite, filtering or movement change; the `CameraRig.snap()` runtime
fix of correction report 18 is unchanged; no PixiJS, Capacitor or root `android/` file changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); every automated M1 acceptance ID is satisfied; every automated M2 ID is satisfied except DOG-008a, pending architect acceptance; open: the manual M1 checks and the manual M2 desktop and touch play checks |
| Base | `9c4cd52` (correction report 18) |
| Current `godot/` tree | `2ffca5ffaf62ff0c55773fd07fd2630c23a6fe3b`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47), OpenGL 3.3 Compatibility renderer, 60 Hz display; Linux not rerun |
| Android | not rerun (no rendered or device claim here); the accepted M1 spike evidence is correction report 17's, on emulators `sv_m1_api36` (`emulator-5554`, Android 16 / API 36), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34) and `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24); no physical device |

### Architect decisions recorded (review of `9c4cd52`)

- **VIEW-004 and CAM-004 are accepted** on correction report 18's combined suite + renderer
  evidence (`godot/` tree `366eb3b`).
- **DOG-008a stays pending architect acceptance:** correction report 18's camera-snap no-reset
  control (`_snap_no_reset()`) updated the model and the rig position but left out
  `force_update_scroll()` as well as the two interpolation resets, so it did not isolate the missing
  reset from the missing viewport push that the RESTART fix added. DOG-008a is not counted until the
  architect accepts it.
- The `CameraRig.snap()` runtime fix stays; its pre-fix mutation remains the distinct evidence that a
  missing `force_update_scroll()` breaks the real Main RESTART frame.

### Changes per review item

1. **Control corrected.** `_snap_no_reset()` now reproduces `CameraRig.snap()` except for the
   interpolation resets: `model.snap_to()`, `CameraRig._apply()` (the rig position), then
   `camera.force_update_scroll()`; only `rig.reset_physics_interpolation()` and
   `camera.reset_physics_interpolation()` are omitted. The probe's history still marks the action
   tick as a reset point (the expected presentation is the snapped view at once).
2. **Two faults, two pieces of evidence.** The missing-reset control runs on the fixed tree
   (`camera_snap_without_reset_<fps>`); the missing `force_update_scroll()` is the separate pre-fix
   mutation of `CameraRig.snap()` (the clone's `camera_rig.gd` reverted to `8f8dcb6`'s blob), which
   fails the four real Main RESTART records (in its rerun, only those; see below).
3. **Focused resets probe first** (`--only=resets`, VSync off): 12 of 12 positive first frames passed (spawn, teleport and camera snap at 30/60/90/120 FPS, each drawn right after its action tick), and `camera_snap_without_reset` was detected at every rate (fractions 0.8852 / 0.8526 / 0.3453 / 0.1752): at 30, 60 and 120 FPS none of the 27 expected markers lay within 4 px of the snapped view and 27, 24 and 27 marker components stood elsewhere (the interpolated old view); at 90 FPS all 27 lay near but off their snapped positions (27 position failures); the dog was 16 / 21 / 93 / 118 px from its expected place; 12 of 12 controls of this section detected.
4. **Complete probe** (VSync off, 30/60/90/120 FPS): The stage check and all 24 measured records passed and 24 of 24 negative controls were detected, with no engine error (motion achieved 29.99 / 60.01 / 90.0 / 120.01 FPS, velocity ratio 1.0–1.0001; camera 30.13 / 60.09 / 90.23 / 119.26 FPS, every marker exact; the real Main RESTART first frame exact at every rate).
5. **Docs.** TEST_PLAN.md: VIEW-004 and CAM-004 accepted, DOG-008a pending with the corrected
   control (acceptance wording unchanged). FEATURE_MATRIX.md: total 97 (DOG-008a not counted), the
   current tree. This log: this report; correction report 18 historical with a supersession note.

### Focused resets probe (`step_o_rendered_probe_resets_vsync_off.txt`)

Environment: NVIDIA GeForce RTX 3090 (NVIDIA), 3.3.0 NVIDIA 610.47, rendering method `gl_compatibility`, driver `opengl3`, VSync mode 0, display 60.0 Hz, Godot 4.7.2.stable (ed1daf0bf), Windows 10.0.26200; physics 60 Hz, interpolation True, snap transforms/vertices True/True, default texture filter 0; Main GameViewport {'canvas_item_default_texture_filter': 0, 'snap_2d_transforms_to_pixel': True, 'snap_2d_vertices_to_pixel': True}.
Stage: 432×240, 60 markers, matches Main's GameViewport: True; dog sheet: 544 frames, 290,464 opaque texels, 0 in the background/marker colours.

| First frame after (stage) | FPS | frame tick − action tick | fraction | dog components / pattern mismatches / position residual | old position: dog pixels | markers (visible / position failures / pattern failures / extra) | result |
|---|---|---|---|---|---|---|---|
| spawn | 30 | 0 | 0.8642 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 30 | 0 | 0.8637 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 30 | 0 | 0.8629 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 60 | 0 | 0.86 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 60 | 0 | 0.8575 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 60 | 0 | 0.8541 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 90 | 0 | 0.1852 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 90 | 0 | 0.1846 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 90 | 0 | 0.3457 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 120 | 0 | 0.2368 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 120 | 0 | 0.2874 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 120 | 0 | 0.1407 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |

| Negative control | Detected | Failed checks (what saw it) |
|---|---|---|
| `stale_copy_after_teleport_30` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_30` | yes | dog_at_new_position |
| `camera_snap_without_reset_30` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_60` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_60` | yes | dog_at_new_position |
| `camera_snap_without_reset_60` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_90` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_90` | yes | dog_at_new_position |
| `camera_snap_without_reset_90` | yes | dog_at_new_position, markers_at_snapped_view |
| `stale_copy_after_teleport_120` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_120` | yes | dog_at_new_position, nothing_at_old_position |
| `camera_snap_without_reset_120` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |

Summary: ok = True; failures: none; engine errors: none; 12 measured records, 12 negative controls, 12 detected.

### Complete probe (`step_q_rendered_probe_vsync_off.txt`)

Environment: NVIDIA GeForce RTX 3090 (NVIDIA), 3.3.0 NVIDIA 610.47, rendering method `gl_compatibility`, driver `opengl3`, VSync mode 0, display 60.0 Hz, Godot 4.7.2.stable (ed1daf0bf), Windows 10.0.26200; physics 60 Hz, interpolation True, snap transforms/vertices True/True, default texture filter 0; Main GameViewport {'canvas_item_default_texture_filter': 0, 'snap_2d_transforms_to_pixel': True, 'snap_2d_vertices_to_pixel': True}.
Stage: 432×240, 60 markers, matches Main's GameViewport: True; dog sheet: 544 frames, 290,464 opaque texels, 0 in the background/marker colours.

| Motion (static camera, frozen `run_e` frame 0) | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| achieved FPS / frames measured | 29.99 / 43 | 60.01 / 85 | 90.0 / 127 | 120.01 / 169 |
| dog components per frame (min–max); component failures | 1–1; 0 | 1–1; 0 | 1–1; 0 | 1–1; 0 |
| area / bbox / pattern mismatches / intensity (reference 489 px, 34×21, 0, 234,147) | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 |
| position vs interpolated physics state (failures; residual px) | 0; 0..0 | 0; 0..0 | 0; 0..0 | 0; 0..0 |
| displacement rendered / logic (error, limit 2 px) | 238 / 237.586 (0.414) | 237 / 237.578 (-0.578) | 237 / 237.585 (-0.585) | 237 / 237.578 (-0.578) |
| fitted / expected px/s (ratio, limit ±3 %) | 169.705 / 169.705 (1.0) | 169.724 / 169.705 (1.0001) | 169.697 / 169.705 (1.0) | 169.711 / 169.705 (1.0) |
| physics ticks/s | 59.99 | 60.0 | 60.0 | 60.0 |
| step RMS vs elapsed time (limit 1 px); held frames (predicted); max step; max excess (limit 2 px) | 0.476; 0 (0); 6; 0.433 | 0.385; 0 (0); 3; 0.289 | 0.323; 0 (0); 2; 0.198 | 0.514; 0 (0); 2; 0.692 |
| result | pass | pass | pass | pass |

| Camera (real CameraRig following the running dog) | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| achieved FPS / frames | 30.13 / 43 | 60.09 / 85 | 90.23 / 127 | 119.26 / 169 |
| marker samples (fully visible markers × frames); missing; extra components | 1,137; 0; 0 | 2,250; 0; 0 | 3,366; 0; 0 | 4,482; 0; 0 |
| absolute position vs interpolated camera: failures; residual x / y px; tie samples | 0; 0..0 / 0..0; 0 | 0; 0..0 / 0..0; 0 | 0; 0..0 / 0..0; 105 | 0; 0..0 / 0..0; 0 |
| common-mode jitter frames; max centroid deviation px | 0; 0.0 | 0; 0.0 | 0; 1.0 | 0; 0.0 |
| pattern / size failures; intensity (reference 24,990) | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 |
| adjacent-marker gaps px (supplemental) | 48 | 48 | 48 | 48 |
| dog: components failures / shape failures / position failures | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| result | pass | pass | pass | pass |

| First frame after (stage) | FPS | frame tick − action tick | fraction | dog components / pattern mismatches / position residual | old position: dog pixels | markers (visible / position failures / pattern failures / extra) | result |
|---|---|---|---|---|---|---|---|
| spawn | 30 | 0 | 0.4703 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 30 | 0 | 0.4698 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 30 | 0 | 0.4688 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 60 | 0 | 0.466 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 60 | 0 | 0.4635 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 60 | 0 | 0.4603 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 90 | 0 | 0.4581 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 90 | 0 | 0.4573 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 90 | 0 | 0.4998 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 120 | 0 | 0.39 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 120 | 0 | 0.4297 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 120 | 0 | 0.4217 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |

| Real Main → Green Zone → pause → RESTART | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| start frame: canvas origin (expected) ; dog bbox ; texel mismatches | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 |
| old run: dog / camera before RESTART | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] |
| replacement added after draw / first frame (seq) | 3434 / 3435 | 3594 / 3595 | 3825 / 3826 | 4128 / 4129 |
| first frame after RESTART: canvas origin (expected) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) |
| camera / dog at (expected spawn) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) |
| dog components; bbox (expected); area (reference); texel mismatches | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 |
| dogs / rigs in tree; redraw px differing from the frame | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 |
| old position (rect, visible px): dog pixels; dog pixels elsewhere | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 |
| failing checks | — | — | — | — |
| result | pass | pass | pass | pass |

| Negative control | Detected | Failed checks (what saw it) |
|---|---|---|
| `ghost_trail_3px` | yes | shape_exact |
| `ghost_trail_1px` | yes | shape_exact |
| `ghost_separate_60px` | yes | shape_exact, single_component |
| `stale_copy_60px` | yes | shape_exact, single_component |
| `interpolation_off_90` | yes | model_position, no_unexpected_holds, step_rms |
| `interpolation_off_120` | yes | model_position, no_unexpected_holds, step_rms |
| `doubled_displacement_30` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_60` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_90` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_120` | yes | displacement, max_step, model_position, step_rms, velocity |
| `fractional_camera_dither_120` | yes | dog_position, marker_pattern_exact, marker_position_exact, no_stale_or_extra_markers |
| `subpixel_camera_linear_120` | yes | dog_shape_exact, dog_single_component, marker_intensity_exact, marker_pattern_exact, marker_position_exact, no_stale_or_extra_markers |
| `stale_copy_after_teleport_30` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_30` | yes | dog_at_new_position |
| `camera_snap_without_reset_30` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_60` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_60` | yes | dog_at_new_position |
| `camera_snap_without_reset_60` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_90` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_90` | yes | dog_at_new_position |
| `camera_snap_without_reset_90` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_120` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_120` | yes | dog_at_new_position |
| `camera_snap_without_reset_120` | yes | dog_at_new_position, marker_pattern_exact, markers_at_snapped_view, no_stale_markers |

Summary: ok = True; failures: none; engine errors: none; 24 measured records, 24 negative controls, 24 detected.

### Pre-fix `CameraRig.snap()` mutation (distinct evidence, steps s–v and its rerun w–z)

The clone's `godot/iso/camera_rig.gd` was reverted to `8f8dcb6`'s blob (`f13dac1…`, `step_s`: `CameraRig.snap()` without `force_update_scroll()`), the focused cases and the complete probe were run, and the file was restored (`step_v`: hash = `HEAD:godot/iso/camera_rig.gd`). `test_P_DOG_008a_restart_canvas_snapped_before_first_draw` failed (`expected (108.0, -1112.0), got (0.0, 0.0)`); the probe exited 1: the four `main_restart` records (30/60/90/120 FPS) failed, plus two failures the mutation cannot cause: `motion_30`'s wall-clock step metric and the per-tick fractional-camera dither control (not detected); every other record passed and every other control, including the corrected `camera_snap_without_reset`, was detected (see the probe weaknesses below). A rerun in the same clone (steps w–z: reverted again, the complete probe, restored, `git status` empty) failed exactly the four `main_restart` records and passed every other record and control. This is the RESTART defect of correction report 18, separate from the missing-reset control (frame `prefix_main_60_first_frame_after_restart.png`, from the rerun). The rerun:

| Real Main → Green Zone → pause → RESTART | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| start frame: canvas origin (expected) ; dog bbox ; texel mismatches | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 |
| old run: dog / camera before RESTART | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] |
| replacement added after draw / first frame (seq) | 3437 / 3438 | 3598 / 3599 | 3828 / 3829 | 4130 / 4131 |
| first frame after RESTART: canvas origin (expected) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) |
| camera / dog at (expected spawn) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) |
| dog components; bbox (expected); area (reference); texel mismatches | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 |
| dogs / rigs in tree; redraw px differing from the frame | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 |
| old position (rect, visible px): dog pixels; dog pixels elsewhere | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 |
| failing checks | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component |
| result | FAIL | FAIL | FAIL | FAIL |

### Commands executed and results

| Command | Result |
|---|---|
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `2ffca5ffaf62ff0c55773fd07fd2630c23a6fe3b` = `git rev-parse HEAD:godot` of this commit; only the docs and the evidence folders were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **139 passed, 0 failed, 139 total** |
| `… --suite all --case DOG_008a` (focused logical restart cases) | exit 0: 2 passed |
| `<console exe> --headless --path godot --quit-after 600` (600-frame desktop launch) | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,906,024 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| `<console exe> --path godot --rendering-driver opengl3 --disable-vsync --script res://tools/rendered_presentation_probe.gd -- --only=resets --out=…` | exit 0: 12 reset records pass; 12 of 12 controls detected, `camera_snap_without_reset` at all four rates |
| the same without `--only` (complete probe) | exit 0: the stage check and 24 measured records pass, 24 of 24 negative controls detected, no engine error |
| pre-fix: `camera_rig.gd` reverted in the clone (`f13dac1…`); `--case DOG_008a`; the complete probe; file restored | exit 1 (1 of 2 failed); exit 1 (the four `main_restart` records (30/60/90/120 FPS) failed, plus two failures the mutation cannot cause: `motion_30`'s wall-clock step metric and the per-tick fractional-camera dither control (not detected); every other record passed and every other control, including the corrected `camera_snap_without_reset`, was detected); restored, hash = `HEAD:godot/iso/camera_rig.gd` |
| pre-fix rerun in the same clone: reverted again; the complete probe; restored; `git status --porcelain` | exit 1: exactly the four `main_restart` records failed; restored, hash = `HEAD:godot/iso/camera_rig.gd`; status empty |
| `… harness/m1_spike_harness_selftest.gd`; `node … m1_spike_tool.mjs selftest` | exit 0: **37 passed, 0 failed**; **6 passed, 0 failed** |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (after the import, after the probes, after all steps); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty (HEAD: the code-only commit `b35d795`, folded into this commit with the same `godot/` tree) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --cached --check 9c4cd52` (this commit's full content, staged) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 82 checks` |

Evidence: `docs/porting/windows_evidence/correction-19-godot-tree-2ffca5f/` (REPORT.md, the logs of every
step, `exit_codes.txt`) and `docs/porting/captures/m2_rendered/godot-tree-2ffca5f/` (14 PNG
frames: the camera-snap and no-reset frames at every rate from the focused run, representative
frames of the complete run, the pre-fix RESTART frame). Correction report 18's evidence folders are
unchanged. The rendered evidence is not a suite result. Not run: Linux; Android; manual play.

Host evidence: current tree above. Previous Windows trees: `366eb3b` (correction report 18, 139
passed), `51ad8b3` (correction report 17, 138 passed), `591e2df` (correction report 16, 138 passed),
`cd87171` (correction report 15, 138 passed), `ef6c318` (progress report 14, 138 passed), `9bbe179`
(correction report 12, 138 passed), `a06b1df` (correction report 11, 138 passed), `1532143`
(correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595`
(correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum, corrections 8 to 13, progress report 14, correction reports 15 to 18 and
this report.

### Acceptance status

| ID | Status | Evidence |
|---|---|---|
| VIEW-004 | **accepted** (architect's review of `9c4cd52`), combined evidence | suite: `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`; renderer: correction report 18 (`366eb3b`), rerun here |
| CAM-004 | **accepted** (architect's review of `9c4cd52`), combined evidence | suite: whole-pixel camera origin in `test_CAM_002_camera_clamps_small_and_large_maps` and `test_P_VIEW_004_…`; renderer: correction report 18 (`366eb3b`), rerun here |
| DOG-008a | **pending architect acceptance** (not counted) | suite: `test_CORE_002_logic_independent_of_render_rate`, `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, `test_P_DOG_008a_restart_canvas_snapped_before_first_draw`; renderer: this report (corrected camera-snap control detected at every rate, every positive frame exact) |

Totals: 97 satisfied (92 full suite + 3 combined: ARCH-001a, VIEW-004, CAM-004 + 2 command:
AST-019, CORE-001); DOG-008a pending architect acceptance.

### Probe weaknesses seen in the first pre-fix run (not changed here)

This correction changes only the camera-snap control, as the review asked. The first pre-fix run
showed two failures that the `CameraRig.snap()` mutation cannot cause; they are weaknesses of the
probe as committed in correction report 18 and can recur in any run:

- **Step-timing metric at 30 FPS.** `motion_30` failed `step_rms` (1.07 px, limit 1 px) and
  `max_step` (excess 4.4 px, limit 2 px) although all 43 frames sat exactly at the positions the
  interpolated physics state predicts and the fitted velocity ratio was 1.0029. These two metrics
  compare steps with wall-clock frame timestamps taken in `frame_post_draw`, so a delayed callback
  (host scheduling or readback) shows as a large step.
- **Fractional-camera dither control.** It was not detected at 120 FPS (0 of 4,476 marker samples
  shifted, 0 jitter frames). The ±0.45 px dither is applied once per physics tick and is
  interpolated like the camera, so at some frame/tick phases it never moves a rendered marker across
  a rounding boundary. It was detected in correction report 18's runs and in this report's complete
  run.

Both would need a probe change for the architect to decide (for example a per-frame ±0.5 px dither,
which always moves one of two consecutive frames off the prediction, and engine-time steps).

### Development attempts (kept as found)

- Working tree, focused resets probe: every positive frame passed and `camera_snap_without_reset`
  was detected at 30/60/90/120 FPS (no marker within 4 px of the snapped view; 24–27 marker
  components elsewhere). Complete probe on the working tree: 24 records passed, 24 of 24 controls
  detected.

### Legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, accepted by the architect on review of
   `8f8dcb6`.** The throwaway native migration plugin under `/godot/platform/android/` read the five
   legacy keys of a controlled same-package/same-signature lineage on three emulators. The
   native-bridge versus staged-Capacitor decision stands: `native_bridge_viable_for_controlled_lineage`
   (controlled lineage, emulators, test key; not a production approval).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the accepted M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key, accepted by the architect on review of `8f8dcb6`; physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Architect acceptance of DOG-008a** (this report's corrected control and reruns).
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 18: renderer-backed presentation probe; VIEW-004, CAM-004 and DOG-008a on combined evidence (`9c4cd52`; M1 Partial, M2 Partial)

> Historical record of `9c4cd52`, superseded by correction report 19 (text below kept as
> submitted). **Supersession:** on review of `9c4cd52` the architect accepted VIEW-004 and CAM-004 on its combined
> evidence. DOG-008a was not accepted: its camera-snap no-reset control (`_snap_no_reset()`) also left out
> `force_update_scroll()`, so it did not isolate the missing interpolation reset. Correction report 19 corrects that
> control and reruns the probe; DOG-008a is pending architect acceptance, and its total of 98 is superseded by 97.
> Its `CameraRig.snap()` RESTART fix and its pre-fix evidence stand.

Scope: the architect's review of `8f8dcb6`, in one focused commit. Changed: the renderer-backed probe
(`godot/tools/rendered_presentation_probe.gd` with `rendered_presentation_probe_impl.gd`, replacing
`tools/interpolation_probe.gd`), one defect fix the probe found (`godot/iso/camera_rig.gd`:
`CameraRig.snap()` pushes the snapped view to the viewport at once), one new partial suite case and
two updated comments (`tests/integration/test_main_and_rates.gd`), `godot/README.md`, TEST_PLAN.md
(evidence wording), FEATURE_MATRIX.md, this log and new evidence. No movement constant, camera
tuning, interpolation setting, sprite art, filtering, collision or gameplay rule changed; no
PixiJS, Capacitor or root `android/` file changed; M3 not started.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); every automated M1 and M2 acceptance ID is satisfied; open: the manual M1 checks and the manual M2 desktop and touch play checks |
| Base | `8f8dcb6` (correction report 17) |
| Current `godot/` tree | `366eb3bca4bfe5e71e2804eac2deb806351fa2eb`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (build 10.0.26200), NVIDIA GeForce RTX 3090 (driver 610.47), OpenGL 3.3 Compatibility renderer, 60 Hz display; Linux not rerun |
| Android | not rerun (no rendered or device claim here); the accepted M1 spike evidence is correction report 17's, on emulators `sv_m1_api36` (`emulator-5554`, Android 16 / API 36), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34) and `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24); no physical device |

### Architect decisions recorded (review of `8f8dcb6`)

- The M1 controlled Android migration spike is **accepted** (decision
  `native_bridge_viable_for_controlled_lineage` for the controlled lineage; not a production
  approval; MIG-001–010 stay open).
- DOG-008a's logical spawn, teleport and camera-snap reset calls and its real Main restart-reset
  subclause are accepted; VIEW-004, CAM-004 and DOG-008a stayed Partial only for their rendered
  clauses. The review set the condition: satisfied on combined suite + renderer evidence only if
  every real measurement and every negative control of a strengthened probe passes.

### Changes per review item

1. **Renderer-backed probe.** `tools/rendered_presentation_probe.gd` (a `SceneTree` launcher;
   the checks are in `rendered_presentation_probe_impl.gd`, loaded once the autoloads exist) runs
   under the real Compatibility renderer, outside the headless suite. Every measured frame is read
   back from a pixel SubViewport after `RenderingServer.frame_post_draw`. The controlled stage is a
   SubViewport with the shipped GameViewport's pixel settings (snap transforms and vertices,
   nearest filtering; read from `main.tscn` and compared), a pure-blue background, 60 static 7×7
   pixel-art markers in three colours, the real `PlayableDog` (shadow hidden) moved only in 60 Hz
   physics ticks, and the shipped `CameraRig` node taken from `world_2d.tscn`. The background and
   marker colours are asserted absent from all 544 frames of the dog's sheet (0 of 290,464 opaque
   texels). Any engine or script error during a run fails it; the probe exits 1 on any failure,
   including a negative control that is not detected.
2. **Dog image analysis.** The run animation is frozen on `run_e` frame 0 (paused and checked
   on every frame). Per frame: the 8-connected dog components (exactly one required), area,
   bounding box, centroid, the translation-normalised pixels of the component compared with the
   reference frame (opaque texels on the background), RGB intensity and alpha. Tolerance for the
   shape: none (an integer-placed, nearest-filtered, unscaled sprite is an exact copy); for the
   position: the renderer's snap of the interpolated position, with both neighbours accepted only
   within 0.001 px of a half pixel (counted for the markers: no such tie occurred). Negative
   controls on a measured 60 FPS frame:
   a 3 px and a 1 px half-opacity trail, a separate half-opacity ghost 60 px behind and an opaque
   stale copy must each fail.
3. **Motion and double interpolation.** At 30/60/90/120 FPS (achieved rate within 3 % of the
   request) the dog warms up for 36 ticks to the steady scripted RUN (169.705 px/s on screen,
   checked against the constants), then 1.4 s of frames are measured. Per frame the rendered
   position must equal the interpolated physics state's snapped position (the two ticks around
   the frame at its interpolation fraction). Over the window: rendered displacement against the
   logic displacement (limit 2 px: each endpoint carries at most 0.5 px tick rounding and 0.5 px
   snap rounding), fitted on-screen velocity against the expected speed (limit ±3 %; ticks follow
   the wall clock within about one tick over the window, the raster adds < 0.5 %), so sustained
   double presentation (ratio ≈ 2) and even a 10 % error fail. Kept: repeated frames (a hold must be
   predicted by the interpolated state) and the per-step excess over the elapsed time's share (< 2
   px); added: the RMS deviation of the steps from the elapsed time (≤ 1 px). Controls:
   interpolation off at 90 and 120 FPS must fail this smooth-motion metric, and the measured series
   with its displacement doubled must fail at every rate.
4. **Camera shimmer.** At 30/60/90/120 FPS the real `CameraRig` follows the running dog (as
   `IsoWorld.end_step`). Every fully visible marker is tracked on its own: its absolute top-left,
   centroid and bounding box against the position the interpolated camera predicts, its 9×9
   pattern (with a 1 px background border) and its intensity; frames with any residual count as
   common-mode jitter; extra marker components (stale or doubled markers) fail; the 48 px spacing of
   neighbours is kept as supplemental. Controls at the highest rate: a fractional camera (the rig
   leaves its whole-pixel path by ±0.45 px each tick, not in the prediction) must fail the absolute
   position check while the spacing check alone stays blind to it; an unsnapped subpixel camera
   with linear-sampled markers must fail the pattern/intensity check.
5. **Reset presentation.** On the stage at every rate, each action is aligned so that the first
   frame drawn after it follows the action's tick directly (at 30 FPS a frame holds two ticks): a
   new dog entering like `IsoWorld.setup` after the old one ran away, a teleport with
   `set_grid_position()`, and `CameraRig.snap()` 140 px ahead while following. The first frame must
   show one dog with exact pixels at the new position, nothing at the old position, and (snap)
   every marker exactly at the snapped view with no stale marker. Controls: the same teleport and
   snap without their interpolation resets must fail, and the teleport frame with the dog pasted
   back at the old position must fail.
6. **Real Main restart.** Main → Green Zone → Enter (briefing) → injected walk (60 ticks, staying in
   the spawn view) → Esc → Down → Enter (RESTART), the key path of
   `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`. The first frame drawn after the
   replacement entered the tree is analysed, and so is the first frame of the fresh start. The
   animated terrain tiles (tall-grass wind, water; engine TileSet animations, WORLD-004) follow the
   engine's clock, so two Main instances never draw identical frames; the analysis therefore uses
   same-instant redraws inside that frame's `frame_post_draw`
   (`RenderingServer.force_draw(false, 0.0)`: no swap, no time advance): unchanged (it must
   reproduce the frame exactly), without the UI layers and shadows, and also without the dogs. Checks:
   the canvas transform used for the frame is the snapped spawn view; exactly one dog and one camera
   in the tree; the dog is one component equal to the displayed sprite frame's opaque pixels at the
   canonical spawn; no dog pixel anywhere else, in particular in the old run's rectangle (fully in
   view).
7. **Defect found and fixed.** On the unchanged code the first frame after RESTART was drawn with
   the identity canvas transform at every rate (origin (0, 0) instead of (108, −1112)): the world's
   top corner instead of the spawn view, no dog in view. The pause menu reads the key in `_process`,
   so `Main.start_green_zone` runs in the deferred flush after the process step; the new
   physics-interpolated `Camera2D` pushes its view to the viewport only in its process callbacks,
   none of which runs before that frame is drawn, and the old camera left the identity transform on
   exit. The fresh start is not affected (the probe's and the engine's start add Main before the
   nodes' `_process`). Fix: `CameraRig.snap()` calls `camera.force_update_scroll()` after its
   interpolation resets. New partial case `test_P_DOG_008a_restart_canvas_snapped_before_first_draw`:
   at the end of the deferred flush that adds the replacement, the GameViewport canvas transform is
   the snapped spawn view; it fails on the unchanged code (`expected (108.0, -1112.0), got (0.0,
   0.0)`) and passes with the fix. The pre-fix probe run is kept (below).
8. **Docs.** TEST_PLAN.md: the renderer-backed probe and the three IDs' combined evidence (the
   acceptance wording unchanged). FEATURE_MATRIX.md: VIEW-004, CAM-004 and DOG-008a satisfied on
   combined evidence (total 98), the M1 spike accepted, the current tree. This log: this report;
   correction report 17 historical with a supersession note.

### Probe results (fresh clone, VSync off, `step_o_rendered_probe_vsync_off.txt`)

Environment: NVIDIA GeForce RTX 3090 (NVIDIA), 3.3.0 NVIDIA 610.47, rendering method `gl_compatibility`, driver `opengl3`, VSync mode 0, display 60.0 Hz, Godot 4.7.2.stable (ed1daf0bf), Windows 10.0.26200; physics 60 Hz, interpolation True, snap transforms/vertices True/True, default texture filter 0; Main GameViewport {'canvas_item_default_texture_filter': 0, 'snap_2d_transforms_to_pixel': True, 'snap_2d_vertices_to_pixel': True}.
Stage: 432×240, 60 markers, matches Main's GameViewport: True; dog sheet: 544 frames, 290,464 opaque texels, 0 in the background/marker colours.

| Motion (static camera, frozen `run_e` frame 0) | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| achieved FPS / frames measured | 30.0 / 43 | 60.0 / 85 | 90.0 / 127 | 119.99 / 169 |
| dog components per frame (min–max); component failures | 1–1; 0 | 1–1; 0 | 1–1; 0 | 1–1; 0 |
| area / bbox / pattern mismatches / intensity (reference 489 px, 34×21, 0, 234,147) | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 | 489–489 / 34×21–34×21 / 0–0 / 234,147–234,147 |
| position vs interpolated physics state (failures; residual px) | 0; 0..0 | 0; 0..0 | 0; 0..0 | 0; 0..0 |
| displacement rendered / logic (error, limit 2 px) | 238 / 237.585 (0.415) | 238 / 237.578 (0.422) | 238 / 237.585 (0.415) | 238 / 237.578 (0.422) |
| fitted / expected px/s (ratio, limit ±3 %) | 169.737 / 169.705 (1.0002) | 169.7 / 169.705 (1.0) | 169.697 / 169.705 (0.9999) | 169.668 / 169.705 (0.9998) |
| physics ticks/s | 60.0 | 60.0 | 60.0 | 60.0 |
| step RMS vs elapsed time (limit 1 px); held frames (predicted); max step; max excess (limit 2 px) | 0.479; 0 (0); 6; 0.419 | 0.373; 0 (0); 3; 0.288 | 0.318; 0 (0); 2; 0.255 | 0.466; 0 (0); 2; 0.586 |
| result | pass | pass | pass | pass |

| Camera (real CameraRig following the running dog) | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| achieved FPS / frames | 30.14 / 43 | 60.07 / 85 | 90.17 / 127 | 120.39 / 169 |
| marker samples (fully visible markers × frames); missing; extra components | 1,137; 0; 0 | 2,253; 0; 0 | 3,366; 0; 0 | 4,479; 0; 0 |
| absolute position vs interpolated camera: failures; residual x / y px; tie samples | 0; 0..0 / 0..0; 0 | 0; 0..0 / 0..0; 0 | 0; 0..0 / 0..0; 0 | 0; 0..0 / 0..0; 0 |
| common-mode jitter frames; max centroid deviation px | 0; 0.0 | 0; 0.0 | 0; 0.0 | 0; 0.0 |
| pattern / size failures; intensity (reference 24,990) | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 | 0 / 0; 24,990–24,990 |
| adjacent-marker gaps px (supplemental) | 48 | 48 | 48 | 48 |
| dog: components failures / shape failures / position failures | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 | 0 / 0 / 0 |
| result | pass | pass | pass | pass |

| First frame after (stage) | FPS | frame tick − action tick | fraction | dog components / pattern mismatches / position residual | old position: dog pixels | markers (visible / position failures / pattern failures / extra) | result |
|---|---|---|---|---|---|---|---|
| spawn | 30 | 0 | 0.1296 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 30 | 0 | 0.129 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 30 | 0 | 0.1279 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 60 | 0 | 0.1253 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 60 | 0 | 0.1228 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 60 | 0 | 0.1194 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 90 | 0 | 0.1171 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 90 | 0 | 0.1166 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 90 | 0 | 0.2353 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |
| spawn | 120 | 0 | 0.0661 | 1 / 0 / 0,0 | 0 | 27 / 0 / 0 / 0 | pass |
| teleport | 120 | 0 | 0.1194 | 1 / 0 / 0,0 | 0 | — | pass |
| camera snap | 120 | 0 | 0.469 | 1 / 0 / 0,0 | — | 27 / 0 / 0 / 0 | pass |

| Real Main → Green Zone → pause → RESTART | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| start frame: canvas origin (expected) ; dog bbox ; texel mismatches | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 |
| old run: dog / camera before RESTART | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] |
| replacement added after draw / first frame (seq) | 3436 / 3437 | 3596 / 3597 | 3828 / 3829 | 4130 / 4131 |
| first frame after RESTART: canvas origin (expected) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) | [108.0, -1112.0] ([108.0, -1112.0]) |
| camera / dog at (expected spawn) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) |
| dog components; bbox (expected); area (reference); texel mismatches | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 | 1; [96, 305, 24, 31] ([96, 305, 24, 31]); 505 (505); 0 |
| dogs / rigs in tree; redraw px differing from the frame | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 |
| old position (rect, visible px): dog pixels; dog pixels elsewhere | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 |
| failing checks | — | — | — | — |
| result | pass | pass | pass | pass |

| Negative control | Detected | Failed checks (what saw it) |
|---|---|---|
| `ghost_trail_3px` | yes | shape_exact |
| `ghost_trail_1px` | yes | shape_exact |
| `ghost_separate_60px` | yes | shape_exact, single_component |
| `stale_copy_60px` | yes | shape_exact, single_component |
| `interpolation_off_90` | yes | max_step, model_position, no_unexpected_holds, step_rms |
| `interpolation_off_120` | yes | model_position, no_unexpected_holds, step_rms |
| `doubled_displacement_30` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_60` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_90` | yes | displacement, max_step, model_position, step_rms, velocity |
| `doubled_displacement_120` | yes | displacement, max_step, model_position, step_rms, velocity |
| `fractional_camera_dither_120` | yes | dog_position, marker_position_exact |
| `subpixel_camera_linear_120` | yes | dog_shape_exact, dog_single_component, marker_pattern_exact, marker_position_exact |
| `stale_copy_after_teleport_30` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_30` | yes | dog_at_new_position, nothing_at_old_position |
| `camera_snap_without_reset_30` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_60` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_60` | yes | dog_at_new_position, nothing_at_old_position |
| `camera_snap_without_reset_60` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_90` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_90` | yes | dog_at_new_position, nothing_at_old_position |
| `camera_snap_without_reset_90` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |
| `stale_copy_after_teleport_120` | yes | dog_shape_exact, dog_single_component, nothing_at_old_position |
| `teleport_without_reset_120` | yes | dog_at_new_position |
| `camera_snap_without_reset_120` | yes | dog_at_new_position, markers_at_snapped_view, no_stale_markers |

Summary: ok = True; failures: none; engine errors: none; 24 measured records, 24 negative controls, 24 detected.

### VSync on (supplemental, 30/60 FPS, `step_q_rendered_probe_vsync_on.txt`)

VSync on, 60 Hz display, `--rates=30,60`: motion 30.0 / 60.0 FPS achieved (fitted velocity ratio 0.9999 / 1.0), camera 30.06 / 60.02 FPS (1,137 / 2,250 marker samples, every one exact), the spawn, teleport and camera-snap first frames and the real Main RESTART at both rates: every record passed, 14 of 14 negative controls detected (the interpolation-off control needs more than 60 FPS and is not part of this run). Full tables: the evidence REPORT.md.

### Pre-fix control (the same tree with `CameraRig.snap()` as in `8f8dcb6`)

The clone's `godot/iso/camera_rig.gd` was reverted to `8f8dcb6`'s blob (`f13dac1…`, `step_s`), the focused cases and the probe were run, and the file was restored (`step_v`: hash `1007163…` = `HEAD:godot/iso/camera_rig.gd`). `test_P_DOG_008a_restart_canvas_snapped_before_first_draw` failed (`expected (108.0, -1112.0), got (0.0, 0.0)`); the probe exited 1: the four `main_restart` records (30/60/90/120 FPS) failed; every other record passed and all 24 negative controls were detected. The fresh-start frames were correct; the first frame after RESTART was drawn with the identity canvas transform, so the spawn and the dog were out of view (frames `prefix_main_60_first_frame_after_restart.png`, `prefix_main_120_first_frame_after_restart.png`):

| Real Main → Green Zone → pause → RESTART | 30 FPS | 60 FPS | 90 FPS | 120 FPS |
|---|---|---|---|---|
| start frame: canvas origin (expected) ; dog bbox ; texel mismatches | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 | [108.0, -1112.0] ([108.0, -1112.0]); [96, 305, 24, 31]; 0 |
| old run: dog / camera before RESTART | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] | [16.0, 1400.0] / [23.0, 1328.0] |
| replacement added after draw / first frame (seq) | 3437 / 3438 | 3597 / 3598 | 3829 / 3830 | 4132 / 4133 |
| first frame after RESTART: canvas origin (expected) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) | [0.0, 0.0] ([108.0, -1112.0]) |
| camera / dog at (expected spawn) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) | [0.0, 1328.0] / [0.0, 1448.0] ([0.0, 1448.0]) |
| dog components; bbox (expected); area (reference); texel mismatches | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 | 0; [0, 0, 0, 0] ([96, 305, 24, 31]); 0 (505); 505 |
| dogs / rigs in tree; redraw px differing from the frame | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 | 1 / 1; 0 |
| old position (rect, visible px): dog pixels; dog pixels elsewhere | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 | [104, 252, 40, 40], 1600: 0; 0 |
| failing checks | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component | restart_canvas_at_snapped_view, restart_dog_at_canonical_spawn, restart_single_dog_component |
| result | FAIL | FAIL | FAIL | FAIL |

### Commands executed and results

| Command | Result |
|---|---|
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `366eb3bca4bfe5e71e2804eac2deb806351fa2eb` = `git rev-parse HEAD:godot` of this commit; only the docs and the evidence folders were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **139 passed, 0 failed, 139 total** |
| `… --suite all --case DOG_008a` (focused logical restart cases) | exit 0: 2 passed |
| `<console exe> --headless --path godot --quit-after 600` (600-frame desktop launch) | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,906,024 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| `<console exe> --path godot --rendering-driver opengl3 --disable-vsync --script res://tools/rendered_presentation_probe.gd -- --out=…` | exit 0: the stage check and 24 measured records pass, 24 of 24 negative controls detected, no engine error |
| the same with VSync on and `--rates=30,60` | exit 0: 12 measured records pass, 14 of 14 negative controls detected, no engine error |
| pre-fix: `camera_rig.gd` reverted in the clone; `--case DOG_008a`; the probe (VSync off); file restored | exit 1 (1 of 2 failed); exit 1 (the four `main_restart` records (30/60/90/120 FPS) failed; every other record passed and all 24 negative controls were detected); restored, hash = `HEAD:godot/iso/camera_rig.gd` |
| `… harness/m1_spike_harness_selftest.gd`; `node … m1_spike_tool.mjs selftest` | exit 0: **37 passed, 0 failed**; **6 passed, 0 failed** |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (after the import, after the probes, after all steps); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty (HEAD: the code-only commit `3d06d7c`, folded into this commit with the same `godot/` tree) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --cached --check 8f8dcb6` (this commit's full content, staged) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 77 checks` |

Evidence: `docs/porting/windows_evidence/correction-18-godot-tree-366eb3b/` (REPORT.md, the logs of every
step, `exit_codes.txt`) and `docs/porting/captures/m2_rendered/godot-tree-366eb3b/` (24
PNG frames: first/representative frames per pass, every control, the reset and restart frames,
the pre-fix restart frames). The rendered evidence is not a suite result. Not run: Linux; Android
(no rendered or device claim here); manual play.

Host evidence: current tree above. Previous Windows trees: `51ad8b3` (correction report 17, 138
passed), `591e2df` (correction report 16, 138 passed), `cd87171` (correction report 15, 138 passed),
`ef6c318` (progress report 14, 138 passed), `9bbe179` (correction report 12, 138 passed), `a06b1df`
(correction report 11, 138 passed), `1532143` (correction report 10, 137 passed), `6a3c53b`
(correction report 9, 137 passed), `b1c3595` (correction report 8, 137 passed), `b8535ab`
(correction report 7 addendum, 137 passed), `81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`
(correction report 6, 134 passed). Linux: the prior tree `d12bedd`, 128 passed (progress report 5).
Correction 6 was not rerun on Linux, and neither were correction 7's addendum, corrections 8 to 13,
progress report 14, correction reports 15 to 17 and this report.

### Acceptance status

| ID | Status | Evidence |
|---|---|---|
| VIEW-004 | **satisfied on combined evidence** | suite: `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`; renderer: motion, camera and reset passes above (no streak, double interpolation or static shimmer at 30/60/90/120 FPS) |
| CAM-004 | **satisfied on combined evidence** | suite: whole-pixel camera origin in `test_CAM_002_camera_clamps_small_and_large_maps` and `test_P_VIEW_004_…`; renderer: every marker exact under the following camera, fractional-camera controls detected |
| DOG-008a | **satisfied on combined evidence** | suite: `test_CORE_002_logic_independent_of_render_rate` (spawn, teleport, camera-snap resets; test-hook defaults), `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, `test_P_DOG_008a_restart_canvas_snapped_before_first_draw`; renderer: the motion passes and the first frame after spawn, teleport, camera snap and the real Main RESTART |

Totals: 98 satisfied (92 full suite + 4 combined: ARCH-001a, VIEW-004, CAM-004, DOG-008a + 2
command: AST-019, CORE-001). Every automated M1 and M2 acceptance ID is satisfied. The parent
DOG-008 still needs DOG-008b (M5).

### Development attempts (kept as found)

- The first runs did not compile: a `--script` `SceneTree` is compiled before the autoloads exist,
  so preloading `main.tscn` or naming `GreenZoneScene`/`InputService` failed; the probe became a
  launcher plus an implementation loaded at run time (the test runner's pattern), with the
  project's warnings-as-errors typing fixed.
- One run exited 0 although script errors were logged; the implementation now installs the tests'
  `ErrorCapture` logger and fails on any engine or script error.
- The stage frames were not captured (the stage was never set as the capture source), then no
  marker was evaluated: the marker rows were placed 320 px below the view (the start projects to
  screen y 320, not 640). The palette check first deduplicated the atlas frames by their texture
  RID, which all frames share, and checked only a few; it now checks all 544 frames.
- At 30 FPS the two no-reset controls were first not detected: the first frame after the action
  also held the next tick, which hides a missing reset. Every reset case is now aligned so its first
  frame follows the action tick directly, and that is checked.
- The first Main analysis compared separate Main instances pixel for pixel: two fresh starts
  differed in 8,000–20,000 pixels across the frame (the animated terrain tiles follow the engine
  clock), so it was replaced by the same-instant redraws.
- That analysis found the RESTART defect at every rate on the unchanged code (working tree, all
  four rates). A minimal reproduction that emitted the restart before the nodes' `_process` drew
  correctly; the real key path runs the replacement after `_process`. The fix and the regression
  case followed; the case fails without the fix.
- With Main, the briefing music was still playing at exit (a leaked playback and a "resources still
  in use" error at shutdown, after the verdict); the probe stops the music before quitting.

### Legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, accepted by the architect on review of
   `8f8dcb6`.** The throwaway native migration plugin under `/godot/platform/android/` read the five
   legacy keys of a controlled same-package/same-signature lineage on three emulators. The
   native-bridge versus staged-Capacitor decision stands: `native_bridge_viable_for_controlled_lineage`
   (controlled lineage, emulators, test key; not a production approval).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the accepted M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key, accepted by the architect on review of `8f8dcb6`; physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 17: same-process queued-read cancellation evidence (`8f8dcb6`; M1 Partial, M2 Partial)

> Historical record of `8f8dcb6`, superseded by correction report 18 (text below kept as
> submitted). **Supersession:** on review of `8f8dcb6` the architect accepted the M1 controlled Android migration spike;
> its evidence and decision stand (`native_bridge_viable_for_controlled_lineage`, not a production approval). Its open
> M2 items "rendered clauses of VIEW-004, CAM-004 and DOG-008a" are satisfied on combined evidence in correction
> report 18, whose probe also found and fixed a wrong first frame after RESTART.

Scope: the architect's review of `d502adf`, in one focused commit. Changed: the throwaway M1 spike
under `/godot/platform/android/m1_migration_spike/` only (plugin hook, harness, harness self-test,
`tools/run_upgrade_test.ps1`, README), FEATURE_MATRIX.md, this log and new evidence. No gameplay,
test, tool, asset, PixiJS, Capacitor configuration or root `android/` file changed; no APK or
keystore is committed. The controlled-lineage decision and its production limits are unchanged;
nothing here is a production approval.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); M1 migration spike executed and hardened, pending architect review; open M1 items: the manual checks; open M2 items: the rendered clauses of VIEW-004, CAM-004 and DOG-008a, and the manual desktop and touch play checks |
| Base | `d502adf` (correction report 16) |
| Current `godot/` tree | `51ad8b3f029fc565c9d4237dbc903fdeab15381d`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2; Linux not rerun |
| Android | emulators only, as in correction report 16: `sv_m1_api36` (`emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34, WebView 113.0.5672.136), `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24, WebView provider Chrome 69.0.3497.100); no physical device |

### Changes per review item

1. **Same-process queued-read cancellation case.** New development-only plugin hook
   `cancelForLifecycleTest()`: it calls `cancelForLifecycle("lifecycle_test_cancel")`, the state
   transition `onMainDestroy` and `onGodotTerminating` run (plugin terminated, epoch bumped,
   reservation cleared on the calling thread, then the UI-thread step), without ending the process
   or the Activity. New harness mode (`user://m1_lifecycle_same_process_cancel.flag`): it calls
   `readLegacyStoreQueuedForLifecycleTest()` (the reservation and queueing of `readLegacyStore()`,
   with `start()` posted 5 s later) and, in the same frame, `cancelForLifecycleTest()`; it neither
   quits nor finishes the Activity, and prints `M1_SPIKE_LIFECYCLE_SAME_PROCESS_DONE` 9 s after the
   cancellation. Option **a)** of the review: the queued runnable is not removed; it runs in the
   same process when due and logs `discarded queued start`. That keeps the stale check as the one
   guard, which is needed anyway for a start already taken off the queue when a cancellation lands.
   New device case 06f (7 checks): same-frame request and cancellation with no quit or finish;
   reserved, then invalidated while pending by `lifecycle_test_cancel`; the queued start ran in the
   same process (same pid on the reservation and discard lines and after the case) at least the
   5 s delay after the reservation and discarded itself with exactly `plugin terminated, stale
   epoch E (now E+1), generation invalidated (reserved: 0)`; no WebView created; nothing emitted
   (`result_received: false`); the process and its Activity still running (same pid, Activity
   resumed); no crash. The recovery run is now 06g.
2. **Mutation sensitivity.** Three builds of the tested source, each with one mutation applied and
   restored afterwards (`mutation_api36/`), ran the same case on API 36 with
   `run_upgrade_test.ps1 -SameProcessCancelCaseOnly`, next to the unmutated build, which passed
   (9/9). `no_stale_check` (`start()` ignores `staleReason()`) created a WebView 5,009 ms after the request and failed (7/9: "discarded
   itself" and "no WebView created"; its late-callback guards still emitted nothing).
   `no_epoch_check` (the epoch comparison removed) and `epoch_only` (the terminated and generation
   conditions removed) still discarded the start without a WebView, through the remaining
   conditions, and failed the exact-reasons check (8/9 each; reasons `plugin terminated, generation
   invalidated (reserved: 0)` and `stale epoch 0 (now 1)`). Each mutated source was restored and
   re-hashed identical before the next build. The review's other mutation, removing the
   queued-runnable removal, belongs to option b and does not apply.
3. **Kept:** the real Godot-termination and Activity-destruction cases during an active read (06b,
   06c) and in the same frame as a queued request (06d, 06e), the API 24/34/36 upgrade runs, the
   negative cases and the recovery run (06g).
4. **Rerun** on API 36, 34 and 24 from a fresh clone of this commit's code, and the host checks on
   another fresh clone (below). Harness self-test **37/37** (new: the same-process mode, with nothing
   received and with a fake that emits a result anyway, which must show as `result_received: true`);
   tool self-test 6/6.
5. **Docs.** FEATURE_MATRIX.md: host verification and project-isolation row (this tree), the Android
   emulators, the legacy-save plan's M1 stage, the native-build and campaign-migration rows. This
   log: this report; correction report 16 historical with a supersession note.

### Controlled lineage and results

| APK | Package | versionCode | Certificate SHA-256 | APK SHA-256 |
|---|---|---|---|---|
| old Capacitor (unchanged, progress report 14) | `com.zampano.supervillained` | 1 | `034b187e…2191` | `0771cd78…a89d` |
| Godot spike (minSdk 24, no permissions) | `com.zampano.supervillained` | 2 | the same | `c01004c2…ef82` |
| spike, wrong key | `com.zampano.supervillained` | 2 | `b2df28e1…7a26` | `084e1a06…8396` |
| spike, wrong package | `com.zampano.supervillained.m1negative` | 2 | `034b187e…2191` | `7fada722…951e` |

| Check | API 36 / WebView 133 | API 34 / WebView 113 | API 24 / Chrome 69 |
|---|---|---|---|
| old install, seeding (old boot migration; API 24: direct), values stable across a cold restart | pass | pass | pass |
| wrong-key update rejected, wrong package `not_found` (null error on every key) | pass | pass | pass |
| `adb install -r`: versionCode 2, same firstInstallTime and certificate | pass | pass | pass |
| two spike processes × two reads: `success`, origin `https://localhost`, five raw values identical to the old app's, null key errors | pass | pass | pass |
| termination during an active read (06b Godot quit, 06c Activity finish): cancelled, teardown on `main`, nothing emitted, the lifecycle log consistent, no crash | pass | pass | pass |
| termination in the same frame as a queued request (06d Godot quit, 06e Activity finish): the reserved generation invalidated while pending, no WebView created, nothing emitted, no crash | pass | pass | pass |
| same process (06f): the lifecycle cancellation in the request's frame, process and Activity kept running; the queued start ran in that process after its delay and discarded itself with all three stale reasons; no WebView, nothing emitted, no crash | pass | pass | pass |
| 06g third run after the lifecycle tests: identical values | pass | pass | pass |
| no production save; WebView storage present; fresh install `not_found` (null key errors) | pass | pass | pass |
| `webview_package` | object (API 26+) | object | `null` + diagnostic |
| **Total** | **62/62** | **62/62** | **61/61** |

Same process: `lifecycle_test_cancel` invalidated the reservation 0–1 ms after it, and the queued
start was discarded 5,003 ms (API 36), 5,004 ms (API 34) and 5,004 ms (API 24) after the reservation,
with the same process id on the reservation and discard lines and after the case, and the spike's
Activity still resumed. The same-frame terminations (06d, 06e) ended the process 29 ms–3.2 s after
the request, before the delayed start was due, as in correction report 16.

API 36 needed a second full run of this tree: the first (same APKs) ended **58/62** because in 06b
Godot stalled at start-up after its OpenGL line (12.9 s after its banner, 3.4–6.5 s in that run's
other launches) and the harness never printed `M1_SPIKE_START` (about 105 s, no crash-buffer
entry); no spike code had run. 06b's four held-read checks failed; all of 06c–06g passed in that
run. The test records only the `godot`, `SvMigrationSpike` and `AndroidRuntime` tags, so the cause
is not known. The second run, with an unfiltered logcat recorded alongside (not committed), passed
62/62 without a stall (`android_evidence/…/godot-tree-51ad8b3/REPORT.md`, `device_api36_attempt1/`).

### Commands executed and results

| Command | Result |
|---|---|
| `…/harness/m1_spike_harness_selftest.gd` (working tree) | `37 passed, 0 failed` |
| `tools/run_upgrade_test.ps1 -Serial emulator-5554 -SameProcessCancelCaseOnly` (working tree, trial 1) | exit 0: 9/9 |
| `tools/build_spike_apk.ps1` ×3 from a fresh clone of this commit's code, plus ×3 with one mutation each applied to the clone's plugin source and restored (javac; `api_level_check.py`; JAR; scratch project; `godot --headless --install-android-build-template --export-debug Android`; `apksigner verify`; `aapt2 dump badging`) | exit 0 each; API-level check OK (68 references, 2 guarded); upgrade / wrong-key / wrong-package APKs `c01004c2…ef82` / `084e1a06…8396` / `7fada722…951e` (SHA-256), minSdk 24, no `uses-permission`; plugin source identical after each restore |
| `tools/run_upgrade_test.ps1 -Serial emulator-5554` (API 36) | first run exit 1: 58/62 (06b start-up stall, above); second run exit 0: **62/62** |
| `tools/run_upgrade_test.ps1 -Serial emulator-5556 -DevToolsPort 9334` (API 34) | exit 0: **62/62** |
| `tools/run_upgrade_test.ps1 -Serial emulator-5558 -DevToolsPort 9335 -SeedMode direct -DirectSeedValues <API 36 expected.json>` (API 24) | exit 0: **61/61** |
| `tools/run_upgrade_test.ps1 -Serial emulator-5554 -SameProcessCancelCaseOnly` with the upgrade APK and each mutation APK (API 36) | baseline exit 0 (9/9); `no_stale_check` exit 1 (7/9); `no_epoch_check` exit 1 (8/9); `epoch_only` exit 1 (8/9) |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `51ad8b3f029fc565c9d4237dbc903fdeab15381d` = `git rev-parse HEAD:godot` of this commit; only the docs and the evidence folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `<console exe> --headless --path godot --quit-after 600` (600-frame desktop launch) | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,905,976 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| `… --script res://platform/android/m1_migration_spike/harness/m1_spike_harness_selftest.gd` | exit 0: **37 passed, 0 failed** |
| `node godot/platform/android/m1_migration_spike/tools/m1_spike_tool.mjs selftest` | exit 0: **6 passed, 0 failed** |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after the checks); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty (HEAD: the code-only commit `e20cde0`, folded into this commit with the same `godot/` tree) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --cached --check d502adf` (this commit's full content, staged) | clean |
| Secret scan of the evidence and of the commit (the two test keystore passwords, the local user name, the account e-mail) | no match; no APK, AAB, keystore, JAR or binary in the commit |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 72 checks` |

Evidence: `docs/porting/android_evidence/m1_migration_spike/godot-tree-51ad8b3/` (REPORT.md,
DECISION.md, `builds/`, `device_api36/`, `device_api36_attempt1/`, `device_api34/`, `device_api24/`,
`mutation_api36/`, `dev_attempts/`, `host_checks/`); the folders of correction reports 16
(`godot-tree-591e2df/`) and 15 (`godot-tree-cd87171/`) and progress report 14 (`godot-tree-ef6c318/`)
are unchanged. Not run: Linux; a physical Android device; the game itself on the emulators; manual
play; listening to the audio.

Host evidence: current tree above. Previous Windows trees: `591e2df` (correction report 16, 138
passed), `cd87171` (correction report 15, 138 passed), `ef6c318` (progress report 14, 138 passed),
`9bbe179` (correction report 12, 138 passed), `a06b1df` (correction report 11, 138 passed), `1532143`
(correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595`
(correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum, corrections 8 to 13, progress report 14, correction reports 15 and 16 and
this report.

### Development attempts (kept as found)

- Harness self-test, first version of the new case (working tree): it required `ms_since_cancel`
  of at least 500 for a 0.5 s wait and failed with 450 (the headless timer runs on game time, which
  drifts from the wall clock); it now requires only the field, and the device test times the
  queued start from logcat timestamps.
- Trial 1 (working tree, API 36, `-SameProcessCancelCaseOnly`, the upgrade APK from the working
  tree): 9/9; discarded at +5,006 ms with all three reasons, same process, no WebView.
- The first full API 36 run of this tree: 58/62 (the 06b start-up stall above). Logs:
  `android_evidence/…/godot-tree-51ad8b3/dev_attempts/` and `device_api36_attempt1/`.

### Legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, pending architect review.** The native-bridge
   versus staged-Capacitor decision is unchanged: `native_bridge_viable_for_controlled_lineage`.
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key (decision `native_bridge_viable_for_controlled_lineage`, pending architect review); physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Architect review of the M1 spike** (evidence and decision above).
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Rendered clauses of VIEW-004, CAM-004 and DOG-008a (M2):** a strengthened renderer-backed probe
  with the checks listed in TEST_PLAN.md (combined evidence), run at 30/60/90/120 FPS and accepted
  by the architect.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 16: pre-start lifecycle race, per-key error validation (`d502adf`; M1 Partial, M2 Partial)

> Historical record of `d502adf`, superseded by correction report 17 (text below kept as
> submitted). **Supersession:** its decision `native_bridge_viable_for_controlled_lineage` and its limits stand.
> On review of `d502adf` the architect required a same-process test of a cancelled queued start:
> its `start()` rejection had not run on a device, because every real termination ended the process
> before the delayed start was due. Correction report 17 adds that test (option a): the queued start
> runs in a process that keeps running and discards itself) with mutation checks. Its device totals
> (55/55, 55/55, 54/54) are superseded by correction report 17's reruns.

Scope: the architect's review of `b5b6c82`, in one commit. Changed: the throwaway M1 spike under
`/godot/platform/android/m1_migration_spike/` only (plugin, harness, harness self-test,
`tools/m1_spike_tool.mjs`, `tools/run_upgrade_test.ps1`, README), FEATURE_MATRIX.md, this log and
new evidence. No gameplay, test, tool, asset, PixiJS, Capacitor configuration or root `android/`
file changed; no APK or keystore is committed. The controlled-lineage decision and its production
limits are unchanged; nothing here is a production approval.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); M1 migration spike executed and hardened, pending architect review; open M1 items: the manual checks; open M2 items: the rendered clauses of VIEW-004, CAM-004 and DOG-008a, and the manual desktop and touch play checks |
| Base | `b5b6c82` (correction report 15) |
| Current `godot/` tree | `591e2df2f1826de798024d9b0f237afe07eea6da`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2; Linux not rerun |
| Android | emulators only, as in correction report 15: `sv_m1_api36` (`emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34, WebView 113.0.5672.136), `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24, WebView provider Chrome 69.0.3497.100); no physical device |

### Changes per review item

1. **Pre-start lifecycle race.** `request()` now reserves the read's generation on the caller's
   thread (a compare-and-set; a second request while one is reserved gets `busy`) and records the
   lifecycle epoch before it posts `start()` to the UI thread. Activity destruction
   (`onMainDestroy`) and Godot termination (`onGodotTerminating`) mark the plugin terminated, bump
   the epoch and clear the reservation at once, on whichever thread delivers them, so a pending
   start and an active read are invalidated alike; an active read's timeout and WebView are then
   destroyed on the UI thread. Before it creates a WebView, `start()` rejects a terminated plugin, a
   stale epoch, an invalidated generation and a finishing or destroyed Activity: a rejected start
   creates no WebView and emits nothing (logged as `discarded queued start`). New device tests 06d
   and 06e: the harness calls the development-only `readLegacyStoreQueuedForLifecycleTest()` (the
   same reservation as `readLegacyStore()`; only its `start()` is posted 5 s later, so the
   termination lands while the start is still queued) and, in the same frame
   (`frames_since_request: 0`), quits Godot or finishes the Activity; the device script does not wait
   for `M1_SPIKE_LIFECYCLE_ACTIVE` (the harness never prints it in these modes). The active-read tests
   (06b quit, 06c Activity finish) and the recovery run (now 06f) are kept.
2. **Result validation.** A success or not_found result must carry a null error on every key: the
   harness turns any non-null per-key error into `status: error` / `wrong_shape_plugin_result` (the
   plugin itself reports a per-key read error as `error` / `key_read_error`, unchanged);
   `m1_spike_tool.mjs compare` now requires a null error on every key for not_found as it did for
   success, and `m1_spike_tool.mjs selftest` checks the comparison (6 cases, both error cases with the
   error in both attempts so only the null-error rule rejects them). Harness self-test: `_summarize`
   and whole-harness cases for not_found + per-key error and success + per-key error, and the four
   lifecycle modes against a recording fake (the held modes terminate 2 s after the request, the
   immediate ones in the same frame; none prints `M1_SPIKE_DONE`): **35/35** (17 `_summarize` shapes,
   14 whole runs, 4 lifecycle modes). Mutation checks (working tree, reverted; not in the logs):
   without the harness rule its four new error cases fail (`not_found / <null>`, `success / <null>`);
   without the tool rule the tool self-test fails (`not_found with a per-key error: compare accepts`).
3. **Rerun** on API 36, 34 and 24 from a fresh clone of this commit's code, with the lifecycle and
   negative cases (below). The decision `native_bridge_viable_for_controlled_lineage` and its limits
   stand (`android_evidence/…/godot-tree-591e2df/DECISION.md`).
4. **Host checks** on another fresh clone (below).
5. **Docs.** FEATURE_MATRIX.md: host verification and project-isolation row (this tree), the Android
   emulators, the legacy-save plan's M1 stage, the native-build and campaign-migration rows. This
   log: this report; correction report 15 historical with a supersession note.

### Controlled lineage and results

| APK | Package | versionCode | Certificate SHA-256 | APK SHA-256 |
|---|---|---|---|---|
| old Capacitor (unchanged, progress report 14) | `com.zampano.supervillained` | 1 | `034b187e…2191` | `0771cd78…a89d` |
| Godot spike (minSdk 24, no permissions) | `com.zampano.supervillained` | 2 | the same | `1fb37c71…e40d` |
| spike, wrong key | `com.zampano.supervillained` | 2 | `b2df28e1…7a26` | `ad9feb68…f420` |
| spike, wrong package | `com.zampano.supervillained.m1negative` | 2 | `034b187e…2191` | `65453e10…505b` |

| Check | API 36 / WebView 133 | API 34 / WebView 113 | API 24 / Chrome 69 |
|---|---|---|---|
| old install, seeding (old boot migration; API 24: direct), values stable across a cold restart | pass | pass | pass |
| wrong-key update rejected, wrong package `not_found` (null error on every key) | pass | pass | pass |
| `adb install -r`: versionCode 2, same firstInstallTime and certificate | pass | pass | pass |
| two spike processes × two reads: `success`, origin `https://localhost`, five raw values identical to the old app's, null key errors | pass | pass | pass |
| termination during an active read (06b Godot quit, 06c Activity finish): cancelled, teardown on `main`, nothing emitted, the lifecycle log consistent, no crash | pass | pass | pass |
| termination in the same frame as a queued request (06d Godot quit, 06e Activity finish; no wait for `M1_SPIKE_LIFECYCLE_ACTIVE`): the reserved generation invalidated while pending, no WebView created, nothing emitted, no crash | pass | pass | pass |
| 06f third run after the lifecycle tests: identical values | pass | pass | pass |
| no production save; WebView storage present; fresh install `not_found` (null key errors) | pass | pass | pass |
| `webview_package` | object (API 26+) | object | `null` + diagnostic |
| **Total** | **55/55** | **55/55** | **54/54** |

Same-frame termination: in all six runs `godot_terminating` (GL thread) invalidated the reserved
generation 19–38 ms (Godot quit) or 0.56–1.8 s (Activity finish) after the request, and the process
ended 24 ms–2.2 s after it, before the delayed start was due at 5 s: no WebView was created, and
`start()`'s own rejection of a stale request was not reached on a device (no process outlived the
delay). In every Activity-finish case Godot 4.7.2 delivered `onGodotTerminating` before
`onMainDestroy`; in 06c `activity_destroy` destroyed the still-active WebView on `main`
(`android_evidence/…/godot-tree-591e2df/REPORT.md`).

### Commands executed and results

| Command | Result |
|---|---|
| `…/harness/m1_spike_harness_selftest.gd` (working tree) | `35 passed, 0 failed` |
| `node …/tools/m1_spike_tool.mjs selftest` (working tree) | `6 passed, 0 failed` |
| Mutation checks of both rules (working tree, reverted) | fail without them (messages in "Changes" above) |
| `tools/build_spike_apk.ps1` ×3 from a fresh clone of this commit's code (javac; `api_level_check.py`; JAR; scratch project; `godot --headless --install-android-build-template --export-debug Android`; `apksigner verify`; `aapt2 dump badging`) | exit 0 each; API-level check OK (68 references, 2 guarded; the new `Activity.isDestroyed()` is API 17); upgrade / wrong-key / wrong-package APKs `1fb37c71…e40d` / `ad9feb68…f420` / `65453e10…505b` (SHA-256), minSdk 24, no `uses-permission` |
| `tools/run_upgrade_test.ps1 -Serial emulator-5554` (API 36) | exit 0: **55/55** |
| `tools/run_upgrade_test.ps1 -Serial emulator-5556 -DevToolsPort 9334` (API 34) | exit 0: **55/55** |
| `tools/run_upgrade_test.ps1 -Serial emulator-5558 -DevToolsPort 9335 -SeedMode direct -DirectSeedValues <API 36 expected.json>` (API 24) | exit 0: **54/54** |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `591e2df2f1826de798024d9b0f237afe07eea6da` = `git rev-parse HEAD:godot` of this commit; only the docs and the evidence folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `<console exe> --headless --path godot --quit-after 600` (600-frame desktop launch) | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,905,976 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| `… --script res://platform/android/m1_migration_spike/harness/m1_spike_harness_selftest.gd` | exit 0: **35 passed, 0 failed** |
| `node godot/platform/android/m1_migration_spike/tools/m1_spike_tool.mjs selftest` | exit 0: **6 passed, 0 failed** |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after the checks); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty (HEAD: the code-only commit `c2ac3b2`, folded into this commit with the same `godot/` tree) |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --cached --check b5b6c82` (this commit's full content, staged) | clean |
| Secret scan of the evidence and of the commit (the two test keystore passwords, the local user name, the account e-mail) | no match; no APK, AAB, keystore, JAR or binary in the commit |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 71 checks` |

Evidence: `docs/porting/android_evidence/m1_migration_spike/godot-tree-591e2df/` (REPORT.md,
DECISION.md, `builds/`, `device_api36/`, `device_api34/`, `device_api24/`, `dev_attempts/`,
`host_checks/`); the folders of correction report 15 (`godot-tree-cd87171/`) and progress report 14
(`godot-tree-ef6c318/`) are unchanged. Not run: Linux; a physical Android device; the game itself
on the emulators; manual play; listening to the audio.

Host evidence: current tree above. Previous Windows trees: `cd87171` (correction report 15, 138
passed), `ef6c318` (progress report 14, 138 passed), `9bbe179` (correction report 12, 138 passed),
`a06b1df` (correction report 11, 138 passed), `1532143` (correction report 10, 137 passed),
`6a3c53b` (correction report 9, 137 passed), `b1c3595` (correction report 8, 137 passed), `b8535ab`
(correction report 7 addendum, 137 passed), `81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`
(correction report 6, 134 passed). Linux: the prior tree `d12bedd`, 128 passed (progress report 5).
Correction 6 was not rerun on Linux, and neither were correction 7's addendum, corrections 8 to 13,
progress report 14, correction report 15 and this report.

### Development attempts (kept as found)

- Trial 1 (working tree, API 36; the upgrade APK from the working tree, the two negative APKs from
  correction report 15): 51/53. The same-frame tests' invalidation check expected a thread name
  without spaces and missed `GLThread 48`; the plugin logs show the reservation invalidated while
  pending, no WebView and nothing emitted. Pattern fixed; the device test now also records when the
  process ended.
- Attempt 1 (tree `329d05f`, all three emulators): 53/53, 53/53, 52/52, but in 06c the plugin
  logged `godot_terminating: generation 1 was still queued (no WebView)` after `activity_destroy`
  had destroyed that active read: the Godot-termination UI step reported any missing WebView as a
  queued start. The behaviour was right (teardown on `main`, nothing emitted), the log was not.
  Fixed (`startedGeneration` separates "still queued" from "already torn down"; an invalidation with
  nothing reserved says `no reserved generation`), and 06b/06c gained a log-consistency check, which
  fails on attempt 1's logs. Attempt 1's host checks were stopped after the asset check. Everything
  was rebuilt and rerun on this tree. Logs: `android_evidence/…/godot-tree-591e2df/dev_attempts/`.

### Legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, pending architect review.** The native-bridge
   versus staged-Capacitor decision is unchanged: `native_bridge_viable_for_controlled_lineage`.
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key (decision `native_bridge_viable_for_controlled_lineage`, pending architect review); physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Architect review of the M1 spike** (evidence and decision above).
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Rendered clauses of VIEW-004, CAM-004 and DOG-008a (M2):** a strengthened renderer-backed probe
  with the checks listed in TEST_PLAN.md (combined evidence), run at 30/60/90/120 FPS and accepted
  by the architect.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 15: hermetic PCK smoke, spike hardening, API 24 (`b5b6c82`; M1 Partial, M2 Partial)

> Historical record of `b5b6c82`, superseded by correction report 16 (text below kept as
> submitted). **Supersession:** its decision `native_bridge_viable_for_controlled_lineage` and its limits stand.
> On review of `b5b6c82` the architect required the pre-start lifecycle race closed (a termination
> between a request and its UI-thread start was not seen by the cancellation; correction report 16
> reserves the generation before the start is posted) and null per-key errors enforced for success
> and not_found. Its device totals (43/43, 43/43, 42/42) are superseded by correction report 16's
> reruns, and its lifecycle log order (`activity_destroy` before `godot_terminating`) reflected its
> UI-thread handling, not the order Godot delivers the two callbacks in.

Scope: the architect's review of `5f6d13b`, in one commit. Changed: the PCK smoke test
(`godot/tests/integration/test_export_pack.gd`, `godot/tests/automation/pck_probe.gd`, a new
source-only sentinel `godot/tests/automation/pck_source_only_sentinel.tres`), the throwaway M1 spike
under `/godot/platform/android/m1_migration_spike/`, FEATURE_MATRIX.md, this log and new evidence. No
gameplay, asset, PixiJS, Capacitor configuration or root `android/` file changed; no APK or keystore
is committed. The controlled-lineage decision and its production limits are unchanged.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); M1 migration spike executed and hardened, pending architect review; open M1 items: the manual checks; open M2 items: the rendered clauses of VIEW-004, CAM-004 and DOG-008a, and the manual desktop and touch play checks |
| Base | `5f6d13b` (progress report 14) |
| Current `godot/` tree | `cd8717124f23ef03e16ebb0e71a1d73ba628e39d`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2; Linux not rerun |
| Android | emulators only: `sv_m1_api36` (`emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137), `sv_m1_api34` (`emulator-5556`, Android 14 / API 34, WebView 113.0.5672.136), `sv_m1_api24` (`emulator-5558`, Android 7.0 / API 24, WebView provider Chrome 69.0.3497.100; system image installed for this correction, host GPU enabled in its AVD); no physical device |

### Changes per review item

1. **Hermetic PCK smoke.** The packed children (probe and 600-frame startup) now run with an empty,
   isolated `--path`, so no file of the checkout can answer a `res://` lookup. Before, they inherited
   the project directory as their working directory, and files missing from the pack resolved from
   disk (shown on `5f6d13b`'s exported pack: with the checkout as the working directory
   `res://tests/test_runner.gd` and the spike's harness scene resolved; with an empty one they did
   not). `_runtime_resources()` stops at any directory with a `.gdignore` and skips the
   development-only `platform/` tree; the probe checks a list of source-only paths that must not
   resolve (the new `tests/automation/pck_source_only_sentinel.tres` and every file under
   `platform/`); a control run with the checkout as `--path` must resolve them (the check can see a
   leak); the packed-file scan rejects `platform/` paths. Result on the fresh clone: **254** runtime
   resources (back from 257), **512** packed files, 32,905,976 bytes, all 18 source-only paths
   unresolved, the control resolving all 18. Mutation checks (working tree, reverted; not in the
   logs): without the isolated `--path` the test fails ("no source-only path (sentinel, 15 platform
   files) resolves in the hermetic packed run expected [], got [res://tests/automation/pck_source_only_sentinel.tres, res://platform/android/.gdignore, …]");
   without the `.gdignore` stop and the `platform/` skip it fails ("no development-only platform path
   in the expected runtime list").
2. **minSdk 24.** `WebView.getCurrentWebViewPackage()` (API 26) is called only on API 26+; below, the
   result has `webview_package: null` and the diagnostic `webview_package_unavailable` (the user
   agent carries the version). `getLongVersionCode()` (API 28) is guarded the same way. Every
   diagnostic is gathered behind a `Throwable` guard and emission itself cannot throw, so a
   diagnostic can never stop the raw read result. `tools/api_level_check.py` checks the compiled
   bytecode (every Android class, method and field in its constant pools, method-reference targets
   included) against the SDK's `api-versions.xml`: 66 references, all at API ≤ 24 except the two
   guarded calls; it runs inside `build_spike_apk.ps1` and fails without the guard list. minSdk stays
   24 (`aapt2`: `minSdkVersion:'24'`).
3. **Harness.** Every `_summarize()` path returns `keys`, `diagnostics` and `_values`; `_run()` uses
   safe dictionary access; malformed, empty, non-string and wrong-shape results (top level, status,
   `keys`, per-key entries and fields, status/presence mismatch) become `error` results with specific
   codes, parsed with `JSON.parse` (no engine error line); a watchdog and a single-finish guard give
   exactly one `M1_SPIKE_DONE`. `harness/m1_spike_harness_selftest.gd` runs it on the desktop
   against fake plugins: **27/27** (15 `_summarize` shapes; 12 whole runs incl. malformed, empty,
   non-string, wrong shape, plugin error, no reply, missing singleton, missing signal, missing method).
4. **Lifecycle cleanup.** The active read's WebView, timeout and generation are fields; Activity
   destruction (`onMainDestroy`) and Godot termination (`onGodotTerminating`) cancel the timeout and
   destroy the WebView on the UI thread and emit nothing; every late page request, `onPageFinished`
   or `evaluateJavascript` callback of a finished or cancelled generation is ignored. Tested on every
   emulator during an active (held, development-only) read: Godot quitting (cancelled by
   `godot_terminating`) and the Activity finishing (cancelled by `activity_destroy`; the later
   `godot_terminating` found no active read). Each time: teardown on thread `main`, no `emit`, no
   result reaching GDScript, no crash entry; where the process outlived the cancellation (API 36 both
   cases, API 34 the Activity case) the held page request returned later and was logged as ignored;
   a third run then read the identical values.
5. **Rerun.** The upgrade test ran on API 36, 34 and 24 from a fresh clone of this commit's code.
   On API 24 the old game's bundle cannot boot (Chrome 69: `Uncaught SyntaxError: Unexpected token .`,
   `device_api24/02_old_capacitor_logcat.txt`) while its page, origin `https://localhost` and storage
   work, so `-SeedMode direct` wrote the five strings the old game produced on API 36 with `setItem`
   in the old app's page (compatibility evidence for the plugin, not for the old game's own
   migration). The decision `native_bridge_viable_for_controlled_lineage` and its limits stand
   (`android_evidence/…/godot-tree-cd87171/DECISION.md`).
6. **Docs.** FEATURE_MATRIX.md: export evidence (hermetic smoke, 254/512), host verification and
   project-isolation row (this tree), the Android emulators, the legacy-save plan's M1 stage, the
   native-build and campaign-migration rows. This log: this report; progress report 14 historical with
   a supersession note.

### Controlled lineage and results

| APK | Package | versionCode | Certificate SHA-256 | APK SHA-256 |
|---|---|---|---|---|
| old Capacitor (unchanged, progress report 14) | `com.zampano.supervillained` | 1 | `034b187e…2191` | `0771cd78…a89d` |
| Godot spike (minSdk 24, no permissions) | `com.zampano.supervillained` | 2 | the same | `f1d68d11…` |
| spike, wrong key | `com.zampano.supervillained` | 2 | `b2df28e1…7a26` | `3244d870…` |
| spike, wrong package | `com.zampano.supervillained.m1negative` | 2 | `034b187e…2191` | `a201ebbf…` |

| Check | API 36 / WebView 133 | API 34 / WebView 113 | API 24 / Chrome 69 |
|---|---|---|---|
| old install, seeding (old boot migration; API 24: direct), values stable across a cold restart | pass | pass | pass |
| wrong-key update rejected, wrong package `not_found` | pass | pass | pass |
| `adb install -r`: versionCode 2, same firstInstallTime and certificate | pass | pass | pass |
| two spike processes × two reads: `success`, origin `https://localhost`, five raw values identical to the old app's | pass | pass | pass |
| termination during an active read (Godot quit, Activity finish), then a third identical run | pass | pass | pass |
| no production save; WebView storage present; fresh install `not_found` | pass | pass | pass |
| `webview_package` | object (API 26+) | object | `null` + diagnostic |
| **Total** | **43/43** | **43/43** | **42/42** |

### Commands executed and results

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (working tree, while writing the fix) | `PCK 32905976 bytes, 254 runtime resources checked, 512 packed files, 16 source-only paths unresolved (control resolved 16)`, `1 passed` (16 = the sentinel and the spike's 15 files at the time) |
| Mutation checks of that test (working tree, reverted) | fail without the isolated `--path` and without the `.gdignore` stop / `platform/` skip (messages in "Changes" above) |
| A throwaway probe on `5f6d13b`'s exported pack (`--main-pack`, working directory = checkout vs. empty, and `--path <empty>`) | from the checkout `res://tests/test_runner.gd` and the spike harness scene resolve; from an empty directory or `--path` they do not |
| `…/harness/m1_spike_harness_selftest.gd` (working tree) | `27 passed, 0 failed` |
| `tools/build_spike_apk.ps1` ×3 from a fresh clone of this commit's code (javac; `api_level_check.py`; JAR; scratch project; `godot --headless --install-android-build-template --export-debug Android`; `apksigner verify`; `aapt2 dump badging`) | exit 0 each; API-level check OK (66 references, 2 guarded); upgrade / wrong-key / wrong-package APKs ``f1d68d11…`` / ``3244d870…`` / ``a201ebbf…`` (SHA-256 prefixes), minSdk 24, no `uses-permission` |
| `tools/run_upgrade_test.ps1 -Serial emulator-5554` (API 36) | exit 0: **43/43** |
| `tools/run_upgrade_test.ps1 -Serial emulator-5556 -DevToolsPort 9334` (API 34) | exit 0: **43/43** |
| `tools/run_upgrade_test.ps1 -Serial emulator-5558 -DevToolsPort 9335 -SeedMode direct -DirectSeedValues <API 36 expected.json>` (API 24) | exit 0: **42/42** |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `cd8717124f23ef03e16ebb0e71a1d73ba628e39d` = `git rev-parse HEAD:godot` of this commit; only the docs and the evidence folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 + 55 outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING line |
| `… --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `<console exe> --headless --path godot --quit-after 600` (600-frame desktop launch) | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (hermetic PCK smoke) | exit 0: 32,905,976 bytes, **254** runtime resources, **512** packed files, 18 source-only paths unresolved, control resolved 18 |
| `… --script res://platform/android/m1_migration_spike/harness/m1_spike_harness_selftest.gd` | exit 0: **27 passed, 0 failed** |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after the checks); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| Secret scan of the evidence and of the commit (the two test keystore passwords, the local user name, the account e-mail) | no match; no APK, AAB, keystore, JAR or binary in the commit |
| `git diff --check` (working tree, final text) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 68 checks` |

Evidence: `docs/porting/android_evidence/m1_migration_spike/godot-tree-cd87171/` (REPORT.md,
DECISION.md, `builds/`, `device_api36/`, `device_api34/`, `device_api24/`, `dev_attempts/`,
`host_checks/`). Not run: Linux; a physical Android device; the game itself on the emulators; manual
play; listening to the audio.

Host evidence: current tree above. Previous Windows trees: `ef6c318` (progress report 14, 138
passed), `9bbe179` (correction report 12, 138 passed), `a06b1df` (correction report 11, 138 passed),
`1532143` (correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595`
(correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum, corrections 8 to 13, progress report 14 and this report.

### Development attempts (kept as found)

- Trials from the working tree: the API 24 AVD first had `hw.gpu.enabled=no`, so Godot could not
  create an OpenGL ES 3 context (`createContext failed`, the plugin's `godot_terminating: no active
  read`); with the host GPU (`-gpu host -feature GLESDynamicVersion`, OpenGL ES 3.1) the spike ran.
  The marker for a lifecycle test needs `files/`, which exists after a first launch (the device test
  runs it after the normal runs).
- Attempt 1 (tree `e69b0a2`, API 36): 40/43. The Activity-destroy case used the
  `always_finish_activities` setting and HOME; Android 16 did not destroy the Activity, the held read
  completed normally and the checks failed as they should. Replaced by the development-only
  `finishActivityForLifecycleTest()`, which runs the Activity's real `onDestroy`.
- Attempt 2 (tree `ea97dc6`): API 36 and 34 43/43; API 24 stopped at the certificate step: Android 7's
  `adb pull` cannot read `/data/app/…/base.apk` (fallback: copy through `/data/local/tmp`), and the
  WebView 69 profile keeps `Local Storage` directly under `app_webview` (diagnostic and listing
  updated). A dry run of the fixed script with those APKs passed 42/42 on API 24.
- Attempt 3 (tree `ad79fe0`): 43/43, 43/43, 42/42, but the API-level check read only `javap -c`
  references and missed the method-reference target `Activity::finish` (API 1); fixed to read the
  constant pools, and the device test now records the active WebView provider. Everything was rebuilt
  and rerun on this tree. Logs of attempts 1 and 2: `android_evidence/…/godot-tree-cd87171/dev_attempts/`.

### Legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed and hardened, pending architect review.** The native-bridge
   versus staged-Capacitor decision is unchanged: `native_bridge_viable_for_controlled_lineage`.
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on emulators (API 36, 34, 24) with a throwaway key (decision `native_bridge_viable_for_controlled_lineage`, pending architect review); physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Architect review of the M1 spike** (evidence and decision above).
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Rendered clauses of VIEW-004, CAM-004 and DOG-008a (M2):** a strengthened renderer-backed probe
  with the checks listed in TEST_PLAN.md (combined evidence), run at 30/60/90/120 FPS and accepted
  by the architect.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — progress report 14: M1 legacy-save migration spike (`5f6d13b`; M1 Partial, M2 Partial)

> Historical record of `5f6d13b`, superseded by correction report 15 (text below kept as
> submitted). **Supersession:** its decision `native_bridge_viable_for_controlled_lineage` and its limits stand.
> On review of `5f6d13b` the architect required a hermetic PCK smoke: the PCK smoke count of 257 and
> its explanation below are superseded (the packed probe resolved files outside the pack; with an
> isolated `--path` the count is back to 254), and a minSdk-24-safe plugin, a hardened harness and
> lifecycle cleanup; correction report 15 reran the upgrade test with them on API 36, 34 and 24.

Scope: the architect's M1 task on `f7cf91f`, the controlled Android legacy-save migration
feasibility spike, in one commit. New files only: the throwaway spike under
`/godot/platform/android/` (the committed Godot project ignores it through `.gdignore`) and its
evidence under `docs/porting/android_evidence/m1_migration_spike/godot-tree-ef6c318/`;
FEATURE_MATRIX.md and this log updated. No gameplay, test, tool, asset, PixiJS, Capacitor
configuration or root `android/` file changed. M3 and the stronger rendered probe were not started.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); M1 migration spike executed, pending architect review; open M1 items: the manual checks; open M2 items: the rendered clauses of VIEW-004, CAM-004 and DOG-008a, and the manual desktop and touch play checks |
| Base | `f7cf91f` (correction report 13) |
| Current `godot/` tree | `ef6c3188da5b9d9a8c2c836afa0119c54b9f7e50` (the `9bbe179` tree plus `platform/android/`), verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2; Linux not rerun |
| Android | emulators only: `sv_m1_api36` (`emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137) and `sv_m1_api34` (`emulator-5556`, Android 14 / API 34, WebView 113.0.5672.136; system image installed for this spike); no physical device |

### Decision

**`native_bridge_viable_for_controlled_lineage`** (`android_evidence/…/DECISION.md`). After a
genuine `adb install -r` upgrade (same package `com.zampano.supervillained`, same test certificate,
no uninstall, no data clearing), the Godot spike APK's native plugin read all five legacy keys with
raw values identical to the old Capacitor app's, on both emulators. Verified constraints: the same
application id and signing certificate; Capacitor's default WebView profile and origin
`https://localhost` (Capacitor 8.6.2 defaults, no `server` config); a WebView at runtime (no
network, no INTERNET permission); read-only `getItem` on the five keys. Not claimed: physical
devices, the production signing lineage, real user data, MIG-001–010 (M4/M9).

### What was built (`godot/platform/android/m1_migration_spike/`, README there)

- `native/src/com/zampano/svspike/MigrationSpikePlugin.java`: Godot Android v2 plugin
  `SvMigrationSpike`. On `readLegacyStore()` it creates a hidden WebView in the app's default
  profile, loads `https://localhost/__sv_m1_migration_spike__/read.html` served by request
  interception (every other request answered 404, nothing fetched), checks `location.origin`, calls
  `localStorage.getItem` for exactly the five prefixed keys and emits `legacy_read_completed(json)`:
  status (`success` / `not_found` / `error`), verified origin, per-key presence, raw string or null,
  per-key error, WebView package and version, UTC timestamp, diagnostics (whether the WebView profile
  existed before the read). No set/remove/clear, no LevelDB/SQLite access, no value parsing, no
  save. Errors: missing activity, busy, timeout, WebView unavailable, origin mismatch, storage
  unavailable, per-key error.
- `editor/`: an editor/export plugin that adds the compiled JAR to Android gradle builds and its
  `org.godotengine.plugin.v2.SvMigrationSpike` manifest entry.
- `harness/`: the spike APK's main scene. Checks the singleton and its signal, reads twice, prints
  `M1_SPIKE_*` logcat lines (the plugin's raw JSON in base64 chunks, per-key SHA-256, idempotence,
  final status), quits; driven by `adb shell am start` without touch input.
- `tools/`: test keystores outside the repo, the old Capacitor APK from a clean clone, the spike APK
  from a scratch copy of `godot/` (javac, `--install-android-build-template --export-debug`), the
  device test (`run_upgrade_test.ps1`), a DevTools/logcat tool and the old-app page scripts.

### Controlled lineage and results

| APK | Package | versionCode | Certificate SHA-256 |
|---|---|---|---|
| old Capacitor (stock `debug` variant from a clean clone of `f7cf91f`, re-signed) | `com.zampano.supervillained` | 1 | `034b187e0b72e1567af589678c888f03dd48e58d4a920a13e9a08ace512d2191` |
| Godot spike (gradle build, debug export; no permissions) | `com.zampano.supervillained` | 2 | the same |
| spike, wrong key (negative) | `com.zampano.supervillained` | 2 | `b2df28e1e40cefe5918371dc1228976e5ee796f3f7a9bdb920bb3b06def97a26` |
| spike, wrong package (negative) | `com.zampano.supervillained.m1negative` | 2 | `034b187e…2191` |

The old app's page wrote settings (non-default audio, text speed, lives and every control), a
`level1` record and coins, and a version-1 campaign; its own boot migrated the campaign (v2 under
`story`, the v1 save under `story-v1-backup`). Expected SHA-256 after a cold restart (identical on
both emulators): settings `bcdce149…5427`, records `00b8ac69…a308`, coins `73475cb4…8049`, story
`6e7b6d6e…5f5d`, story-v1-backup `54677975…b084` (full values and hashes in the evidence REPORT.md).

| Check | API 36 / WebView 133 | API 34 / WebView 113 |
|---|---|---|
| old install, seeding through the old runtime, exactly five keys, values stable across a cold restart | pass | pass |
| wrong-key update rejected (`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), old app untouched | pass | pass |
| wrong package beside the old store: `not_found` | pass | pass |
| `adb install -r`: versionCode 2, same firstInstallTime, same certificate | pass | pass |
| two spike processes × two reads: `success`, origin `https://localhost`, all five raw values identical to the old app's | pass | pass |
| no production save written; WebView `Local Storage` still present | pass | pass |
| fresh install after uninstall: `not_found`, no profile before the first read | pass | pass |
| **Total** | **30/30** | **30/30** |

### Commands executed and results (Windows 11 and the two emulators)

| Command | Result |
|---|---|
| `tools/new_test_keystores.ps1` (keystores outside the repository) | exit 0: two PKCS12 test keys; passwords kept in a local file, never printed or committed (no log contains them) |
| `tools/build_old_capacitor_apk.ps1` (clean clone of `f7cf91f`: `npm ci`, `npm run build`, `npx cap sync android`, `gradlew assembleDebug`, `apksigner sign` with the test key, `apksigner verify`, `aapt2 dump badging`) | exit 0 (second run, see "Development attempts"): `com.zampano.supervillained` versionCode 1, v2+v3 signatures, certificate `034b187e…2191`; the sync changed only the generated `capacitor.build.gradle` / `capacitor.settings.gradle` of that clone; Gradle fetched build-tools 35.0.0 into the portable SDK |
| `tools/build_spike_apk.ps1` ×3 from a fresh clone of this commit's code (javac `--release 17`, warnings only for the Godot library's Kotlin metadata; JAR; scratch project; `godot --headless --import`; `godot --headless --install-android-build-template --export-debug Android`; `apksigner verify`; `aapt2 dump badging`) | exit 0 each: the upgrade, wrong-key and wrong-package APKs (277 MB each: debug engine libraries for x86_64, arm64-v8a and armeabi-v7a), versionCode 2, no `uses-permission` |
| `tools/run_upgrade_test.ps1 -Serial emulator-5554` (API 36 / WebView 133) | exit 0: **30/30 checks** |
| `tools/run_upgrade_test.ps1 -Serial emulator-5556 -DevToolsPort 9334` (API 34 / WebView 113) | exit 0: **30/30 checks** |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `ef6c3188da5b9d9a8c2c836afa0119c54b9f7e50` = `git rev-parse HEAD:godot` of this commit; only the docs and the evidence folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: 206 outputs identical (72 copies); 55 build_resources outputs identical |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING line |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `<console exe> --headless --path godot --quit-after 600` (600-frame desktop launch) | exit 0, engine banner only |
| `… --suite integration --file test_export_pack` (Android-preset PCK smoke) | exit 0: PCK 32,905,976 bytes and 512 packed files (both unchanged); 257 runtime resources checked (254 before: the test's DirAccess walk also lists the spike's three ignored Godot files; an `--export-pack Android` of the same clone contains no `platform/android` path, so the packed probe resolved them outside the pack, a limit of that existing check, left unchanged) |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after the checks); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat f7cf91f HEAD -- src android public capacitor.config.ts package.json package-lock.json godot/tests godot/tools godot/project.godot godot/export_presets.cfg godot/main godot/scenes godot/autoload godot/entities godot/world godot/iso godot/systems godot/core godot/data godot/assets docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (before the docs were written) | empty: only `godot/platform/android/` was added |
| `git diff --check` (working tree, final text) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 63 checks` |

Evidence: `docs/porting/android_evidence/m1_migration_spike/godot-tree-ef6c318/` (REPORT.md,
DECISION.md, `builds/`, `device_api36/`, `device_api34/`, `dev_attempts/`, `host_checks/`). Not run:
Linux; a physical Android device; the game itself on the emulators; manual play; listening to the
audio.

Host evidence: current tree above. Previous Windows trees: `9bbe179` (correction report 12, 138
passed), `a06b1df` (correction report 11, 138 passed), `1532143` (correction report 10, 137 passed),
`6a3c53b` (correction report 9, 137 passed), `b1c3595` (correction report 8, 137 passed), `b8535ab`
(correction report 7 addendum, 137 passed), `81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`
(correction report 6, 134 passed). Linux: the prior tree `d12bedd`, 128 passed (progress report 5).
Correction 6 was not rerun on Linux, and neither were correction 7's addendum, corrections 8 to 13
and this report.

### Development attempts (kept as found)

- The old APK's first build failed in Gradle ("Unable to establish loopback connection", Java on
  this host); with `-JavaTmpDir` the second build succeeded.
- Trial builds from the working tree: `has_method()` does not list a Java singleton's methods, so
  the harness checks the signal and lets the call fail instead.
- Attempt 1 (tree `f80ebd6`, API 36): 27/29. Every read's raw values matched, but Godot's Android
  logger cut the harness's summary line at 1023 characters, so the per-key hash check failed. Fixed:
  per-key lines plus a truncation check.
- Attempt 2 (tree `e285294`, API 36): 28/29. All reads matched; pulling the 277 MB installed APK
  back for the certificate check failed once (adb exit 1). Fixed: retry with logging.
- Final tree `ef6c318`: 30/30 on both emulators. Logs of attempts 1 and 2:
  `android_evidence/…/dev_attempts/`.

### Legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike: executed, pending architect review.** The native-bridge versus
   staged-Capacitor decision is the one above; it does not claim production viability.
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005 (raw five-key payload written exactly with timestamp and SHA-256 before any parsing).
3. **M9 — production proof:** the installed lineage and signing certificate, representative real
   user data, two WebView/device versions, end-to-end MIG-001–010. Audit note: the repository's
   Capacitor `release` build type signs with the builder's debug signing config, so updating installed
   copies in place needs that same key.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017) and the M1 spike found the native bridge viable for a controlled lineage. Remaining: the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005; the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | M1 migration spike done on two emulators with a throwaway key (decision `native_bridge_viable_for_controlled_lineage`, pending architect review); physical devices and the production lineage are M9 |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Architect review of the M1 spike** (evidence and decision above).
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Rendered clauses of VIEW-004, CAM-004 and DOG-008a (M2):** a strengthened renderer-backed probe
  with the checks listed in TEST_PLAN.md (combined evidence), run at 30/60/90/120 FPS and accepted
  by the architect.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 13: accepted command evidence, ARCH-001a review confirmed, totals (`f7cf91f`; M1 Partial, M2 Partial)

> Historical record of `f7cf91f`, superseded by progress report 14 (text below kept as
> submitted). **Supersession:** its decisions and totals stand. Its "open M1 blocker: the
> migration-plugin spike" is superseded: progress report 14 executed the spike on two emulators
> (decision `native_bridge_viable_for_controlled_lineage`, pending architect review); M1 stays
> Partial for its manual checks.

Scope: the architect's review of `46d7ad9`, in one documentation-only commit
(`docs/porting/FEATURE_MATRIX.md`, `TEST_PLAN.md` and this log). No gameplay, test, tool, asset,
PixiJS or evidence file changed, and the rendered-ID status is unchanged. The `godot/` tree is still
`9bbe179546b3b600340eebe26fc364d64abd933c`, verified on a fresh Windows clone in correction report 12;
no engine command was rerun for this documentation commit.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); open M1 blocker: the migration-plugin spike; open M2 items: the rendered clauses of VIEW-004, CAM-004 and DOG-008a, and the manual desktop and touch play checks |
| Base | `46d7ad9` (correction report 12) |
| Current `godot/` tree | `9bbe179546b3b600340eebe26fc364d64abd933c`, unchanged; verified on a fresh Windows clone in correction report 12 |
| Host | Windows 11 Pro N for Workstations 25H2; documentation checks only |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Architect decisions recorded (review of `46d7ad9`)

- **Slice legend:** a row is Slice when its listed IDs are supported by full-suite cases,
  architect-accepted combined evidence or architect-accepted command evidence.
- **CORE-001 accepted as command-level evidence:** the clean import and the 600-frame headless
  launch on the current Windows fresh clone (correction report 12, `godot/` `9bbe179`); the prior
  Linux evidence (`d12bedd`) is supplemental support. The project-isolation row is Slice.
- **Accepted totals:** 92 full-suite + 1 combined + 2 command = **95**.
- **ARCH-001a's named static review** is the architect's review of `f580fa4`, and it is confirmed.
- VIEW-004, CAM-004 and DOG-008a stay Partial (rendered clauses open; the probe is supplemental).

### Changes

1. **FEATURE_MATRIX.md:**
   - the Slice legend and the claiming rule name full-suite cases, architect-accepted combined
     evidence and architect-accepted command evidence (AST-019 and CORE-001);
   - ARCH-001a's static part names the architect's review of `f580fa4` as confirmed (status
     section and shared-world row);
   - command evidence: CORE-001 counted as satisfied, citing the correction-12 Windows clean
     import and 600-frame launch logs, with the Linux `d12bedd` clone as supplemental support;
     AST-019 marked accepted;
   - totals: **95 (92 full suite + 1 combined + 2 command)**, superseding 94;
   - project-isolation row: Partial → **Slice**, no gap.
2. **TEST_PLAN.md:** the case-naming rule also admits architect-accepted command evidence
   (currently CORE-001 and AST-019); the combined-evidence rule records the ARCH-001a static review
   as the architect's review of `f580fa4`, confirmed on review of `46d7ad9`.
3. **This log:** this report; correction report 12 marked historical with a supersession note.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated acceptance IDs

| ID | Status | Evidence |
|---|---|---|
| ARCH-001a | **satisfied (combined)** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` + the named static review: the architect's review of `f580fa4`, confirmed on review of `46d7ad9` (no duplicate playable/input movement controller) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` |
| DOG-005a | **satisfied** | `test_DOG_005a_…` |
| VIEW-004 | Partial | `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`; open: the rendered streak, double-interpolation and shimmer clauses (the probe is supplemental) |
| CAM-004 | Partial | whole-pixel origin in `test_CAM_002_…` and `test_P_VIEW_004_…`; open: the rendered static-shimmer clause (the probe is supplemental) |
| DOG-008a | Partial | `test_CORE_002_…` (spawn, teleport, camera snap, hook defaults); restart-reset subclause **satisfied** by `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`; open: the rendered 30/60/90/120 FPS presentation (the probe is supplemental) |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

Documentation checks only; no engine, Node or asset command was run for this commit (the `godot/`
tree is unchanged).

| Command | Result |
|---|---|
| Fresh `git clone` of this commit's documentation (`core.autocrlf=true`; only this results table and the check count were written after it) | exit 0; `git rev-parse HEAD:godot` = `9bbe179546b3b600340eebe26fc364d64abd933c` (unchanged) |
| `git status --porcelain` (fresh clone, before and after the checks) | empty |
| `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --name-only 46d7ad9 HEAD` | `docs/porting/FEATURE_MATRIX.md`, `docs/porting/IMPLEMENTATION_LOG.md`, `docs/porting/TEST_PLAN.md` |
| `git diff --stat 46d7ad9 HEAD -- godot src docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures docs/porting/MILESTONES.md` | empty: gameplay, tests, tools, assets, the PixiJS source and the evidence files unchanged |
| `git diff --check` (working tree, final text) | clean |
| `python docs_consistency_check.py` (session tool, not committed; final text) | `OK: 58 checks` |

Host evidence: current `godot/` tree `9bbe179` (correction report 12, 138 passed), unchanged by this
documentation commit. Previous Windows trees: `a06b1df` (correction report 11, 138 passed),
`1532143` (correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed),
`b1c3595` (correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed),
`81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the
prior tree `d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and
neither were correction 7's addendum and corrections 8, 9, 10, 11 and 12.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Rendered clauses of VIEW-004, CAM-004 and DOG-008a (M2):** a strengthened renderer-backed probe
  with the checks listed in TEST_PLAN.md (combined evidence), run at 30/60/90/120 FPS and accepted
  by the architect. Until then the three IDs stay Partial and are not counted.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 12: rendered IDs back to Partial, ARCH-001a combined evidence, totals (`46d7ad9`; M1 Partial, M2 Partial)

> Historical record of `46d7ad9`, superseded by correction report 13 (text below kept as
> submitted). **Supersession:** on review of `46d7ad9` the architect accepted CORE-001 as
> command-level evidence (the project-isolation row is Slice; the Linux `d12bedd` clone is
> supplemental support), confirmed that ARCH-001a's named static review is the architect's review
> of `f580fa4`, and set the accepted total to 95 (92 full suite + 1 combined + 2 command),
> superseding 94. Its Windows evidence for the `godot/` tree `9bbe179` stands, and VIEW-004, CAM-004
> and DOG-008a remain Partial.

Scope: the architect's review of `f580fa4`, in one evidence-correction commit. The code changes are
comments in two test files (`godot/tests/integration/test_main_and_rates.gd`, `test_world.gd`); no
assertion, gameplay module, restart flow, movement, collision, camera, `PlayableDog`, animation,
audio, save, asset-pipeline, tool (the rendered probe included) or PixiJS file changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither milestone completion accepted); open M1 blocker: the migration-plugin spike; open M2 items: the rendered clauses of VIEW-004, CAM-004 and DOG-008a, and the manual desktop and touch play checks |
| Base | `f580fa4` (correction report 11) |
| Current `godot/` tree | `9bbe179546b3b600340eebe26fc364d64abd933c`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Architect decisions recorded (review of `f580fa4`)

- The acceptance of `tools/interpolation_probe.gd` as satisfying the rendered clauses of VIEW-004,
  CAM-004 and DOG-008a is withdrawn. The three IDs are **Partial** again and the probe's runs are
  **supplemental command evidence**. DOG-008a's restart-reset subclause stays satisfied.
- A probe closes them only with renderer-backed checks: exactly one connected dog component per
  frame; stable dog bounding-box dimensions, shape and pixel intensity, so a trail is rejected;
  total displacement over elapsed time compared with the expected speed tightly enough to reject
  sustained double interpolation; each static marker's absolute centroid, bounding box and pixel
  pattern; an intentional fractional-camera negative control proving shimmer detection; 30/60/90/120
  FPS; and the first rendered frame after spawn, camera snap and restart where required.
- ARCH-001a is classified as **combined evidence**: the automated dummy-host case plus the
  architect's named static review confirming no duplicate playable controller.
- AST-019 is counted consistently as command evidence; "nothing accepted" becomes "neither
  milestone completion accepted".

### Changes

1. **VIEW-004, CAM-004 and DOG-008a back to Partial.** The review allows either a strengthened probe
   or leaving the IDs partial; this correction leaves them partial and does not change the probe.
   Their suite parts are unchanged: `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`; the
   whole-pixel camera origin in `test_CAM_002_camera_clamps_small_and_large_maps` and
   `test_P_VIEW_004_…`; for DOG-008a, `test_CORE_002_logic_independent_of_render_rate` (spawn,
   teleport and camera-snap resets, shipped test-hook defaults) and
   `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, which keeps the
   **restart-reset subclause satisfied**. Open: the rendered clauses (VIEW-004: no streak, double
   interpolation or static shimmer at 30/60/90/120 FPS; CAM-004: no static shimmer; DOG-008a: the
   30/60/90/120 FPS presentation without streaks, including the first rendered frame after spawn,
   camera snap and restart where required). TEST_PLAN.md lists the probe checks above as the
   condition for closing them. The probe's run on this tree is recorded below as supplemental
   command evidence.
2. **Restart case wording.** The case's comments now say that the replacement dog and camera reset
   physics interpolation in the entry process frame (the process frame in which they enter the
   tree), before the test's next awaited frame. The case reads back no rendered frame or pixel
   (no `frame_post_draw` or pixel-readback assertion), so correction report 11's "before that frame
   is drawn" is withdrawn. Its assertions are unchanged.
3. **ARCH-001a on combined evidence.** TEST_PLAN.md's combined-evidence rule now has two forms: a
   named architect static review for a static code-review requirement, or an architect-accepted
   renderer-backed probe for rendered clauses (none is accepted). ARCH-001a =
   `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (dummy host scene, shared classes and
   public interfaces, chapter environment resources, `IsoGrid`/`IsoDepthSorter`, tick-for-tick
   movement, recursive cleanup) + the architect's static review of `f580fa4` (no duplicate
   playable/input movement controller). The case's comment says so.
4. **Totals.** 92 IDs by full suite cases (ARCH-001a moved out of that list) + 1 on combined
   evidence (ARCH-001a) + 1 on command evidence (AST-019) = **94**. VIEW-004, CAM-004 and DOG-008a
   are not counted until their rendered clauses pass. Correction report 11's 96 (93 + 3) counted the
   three rendered IDs and left AST-019 out of the total.
5. **"Nothing accepted".** This report says "neither milestone completion accepted"; the
   introduction of this log carries the erratum for the historical reports' "nothing accepted".
6. **FEATURE_MATRIX.md rows.** The viewport, camera and state-controller rows name their open
   rendered clauses (camera and state controller back to Partial); the shared-world row names the
   static review; the project-isolation row and the host verification name this tree.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated acceptance IDs

| ID | Status | Evidence |
|---|---|---|
| ARCH-001a | **satisfied (combined)** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` + the architect's static review of `f580fa4` (no duplicate playable/input movement controller) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` |
| DOG-005a | **satisfied** | `test_DOG_005a_…` |
| VIEW-004 | Partial | `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering`; open: the rendered streak, double-interpolation and shimmer clauses (the probe is supplemental) |
| CAM-004 | Partial | whole-pixel origin in `test_CAM_002_…` and `test_P_VIEW_004_…`; open: the rendered static-shimmer clause (the probe is supplemental) |
| DOG-008a | Partial | `test_CORE_002_…` (spawn, teleport, camera snap, hook defaults); restart-reset subclause **satisfied** by `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`; open: the rendered 30/60/90/120 FPS presentation (the probe is supplemental) |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case ARCH_001a`, then `--case DOG_008a` (working tree, after the comment edits) | `1 passed, 0 failed` each |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `9bbe179546b3b600340eebe26fc364d64abd933c` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (deterministic asset check, AST-019) | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `… --suite all --case ARCH_001a` (focused, fresh clone) | exit 0: `PASS test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `1 passed, 0 failed` |
| `… --suite all --case DOG_008a` (focused restart case, fresh clone) | exit 0: `PASS test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, `1 passed, 0 failed`; recorded resets: the dog entered in process frame 549 with resets at (0, 0) (its `_ready`, before placement), then (0, 1448) twice (spawn placement, camera snap); the camera entered in process frame 549 with one reset at (0, 1328) (snapped spawn view, view 216×432); all in the entry process frame, before the test's next awaited frame (no rendered frame read back) |
| `<console exe> --headless --path godot --quit-after 600` (600-frame Main launch) | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (Android-preset PCK smoke) | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --rendering-driver opengl3 --disable-vsync --script res://tools/interpolation_probe.gd` (unchanged probe, VSync off, RTX 3090; supplemental) | exit 0 (table below) |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device; run by the same script) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after every other step); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat f580fa4 HEAD -- godot` | only `godot/tests/integration/test_main_and_rates.gd` and `godot/tests/integration/test_world.gd` |
| `git diff -U0 f580fa4 HEAD -- godot`, changed lines that are not `#` / `##` comments | none: comments only, no assertion changed |
| `git diff --stat f580fa4 HEAD -- godot/tests/support godot/entities godot/world godot/iso godot/main godot/scenes godot/autoload godot/systems godot/core godot/tools godot/data godot/assets src docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (before the new log folder was added) | empty: runtime code, the restart flow, the dummy Story host, tools (the probe included), assets, the PixiJS source and historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 55 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-12-godot-tree-9bbe179/`. Not
run: Linux; Android device or emulator; manual play; listening to the audio.

### Rendered interpolation probe (supplemental command evidence; current tree, VSync off, RTX 3090)

`tools/interpolation_probe.gd` (unchanged since correction report 11) on the fresh clone of the
current tree, OpenGL 3.3 Compatibility on the NVIDIA GeForce RTX 3090 (driver 610.47),
`--disable-vsync`, 432×432 window; exit 0. **Supplemental command evidence**: it satisfies no
rendered clause (TEST_PLAN.md combined evidence lists the checks a probe needs for that) and is not
a suite result.

| Run | FPS cap | Achieved FPS | Repeated frames | Max px/frame (expected) | Teleport error px | ok |
|---|---|---|---|---|---|---|
| interpolation on | 30 | 30.0 | 0 | 6.5 (5.66) | 3.5 | true |
| interpolation on | 60 | 60.0 | 0 | 3.5 (2.83) | 0.5 | true |
| interpolation on | 90 | 90.0 | 0 | 2.5 (1.88) | 1.0 | true |
| interpolation on | 120 | 119.4 | 0 | 2.0 (1.42) | 1.0 | true |
| control, interpolation off | 120 | 119.9 | **21** (expected above 60 FPS) | 3.0 (1.42) | 1.0 | false by design |

Moving `CameraRig`, static markers: one distinct marker gap, 40 px, on all 48 measured frames at
90 and at 120 FPS (`ok: true` both). What this probe measures: the midpoint of the dog's bright-pixel
horizontal extent in a fixed band (repeated frames, the largest per-frame step, the teleport error)
and the gap between the two static markers' column runs. It does not check the items the architect
listed for closing the rendered clauses: one connected dog component, a stable dog bounding box,
shape and intensity, total displacement over elapsed time, each marker's absolute centroid,
bounding box and pattern, a fractional-camera negative control, and the first rendered frame after
spawn, camera snap and restart.

Host evidence: current tree above. Previous Windows trees: `a06b1df` (correction report 11, 138
passed), `1532143` (correction report 10, 137 passed), `6a3c53b` (correction report 9, 137 passed),
`b1c3595` (correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137 passed),
`81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the
prior tree `d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and
neither were correction 7's addendum and corrections 8, 9, 10, 11 and 12.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Rendered clauses of VIEW-004, CAM-004 and DOG-008a (M2):** a strengthened renderer-backed probe
  with the checks listed above (TEST_PLAN.md combined evidence), run at 30/60/90/120 FPS and accepted
  by the architect. Until then the three IDs stay Partial and are not counted.
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.

### Architect review result

Pending.

---

## Historical — correction report 11: architect decisions, real restart coverage, gate removal (`f580fa4`; M1 Partial, M2 Partial)

> Historical record of `f580fa4`, superseded by correction report 12 (text below kept as
> submitted). **Supersession:** on review of `f580fa4` the architect withdrew the acceptance of the
> rendered probe for the rendered clauses of VIEW-004, CAM-004 and DOG-008a: the three IDs are
> Partial again and the probe is supplemental command evidence, so the "Architect decisions
> recorded" below, the "satisfied (combined)" rows, "No automated M2 acceptance ID remains
> unsatisfied" and the total of 96 are superseded (correction report 12: 94, with AST-019 counted
> as command evidence). DOG-008a's restart-reset subclause stays satisfied. ARCH-001a is combined
> evidence (its case plus the architect's static review of `f580fa4`). The restart case's "before
> that frame is drawn" is restated as "in the entry process frame, before the test's next awaited
> frame": the case reads back no rendered frame or pixel. "Nothing accepted" means that neither
> milestone completion was accepted.

Scope: the architect's decisions and required changes on `6b91fd3`, in one commit. Code changes
are in two test files (`godot/tests/integration/test_world.gd`, `test_main_and_rates.gd`); no
gameplay module, movement, collision, camera, `PlayableDog`, animation, audio, save, asset-pipeline
or PixiJS file changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); open M1 blocker: the migration-plugin spike; open M2 items: the manual desktop and touch play checks |
| Base | `6b91fd3` (correction report 10) |
| Current `godot/` tree | `a06b1df5e3db91f0fc7690785d94932fdf6bca24`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Architect decisions recorded (review of `6b91fd3`)

- The current-tree rendered interpolation probe (`tools/interpolation_probe.gd`) was rerun
  independently on an RTX 3090 with VSync disabled and passed at 30/60/90/120 FPS. It is accepted as
  **command-level rendered evidence** (TEST_PLAN.md "Combined evidence"): **VIEW-004** and
  **CAM-004** are accepted; DOG-008a's rendered presentation and teleport-reset clauses are
  accepted, and DOG-008a was left incomplete only for the missing real restart-path assertion.
- **AST-007 / finding F-15 accepted:** the sword and shield are baked into the armoured frames, so
  shared frame and foot-anchor alignment is the applicable contract.
- The rendered clauses did not run in the headless suite; the matrix and this report name the probe
  for them.

### Changes

1. **Source-parser gate removed.** `_code_only()`, `_matches()`, `_duplicate_player_controllers()`,
   their synthetic source samples, the repository-wide source scan and its positive control are gone
   from `test_world.gd`. "No duplicate playable/input movement controller" is now a static
   code-review requirement (TEST_PLAN.md ARCH-001, ARCH-001a): only `PlayableDog` turns player input
   into movement; `ActorBody` controllers (NPCs, cats, Bagnaskiz, companions, combat actors) may use
   approved behaviour controllers with the shared `WorldMapModel` solver. Kept in
   `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`: the real dummy Story host scene;
   the shared `IsoWorld`, `PlayableDog` and `CameraRig` scenes, scripts and public interfaces; the
   host's distinct chapter environment resources; `IsoGrid` placement and `IsoDepthSorter` ranking;
   tick-for-tick movement equivalence; lifecycle and cleanup, now checked recursively (every
   descendant of the host, world, dog and camera included, is freed).
2. **Real restart coverage for DOG-008a:**
   `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state` (in `test_main_and_rates.gd`)
   uses only the shipped flow. Main starts the Green Zone with its real ticks and briefing; Enter
   (a key event) closes the briefing; the dog walks on `InputService` movement in real 60 Hz physics
   ticks and pees (Space), so the dog and the camera have interpolation history; Esc opens the pause
   menu; Down and Enter choose RESTART, whose `restart_requested` reaches `Main.start_green_zone`
   (the existing deferred scene replacement). No replacement dog is created by the test and there
   is no test-only gameplay path. It verifies:
   - the old scene, dog, camera and pause menu are freed; one scene, one `PlayableDog` and one
     `CameraRig` remain, the replacement camera is current and only the new briefing is shown;
   - the replacement dog starts at the canonical spawn (`GreenZoneLevel` start, exact grid
     coordinates and spawn pixel), at rest;
   - interpolation: an observation-only child node added as each replacement dog and camera enters
     the tree records every `NOTIFICATION_RESET_PHYSICS_INTERPOLATION` with its process frame and
     position. Both reset in the process frame in which they enter the tree, before that frame is
     drawn; the dog's last reset is at the spawn pixel and the camera's at the snapped spawn view;
     no reset of either is at the old run's position; the runtime reset counters agree; the dog then
     stays on the spawn pixel under the briefing;
   - nothing of the old run survives: fresh stats (`ScoringRules.new_stats` with the settings'
     lives), all 30 treats, playing state, full bladder, start hunger and energy, an unpolluted map,
     the briefing music;
   - settings persist: non-default volume, text speed, lives, run toggle and left hand are
     unchanged in `SaveService` and `AppState`, still applied to `InputService` and `AudioService`,
     and the lives setting drives the new run's speed; the selected profile is kept.
   Mutation check (working tree, reverted before the commit; not in the logs): without the dog's
   placement and camera-snap resets the case fails ("dog: last entry-frame reset at the spawn view
   expected (0.0, 1448.0), got (0.0, 0.0)"); without the camera snap's reset it fails ("camera:
   interpolation reset in its entry frame … ([])").
3. **Evidence wording.** TEST_PLAN.md: the combined-evidence rule (a rendered clause may be
   satisfied by an architect-accepted command-level probe; every other clause by named suite cases;
   rendered clauses never presented as suite results); ARCH-001/ARCH-001a state the code-review
   requirement. FEATURE_MATRIX.md: VIEW-004, CAM-004 and DOG-008a satisfied on combined evidence
   (96 IDs in total), the probe listed as accepted command-level evidence, AST-007/F-15 accepted,
   the viewport, camera, state-controller and shared-world rows updated.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated acceptance IDs

| ID | Status | Evidence |
|---|---|---|
| ARCH-001a | **satisfied** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (no duplicate controller: static code-review requirement) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` |
| DOG-005a | **satisfied** | `test_DOG_005a_…` |
| VIEW-004 | **satisfied (combined)** | `test_P_VIEW_004_whole_pixel_world_and_nearest_filtering` + the accepted rendered probe |
| CAM-004 | **satisfied (combined)** | whole-pixel origin in `test_CAM_002_…` and `test_P_VIEW_004_…` + the probe's static-shimmer pass |
| DOG-008a | **satisfied (combined)** | `test_CORE_002_…` (spawn, teleport, camera snap, hook defaults) + `test_P_DOG_008a_main_restart_resets_interpolation_and_run_state` (restart) + the accepted probe (presentation, teleport) |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case DOG_008a` (working tree, while writing it) | after two test-side fixes (the selection was read one frame early; a lambda held the freed old scene): `1 passed, 0 failed` |
| Mutation check of that case (working tree; runtime files restored and confirmed by `git status` before the commit) | fails without the dog's placement and camera-snap resets, and fails without the camera snap's reset (messages in "Changes" above) |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` (working tree) | `138 passed, 0 failed, 138 total` |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `a06b1df5e3db91f0fc7690785d94932fdf6bca24` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (deterministic asset check) | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **138 passed, 0 failed, 138 total** |
| `… --suite all --case ARCH_001a` (focused, fresh clone) | exit 0: `PASS test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `1 passed, 0 failed` |
| `… --suite all --case DOG_008a` (focused restart case, fresh clone) | exit 0: `PASS test_P_DOG_008a_main_restart_resets_interpolation_and_run_state`, `1 passed, 0 failed`; recorded resets: dog entered frame 553 with resets at (0, 0) (its `_ready`, before placement), then (0, 1448) twice (spawn placement, camera snap); camera entered frame 553 with one reset at (0, 1328) (snapped spawn view, view 216×432) |
| `<console exe> --headless --path godot --quit-after 600` (600-frame Main launch) | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (Android-preset PCK smoke) | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --rendering-driver opengl3 --disable-vsync --script res://tools/interpolation_probe.gd` (rendered probe, VSync off, RTX 3090) | exit 0 (table below) |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device; run by the same script) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 30 files, 248 tests passed; build OK |
| `git status --porcelain` (before and after every other step); `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat 6b91fd3 HEAD -- godot` | only `godot/tests/integration/test_main_and_rates.gd` and `godot/tests/integration/test_world.gd` |
| `git diff --stat 6b91fd3 HEAD -- godot/tests/support godot/entities godot/world godot/iso godot/main godot/scenes godot/autoload godot/systems godot/core godot/tools godot/data godot/assets src docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (before the new log folder was added) | empty: runtime code, the dummy Story host, tools, assets, the PixiJS source and historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 51 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-11-godot-tree-a06b1df/`. Not
run: Linux; Android device or emulator; manual play; listening to the audio.

### Rendered interpolation probe (current tree, VSync off, RTX 3090)

`tools/interpolation_probe.gd` on the fresh clone of the current tree, OpenGL 3.3 Compatibility on the
NVIDIA GeForce RTX 3090 (driver 610.47), `--disable-vsync`, 432×432 window; exit 0. Command-level
rendered evidence, not a suite result.

| Run | FPS cap | Achieved FPS | Repeated frames | Max px/frame (expected) | Teleport error px | ok |
|---|---|---|---|---|---|---|
| interpolation on | 30 | 30.0 | 0 | 6.5 (5.65) | 4.5 | true |
| interpolation on | 60 | 60.0 | 0 | 3.5 (2.83) | 1.5 | true |
| interpolation on | 90 | 90.2 | 0 | 2.5 (1.88) | 1.0 | true |
| interpolation on | 120 | 120.0 | 0 | 2.5 (1.41) | 1.0 | true |
| control, interpolation off | 120 | 120.0 | **21** (expected above 60 FPS) | 3.0 (1.41) | 1.0 | false by design |

Moving `CameraRig`, static markers: one distinct marker gap, 40 px, on all 48 measured frames at
90 and at 120 FPS (`ok: true` both). No repeated frame (stutter or streak), no jump beyond two
frames' worth (double interpolation), the teleport shows the new position at once, and the control
proves the metric detects repeats.

Host evidence: current tree above. Previous Windows trees: `1532143` (correction report 10, 137
passed), `6a3c53b` (correction report 9, 137 passed), `b1c3595` (correction report 8, 137
passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum and corrections 8, 9, 10 and 11.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- No automated M2 acceptance ID remains unsatisfied.

### Architect review result

Pending.

---

## Historical — correction report 10: ARCH-001a static gate and collision-row wording (`6b91fd3`; M1 Partial, M2 Partial)

> Historical record of `6b91fd3`, superseded by correction report 11 (text below kept as
> submitted). **Supersession:** on review of `6b91fd3` the architect replaced its ARCH-001a static
> source-parser gate with a static code-review requirement (the gate's code is removed), accepted
> the rendered probe for VIEW-004 and CAM-004 and for DOG-008a's rendered presentation and
> teleport-reset clauses, and accepted AST-007 / finding F-15. Its "Unsatisfied automated M2
> gates" list (VIEW-004, CAM-004 pending the gate decision; DOG-008a) is superseded: VIEW-004 and
> CAM-004 are satisfied on combined evidence, and DOG-008a on combined evidence with the real
> restart case added in correction report 11.

Scope: the architect's two items on `d7933a7`, in one commit. Code changes are in one test file
(`godot/tests/integration/test_world.gd`: the ARCH-001a gate and its synthetic cases); no gameplay
module, no PixiJS file, and neither the dummy Story host scene nor its lifecycle changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); open M1 blocker: the migration-plugin spike |
| Base | `d7933a7` (correction report 9) |
| Current `godot/` tree | `15321434e94325b632bc38bb2a40246e0577ad08`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Changes per review item

1. **`_duplicate_player_controllers()` refined.** Defining `update_movement` or `set_intent` is no
   longer evidence by itself. A runtime script other than `PlayableDog` is flagged only on
   player-specific evidence: both playable-controller methods outside an `ActorBody` controller; a
   `PlayableDog` subclass overriding either method; direct `InputService`-to-body movement (player
   input fed to the solver or a physics body, actors included); or moving the player's body itself
   (writing a `PlayableDog`/player position or velocity). `ActorBody` controllers (ARCHITECTURE §9:
   NPCs, cats, Bagnaskiz, combat foes, companions; a script that is, extends or owns an `ActorBody`)
   may define both methods and use the shared `WorldMapModel` solver. Comments and string literals
   are blanked before matching (`_code_only`). Synthetic cases in the ARCH-001a case: allowed —
   `ActorBody` itself with both methods, a cat with `update_movement`, a Bagnaskiz behaviour
   controller owning an `ActorBody` with both methods, a companion with both, a script naming the
   methods only in comments and strings, and a rules-like script routing input to the
   `PlayableDog`; flagged — a non-actor body with both methods, a `PlayableDog` subclass overriding
   `update_movement`, an input-fed `move_circle` mover, a script writing `player.gx`, and an
   `ActorBody` driven straight by `InputService`. The scan of every runtime script finds nothing,
   and a positive control on real code (the real `PlayableDog` source under another path) is
   flagged. TEST_PLAN.md (ARCH-001, ARCH-001a) and FEATURE_MATRIX state the same rule.
2. **FEATURE_MATRIX collision row:** "COLL-005b literal-coordinate story objectives" now reads
   "COLL-005b scripted-position story objectives", as in TEST_PLAN.md.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated gates

| ID | Status | Evidence / milestone |
|---|---|---|
| ARCH-001a | **satisfied** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (refined gate, this report) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` (correction report 8) |
| DOG-005a | satisfied | `test_DOG_005a_…` (correction report 7 addendum) |
| VIEW-004, CAM-004 | **not satisfied** | rendered clauses only by `tools/interpolation_probe.gd` outside the suite; gate decision not taken |
| DOG-008a | **not satisfied** | rendered presentation clause (same decision); restart reset not asserted separately |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case ARCH_001a` (working tree, twice while writing it) | `1 passed, 0 failed` each |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `15321434e94325b632bc38bb2a40246e0577ad08` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (asset check) | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **137 passed, 0 failed, 137 total** |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case ARCH_001a` (focused, in the fresh clone) | exit 0: `PASS test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `1 passed, 0 failed` |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (PCK smoke) | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device; run by the same script) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat d7933a7 -- godot` (working tree) | only `godot/tests/integration/test_world.gd` |
| `git diff --stat d7933a7 -- godot/tests/support` | empty: the dummy Story host scene and its lifecycle are unchanged |
| `git diff --stat d7933a7 -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (before the new log folder was added) | empty: historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 46 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-10-godot-tree-1532143/`. Not
run: Linux, the rendered interpolation probe (nothing rendered changed).

Host evidence: current tree above. Previous Windows trees: `6a3c53b` (correction report 9, 137
passed), `b1c3595` (correction report 8, 137 passed), `b8535ab` (correction report 7 addendum, 137
passed), `81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed).
Linux: the prior tree `d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on
Linux, and neither were correction 7's addendum and corrections 8, 9 and 10.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Unsatisfied automated M2 gates:** **VIEW-004** and **CAM-004** (gate decision not taken: accept
  the probe evidence, or add an in-suite rendered case); **DOG-008a** (the same rendered clause and
  a restart-reset assertion).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — correction report 9: ARCH-001a contract and COLL-005 ownership (`d7933a7`; M1 Partial, M2 Partial)

> Historical record of `d7933a7`, superseded by correction report 10. **Erratum** (text below kept
> as submitted): its static gate flagged any script other than `PlayableDog` that merely defined
> `update_movement` or `set_intent`, which would also flag approved `ActorBody` controllers, and it
> matched names inside comments and strings; correction report 10 requires player-specific
> evidence and ignores comments and strings. Its FEATURE_MATRIX collision row still said
> "literal-coordinate story objectives" (now "scripted-position", as in TEST_PLAN.md).

Scope: the architect's three items on `5435c32`, in one commit. Code changes are test files only
(the dummy Story host scene and the ARCH-001a case); no gameplay module, the continuous COLL-005a
driver and the PixiJS source are untouched.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); open M1 blocker: the migration-plugin spike |
| Base | `5435c32` (correction report 8) |
| Current `godot/` tree | `6a3c53bb9bf2c0cfc14e9c569ec03015543b914c`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Remaining blocker: the migration plugin and a controlled signed old→new APK lineage |

### Changes per review item

1. **ARCH-001a contract corrected** (TEST_PLAN.md ARCH-001 and ARCH-001a, the case, FEATURE_MATRIX,
   this report). Required now: the same `IsoWorld`, `PlayableDog` and `CameraRig` classes **and
   public interfaces** (public methods with argument counts and public variables, compared), with
   `IsoGrid` placing and `IsoDepthSorter` ranking both worlds; **not** the same tile set or sprite
   catalogue. The dummy Story host gained `environment_tileset`, `environment_catalog` and
   `environment_id`, applied through the world's public properties before `setup()`; the case gives
   it its own resource instances and checks that the story world uses them (ground layers, catalogue,
   bank id) while the Green Zone keeps `ch01_greenzone`. The static no-fork rule is scoped to
   **duplicate playable/input movement controllers**: a runtime script other than `PlayableDog` that
   defines the playable controller API (`update_movement`, `set_intent`) or reads player movement
   input and moves a body. Actor controllers (ActorBody, cats, Bagnaskiz, companions) may move with
   approved behaviour controllers on the shared `WorldMapModel` solver; the case first checks the
   rule's scope on four synthetic scripts (two actor controllers using `move_circle` pass, a second
   playable controller and an input-reading mover are flagged), then scans every runtime script.
   ARCH-001a stays claimed on `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, which
   passes in its corrected form.
2. **COLL-005 ownership** (TEST_PLAN.md): COLL-005 is redefined as static and scripted-position
   reachability (spawn/start/exit and every statically placed or scripted-position objective);
   dynamic goals (moving or runtime-placed targets and action zones) are explicitly not COLL-005 and
   are owned by WALK, NPC, MINI and each scene's STY real-input completion. COLL-005a and COLL-005b
   are unchanged: `test_P_COLL_005b_…` evidence in M5/M6, the full `test_COLL_005b_…` aggregate in
   M7. The continuous COLL-005a driver is unchanged.
3. **Project-isolation row** (FEATURE_MATRIX): CORE-001 now cites the current Windows tree
   (this report) and, before it, correction report 8's `b1c3595`; the old `81906cd` reference is
   gone; Linux stays the prior tree `d12bedd`.

### Legacy-save plan (unchanged; MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker:** a throwaway native migration plugin under
   `/godot/platform/android/` on a controlled same-package/same-signature old→new APK lineage; the
   five legacy keys read without mutation, or a documented reproducible failure, plus the written
   native-bridge versus staged-Capacitor decision. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005.
3. **M9 — production proof:** the installed lineage and signing certificate, two WebView/device
   versions, end-to-end MIG-001–010.

### M2 automated gates

| ID | Status | Evidence / milestone |
|---|---|---|
| ARCH-001a | **satisfied** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (corrected contract, this report) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` (correction report 8) |
| DOG-005a | satisfied | `test_DOG_005a_…` (correction report 7 addendum) |
| VIEW-004, CAM-004 | **not satisfied** | rendered clauses only by `tools/interpolation_probe.gd` outside the suite; gate decision not taken |
| DOG-008a | **not satisfied** | rendered presentation clause (same decision); restart reset not asserted separately |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case ARCH_001a` (working tree, while writing it) | `1 passed, 0 failed` |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `6a3c53bb9bf2c0cfc14e9c569ec03015543b914c` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` (asset reproducibility) | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` (clean import) | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **137 passed, 0 failed, 137 total**, including `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `test_COLL_005a_…`, `test_DOG_005a_…` |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` (PCK smoke) | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device; run by the same script) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat 5435c32 -- godot` (working tree) | only `godot/tests/integration/test_world.gd` and `godot/tests/support/dummy_story_scene.gd` |
| Python comparison of `test_world.gd` from `## Drives a PlayableDog…` to the end against `git show 5435c32:godot/tests/integration/test_world.gd` | identical: the COLL-005a driver and case are unchanged |
| `git diff --stat 5435c32 -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (working tree, before the new log folder was added) | empty: historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 42 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-9-godot-tree-6a3c53b/`. Not
run: Linux, the rendered interpolation probe (nothing rendered changed).

Host evidence: current tree above. Previous Windows trees: `b1c3595` (correction report 8, 137
passed), `b8535ab` (correction report 7 addendum, 137 passed), `81906cd` /
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6, 134 passed). Linux: the prior tree
`d12bedd`, 128 passed (progress report 5). Correction 6 was not rerun on Linux, and neither were
correction 7's addendum and corrections 8 and 9.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Unsatisfied automated M2 gates:** **VIEW-004** and **CAM-004** (gate decision not taken: accept
  the probe evidence, or add an in-suite rendered case); **DOG-008a** (the same rendered clause and
  a restart-reset assertion).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — correction report 8: M1/M2 acceptance evidence (`5435c32`; M1 Partial, M2 Partial)

> Historical record of `5435c32`, superseded by correction report 9. **Erratum** (text below kept
> as submitted): its ARCH-001a contract required the dummy Story host to share GreenZoneScene's tile
> set and sprite catalogue instances and flagged every runtime `move_circle` caller other than
> `PlayableDog`; correctly, the classes and public interfaces must be identical, a story stage may
> supply its own environment resources, and the static rule covers duplicate playable/input
> movement controllers only (actor behaviour controllers may use the shared solver). The COLL-005
> parent still read "every current story objective"; it now covers static and scripted-position
> reachability, with dynamic goals owned by WALK/NPC/MINI/STY.

Scope: the architect's five items on `965d0b0`, in one commit. No M3 content. Code changes are test
files only (a dummy Story host scene under `godot/tests/support/` and two rewritten acceptance
cases); no gameplay, audio, animation or isometric module and no PixiJS file changed.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); open M1 blocker: the migration-plugin spike |
| Base | `965d0b0` (correction report 7 and its addendum) |
| Current `godot/` tree | `b1c3595c49666587c04d2ad3d652d28d774a2bc5`, verified on a fresh Windows clone (below) |
| Host | Windows 11 Pro N for Workstations 25H2 (RTX 3090, WASAPI audio); Linux not rerun |
| Android on this host | available: Android SDK in `%USERPROFILE%\Desktop\android-sdk` (platform-tools/adb 37.0.3, build-tools 36.1.0, platform 36), Godot's 4.7.2 Android export templates, JDK 21, emulator 37.3.10 with the device `sv_m1_api36` (adb serial `emulator-5554`, Android 16 / API 36, Google WebView 133.0.6943.137). Not yet: the migration plugin and a controlled signed old→new APK lineage |

### Changes per review item

1. **ARCH-001a now rests on a real dummy Story host.** `godot/tests/support/dummy_story_scene.tscn`
   (tests/ is excluded from export; the M5 story scene replaces it) instantiates the shared
   `IsoWorld` scene as its child like `GreenZoneScene`, configures a story-style map (no exit,
   markers, water, props) through `IsoWorld.setup()`, ticks in a story walk's order (InputService
   intent → `PlayableDog.update_movement` on the grid solver → `IsoWorld.end_step`) and renders
   through `IsoWorld.render`. `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`
   replaces the direct-IsoWorld case: the world is the host's child; world scene/class, dog
   scene/class/profile, camera class, tile set and sprite catalogue equal `GreenZoneScene`'s; 200
   ticks driven through `InputService` move the dog east until the grid solver stops it at the
   wall, the camera follows on whole pixels, the visible set is ranked 0..n-1 by `IsoDepthSorter`;
   replaying the same intents on a bare `PlayableDog` and the same map gives the identical position
   every tick (no host-specific movement); freeing the host frees its world and dog. The no-fork
   check is kept as a **static review gate** and strengthened: no runtime script except
   `PlayableDog` calls `move_circle`/`circle_blocked`, defines `update_movement` or uses
   `move_and_slide`/`move_and_collide` (it cannot see future code paths: reviewers re-check new
   movers). ARCH-001a is claimed on this case.
2. **COLL-005a drives continuously to exact targets.** One `PlayableDog` is driven through its own
   controller (walking intent, screen space) and the grid solver from the Green Zone start to each
   treat's exact coordinate, finishing within the rule's pickup radius (`TREAT.PICKUP_RADIUS` 0.55,
   eaten at distance ≤ 0.55); each leg starts at the dog's real end position (no idealized tile
   centres), and from the last treat it continues to the exit (level complete at distance < 0.8).
   The case also keeps the story-map marker drives. COLL-005a is claimed on this case.
3. **COLL-005b planning** (TEST_PLAN.md, MILESTONES.md): every remaining scripted spatial objective
   with a scripted position (marker or literal reach goals, pickups, spots, marvels, action zones
   placed when their walk starts); runtime-placed and moving targets are assigned explicitly to
   WALK-007–009, WALK-014–017, WALK-019–021, NPC-001–006, NPC-008–011, MINI-001–012 and each
   scene's STY real-input completion. `test_P_COLL_005b_…` evidence in M5 (Level 1) and M6
   (Levels 2–4); the full `test_COLL_005b_…` aggregate is reserved for M7.
4. **Android status** updated in FEATURE_MATRIX (legacy-save plan, "Not verified", the Android rows)
   and here; the remaining blocker is the plugin plus a controlled signed old→new lineage.
5. **MIG-005 fixture/simulated portion added to M4** (TEST_PLAN.md MIG-005, MILESTONES.md M4, the
   plan below): the raw five-key payload written exactly with timestamp and SHA-256 before any
   parsing, read back and verified; backup, write and read-back failure tests; M9 still proves it
   through real WebView acquisition.

### The approved three-stage legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike, open M1 blocker.** A throwaway native migration plugin under
   `/godot/platform/android/`, tested on a controlled same-package/same-signature old→new APK
   lineage: it either reads the five legacy `supervillained:` keys without mutating them, or a
   reproducible failure is documented; either way the native-bridge versus staged-Capacitor
   decision is written. Not started; the tools are available (above).
2. **M4 — deterministic format-3 converter and SaveService integration**, plus the fixture/simulated
   MIG-005. Today only the pure v1→v2 rules are ported (SAV-013–017).
3. **M9 — production proof:** the actual installed lineage and signing certificate, two
   WebView/device versions, and end-to-end MIG-001–010.

### M2 automated gates

| ID | Status | Evidence / milestone |
|---|---|---|
| ARCH-001a | **satisfied** | `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world` (this report) |
| COLL-005a | **satisfied** | `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` (this report) |
| DOG-005a | satisfied | `test_DOG_005a_…` (correction report 7 addendum) |
| VIEW-004, CAM-004 | **not satisfied** | rendered clauses only by `tools/interpolation_probe.gd` outside the suite; gate decision not taken |
| DOG-008a | **not satisfied** | rendered presentation clause (same decision); restart reset not asserted separately |
| ARCH-001b, DOG-008b / COLL-005b / DOG-005b | later | M5 / M5–M7 (aggregate M7) / M3 |

### Commands executed and results (Windows 11)

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case <c>` for `ARCH_001a` and `COLL_005a` (working tree, while writing them) | each `1 passed, 0 failed` |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `b1c3595c49666587c04d2ad3d652d28d774a2bc5` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **137 passed, 0 failed, 137 total**, including `test_ARCH_001a_dummy_story_host_shares_the_green_zone_world`, `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver`, `test_DOG_005a_…` |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` | exit 0: PCK 32,905,976 bytes (unchanged: the dummy host under `tests/` is not exported), 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device) | exit 0, `"ok":true` |
| `npm test`; `npm run build` | exit 0: 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat 965d0b0 -- godot` (working tree) | only `godot/tests/integration/test_world.gd` and the new `godot/tests/support/dummy_story_scene.{gd,gd.uid,tscn}` |
| `git diff --stat 965d0b0 -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (working tree, before the new log folder was added) | empty: historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 37 checks` |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-8-godot-tree-b1c3595/`. Not
run: Linux, the rendered interpolation probe (nothing rendered changed).

Host evidence: current tree above. Previous Windows trees: `b8535ab` (correction report 7 addendum,
137 passed) and `81906cd` / `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876` (correction report 6,
134 passed). Linux: the prior tree `d12bedd`, 128 passed (progress report 5). Correction 6 was not
rerun on Linux, and neither were correction 7's addendum and this report.

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter, SaveService integration and fixture/simulated MIG-005, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker). The Android tools and the emulator are available; missing are the plugin and a controlled signed old→new APK lineage |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker):** a controlled test keystore, the old Capacitor
  APK built and signed with it, a few representative saves, the spike plugin and APK with the same
  package and signature installed over it without uninstalling (`adb install -r`) on
  `sv_m1_api36`; result: the five keys read unmutated, or a documented reproducible failure, plus
  the written native-bridge / staged-Capacitor decision.
- **Unsatisfied automated M2 gates:** **VIEW-004** and **CAM-004** (gate decision not taken: accept
  the probe evidence, or add an in-suite rendered case); **DOG-008a** (the same rendered clause and
  a restart-reset assertion).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — correction report 7: legacy-save plan, host evidence, M2 gates (`cc1ebb3`, addendum `965d0b0`; M1 Partial, M2 Partial)

> Historical record of `cc1ebb3` and its addendum `965d0b0`, superseded by correction report 8.
> **Erratum** (text below kept as submitted): the addendum claimed ARCH-001a on a case that built
> `IsoWorld` directly, without a Story host scene, and COLL-005a on drives to floored treat tiles
> that restarted each leg from an idealized tile centre; both claims rest on the stronger cases of
> correction report 8 instead. Its Android statements ("no Android SDK, adb, emulator or device",
> the spike's needs) are superseded by the current status in correction report 8.

Scope: the architect's three documentation items on `81906cd`, in one documentation commit. No code
changes: `godot/` is identical to `81906cd` (tree `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`); the
accepted AudioService and PlayableDog corrections and the PixiJS source are untouched.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted); **open M1 blocker: the migration-plugin spike** |
| Base | `81906cd` (correction report 6) |
| Code under test | at `cc1ebb3`: unchanged from `81906cd`. **Addendum** (below): test files only, three acceptance cases added; new `godot/` tree `b8535ab2b041ed91caa74eee1f8e3b5a65130860`, verified on Windows |
| Host | Windows 11 Pro N for Workstations 25H2 (same PC); Ubuntu 26.04 in WSL 2 (checked for Android tools only) |
| Android on this host | at `cc1ebb3`: no Android SDK, adb, emulator or device; no controlled old→new APK lineage; present: JDK 21 (Eclipse Adoptium) and Godot's 4.7.2 Android export templates. Since then, with the owner's OK: an Android SDK (platform-tools 37.0.3, build-tools 36.1.0, platform 36) and the emulator 37.3.10 with the virtual device `sv_m1_api36` (Android 16 / API 36, Google WebView 133.0.6943.137) in `%USERPROFILE%\Desktop\android-sdk`. The spike itself is not started |

### The approved three-stage legacy-save plan (MILESTONES.md M1/M4/M9, ARCHITECTURE.md §17.2–17.3)

1. **M1 — feasibility spike.** A throwaway native migration plugin under `/godot/platform/android/`,
   tested on a controlled same-package/same-signature old→new APK lineage. It either reads the five
   legacy `supervillained:` keys without mutating them, or a reproducible failure is documented;
   either way the native-bridge versus staged-Capacitor decision is written. Missing access to the
   owner's production signing identity is an M9 blocker, not an M1 one.
   **Status: not started, open M1 blocker.** No controlled Android environment exists on the hosts
   used (above), so the spike cannot run here. It is not unnecessary and it is not deferred to M9.
2. **M4 — deterministic format-3 converter and SaveService integration.** Today only the pure
   v1→v2 rules are ported (`CampaignMigration`, SAV-013–017).
3. **M9 — production proof:** the actual installed lineage and signing certificate, two
   WebView/device versions, and end-to-end MIG-001–010.

### Changes per review item

1. **Plan restored everywhere it was misstated.** Correction report 6 (item 3, D-11, D-13) and the
   erratum it added to progress report 5 had collapsed the plan to "M4 converter, M9 Android",
   dropping the M1 spike. Corrected in: FEATURE_MATRIX (status headline, "Not verified", the new
   "Legacy-save plan" paragraph, the campaign row, and the planning row "Legacy Capacitor import",
   whose milestone column now reads "M1 spike, M4 converter, M9 proof" as in MILESTONES.md); this
   report (D-11, D-13, "Still required"); the progress report 5 erratum; an erratum on correction
   report 6, now historical. MILESTONES.md, ARCHITECTURE.md and TEST_PLAN.md already state the
   three stages and are unchanged.
2. **D-11 / D-13 and "Still required"** below. The spike is listed as an open M1 blocker with what
   it needs.
3. **Host evidence in FEATURE_MATRIX.** Current tree: `81906cd` / `godot/` tree
   `fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`, Windows, 134 passed (correction report 6). Linux
   `d12bedd` / 128 passed is prior-tree evidence. Correction 6 was not rerun on Linux, and neither
   was this documentation commit. CORE-001 / AST-019 command evidence and the project-isolation row
   name the tree each host ran.

Historical evidence files (`windows_evidence/`, `linux_evidence/`, `captures/`) are unchanged.

### Commands executed and results

Only these commands were run for this commit (Windows 11, PowerShell 5.1 / Git Bash; WSL where
stated). No build, import, suite or launch was re-run: no code changed.

| Command | Result |
|---|---|
| `Get-Command adb`, `Get-Command emulator`, `Get-Command java` | adb: not found; emulator: not found; java: `C:\Program Files\Eclipse Adoptium\jdk-21.0.13.9-hotspot\bin\java.exe` |
| `$env:ANDROID_HOME`, `$env:ANDROID_SDK_ROOT`; `Test-Path $env:LOCALAPPDATA\Android\Sdk` | both empty; `False` |
| `Test-Path $env:APPDATA\Godot\export_templates\4.7.2.stable`; its listing filtered on `android` | `True`; `android_debug.apk`, `android_release.apk`, `android_source.zip` |
| `Test-Path godot\platform` | `False` (no spike code exists) |
| WSL Ubuntu 26.04: `command -v adb`, `command -v sdkmanager` | both not found |
| `git diff --stat d12bedd 81906cd -- godot/assets godot/data godot/tests/fixtures godot/tools/source_extract godot/tools/build_resources.gd` | empty: the generated outputs are the same on both trees |
| `git diff --stat 81906cd -- godot` (working tree) | empty: no code change |
| `git diff --stat 81906cd -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures docs/porting/MILESTONES.md docs/porting/ARCHITECTURE.md docs/porting/TEST_PLAN.md` | empty: historical evidence and planning documents unchanged |
| `git diff --check` and `git diff --check 95b69c0` (working tree) | clean |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 16 checks` — one "— current" report; the plan's three stages, the M1 blocker and the host-evidence facts present in FEATURE_MATRIX and this report; the collapsed "M9 only" wording absent from both |

### Addendum on top of `cc1ebb3`: the automated M2 gates reconciled

The architect's follow-up: list the unsatisfied automated M2 gates (ARCH-001, VIEW-004, CAM-004,
COLL-005, DOG-005, DOG-008) and reconcile MILESTONES.md, TEST_PLAN.md and FEATURE_MATRIX.md without
moving requirements to declare M2 complete. Only test files changed; no game or PixiJS code.

- **Split IDs** (TEST_PLAN.md rule: `<ID>a` = the earlier milestone's clauses, `<ID>b` = the later
  clauses with their own milestone; the parent is satisfied only when both are; no clause is
  dropped). MILESTONES.md lists each part under its milestone (M2, M3, M5–M7) and FEATURE_MATRIX's
  planning rows name the parts.

| Parent | M2 part | Evidence for the M2 part | Later part (milestone) |
|---|---|---|---|
| ARCH-001 | ARCH-001a: a dummy story scene and the Green Zone scene share the `IsoWorld` scene and setup, `PlayableDog`, `IsoGrid`, `IsoDepthSorter`, `CameraRig`; shared controller and grid solver; no forked movement | **satisfied**: new `test_ARCH_001a_dummy_story_scene_shares_the_green_zone_world` (both scenes' world/dog/camera scenes and classes, IsoGrid foot point, story map without exit and with markers, the dog stopped by a wall through the grid solver, depth-sorted, and a static scan finding a single movement implementation) | ARCH-001b: production story scene (M5) |
| COLL-005 | COLL-005a: Green Zone spawn/start, exit and every treat; every story map's start, exit and every marker the source can reach | **satisfied**: new `test_COLL_005a_maps_start_exit_treats_and_markers_reachable_under_the_solver` (runs the earlier partial case, then drives the grid solver start → each of the 30 treats in placement order → exit) | COLL-005b: story objectives at literal coordinates (M5–M7) |
| DOG-005 | DOG-005a: bark, eat/drink, hurt, exit cannot overlap illegally | **satisfied**: new `test_DOG_005a_bark_eat_drink_hurt_exit_never_overlap_like_source` (the source `rules_busy` and `rules_overlap` scenarios tick by tick: states bark, eat, pee, poop, hurt, drink, exit) | DOG-005b: forced fetch (M3, with GZ-034–036) |
| DOG-008 | DOG-008a: spawn/teleport/restart/camera-snap resets; 30/60/90/120 FPS presentation without streak; no test-hook leak | **not satisfied**: spawn, teleport and camera-snap resets and hook isolation are in `test_CORE_002_logic_independent_of_render_rate`; the presentation clause is only the rendered probe (decision below); a restart reset is not asserted separately | DOG-008b: stage change (M5) |

- **VIEW-004 and CAM-004: kept incomplete.** The suite covers nearest filtering and whole-pixel
  world, camera and UI transforms (`test_P_VIEW_004_…`, the CAM-004 assertion in
  `test_CAM_002_…`); the rendered 30/60/90/120 FPS, streak, double-interpolation and static-shimmer
  clauses are measured only by `tools/interpolation_probe.gd` outside the suite (llvmpipe,
  correction report 1; a real RTX 3090 for `d12bedd`, `windows_evidence/d12bedd/` steps f/g).
  **Gate decision: not taken** — accepting that probe evidence for these clauses, or requiring an
  in-suite rendered case, is the architect's call. The same decision covers DOG-008a's
  presentation clause.

Commands executed for the addendum and results (Windows 11):

| Command | Result |
|---|---|
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all --case <c>` for `ARCH_001a`, `COLL_005a`, `DOG_005a` (working tree, while writing them) | each `1 passed, 0 failed` |
| Fresh `git clone` of this commit's code (`core.autocrlf=true`; tested `godot/` tree `b8535ab2b041ed91caa74eee1f8e3b5a65130860` = `git rev-parse HEAD:godot` of this commit; only the docs and the log folder were written after it), `npm ci`, `npx playwright install chromium` | exit 0 each |
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | exit 0: `asset check OK: 206 outputs identical (72 copies) …`; `build_resources check (all): OK, 55 outputs identical` |
| `<console exe> --headless --path godot --import` | exit 0, no ERROR/WARNING lines |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | exit 0: **137 passed, 0 failed, 137 total** (134 + `test_ARCH_001a_…`, `test_COLL_005a_…`, `test_DOG_005a_…`) |
| `<console exe> --headless --path godot --quit-after 600` | exit 0, engine banner only |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` | exit 0: PCK 32,905,976 bytes, 254 runtime resources, 512 packed files, packed 600-frame startup clean |
| `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` (real WASAPI device) | exit 0, `"ok":true`, `late_effect_dropped` true, nothing replayed |
| `npm test`; `npm run build` | exit 0: 248 tests passed; build OK |
| `git status --porcelain`; `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | exit 0, all empty |
| `bash godot/tools/source_tree_guard.sh` | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |
| `git diff --stat cc1ebb3 -- godot` (working tree) | only `godot/tests/integration/test_world.gd` (+77) and `godot/tests/unit/test_needs_rules.gd` (+10) |
| `git diff --stat cc1ebb3 -- docs/porting/windows_evidence docs/porting/linux_evidence docs/porting/captures` (working tree, before the new log folder was added) | empty: historical evidence unchanged |
| `git diff --check` (working tree) | clean |
| `python docs_consistency_check.py` (session tool, not committed) | `OK: 36 checks` (current report, the M1/M4/M9 plan, host evidence, the split IDs in TEST_PLAN, MILESTONES and FEATURE_MATRIX, claimed IDs backed by `test_<ID>` cases) |

Logs of the fresh-clone run: `docs/porting/windows_evidence/correction-7-godot-tree-b8535ab/`. Not run:
Linux, the rendered interpolation probe (nothing rendered changed).

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign save: the pure v1→v2 rules are ported (SAV-013–017). Remaining, per the approved plan: the M1 migration-plugin spike (open M1 blocker), the M4 format-3 converter and SaveService integration, the M9 production-lineage / two WebView-device / MIG-001–010 proof |
| D-13 | Not done from M1: the Android migration-plugin spike (open M1 blocker: no Android SDK, adb, emulator, device or controlled APK lineage on the hosts used). Done since report 1: title, synthesized audio, Sbrimbrulòn/Bagnaskiz profiles, cast |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **M1 migration-plugin spike (open M1 blocker).** Still to do: a controlled test keystore, the
  old Capacitor APK built and signed with it, a few representative saves, and a spike APK with the
  same package and signature installed over it without uninstalling (`adb install -r`). Result: the
  five keys read unmutated, or a documented reproducible failure, plus the written native-bridge /
  staged-Capacitor decision. Now available on this PC: the Android SDK, the emulator device
  `sv_m1_api36`, JDK 21 and the Godot Android export templates.
- **Unsatisfied automated M2 gates:**
  - **VIEW-004** and **CAM-004**: rendered clauses only by the probe outside the suite; gate
    decision not taken (accept the probe evidence, or add an in-suite rendered case).
  - **DOG-008a**: the rendered presentation clause (same decision) and a restart-reset assertion.
  - ARCH-001, COLL-005 and DOG-005: their M2 parts ARCH-001a, COLL-005a and DOG-005a are satisfied
    by this addendum's cases; ARCH-001b (M5), COLL-005b (M5–M7) and DOG-005b (M3) stay with their
    milestones, as does DOG-008b (M5).
- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — correction report 6: fifth M1/M2 review (`81906cd`; M1 Partial, M2 Partial)

> Historical record of `81906cd`, superseded by correction report 7. Its Windows results remain the
> current-tree evidence (`godot/` is unchanged since). **Erratum** (text below kept as submitted):
> item 3, D-11 and D-13 dropped the approved M1 stage of the legacy-save plan. Correctly: M1 — a
> migration-plugin feasibility spike on a controlled old→new APK lineage (open M1 blocker, not
> started); M4 — the format-3 converter and SaveService integration; M9 — the production
> lineage/certificate, two WebView/device versions and end-to-end MIG-001–010 proof.

Scope: the architect's three items on `5a4a486`, in one correction-only commit. No M3 content and
no PixiJS source change. Beyond the two places the review names (AudioService effect requests and
the dog scene's profile reference) nothing is rewritten: IsoGrid, GridKinematicSolver, movement,
camera, depth sorting, the TileMap renderer, SaveService, interaction geometry, the asset pipeline,
the test runner and the PCK test are unchanged.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted) |
| Base | `5a4a486` (progress report 5) |
| Host | Windows 11 Pro N for Workstations 25H2, build 26200.8037 (RTX 3090, WASAPI audio) |
| Godot / toolchain | Godot 4.7.2.stable.official.ed1daf0bf (win64 console); PowerShell 7.7.0; Git 2.54.0.windows.1 (`core.autocrlf=true`); Node v24.15.0; Playwright 1.63.0; Chromium 153.0.8010.12 (revision 1243, pinned) |
| Not available | an Android device, SDK, export templates or signing identity; a human tester |

### Changes per review item

1. **AudioService effect requests now follow `src/core/audio.ts` `AudioEngine.play()`
   (finding F-18).** The source returns before scheduling anything while `settings.muted` or while
   its AudioContext is not running (background), drops the same cue again within 45 ms of
   `ctx.currentTime`, and its master gain is `muted ? 0 : volume`. The port had started a request
   made in the background paused (audible on return), had no mute drop and no 45 ms rule, and set
   volume 0 to -80 dB. Now:
   - `muted` and `volume` are tracked explicitly (`apply_settings`);
   - a new immediate or delayed request made while muted or suspended is dropped (counted in
     `dropped` by reason) and nothing is replayed on unmute or resume;
   - sounds already playing and delayed cues already scheduled before suspension still pause and
     resume (an audio clock, `audio_time`, advances only while not suspended, like
     `ctx.currentTime`; delays and the 45 ms rule use it, the time taken when the request is made);
   - the same cue within 45 ms of audio time is dropped;
   - muted or volume 0 mutes the master bus (true silence); otherwise the bus level is the volume.

   Tests: `test_SLICE_audio_background_suspends_music_and_effects` now requires a background
   request to be dropped (not started paused) and nothing replayed on return; new regressions
   `test_SLICE_audio_mute_drops_new_effects_and_unmute_replays_nothing`,
   `test_SLICE_audio_suspend_drops_new_effects_and_resume_replays_nothing`,
   `test_SLICE_audio_delayed_cue_from_before_suspension_resumes`,
   `test_SLICE_audio_volume_zero_is_silence`,
   `test_SLICE_audio_same_cue_within_45_ms_is_suppressed`; the bounded-log case advances audio
   time between requests. `tools/audio_suspend_probe.gd` now requires the late background cue to
   be dropped (`late_effect_dropped`) and nothing to start on resume (`replayed_on_resume: false`).
2. **The dog scene no longer references Zampanò.** `playable_dog.tscn` has no `profile`
   ext_resource; `IsoWorld` injects the selected profile (AppState's `--as` choice or an explicit
   option) before `add_child()`. `PlayableDog.active_profile()` loads Zampanò lazily from a path
   string (no preload, so no static dependency) only when a dog is used unconfigured, and records
   it (`used_fallback_profile`). `test_SLICE_playable_profile_injected_before_add_child`: the
   PackedScene's dependencies and text name no Zampanò resource and the script preloads no profile;
   `--as=zampano|sbrimbrulon|bagnaskiz` each reach the spawned dog with no fallback, and an explicit
   option overrides the `--as` choice; a bare instantiated scene carries no profile and falls back
   to Zampanò only once added.
3. **Milestone wording.** The format-3 campaign converter and its SaveService integration are
   **M4**; the Android legacy-store acquisition and the signed-upgrade/MIG-001–010 proof are
   **M9**. Corrected in the FEATURE_MATRIX status section and campaign row, in the deviations below,
   and by an erratum on progress report 5, which is now historical. Earlier evidence folders and
   reports are kept unchanged as historical records.

### Commands executed and results (Windows 11)

A fresh `git clone` (Git for Windows defaults, `core.autocrlf=true`) of this commit's code, taken
before this table and the log folder were written: the tested `godot/` tree is
`fd20ac1f3c8ac95fb197fd7bcca6a5d4c2c95876`, which equals `git rev-parse HEAD:godot` of this
commit (only this report and its log folder differ). `npm ci` and `npx playwright install
chromium` exit 0; then, from the clone root in PowerShell 7.7.0
(logs: `docs/porting/windows_evidence/correction-6-godot-tree-fd20ac1/`):

| Check | Command | Exit | Result |
|---|---|---|---|
| Deterministic asset check | `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | 0 | `asset check OK: 206 outputs identical (72 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)`; `build_resources check (all): OK, 55 outputs identical` |
| Clean Godot import | `<console exe> --headless --path godot --import` | 0 | no ERROR/WARNING lines |
| Full suite | `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | **134 passed, 0 failed, 134 total** (128 earlier cases + 5 audio regressions + the profile-injection case; the background-audio case now requires the drop) |
| 600-frame launch | `<console exe> --headless --path godot --quit-after 600` | 0 | engine banner only |
| PCK smoke | `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite integration --file test_export_pack` | 0 | `test_SLICE_android_pck_has_runtime_data_and_starts_clean` passed: PCK 32,905,976 bytes, 254 runtime resources load from the pack, 512 packed files, no excluded content, packed 600-frame startup with no error or warning |
| Audio probe (real WASAPI device) | `<console exe> --path godot --script res://tools/audio_suspend_probe.gd` | 0 | `{"late_effect_dropped":true,"live_players":2,"ok":true,"paused_in_background":[true,true],"replayed_on_resume":false,"resumed":[true,true]}`, clean exit |
| PixiJS tests | `npm test` | 0 | 30 files, **248 tests passed** |
| PixiJS build | `npm run build` | 0 | TypeScript + Vite build OK |
| Working tree | `git status --porcelain` | 0 | empty |
| Diff check | `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | 0 | clean (whole port; this commit) |
| Source-tree guard | `bash godot/tools/source_tree_guard.sh` (Git Bash) | 0 | `source-tree guard OK: only /godot and docs/porting differ from 95b69c04c5c3b9626e49719f8f916a44659cd265` |

Not re-run for this commit: Linux (no Linux-specific code changed), the rendered interpolation
probe and the captures (nothing visual changed).

### Deviations

| ID | Status |
|---|---|
| D-11 | Campaign: the pure v1→v2 rules are ported (SAV-013–017); the format-3 converter and SaveService integration are M4; the Android legacy-store acquisition and the signed-upgrade/MIG proof are M9 |
| D-13 | Mostly closed (title, synthesized audio, profiles, cast); what remains is the Android legacy-store acquisition and MIG proof, which are M9, not M1/M2 evidence |
| D-05, D-14, D-15 | As in progress report 5 |
| D-01–D-04, D-06–D-10 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).

### Architect review result

Pending.

---

## Historical — progress report 5: remaining M1/M2 work (`5a4a486`; M1 Partial, M2 Partial)

> Historical record of `5a4a486`, superseded by correction reports 6 and 7. **Errata** (text below
> kept as submitted): "legacy import into the container stays M9" should read as the approved
> three-stage plan (correction report 7): M1 — the migration-plugin feasibility spike on a
> controlled old→new APK lineage, still open as an M1 blocker (the "Android (M1 spike)" item below
> was right to list it); M4 — the format-3 converter and SaveService integration; M9 — the
> production lineage/certificate, two WebView/device versions and end-to-end MIG-001–010 proof.
> The audio behaviour then recorded, a new effect requested in the background "starts paused"
> (also in `windows_evidence/d12bedd/`), was not source parity: the source drops it (F-18).

Scope: the architect's instruction after the fourth review ("continue only the remaining documented
M1/M2 work"). No M3 content. The accepted foundations are not rewritten: IsoGrid,
GridKinematicSolver, movement, camera, depth sorting, the TileMap renderer, SaveService candidate
handling, the audio lifecycle (suspend/resume, track continuity), interaction geometry, the test
runner and the PCK test are unchanged. The asset pipeline is extended (new outputs and fixtures);
every earlier output is byte-identical (`--check` on Windows and Linux).

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted; see "Still required") |
| Base | `c320000` (correction report 4) |
| Code commits | `53493e2` audio, `392207d` playable dogs, `5745c99` cast/banks/frozen art, `16b5619` title/font/coverage, `ead5918` campaign migration, `acdfce3` story maps, `401e8e4` RNG-002, `d12bedd` probe exit + README |
| Hosts | **Windows 11 25H2** (RTX 3090, WASAPI audio) and **Linux: Ubuntu 26.04 in WSL 2** on the same PC |
| Godot / toolchain | Godot 4.7.2.stable.official.ed1daf0bf (win64 console and linux.x86_64); Node v24.15.0; Playwright 1.63.0; Chromium 153.0.8010.12 (revision 1243, pinned) |
| Not available | an Android device, SDK, export templates or signing identity; a human tester |

### What changed

1. **Audio (AUD-001–008).** The extractor copies the remaining recorded music (levels 2–4) and
   effects (meow, coin, ball, alarm, siren, laser) and executes `src/fx/audioFiles.ts` for the
   cue tables (`?url` imports now resolve to repository paths). It renders the fourteen `SOUNDS`
   cues and the medieval loop with the source's own `synth.ts`/`sounds.ts` at the source rate to
   mono 22,050 Hz signed 16-bit PCM WAV (`round(clamp(x, -1, 1) * 32767)`), records recipe/input
   hashes, sample counts, peaks and probe samples, and Chromium decode references for every
   recorded file. WAVs import as plain PCM; the medieval loop loops over its whole buffer.
   AudioService plays all five recorded tracks (per-track `MUSIC_FILE_GAIN`), `medieval`
   (`MUSIC_VOLUME`, restarts from 0 like the source's new buffer source), twelve recorded and
   fourteen synthesized effects, and delayed cues in audio time. The Green Zone gains the source's
   marking star (+0.12 s), tired and cleaned-poop cues. D-05 closed.
2. **Playable dogs (AST-002–009).** Copies of the knight, Sbrimbrulòn (plain/knight) and Bagnaskiz
   (plain/armoured) sheets; one layout per `PLAYABLE_CHARACTER_KEYS` skin (`zampanoCross` detected
   as an alias of the knight art); the source `costumeFor()` table. SpriteFrames for all six skins
   and a `PlayableCharacterProfile` per `PLAY_AS` dog (normal/cross/armoured slots; Zampanò's frames
   byte-identical). The world applies the `--as` profile (it was parsed but not applied before).
3. **Cast, banks, frozen art (AST-011–018).** The 23 delivered pixel-cast sheets and the professor
   portrait; the 14 remaining Color Ink banks; the 17 procedural cast roles frozen with the source
   recipe (`CAST_SPECS` + `poseFor` + `drawCritter`); the remaining palette-independent procedural
   sprites (items, FX, story specials). The native level-frame contract is taken from the executed
   source generators: every bank delivers all 104 native frames with exact geometry, every
   `floorArt_` frame is a native tile, all 19 compositions are valid. SpriteFrames for every cast
   role.
4. **Title (AST-010).** `src/ui/titleAnim.ts` runs unchanged in Chromium (three imports replaced;
   the page and the WebP share one intercepted offline origin): 99 frames at the canonical
   125 px width, one 2000×1176 page, 8,316,000 bytes; the WebP's delays (checked against the
   file's own ANMF chunks); `TitlePortrait` is the only linear-sampled node (alpha-cut shader).
   `docs/porting/captures/title_m1/` has first/middle/last frames at three widths for approval.
5. **Font (AST-020).** Fallback-glyph map and 128 wrapping cases from the source (`layoutLines`
   executed); `PixelText.wrap` no longer wraps every word at width 0 (source: 0 = no wrap).
6. **Coverage (AST-001).** Every runtime-authoritative source file is a verified copy; the WebP and
   WOFF2 converter inputs are hash-recorded.
7. **Campaign migration (SAV-013–017).** `CampaignMigration` (pure): `migrateV1`, `loadCampaign`
   (v1 migrated once with its untouched payload kept aside; v2 normalized) and the one-time notice
   of `storyFlow.showNotice`, against fixtures produced by the executed source over an in-memory
   localStorage. Legacy import into the container stays M9 (D-11).
8. **Story maps (MAP-003, AST-015, COLL-005).** The twenty story maps parse like the source cell for
   cell; TileMapLayer cell centres equal IsoGrid tile centres over every extent. The grid solver
   reaches every marker and exit the source can reach; the four markers the source cannot reach
   are actor spawn points (ship 5/6, neighborhood 0/9). The four map keys without a composition
   resolve to delivered theme/fallback banks; none of them is staged by the current chapters.
9. **RNG-002.** The same seed reproduces the source World: treat route, spawn spots, all 692 static
   props (map props, forest trees, wall blocks) and all 9,216 ground cells (`mapRenderer.makeTile`
   executed with texture-token stubs), and a second build is identical.
10. **Probes.** `audio_suspend_probe.gd` waits for the audio server before quitting (clean exit on a
    real device); `title_capture.gd` added. README updated.

Findings for the architect:

- **F-15:** AST-007's "arms attachment alignment" has no separate source counterpart: the armoured
  sheets draw sword and shield inside each frame. The case checks the armoured frames on the shared
  40×40 frame and foot anchor (standing frames end 1–2 rows above the anchor in all 8 directions),
  the art differing from the plain costume, and the arms capability flag. Architect to accept or
  redefine.
- **F-16:** the source cannot load a v1 save whose `book.shards` is not an array (`filter` throws);
  the fixtures only use shapes the source accepts. The port tolerates the malformed shape.
- **F-17:** on a 60 Hz display with VSync, the rendered probe cannot reach 90/120 FPS and its
  interpolation-off control may show no repeated frames (exit 1, inconclusive); the 30/60/90/120
  evidence is the `--disable-vsync` run.

### Acceptance IDs

Newly satisfied by full suite cases (33): RNG-002; MAP-003; AST-001–013, AST-015–018, AST-020;
AUD-001–008; SAV-013–017. Total: **90** (FEATURE_MATRIX status section). Every automated M1 ID
(ISO-001–003, RNG-001–003, AST-001–020, AUD-001–008, SAV-013–017) is now satisfied, AST-019 by
command evidence on both hosts. Still partial: ARCH-001 (M5 story scene), VIEW-004 and CAM-004
(rendered checks by probe, now also on a real GPU), DOG-005 (M3 fetch), DOG-008 (M5 stage change),
COLL-005 (story pickups/spots/marvels at literal coordinates arrive with the M5 scripts), and the
M3 IDs GZ-001/002/021/025, UI-001–006, FLOW-005, SAV-021.

### Commands executed and results

Fresh clones of `d12bedd`, every step exit 0 unless stated; reports and logs:
`docs/porting/windows_evidence/d12bedd/REPORT.md`, `docs/porting/linux_evidence/d12bedd/REPORT.md`.

| Check | Windows 11 (`core.autocrlf=true`) | Linux (Ubuntu 26.04, WSL 2) |
|---|---|---|
| Asset check (`build_assets.ps1 -Check` / `build_assets.sh --check`) | 206 outputs identical (72 copies); 55 resources identical | identical result, same bytes |
| Clean import | no errors or warnings | no errors or warnings |
| Suite `--suite all` | **128 passed, 0 failed** | **128 passed, 0 failed** |
| Main scene, 600 frames | banner only | banner only |
| `git status --porcelain` | empty | empty |
| Source-tree guard | OK | OK |
| `git diff --check 95b69c0 HEAD` | clean | — |
| Rendered probe, real GPU, `--disable-vsync` | 30.0/60.0/90.4/120.6 FPS, 0 repeated frames, teleport resets, no static shimmer; control shows the expected repeats | not run (no display) |
| Audio probe, real device | pause/resume of music and effects, clean exit | not run |
| PixiJS baseline `npm test`, `npm run build` | 30 files, 248 tests passed; build OK | not run |

### Deviations

| ID | Status |
|---|---|
| D-05 | **Closed**: synthesized cues and the medieval loop are rendered source WAVs |
| D-13 | **Mostly closed**: title, synthesized audio, Sbrimbrulòn/Bagnaskiz profiles and the cast are done; the Android migration spike remains (no device/SDK/signing lineage here) |
| D-14 | Rendered 30/60/90/120 checks now also on a real desktop GPU; device rates unverified |
| D-15 | Still proposed (Windows CI); Windows and Linux evidence now come from real host runs |
| D-01–D-04, D-06–D-11 | As in correction report 1 |

### Still required before requesting M1/M2 completion review

Cannot be produced on this host without a person or a device:

- **Manual desktop play (M2):** five minutes with keyboard/controller; occlusion at every approach
  angle; camera bounds at map edges; crisp rendering at two window sizes and one non-integer
  aspect.
- **Manual touch play (M2):** five minutes on a portrait Android device or touch surface (move,
  simultaneous RUN, PEE, pointer ownership, left/right edges); touch video/capture.
- **Manual M1 checks:** editor preview of every playable animation/direction; listening to the
  recorded and synthesized audio; approval of the title images (`captures/title_m1/`).
- **Android (M1 spike, device evidence):** export templates, SDK, a controlled signed old APK and
  a device, for the migration spike and any device-only row (B-04).

### Architect review result

Pending.

---

## Historical — correction report 4: fourth M1/M2 review (`c320000`; M1 Partial, M2 Partial)

> Historical record of `c320000`, superseded by progress report 5.

Scope: the architect's three items on `e2768cf` (`a0e3b8d` plus its Windows evidence), in one
commit. No M3 content. The asset pipeline, SaveService candidate selection, IsoGrid,
GridKinematicSolver, movement, camera, depth sorting, the TileMap renderer, the audio lifecycle
and the PCK export test are unchanged.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted) |
| Base | `e2768cf` (`a0e3b8d` + `docs/porting/windows_evidence/a0e3b8d/`) |
| Host | **Windows 11 Pro N for Workstations 25H2, build 26200.8037**: a real Windows PC (the project owner's), not a simulation |
| Godot / toolchain | Godot 4.7.2.stable.official.ed1daf0bf, `Godot_v4.7.2-stable_win64_console.exe`; PowerShell 7.7.0 (official portable zip, SHA-256 verified); Git 2.54.0.windows.1, `core.autocrlf=true`; Node v24.15.0, npm 11.12.1; Playwright 1.63.0; **Chromium 153.0.8010.12 (revision 1243, pinned)** |
| Hosts not available | Android (no SDK, templates or device). Linux was not used for this report |

### Windows evidence: obtained on a real Windows host

A fresh `git clone` of `a0e3b8d` with Git for Windows' default line endings
(`core.autocrlf=true`), `npm ci`, `npx playwright install chromium`, then from the clone root in
PowerShell 7.7.0. Report and every step's merged stdout/stderr:
`docs/porting/windows_evidence/a0e3b8d/REPORT.md`.

| Step | Exit | Result |
|---|---|---|
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | 0 | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)`; `build_resources check (all): OK, 7 outputs identical` |
| `<console exe> --headless --path godot --import` | 0 | no errors or warnings |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | **110 passed, 0 failed** |
| `<console exe> --headless --path godot --quit-after 600` | 0 | engine banner only, no errors or warnings |
| `git status --porcelain` | 0 | empty: the checks modified no tracked file |

This produces, for `a0e3b8d`, the two Windows items earlier reports could not: the Windows
PowerShell asset check exits 0, and the Godot Windows console suite passes (110/110). The asset
check regenerates every output on the host and compares bytes, so Windows Chromium's font
rasterization and WebAudio decoding yield the committed bytes. This commit is re-verified the same
way below.

### Changes per review item

1. **Interaction broad phase covers the target radius (finding F-14).** The source measures prop
   interactions to the prop's **edge** (`WorldMapModel.nearest_prop`:
   `hypot(prop − player) − radius ≤ distance`; marking 1.05 to any vertical prop, drinking 1.0 to
   a fountain), so an accepted prop's centre can lie distance + radius away: tree 1.37, pole 1.21,
   fountain 1.41 (marking) and 1.36 (drinking) tiles. The previous probe (`PROBE_RADIUS` = 1.05,
   the bare rule distance) would have missed every such target registered at its centre. The
   probe is now conservatively inflated: `GridShapes.PROBE_RADIUS` = the largest prop rule
   distance 1.05 + `MAX_TARGET_RADIUS` 0.5 (the widest catalog prop: house, gate) +
   `SNAP_MARGIN` 0.1 (probe and target nodes both sit on whole pixels; a half-pixel diagonal is
   0.0494 tiles) = **1.65 tiles**; `GridShapes.reach(rule, radius)` names the reach. The exact
   source edge-distance logic (`nearest_prop`, as used by `try_pee` and `_check_drink`) is
   unchanged and stays authoritative; no rule reads the probe before M3.
   `test_SLICE_interaction_broad_phase_covers_prop_edge_reach`: the widest-prop and snap-margin
   contract for every catalog prop; tree, pole and fountain (marking) and fountain (drinking) at
   reach ± 1e-9 tiles in 16 grid directions (8 compass points and the 8 edge midpoints of the
   probe polygon, its tightest directions); the exact decision accepts every inside point and
   rejects every outside point; the old bare-distance polygon misses every inside point; and a
   real physics-server overlap with a point-like target on the whole-pixel prop centre reports all
   128 placements. Mutation check: with the old 1.05 probe this case fails all 128 broad-phase
   assertions while the exact decisions still pass.
   `test_SLICE_probe_and_hurtbox_are_projected_grid_ellipses_broad_phase_only` now uses the new
   radius (a target at the probe radius overlaps; one 0.05 tile beyond the polygon vertex does
   not). ARCHITECTURE §7.2 describes the reach.
2. **Current evidence status.** This section carries the real Windows evidence. FEATURE_MATRIX:
   CORE-001 and AST-019 command evidence name the Windows clean clone, a Windows verification note
   was added, the Windows-host item was removed from "Not verified", and the isolated-project and
   contact-shape rows were updated. Older reports are marked historical.
3. **Windows evidence logs normalized.** Trailing spaces (23 Godot progress lines in step a) and
   final blank lines (steps b and d) removed in `docs/porting/windows_evidence/a0e3b8d/`;
   `git diff -w --ignore-blank-lines` shows no other change, and REPORT.md records it.

### Commands executed and results (Windows 11)

A fresh `git clone` of this commit's code (taken before this table was written; the tested tree
differs from this commit only in this table) with Git for Windows' defaults
(`core.autocrlf=true`), `npm ci` (exit 0) and `npx playwright install chromium` (exit 0), then
from the clone root in PowerShell 7.7.0:

| Command | Exit | Result |
|---|---|---|
| `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check` | 0 | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)`; `build_resources check (all): OK, 7 outputs identical` |
| `<console exe> --headless --path godot --import` | 0 | no errors or warnings |
| `<console exe> --headless --path godot --script res://tests/test_runner.gd -- --suite all` | 0 | **111 passed, 0 failed** (the 110 earlier cases + `test_SLICE_interaction_broad_phase_covers_prop_edge_reach`) |
| `<console exe> --headless --path godot --quit-after 600` | 0 | engine banner only, no errors or warnings |
| `git status --porcelain` | 0 | empty: the checks modified no tracked file |
| `git diff --check 95b69c0 HEAD`; `git show --check HEAD` | 0 | clean (whole port against the audited source; this commit) |
| `bash godot/tools/source_tree_guard.sh` (Git Bash) | 0 | guard OK: only `/godot` and `docs/porting` differ from `95b69c0` |

Not re-run for this commit: the PixiJS source checks (no source file changed), the captures and
the rendered interpolation probe (nothing visual changed), and Linux.

### Deviations

| ID | Status |
|---|---|
| D-15 | Still proposed only (Windows CI outside the gate-5 paths); no longer the only route to Windows evidence, which now comes from a real host run |
| D-01–D-14 | As in correction report 1 |

### Architect review result

Pending.

---

## Historical — correction report 3: third M1/M2 review (`a0e3b8d`; M1 Partial, M2 Partial)

> Historical record of `a0e3b8d`, superseded by correction report 4. Its "Windows evidence: still
> not obtained" was true when written; real Windows evidence for `a0e3b8d` is in correction report 4.

Scope: the architect's four items on `9f458f8`, in one commit. No M3 content. IsoGrid,
GridKinematicSolver, movement, camera, depth sorting, TileMap rendering, Green Zone rules, the
audio lifecycle, the PCK export test and SaveService candidate selection are unchanged.

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted) |
| Base | `9f458f8` |
| Godot / toolchain | 4.7.2.stable.official.ed1daf0bf Linux x86_64; Node v24.15.0; Playwright/playwright-core 1.63.0; **Chromium 153.0.8010.12 (revision 1243), the build pinned by playwright-core** |
| Hosts not available | **Windows** (still none attached; see "Windows evidence"); Android (no SDK, templates or device) |

### Finding F-13: the committed metadata was generated under a non-pinned Chromium

`playwright-core@1.63.0/browsers.json` pins Chromium **153.0.8010.12** (revision 1243), but every
earlier output recorded **157.0.8103.78**. This container installs its own headless shell in
the revision-1243 slot (`chromium_headless_shell-1243` wraps a 157 binary), and Playwright's
default headless launch uses that shell. A Windows host with `npx playwright install chromium`
gets the genuine 153 build, so its `--check` saw different `chromium` values in
`sfx_leading_silence.json`, `source_font_glyphs.json` and the manifest: the likely cause of the
reported Windows failure. Regenerated under the genuine 153 build (the full Chromium of the same
revision, present here as `chromium-1243/chrome-linux64/chrome`), only those version strings
changed: the font atlas, the 95 glyph hashes and every leading-silence offset are byte-identical
under 157 and 153, so those outputs do not depend on the Chromium build.

### Changes per review item

1. **Deterministic Chromium provenance.** The extractor derives the expected build from the
   installed `playwright-core/browsers.json` (after checking playwright and playwright-core both
   equal the lockfile), launches the full `chromium` channel (what `npx playwright install
   chromium` installs on every platform; hosts may substitute the default headless shell), and
   exits 6 unless `browser.version()` equals the pinned version. Generated files record only the
   pinned values (`toolchain.chromium`, `chromium_revision`, `chromium_channel`,
   `chromium_pinned_by`); the host browser's own report is printed (host evidence) and never
   written. Verified: a revision-1243 slot that actually holds the 157 shell is refused with
   exit 6. `test_SLICE_chromium_provenance_is_the_pinned_build` asserts every recorded Chromium
   value is the same pinned version and equals the installed `browsers.json` when present.
2. **Future-copy failures reported.** `_preserve_future()` returns `""` or
   `future_copy_failed:<file>` (`<file>` = `save_v3.json`, `save_v3.tmp` or `save_v3.bak`); it
   reads the copy back and removes a short or failed copy of its own. Failures are listed in
   `future_copy_errors`, put in `last_error` and emitted through `save_failed`; writes stay blocked
   and the originals stay untouched. Injections: a directory occupying the copy path (a real
   I/O failure) and `fault_future_copy` (a short write caught by the read-back), for each of
   main, temp and backup, plus two simultaneous failures and recovery on the next launch:
   `test_SLICE_future_copy_failures_are_reported_and_writes_stay_blocked`. The runner resets
   `fault_future_copy` per case.
3. **Viewport documentation.** ARCHITECTURE §8 and the base matrix row now describe the source
   `computeViewport` as authoritative, step by step, with its below-192 bands (areas narrower than
   192 px at scale 1; areas 271–383 px at scale 2, width 135–191).
4. **InteractionProbe/Hurtbox.** Both are now projected grid circles (`GridShapes.ellipse_polygon`,
   circumscribed 16-gon, on the foot point) instead of screen circles (probe radius 12 px, hurtbox
   6 px at (0, −8)), and are documented (ARCHITECTURE §7.2) and tested as **broad phase only**:
   the probe gates the largest Green Zone interaction distance (`GridShapes.PROBE_RADIUS` = 1.05
   tiles), the hurtbox is the player's 0.26-tile radius, and rules decide with
   `GridShapes.distance` (the source's hypot). `test_SLICE_probe_and_hurtbox_are_projected_grid_ellipses_broad_phase_only`:
   every vertex lies on the projected grid circle, 2,000 grid points within the radius project
   inside (no missed contact), a corner point is inside but farther (so the shape never decides),
   and a real Area2D overlap in the physics server accepts a target at 1.0 tile and rejects one at
   1.3 tiles.

### Commands executed and results (Linux)

| Command | Result |
|---|---|
| `NODE=/opt/node24150/bin/node godot/tools/build_assets.sh --check godot` | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 153.0.8010.12 (revision 1243, pinned; host browser reported 153.0.8010.12)`; `build_resources check (all): OK, 7 outputs identical`; exit 0 |
| the extractor with a revision-1243 slot holding the 157 headless shell | `Chromium 157.0.8103.78 is not the build pinned by playwright-core 1.63.0 (153.0.8010.12, revision 1243); run npx playwright install chromium.`, exit 6 |
| `rm -rf godot/.godot && godot --headless --path godot --import` | exit 0, 0 errors, 0 warnings |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **110 passed, 0 failed** (unit 60, content 15, integration 35), exit 0; the Android-preset PCK case: 5,185,812 bytes, 83 runtime resources loaded from the pack (171 packed files), clean 600-frame packed startup |
| `godot --headless --path godot --quit-after 600` | exit 0, 0 errors, 0 warnings |
| PixiJS under Node v24.15.0: `npm test`, `npm run build`, `npm run smoke`, `npm run playtest -- --skill 0.7 --ending knight --choice first` | 30 files / **248 tests passed**; build OK; smoke **36/36 sub-levels ok**; playtest 36 sub-levels, 0 unfinished, 0 flagged, 0 page errors, ending KNIGHT; all exit 0 |
| `godot/tools/source_tree_guard.sh`; `git diff --check` | guard OK (only `/godot` and `docs/porting` differ from `95b69c0`); diff clean |

### Windows evidence: still not obtained (historical; obtained since, see correction report 4)

"Windows PowerShell asset check exits 0" and "Godot Windows suite remains 107/107 or better" were
**not** run: no Windows machine is attached to this session and none is reachable from this
environment; the CI route needs the D-15 gate-5 exception (still proposed only, updated in
`docs/porting/proposals/godot-port-windows.yml`, which already runs `npx playwright install
chromium`). What changed for the Windows check: with F-13 fixed, the committed outputs now
carry the same pinned Chromium that a Windows `npx playwright install chromium` provides, and
the font/audio outputs proved independent of the Chromium build (157 vs 153). Rasterization and
WebAudio decoding on Windows itself remain unverified.

Simulated Windows checkout (not Windows evidence): `git clone -c core.autocrlf=true` of this commit
(CRLF in 111 source `.ts` files), `npm ci`, then the same asset check (**exit 0**, 33 + 7 outputs
identical, pinned Chromium 153.0.8010.12), the full suite (**110 passed, 0 failed**) and the
600-frame run (exit 0, 0 errors, 0 warnings); `git status` stayed clean.

### Architect review result

Pending.

---

## Historical — correction report 2: second M1/M2 review (`9f458f8`; M1 Partial, M2 Partial)

> Historical record of `9f458f8`, superseded by later reports; current status is correction report 4.

Scope: the architect's nine items on `7b67122`, in one commit. No M3 content. IsoGrid,
GridKinematicSolver, movement, camera, depth sorting, Green Zone rules, safe-area routing, the
audio lifecycle and the three-layer pollution renderer are unchanged (the renderer layers and
AudioService only gained the debug-only bounds of item 5).

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (nothing accepted) |
| Base | `7b67122` |
| Godot / toolchain | 4.7.2.stable.official.ed1daf0bf Linux x86_64; Node v24.15.0, Playwright 1.63.0, Chromium 157.0.8103.78 |
| Hosts not available | **Windows** (none reachable from this environment; see "Windows evidence"); Android (no SDK, templates or device) |

### Changes per review item

1. **Windows dynamic imports.** All 22 dynamic imports of audited source modules in
   `extract.mjs` go through `importSource(rel)` = `import(pathToFileURL(path.join(SRC, rel)).href)`
   (a bare `C:\…` path is rejected by the ESM loader as an unsupported URL scheme). The TS resolve
   hooks already used `pathToFileURL`. Verified on Linux (regeneration and `--check`); **not run on
   Windows** (see below).
2. **Export-safe leading silence.** `tools/build_resources.gd` builds
   `data/audio/sfx_leading_silence.tres` (`SfxLeadingSilence`: audited commit, runtime rate 48000,
   trim level, cue → seconds) from the extractor's JSON; `build_resources --check` now verifies 7
   outputs. `AudioService` preloads the Resource and reads no JSON; the JSON stays a non-exported
   build input (`data/*.json, data/*/*.json` exclusions unchanged). `assets/environment/manifest.json`
   is excluded from the release package. New integration case
   `test_SLICE_android_pck_has_runtime_data_and_starts_clean`: `--export-pack "Android"` with the
   running binary (no export templates needed), then the pack as the only `res://` (`--main-pack`):
   every runtime resource of the project (82, derived from the project tree, minus the font page
   PNG that the `.fnt` import consumes) loads from the pack, OFL.txt is present, nothing under
   `tests/`/`tools/` and no `.json`/`.md` is packed, AudioService has the 6 offsets from the pack,
   the real main scene starts the Green Zone with Zampanò's SpriteFrames, and a 600-frame packed
   startup exits 0 with no engine error or warning. Packed runs get their own user-data directory
   (`XDG_DATA_HOME`/`APPDATA`), so they never touch a real save.
3. **Future format in main, temp and backup.** `load_from_disk` validates all three files first.
   Any future-format file is copied byte-for-byte (`save_v3.future.json`,
   `save_v3.tmp.future.json`, `save_v3.bak.future.json`; an identical copy is not rewritten, a
   different earlier copy is kept), `future_files` lists the locations, no save file is touched
   again (no temp deletion, no promotion, no rotation) and every write is refused
   (`write_blocked_future_version`). A future main loads defaults; otherwise the valid
   current-format file is shown read-only. `test_SAV_022_…` covers each location with a payload
   containing CRLF, non-ASCII characters and trailing spaces: status, blocked writes, every file
   byte-identical after two refused writes, the copy byte-identical, and a second launch.
4. **No corrupt copy of a valid older main.** Only an INVALID main is written to
   `save_v3.corrupt.json`; on temp recovery a valid older main is rotated to the backup by the
   normal write. `test_SLICE_temp_recovery_keeps_a_valid_older_main_as_backup` (plus the invalid
   main case, still preserved).
5. **Bounded, debug-only diagnostics.** `AudioService.started` records only when
   `diagnostics` (default `OS.is_debug_build()`) and keeps the last 64 entries; the Ground and
   overlay TileMap layers record `applied` only in debug builds and for at most 256 distinct cells
   (the integer `callback_calls` counter stays). `test_SLICE_diagnostics_are_bounded_and_debug_only`.
6. **MAP-007** is one aggregator, `test_MAP_007_green_zone_topology_route_and_treats_match_source`:
   96×96 rows (and SHA-256), size, start/exit, playable tiles, every prop, every ground count,
   the exit-distance field, the canonical start→exit route length (the source's `startDist` that
   `placeTreats` walks) and the 30 treat placements (twice, same seed). The separate `MAP_007b`
   case is gone.
7. **Profile isolation.** `AppState.reload()` resets `selected_profile` to the validated default on
   every call; `--as=<id>` is accepted only for profiles in `AppState.PROFILES` (Zampanò in this
   build), otherwise rejected with a warning and recorded in `rejected_profile`. The isolation pair
   dirties both fields; `test_SLICE_profile_override_is_validated` covers the pure resolver.
8. **AUTO-001 label removed** from the slice driver, the slice run case and its output line.
9. **VIEW-002 resolved for the original algorithm.** No new clamp. The extractor executes the
   source `computeViewport` over a dense grid (5 DPRs × 26 widths × 22 heights = 2,860 cases,
   device px 100–2,525 × 160–2,911) and stores the outputs; `test_VIEW_002_…` requires the Godot
   result to equal the source in every case, an integer scale, and width 192–270 / aspect
   0.42–0.62 wherever the source gives them, the only exceptions being the source's own (narrow
   areas: scale 1 at their width, 360 cases; constrained areas 271–383 px: scale 2 at 135–191 px,
   210 cases; 2,290 in range). TEST_PLAN VIEW-002 now states this resolution.

### Commands executed and results (Linux)

| Command | Result |
|---|---|
| `NODE=/opt/node24150/bin/node godot/tools/build_assets.sh --check godot` | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 157.0.8103.78`; `build_resources check (all): OK, 7 outputs identical`; exit 0 |
| `rm -rf godot/.godot && godot --headless --path godot --import` | exit 0, 0 errors, 0 warnings |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **107 passed, 0 failed** (unit 59, content 14, integration 34), exit 0; VIEW-002 compared 2,860 source cases; the PCK case exported 5,183,640 bytes, checked 82 runtime resources against 169 packed files |
| `godot --headless --path godot --quit-after 600` | exit 0, 0 errors, 0 warnings |
| PixiJS under Node v24.15.0: `npm test`, `npm run build`, `npm run smoke`, `npm run playtest -- --skill 0.7 --ending knight --choice first` | 30 files / **248 tests passed**; build OK; smoke **36/36 sub-levels ok**; playtest 36 sub-levels, 0 unfinished, 0 flagged, 0 page errors, ending KNIGHT; all exit 0 |
| `godot/tools/source_tree_guard.sh`; `git diff --check` | guard OK (only `/godot` and `docs/porting` differ from `95b69c0`); diff clean |

Captures and the rendered probes were not re-run: nothing visual or in the interpolation path
changed (the 18 captures of correction report 1 stand).

### Windows evidence: not obtained (blocked) (historical; obtained since, see correction report 4)

The two Windows items of the required evidence were **not** produced:

- "Windows PowerShell asset check exits 0" — not run.
- "Godot Windows console suite remains 104/104 or better" — not run.

No Windows machine is reachable from this cloud environment (no attached computer). Two ways to get
it were attempted and stopped by this environment's permission policy, deliberately not worked
around:

- A GitHub Actions workflow on a `windows-2025` runner (the repository is public, so the runner
  is free) needs a file in `.github/workflows/`, outside the paths MILESTONES gate 5 allows, and an
  exception in `godot/tools/source_tree_guard.sh`. Widening the guard was refused as an oversight
  change that is the architect's to approve. The ready workflow is kept, **inactive**, at
  `docs/porting/proposals/godot-port-windows.yml` (D-15): it verifies the official Godot 4.7.2
  win64 zip against `SHA512-SUMS.txt`, uses the pinned Node, runs `npm ci` and the lockfile's
  Chromium, then exactly `pwsh godot/tools/build_assets.ps1 -Godot <console exe> -Check`, the
  console import + suite, the 600-frame run, and fails if the checks modified tracked files.
- Installing PowerShell 7 for Linux to at least execute `build_assets.ps1` here was refused too.

The simulated Windows checkout below (`core.autocrlf=true`) is repeated for this commit; it is
not Windows evidence.

`git clone -c core.autocrlf=true` of this commit, then (pinned Node 24.15.0):

| Step in the clone | Result |
|---|---|
| checkout | CRLF in 111 source `.ts` files; LF in every Godot text file (the only CRLF file under `godot/` is the verbatim `assets/environment/manifest.json`, binary by design); `git status` clean |
| `npm ci` | exit 0 |
| `NODE=… godot/tools/build_assets.sh --check godot` (includes a clean `--import`) | `asset check OK: 33 outputs identical (15 copies) …`; `build_resources check (all): OK, 7 outputs identical`; exit 0 |
| full suite | **107 passed, 0 failed**, exit 0 (includes the PCK export/packed-runtime case) |
| `--quit-after 600` | exit 0, 0 errors, 0 warnings; `git status` still clean |

### Deviations

| ID | Status |
|---|---|
| D-15 | **New, needs approval:** Windows CI workflow outside `/godot` and `docs/porting` (gate 5 exception) to produce the Windows evidence; proposed only, not active |
| F-09 / VIEW-002 | Closed by the review resolution: the source algorithm is authoritative |
| D-01–D-14 | As in correction report 1 |

### Architect review result

Pending.

---

## Historical — correction report 1: M1/M2 review fixes (`7b67122`; M1 Partial, M2 Partial)

> Historical record of `7b67122`, superseded by later reports; current status is correction report 4.

Scope: the architect's ten correction items on `5858dc7`, in one commit. No M3 content. IsoGrid,
GridKinematicSolver, movement, depth sorting, camera, needs, pollution and scoring logic are
unchanged (only presentation rounding, diagnostics counters and test hooks were added around them).

| Field | Value |
|---|---|
| Milestone status | **M1 Partial, M2 Partial** (neither complete; nothing accepted) |
| Base | `5858dc7` |
| Godot | 4.7.2.stable.official.ed1daf0bf, Linux x86_64 |
| Asset toolchain | Node **v24.15.0** (official linux-x64 build, = `godot/tools/.node-version`), Playwright 1.63.0 (= `package-lock.json`), Chromium 157.0.8103.78 |
| Renderer for captures/probes | Xvfb + Mesa llvmpipe, GL Compatibility |
| Hosts not available | Windows (no Windows host or Wine here); Android (no SDK, templates or device) |

### Changes per review item

1. **Platform-independent asset pipeline.** The extractor reads every source input as the audited Git
   blob (`git cat-file blob 95b69c0:<path>`), so working-tree line endings (autocrlf) cannot change
   a hash or an output. Generated text (FNT, JSON, `.tres`, `.import`) is LF and refused if it
   contains CR; `godot/.gitattributes` pins LF for every generated/edited text type and marks
   binary inputs (`assets/environment/manifest.json` is a CRLF blob in the source and is copied
   byte-for-byte; PNG/MP3/WAV/WOFF2/OFL.txt). `--check` now verifies every generated output
   (33 outputs incl. 15 copies, SHA-256 in `data/source_asset_manifest.json`) and
   `build_resources.gd --check` verifies the 6 Godot-built outputs. Guards: refuses to run if
   `src/`, `public/`, `assets/`, `package.json` or `package-lock.json` differ from the audit
   (exit 3), if Node is not exactly v24.15.0 (exit 4), or if the installed Playwright differs from
   the lockfile (exit 5). Everything was regenerated under 24.15.0. Windows commands:
   `godot/tools/build_assets.ps1 -Godot <Godot_v4.7.2-stable_win64_console.exe> -Check` and the
   `_console.exe` test command (README, TEST_PLAN §2).
2. `application/config/quit_on_go_back=false`; `test_SLICE_android_back_pauses_and_never_quits`
   asserts the setting and that Back pauses (Android Back itself unverified on device).
3. **Evidence corrected.** Case naming (TEST_PLAN): `test_<ID>_…` only when every clause is
   exercised, `test_P_<ID>_…` partial, `test_SLICE_…` no plan ID. 104 cases were renamed or
   classified accordingly; M1 and M2 marked Partial; capture count corrected (below); AUTO-001 is
   not claimed and stays reserved for the M3 run with an attack. Errata for the first report are
   listed in that report.
4. **Missing M2 tests added:** VIEW-003 (safe-area override + real `Input.parse_input_event`
   routing through the SubViewportContainer, ≤0.5 logical px), P_VIEW_004, MOVE-005, COLL-003
   (segment-through-obstacle tunnelling at run speed and worst delta), P_COLL_005, DEPTH-003,
   CAM-003, MAP-006, DOG-004, P_DOG_005, DOG-006, CORE-002 at 30/60/90/120 FPS caps, real SubViewport
   multi-touch routing, test-state isolation (`_isolate()` per case: InputService, AudioService,
   SaveService per-case `user://test_runs/<pid>/case_NNN/`, AppState reload, renderable IDs,
   `Engine.max_fps`, time scale; proven by the `SLICE_isolation_1/2` pair), and the rendered
   multi-rate probe (below).
5. **Deep water and walls:** DEEP (phase-rotated `deep_phase0/1` by `hash2(i,j,74)`), WALL
   (`wallBase_0` + depth-sorted `wallBlock` props by `hash2(i,j,5)`) and the story grounds render
   through the shared IsoWorld; COLL-004 covers blocked/walkable grounds including deep water and
   walls; `test_SLICE_deep_water_and_wall_diagnostic_rendering` + capture 20.
6. **SaveService:** `load_status` (new / loaded / recovered_from_temp / recovered_from_backup /
   future_version / corrupt) and `last_error`; the newest valid of main/temp/backup wins; a corrupt
   main is preserved as `save_v3.corrupt.json`; a future-format main is copied byte-for-byte to
   `save_v3.future.json` and writing is blocked; `save_failed` is emitted on any write failure and
   callers report `saved`. SAV-020 injects a crash at all four write stages; SAV-022 replaces the
   vacuous test with real assertions (file untouched, writes blocked, status reported).
7. **Audio:** the briefing and the result card play `intro`, the walk plays `greenzone`, each track
   resumes from its own position; background (`APPLICATION_PAUSED`/focus out) suspends music and
   every effect player, and effects started while suspended start paused; effects start after the
   source's leading silence (computed by executing the source `leadingSilence` in Chromium at 48 kHz:
   bark 0.0947 s, treat 0.0404 s, pee 0.0075 s, drink 0.2799 s, poop/splash 0); the drink WAV is
   imported lossless (`compress/mode=0`).
8. In-viewport `#0c3a10` underlay (canvas layer −100, logical size) under the world; the outer
   pillar/letterbox stays black (`test_SLICE_viewport_underlay_and_black_letterbox`, capture 20).
9. ARCHITECTURE §7 and TEST_PLAN now state the measured `TILE_LAYER_OFFSET = Vector2(-16, 0)` and
   approve the three-layer pollution renderer (Ground tint, Pollution, Fresh); WORLD-005 asserts
   the TileData the engine itself passes to `_tile_data_runtime_update`.
10. `assets/fonts/OFL.txt` is in the export `include_filter`; the Android label is restored to
    `SUPERVILLAINED: CRUSADER` (`test_SLICE_export_ships_ofl_and_the_app_label`).

### Commands executed and results (Linux)

| Command | Result |
|---|---|
| `NODE=/opt/node24150/bin/node godot/tools/build_assets.sh --check godot` | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 157.0.8103.78`; `build_resources check (all): OK, 6 outputs identical`; exit 0 |
| the extractor under Node v24.22.3 | `Node v24.22.3 is not the pinned v24.15.0 … refusing to run.`, exit 4 |
| simulated Windows checkout: `git clone -c core.autocrlf=true`, `npm ci`, `--check`, suite, 600-frame run in the clone | all exit 0, see "Simulated CRLF clone" below |
| `rm -rf godot/.godot && godot --headless --path godot --import` | exit 0, 0 errors, 0 warnings |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **104 passed, 0 failed** (unit 58, content 14, integration 32), exit 0, no leaks or orphans |
| `godot --headless --path godot --quit-after 600` | exit 0, 0 errors, 0 warnings |
| `xvfb-run … tools/interpolation_probe.gd` | exit 0 (results below) |
| `godot --headless --path godot --script res://tools/audio_suspend_probe.gd` (forces playback on the Dummy driver so playbacks are live; outside the suite because they are never mixed) | `{"late_effect_paused":true,"live_players":2,"ok":true,"paused_in_background":[true,true],"resumed":[true,true]}`, exit 0; the engine then reports the never-mixed playbacks as leaked at exit (6 objects, 3 resources), the reason this probe is outside the suite |
| `xvfb-run … capture_suite.gd` (tour, `--mode run`, `--mode diagnostic`, two viewport sizes) | 18 PNGs (below); the real-time run reached the exit with total 5660 at 45.17 s |
| PixiJS under Node v24.15.0: `npm test`, `npm run build`, `npm run smoke`, `npm run playtest -- --skill 0.7 --ending knight --choice first` | 30 files / **248 tests passed**; build OK; smoke **36/36 sub-levels ok**; playtest 36 sub-levels, 0 unfinished, 0 flagged, 0 page errors, ending KNIGHT; all exit 0 (also green under v24.22.3) |
| `godot/tools/source_tree_guard.sh`; `git diff --check` | guard OK (only `/godot` and `docs/porting` differ from `95b69c0`); diff clean |

### Rendered multi-rate interpolation probe (`tools/interpolation_probe.gd`, 432×432, llvmpipe)

The real PlayableDog runs east at RUN speed under a static camera; each rendered frame is read
back. Interpolated runs: no repeated frame while moving, no jump beyond two frames' worth, teleport
shown at once. A control run with interpolation off must stutter (it does), proving the metric.
A last pass follows the dog with the real CameraRig: two static markers 40 px apart stay exactly
40 px apart on every frame (no static shimmer).

| FPS cap | achieved | expected px/frame | repeated frames | max px/frame | teleport error px |
|---|---|---|---|---|---|
| 30 | 30.0 | 5.65 | 0 | 6.5 | 3.5 |
| 60 | 60.1 | 2.82 | 0 | 3.5 | 0.5 |
| 90 | 90.0 | 1.88 | 0 | 2.5 | 1.0 |
| 120 | 119.9 | 1.42 | 0 | 2.0 | 1.0 |
| 120, interpolation **off** (control) | 120.4 | 1.41 | **21** | 3.0 | 1.0 |

Camera-follow pass: 90 and 120 FPS, 48/48 frames measured, marker gap always 40 px. This is
renderer evidence for VIEW-004/DOG-008/CAM-004 but runs outside the headless suite and on llvmpipe
only, so those IDs stay partial.

### Captures (18 PNGs in `docs/porting/captures/m2_green_zone_slice/`)

- Tour, 432×864 (logical 216×432 at scale 2), 8: `01_briefing` … `08_touch_joystick`.
- Real-input run, 5: `10_poop_dirt`, `11_pee_cleans_poop`, `12_occlusion_fade`,
  `13_level_end_reveal`, `14_level_end_final`.
- Diagnostic, 800×600, 1: `20_diagnostic_deep_water_walls_story_grounds` (deep water, walls and
  wall blocks, story grounds, void on the green underlay, black pillarbox outside the viewport).
- Viewport extremes, 4: `view_192x457/{02_start,03_walk_north}`, `view_270x435/{02_start,03_walk_north}`.

### Simulated CRLF clone

Closest available stand-in for a Windows clean clone (Linux, not a Windows host):
`git clone -c core.autocrlf=true --branch claude/gallant-keller-rbvtvy` of this commit's tree.
The checkout had CRLF line endings in 111 source text files (e.g. `src/core/audio.ts`,
`package.json`) and LF in every Godot text file (`godot/.gitattributes`); `git status` clean.

| Step in the clone | Result |
|---|---|
| `npm ci` (Node v24.15.0) | exit 0 |
| `NODE=… godot/tools/build_assets.sh --check godot` (includes a clean `--import`) | `asset check OK: 33 outputs identical (15 copies), Node v24.15.0, Playwright 1.63.0, Chromium 157.0.8103.78`; `build_resources check (all): OK, 6 outputs identical`; exit 0; `git status` still clean |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **104 passed, 0 failed**, exit 0 |
| `godot --headless --path godot --quit-after 600` | exit 0, 0 errors, 0 warnings; `git status` still clean |

### Not verified

- **Windows host:** the clean-clone asset `--check` and the Godot 4.7.2 Windows console suite were
  not executed on Windows (no Windows host here). The simulated `core.autocrlf=true` clone above is
  the closest available evidence; the PowerShell script and `_console.exe` commands are untested.
- **Android/device:** export, install, Back, immersive mode, keep-awake, display-cutout safe area,
  touch hardware, audio focus/background on a real app lifecycle, performance. Configuration only.

### Findings added by this correction

- **F-09 (VIEW-002):** the source `computeViewport` yields logical widths 135–191 px for constrained
  areas 271–383 device px wide (scale 2), outside the plan's 192–270. The port keeps source parity
  (`test_P_VIEW_002` asserts the band); the owner decides whether the plan or the source is right.
- **F-10:** `get_cell_tile_data()` returns the shared TileSet data; only the TileData the engine
  passes to `_tile_data_runtime_update` shows the runtime tint, so WORLD-005 records it inside the
  callback.
- **F-11:** `AudioStreamPlayer.stream_paused` is kept only by a live playback and a paused playback
  reports `playing == false`; with the Dummy driver no playback is live, so the suite checks the
  suspension mapping and the probe checks live playbacks under a real driver.
- **F-12:** the test runner previously skipped a test file that failed to parse (0 cases, no
  failure); it now fails the run.

### Deviations status after this correction

| ID | Status |
|---|---|
| D-02 | Closed: three runtime layers approved in ARCHITECTURE §7 |
| D-05 | Partly closed: recorded intro/greenzone music, six effects, leading-silence offsets, background suspension; synthesized cues still silent (M1 audio pipeline) |
| D-12 | Closed: Node v24.15.0 pinned, enforced and used for all generated outputs |
| D-14 | Partly closed: logic at 30/60/90/120 FPS in the suite; rendered presentation by probe (llvmpipe); device rates unverified |
| D-01, D-03, D-04, D-06–D-11, D-13 | Unchanged |
| B-03, B-05 | Closed (ARCHITECTURE §7 offset; TEST_PLAN import step) |
| B-01, B-02, B-04 | Unchanged |

### Architect review result

Pending.

---

## Historical — milestone report: M1 foundation (partial) + M2 Green Zone vertical slice (first submission, `5858dc7`)

> Historical record of `5858dc7`, superseded by later reports; current status is correction report 4.

**Errata (corrected by the report above; this report is kept as submitted otherwise):**
- The "Automated cases" list below used plan IDs for partial checks. Of those, AUTO-001, CFG-001,
  FLOW-004, FLOW-005, GZ-001, GZ-002, GZ-005, GZ-018, GZ-021, GZ-029, AST-001–005/012/016–018/020,
  AUD-001, ARCH-001, MAP-003b, CAM-004, COLL-005, SAV-021, UI-001 and RNG-002 were not satisfied in
  full; the current classification is the correction report's and the matrix status section's.
- AUTO-001 is not claimed: it requires an attack (M3).
- Captures: 13 scripted/run captures + 4 viewport captures = 17, not "14 + 4".
- Tooling: the outputs of this submission were generated under Node v24.22.3; they were
  regenerated under the pinned v24.15.0 by the correction (D-12 closed).

| Field | Value |
|---|---|
| Milestone | First playable milestone requested by the owner: M1 core foundation and content pipeline (partial) + M2 vertical slice, extended with the Green Zone needs/pollution loop, HUD, basic save and start/finish flow from M3/M4 |
| Branch | `claude/gallant-keller-rbvtvy` (session-mandated dedicated porting branch; see B-02) |
| Base | `fb9daa8` = merge of audited source `95b69c0` into the planning-docs commit `576cbdb` (tree = source + 4 planning docs, no other change) |
| Godot | 4.7.2.stable.official.ed1daf0bf, Linux x86_64, from the official GitHub release; SHA-512 `9aa00f7a…ed54c65` matches `SHA512-SUMS.txt` |
| Source reference commit | `95b69c04c5c3b9626e49719f8f916a44659cd265` |
| Tooling | Node v24.22.3 (pin 24.15.0 unavailable, D-12), Playwright 1.63.0, Chromium 157.0.8103.78, Mesa 25.2.8 llvmpipe (captures) |
| Device | No Android device, SDK or export templates in this environment: Android not built or installed |

### Commands executed and results

| Command | Result |
|---|---|
| `godot/tools/build_assets.sh godot` (twice) | first run generated outputs; second run: `extract done … 0 file(s) changed`, `build_resources (images): OK, 0 file(s) changed`, `build_resources (resources): OK, 0 file(s) changed`; SHA-256 of every `.tres/.png/.import` identical across runs (AST-019) |
| `node … extract.mjs --check` | `asset check OK (14 copies, 4 inputs)` |
| `rm -rf godot/.godot && godot --headless --path godot --import` | exit 0, 0 errors, 0 warnings (CORE-001 clean cache) |
| `godot --headless --path godot --script res://tests/test_runner.gd -- --suite all` | **73 passed, 0 failed** (unit 46, content 11, integration 16), exit 0, no leaked objects at exit |
| `godot --headless --path godot --quit-after 600` (real Main scene, real main loop) | exit 0, 0 errors, 0 warnings |
| `xvfb-run … capture_suite.gd` (tour) and `--mode run` | 14 captures + 4 viewport captures in `docs/porting/captures/m2_green_zone_slice/`; real-time full run reached the exit with total 5660 at 45.2 s, identical to the deterministic headless run |
| `godot/tools/source_tree_guard.sh` | `OK: only /godot and docs/porting differ from 95b69c0` |
| `npm ci && npm test && npm run build` (source baseline, Node 24.22.3) | 30/30 files, **248/248 tests passed**; TypeScript + Vite build passed |
| `git diff --check` | clean |

### Automated cases (all executed, all passed)

- Unit: CFG-001, CORE-002, RNG-001/002/003, ISO-001/002/003/004, MOVE-001/002/003/004, VIEW-001/002,
  DEPTH-001/002, CAM-001, MAP-001/002 (incl. MAP-004), MAP-007 (rows, topology, props, BFS = MAP-005,
  reachability = COLL-005), GZ-001 (spot RNG), GZ-002 (needs script), GZ-005 (full scripted rules
  run: treats → warning → poop → pee-clean → drink → starvation → game over, every checkpoint and the
  complete event sequence equal to the source), GZ-008, GZ-018/019/020/021 (scoring), GZ-024,
  GZ-029, COLL-002/004, DOG-001/002/003/007, AST-005, FLOW-004 (exit), SAV-001/002/003/004/018/019/020/021/022.
- Content: AST-001/002/003/004/012/014/016/017/018/020, AUD-001.
- Integration: ARCH-001 and ARCH-001b (dummy story map through the same IsoWorld), MAP-003b,
  WORLD-004, WORLD-005, CAM-002/004, COLL-001/006, COLL-002 decision experiment, DEPTH-004, UI-001,
  MOVE-001 (keyboard + joystick + simultaneous RUN), FLOW-001/002/005, **AUTO-001**.

AUTO-001 (real input only — InputService movement and PEE, no teleport, no rule calls): start
(90,90) → exit (4,4) in 45.1 s game time, 30 treats, 7 poops, 6 pees (poops cleaned), 2 lives,
final health 0.9359, 3 stars, total score 5660, record saved, level-end overlay shown.

Source-parity precision achieved: grid solver identical to `GameMap.moveCircle` on 48 trajectories
(0.0 tile); Zampanò movement/animation traces (8 directions × walk/analog/run, exhaustion, idle
phases, scripted run, three terrains, action lock, knockback) within 1e-9 tile of the source class;
Green Zone rows, BFS field, 94 props and 30 treat positions identical; pollution field equal to
float32 precision.

### Captures (432×864 = logical 216×432 at integer scale 2; Mesa llvmpipe, GL Compatibility)

`01_briefing`, `02_start`, `03_walk_north`, `04_walk_east`, `05_run_northwest`, `06_pee_clean`,
`07_pause`, `08_touch_joystick`, `10_poop_dirt`, `11_pee_cleans_poop`, `12_occlusion_fade`,
`13_level_end_reveal`, `14_level_end_final`; viewport extremes `view_192x457/` and `view_270x435/`
(both scale 2). Manual review: tiles tessellate, path edge masks, prop anchors, 8-way sprite facing,
dirt overlay + dead-grass tint, fresh highlight, tree fade over the dog, HUD/touch layout inside the
view at all three widths.

### M2 collision decision (recorded once)

The 48 source trajectories were replayed through native `CharacterBody2D.move_and_slide()`
(floating, safe_margin 0.08, max_slides 4, wall_min_slide_angle 0.261799) against 1,194 projected
blocked-tile diamonds and prop ellipses: **21/48 trajectories exceed 0.10 tile (max 9.18 tile);
excluding starts that overlap an obstacle, 15/40 exceed (max 6.92 tile)**. Godot projects the
motion onto the wall tangent in screen space, which is not equivalent under the 2:1 projection to
the source's per-axis grid-space slide (for a grid-x wall the slide speed becomes vx − 0.6·vy).
**Selected: the approved GridKinematicSolver** (`WorldMapModel.move_circle`, exact port), 0.0 tile
deviation. `PlayableDog` stays a `CharacterBody2D` on PlayerBody (layer 2) with mask 0 (no
WorldSolid); no native slide is applied to static geometry. The test asserts native remains out of
tolerance so a future engine change forces a re-review.

### Findings for the architect

- **F-01 (contract error):** ARCHITECTURE.md §7 states `map_to_local(i,j) + Vector2(0,8)` equals
  `IsoGrid.grid_to_screen(i+0.5, j+0.5)`. Measured on 4.7.2 with ISOMETRIC + DIAMOND_DOWN +
  horizontal offset axis: `map_to_local(i,j) = tile centre + (16, 0)`. Every TileMapLayer therefore
  sits at `IsoGrid.TILE_LAYER_OFFSET = (-16, 0)`; MAP-003b proves alignment on six cells.
- **F-02:** Godot 4.7.2's decimal→double conversion (JSON, `String.to_float`, GDScript literals) is
  not correctly rounded (up to 18 ulps measured). Fixture floats are compared within 64 ulps
  (~1.4e-14 relative); RNG outputs are compared bit-exactly through their integer numerators.
- **F-03:** `Vector2` is 32-bit in official builds. Authoritative grid state (positions,
  velocities, distances, dirt) is kept in 64-bit floats; `Vector2` is presentation-only.
- **F-04:** V8's `Math.hypot` (normalised Kahan) is not bit-identical to `sqrt(x²+y²)`; it is
  ported as `JsMath.hypot` so distances and pollution stamps match the source bit-for-bit.
- **F-05:** An entry `--script` cannot statically reference classes that use autoload globals; the
  runner and capture tool access them dynamically.
- **F-06:** `JSON.parse_string` logs an engine error on corrupt input; SaveService uses
  `JSON.new().parse()` so corruption recovery is silent and testable.
- **F-07:** With the Dummy audio driver (headless/no sound card) playbacks are never mixed and leak
  at exit; AudioService records requested cues but does not play on Dummy.
- **F-08:** Camera2D under physics interpolation must be declared physics-process
  (`process_callback = 0`), otherwise the engine warns and overrides it.

### Known deviations in this milestone (to close or approve)

| ID | Deviation | Closes in |
|---|---|---|
| D-01 | Tuning is typed GDScript constants (`core/game_config.gd`) verified value-by-value against the source export (CFG-001), not `.tres` balance Resources | architect decision; trivial to convert |
| D-02 | Three runtime-updated TileMapLayers (ground tint, dirt, fresh) instead of two: in the source a cell can show dirt and the fresh highlight at once | architect decision |
| D-03 | The source's threat RNG is shared by cats/balls and pollution waves; with cats/balls not yet ported, wave placement matches the source only until the first cat spawn (16 s) | M3 |
| D-04 | Camera shake noise and treat bob phase use seeded/hashed values instead of `Math.random` (CAM-003 determinism; cosmetic) | approve |
| D-05 | Synthesized cues (warning, empty, hurt, jingle, gameover, star, …) are silent; requests are counted in `AudioService.missing_cues`. Recorded music/effects play | M1 audio pipeline (AUD-005–008) |
| D-06 | Text glow/outline-glow and the briefing's justified layout are simplified (shadow + centred wrap) | M8 |
| D-07 | Popups are text-only; the poop warning is a blinking "!" instead of the thought sprite; no particles | M8 |
| D-08 | No title/campaign yet: TITLE on the result card returns to the briefing; no CONTINUE handoff to 1.1; no Supervillained snap | M3–M5 |
| D-09 | Gesture bindings, action switcher and RUN-toggle UI are not wired (InputService supports toggle) | M3/M5 |
| D-10 | Cats, coins, magnet balls, Bagnaskiz and Under Attack are not ported | M3 |
| D-11 | Save: campaign subtree preserved as an opaque v2 object; `CampaignFlagSchema`, v1→v2 migration and legacy import not implemented | M4/M9 |
| D-12 | Node 24.22.3 used; the pinned 24.15.0 is not installed here (Playwright pinned version matches) | tooling |
| D-13 | Not done from M1: title WebP extraction (AST-010), synthesized audio WAVs, Sbrimbrulòn/Bagnaskiz profiles (AST-008/009), cast sheets, Android migration spike | M1 completion / M8 / M9 |
| D-14 | DOG-008/VIEW-004 multi-rate (30/90/120 FPS) presentation checks not executed; physics interpolation is enabled and resets on spawn/teleport/camera snap | M2 follow-up |

### Blockers and architecture conflicts

- **B-01:** The planning branch `codex/godot-port-architecture` does not exist on the remote; the four
  planning documents were taken from `main@576cbdb` (they are identical to what the milestone
  references).
- **B-02:** MILESTONES.md says "Claude Code creates `godot/vg1-port`"; this session may only push to
  `claude/gallant-keller-rbvtvy`, which is used as the dedicated porting branch.
- **B-03:** F-01 (TileMap offset contract) needs an architecture correction.
- **B-04:** Android: no export templates, SDK, signing identity, old APK or device here. The preset
  (`export_presets.cfg`: `com.zampano.supervillained`, versionCode 2, min SDK 24, portrait,
  immersive, no Internet permission) is configuration only; target SDK 36 applies only with a
  Gradle build. No APK/AAB was built and the WebView migration spike was not attempted.
- **B-05:** A clean clone must run `godot --headless --import` once before the test runner (global
  class registration); the documented TEST_PLAN command should include it.

### Android compatibility assessment (static, not device-verified)

GL Compatibility renderer; portrait orientation; keep-screen-on; ETC2/ASTC import enabled for
export validation; all pixel art imported lossless without mipmaps; touch via
`InputEventScreenTouch/Drag` with per-index pointer ownership; Back (`NOTIFICATION_WM_GO_BACK_REQUEST`)
and background (`NOTIFICATION_APPLICATION_PAUSED`/focus out) pause the run; no network API is used.

### Source-tree guard

Only `/godot` and `docs/porting/` (this log, the matrix status section, captures) differ from the
audited source commit.

### Architect review result

Pending.
