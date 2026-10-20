class_name PackDownload
extends HTTPRequest
# Downloads one game pack into user://packs and installs it (see Packs).
# Emits finished(error) with "" on success.

signal finished(error: String)

var key := ""
var _part := ""


static func start(parent: Node, pack_key: String) -> PackDownload:
	var d := PackDownload.new()
	d.key = pack_key
	d.use_threads = true
	d.timeout = 120.0
	parent.add_child(d)
	d._go()
	return d


func _go() -> void:
	Packs.setup()
	_part = Packs.path_for(key) + ".part"
	download_file = _part
	request_completed.connect(_on_done)
	var err := request(Packs.URL + str(Packs.manifest[key]["file"]))
	if err != OK:
		_end("could not start the download")


## 0..1
func progress() -> float:
	var total := float(Packs.size_of(key))
	return clampf(get_downloaded_bytes() / total, 0.0, 1.0) if total > 0 else 0.0


func _on_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != RESULT_SUCCESS:
		_end("no internet connection?" if result in [RESULT_CANT_CONNECT, RESULT_CANT_RESOLVE, RESULT_CONNECTION_ERROR, RESULT_TLS_HANDSHAKE_ERROR] else "download failed (%d)" % result)
		return
	if code == 404:
		_end("this game isn't online for this app version: update Lab Arcade")
		return
	if code != 200:
		_end("download failed (server said %d)" % code)
		return
	_end(Packs.install_file(key, _part))


func cancel() -> void:
	cancel_request()
	_end("cancelled")


func _end(error: String) -> void:
	if error != "" and FileAccess.file_exists(_part):
		DirAccess.remove_absolute(_part)
	finished.emit(error)
	queue_free()
