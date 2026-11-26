# Active prototype scope

The active product is a small editable Godot sandbox, not a feature-complete port.

## Included

- Zampano only, with eight-direction movement and normal animations.
- One 2:1 isometric Green Zone map, camera, collision, depth sorting and occlusion.
- Treat collection, hunger and digestion.
- Automatic poop after the digestion warning; poop pollutes the ground.
- Pee charges, regeneration/refill, marking, pollution cleaning and simple score.
- Compact HUD, keyboard input, portrait touch joystick, RUN, PEE and pause/restart.
- Green Zone music and the sound cues used by that loop.

## Explicitly excluded

- Campaign/chapter graph, story draft, dialogue and endings.
- Combat, companions, NPC behaviours, cats, balls, Bagnaskiz encounters and pollution waves.
- Secondary minigames, title shell, briefing, level exit, lives/game-over and replay/records.
- Alternate playable characters and armour variants.
- Save migration and production Android upgrade work.

Those ideas can be redesigned later from the playable Godot sandbox. They are not requirements
for this prototype and should not be reintroduced without a direct design decision.

## Working rule

Change the prototype directly in Godot. Prefer a visible playable improvement over additional
architecture, evidence documents or migration machinery. Keep the root PixiJS source untouched;
the earlier full-port attempt remains recoverable from Git history.
