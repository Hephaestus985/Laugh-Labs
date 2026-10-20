class_name SafeResource
extends RefCounted
# Loading a Godot resource (.tres) runs any script inside it, so a save file in the
# writable user:// folder that someone swapped could run code. Games by others that
# save as resources load their saves through here: the file must be a plain text
# resource whose scripts and other files all come from the game's own folder, with
# no scripts written inside it and no raw objects.

static func is_safe(path: String, allowed_prefix: String) -> bool:
	if not path.begins_with("user://") or not path.ends_with(".tres") or not FileAccess.file_exists(path):
		return false
	var t := FileAccess.get_file_as_string(path)
	if not t.begins_with("[gd_resource"):
		return false
	for bad in ['type="GDScript"', 'type="CSharpScript"', "script/source", "Object(", "Callable(", "user://"]:
		if t.contains(bad):
			return false
	var re := RegEx.create_from_string('path="([^"]*)"')
	for m in re.search_all(t):
		var p := m.get_string(1)
		if not p.begins_with(allowed_prefix) or p.contains(".."):
			return false
	return true


## Loads the resource when it passes is_safe(), else returns null (like a missing save).
static func load_user(path: String, allowed_prefix: String) -> Resource:
	if not is_safe(path, allowed_prefix):
		if FileAccess.file_exists(path):
			print("Ignored a save file that doesn't look like this game's own: " + path)
		return null
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
