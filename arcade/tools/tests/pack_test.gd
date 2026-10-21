extends Node
# Download pack test, run inside a launcher-only build (no games inside), as the
# phone app is built. Usage: <LinuxBase build> --headless -- <report_dir> <packs_dir>
# <packs_dir> holds Linux packs for a few games plus sha.json with their SHA-256.
# Checks: the launcher has no games inside, a damaged pack is refused, a good one
# installs, its game starts with its code, it is loaded again on the next start,
# and an app update keeps an unchanged pack without downloading it again.

const Games := preload("res://games.gd")

var results: Array = []
var errors: Array[String] = []

class ErrorCounter extends Logger:
	var owner_test: Node
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
		if file.contains("jolt_job_system"):
			return
		owner_test.errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])


func check(test: String, ok: bool, detail := "") -> void:
	results.append([test, ok, detail])
	print("%s  %-26s %-44s %s" % ["PASS" if ok else "FAIL", "packs", test, detail])


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var lc := ErrorCounter.new()
	lc.owner_test = self
	OS.add_logger(lc)
	AudioServer.set_bus_mute(0, true)
	get_window().size = Vector2i(1920, 1080)
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var dir: String = args[1]
	await frames(1)
	for g in Games.EXTERNAL:
		if g.has("park"):
			load(g["park"]).park(get_tree())
	# the always-loaded helpers of games by others start with the app, before any
	# download: everything they need must be inside the launcher
	var broken := []
	for prop in ProjectSettings.get_property_list():
		var k: String = prop["name"]
		if k.begins_with("autoload/"):
			var n := get_tree().root.get_node_or_null(NodePath(k.trim_prefix("autoload/")))
			if n == null or (str(ProjectSettings.get_setting(k)).ends_with(".gd") and n.get_script() == null):
				broken.append(k.trim_prefix("autoload/"))
	check("the launcher's always-loaded helpers all start (no downloads yet)", broken.is_empty(), ", ".join(broken))
	# start clean: no downloads and no downloaded game list on this "phone"
	for f in DirAccess.get_files_at(Packs.DIR):
		DirAccess.remove_absolute(Packs.DIR.path_join(f))
	Store.reset_to_builtin()
	Packs.setup()
	Packs.refresh()
	var sha: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("sha.json")))
	check("the app lists every game version as a pack", Packs.manifest.size() >= Games.LIST.size() + Games.EXTERNAL.size(), "%d packs" % Packs.manifest.size())
	for key in sha:
		var scene: String = Packs.manifest[key]["scene"]
		var e0 := errors.size()
		check("%s is not inside the launcher" % key, not ResourceLoader.exists(scene) and Packs.status(key) == "download")
		var cls: Array = Packs.manifest[key].get("classes", [])
		if not cls.is_empty():
			check("%s: its code comes with the download (%d classes)" % [key, cls.size()], not ResourceLoader.exists(cls[0]["path"]))
		# the test packs are built for Linux: trust their fingerprints instead of the Android ones
		Packs.manifest[key]["sha256"] = sha[key]
		var src := dir.path_join(key.replace("/", "_") + ".pck")
		var bad := Packs.DIR.path_join("bad.part")
		DirAccess.copy_absolute(src, bad)
		var f := FileAccess.open(bad, FileAccess.READ_WRITE)
		f.seek_end()
		f.store_8(7)
		f = null
		check("%s: a damaged download is refused" % key, Packs.install_file(key, bad) != "" and Packs.status(key) == "download")
		var good := Packs.DIR.path_join("good.part")
		DirAccess.copy_absolute(src, good)
		var err := Packs.install_file(key, good)
		check("%s: the real pack installs" % key, err == "" and Packs.status(key) == "ready", err)
		var ps = load(scene)
		var n: Node = ps.instantiate() if ps else null
		check("%s: its game starts with its code" % key, n != null and (n.get_script() != null or n.get_child_count() > 0))
		if n:
			get_tree().root.add_child(n)
			get_tree().current_scene = n
			await frames(90)
			if is_instance_valid(n):
				n.queue_free()
			get_tree().current_scene = self
			await frames(3)
		var new_errs := errors.slice(e0)
		check("%s: plays without errors" % key, new_errs.is_empty(), ", ".join(new_errs.slice(0, 2)))
	# an update of a game downloaded while an older version of it is loaded: the new
	# files win, and the app says to restart for the new code
	if sha.has("racing/v1") and Packs.manifest.has("racing/v2"):
		Packs.manifest["racing/v2"]["sha256"] = sha["racing/v1"]
		var again := Packs.DIR.path_join("again.part")
		DirAccess.copy_absolute(dir.path_join("racing_v1.pck"), again)
		check("an update while the old version is loaded installs", Packs.install_file("racing/v2", again) == "" and Packs.mounted.has("racing/v2"))
		check("... and asks to restart the app for it", Packs.needs_restart("racing") and not Packs.needs_restart("sudoku"))
		Packs.remove("racing/v2")
		Packs.mounted.erase("racing/v2")
	# next app start: downloads are loaded again from the phone
	Packs.mounted.clear()
	Packs.mount_all()
	check("downloads are loaded again on the next start", Packs.mounted.size() == sha.size())
	# app update where the game didn't change: same fingerprint, no new download
	var state := Packs.state()
	var same := true
	for key in sha:
		Packs.mounted.erase(key)
		same = same and state.get(key, "") == Packs.manifest[key]["sha256"] and Packs.status(key) == "ready"
	check("an app update keeps unchanged games", same)
	# an update that changed a game asks for that one again
	var first: String = sha.keys()[0]
	Packs.manifest[first]["sha256"] = "0".repeat(64)
	check("an app update asks again only for changed games", Packs.status(first) == "update")
	for k in sha:
		Packs.remove(k)
	var failed := results.filter(func(r): return not r[1])
	var lines := ["Lab Arcade pack test", "%d checks, %d failed" % [results.size(), failed.size()], ""]
	for r in results:
		lines.append("%s  %s  %s" % ["PASS" if r[1] else "FAIL", r[0], r[2]])
	var rf := FileAccess.open(out.path_join("pack_report.txt"), FileAccess.WRITE)
	rf.store_string("\n".join(lines) + "\n")
	print("PACKTESTS: %d checks, %d failed" % [results.size(), failed.size()])
	get_tree().quit(1 if failed.size() > 0 else 0)
