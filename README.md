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

Under each game in the app: **Difficulty** (Easy / Normal / Hard), **Versions** (every older version stays playable, plus run length and effort), and **Continue / New game** for games with saves (The Last Knight). See [CHANGELOG.md](CHANGELOG.md).

## For developers
`arcade/` is one Godot 4 project. Each game version lives in `arcade/games/<game>/v<N>/` and is listed in `arcade/games.gd`. Shared input, touch controls and high scores are in `arcade/common/arcade_game.gd`. `arcade/tools/smoke_test.tscn` plays every game with random input and saves screenshots. Open `arcade/` in Godot and press F5 to play on a PC. Build and test the APK with `arcade/tools/build_apk.sh`.
