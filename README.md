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

## For developers
`arcade/` is one Godot 4 project. Each game version lives in `arcade/games/<game>/v<N>/` and is listed in `arcade/games.gd`. Shared input, touch controls and high scores are in `arcade/common/arcade_game.gd`. Open `arcade/` in Godot and press F5 to play on a PC. Build and test the APK with `arcade/tools/build_apk.sh`.

## Tests
`arcade/tools/tests/run_tests.tscn` checks the menu and every version of every game (143 checks): the scene loads with its code, the title screen draws, a tap starts the game, 20 seconds of random play without a single error, the screen still draws, high scores save, the menu's difficulty reaches the game, and there's a way back to the menu. The Last Knight also gets all 5 levels, the 3 boss phases, the ending, game over, Continue and New game.

Run them in the editor:
```bash
flatpak run --filesystem=home org.godotengine.Godot --path arcade --fixed-fps 60 res://tools/tests/run_tests.tscn -- /tmp/report
```
`arcade/tools/build_apk.sh` builds the APK and runs the same tests on an exported build (the way the phone app is built); it stops with an error if any test fails. Your own high scores and saves are backed up and restored around the tests. Latest results: `arcade/tools/tests/last_report.txt`.

