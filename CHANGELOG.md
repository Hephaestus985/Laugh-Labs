# Changelog

Every game keeps all its versions: each lives in `arcade/games/<game>/v<N>/` and stays playable from the game's **Versions** page in the app. Each game version also has a git tag `<game>-v<N>`, and each app build has a tag `arcade-<version>`.

## Lab Arcade 1.17 (2026-10-19)
- New games: **Flow** (generated pipe puzzles that can always be filled), **Block Stacker** (falling blocks; drag to slide, tap to turn, swipe down to drop; clear 20 / 40 / 60 rows to win) and **Connect Four** (against the computer, looking 1, 4 or 6 moves ahead)
- That completes the 12 simple games: 2048, Sudoku, Minesweeper, Solitaire, Nonogram, Lights Out, Sliding Puzzle, Mahjong Solitaire, Sokoban, Flow, Block Stacker and Connect Four

## Lab Arcade 1.16 (2026-10-19)
- New games: **Sliding Puzzle** (3x3 to 5x5), **Mahjong Solitaire** (deals that can always be cleared, hint, shuffle) and **Sokoban** (levels built backwards from the solution so they can always be solved; tap to walk, swipe to push)

## Lab Arcade 1.15 (2026-10-19)
- New games: **Solitaire** (Klondike; tap or drag cards, draw 3 on Hard, auto finish), **Nonogram** (hidden pictures from number clues; drag to paint, cross mode) and **Lights Out** (every board solvable, hints)

## Lab Arcade 1.14 (2026-10-19)
- New games: **2048**, **Sudoku** (generated puzzles with exactly one solution, notes, hints) and **Minesweeper** (tap to open, long-press to flag, safe first tap). All have Easy / Normal / Hard, save after every move with Continue / New game, and finger-sized buttons
- Shared base for calm board games (`arcade/common/puzzle_game.gd`); tests play each one by touch, check Continue, and solve a round
- `tools/test.sh only=<id>,<id>` tests just those games

## Lab Arcade 1.13 (2026-10-19)
- The Library keeps your search and filters after you play a game (and the next time you open the app)

## Lab Arcade 1.12 (2026-10-19)
- Kenney Racing: the stick now steers by screen direction (point where the truck should go), so left and right are no longer swapped when it drives towards you
- Fixed: "< MENU" in games by others could crash on the way back to the launcher
- Fixed: the small on-screen buttons that run an action did nothing (Tactical RPG turn and zoom, Open RPG BACK)
- Tests now tap "< MENU" in every game by others, check all four stick directions in Kenney Racing, and use the turn and BACK buttons

## Lab Arcade 1.11 (2026-10-19)
- Library filters are now drop-down menus: **Publisher** (Lab Arcade, games by others, or a studio), **Length** (short, medium, long, no end) and **Genre** (action, arcade, platformer, puzzle, racing, RPG, runner, strategy), plus "Not played yet"
- Every game card shows its genre; the Info page lists genre and publisher. Search also finds publishers and genres

## Lab Arcade 1.10 (2026-10-19)
- Four more games by others, each security-reviewed first (see `arcade/external/<game>/SECURITY_REVIEW.md`) and made fully playable on a phone:
  - **Open RPG** (GDQuest, MIT): a short pixel-art RPG with a town, a puzzle and turn-based battles. Tap to walk, talk and continue; tap an action, then tap the enemy. BACK undoes a choice
  - **Tactical RPG** (ramaureirac and mbusson, MIT): a turn-based battle on a 3D board. Tap units and tiles; arrow buttons move the camera, << >> turn it, + and - zoom. Added a Victory / Defeat ending (the original never ended)
  - **3D Platformer** (Kenney, MIT): on-screen stick, JUMP and camera buttons
  - **Kenney Racing** (Kenney, MIT): on-screen steering with GAS and BRAKE
- Shared on-screen controls for games by others (`arcade/common/touch_overlay.gd`): stick, buttons, arrow pad, and a "< MENU" button; the Android back button returns to the launcher
- Silent, windowless test mode: `arcade/tools/test.sh` (`menu` or `external` for quick runs, `VISUAL=1` for an off-screen window)
- Tests now also play each new game with simulated taps (a battle turn, a conversation, walking, steering, jumping)

## Lab Arcade 1.9 (2026-10-19)
- Outpost Assault playable on phones: zoom and pause buttons, finger-sized turret buttons, a drag never opens the build menu

## Lab Arcade 1.8 (2026-10-19)
- Fixed: taps on phones opened nothing or the wrong game
- Home tab with your picked games; Library tab with search and filters ("More games" is a filter)

## Lab Arcade 1.7 (2026-10-19)
- New "More games" tab for open-source games by others, starting with Outpost Assault (tower defense by Quiver, MIT / CC BY 4.0). Security-reviewed first: see arcade/external/outpost_assault/SECURITY_REVIEW.md. Added touch drag and pinch zoom, and a way back to the arcade
- Tests now run headless (no game windows popping up), 157 checks; `VISUAL=1 tools/build_apk.sh` also checks drawing

## Lab Arcade 1.6 (2026-10-19)
- New app icon: a lab flask with a game controller, with proper Android adaptive icon layers (no more cropped sock)
- Swipes ignore stray pointer moves, so a swipe or tap is never misread

## Lab Arcade 1.5 (2026-10-19)
- Fixed: swiping the launcher on a touch screen only worked when the swipe started on a button. Now it scrolls wherever you start, and keeps gliding a little
- Tests: swipe scrolling from cards, labels and buttons; taps still press buttons

## Lab Arcade 1.4 (2026-10-19)
- New launcher layout: each game card shows run length, best score, times played, effort and saved progress, with Play / Continue, Difficulty and Info buttons
- Info page per game: story, controls, facts, difficulty, all versions
- Settings page: difficulty for all games, sort order, menu orientation, reset high scores, about
- Sorting: A to Z, recently played, most played, shortest / longest first, most effort, newest
- Portrait support: the menu turns with the phone (one column); games always play in landscape
- Tests: 143 checks, now also covering the launcher pages, sorting and portrait layout

## Lab Arcade 1.3 (2026-10-19)
- Fixed: The Last Knight, Escape Velocity and Lighthouse Keeper did not start in 1.2 (a stale build cache shipped their scenes without code)
- Renamed the app to Lab Arcade (high scores are kept)
- Difficulty (Easy / Normal / Hard) for every game, chosen in the menu
- Continue / New game buttons for The Last Knight's save
- Each game shows how long a run takes and how much effort went into it
- Tap anywhere to start a game or play again

## Laugh Lab Arcade 1.2 (2026-10-19)
All the Laugh Lab games John kept, remade in Godot:
- waveguide_snake v1: remake of the Laugh Lab built-in game, with swipe controls
- cleanroom_parkour v1: remake of the Laugh Lab built-in game, five rooms
- escape_the_cavity v2: remake of web v2 (difficulty setting, 6 levels with the Lab Cat)
- bend_it_like_einstein v2: remake of web v2 (difficulty setting, nebula fog level)
- orbit_courier v1: remake, with a difficulty setting
- never_ask_for_directions v1: remake; the longship sails sideways to fit a landscape screen
- lighthouse_keeper v1: remake (fog, storm, smugglers, serpent)
- escape_velocity v1: remake (5 zones, windmills, geese, the Moon)
- the_last_knight v2: remake of web v2 (5 eras, boss fight, save and continue)
- Menu: version history page per game

## Laugh Lab Arcade 1.1 (2026-10-19)
- Interim build with the first seven games

## Laugh Lab Arcade 1.0 (2026-10-19)
- sock_escape v1: first version
