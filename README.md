# Laugh-Labs

Silly little games, all in one Android app: **Lab Arcade**.

**Install on your phone:** [LabArcade.apk](https://github.com/Hephaestus985/Laugh-Labs/raw/downloads/apks/LabArcade.apk). Open it and allow installs from your browser if Android asks. Installing a newer version updates the app and keeps your high scores.

Games are downloaded inside the app the first time you play them (from the [downloads branch](https://github.com/Hephaestus985/Laugh-Labs/tree/downloads), checked against a fingerprint built into the app), then work offline. An app update only downloads a game again if that game changed.

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
| 2048 | Swipe to slide numbered tiles; equal tiles merge. |
| Sudoku | Generated puzzles with exactly one solution, notes and hints. |
| Minesweeper | Tap to open, long-press to flag; the first tap is always safe. |
| Solitaire | Klondike patience: tap or drag cards, draw 3 on Hard. |
| Nonogram | Fill the grid from number clues to reveal a picture. |
| Lights Out | Tap a light to flip it and its neighbours; turn them all off. |
| Sliding Puzzle | Slide the tiles back into order (3x3 to 5x5). |
| Mahjong Solitaire | Match pairs of free tiles; every deal can be cleared. |
| Sokoban | Push crates onto targets; generated levels that can always be solved. |
| Flow | Connect same-coloured dots with pipes that fill the board. |
| Block Stacker | Falling blocks: slide, turn, clear rows. |
| Connect Four | Four in a row against the computer, three strengths. |

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
`arcade/tools/tests/run_tests.tscn` checks the menu and every version of every game (713 checks): the scene loads with its code, the title screen draws, a tap starts the game, 20 seconds of random play without a single error, the screen still draws, high scores save, the menu's difficulty reaches the game, and there's a way back to the menu. The Last Knight also gets all 5 levels, the 3 boss phases, the ending, game over, Continue and New game.

Run them without a window or sound (`menu` or `external` for a quick run, `VISUAL=1` to also check drawing in an off-screen window):
```bash
arcade/tools/test.sh
```
`arcade/tools/build_apk.sh` builds the game packs that changed (`arcade/tools/packs.py`, unchanged packs keep their exact bytes), the launcher-only APK and runs the same tests headless (no windows) on an exported build; `VISUAL=1` also checks that screens draw (the way the phone app is built); it stops with an error if any test fails. Your own high scores and saves are backed up and restored around the tests. Latest results: `arcade/tools/tests/last_report.txt`.

## Repository layout
- `main` (this branch): source code, version history and tags. No build files, so it stays small as games are added.
- `downloads`: the APK and one download pack per game version. It is a single commit that is rewritten on every release, so old builds don't pile up.
- `arcade/games/<id>/`: a game made for the arcade: `arcade_info.json` (name, description, versions...), `arcade_tests.gd` (its phone tests, for board games) and one folder per version (`v1/`, `v2/`...).
- `arcade/external/<id>/`: a game by others, the same way, plus its license and `SECURITY_REVIEW.md`.
- `arcade/catalog.json`: all `arcade_info.json` files joined (made by `arcade/tools/catalog.py`, which also checks them). The app reads this.

## Adding a game
1. Make `arcade/games/<id>/v1/` with `game.tscn` (extend `common/arcade_game.gd`, or `common/puzzle_game.gd` for board and puzzle games: saves, Continue, difficulty, portrait and buttons come for free).
2. Copy an `arcade_info.json` from another game, change it, and give it the next `order` number.
3. For a puzzle game, add `arcade_tests.gd` with `play()` (touch play) and `win()` (see `games/sudoku/`).
4. `arcade/tools/test.sh only=<id>` to try it (no window, no sound), then `arcade/tools/build_apk.sh` and `arcade/tools/publish.sh "<message>" <id>-v1`.

A game by others: clone it somewhere isolated, review it (`SECURITY_REVIEW.md`), import with `python3 -I arcade/tools/import_external.py <checkout> <id>`, merge its project settings by hand and add `arcade_info.json`.

The build only rebuilds the downloads of games that changed and only tests what changed since the last release (plus the launcher and a few other games as a spot check); `FULL=1 arcade/tools/build_apk.sh` tests everything.

