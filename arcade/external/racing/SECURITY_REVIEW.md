# Security review: Kenney Racing (2026-10-19)

Source: https://github.com/KenneyNL/Starter-Kit-Racing, commit 2f2e5f2 (2026-08-21), MIT license.
Downloaded into an isolated folder; nothing was run or opened in Godot until the review below was done.

What was checked, and the result:

- **All 67 tracked files listed by type.** Scripts (.gd, 3), scenes/resources, import settings, 13 GLB models, PNG textures, OGG sounds, license and README, plus Adobe Animate and FBX source files (not used by the game and left out). No native libraries, GDExtension, C#, shell scripts, addons or export presets.
- **Models and images came from Git LFS:** each file was downloaded separately and its SHA-256 checked against the hash in the repository. All matched.
- **Every line of all 3 scripts (255 lines) read by hand:** vehicle physics, a motorcycle variant and the follow camera. No risky APIs: no OS calls, network, file access, JavaScript bridge or dynamic code.
- **Scenes and resources:** no embedded scripts, all paths inside the project.
- **Project settings:** no autoloads or plugins, ordinary input actions, Jolt physics. The editor's movie-writer path points to the author's own PC and is not used.

Verdict: no malicious or risky code found.

Changes made for Lab Arcade (marked `[Lab Arcade]` in the code): resource paths moved to `res://external/racing/`, on-screen steering with GAS and BRAKE buttons, back button, and screen-space indirect light (SSIL) turned off because the phone renderer doesn't support it.
