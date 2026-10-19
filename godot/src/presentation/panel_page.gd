class_name PanelPage
extends RefCounted

## Projects the approved 520x1040 panel pages into a responsive panel rect.
## Layer coordinates are the frozen editor values; UI only scales and centers.

const DESIGN := Vector2(520.0, 1040.0)

var pages: Dictionary = {}


func load_pages(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open panel pages: " + path)
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid panel pages JSON: " + path)
		return false
	pages = parsed.get("pages", {})
	return not pages.is_empty()


func page(page_name: String) -> Dictionary:
	return pages.get("panel-" + page_name, {})


func layers(page_name: String) -> Array:
	return page(page_name).get("layers", [])


func layer(page_name: String, id: String) -> Dictionary:
	for row in layers(page_name):
		if str(row.get("id", "")) == id:
			return row
	return {}


func asset(page_name: String, asset_id: String) -> Dictionary:
	for row in layers(page_name):
		if str(row.get("assetId", "")) == asset_id:
			return row
	return {}


func fit(rect: Rect2) -> Dictionary:
	# Keep the frozen page aspect ratio. The uncovered top/bottom area is
	# intentional and must not be filled with a flat color.
	var scale := minf(rect.size.x / DESIGN.x, rect.size.y / DESIGN.y)
	var page_size := DESIGN * scale
	return {
		"scale": scale,
		"origin": (rect.size - page_size) * 0.5,
		"size": page_size,
	}


func project(fit_value: Dictionary, row: Dictionary) -> Dictionary:
	var scale := float(fit_value["scale"])
	var origin: Vector2 = fit_value["origin"]
	var row_size := Vector2(float(row.get("width", 0.0)), float(row.get("height", 0.0)))
	var center := origin + Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0))) * scale
	return {
		"position": center - row_size * scale * 0.5,
		"size": row_size * scale,
		"rotation": float(row.get("rotation", 0.0)),
	}


func rect(fit_value: Dictionary, x: float, y: float, width: float, height: float) -> Rect2:
	var scale := float(fit_value["scale"])
	var origin: Vector2 = fit_value["origin"]
	return Rect2(origin + Vector2(x, y) * scale, Vector2(width, height) * scale)


func add_layer(parent: Node, fit_value: Dictionary, row: Dictionary, node_name: String = "") -> TextureRect:
	var projected := project(fit_value, row)
	var node := TextureRect.new()
	node.name = node_name if not node_name.is_empty() else "PageLayer_" + str(row.get("id", ""))
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = load("res://media/" + str(row.get("path", ""))) as Texture2D
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.position = projected["position"]
	node.size = projected["size"]
	node.pivot_offset = node.size * 0.5
	node.rotation_degrees = projected["rotation"]
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node


func add_page(parent: Node, fit_value: Dictionary, page_name: String, skip: Array = []) -> void:
	for row in layers(page_name):
		if skip.has(str(row.get("id", ""))):
			continue
		add_layer(parent, fit_value, row)
