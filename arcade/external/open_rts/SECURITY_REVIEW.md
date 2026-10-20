# Security review: Open RTS (2026-10-20)

Source: https://github.com/lampe-games/godot-open-rts, commit a628ad3 (2025-01-07), MIT license (code). 3D models from Kenney's Space Kit (CC0).
Shallow-cloned into an isolated folder outside the project; nothing was opened or run in Godot before this review.

What was checked, and the result:

- **All tracked files listed by type:** 118 GDScript files (7,297 lines), 84 scenes, 8 resources, 153 GLB models and one OBJ, PNG textures, OGG sounds (voice lines), 8 shaders, CSV translations, license files, a makefile, build/test folders and media. No native libraries, GDExtension, C#, addons or plugins. No Git LFS. The makefile and `build/` (export helpers for the author's own releases) and `tests/` and `media/` were not copied.
- **Every script scanned for risky APIs** (OS calls, network, JavaScript bridge, threads, dynamic code such as `Expression` / `GDScript.new` / `set_script` / `callv`, file and folder access, loading from variable paths): the only hits were reading the computer's name and processor count for a debug overlay (shown on screen only, never sent anywhere), `get_tree().quit()` on Quit, and the options file (below). The 8 `@tool` scripts only draw shapes in the editor.
- **The global helpers (autoloads) read in full:** feature flags, constants, signals, small utilities and the options holder. They preloaded the player scenes and voice lines when the app starts; Lab Arcade changed those to file paths loaded when a match needs them, so the arcade doesn't load this game at start.
- **Scenes and resources:** no embedded scripts; every path stays inside the project.
- **Options file:** the game saved and loaded its options as a Godot resource in `user://`. Loading a resource from a writable folder can run code if someone swaps the file, so it now goes through `common/safe_resource.gd` (plain resource from the game's own folder only, otherwise defaults are used), under its own name `open_rts_options.tres`.
- **Licenses:** the Lampe Games logo is "all rights reserved" and may not be used in derived projects, so it and the logo screen were left out. The Godot logo is CC-BY 4.0 (credited in `assets/logos/LOGO_LICENSES.md`).

Verdict: no malicious code found. One risky pattern (loading a resource from user://) guarded.

Changes made for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/open_rts/`; global helpers renamed with an `Rts` prefix and input actions with `rts_`; an inner `Player` class renamed (that name is another game's global helper); the 1920x1080 screen and the game's texts set while it runs (`source/lab_arcade.gd`); screen-size math uses the visible screen (the arcade scales the screen); phone controls (`source/match/lab_arcade_touch.gd`: tap to select and give orders, drag to move the camera, pinch to zoom, BOX / ALL / NONE / STOP / II buttons); a finger never triggers edge scrolling; the fog of war is drawn on the ground in the OpenGL renderer the arcade uses (the original full-screen version needs the Vulkan renderer); Quit goes back to the arcade.
