class_name Store
extends RefCounted
# The game list ("store"): which games and versions exist, and the download (pack) of
# each version with its SHA-256. The app has one built in (res://catalog.json and
# res://packs.json). A newer one can come from GitHub (store.json + store.sig on the
# "downloads" branch), so games can be updated or added without a new app.
#
# Safety: a downloaded store is only used when its signature checks out against the
# public key below (the private key never leaves the PC that publishes), and when it
# is newer than the one in use (an old list can't be replayed to downgrade games).
# Packs are still checked against the SHA-256s in the store before they're loaded.
#
# A pack can need a newer app (its "min_build", when it uses shared code that changed):
# then this app keeps its own copy of that version, or doesn't show the version.

const URL := "https://raw.githubusercontent.com/Hephaestus985/Laugh-Labs/downloads/"
const DIR := "user://store"
const FORMAT := 1
const PUBLIC_KEY := """-----BEGIN PUBLIC KEY-----
MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAt2LEpBEdSilJ8cDiXFtj
IsdvLqMe+bIsWHcbpG05qvgroQ6FDQtopySINGRkllcBo8P383SR60sMuDahaowo
7K5wsisp927NLjtVZcrUReixnOt/f9NS2CoQCy+JATD4ZLTQLM0MSBQnyq6jmQ6O
PR8WQLtRfWzMsXB3xWPVWfH/dvG9cgIXLkKNhFE7ZY6iPyNMzZu/v+d4FniKCwbs
gVv5i+1IQut5B5blv/jAWjhIl1UsJ0vbLEvL+ZiiSpt08vQL5RfoKdvCJtjRFppb
rAyYdQdlV8j6DA/yflsK/1fXT/Lm+EgohYj7AuWbe4/cFQGJnzZVDepuczjMnqBl
qKtqjAer7hLID39HzUHpeMSzVX+3gU26A6DGiPIeqBfyOaqXZJ9YjUfa9hcOhCue
jb1sroInnCWHphV2my49p63FALD/9SGwAWi6qjIBurvTaJ3+BxUJrot8q7XStlkX
/83SNYxb1Y3a42EafHUTW9x1V9Z/R7nEe9jE2UbFSkVBAgMBAAE=
-----END PUBLIC KEY-----
"""

static var catalog := {}  # {"lab": [...], "external": [...]} as in catalog.json
static var packs := {}  # key ("<id>/v<N>") -> {file, sha256, size, scene, uids, classes, min_build}
static var art := {}  # res:// path of a cover or screenshot -> {file, sha256}
static var serial := 0  # which store is in use; the built-in one is app build * 1000
static var from_online := false
static var _ready := false
static var _builtin := {}


static func setup() -> void:
	if _ready:
		return
	_ready = true
	_builtin = {
		"serial": GameData.app_build() * 1000,
		"catalog": _read_json("res://catalog.json"),
		"packs": _read_json("res://packs.json"),
		"art": {},
	}
	_use(_builtin, false)
	# a store downloaded earlier (not in the editor: the tools there use the built-in one)
	if not OS.has_feature("editor") and FileAccess.file_exists(DIR.path_join("store.json")):
		var data := FileAccess.get_file_as_bytes(DIR.path_join("store.json"))
		var sig := FileAccess.get_file_as_bytes(DIR.path_join("store.sig"))
		var d := parse_signed(data, sig)
		if not d.is_empty() and int(d["serial"]) > serial:
			_use(d, true)


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if typeof(d) == TYPE_DICTIONARY else {}


