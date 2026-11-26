# SUPERVILLAINED dog prototype

This is the active, deliberately small Godot 4.7.2 project. It opens directly in one portrait
Green Zone sandbox. There is no title flow, campaign, story, combat, companion, minigame, level
exit, game-over, record or save migration in this branch.

## Play

- Move: WASD, arrow keys, or the virtual joystick.
- Run: Shift/K or RUN.
- Pee: Space or PEE. Pee cleans pollution and neutralises nearby poop.
- Pause: Escape/P or MENU. The pause menu can resume or restart.
- Eat treats by walking over them. Four treats fill digestion; after the warning Zampano poops.
- Water and fountains refill pee charges.

Open `project.godot` in Godot 4.7.2 and press F6/F5. The main scene is `main/main.tscn` and the
gameplay scene is `scenes/green_zone/green_zone_scene.tscn`.

## Focused checks

On Windows:

```powershell
& 'C:\Program Files\Godot472\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --import
& 'C:\Program Files\Godot472\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --script res://tests/test_runner.gd -- --suite all
& 'C:\Program Files\Godot472\Godot_v4.7.2-stable_win64_console.exe' --headless --path godot --quit-after 600
```

The test suite covers only the prototype contract: direct launch, movement/collision, the
treat-to-poop-to-pee loop, pause/resume and restart/reset.

## Recovery

The abandoned full-port work is not hidden or overwritten. It remains in Git history on remote
branch `origin/claude/gallant-keller-rbvtvy`. This branch is the clean place to continue game
design in Godot.
