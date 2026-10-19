# Every game in the arcade, with its version history.
#
# Each version lives in its own folder (games/<id>/v<N>/) and stays playable,
# so a new version never overwrites an old one. To release a new version:
# copy the newest folder to v<N+1>, change it, and add an entry at the END
# of "versions". The menu plays the last entry by default.
# "length" is how long one run or round takes, "effort" how much work went into the
# original, "godot_time" roughly how long the Godot version took to build.
# "web" lists the versions that existed in the Laugh Lab web page (not playable here).
const LIST := [
	{
		"id": "sock_escape",
		"about": "A runaway sock flees the washing machine through the laundry room: rubber ducks, soap bars, cats, bubbles and a hairdryer. It speeds up every second.",
		"controls": "Phone: tap the right side to jump (again for a double jump), hold the left side to duck. PC: SPACE / up to jump, down to duck.",
		"length": "1-3 min per run (endless, gets faster)",
		"effort": "Original for the arcade",
		"godot_time": "~10 min",
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
		"about": "You are a light pulse in a waveguide. Collect photons and grow, but don't hit the walls, your own tail or scattering defects. Every 5 photons adds defects and speed.",
		"controls": "Phone: swipe to steer. PC: arrows or WASD.",
		"length": "1-3 min per run (endless)",
		"effort": "Laugh Lab built-in game",
		"godot_time": "~3 min",
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
		"about": "You're late for your cleanroom slot. Every 14 seconds is a new room with new hazards: pits, flying deadlines, hopping HF, falling reviews. Grab wafers for bonus metres.",
		"controls": "Phone: tap to jump, tap again in the air to double jump. PC: SPACE or up.",
		"length": "1-2 min per run (endless, 5 rooms)",
		"effort": "Laugh Lab built-in game",
		"godot_time": "~3 min",
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
		"about": "You are a photon trapped in a VCSEL, and the only way out is to hop across Bragg mirrors while Reviewer 2 sweeps the room with a laser pointer. Survive 72 seconds and 6 levels.",
		"controls": "Phone: drag on the left half to move, JUMP button to jump. PC: arrows to move, SPACE or up to jump.",
		"length": "72 s round, 6 levels",
		"effort": "Web effort 4 of 8: Polished",
		"godot_time": "~5 min",
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
		"about": "Photons refuse to turn, so you summon a pocket black hole to bend them into the fiber. Don't let them fall in, and watch out for the goose, the monolith and the nebula.",
		"controls": "Phone: touch and hold where the black hole should be. PC: hold the mouse, or move with arrows and hold SPACE.",
		"length": "60 s round, 5 levels",
		"effort": "Web effort 4 of 8: Polished",
		"godot_time": "~4 min",
		"name": "Bend It Like Einstein",
		"tagline": "Hold to summon a pocket black hole and bend photons into the fiber.",
		"color": Color(0.25, 0.30, 0.55),
		"versions": [
			{"v": 2, "date": "2026-10-19", "scene": "res://games/bend_it_like_einstein/v2/game.tscn", "notes": "Godot remake of web v2: difficulty setting, nebula fog level."},
		],
		"web": ["v1 (2026-10-18): original", "v2 (2026-10-19): difficulty setting, real fog level, broader jokes"],
	},
	{
		"id": "orbit_courier",
		"about": "Deliver party invitations across the galaxy by slingshotting between moving planets. Let go of your orbit at the right moment. You have to planet ahead.",
		"controls": "Tap anywhere or press SPACE to let go of the orbit.",
		"length": "2-4 min per run (endless)",
		"effort": "Web effort 7 of 8: Studio (built and playtested)",
		"godot_time": "~3 min",
		"name": "Orbit Courier",
		"tagline": "Slingshot between moving planets to deliver party invitations.",
		"color": Color(0.35, 0.25, 0.60),
		"versions": [
			{"v": 1, "date": "2026-10-19", "scene": "res://games/orbit_courier/v1/game.tscn", "notes": "Godot remake of the Laugh Lab game, with a difficulty setting."},
		],
		"web": ["v1 (2026-10-18): original"],
	},
	{
		"id": "never_ask_for_directions",
		"about": "Steer a Viking longship through fjords, gusts, icebergs and a kraken, without once asking for the way. Grab loot, keep your three shields.",
		"controls": "Phone: hold the screen above or below the ship to steer. PC: up / down.",
		"length": "2-4 min per run (endless, 5 zones)",
		"effort": "Web effort 7 of 8: Studio (built and playtested)",
		"godot_time": "~3 min",
		"name": "Never Ask for Directions",
		"tagline": "Steer a Viking longship past fjords, icebergs and a kraken. Don't ask.",
		"color": Color(0.20, 0.42, 0.55),
		"versions": [
			{"v": 1, "date": "2026-10-19", "scene": "res://games/never_ask_for_directions/v1/game.tscn", "notes": "Godot remake of the Laugh Lab game. Sails sideways to fit a landscape screen."},
		],
		"web": ["v1 (2026-10-18): original"],
	},
	{
		"id": "lighthouse_keeper",
		"about": "Swing a very expensive laser beam across a night sea so captains can see the rocks, without lighting up the smugglers or feeding the sea serpent. Each night adds fog, storms, smugglers or the serpent.",
		"controls": "Phone: touch where the beam should point. PC: move the mouse, or left / right.",
		"length": "3-6 min per run (endless levels)",
		"effort": "Web effort 7 of 8: Studio (built and playtested)",
		"godot_time": "~5 min",
		"name": "Lighthouse Keeper",
		"tagline": "Swing a very expensive laser so ships see the rocks. Mind the serpent.",
		"color": Color(0.70, 0.52, 0.18),
		"versions": [
			{"v": 1, "date": "2026-10-19", "scene": "res://games/lighthouse_keeper/v1/game.tscn", "notes": "Godot remake of the Laugh Lab game: fog, storm, smugglers and the serpent."},
		],
		"web": ["v1 (2026-10-18): original"],
	},
	{
		"id": "escape_velocity",
		"about": "Bounce from a Twente rooftop to the Moon, dodging honking geese, space junk and meteoroids, with stroopwafels as syrup-powered rocket fuel. Stomp geese from above.",
		"controls": "Phone: hold the left or right side of the screen to steer. PC: left / right. Jumping is automatic.",
		"length": "3-5 min to reach the Moon",
		"effort": "Web effort 7 of 8: Studio (built and playtested)",
		"godot_time": "~6 min",
		"name": "Escape Velocity",
		"tagline": "Bounce from an Enschede rooftop to the Moon. Stomp geese, eat stroopwafels.",
		"color": Color(0.20, 0.50, 0.70),
		"versions": [
			{"v": 1, "date": "2026-10-19", "scene": "res://games/escape_velocity/v1/game.tscn", "notes": "Godot remake of the Laugh Lab game: 5 zones, windmills, geese and the Moon."},
		],
		"web": ["v1 (2026-10-18): original"],
	},
	{
		"id": "the_last_knight",
		"about": "Eleven years of sword school, then someone invented the crossbow, so you chase the inventor through five eras of history: a castle, Viking seas, a Roman aqueduct, a Dutch polder and his tower. Progress saves at every level and at the boss.",
		"controls": "Phone: drag on the left half to move, JUMP and SWORD buttons. PC: arrows, SPACE / up to jump, X or J to swing. Swing at bolts and axes to parry them.",
		"save_file": "user://the_last_knight_save.json",
		"length": "20-30 min: 5 levels and a boss, with saves",
		"effort": "Web effort 8 of 8: Masterpiece (several playtest rounds)",
		"godot_time": "~12 min",
		"name": "The Last Knight",
		"tagline": "Chase the crossbow inventor through five eras. Parry, stomp, honk.",
		"color": Color(0.55, 0.18, 0.25),
		"versions": [
			{"v": 2, "date": "2026-10-19", "scene": "res://games/the_last_knight/v2/game.tscn", "notes": "Godot remake of web v2: 5 eras, the boss, save and continue at every level and at the boss."},
		],
		"web": ["v1 (2026-10-18): original", "v2 (2026-10-19): save and continue at every level and at the boss"],
	},
]


