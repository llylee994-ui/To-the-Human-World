extends Control

const LayoutService = preload("res://src/app/layout_service.gd")
const UiKit = preload("res://src/presentation/ui_kit.gd")

var _building := false
var safe_override := Rect2()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	get_viewport().size_changed.connect(_rebuild)
	call_deferred("_rebuild")


func _rebuild() -> void:
	if _building:
		return
	_building = true
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var viewport := get_viewport_rect().size
	var safe := _safe_rect(viewport)
	var layout := LayoutService.layout(viewport, safe)
	var cover := LayoutService.cover_rect(Vector2(1672.0, 941.0), viewport, true)
	var background := TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.texture = load("res://media/image/title-screen-r1/shop-doorway-soft.png") as Texture2D
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.position = cover.position
	background.size = cover.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var sw := maxf(safe.size.x, 1.0)
	var sh := maxf(safe.size.y, 1.0)
	var compact := sh < 540.0
	var column_width := minf(520.0, sw * 0.38)
	var left := safe.position.x + sw * 0.085
	var top := safe.position.y + sh * (0.12 if compact else 0.17)

	# A soft left wash keeps the cream lettering readable over the door frame.
	var wash := ColorRect.new()
	wash.color = Color(0.06, 0.045, 0.03, 0.34)
	wash.position = Vector2(0.0, 0.0)
	wash.size = Vector2(left + column_width + 40.0, viewport.y)
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)

	UiKit.label(self, "寄往人间", Vector2(left, top), Vector2(column_width, 130.0),
		int(minf(68.0, column_width * 0.165)), UiKit.CREAM, UiKit.medium(), HORIZONTAL_ALIGNMENT_LEFT,
		false, true)
	UiKit.label(self, "TO THE HUMAN WORLD", Vector2(left, top + 122.0), Vector2(column_width, 30.0),
		13, UiKit.MUTED, UiKit.regular(), HORIZONTAL_ALIGNMENT_LEFT, false, true)
	UiKit.label(self, "海边魔药铺", Vector2(left, top + 160.0), Vector2(column_width, 32.0),
		18, UiKit.CREAM, UiKit.regular(), HORIZONTAL_ALIGNMENT_LEFT, false, true)

	var button_y := top + (214.0 if compact else 240.0)
	var start := UiKit.text_button(self, "开始游戏", Vector2(left, button_y), Vector2(column_width, 54.0),
		_start_game, true, false)
	start.name = "StartGame"
	var continue_button := UiKit.text_button(self, "继续游戏（P1 接入）", Vector2(left, button_y + 68.0),
		Vector2(column_width, 52.0), _noop, false, true)
	continue_button.name = "ContinueGame"
	var rewind := UiKit.text_button(self, "进度回溯（P1 接入）", Vector2(left, button_y + 126.0),
		Vector2(column_width, 52.0), _noop, false, true)
	rewind.name = "OpenRewind"
	UiKit.label(self, "P0 视觉基线 · 正式玩法尚未迁移", Vector2(left, safe.position.y + sh - 48.0),
		Vector2(column_width + 120.0, 30.0), 15, UiKit.MUTED, UiKit.regular(),
		HORIZONTAL_ALIGNMENT_LEFT, false, true)

	if bool(layout["portrait"]):
		UiKit.portrait_guard(self, viewport)
	_building = false


func _safe_rect(viewport: Vector2) -> Rect2:
	if safe_override.size.x > 0.0 and safe_override.size.y > 0.0:
		return safe_override
	return LayoutService.current_safe_rect(viewport)


func _start_game() -> void:
	get_tree().change_scene_to_file("res://scenes/home.tscn")


func _noop() -> void:
	pass
