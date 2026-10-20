# Changelog

Every game keeps all its versions: each lives in `arcade/games/<game>/v<N>/` and stays playable from the game's **Versions** page in the app. Each game version also has a git tag `<game>-v<N>`, and each app build has a tag `arcade-<version>`.

## Lab Arcade 2.4 (2026-10-20)
- Game updates and new games no longer need a new app: the app reads a signed game list from GitHub, and each game's download now carries the game's code too
  - the list is only used when its signature checks out (the signing key stays on the PC that publishes) and it is newer than the one in the app, so a changed or old list is ignored
  - every download is still checked against its fingerprint before it's loaded
  - covers and screenshots of new games come with the list
  - a game update that needs newer shared code waits for an app update; until then the app keeps its own copy
- The launcher is smaller: game code moved out of it into the game downloads (every game downloads once more after this update)

## Lab Arcade 2.3 (2026-10-20)
- Kenney Racing 2.0 is a kart racer (1.0, the free drive, stays playable from its Versions page):
  - five tracks (Oval, Classic, Hairpins, Snake, Grand Tour) built from the kit's pieces, with bumps
  - three computer drivers, 3 laps, a 3-2-1-GO countdown, finish line, live position, lap and time
  - boost pads, a drift boost and a start boost; item boxes with mushroom (boost), banana (spins out whoever hits it) and shell (flies at the car ahead), more mushrooms for whoever is behind
  - Race, a 5-track Cup with points, and Time trial against the ghost of your best time on each track
  - score and wins count in the Arcade; Easy / Normal / Hard sets how fast the others drive
  - GAS / BRAKE were the same as the stick, so they're replaced by ITEM and REVERSE; a help page inside the game
- The on-screen controls can hide the stick and big buttons while a game shows its own menu

## Lab Arcade 2.2 (2026-10-20)
- Duel Defense made for phones:
  - fixed: picking a level did nothing, so you couldn't start a game (a link was lost when the online mods screen was removed); the pop-ups' close buttons work again too
  - fixed: the "?" help button sat on top of Level select and Settings, so taps there opened the help instead
  - everything is 1.5x bigger, pop-ups (levels, settings, achievements, about) fill most of the screen with bigger text, and the phone's back button closes them
  - the menu has "How to play" and "Back to Arcade" (was "Quit"); the map editor, which needs a mouse, is hidden on phones
  - a new phone test taps Level select, closes it with back, taps a level and plays it

## Lab Arcade 2.1 (2026-10-20)
- Every game starts at version 1.0: The Last Knight, Escape the Cavity and Bend It Like Einstein were numbered v2 (their v1 was the old web version, never in the app) and are now v1.0 like all the others
- Game versions are shown as v1.0, v1.1... on the game pages and start screens

## Lab Arcade 2.0 (2026-10-20)
- Lab Arcade 2.0: 32 games in one app, every one playable by touch: 10 arcade games remade from Laugh Lab, 12 puzzle and board games, and 10 open-source games by others, each security-reviewed
- What 2.0 is built on: a Steam-style Home and Library with search, filters, ratings and collections; games as downloads that only update when they changed; a start screen per game with difficulty, high scores, saves and achievements; help pages inside 12 games; your profile, save backup, in-app updates, keyboard and controller support
- Updates now compare build numbers, so version names can move on freely
- The tests no longer depend on what's online at that moment, and the Library only jumps back to where you were when you come back from another page

## Lab Arcade 1.28 (2026-10-20)
- Bug fixing round over all 32 games:
  - a new stress test (`tools/test.sh stress`, optional `diff=0..2` and `only=`) starts every game from its start screen like a player, plays 40 s with taps, swipes, long presses, two fingers and keys, turns the phone halfway, then presses back and tries Continue; run on Normal and on Hard
  - fixed: the phone's back button in Sock Escape and in Outpost Assault (game and its menu) changed scene while the app was still busy, which logged errors and could fail
  - fixed: 10 title screens still said difficulty is changed "in the menu"; it's on the game's start screen now
  - the full test suite also ran with real rendering: no shader or drawing errors

## Lab Arcade 1.27 (2026-10-20)
- Help pages inside 12 games: a "?" button opens the game's own page with its goal, controls, rules and tips (the game pauses while it's open; "Got it" or the back button closes it). It also opens by itself the first time you play the game
  - Puzzles: Minesweeper, Nonogram, Sudoku, Mahjong, Solitaire, Sokoban
  - The Last Knight, Outpost Assault, Open RTS, Deck Crawler, Duel Defense, Tactical RPG
- The text lives in each game's own folder (`help.json`, or `lab_arcade_help.json` for games by others), shown by `common/help_page.gd`
- Small fix: on tiny pixel-art screens (Deck Crawler) the phone buttons' touch areas no longer overlap
- Back from a game's Info page, Home and Library return to where you were scrolled (rows on Home too) instead of the top
- City Builder: a new city starts on a piece of grass land with trees around the edge, instead of an empty grey space; new cover art showing a town on its land

## Lab Arcade 1.26 (2026-10-20)
- Five bigger games by others, each security-reviewed first (see SECURITY_REVIEW.md in each folder) and made playable by touch:
  - City Builder (Kenney): tap to build roads, parks and houses; drag, pinch and twist the view; your town saves itself
  - Deck Crawler (Adam Gulacsi): a Slay-the-Spire-style deckbuilder; drag cards onto enemies, drag the map
  - Open RTS (Lampe Games): real-time strategy against the computer; tap to select and give orders, drag and pinch the camera, BOX / ALL / NONE
  - Duel Defense (d10sfan): tower defense with three maps; its online mod downloads and start-up command files are removed
  - Tanks of Freedom II (P1X): turn-based tank battles with campaigns, skirmish and a map editor; online and network play switched off, pinch to zoom
