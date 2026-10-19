# Security review: Open RPG (2026-10-19)

Source: https://github.com/gdquest-demos/godot-open-rpg, commit d59f2f7 (2026-10-13), MIT code, CC0 / CC-BY assets (see CREDITS.md).
Downloaded into an isolated folder; nothing was run or opened in Godot until the review below was done.

What was checked, and the result:

- **All 1,386 tracked files listed by type.** 975 belong to the Dialogic 2 add-on; the game itself has 78 scripts (.gd), scenes/resources, 16 Dialogic timelines (.dtl), 9 character files (.dch), images, music, sounds and two fonts. No native libraries, no GDExtension, no C#, no shell/Python scripts, no export presets.
- **Dialogic add-on compared file by file with the official Dialogic repository** (github.com/dialogic-godot/dialogic, commit 701b67b, 2026-08-30) by git object hash: 972 of 975 files are identical. The 3 that differ are harmless: a font license with different line endings, the dialogue input reacting on button release instead of press, and one commented-out "ending timeline" call.
- **Every line of the game's 78 scripts (5,344 lines) read by hand:** gameboard and pathfinding, gamepieces, the player controller, cutscenes, doors, chests, pickups, the turn-based combat, UI, music and screen fades. No OS / shell calls, no network, no JavaScript/Java bridges, no dynamic code, no ProjectSettings changes, no threads. The only file access is the inventory, saved as a resource in the app's own user folder.
- **All 16 dialogue timelines read:** only text, choices, variable changes and signals to the game (coins, wands, opening a path). No code calls.
- **Scenes and resources:** no embedded scripts. Animation "method" tracks only call `queue_free` and a popup's own bounce function. The 3 binary `.res` files were unpacked and are plain animation libraries. SVG icons contain no scripts.
- **Project settings:** 9 autoloads (camera, event buses, gameboard, registry, music, player, screen fade, Dialogic) and the Dialogic editor plugin (not needed at runtime, not copied).
- **Links:** only in the README, CREDITS and SVG metadata.

Verdict: no malicious or risky code found.

Changes made for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/open_rpg/`, input actions renamed to `orpg_*`, a start wrapper (`lab_arcade_main.gd`) that sets the game's 1920x1080 canvas, theme and pixel filter only while it runs, resets its state each visit and puts its autoloads to sleep in the launcher; tap a target in battle to attack it, a BACK button, a back-to-arcade button, and the inventory file renamed to `open_rpg_inventory.tres`. Broken timeline UIDs were removed from two scenes (they fall back to the file path).
