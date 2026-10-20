# Security review: City Builder (2026-10-20)

Source: https://github.com/KenneyNL/Starter-Kit-City-Builder, commit 4535092 (2026-03-12), MIT license.
Shallow-cloned into an isolated folder outside the project; nothing was opened or run in Godot before this review.

What was checked, and the result:

- **All tracked files listed by type:** 6 scripts, 1 scene, 16 resources, 15 GLB models, PNG sprites, OGG sounds, one font, a license and README, 4 leftover editor `.tmp` files, a binary sample map (`sample map/map.res`) and screenshots/vector source art. No native libraries, GDExtension, C#, shell or Python scripts, addons, plugins or export presets. No Git LFS.
- **Every line of all 6 scripts (305 lines) read by hand:** the builder (grid, building, saving), the camera, an audio pool and three small data classes. No OS calls, network, JavaScript bridge, dynamic code (`Expression`, `GDScript.new`, `set_script`) or file access beyond its own save.
- **Scenes and resources:** no embedded scripts, all paths inside the project. The 15 piece resources only point to a model and a price.
- **Binary sample map:** its strings show only the map's own data classes and cell entries. Left out anyway (not needed).
- **Saving:** the original saved and loaded the town as a Godot resource in `user://map.res`. Loading a Godot resource from a writable folder can run code if someone swaps the file, so Lab Arcade saves the town as plain JSON instead and reads only numbers from it.
- **Project settings:** one autoload (the audio pool), ordinary input actions, no plugins. The editor movie-writer path points to the author's PC and is not used.

Verdict: no malicious or risky code found. One risky pattern (resource-based save file) replaced.

Changes made for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/city_builder/`; class names prefixed with `City` so they can't clash with other games; the audio pool is a node in the scene instead of a global autoload; touch controls (tap to build or remove, drag / pinch / twist for the camera, buttons for piece, turn, remove and new city); keyboard controls read directly so no project-wide input actions are needed; JSON autosave with "Continue" on the start screen; the keyboard instruction picture removed; back button.
