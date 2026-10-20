# Security review: Tanks of Freedom II (2026-10-20)

Source: https://github.com/P1X-in/tanks-of-freedom-ii, commit dbe629e (2025-10-02), MIT license for code and art; music and sounds by QmYaan (CC BY-SA 4.0) and reduz (CC BY 4.0), see `LICENSE.md` and `CREDITS.md`.
Shallow-cloned into an isolated folder outside the project; nothing was opened or run in Godot before this review.

What was checked, and the result:

- **All tracked files listed by type:** 292 GDScript files (24,069 lines), 661 scenes, OBJ/MTL models with their MagicaVoxel sources, PNG textures, WAV/OGG audio, JSON maps and campaigns, translations, a TLS certificate for the game's own server, three Python helper scripts (`tools/`, for the developers' translation work) and a 900 MB `docs/` folder (devlog videos and pictures). No native libraries, GDExtension, C#, addons or plugins. No Git LFS.
- **Left out:** `docs/`, `tools/`, the editor source files (`.vox`, `.ase`, `.aseprite`, `.xcf`) and icons for desktop builds. The 24 MB HDR sky was replaced by a 2048x1024 JPG made from it.
- **Every script scanned for risky APIs**, and every hit read in full:
  - **Online services (switched off):** `TofOnline` talks to the game's server (`api.tof.p1x.in`) over HTTPS to browse and share maps and register a player id; `TofRelay` joins online matches over a WebSocket relay. In Lab Arcade the connector returns "unavailable" without opening any connection, and the relay can't create or join games.
  - **Network play (switched off):** `TofMultiplayer` hosts and joins LAN games with ENet, and `TofAutodiscovery` broadcasts and listens for games on the local network over UDP. Hosting, joining, scanning and the discovery server now return straight away. The Online and Multiplayer buttons are hidden in the menu.
  - **Files:** settings, campaign progress, saves and your own maps are plain JSON (read with the JSON parser, which can't create objects), now in `user://tanks_of_freedom/`. Custom campaigns are read as JSON from a folder next to the program (desktop only).
  - **Other OS calls:** checking for a Steam Deck (the OS name), the program's folder for custom campaigns, and debug-build checks. Nothing runs programs or opens links.
- **Global helpers (autoloads) read in full:** map list, gamepad helper, audio library, mouse layer, scene switcher, match setup, settings, campaign progress, saves and the network services above. The audio library preloaded all music when the app starts; it now loads it when the game starts.
- **Scenes and resources:** no embedded scripts; all paths inside the project (two sky textures pointed into the original project's import cache and now point to the new sky picture).

Verdict: nothing malicious found; all internet and network access is switched off inside the arcade.

Other changes for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/tanks_of_freedom/`; classes and global helpers renamed with a `Tof` prefix and its own input actions with `tof_`; the 1280x800 screen, physics at 144 steps a second and its texts set while it runs (`lab_arcade.gd`), and its helpers asleep outside it; two-finger pinch zoom (`lab_arcade_pinch.gd`) and an X button to cancel a selection; depth-of-field blur and screen-space lighting switched off (they need the Vulkan renderer); Quit goes back to the arcade.
