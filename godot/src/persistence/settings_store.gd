class_name SettingsStore
extends RefCounted

## Small independent settings file. It is deliberately not part of the
## business snapshot: restarting a journey must not reset audio preferences.


const DEFAULT_PATH := "user://settings.json"
var path: String


func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path


func load_settings() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return (parsed as Dictionary).duplicate(true)


func save_settings(settings: Dictionary) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	var written := file.store_string(SaveCodec.encode(settings))
	file.flush()
	var error := file.get_error()
	file.close()
	if not written or error != OK:
		return false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),
		ProjectSettings.globalize_path(path)) == OK
