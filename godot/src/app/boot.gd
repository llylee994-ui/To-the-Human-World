extends Control

const LayoutService = preload("res://src/app/layout_service.gd")
const UiKit = preload("res://src/presentation/ui_kit.gd")


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	var viewport := get_viewport_rect().size
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture = load("res://media/image/loading-r1/harbor-small-v01.jpg") as Texture2D
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.position = Vector2.ZERO
	background.size = viewport
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	UiKit.label(
		self, "寄往人间", Vector2(0.0, viewport.y * 0.42), Vector2(viewport.x, 96.0),
		52, UiKit.CREAM, UiKit.medium(), HORIZONTAL_ALIGNMENT_CENTER, false, true
	)
	await get_tree().process_frame
	await get_tree().process_frame
	var target := "title"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--p0-screen="):
			target = argument.substr("--p0-screen=".length())
	if target != "title" and target != "home" and target != "brew":
		target = "title"
	get_tree().change_scene_to_file("res://scenes/%s.tscn" % target)
