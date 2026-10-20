# Security review: Deck Crawler (roguelike deckbuilder) (2026-10-20)

Source: https://github.com/guladam/deck_builder_tutorial, commit 91b408b (2024-10-16), MIT license.
Shallow-cloned into an isolated folder outside the project; nothing was opened or run in Godot before this review.

What was checked, and the result:

- **All tracked files listed by type:** 122 GDScript files (4,708 lines), 61 scenes, 48 resources, PNG art, OGG/MP3 sounds, one font, a shader, license and READMEs, and editor script templates. No native libraries, GDExtension, C#, shell or Python scripts, addons, plugins, export presets or binary resources. No Git LFS.
- **Every script scanned for risky APIs** (OS calls, network, JavaScript bridge, threads, dynamic code such as `Expression` / `GDScript.new` / `set_script` / `callv`, file and folder access, resource loading from variable paths): the only hits were the save system (below), one `Callable.call()` for event-room buttons (calls a function the game set itself) and `get_tree().quit()` on the Exit button.
- **The global helpers (autoloads) read in full:** an event bus (signals only), a screen shaker, two sound players and a random number generator. Nothing runs on start except creating the random generator.
- **Scenes and resources:** no embedded scripts; every path stays inside the project.
- **Saving:** the game saves a run as a Godot resource (`user://savegame.tres`) and loads it back. Loading a resource from a writable folder can run code if someone swaps the file. Lab Arcade now checks the save before loading it (`common/safe_resource.gd`): it must be a plain text resource whose scripts and files all come from the game's own folder, with no scripts written inside it, otherwise it is ignored like a missing save. A test plants a save with code in it and checks it is refused.

Verdict: no malicious code found. One risky pattern (loading a resource save) guarded.

Changes made for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/deck_builder/`; every class and global helper renamed with a `Dk` prefix (the game used common names like Card, Map, Enemy and Player that clash with other games); input actions prefixed `deck_`; the card state's type changed to a plain number (another game's global `State` class shadowed it); the game's 256x144 pixel-art screen, sharp pixels and its own theme set while it runs (`lab_arcade.gd`); drag the map by touch; map rooms are picked when the finger lifts without moving, so dragging the map never enters a room; a II pause button during runs; Exit goes back to the arcade instead of closing the app; wins count for achievements; editor script templates left out.
