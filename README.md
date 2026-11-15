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
