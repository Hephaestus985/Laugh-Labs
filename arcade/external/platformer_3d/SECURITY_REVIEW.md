# Security review: 3D Platformer (2026-10-19)

Source: https://github.com/KenneyNL/Starter-Kit-3D-Platformer, commit 3fa8a04 (2026-03-12), MIT license.
Downloaded into an isolated folder; nothing was run or opened in Godot until the review below was done.

What was checked, and the result:

- **All 100 tracked files listed by type.** Scripts (.gd, 9), scenes/resources, import settings, 15 GLB models, PNG textures, OGG sounds, one TTF font, license and README, plus one Adobe Animate source (`.fla`, not used by the game and left out). No native libraries, GDExtension, C#, shell scripts, addons or export presets.
- **Models and images came from Git LFS:** each file was downloaded separately and its SHA-256 checked against the hash in the repository. All matched.
- **Every line of all 9 scripts (369 lines) read by hand:** player movement, camera, coins, bricks, falling platforms, clouds, HUD and a small sound player. No risky APIs: no OS calls, network, file access, JavaScript bridge or dynamic code.
- **Scenes and resources:** no embedded scripts, all paths inside the project.
- **Project settings:** one autoload (`Audio`, the sound player), ordinary input actions, Jolt physics. The editor's movie-writer path points to the author's own PC and is not used.

Verdict: no malicious or risky code found.

Changes made for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/platformer_3d/`, on-screen stick, JUMP and camera buttons, back button. Physics interpolation was not copied (it warns with the arcade's 2D games).
