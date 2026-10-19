# Laugh-Labs

Silly little games, all in one Android app: **Lab Arcade**.

**Install on your phone:** [LabArcade.apk](https://github.com/Hephaestus985/Laugh-Labs/raw/main/apks/LabArcade.apk). Open it and allow installs from your browser if Android asks. Installing a newer version updates the app and keeps your high scores.

## Games
| Game | What it is |
|---|---|
| Sock Escape | A sock flees the washing machine. Jump ducks, soap and cats, duck under bubbles. |
| Waveguide Snake | You're a light pulse. Eat photons, grow, dodge scattering defects. |
| Cleanroom Parkour | Late for your cleanroom slot. Jump pits, deadlines and falling reviews. |
| Escape the Cavity | A photon stuck in a laser. Hop the mirrors, grab carriers, survive 6 levels. |
| Bend It Like Einstein | Hold to summon a pocket black hole and bend photons into the fiber. |
| Orbit Courier | Slingshot between moving planets to deliver party invitations. |
| Never Ask for Directions | Steer a Viking longship past fjords, icebergs and a kraken. |
| Lighthouse Keeper | Swing a very expensive laser so ships see the rocks. Mind the serpent. |
| Escape Velocity | Bounce from an Enschede rooftop to the Moon. Stomp geese, eat stroopwafels. |
| The Last Knight | Chase the crossbow inventor through five eras. Parry, stomp, honk. |

Each game card shows run length, best score, times played and effort, with **Play / Continue**, **Difficulty** and **Info** (story, controls, facts, every older version). **Settings** has difficulty for all games, sorting, menu orientation (the menu works in portrait too) and resetting scores. See [CHANGELOG.md](CHANGELOG.md).

## More games
Open-source games by others (the "More games" filter in the Library), each security-reviewed before it was added:
- **Outpost Assault**: tower defense by [Quiver](https://quiver.dev) (MIT code, CC BY 4.0 art)
- **Open RPG**: a short pixel-art RPG by [GDQuest](https://github.com/gdquest-demos/godot-open-rpg) with Dialogic 2 (MIT; CC0 / CC-BY assets, see its CREDITS.md)
- **Tactical RPG**: a turn-based 3D tactics battle by [ramaureirac and mbusson](https://github.com/ramaureirac/godot-tactical-rpg) (MIT)
- **3D Platformer** and **Kenney Racing**: starter kits by [Kenney](https://kenney.nl) (MIT)

They live in `arcade/external/<game>/` with their licenses and a `SECURITY_REVIEW.md`. To add one: clone it somewhere isolated, review it, then `python3 -I arcade/tools/import_external.py <checkout> <id>` and merge its project settings by hand.

## For developers
`arcade/` is one Godot 4 project. Each game version lives in `arcade/games/<game>/v<N>/` and is listed in `arcade/games.gd`. Shared input, touch controls and high scores are in `arcade/common/arcade_game.gd`. Open `arcade/` in Godot and press F5 to play on a PC. Build and test the APK with `arcade/tools/build_apk.sh`.

## Phone first
Every game must be fully playable with touch only: no keyboard, no mouse wheel, no hover, no right-click. Lab games use the on-screen stick and buttons from `arcade/common/arcade_game.gd`; games by others get on-screen buttons and touch fixes (marked `[Lab Arcade]`). The tests check this by playing with simulated phone touches on a scaled, phone-sized screen.

## Tests
`arcade/tools/tests/run_tests.tscn` checks the menu and every version of every game (255 checks): the scene loads with its code, the title screen draws, a tap starts the game, 20 seconds of random play without a single error, the screen still draws, high scores save, the menu's difficulty reaches the game, and there's a way back to the menu. The Last Knight also gets all 5 levels, the 3 boss phases, the ending, game over, Continue and New game.

Run them without a window or sound (`menu` or `external` for a quick run, `VISUAL=1` to also check drawing in an off-screen window):
```bash
arcade/tools/test.sh
```
`arcade/tools/build_apk.sh` builds the APK and runs the same tests headless (no windows) on an exported build; `VISUAL=1` also checks that screens draw (the way the phone app is built); it stops with an error if any test fails. Your own high scores and saves are backed up and restored around the tests. Latest results: `arcade/tools/tests/last_report.txt`.