# Open-source games by other makers, shown in the "More games" tab. Each lives
# in external/<id>/ with its own license files. Their res:// paths were
# rewritten to the folder; changes made for the arcade are marked "[Lab Arcade]".
const EXTERNAL := [
	{
		"id": "outpost_assault",
		"name": "Outpost Assault",
		"tagline": "Tower defense: build gatling, cannon and missile turrets to hold the outpost.",
		"about": "Waves of infantry, tanks and helicopters march on your outpost. Tap the empty turret slots to build gatling, single-shot or missile turrets, and repair or replace them between waves. Survive three growing waves to win. Made by Quiver (quiver.dev) as an open-source Godot 4 template.",
		"controls": "Tap a turret slot to build, tap a turret to repair or remove it. Drag with one finger to move the map, pinch to zoom. PC: click, middle-drag to move, scroll to zoom. ESC pauses.",
		"length": "10-15 min: 3 waves",
		"effort": "Open-source game by Quiver",
		"credit": "Outpost Assault by Quiver (quiver.dev), github.com/quiver-dev/tower-defense-godot4. Code: MIT license. Art: CC BY 4.0. Font: Akashi by Ed Merritt. Added to Lab Arcade with touch controls and a back button.",
		"godot_time": "~30 min to review and add",
		"color": Color(0.35, 0.42, 0.25),
		"no_difficulty": true,
		"no_score": true,
		"aspect": "expand",
		"versions": [
			{"v": 1, "date": "2026-10-19", "scene": "res://external/outpost_assault/interfaces/UI/menu/menu.tscn", "notes": "Quiver's Outpost Assault (commit 1cbd622, 2026-08-21), security-reviewed, with touch pan / pinch zoom and a way back to the arcade."},
		],
		"web": [],
	},
]