- Bread Adventure was left out: its open-source version has none of its texts
- Games by others that save Godot resources now have their saves checked before loading (`common/safe_resource.gd`)

## Lab Arcade 1.25 (2026-10-20)
- Achievements: 3 to 5 per game (play it, play it often, an hour in total, and a win or a high score, also on Hard), shown on each game's start screen with the date you got them. New ones get a banner; the profile shows your total and the latest ones
- Save backup (Settings, "Backup"): one file with your saved games, high scores, achievements, ratings, collections and settings. Save it as a file, or copy it as text and paste it back on a new phone. Restoring asks first, only writes plain data (no code), and leaves downloads alone. Open RPG's story saves stay out, because that game reads them in a way a doctored backup could abuse
- Keyboard and controller: arrows / d-pad move between buttons, Enter / A presses, Escape / B goes back, and the shoulder buttons switch between Home and Library. Start screens begin on Play

## Lab Arcade 1.24 (2026-10-20)
- A Steam-style Home: a big banner for the game you played last (Resume) or one to start with, then rows of covers you swipe sideways: your picks, your collections, recently played, new and updated, and one row per genre
- Rate games (1 to 5 stars on their page) and sort the Library by your rating
- Collections: make your own lists of games on a game's page; each gets a Home row and a Library filter, and can be deleted in Settings
- Smoother feel: a soft tap sound and a short vibration on buttons (both can be switched off in Settings under "Feel"), and pages and covers fade in

## Lab Arcade 1.23 (2026-10-20)
- Updates inside the app: Lab Arcade checks GitHub for a newer version and shows an Update banner (one tap downloads it). Settings has "Check for updates"
- What's new: the first start after an update shows what changed (also in Settings), and games get NEW or UPDATED badges until you open them
- Playtime and a profile page: time played per game (on the cards and start screens), and a profile with total time, games tried, times played, rounds won and your most played games

## Lab Arcade 1.22 (2026-10-20)
- Every game has its own start screen (`arcade/common/game_hub.gd`): its cover, Play or Continue / New game, difficulty, a top-10 high score list (score, difficulty, date), the saved game (with Delete), sound on/off and clearing the scores, how to play, about and credits. "< MENU" in a game comes back to it; "< Arcade" goes back to the launcher
- Play on the start screen skips the game's own title screen
- The launcher is now just the library: covers, game pages and downloads. Difficulty, saves and scores moved to the games' start screens

## Lab Arcade 1.21 (2026-10-20)
- Cover art for every game (Steam-style headers): the art games by others ship with where it's good (Open RPG's banner, Outpost Assault's cover and logo), and covers made from real gameplay or drawn by hand for the rest (`arcade/tools/covers/`)
- The Library is a grid of cover tiles (3 across in landscape): tap a cover for the game's page; Play / difficulty / Info / Home under it
- A Steam-style game page: the cover with name, description and key facts beside it, a big Play / Get button, tags, screenshots (tap to see full screen), About, How to play, Details, Credits and Versions

## Lab Arcade 1.20 (2026-10-20)
- Set up to scale (still one repository):
  - each game describes itself in its own folder (`arcade_info.json`); `tools/catalog.py` joins and checks them into `catalog.json`, which the app reads. Adding a game = adding its folder (see "Adding a game" in the README)
  - board games keep their phone tests in their own folder (`arcade_tests.gd`)
  - the APK and the game downloads moved to the `downloads` branch, one commit rewritten per release, so the main history stops growing with builds. New install link: https://github.com/Hephaestus985/Laugh-Labs/raw/downloads/apks/LabArcade.apk
  - builds only rebuild changed game downloads and only test what changed since the last release (plus the launcher and a rotating spot check of 3 games); `FULL=1` tests everything
  - the tests run on GitHub on every push (`.github/workflows/tests.yml`)
  - `tools/publish.sh` publishes a release in one step
- A crashed set of board-game checks now fails the build instead of passing quietly

## Lab Arcade 1.19 (2026-10-20)
- Games are now downloads: the app itself is small (the launcher), and each game is fetched from github.com/Hephaestus985/Laugh-Labs (packs/) the first time you play it, then works offline. Cards show "Get" with the size; Settings has "Download all" and "Delete all downloads"; a game's Info page can delete its download
- Safe: the app only installs a download whose SHA-256 fingerprint matches the list built into that app version
- Smart updates: an app update only asks for a game again if that game changed. Unchanged games keep the exact same pack (it isn't rebuilt), so the copy on your phone stays
- Tests: a launcher-only build (like the phone app) refuses a damaged download, installs and plays downloaded games, loads them again on the next start, and keeps unchanged games after an update

## Lab Arcade 1.18 (2026-10-20)
- All 12 board and puzzle games now turn with the phone: a portrait layout with the buttons along the bottom (Minesweeper and Sokoban turn their board on its side to fill the tall screen)
- Animations everywhere: 2048 tiles slide, merge with a pop and new tiles grow in; Sudoku numbers pop and finished rows / columns / boxes glow; Minesweeper cells open in a ripple and mines go off with a blast; Solitaire cards fly to their place and turn over; Nonogram cells pop and solved lines glow; Lights Out lights fade with a ripple; Sliding Puzzle tiles slide; Mahjong pairs lift away and shuffles wobble; Sokoban's worker and crates walk smoothly; Flow pipes pulse when connected; Block Stacker rows flash and drops leave a trail; Connect Four discs fall into place; the end screen fades in
- Tests now also play every one of the 12 games on a tall (portrait) screen

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
