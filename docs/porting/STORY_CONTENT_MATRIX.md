# SUPERVILLAINED VG1 — Story content matrix (scenes 1.1–8.4)

One entry per scripted scene (1.0 is the Green Zone walk, ported in M3/M4). Rules, vocabulary and
schema: [`STORY_REWRITE_SPEC.md`](STORY_REWRITE_SPEC.md). Decisions and open owner questions:
[`STORY_REWRITE_DECISIONS.md`](STORY_REWRITE_DECISIONS.md) (`RD-nn`, `OQ-nn`).

Field key: **Titles** (old → proposed); **Purpose**; **History/place**; **Play** (gameplay
interaction); **Cast**; **Setup → payoff**; **Effects** (persistent effects and flags);
**Status** (keep / revise / replace / remove); **Refs** (short forms of `docs/STORY-SOURCES.md`);
**Open** (unresolved owner decision); **Impl** (technical status · narrative status).

Source references are the repository's: `docs/STORY.md` (the draft story), `docs/STORY-SOURCES.md`
(editions, attested/adaptation split) and the PixiJS chapter files. Where those materials do not
support a fact, the entry says **`REVIEW REQUIRED`**. Nothing here is a new verification of an
edition: "attested" means "listed as attested in `docs/STORY-SOURCES.md`".

## Level 1 — The Greenzone (reality)

Chapter: rewritten draft in `godot/data/story/chapters/ch1.tres` (intro and the Professor's Level 1
aside: kept from the draft, aside `REVIEW REQUIRED` for "Picardy", OQ-09).

### 1.1 A bucket on his head
- **Titles**: A bucket on his head → A bucket on his head.
- **Purpose**: the hinge from the Green Zone walk into the story; plants the helmet of 2.1.
- **History/place**: none (reality); the neighbourhood lane.
- **Play**: a sand bucket lands on his head; walk to the hedge gap with the head up (standing still
  or barking lets the bucket slide down: the visor closes); Confusione slaps it off.
- **Cast**: Zampanò, Watson, Confusione.
- **Setup → payoff**: the bucket → the slipping helmet of 2.1.
- **Effects**: remembered line "THERE WAS A BUCKET, AND IT FELT LIKE A HELMET."
- **Status**: keep (prose tightened; the first card names the walk it follows, RD-20).
- **Refs**: `docs/STORY.md` 1.1; PixiJS ch1 1.1 (adaptation: all).
- **Open**: —
- **Impl**: specified · rewrite drafted (Resources: M5R-B), narrative review pending.

### 1.2 Under the Professor's desk
- **Titles**: Under the Professor's desk → Under the Professor's desk (kept for the catalog, RD-21).
- **Purpose**: the lecture plants the three witnesses and the dream's numbers; Jack's gate teaches
  that barking (being heard) works where pushing does not.
- **History/place**: the Professor's study (lecture framing only): Villehardouin among the envoys
  who negotiated the fleet (attested: Villehardouin pp. 1–4, 6–7); Clari outside the leaders' room
  (attested claim: Clari XIII, "No one in the army knew this plan, except the leaders"); the fleet
  bought on credit, 85,000 marks (attested: Villehardouin pp. 6–7); fewer men came than the fleet
  was built for (Clari XI, a claim in its numbers); Niketas inside the walls watching —
  **REVIEW REQUIRED** (lecture framing; Niketas's presence in the city is not itemised for this
  scene in `docs/STORY-SOURCES.md`).
- **Play**: follow the Professor round the study (he lectures at each stop); sniff three scraps
  (chair leg, suitcase, coat hem); outside, Jack lets every dog through his gap but Zampanò:
  **success** — bark three times, Jack echoes him, heads pop up along the fences, the Professor's
  window creaks and Jack steps aside; **failure/recovery** — pushing into Jack gets "NOPE!", a hint
  after 3 and 8 pushes, and after 14 the window creaks anyway (nobody stays stuck).
