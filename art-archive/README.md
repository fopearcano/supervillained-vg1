# Art archive

Character art the game no longer ships: it only uses the latest delivery (see `ASSETS.md`).
Kept here for reference, outside `public/`, so it is not bundled.

- `sprites-old/` — the original procedural art (drawn by `src/assets/placeholders/`), frozen as
  sheets in the game's layout before sprite updates 1 and 2 replaced it; `runIcon.png` is the old
  RUN chevrons.
- `sprites-update-1/` — sprite update 1's Zampanò (new run rows over the old art, and his first
  tired pose), replaced by sprite update 2; and update 1's Sbrimbrulòn (`sbrimbrulon.png`, 5
  animations), replaced by the Sbrimbrulòn normal animations.
- `sprites-update-2/` — sprite update 2's plain Zampanò and knight (`zampano.png`,
  `zampanoKnight.png`: 10 animations of 4 frames, and their `-tired.png`), replaced by the Zampanò
  animation integration and the armoured Zampanò animations (8-frame cycles and the seated idle).
  The rag cross (`zampanoCross`) is still update 2's and still in `public/sprites/`.
- `directions-before-8way/` — the four-view sheets of plain and armoured Zampanò and Sbrimbrulòn
  (`zampano`, `zampanoKnight`, `sbrimbrulon`, `sbrimbrulonKnight`, each with its `-tired.png`),
  whose NE/SE rows repeated E and NW/SW repeated W; replaced by the 8-directions update, which
  keeps their N, E, S and W frames pixel for pixel.
- `sprites-update-1-cast/` — update 1's Bagnaskiz (`bagnaskiz.png`, 5 animations, four views),
  Jack, Watson and Confusione, replaced by the Bagnaskiz 8-directions delivery and the pixel cast.
