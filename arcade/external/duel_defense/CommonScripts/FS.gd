extends Node

func list_files_in_directory(path):
	var files = []
	var dir = DirAccess.open(path)
	
	if dir == null and path.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(path)  # [Lab Arcade] nested folder: recursive; never in res://
		dir = DirAccess.open(path)
	if dir == null:
		return files
	
	dir.list_dir_begin()

	while true:
		var file = dir.get_next()
		if file == "":
			break
		elif not file.begins_with("."):
			files.append(file)

	dir.list_dir_end()
	
	files.sort()

	return files
	
func read_file(path):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return null
	var content = file.get_as_text()
	file.close()
	return content

func write_file(path, contents):
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())  # [Lab Arcade] its own folder may not exist yet
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
	
func write_file_buffer(path, contents):
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(contents)
	file.close()
	
func extract_zip(path, extract_path):
	var reader := ZIPReader.new()
	var err := reader.open(path)
	if err != OK:
		DdGodotLogger.error("extract zip error: %s" % err)
		return false
		
	for file in reader.get_files():
		DdGodotLogger.info("extract zip, extracting: %s" % file)
		write_file_buffer(extract_path + file, reader.read_file(file))
		
	reader.close()
	return true

func file_exists(path):
	return FileAccess.file_exists(path)
