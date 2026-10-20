# Security review: Duel Defense (2026-10-20)

Source: https://github.com/duel-defense/duel-defense, commit b4e5922 (2026-03-16), MIT license (code). Art, music and add-ons under their own licenses, listed in `Assets/AssetLicenses/` (CC0, CC BY 4.0, MIT and free-to-use asset packs).
Shallow-cloned into an isolated folder outside the project; nothing was opened or run in Godot before this review.

What was checked, and the result:

- **All tracked files listed by type:** 71 GDScript files (7,155 lines, game and 8 add-ons), 38 scenes, PNG art, MP3/OGG audio, JSON configs, fonts, shaders, license texts, CI workflows and export presets. No native libraries, GDExtension, C# or shell scripts. No Git LFS. CI workflows, export presets and `out/` were not copied.
- **Every script scanned for risky APIs**, and every hit read in full:
  - **Mod system (removed):** `ModManager.gd` asked mod.io for a list of mods over the internet (with an API key in the code), downloaded zip files, unpacked them into `user://mods/` and loaded every `.pck` found there with `load_resource_pack`. A `.pck` can contain any code, so this is a way to run code from outside the arcade. The mod manager, the Mods screen and its menu button are removed.
  - **Start-up commands (removed):** at start the game read `.cfg` files from the user folder (`autoexec.cfg`) and ran every line as a developer-console command. Only the game's own built-in config files are read now; nothing from the user folder is run.
  - **Developer console add-on:** a backtick opens a console with the game's own debug commands (load a map, spawn things, change settings). It can't run code, only those commands. Kept for PC, and asleep outside this game so it can't open in the launcher or other games.
  - **Links:** "About" and the mod items opened web pages with `OS.shell_open`; the mod items are gone, the About links are fixed addresses.
  - **Logger add-on:** reads its own settings from environment variables and can write a log file; logging to file is off.
  - **Debug overlay add-on:** shows frame times and hardware names on screen (F3); never sent anywhere. Asleep outside this game.
- **Editor plugins:** the add-ons' editor-only plugin scripts (`plugin.gd`, `plugin.cfg`, an icon finder) were not copied; they only run inside the Godot editor.
- **Scenes and resources:** no embedded scripts; all paths inside the project. Paths inside the JSON configs were moved too.
- **Saving:** progress and settings are plain JSON in `user://duel_defense/configs/` (read with the JSON parser, which can't create objects).

Verdict: two ways to run outside code (online mods, start-up command files) removed; nothing malicious found.

Other changes for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/duel_defense/`; classes and global helpers renamed with a `Dd` prefix (its `GameData` clashed with the arcade's); its own input actions prefixed `dd_`; a local `MusicPlayer` name renamed (another game's global class); the 1920x1080 screen, theme, background colour and sound channels set while it runs (`lab_arcade.gd`); the camera and HUD use the visible screen size (the arcade scales the screen); turret placement and turret taps use map coordinates and work by touch (the game's own mouse-button bindings are checked directly); a missing save folder no longer breaks start-up; physical-key icon lookup skipped where phones can't do it; Quit goes back to the arcade; the music was re-encoded at 80 kbps to keep the download small.