## The store in `data` if `sig` is a valid signature of it and it is well formed, else {}.
static func parse_signed(data: PackedByteArray, sig: PackedByteArray, pem := PUBLIC_KEY) -> Dictionary:
	if data.is_empty() or sig.is_empty() or not verify(data, sig, pem):
		return {}
	var d = JSON.parse_string(data.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY or int(d.get("format", 0)) != FORMAT:
		return {}
	if not (d.get("catalog") is Dictionary and d.get("packs") is Dictionary and d.get("serial") is float):
		return {}
	return d


static func verify(data: PackedByteArray, sig: PackedByteArray, pem := PUBLIC_KEY) -> bool:
	var key := CryptoKey.new()
	if key.load_from_string(pem, true) != OK:
		return false
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(data)
	return Crypto.new().verify(HashingContext.HASH_SHA256, h.finish(), sig, key)


## Use a store: packs that need a newer app fall back to this app's own copy of that
## version (or are left out), and versions without a usable pack are hidden.
static func _use(d: Dictionary, online: bool) -> void:
	serial = int(d.get("serial", 0))
	from_online = online
	var build := GameData.app_build()
	var own: Dictionary = _builtin.get("packs", {})
	var p := {}
	var all_packs: Dictionary = d.get("packs", {})
	for key in all_packs:
		var m: Dictionary = all_packs[key]
		if int(m.get("min_build", 0)) <= build:
			p[key] = m
		elif own.has(key):
			p[key] = own[key]
	var c := {}
	var src: Dictionary = d.get("catalog", {})
	for kind in ["lab", "external"]:
		var games: Array = []
		for g in src.get(kind, []):
			if not g is Dictionary or not g.get("versions") is Array:
				continue
			var g2: Dictionary = g.duplicate(true)
			g2["versions"] = g2["versions"].filter(func(v): return v is Dictionary and (p.has("%s/v%d" % [g2["id"], int(v.get("v", 0))]) or p.is_empty()))
			if not g2["versions"].is_empty():
				games.append(g2)
		c[kind] = games
	catalog = c
	packs = p
	art = d.get("art", {}) if d.get("art") is Dictionary else {}


# ---------------------------------------------------------------- checking GitHub

## Fetch the newest store. done(changed: bool, message: String) is called at the end.
## A new store is used right away (the caller rebuilds its pages) and kept for next time.
static func check_online(host: Node, done: Callable) -> void:
	setup()
	_fetch(host, URL + "store.json", func(data: PackedByteArray):
		if data.is_empty():
			done.call(false, "couldn't reach the game list")
			return
		_fetch(host, URL + "store.sig", func(sig: PackedByteArray):
			var why := accept(data, sig)
			if why != "":
				done.call(false, "" if why == "not newer" else why)
				return
			_fetch_art(host, done)))  # done(true): the caller calls Packs.refresh()


## Take a downloaded store if it is signed and newer: returns "" when it is now in use,
## else why not. (The tests pass their own key as pem.)
static func accept(data: PackedByteArray, sig: PackedByteArray, pem := PUBLIC_KEY) -> String:
	setup()
	var d := parse_signed(data, sig, pem)
	if d.is_empty():
		return "the game list wasn't signed correctly, so it was ignored"
	if int(d["serial"]) <= serial:
		return "not newer"
	DirAccess.make_dir_recursive_absolute(DIR)
	_write(DIR.path_join("store.json"), data)
	_write(DIR.path_join("store.sig"), sig)
	_use(d, true)
	return ""  # the caller then calls Packs.refresh()


## Back to the app's own game list, forgetting downloaded ones (tests, and "reset").
static func reset_to_builtin() -> void:
	setup()
	for f in ["store.json", "store.sig"]:
		DirAccess.remove_absolute(DIR.path_join(f))
	_use(_builtin, false)  # the caller then calls Packs.refresh()


static func _write(path: String, data: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_buffer(data)


static func _fetch(host: Node, url: String, on_data: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 20.0
	host.add_child(req)
	req.request_completed.connect(func(result: int, code: int, _h, body: PackedByteArray):
		req.queue_free()
		on_data.call(body if result == HTTPRequest.RESULT_SUCCESS and code == 200 else PackedByteArray()))
	if req.request(url) != OK:
		req.queue_free()
		on_data.call(PackedByteArray())


# ---------------------------------------------------------------- covers and screenshots

## Covers and screenshots of games this app doesn't have yet are small downloads.
static func _art_file(path: String) -> String:
	return DIR.path_join("art").path_join(str(art[path]["sha256"]).substr(0, 24) + ".jpg")


static func _fetch_art(host: Node, done: Callable) -> void:
	var todo: Array = []
	for path in art:
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(_art_file(path)):
			todo.append(path)
	DirAccess.make_dir_recursive_absolute(DIR.path_join("art"))
	_next_art(host, todo, done)


static func _next_art(host: Node, todo: Array, done: Callable) -> void:
	if todo.is_empty():
		done.call(true, "")
		return
	var path: String = todo.pop_back()
	var entry: Dictionary = art[path]
	_fetch(host, URL + str(entry["file"]), func(data: PackedByteArray):
		var h := HashingContext.new()
		h.start(HashingContext.HASH_SHA256)
		h.update(data)
		if not data.is_empty() and h.finish().hex_encode() == str(entry["sha256"]):
			_write(_art_file(path), data)
		_next_art(host, todo, done))


## A cover or screenshot: from the app, or downloaded with the game list.
static func texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if not art.has(path) or not FileAccess.file_exists(_art_file(path)):
		return null
	var img := Image.new()
	if img.load_jpg_from_buffer(FileAccess.get_file_as_bytes(_art_file(path))) != OK:
		return null
	return ImageTexture.create_from_image(img)
