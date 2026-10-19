# Every game in the arcade, with its version history.
#
# Each version lives in its own folder (games/<id>/v<N>/) and stays playable,
# so a new version never overwrites an old one. To release a new version:
# copy the newest folder to v<N+1>, change it, and add an entry at the END
# of "versions". The menu plays the last entry by default.
# "web" lists the versions that existed in the Laugh Lab web page (not playable here).
const LIST := [
	{
		"id": "sock_escape",
		"name": "Sock Escape",
		"tagline": "A sock flees the washing machine. Jump, duck, survive the Dryer of Doom.",
		"color": Color(0.30, 0.55, 0.85),
		"best_file": "user://sock_escape_best.dat",
		"versions": [
			{"v": 1, "date": "2026-10-19", "scene": "res://games/sock_escape/v1/game.tscn", "notes": "First version."},
		],
		"web": [],
	},
	{
		"id": "waveguide_snake",
		"name": "Waveguide Snake",
		"tagline": "You're a light pulse. Eat photons, grow, dodge scattering defects.",
		"color": Color(0.20, 0.45, 0.75),
		"versions": [
			{"v": 1, "date": "2026-10-19", "scene": "res://games/waveguide_snake/v1/game.tscn", "notes": "Godot remake of the Laugh Lab built-in game, with swipe controls."},
		],
		"web": ["v1 (2026-10-17): built into Laugh Lab"],
	},
	{
		"id": "cleanroom_parkour",
		"name": "Cleanroom Parkour",
		"tagline": "Late for your cleanroom slot. Jump pits, deadlines and falling reviews.",
		"color": Color(0.55, 0.40, 0.75),
		"versions": [
			{"v": 1, "date": "2026-10-19", "scene": "res://games/cleanroom_parkour/v1/game.tscn", "notes": "Godot remake of the Laugh Lab built-in game, five rooms."},
		],
		"web": ["v1 (2026-10-17): built into Laugh Lab"],
	},
	{
		"id": "escape_the_cavity",
		"name": "Escape the Cavity",
		"tagline": "You're a photon stuck in a laser. Hop the mirrors, grab carriers, survive 6 levels.",
		"color": Color(0.80, 0.30, 0.42),
		"versions": [
			{"v": 2, "date": "2026-10-19", "scene": "res://games/escape_the_cavity/v2/game.tscn", "notes": "Godot remake of web v2: difficulty setting, 6 levels with the Lab Cat."},
		],
		"web": ["v1 (2026-10-18): original", "v2 (2026-10-19): difficulty setting, 6 levels with a new Lab Cat, broader jokes"],
	},
	{
		"id": "bend_it_like_einstein",
		"name": "Bend It Like Einstein",
		"tagline": "Hold to summon a pocket black hole and bend photons into the fiber.",
		"color": Color(0.25, 0.30, 0.55),
		"versions": [
			{"v": 2, "date": "2026-10-19", "scene": "res://games/bend_it_like_einstein/v2/game.tscn", "notes": "Godot remake of web v2: difficulty setting, nebula fog level."},
		],
		"web": ["v1 (2026-10-18): original", "v2 (2026-10-19): difficulty setting, real fog level, broader jokes"],
	},
]
