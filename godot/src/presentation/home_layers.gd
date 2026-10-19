class_name HomeLayers
extends Control

## Draws the approved home layer snapshot in design coordinates.
## TextureRect.expand_mode is set before the texture and size on purpose:
## the texture's minimum size must never clamp the manifest target size.

const DESIGN_SIZE := Vector2(1920.0, 1080.0)

var manifest: Dictionary = {}
var hidden_keys: Array[String] = []
var layer_nodes: Dictionary = {}
var backdrop_path := ""
var backdrop_rect := Rect2()
var backdrop_node: TextureRect


func load_manifest(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open home layout: " + path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid home layout JSON: " + path)
		return false
	manifest = parsed
	return true


func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	layer_nodes.clear()
	name = "HomeLayers"
	size = DESIGN_SIZE
	custom_minimum_size = DESIGN_SIZE
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_node = null
	if not backdrop_path.is_empty():
		var backdrop := TextureRect.new()
		backdrop.name = "HomeSeaBackdrop"
		backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop.texture = load(backdrop_path) as Texture2D
		backdrop.stretch_mode = TextureRect.STRETCH_SCALE
		backdrop.position = backdrop_rect.position
		backdrop.size = backdrop_rect.size
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backdrop)
		backdrop_node = backdrop
	var rows: Array = manifest.get("layers", [])
	for row in rows:
		if not bool(row.get("visible", true)):
			continue
		var key := str(row.get("key", ""))
		if hidden_keys.has(key):
			continue
		var path := str(row.get("path", ""))
		var texture := load("res://media/" + path) as Texture2D
		if texture == null:
			push_error("Missing home layer: " + path)
			continue
		var target_size := Vector2(float(row.get("width", 0.0)), float(row.get("height", 0.0)))
		var node := TextureRect.new()
		node.name = "Layer_" + key
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_SCALE
		node.texture = texture
		node.size = target_size
		node.position = Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0))) - target_size * 0.5
		node.pivot_offset = target_size * 0.5
		node.rotation_degrees = float(row.get("rotation", 0.0))
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(node)
		layer_nodes[key] = node


func apply_layout(layout: Dictionary) -> void:
	var content: Rect2 = layout["content"]
	position = content.position
	scale = Vector2.ONE * float(layout["fit_scale"])
	size = DESIGN_SIZE


func apply_room(room: Dictionary) -> void:
	var rect: Rect2 = room["rect"]
	position = rect.position
	scale = Vector2.ONE * float(room["scale"])
	size = DESIGN_SIZE


func set_zoom_transform(zoom: float, origin: Vector2) -> void:
	scale = Vector2.ONE * zoom
	position = origin


func layer_node(key: String) -> TextureRect:
	return layer_nodes.get(key, null)


func layer_size(key: String) -> Vector2:
	var node: TextureRect = layer_nodes.get(key, null)
	return node.size if node != null else Vector2.ZERO


func layer_center(key: String) -> Vector2:
	var node: TextureRect = layer_nodes.get(key, null)
	return node.position + node.size * 0.5 if node != null else Vector2.ZERO
