extends Node

## Development-only P0 evidence hook. It is inert unless --p0-capture=<path>
## is passed after the engine argument separator. The normal game path never
## calls this and no player-facing control is added.

func _ready() -> void:
	var path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--p0-capture="):
			path = argument.substr("--p0-capture=".length())
	if path.is_empty():
		return
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	print("[P0Capture] path=%s error=%s size=%s" % [path, str(error), str(image.get_size())])
	get_tree().quit(0 if error == OK else 1)
