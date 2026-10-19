# Laugh-Labs

Silly little games, all in one Android app: **Laugh Lab Arcade**.

**Install on your phone:** [LaughLabArcade.apk](https://github.com/Hephaestus985/Laugh-Labs/raw/main/apks/LaughLabArcade.apk). Open it and allow installs from your browser if Android asks. Installing a newer version updates the app and keeps your high scores.

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

Every game keeps its old versions: open **Versions** under a game in the app. See [CHANGELOG.md](CHANGELOG.md).

## For developers
`arcade/` is one Godot 4 project. Each game version lives in `arcade/games/<game>/v<N>/` and is listed in `arcade/games.gd`. Shared input, touch controls and high scores are in `arcade/common/arcade_game.gd`. `arcade/tools/smoke_test.tscn` plays every game with random input and saves screenshots. Open `arcade/` in Godot and press F5 to play on a PC.
