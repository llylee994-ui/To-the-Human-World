extends Control

const LayoutService = preload("res://src/app/layout_service.gd")
const HomeLayersScript = preload("res://src/presentation/home_layers.gd")
const HomeHotspotScript = preload("res://src/presentation/home_hotspot.gd")
const UiKit = preload("res://src/presentation/ui_kit.gd")

var _layers: HomeLayers
var _toast: Label
var _toast_timer := 0.0
const HOME_FOREGROUND := "res://media/image/misty-harbor-r1/home-foreground.png"

var _building := false
var safe_override := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	get_viewport().size_changed.connect(_rebuild)
	call_deferred("_rebuild")


func _process(delta: float) -> void:
	if _toast != null and _toast_timer > 0.0:
		_toast_timer = maxf(0.0, _toast_timer - delta)
		if _toast_timer <= 0.0:
			_toast.visible = false


func _rebuild() -> void:
	if _building:
		return
	_building = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_layers = null
	_toast = null
	var viewport := get_viewport_rect().size
	var safe := _safe_rect(viewport)
	var layout := LayoutService.layout(viewport, safe)
	var room := LayoutService.room_rect(viewport)
	var room_rect: Rect2 = room["rect"]

	var sea := TextureRect.new()
	sea.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sea.texture = load("res://media/image/misty-harbor-r1/sea-calm.png") as Texture2D
	sea.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sea.position = Vector2.ZERO
	sea.size = viewport
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sea)
	_add_edge_extensions(viewport, room_rect)

	_layers = HomeLayersScript.new()
	if not _layers.load_manifest("res://media/home-layout.json"):
		_building = false
		return
	_layers.hidden_keys = ["case-file"]
	_layers.backdrop_path = "res://media/image/misty-harbor-r1/sea-calm.png"
	_layers.backdrop_rect = Rect2(0.0, -115.0, 1920.0, 1080.0)
	_layers.build()
	_layers.apply_room(room)
	add_child(_layers)
	_add_hotspots()
	_add_hud(safe)
	_add_toast(safe)

	if bool(layout["portrait"]):
		UiKit.portrait_guard(self, viewport)
	_building = false


func _safe_rect(viewport: Vector2) -> Rect2:
	if safe_override.size.x > 0.0 and safe_override.size.y > 0.0:
		return safe_override
	return LayoutService.current_safe_rect(viewport)


func _add_edge_extensions(viewport: Vector2, room: Rect2) -> void:
	var source := load(HOME_FOREGROUND) as Texture2D
	if source == null:
		return
	var source_size := source.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return
	var edges := LayoutService.edge_rects(viewport, room)
	# Use a low-detail wall band rather than the room's extreme edge, which
	# contains bags, shelves and flowers that would visibly duplicate.
	var strip_width := maxf(24.0, source_size.x * 0.02)
	var strip_start := source_size.x * 0.10
	var region := Rect2(strip_start, 0.0, strip_width, source_size.y)
	_add_edge_strip(edges["left"], source, region, "HomeEdgeLeft", false, true)
	_add_edge_strip(edges["right"], source, region, "HomeEdgeRight", true, false)


func _add_edge_strip(rect: Rect2, source: Texture2D, region: Rect2, node_name: String,
		flip: bool, shade_outer_left: bool) -> void:
	if rect.size.x <= 0.5:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = source
	atlas.region = region
	var strip := TextureRect.new()
	strip.name = node_name
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.texture = atlas
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.flip_h = flip
	strip.position = rect.position
	strip.size = rect.size
	strip.modulate = Color(0.90, 0.86, 0.80, 1.0)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(strip)
	var gradient := Gradient.new()
	if shade_outer_left:
		gradient.set_color(0, Color(0.02, 0.012, 0.008, 0.48))
		gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	else:
		gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.0))
		gradient.set_color(1, Color(0.02, 0.012, 0.008, 0.48))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var shade := TextureRect.new()
	shade.name = node_name + "Shade"
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.texture = texture
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = rect.position
	shade.size = rect.size
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)


func _add_hotspots() -> void:
	for spot in LayoutService.object_hotspots(_layers.manifest):
		var center: Vector2 = spot["center"]
		var spot_size: Vector2 = spot["size"]
		var hotspot := HomeHotspotScript.new()
		hotspot.object_id = str(spot["object_id"])
		hotspot.region_index = int(spot["region_index"])
		hotspot.shape = str(spot["shape"])
		hotspot.size = spot_size
		hotspot.custom_minimum_size = spot_size
		hotspot.position = center - spot_size * 0.5
		hotspot.pivot_offset = spot_size * 0.5
		hotspot.rotation_degrees = float(spot["rotation_degrees"])
		hotspot.activated.connect(_on_object)
		_layers.add_child(hotspot)


func _add_hud(safe: Rect2) -> void:
	var ledger := UiKit.ledger_tag(self, "金币 30 · 第 1 天",
		Vector2(safe.position.x + 8.0, safe.position.y + 8.0), Vector2(320.0, 48.0))
	ledger.name = "LedgerTag"
	var back_width := 240.0
	var back := UiKit.button(self, "返回首页",
		Vector2(safe.position.x + safe.size.x - back_width - 8.0, safe.position.y + 8.0),
		Vector2(back_width, 76.0), _go_title)
	back.name = "HomeBack"
	var hint := UiKit.tag(self, "点物件，看看有什么",
		Vector2(safe.position.x + 12.0, safe.position.y + safe.size.y - 58.0), Vector2(340.0, 46.0), 15)
	hint.name = "HomeHint"


func _add_toast(safe: Rect2) -> void:
	_toast = UiKit.tag(self, "", Vector2(safe.position.x + 12.0, safe.position.y + safe.size.y - 116.0),
		Vector2(minf(720.0, safe.size.x - 24.0), 56.0), 15)
	_toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast.visible = false


func _on_object(object_id: String) -> void:
	var row := _object_row(object_id)
	var target := str(row.get("target", ""))
	var label := str(row.get("label", object_id))
	if target == "brew":
		get_tree().change_scene_to_file("res://scenes/brew.tscn")
		return
	_show_toast("「" + label + "」在 P2 接入；当前是 P0 视觉基线。")


func _object_row(object_id: String) -> Dictionary:
	for row in _layers.manifest.get("objects", []):
		if str(row.get("id", "")) == object_id:
			return row
	return {}


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	_toast_timer = 2.8


func _go_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
