# Security review: Tactical RPG (2026-10-19)

Source: https://github.com/ramaureirac/godot-tactical-rpg, commit cfe785e (2026-02-21), MIT license.
Downloaded into an isolated folder; nothing was run or opened in Godot until the review below was done.

What was checked, and the result:

- **All 180 tracked files listed by type.** Only scripts (.gd, 57), scenes/resources (.tscn/.tres), import settings, 78 PNG images (67 of them in `docs/`, screenshots for the README), five editor leftovers (`*.tmp`), a license and a README. No native libraries, no GDExtension, no C#, no shell/Python scripts, no shaders, no export presets. All PNGs are genuine images with nothing appended.
- **Every line of all 57 scripts (4,136 lines) read by hand.** They only do game logic: the tile grid, pathfinding, turns, the enemy AI, camera, UI and debug printing. No OS.execute / shell_open, no network, no file or directory access, no JavaScript/Java bridges, no dynamic code, no ProjectSettings changes, no threads. The only global changes are the mouse cursor shape and mouse mode.
- **Seven scripts exist twice** under two names with the same class (e.g. `service.gd` and `t_cam_serv.gd`). The copies are identical apart from one type hint, so only the ones the scenes use were imported.
- **One scene embeds a script** (`input_capture.tscn`): a 15-line ray cast from the camera to the mouse. It's overridden by `input_capture.gd` and never runs. Harmless.
- **Project settings:** a `DebugMenu` autoload and four editor plugins point to an `addons/` folder that is not in the repository. Both were dropped. Input actions were copied with a `trpg_` prefix so they don't clash with other games.
- **No links** to any site in the code or scenes.

Verdict: no malicious or risky code found.

Changes made for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/tactical_rpg/`, actions renamed to `trpg_*`, `docs/` and the duplicate scripts left out, console debug logging off, on-screen camera arrows / turn / zoom buttons, no edge panning on touch screens, a Victory / Defeat ending (the original demo never ends), "Debug: End Turn" renamed "End turn", and a back button.
