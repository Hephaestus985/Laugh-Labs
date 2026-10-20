extends SceneTree
# Works out how the app is split into the launcher (inside the APK) and one
# download pack per game version. Run headless from the arcade folder:
#   godot --headless --path . -s res://tools/pack_plan.gd -- <out.json>
# Writes {"base": [files], "packs": {"<id>/v<N>": {"dir": ..., "files": [...], "classes": [...]}}}.
#
# The launcher keeps: menu, common code, games.gd, icons, and everything the
# always-loaded helpers (autoloads) need when the app starts. A pack holds the
# game's own folder; files the launcher already has are never replaced by a pack.

const Games := preload("res://games.gd")

var classes := {}  # class_name -> script path


func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	for c in ProjectSettings.get_global_class_list():
		classes[c["class"]] = c["path"]
	var base := {}
	for f in ["res://menu.tscn", "res://menu.gd", "res://games.gd", "res://catalog.json", "res://whats_new.json", "res://default_bus_layout.tres", "res://icon.png", "res://icon_192.png", "res://icon_bg.png", "res://icon_fg.png", "res://icon_mono.png"]:
		_add(base, f)
	for f in _files_in("res://common"):
		_add(base, f)
	# scripts the launcher calls for games by others (e.g. to put their helpers to sleep)
	for g in Games.EXTERNAL:
		if g.has("park"):
			_add(base, g["park"])
	# autoloads and everything they reach
	for prop in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		if not key.begins_with("autoload/"):
			continue
		var path := str(ProjectSettings.get_setting(key)).trim_prefix("*")
		if path.begins_with("uid://"):
			path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))
		var addon := path.find("/addons/")
		if addon >= 0:
			# add-ons look up their own files at runtime: keep the whole add-on
			var root := path.substr(0, path.find("/", addon + 8) + 1)
			for f in _files_in(root.trim_suffix("/")):
				_add(base, f)
		_add(base, path)
	# A game's code goes in its pack (the app adds the pack's script classes to its
	# class list when it loads the pack: see common/packs.gd). Only cover art and
	# screenshots stay here: the launcher shows them before a game is downloaded.
	for root in ["res://games", "res://external"]:
		for f in _files_in(root):
			if f.get_file() == "cover.jpg" or (f.get_base_dir().get_file() == "shots" and f.ends_with(".jpg")):
				base[f] = true
	var packs := {}
	for g in Games.LIST:
		for v in g["versions"]:
			var dir: String = str(v["scene"]).get_base_dir()
			packs["%s/v%d" % [g["id"], v["v"]]] = {"dir": dir, "scene": v["scene"], "files": _pack_files(dir, base)}
	for g in Games.EXTERNAL:
		var dir: String = "res://external/" + str(g["id"])
		for v in g["versions"]:
			packs["%s/v%d" % [g["id"], v["v"]]] = {"dir": dir, "scene": g.get("main", v["scene"]), "files": _pack_files(dir, base)}
	# the script classes each pack brings
	var class_list := ProjectSettings.get_global_class_list()
	for key in packs:
		var files := {}
		for f in packs[key]["files"]:
			files[f] = true
		var cl := []
		for c in class_list:
			if files.has(c["path"]):
				cl.append({"class": str(c["class"]), "base": str(c["base"]), "icon": str(c["icon"]), "is_abstract": c.get("is_abstract", false), "path": c["path"]})
		packs[key]["classes"] = cl
		# resource IDs Godot knows for the pack's files (also those inside binary files)
		var uids := {}
		for f in packs[key]["files"]:
			var id := ResourceLoader.get_resource_uid(f)
			if id != ResourceUID.INVALID_ID:
				uids[ResourceUID.id_to_text(id)] = f
		packs[key]["uids"] = uids
	var base_list := base.keys()
	base_list.sort()
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"base": base_list, "packs": packs}, "\t"))
	print("base files: %d, packs: %d" % [base_list.size(), packs.size()])
	quit()


func _pack_files(dir: String, base: Dictionary) -> Array:
	var out := []
	for f in _files_in(dir):
		if not base.has(f) and _is_resource(f):
			out.append(f)
	out.sort()
	return out


func _is_resource(f: String) -> bool:
	if f.contains("/AssetLicenses/"):
		return true  # license texts a game shows itself (Duel Defense's About page)
	return not (f.ends_with(".import") or f.ends_with(".uid") or f.ends_with(".md") or f.get_file().begins_with("LICENSE") or f.ends_with(".txt") or f.get_file() in ["arcade_info.json", "arcade_tests.gd"])


func _files_in(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		out.append(dir.path_join(f))
	for sub in d.get_directories():
		if not sub.begins_with("."):
			out.append_array(_files_in(dir.path_join(sub)))
	return out


## Add a file and (recursively) what it needs: its dependencies and the
## script classes its code mentions.
func _add(base: Dictionary, path: String) -> void:
	if path == "" or base.has(path) or not FileAccess.file_exists(path):
		return
	base[path] = true
	for dep in ResourceLoader.get_dependencies(path):
		var p: String = dep.get_slice("::", 2) if dep.contains("::") else dep
		if p.begins_with("uid://"):
			p = ResourceUID.get_id_path(ResourceUID.text_to_id(p))
		_add(base, p)
	if path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres"):
		var src := FileAccess.get_file_as_string(path)
		var re := RegEx.create_from_string("\\b([A-Z][A-Za-z0-9_]+)\\b")
		var seen := {}
		for m in re.search_all(src):
			var name := m.get_string(1)
			if classes.has(name) and not seen.has(name):
				seen[name] = true
				_add(base, classes[name])
		# files the code preloads (needed as soon as the script is loaded)
		var re2 := RegEx.create_from_string("preload\\(\"(res://[^\"]+)\"")
		for m in re2.search_all(src):
			var p := m.get_string(1)
			if FileAccess.file_exists(p) and path.ends_with(".gd") and path != "res://games.gd":
				_add(base, p)
		# scripts named by path: `extends "res://..."` (needed to load the script at all)
		# and scripts loaded by path at runtime; the always-loaded helpers start before
		# any download is loaded, so they need theirs in the launcher
		var re3 := RegEx.create_from_string("\"(res://[^\"]+\\.gd)\"")
		for m in re3.search_all(src):
			var p := m.get_string(1)
			if FileAccess.file_exists(p) and path.ends_with(".gd") and path != "res://games.gd":
				_add(base, p)
