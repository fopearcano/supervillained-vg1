# SUPERVILLAINED

A 2D isometric arcade game about **Zampanò**, a Maltese dog on a walk in the park, with a retro
video-game HUD. Browser + Android, written from scratch in TypeScript with PixiJS as a pure WebGL
renderer — no game engine.

> MAKE A WALK. COLLECT ENOUGH TREATS TO COMPENSATE THE HUNGER. PEE ENOUGH TO COMPENSATE THE POOPS
> AS TOO MANY POOPS CAN ENDANGER THE ENVIRONMENT OF THE ZONE YOU ARE PLAYING IN. CATS MEAN MONEY.
> DON'T GET DISTRACTED BY THE BALLS.

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
| Run    | push the joystick all the way | hold Shift |
| Pee    | PEE button | Space |
| Bark   | BARK button | J or X |
| Menu   | MENU (top right) | Esc |

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
Placeholder icons/splash screens are regenerated with `npm run android:icons`.

## Develop

```bash
npm run build      # typecheck + production build (dist/)
npm test           # unit tests (Vitest)
npm run screens    # Playwright screenshots into docs/screens/
```

See `CLAUDE.md` for the architecture, `ASSETS.md` to replace the placeholder art, and
`DECISIONS.md` for design decisions.

## License notes

Font: Press Start 2P by CodeMan38, SIL Open Font License 1.1 (`src/assets/fonts/OFL.txt`).
