# Assets: replacing the placeholders

Every sprite in the game is described in **`src/assets/manifest.ts`**. Game logic only asks for
textures *by name*; the loader (`src/assets/build.ts`) either loads your PNG or generates a
code-drawn placeholder. To drop in final art you edit the manifest — never game logic.

Put image files under `public/` (served as-is and copied into the Android build). Paths in the
manifest are relative to `public/`, e.g. `sheet: 'sprites/zampano.png'` → `public/sprites/zampano.png`.
If a file is missing or broken the placeholder is used and a warning is printed in the console.

Tip: open the game with `?debug=sprites&char=zampano` (or `bagnaskiz`, `cat`) to see every
animation and direction of a character playing side by side.

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
| `zampano`  | 40 × 40    | (20, 36)    | idle 2, walk 4, run 4, sniff 2, pee 2, poop 2, eat 2, bark 2, fetch 4, hurt 2 |
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
head forward, played once) · `fetch` (running with the ball in the mouth) · `hurt` (flinch).

### Sheet layout

One PNG per character, a grid of `frameW × frameH` cells:

- **rows**: for each animation *in the order listed in the manifest*, 8 rows (one per direction,
  order `N NE E SE S SW W NW`);
- **columns**: frame 0, 1, 2, … (unused cells may stay empty).

So Zampanò has 10 animations × 8 directions = 80 rows, 4 columns, i.e. a 160 × 3200 px image.

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
`palm`, `altar`, `stall`, `throne`, `vine`, `gate`, `bones`, `table`; story items/FX: `shard`,
`relic`, `tear`, `flame`, `sparkle`, `professorFace`. Story props are drawn per theme palette
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
| `music/intro-music.mp3` | title screen, briefing, story menu |
| `music/greenzone-music.mp3` | arcade gameplay; story levels 1 and 8 (Greenzone) |
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
(`AUDIO.FILE_GAIN`). To replace a sound, overwrite the file with the same name (mp3 or wav). The
dream levels (2 to 7) keep the synthesized medieval loop, and interface sounds (clicks, glitch
transitions, stars, jingles, game over) stay synthesized in `src/fx/sounds.ts`.

## App icon and logo

`branding/` holds the logo: `logo-source.webp` (the original), `logo.png` (the shape on pure white,
cropped to its edges) and `app-icon.png` (1024 × 1024 square with the whole shape, for stores and
documents). `npm run android:icons` builds everything else from `logo.png`: the Android launcher
icons (square, round, adaptive foreground inside the 66 dp safe zone, white adaptive background),
the white splash screens with the logo in the middle, and the web icons in `public/` (favicons,
Apple touch icon, 192/512). To change the logo, replace `branding/logo.png` (8-bit RGB or RGBA PNG,
the shape on white, cropped) and run the command again.
