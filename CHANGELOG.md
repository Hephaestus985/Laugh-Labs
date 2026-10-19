# Changelog

Every game keeps all its versions: each lives in `arcade/games/<game>/v<N>/` and stays playable from the game's **Versions** page in the app. Each game version also has a git tag `<game>-v<N>`, and each app build has a tag `arcade-<version>`.

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
