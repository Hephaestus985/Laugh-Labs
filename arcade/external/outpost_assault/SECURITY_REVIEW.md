# Security review: Outpost Assault (2026-10-19)

Source: https://github.com/quiver-dev/tower-defense-godot4, commit 1cbd622 (2026-08-21), MIT code / CC BY 4.0 art.
Downloaded into an isolated folder; nothing was run or opened in Godot until the review below was done.

What was checked, and the result:

- **All 1,073 files listed by type.** Only scripts (.gd, 41), scenes/resources (.tscn/.tres), import settings, 475 PNG images, 1 JPG, 1 TTF font, licenses and a README. No native libraries (.so/.dll/.dylib), no GDExtension, no C#, no shell/Python scripts, no shaders, no addons, no export presets, no hidden or untracked files.
- **Images came from Git LFS:** each of the 475 PNGs was downloaded separately and its SHA-256 checked against the hash in the repository. All 475 matched. All images are genuine PNG/JPEG files with nothing appended after the image data.
- **Every line of all 41 scripts (1,558 lines) read by hand.** They only do game logic: enemies, turrets, projectiles, waves, HUD, menus, camera. Scan for risky APIs found none: no OS.execute / shell_open, no network (HTTP, sockets, WebSocket, multiplayer), no file or directory access, no JavaScript/Java bridges, no dynamic code (GDScript.new, Expression, str_to_var), no ProjectSettings changes, no threads. The only `OS.` use is `OS.has_feature("editor")`.
- **Two `@tool` scripts** (run inside the Godot editor): `shooter.gd` and `spawner.gd`. They only add or remove their own child nodes when an inspector value changes. Safe.
- **Scenes and resources:** no embedded scripts, every resource path points inside the project, resource types are ordinary (textures, sprite frames, shapes, navigation, themes, animations, a tileset, a font).
- **Project settings:** two autoloads (Global, Scenes: plain game state), one input action (middle mouse), physics layer names. No editor plugins enabled.
- **Links in the files:** only documentation, license and the author's own site in comments and the README.

Verdict: no malicious or risky code found.

Changes made for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/outpost_assault/`, the Quit button goes back to the arcade, Android back button support, one-finger drag and pinch zoom on touch screens.

Note: the font (Akashi by Ed Merritt) says "All Rights Reserved" in its metadata and isn't covered by the repo's asset license. It's fine for private use; replace it before publishing the app anywhere.