- **Cast**: Zampanò, the Professor (his legs), Jack, a passing dog, heads along the fences.
- **Setup → payoff**: the three shards (8.2's study; 3.1/7.3/7.1 echoes); the gate → the walls; Jack
  as the band's echo.
- **Effects**: shards "A FLEET BOUGHT ON CREDIT", "A KNIGHT WHO KEPT WALKING", "A CITY SEEN FROM ITS
  WALLS" (names unchanged: the v1 migration keeps them); remembered line "THERE WAS A GATE, AND IT
  WAS A CHIHUAHUA."
- **Status**: revise (RD-06 one remembered line; RD-10 lecture lines; RD-11 narration; RD-19 gate;
  RD-22 the Professor sends him out).
- **Refs**: Villehardouin pp. 1–4, 6–7; Clari XI, XIII (Munro); `docs/STORY.md` 1.2.
- **Open**: OQ-03 (every lecture fragment), OQ-04 (Jack's breed in the remembered line).
- **Impl**: specified · rewrite drafted (Resources: M5R-B), narrative review pending.

### 1.3 The toll at the bowl
- **Titles**: The toll at the bowl → The toll at the bowl.
- **Purpose**: the band's toll; the first real choice (submit or not); the long way home.
- **History/place**: none (reality); the bowl's CLONG becomes Venice's harbour bell (3.1).
- **Play**: Bagnaskiz lets Sbrimbrulòn drink and demands "the usual apology"; Jack calls the fences
  to watch; **choice**: offer the paw (he then demands the other one) or look past him at the
  water; Watson drags the bowl out of reach either way; walk home to Santina's gate — Jack cuts off
  the direct path; the hedge is always open.
- **Cast**: Zampanò, Bagnaskiz, Sbrimbrulòn, Jack, Watson, heads along the fences.
- **Setup → payoff**: the denied direct path → 8.3 (the direct path walked, Bagnaskiz steps aside);
  the bowl always one step away → the fleet bought on credit.
- **Effects**: `pawOffered` = true (Supervillain −3) or false (RD-07); `longWay` = true at
  completion (RD-08); remembered line "THERE WAS A BOWL, AND IT WAS ALWAYS ONE STEP AWAY."
- **Status**: revise (RD-07, RD-08, RD-11).
- **Refs**: `docs/STORY.md` 1.3 (adaptation: all).
- **Open**: OQ-01 (should the paw, or its refusal, pay off later?).
- **Impl**: specified · rewrite drafted (Resources: M5R-B), narrative review pending.

### 1.4 Santina wants her ball back
- **Titles**: Santina wants her ball back → Santina wants her ball back.
- **Purpose**: his sincere belief that she wants a performance; the unreturned ball, answered in 8.4.
- **History/place**: none (reality); Santina's gate. Echo of Clari 47 (the ladies at the windows)
  in 7.3/8.4.
- **Play**: the ball is on his side of her gate; she asks him to roll it back; he tries each of
  three performances (a bow, a display of strength, a compliment), each answered; the ball settles
  by the gatepost, on his side, and he leaves pleased.
- **Cast**: Zampanò, Santina, her friend.
- **Setup → payoff**: the ball stays on his side (RD-09) → 8.4 ("push the ball through the bars",
  `ballReturned`); his conviction → the woman on the walls in 7.3.
- **Effects**: `santinaBall` = "performed"; remembered line "THERE WAS A GATE, AND IT WAS A STAGE."
  (RD-06).
- **Status**: revise (RD-06, RD-09, RD-11).
- **Refs**: `docs/STORY.md` 1.4, 8.4; Clari 47 (7.3, attested).
- **Open**: OQ-05 (Santina's friend: name and role).
- **Impl**: specified · rewrite drafted (Resources: M5R-B), narrative review pending.

### 1.5 A cross of rag
- **Titles**: A cross of rag → A cross of rag.
- **Purpose**: the cloth cross; Zampanò's wish to belong; **the sleep boundary**.
- **History/place**: the Professor rehearses the taking of the cross, a cloth cross sewn on as the
  sign of those who took it (attested as the basis: Villehardouin pp. 1–4); "on the shoulder" and
  "in the spring they set off for Venice" — **REVIEW REQUIRED** (OQ-10).
- **Play**: take the red rag caught in the hedge and carry it home; in the study the Professor
  rehearses; the rag slides off his back and he lays it on again; **choice** with Confusione
  ("I AM ONE OF THEM" or say nothing); the Professor steps over him without looking down; curl up
  under the desk; the last card is the sleep.
- **Cast**: Zampanò, the Professor, Confusione.
- **Setup → payoff**: the rag → the coat of mail of 2.1 (dream only); the hem → a sail; the desk → a
  ship; "nobody looked" → 8.2–8.4 (telling his story at his real size).
- **Effects**: `unlock: cross` with Supervillain +3 ("I AM ONE OF THEM") or Commozione +3 (silence);
  remembered line "THERE WAS A RAG, AND IT WAS A CROSS, AND NOBODY LOOKED."
- **Status**: keep (prose tightened; RD-12 no armour in reality).
- **Refs**: Villehardouin pp. 1–4; `docs/STORY.md` 1.5.
- **Open**: OQ-06 (the two choice rewards), OQ-10 (the Professor's date line).
- **Impl**: specified · rewrite drafted (Resources: M5R-B), narrative review pending.

### Level 1 side by side (draft → rewritten draft)

| ID | Draft (PixiJS `ch1.ts`) | Rewritten draft (`godot/data/story/scenes/`) |
|---|---|---|
| 1.1 | Dozes, CLONK, Watson's line, the visor walk, the slap, the remembered line. | Same beats and lines; the first card says it follows the walk (RD-20); the bark echo and the hint kept. |
| 1.2 | Lecture lines include "HE SAW EVERYTHING AND WAS TOLD NOTHING" and "NOBODY SAILS IN WINTER"; two remembered lines; stage directions spoken inside Jack's lines; the move outside is unexplained. | "HE SAW A GREAT DEAL AND WAS TOLD VERY LITTLE"; the winter line replaced by the smaller army (Clari's claim); one remembered line; stage directions as narration; the Professor sends him out to drink (RD-10, RD-06, RD-11, RD-22). The gate's success and failure paths kept. |
| 1.3 | The paw sets `pawOffered`; looking past sets nothing; `longWay` always set after the walk; stage directions inside lines. | The paw sets `pawOffered: true` (−3), the water `pawOffered: false`; `longWay` documented as the completion marker; stage directions as narration (RD-07, RD-08, RD-11). |
| 1.4 | Three performances, the ball settles on his side; the remembered line "I WAS MAGNIFICENT AT IT" breaks the dream's grammar. | Same performances; "THE BALL STAYS WHERE IT IS" makes the 8.4 setup explicit; remembered line "THERE WAS A GATE, AND IT WAS A STAGE." (RD-09, RD-06). |
| 1.5 | The rag, the rehearsal, the choice (both unlock `cross`), the Professor's step over him, the desk, the sail card. | Same; the final card is the explicit sleep boundary; no armour in reality (RD-12). |

## Level 2 — On the edge of dreams (dream)

### 2.1 One step from Jerusalem
- **Titles**: One step from Jerusalem → (unchanged; rewrite in Level 2).
- **Purpose**: the dream's prologue image; the helmet that slips (the bucket).
- **History/place**: the leaders' real objective was Egypt; the people were told "overseas"
  (attested: Villehardouin p. 8; Clari XIII).
- **Play**: walk to Jerusalem's gate, always one step away; behind a door, "Babylon… Egypt first".
- **Cast**: Zampanò. **Setup → payoff**: Jerusalem never loads (7.9 "LOADING…").
- **Effects**: — (the dream skin begins: coat of mail, no arms).
- **Status**: keep. **Refs**: Villehardouin p. 8; Clari XIII. **Open**: —
- **Impl**: reference_only · draft_reference.

### 2.2 Names on a list
- **Titles**: Names on a list → (unchanged).
- **Purpose**: taking the cross; being counted at the bottom of the list.
- **History/place**: Fulk of Neuilly's preaching; the tourney of Écri; the counts take the cross;
  six envoys (attested: Villehardouin pp. 1–4).
- **Play**: shout the vow in the pauses of Fulk's preaching; a clerk lists names by rank.
- **Cast**: Fulk, a clerk, the marshal (Bagnaskiz), Zampanò.
- **Setup → payoff**: the vow → Grace's forms (5.1, 7.7).
- **Effects**: `unlock: sermon`, Grace +5, `vow`.
- **Status**: keep. **Refs**: Villehardouin pp. 1–4. **Open**: —
- **Impl**: reference_only · draft_reference.

### 2.3 A coat of mail too big
- **Titles**: A coat of mail too big → (unchanged).
- **Purpose**: first fight (bark only), the borrowed arms, falling in behind Pierre.
- **History/place**: Pierre d'Amiens is Clari's lord, Aleaume his brother, a clerk (attested:
  Clari 75–76, 120).
- **Play**: bark Jack and two lads off the road; pick up sword, belt, shield; spar with Pierre's
  squires (sword and shield; they parry).
- **Cast**: Jack and lads, Aleaume (Confusione), Pierre (Sbrimbrulòn), squires.
- **Setup → payoff**: the arms → fights in 5.3, 7.2; Pierre → 7.3.
- **Effects**: `unlock: knight`, Supervillain +8.
- **Status**: keep. **Refs**: Clari 75–76, 120. **Open**: —
- **Impl**: reference_only · draft_reference.

## Level 3 — Venice (dream)

### 3.1 Look at those ships
- **Titles**: unchanged. **Purpose**: Meraviglia opens; the empty berths.
- **History/place**: far fewer came than the fleet was built for (Clari XI, a claim in its
  numbers); horse transports (Clari 13); other ports (Villehardouin pp. 13–16).
- **Play**: follow Pierre on the quay; LOOK at transports, galleys, great ships; count empty berths.
- **Cast**: Pierre, Zampanò. **Setup → payoff**: marvels → 8.2's study furniture.
- **Effects**: marvels. **Status**: keep. **Refs**: Clari XI, 13; Villehardouin pp. 13–16.
- **Open**: — **Impl**: reference_only · draft_reference.

### 3.2 The price of passage
- **Titles**: unchanged. **Purpose**: the debt; two counts kept side by side.
- **History/place**: the treaty, 85,000 marks; collections; 34,000 (Villehardouin) vs 36,000
  (Clari) still owed (kept disagreement).
- **Play**: the marshal explains; take the collecting bowl round twice.
- **Cast**: the marshal, crowd. **Setup → payoff**: `shortfall` → 5.5's board.
- **Effects**: `shortfall` = 36000. **Status**: keep.
- **Refs**: Villehardouin pp. 6–7, 15–16; Clari XI–XII. **Open**: —
- **Impl**: reference_only · draft_reference.

### 3.3 The art of weeping
- **Titles**: unchanged. **Purpose**: the envoys' 1201 plea, played as a recollection.
- **History/place**: "knelt at the feet of the people, weeping many tears" (Villehardouin p. 8).
- **Play**: kneel, wait for quiet, weep; the square answers. **Cast**: envoys, crowd.
- **Setup → payoff**: weeping → Commozione; 6.3's kneeling chiefs. **Effects**: `weptWell`.
- **Status**: keep. **Refs**: Villehardouin pp. 7–8. **Open**: —
- **Impl**: reference_only · draft_reference.

### 3.4 Nobody leaves the Lido
- **Titles**: unchanged. **Purpose**: the deal for Zara, overheard.
- **History/place**: the island, the food threat, Zara, secrecy (Clari 10–13 / XI–XIII); the Doge
  takes the cross on his cotton hat (Villehardouin pp. 16–17).
- **Play**: follow a bread seller unseen to the council awning; overhear.
- **Cast**: the Doge, the marshal, a bread seller. **Setup → payoff**: `zaraDeal` → 4.3, 5.1.
- **Effects**: `zaraDeal`. **Status**: keep. **Refs**: Clari XI–XIII; Villehardouin pp. 16–17.
- **Open**: — **Impl**: reference_only · draft_reference.

## Level 4 — The sea (dream)

### 4.1 Veni Creator
- **Titles**: unchanged. **Purpose**: the fleet leaves Venice. **History/place**: *Veni Creator*
  from the ships' castles (Clari 13); sailing October 1202 (Villehardouin p. 19).
- **Play**: walk the deck with Watson; raise shields on the beat (rhythm minigame).
- **Cast**: Watson. **Setup → payoff**: marvel of the fleet. **Effects**: a marvel.
- **Status**: keep. **Refs**: Clari 13; Villehardouin p. 19. **Open**: —
- **Impl**: reference_only · draft_reference.

### 4.2 Horses below deck
- **Titles**: unchanged. **Purpose**: connective scene. **History/place**: horse transports exist
  (Clari 10, 13); the task is adaptation.
- **Play**: ease a skiff alongside; feed three horses; Watson drags the bucket out of reach.
- **Cast**: Watson. **Setup → payoff**: Watson's bucket echo of 1.3. **Effects**: —
- **Status**: keep. **Refs**: Clari 10, 13. **Open**: — **Impl**: reference_only · draft_reference.

### 4.3 Rumours on deck
- **Titles**: unchanged. **Purpose**: where is the fleet going? **History/place**: Zara and the
  arrival on the eve of Saint Martin (Villehardouin pp. 16, 19–20; Clari 13–14).
- **Play**: ask four men; the marshal says Zara; row into the harbour (rhythm minigame).
- **Cast**: the marshal, men on deck. **Effects**: `heardZara`.
- **Status**: keep. **Refs**: Villehardouin pp. 16, 19–20; Clari 13–14. **Open**: —
- **Impl**: reference_only · draft_reference.

## Level 5 — Zara (dream)

### 5.1 A small favor for Venice
- **Titles**: unchanged. **Purpose**: the pope's prohibition; the first dissent.
- **History/place**: the abbot of Vaux "on the part of the Pope of Rome" (Villehardouin p. 21);
  Zara's letter from Rome (Clari 14).
- **Play**: carry messages; say one aloud (costs Commozione).
- **Cast**: the abbot, the Doge, Aleaume. **Setup → payoff**: `dissent` → Standing/ending notes.
- **Effects**: "We took the cross for Jerusalem": Standing −12, Supervillain +5, Grace +4,
  `dissent`; or "the host falls apart…": Standing +5. **Status**: keep.
- **Refs**: Villehardouin pp. 20–21; Clari 14. **Open**: — **Impl**: reference_only · draft_reference.

### 5.2 A cross above the wall
- **Titles**: unchanged. **Purpose**: the siege; the cloth that leads to the pile.
- **History/place**: siege, surrender, the city divided (Villehardouin pp. 21–22).
- **Play**: climb the ladder (minigame), steady it for the next; follow a bolt of red cloth.
- **Cast**: pilgrims. **Setup → payoff**: `clothRoute` → 7.9's pile. **Effects**: `clothRoute`.
- **Status**: keep. **Refs**: Villehardouin pp. 21–22. **Open**: —
- **Impl**: reference_only · draft_reference.

### 5.3 Whose orders?
- **Titles**: unchanged. **Purpose**: whom he believes; the brawl.
- **History/place**: the fray between Venetians and pilgrims (Villehardouin p. 22; Clari 15).
- **Play**: three speeches; tell Aleaume which one; fight through the brawl (sword blows cost Grace).
- **Cast**: the abbot, the marshal, a Venetian, Aleaume. **Effects**: `zaraOwe` pope (Grace +5) /
  host (Standing +4) / debt (Grace −3); Grace −1 per landed sword blow.
- **Status**: keep. **Refs**: Villehardouin p. 22; Clari 15. **Open**: —
- **Impl**: reference_only · draft_reference.

### 5.4 A letter for Rome
- **Titles**: unchanged. **Purpose**: the absolution, in two versions.
- **History/place**: Villehardouin (the pilgrims) vs Clari 15 ("all the pilgrims and all the
  Venetians"): kept disagreement.
- **Play**: assemble the barons' account (letter minigame). **Cast**: clerks.
- **Effects**: — **Status**: keep. **Refs**: Villehardouin pp. 26–27; Clari 15. **Open**: —
- **Impl**: reference_only · draft_reference.

### 5.5 Winter at Zara
- **Titles**: unchanged. **Purpose**: the balance still owed. **History/place**: wintering at
  Zara; no money for Egypt (Clari 13, 16 / XVI).
- **Play**: carry the last sail into store; chalk the balance. **Cast**: Watson, sailmaker.
- **Setup → payoff**: JERUSALEM written at the top → 7.9. **Effects**: —
- **Status**: keep. **Refs**: Clari 13, 16. **Open**: — **Impl**: reference_only · draft_reference.

## Level 6 — The long winter (dream)

### 6.1 Short rations
- **Titles**: unchanged. **Purpose**: comradeship (read at the breach, 7.7).
- **History/place**: desertions (Villehardouin pp. 25–26); hardship (Clari XVI).
- **Play**: hand out half loaves; share yours (costs Commozione) or go to Jack's dice.
- **Cast**: Aleaume, Jack. **Setup → payoff**: `comradeship` → 7.7 (his voice guides you in).
- **Effects**: share: Supervillain +8, value *Comradeship*, `comradeship`; dice: Standing +4.
- **Status**: keep. **Refs**: Villehardouin pp. 25–26; Clari XVI. **Open**: —
- **Impl**: reference_only · draft_reference.

### 6.2 A prince on credit
- **Titles**: unchanged. **Purpose**: the young Alexios's offer, pieced together.
- **History/place**: the terms; only a dozen swear (Villehardouin pp. 23–25); Boniface knew him
  (Clari XVII).
- **Play**: rumour minigame. **Cast**: the cook, the council. **Effects**: —
- **Status**: keep. **Refs**: Villehardouin pp. 23–25; Clari XVII. **Open**: —
- **Impl**: reference_only · draft_reference.

### 6.3 On their knees at Corfu
- **Titles**: unchanged. **Purpose**: advice to Pierre; the fleet sails.
- **History/place**: Corfu; "Bah! What have we to do in Constantinople?" (Clari 31–33); the
  kneeling chiefs (Villehardouin pp. 27–30).
- **Play**: tell Pierre stay or Syria. **Cast**: the young Alexios, Pierre, the leaders.
- **Effects**: `corfu` stay (Standing +6) / syria (Supervillain +3, Standing −3).
- **Status**: keep. **Refs**: Villehardouin pp. 27–30; Clari 31–33, 39. **Open**: —
- **Impl**: reference_only · draft_reference.

## Level 7 — Constantinople (dream)

### 7.1 Looking both ways
- **Titles**: unchanged. **Purpose**: the city watching back. **History/place**: the city
  watching; the prince shown, not recognised (Clari 40–41; Villehardouin pp. 35–36).
- **Play**: LOOK at walls, roofs, domes; row the prince along the walls (tug/row minigame).
- **Cast**: Niketas, the young Alexios. **Effects**: three marvels.
- **Status**: keep. **Refs**: Clari 40–41; Villehardouin pp. 35–36. **Open**: —
- **Impl**: reference_only · draft_reference.

### 7.2 The Doge's banner
- **Titles**: unchanged. **Purpose**: 17 July 1203, the banner; a stand.
- **History/place**: the Doge with the standard; "more than forty people told him" (Villehardouin
  pp. 41–45). **Play**: follow the banner; hold your ground (fight, 18 s, shield up).
- **Cast**: the Doge, the marshal, axe-men. **Effects**: — **Status**: keep.
- **Refs**: Villehardouin pp. 41–45; Clari 46. **Open**: — **Impl**: reference_only · draft_reference.

### 7.3 Stay beside Pierre
- **Titles**: unchanged. **Purpose**: the dream's emotional centre; the walk at a walk.
- **History/place**: Pierre and Saint-Pol refuse to turn back; pots and pestles; the ladies;
  Flanders rejoins (Clari 45–48).
- **Play**: hold level with Pierre's shoulder at a walk (bespoke pace). **Cast**: Pierre, Flanders,
  Alexios III (Bagnaskiz), a woman with Santina's face. **Effects**: value *Physical courage*,
  `vanguard`. **Status**: keep. **Refs**: Clari 45–48. **Open**: —
- **Impl**: reference_only · draft_reference.

### 7.4 A city to visit
- **Titles**: unchanged. **Purpose**: marvels; the carved column. **History/place**: Alexios III
  flees, Isaac restored, Alexios IV crowned (Villehardouin pp. 45–48); the palace (Clari 80);
  pillars (Clari 92); the Hercules (Choniates).
- **Play**: visit with Watson (four marvels). **Cast**: Watson, Niketas.
- **Effects**: four marvels, `visitedCity`. **Status**: keep.
- **Refs**: Villehardouin pp. 45–48; Clari 80, 92; Choniates. **Open**: OQ-07 (the mosque).
- **Impl**: reference_only · draft_reference.

### 7.5 Unpaid promises
- **Titles**: unchanged. **Purpose**: the unpaid sums; the fire; the woman led home.
- **History/place**: the Doge's rebuke (Clari LIX, paraphrased); riot and two-day fire
  (Villehardouin pp. 48–53); the mosque as the fire's start (Barbero, not checked in an edition).
- **Play**: carry the chests; lead a woman of Niketas's household home.
- **Cast**: the Doge, Alexios IV, a woman of the household. **Effects**: —
- **Status**: revise — **contradiction to resolve**: `docs/STORY.md` "Old → new" says "the mosque
  omitted" for 7.4 while 7.5 and `docs/STORY-SOURCES.md` keep the mosque as the fire's start (OQ-07).
- **Refs**: Clari LVI, LIX; Villehardouin pp. 48–53; Barbero. **Open**: OQ-07.
- **Impl**: reference_only · draft_reference.

### 7.6 A third Alexios
- **Titles**: unchanged. **Purpose**: the defiance; the coup; "the dream runs out of faces".
- **History/place**: the defiance at Blachernae; fire-ships; Mourtzouphlos's coup (Villehardouin
  pp. 53–56; Clari 61–62, kept disagreement on the deaths).
- **Play**: walk in with the envoys at the same pace. **Cast**: envoys, Alexios V (Bagnaskiz).
- **Effects**: — **Status**: keep. **Refs**: Villehardouin pp. 53–56; Clari 61–62. **Open**: —
- **Impl**: reference_only · draft_reference.

### 7.7 The hole in the wall
- **Titles**: unchanged. **Purpose**: the oath; Aleaume's breach.
- **History/place**: the oath on booty, women and clergy (Clari 68); the failed Friday, the breach,
  Robert holding Aleaume's foot (Clari 70–79); 12 April 1204 (Villehardouin pp. 59–63).
- **Play**: swear; tug minigame (lost by design); with `comradeship` his voice guides you in.
- **Cast**: a bishop, Aleaume. **Effects**: Grace +5, `sworn`. **Status**: keep.
- **Refs**: Clari 68–79; Villehardouin pp. 59–63. **Open**: — **Impl**: reference_only · draft_reference.

### 7.8 Whose street was it?
- **Titles**: unchanged. **Purpose**: **decides the ending**.
- **History/place**: Clari 80 vs Choniates (kept disagreement); Niketas's flight and the girl let
  go when he recalls the oath (Barbero, after Niketas; not checked in an edition).
- **Play**: LOOK; turn the page to Niketas's account; at his doorway Jack drags a girl: call the
  pilgrims to their oath (costs Commozione) or stand silent while Niketas calls them.
- **Cast**: Niketas, Jack, a girl, pilgrims. **Effects**: call: Supervillain +15, Grace +5,
  Standing −6, value *Kept oaths*, `oath: enforced` (THE KNIGHT); silent: `oath: silent`
  (THE WITNESS, key `alpha`). **Status**: keep. **Refs**: Clari 80; Choniates (Munro pp. 15–16);
  Barbero. **Open**: — **Impl**: reference_only · draft_reference.

### 7.9 The common pile
- **Titles**: unchanged. **Purpose**: the lamp; the empty pedestal; Jerusalem never loads.
- **History/place**: treasure under guard, coarse silver for poor knights (Clari 81, 105);
  Aleaume's share (Clari 98); a knight hanged for keeping things back (Villehardouin pp. 65–66);
  statues melted (Choniates).
- **Play**: declare or hide the lamp. **Cast**: Saint-Pol, guards.
- **Effects**: declare: Grace +6, value *An honest share*; hide: Grace −8, coins +3.
- **Status**: keep. **Refs**: Clari 81, 92, 98, 105; Villehardouin pp. 65–66; Choniates.
- **Open**: — **Impl**: reference_only · draft_reference.

## Level 8 — Back to the Greenzone (reality)

### 8.1 Falling to pieces
- **Titles**: unchanged. **Purpose**: waking continues the dream in the body. **History/place**:
  none (reality). **Play**: scrambled legs; follow the knock and the smell of his cushion.
- **Cast**: Zampanò. **Effects**: — **Status**: keep. **Refs**: `docs/STORY.md` 8.1.
- **Open**: — **Impl**: reference_only · draft_reference.

### 8.2 What he can tell
- **Titles**: unchanged. **Purpose**: nothing came back; telling at his real size.
- **History/place**: Clari's "strict truth" (Clari 120). **Play**: LOOK at the study (marvels →
  furniture); tell the oath; leave one drawing. **Cast**: the Professor, Confusione.
- **Effects**: `tellingTier`, `drawing`, `letter`, `lamp` per the reference.
- **Status**: keep. **Refs**: Clari 120. **Open**: — **Impl**: reference_only · draft_reference.

### 8.3 The vanguard of the lawn
- **Titles**: unchanged. **Purpose**: the direct path to the bowl, at a walk; payoff of 1.3.
- **History/place**: none (reality); Pierre's walk (7.3) on the lawn.
- **Play**: walk the direct path; companions fall in. **Cast**: Sbrimbrulòn, Confusione, Bagnaskiz.
- **Effects**: Supervillain +25, value *Resistance*, `lawnHeld`. **Status**: keep.
- **Refs**: `docs/STORY.md` 8.3. **Open**: OQ-01 (does 8.3 acknowledge the 1.3 paw?).
- **Impl**: reference_only · draft_reference.

### 8.4 At Santina's gate, again
- **Titles**: unchanged. **Purpose**: the ball returned; her question unanswered.
- **History/place**: his version of Clari 47 (the ladies).
- **Play**: tell her his day; push the ball through the bars. **Cast**: Santina.
- **Setup → payoff**: 1.4's ball (RD-09). **Effects**: `ballReturned`, `courtesy84: unanswered`.
- **Status**: keep. **Refs**: Clari 47. **Open**: — **Impl**: reference_only · draft_reference.
