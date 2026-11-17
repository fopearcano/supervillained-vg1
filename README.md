# SUPERVILLAINED

A 2D isometric game about **Zampanò**, a bullied Maltese dog, with a retro video-game HUD.
Browser + Android, written from scratch in TypeScript with PixiJS as a pure WebGL renderer — no
game engine.

> MAKE A WALK. COLLECT ENOUGH TREATS TO COMPENSATE THE HUNGER. PEE ENOUGH TO COMPENSATE THE POOPS
> AS TOO MANY POOPS CAN ENDANGER THE ENVIRONMENT OF THE ZONE YOU ARE PLAYING IN. CATS MEAN MONEY.
> DON'T GET DISTRACTED BY THE BALLS.

One game, one story (title menu: NEW GAME, CONTINUE, OPTIONS, GLOSSARY, QUIT). It starts in the Green
Zone: the walk in the park above (1.0, the level from `SPEC.md`) and the bullying of the lawn.
Then Zampanò falls asleep under the Professor's desk and dreams the Fourth Crusade, and at the end
he wakes up *supervillained* (with character), not to be bullied again in the Green Zone.

8 levels (The Greenzone, On the edge of dreams, Venice, The sea, Zara, The long winter,
Constantinople, Back to the Greenzone) from the design documents *Supervillained — VG1
implemented* and the level design revision *Levels implementation 2*: the Green Zone walk, then
dialogue with choices, dream walks (following someone, carrying things, acting in a lull,
stealth, a nerve gauge beside Pierre, thirst, smoke and fire, scrambled controls), mini-games,
hard cuts into other crusades, the Meraviglia book, and two endings decided by whether he calls
the oath himself at the sack of Constantinople. Progress is saved after every scene; OPTIONS has
sound, volume, text speed, the character art (NEW: the delivered sprite sheets; OLD: the art they
replaced, kept), level replays and the book.

## Run it

```bash
npm install
npm run dev
```

Open the printed `Local` URL on the computer, or the `Network` URL on a phone on the same Wi-Fi.

### Controls

| Action | Touch | Keyboard |
|--------|-------|----------|
| Move   | virtual joystick (appears under your thumb, left side) | WASD / arrow keys |
| Run    | hold RUN (only while the energy ring around it has energy) | hold Shift or K |
| Pee    | PEE button | Space |
| Bark   | BARK button | J or X |
| Menu   | MENU (top right) | Esc |
| Story: next line / choose | tap the line / tap an option | Space or Enter / arrows + Space |

In the story the right button changes name with the scene (LOOK, SNIFF, BARK, PLACE…). The
pause menu sets the text speed; the story menu opens each level's scene list, where any finished
scene can be replayed without changing your campaign.

## Play on a phone (browser)

With `npm run dev` running, open the `Network` URL (e.g. `http://192.168.1.20:5173`) in Chrome on a
phone connected to the same Wi-Fi. Hold the phone in portrait. Sound starts after the first tap.

## Android (debug APK)

The Android app is a [Capacitor](https://capacitorjs.com) shell around the same web build: portrait
locked, fullscreen (immersive), screen kept on, hardware **Back** opens/closes the pause menu.

### Prerequisites (once)

- **Node 22+** and `npm install` done.
- **JDK 21** (`java -version`). Android Studio ships one (`File > Settings > Build Tools > Gradle >
  Gradle JDK`), or install e.g. Temurin 21.
- **Android SDK** with *Android SDK Platform 36* and *Build-Tools 36* — easiest via Android Studio
  (SDK Manager). Then either set `ANDROID_HOME` (e.g. `~/Android/Sdk`) or create
  `android/local.properties` containing `sdk.dir=/path/to/Android/Sdk`.

### Build

```bash
npm run android:apk
```

This builds the web app, copies it into the Android project (`cap sync`) and runs Gradle.
The APK is written to `android/app/build/outputs/apk/debug/app-debug.apk`.
(Windows: run `npm run android:sync`, then `cd android` and `gradlew.bat assembleDebug`.)

### Install

Over USB: enable *Developer options* → *USB debugging* on the phone, plug it in, then

```bash
npm run android:install
```

(`adb` comes with the SDK *platform-tools*.) Or copy `app-debug.apk` to the phone and open it
(allow "install unknown apps" for your file manager / browser when asked).

To open the native project in Android Studio (run on an emulator, debug): `npm run android:open`.
After changing game code, `npm run android:sync` is enough before rebuilding.
App icons, splash screens and web icons are generated from the logo (`branding/logo.png`) with
`npm run android:icons`.

## Develop

```bash
npm run build      # typecheck + production build (dist/)
npm test           # unit tests (Vitest)
npm run screens    # Playwright screenshots into docs/screens/
npm run smoke      # runs every story script start to finish (skipping steps)
npm run playtest   # the autopilot plays the whole campaign for real; report in docs/PLAYTEST.md
```

See `CLAUDE.md` for the architecture, `ASSETS.md` to replace the placeholder art (and how the
replaced art is kept as the old version), and
`DECISIONS.md` for design decisions.

## License notes

Font: Press Start 2P by CodeMan38, SIL Open Font License 1.1 (`src/assets/fonts/OFL.txt`).
