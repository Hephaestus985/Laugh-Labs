# Every game in the arcade, with its version history.
#
# Each game describes itself in its own folder: games/<id>/arcade_info.json (made for
# the arcade) or external/<id>/arcade_info.json (games by others). tools/catalog.py
# checks them and joins them into catalog.json, which is what the app reads here
# (or a newer, signed game list from GitHub: see common/store.gd).
# Adding a game = adding its folder; see "Adding a game" in the README.
#
# Each version lives in its own folder (games/<id>/v<N>/) and stays playable, so a
# new version never overwrites an old one: copy the newest folder to v<N+1>, change
# it, and add an entry at the END of "versions". The menu plays the last one.
# "length" is how long one run or round takes, "effort" how much work went into the
# original, "godot_time" roughly how long the Godot version took to build.
# "web" lists versions that existed in the Laugh Lab web page (not playable here).

static var LIST: Array = _load("lab")
## Open-source games by other makers ("More games" filter). Each lives in
## external/<id>/ with its license and security review; changes are marked "[Lab Arcade]".
static var EXTERNAL: Array = _load("external")


static func _load(kind: String) -> Array:
	# the game list in use: the app's own catalog.json, or a newer signed one (see Store)
	Store.setup()
	var data: Dictionary = Store.catalog
	if data.is_empty():
		push_error("catalog.json is missing or broken: run tools/catalog.py")
		return []
	var out: Array = []
	for g in data.get(kind, []):
		g = g.duplicate(true)
		g["color"] = Color(str(g["color"]))
		for v in g["versions"]:
			v["v"] = int(v["v"])
		out.append(g)
	return out


## After a newer game list arrived.
static func reload() -> void:
	LIST = _load("lab")
	EXTERNAL = _load("external")
