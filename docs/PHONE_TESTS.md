# What to test on the phone

Run `npm run dev`, open the `Network` URL in Chrome on the phone (same Wi-Fi), portrait.
Or install the debug APK (see README → Android).

## M1 — Scaffold and movement
- Put your thumb anywhere on the left 60% of the screen: a joystick appears there; Zampanò walks
  in the exact on-screen direction you push (up = up the screen). Push all the way to run.
- Walk behind a tree: the tree turns semi-transparent. Camera follows with a slight lag and sway.
- No pinch-zoom, no page scroll, no long-press menu. Text and pixels look crisp (not blurry).

## M2 — Core loop and HUD
- Eat bones: TREATS goes up, the hunger bar refills; after ~4 bones a poop bubble appears, then a
  poop: try doing it on the path (big brown stain) vs. in a bush/tall grass (tiny stain).
- Press PEE on a stain: the area turns green again; next to a tree/pole/bush you get "MARKING!".
- Watch the stars drop in half steps when the park gets dirty; let the hunger run out (−1 life).
- Walk into a puddle or next to a fountain with missing pee charges: they refill.

## M3 — Scenes
- Title (glitch entrance) → tap → briefing → tap → play. MENU (top right): resume, restart,
  sound, volume, quit. Switch app / lock the screen during play: it comes back paused.
- Reach the EXIT flag (top of the map): stars pop one by one, bonuses, NEXT/RETRY; best score
  shows on the title. Starve twice → GAME OVER → RETRY.

## M4 — Threats and bonuses
- Cats run away around trees: run to catch them (+5 coins); BARK at a cat makes it freeze.
- A tennis ball pulls you in (pulsing rings): walk away and it wins, run away and you escape.
  Touching it = 2 s fetch, +5 s on the timer.
- Past halfway (or with a dirty park): "GREEN ZONE UNDER ATTACK", brown/glitchy world, Bagnaskiz
  the pug dirties the grass. Face him and BARK 3 times; then pee until the alarm stops.

## M5 — Polish
- Sound starts after the first tap: barks, pee, poop, treats, alarm, stars, game over, music.
  Check the SOUND and VOLUME items in the pause menu (saved across restarts).
- Feel: shake on poop/hits, squash on eating, dust when running, leaves in bushes, splashes.
- Balance: a full walk should take 2–3 minutes and you should need several treats.

## M6 — Android
- Install the APK: fullscreen (no status/navigation bar; swipe to peek), portrait locked, screen
  stays on, launcher icon is Zampanò's face.
- Hardware Back during play opens the pause menu, Back again resumes. Home → return: paused.
- Check 60 fps feel while running through the forest edges and during the attack effect.
