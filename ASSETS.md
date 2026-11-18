# Assets: replacing the placeholders

Every sprite in the game is described in **`src/assets/manifest.ts`**. Game logic only asks for
textures *by name*; the loader (`src/assets/build.ts`) either loads your PNG or generates a
code-drawn placeholder. To drop in final art you edit the manifest — never game logic.

Put image files under `public/` (served as-is and copied into the Android build). Paths in the
manifest are relative to `public/`, e.g. `sheet: 'sprites/zampano.png'` → `public/sprites/zampano.png`.
If a file is missing or broken the placeholder is used and a warning is printed in the console.

Tip: open the game with `?debug=sprites&char=zampano` (or `bagnaskiz`, `cat`, any cast key) to
see every animation and direction of a character playing side by side; add `&art=v1` or `&art=old`
for an older art version (below).

## Delivered art and the art versions

Three art versions, oldest first; **OPTIONS > ART** cycles NEW → UPDATE 1 → OLD (saved, applied at
once; `?art=new|v1|old` forces one for a test). **Nothing replaced is ever deleted**: each delivery
moves the files it replaces into the folder of the version they belong to.

| version | where | what |
|---|---|---|
| **OLD** | `public/sprites/old/` | the procedural art the game shipped with, frozen as PNGs by `npm run sprites:old` (drawn by the game's own generator, `src/assets/placeholders/`, also kept); the RUN chevrons (`runIcon.png`, 7 × 5) |
| **UPDATE 1** | `public/sprites/v1/` + the update-1 files still in use | sprite update 1 (`Supervillained-vg1-sprite-update-1.zip`) |
| **NEW** | `public/sprites/` | sprite update 2 (`Supervillained-vg1-sprite-update-2.zip`) over update 1 |

Both zips are kept at the repo root as delivered.

**Sprite update 1** replaced the procedural art of six characters and added the RUN icon:
`zampano.png` (only the **run** rows new; the rest the old art) and `zampano-tired.png` (the new
**tired** animation: standing still after running out of energy), both now in `sprites/v1/`;
`bagnaskiz.png` (fawn pug, black ears, yellow eyes), `sbrimbrulon.png` (long-haired tricolour
Shih-tzu), `jack.png` (black chihuahua, pink-lined ears), `watson.png` (white-and-orange Jack
Russell, teal cap, cigar), `confusione.png` (orange tabby fighting cat) and `runIcon.png` (13 × 11),
still in `sprites/` (update 2 kept them unchanged).

**Sprite update 2** (in `sprites/`) completes Zampanò and his two dream costumes, all with the
same 10 animations (160 × 3200) plus a tired sheet each (80 × 320):

| file | what it is |
|---|---|
| `zampano.png`, `zampano-tired.png` | the complete new Zampanò (fluffy ivory Maltese) |
| `zampanoCross.png`, `zampanoCross-tired.png` | with the rag cross sewn on his coat (worn from 1.5) |
| `zampanoKnight.png`, `zampanoKnight-tired.png` | with the white tabard and red cross and a big steel helm (from 2.5); the helm slips over his eyes when he sniffs or eats |

Its own QA notes (in the zip's `reports/QA.md`): NE reads more like a side view, the S idle is
seated, S run/fetch is a bobbing cycle rather than a gallop, the helm is blocky.

**In the manifest** each character with delivered art has `sheets`: a list of sheet sets, oldest
first, each with the version that introduced it (`since: 'old' | 'v1' | 'new'`), its `sheet` and
any `animSheets` (animations delivered as a sheet of their own, like `tired`). A version shows the
newest set introduced at or before it (`sheetSetFor`), so the band shows update 1 under NEW too,
and the costumes show the procedural art under UPDATE 1 (as update 1 did). A sheet that predates an
animation (no rows for it) shows the idle frames for it. The first set is always the procedural
art in `sprites/old/`; `tests/sprites.test.ts` checks every sheet's size against the manifest.

**The next update**: move the files it replaces into `public/sprites/v2/` (or the next version's
folder), add the version to `ART_VERSIONS` / `ART_LABELS`, give the replaced characters a set
for it and put the delivered files in `public/sprites/`. If it replaces art that is still
procedural, give that character an `old` set and run `npm run sprites:old` first.

Still procedural in every version: Bagnaskiz's masks `bagnaskizMarshal` / `bagnaskizEmperor`,
Santina, the Green Zone `cat` and the rest of the story cast.

## Directions

Eight facing directions, named as seen by the camera (screen space, **N = up/away from the camera**):

```
        N            N  : walking up the screen (seen from behind)
   NW       NE       NE : up-right along the iso grid axis (≈26.6° above horizontal)
 W             E     E  : right
   SW       SE       SE : down-right along the iso grid axis (seen 3/4 from the front)
        S            S  : toward the camera (face visible)
```

Sheet row order is always: `N, NE, E, SE, S, SW, W, NW`.
W/SW/NW may simply be mirrored copies of E/SE/NE.

## Characters

| key        | frame (px) | anchor (px) | animations                                                         |
|------------|-----------:|------------:|--------------------------------------------------------------------|
| `zampano`  | 40 × 40    | (20, 36)    | idle 2, walk 4, run 4, sniff 2, pee 2, poop 2, eat 2, bark 2, fetch 4, hurt 2, tired 2 (own sheet) |
| `bagnaskiz`| 40 × 40    | (20, 36)    | idle 2, walk 4, run 4, bark 2, hurt 2                              |
| `cat`      | 28 × 28    | (14, 25)    | idle 2, walk 4, run 4                                              |

### Story cast

The story mode adds 31 characters (`CAST_KEYS` in `src/assets/manifest.ts`), all 40 × 40,
anchor (20, 36), animations **idle 2, walk 4, run 4, bark 2, hurt 2** (same sheet layout as below,
5 animations × 8 directions = 40 rows):

| key | role in the VG1 design |
|-----|------------------------|
| `zampanoCross`, `zampanoKnight` | Zampanò with the rag cross (1.5) / in armour (2.5 onwards) |
| `sbrimbrulon` | Shih-tzu; Pierre d'Amiens in 7.3 |
| `jack`, `watson`, `santina`, `confusione` | the band and friends (Jack the absent general / looter, Watson the sailor, Santina the purple-born princess, Confusione as Aleaume) |
| `bagnaskizMarshal`, `bagnaskizEmperor` | Bagnaskiz's masks: Villehardouin, then the usurpers |
| `doge`, `king`, `emir`, `legate`, `cellarer`, `preacher`, `stranger`, `marquis`, `prince`, `burgher`, `lady`, `greek`, `knight`, `varangian`, `clerkA`, `clerkB` | supporting cast |
| `crowdA`, `crowdB`, `crowdC` | crowds (pilgrims, Venetians) |
| `bear`, `leopard`, `hound` | the band as the three beasts of 2.1 (the hound is also the dream that chases him in 8.1) |

They are generated on first use, so a replacement sheet is loaded the same way (`sheet:` in the
manifest). Preview any of them with `?debug=sprites&char=<key>`. Dialogue portraits use frame
`idle_S_0`; the Professor's portrait is the single sprite `professorFace`.

Non-animal figures are single sprites: `legs` (the Professor under the desk), `fortune`,
`falcon`, `stag`.

The **anchor** is the ground contact point, centered between the paws (the shadow is drawn there,
the sprite is depth-sorted by it). Frame counts and fps live in the manifest — change them freely,
the game reads them from there.

Animation meaning: `idle` standing/breathing · `walk` · `run` · `sniff` (head low, idle variant) ·
`pee` (hind leg lifted) · `poop` (squatting) · `eat` (head down, mouth) · `bark` (mouth open,
head forward, played once) · `fetch` (running with the ball in the mouth) · `hurt` (flinch) ·
`tired` (panting, standing still while the energy recovers).

### Sheet layout

One PNG per character, a grid of `frameW × frameH` cells:

- **rows**: for each animation *in the order listed in the manifest*, 8 rows (one per direction,
  order `N NE E SE S SW W NW`);
- **columns**: frame 0, 1, 2, … (unused cells may stay empty).

So Zampanò has 10 animations × 8 directions = 80 rows, 4 columns, i.e. a 160 × 3200 px image
(his 11th animation, `tired`, is a sheet of its own: see `animSheets`).

Frame files rendered individually (e.g. from Blender) can be assembled with ImageMagick:

```bash
# frames named <anim>_<dir>_<frame>.png, e.g. walk_NE_2.png
for a in idle walk run sniff pee poop eat bark fetch hurt; do
  for d in N NE E SE S SW W NW; do
    montage ${a}_${d}_*.png -tile x1 -geometry 40x40+0+0 -background none row_${a}_${d}.png
  done
done
montage $(for a in idle walk run sniff pee poop eat bark fetch hurt; do for d in N NE E SE S SW W NW; do echo row_${a}_${d}.png; done; done) \
  -tile 1x -geometry +0+0 -gravity West -background none zampano.png
```

Then in `manifest.ts`: `zampano: { …, sheet: 'sprites/zampano.png' }`.

## Single sprites

`SPRITES` in the manifest: props (`tree`, `forestTree`, `bush`, `pole`, `fountain`, `exitFlag`),
items (`treat`, `ball`, `poop`, `coin`), shadows, popups (`rainbow`, `thought`), particles and HUD
icons. Story props: `column`, `desk`, `shelf`, `house`, `tent`, `galley`, `rock`, `statue`, `crate`,
`palm`, `altar`, `stall`, `throne`, `vine`, `gate`, `wicket` (a garden gate, map letter `J`), `bones`,
`table`; story items/FX: `shard`, `relic`, `bowl` (the water bowl on the lawn), `tear`, `flame`,
`sparkle`, `professorFace`. Story props are drawn per theme palette
(like ground tiles), so a file replacement should be neutral or one per theme. Each has `w × h`,
an anchor and a number of `variants`. To replace one, add
`file: 'sprites/tree.png'` — a horizontal strip with the variants side by side.

Texture names: `${key}_${variant}` (e.g. `tree_2`); characters: `${key}_${anim}_${dir}_${frame}`
(e.g. `zampano_walk_NE_2`).

## Ground tiles

Tiles are 32 × 16 diamonds (2:1), anchored at the top vertex. They are generated per zone from the
level `palette` (`grass_0..3`, `tallGrass_0..2` (32 × 21, blades poke 5 px above), `path_<mask>_<v>`
(16 edge masks: bit 1 = top-right neighbor is not path, 2 = bottom-right, 4 = bottom-left,
8 = top-left), `water_0..1`, `forest_0..2`, pollution overlay `dirt_0..3`, `fresh_0`, `exitRing_0`).
Story grounds add `floor`, `stone`, `sand`, `snow`, `deep` (animated), `wall`, `dock`, `carpet`, colored
per theme (`story/maps.ts`). Replacing tiles follows the same principle (register a texture under the same name); a file-based
tile set is not wired yet because tiles are palette-driven per zone.

## Sounds and music

Recorded audio lives in `assets/` (uploaded to `main`) and is bundled with the build, so it works
offline. Each file is wired in `src/fx/audioFiles.ts`:

| File | Plays when |
|------|-----------|
| `music/intro-music.mp3` | every reading screen: title, options, level and scene cards, the walk's briefing and score, the Professor's asides, the ending |
| `music/greenzone-music.mp3` | only while playing in the Green Zone: the 1.0 walk and the scenes of levels 1 and 8 |
| `music/Level-2_SLY-Disco-Weapon.mp3` | while playing the scenes of level 2 (On the edge of dreams) |
| `music/Level-3_HM-Plenty-Good-Lovin.mp3` | while playing the scenes of level 3 (Venice) |
| `music/Level-4_CRI-Brother-Sister-(RM-Remix).mp3` | while playing the scenes of level 4 (The sea) |
| `sounds/dog-bark.mp3` | Zampanò barks (arcade and story) |
| `sounds/food-collect.mp3` | a treat is eaten (TREATS +1); story pickups |
| `sounds/poos.mp3` | a poop (POOPS +1) |
| `sounds/pees-drop.mp3` | a pee (PEES +1); a marking adds a short chime |
| `sounds/pees-collect.wav` | pee charges refilled at a puddle or fountain |
| `sounds/water.mp3` | stepping into a puddle |
| `sounds/cat-meow.mp3` + `sounds/cash-after-cat.mp3` | a cat caught: the meow, then the cash; the cash also plays for coins |
| `sounds/ball.mp3` | a magnet ball appears |
| `sounds/alarm-greenzone-under-attack.mp3` | GREEN ZONE UNDER ATTACK starts |
| `sounds/siren.mp3` | loops (quieter) while the attack lasts; the fire in Constantinople (7.4) |
| `sounds/laser-eyes.mp3` | Bagnaskiz knocks Zampanò |

Leading silence is skipped automatically, and per-file loudness trims are in `config.ts`
(`AUDIO.FILE_GAIN`; music: `AUDIO.MUSIC_FILE_GAIN`, which brings the louder level tracks down to
the Green Zone track's level). To replace a sound, overwrite the file with the same name (mp3 or
wav). A level's music is its chapter's `music` (`src/campaign/chapters/chN.ts`). All the
music in the game is re-encoded (MP3 VBR, about 130 kbit/s: `ffmpeg -i <original> -codec:a
libmp3lame -q:a 5 <file>`) to keep the app small; the files as uploaded are kept in
`assets/music/originals/` (not bundled). A new track: put the original there and the re-encoded
copy in `assets/music/`. Levels 5 to 7
keep the synthesized medieval loop, and interface sounds (clicks, glitch
transitions, stars, jingles, game over) stay synthesized in `src/fx/sounds.ts`.

## Title page art

`assets/starting-page-images/` holds the pictures of the title page and the level ends:

- `Zampano-Samemala-3.gif`: Zampanò over the title's buttons, **animated** (99 frames, about
  4 s, 1024 × 1536, transparent; `src/ui/titleAnim.ts`). The app bundles `app/Zampano-Samemala-3.webp`,
  the same animation as a lossless animated WebP (identical frames and delays, 2.3 MB instead of
  6.6 MB; made with Pillow: `save(..., save_all=True, lossless=True, method=6, duration=<the GIF's
  delays>, loop=0)`). Replacing the GIF means redoing that copy. The browser decodes its frames one after
  another (WebCodecs `ImageDecoder`: Chromium and the Android WebView) and each frame plays as
  soon as it is ready, so the dog moves about a second after the title appears. Every frame is
  cropped to the same box (the first frame's dog plus `TITLE.DOG_CROP_MARGIN`) and scaled to the
  title's size. Without `ImageDecoder` (Safari, the dev server opened over plain http on the
  LAN) the first frame stays still. The earlier `Zampano-Samemala-1.gif` and `-2.gif` are kept,
  unused.
- `Retro-16-Bit Ivory Dog Sprite-3-4-front.png`: the previous portrait, kept as the old version:
  OPTIONS > ART: OLD shows it (still), from a 384-px copy (`app/...-384.png`, 0.2 MB instead of
  1.4 MB; it is shown at most about 124 px wide).
- `Youve_Been_Supervillained_Logo.png`: not on the title page; it snaps in at the end of every
  level, before the final info (`src/scenes/supervillainedScene.ts`).

They are scaled down in the browser to the exact size each screen needs, so replacing a file
(same name, transparent background) is all it takes; another GIF needs only its name changed in
`titleAnim.ts`. Tuning in `config.ts`: `TITLE` (portrait, glitch, old-film look) and
`SUPERVILLAINED` (size, snap, flash, shake, glow, sprite burst, hold time).

## App icon and logo

`branding/` holds the logo: `logo-source.webp` (the original), `logo.png` (the shape on pure white,
cropped to its edges) and `app-icon.png` (1024 × 1024 square with the whole shape, for stores and
documents). `npm run android:icons` builds everything else from `logo.png`: the Android launcher
icons (square, round, adaptive foreground inside the 66 dp safe zone, white adaptive background),
the white splash screens with the logo in the middle, and the web icons in `public/` (favicons,
Apple touch icon, 192/512). To change the logo, replace `branding/logo.png` (8-bit RGB or RGBA PNG,
the shape on white, cropped) and run the command again.
