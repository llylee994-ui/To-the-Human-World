class_name WordSlip
extends Control

## A word strip whose paper follows the measured text. Long words wrap at the
## supplied maximum width instead of shrinking the font; token_id remains the
## identity even when two strips show the same text.

signal selected(slip: WordSlip)
signal drag_cancelled(slip: WordSlip)

const UiKit = preload("res://src/presentation/ui_kit.gd")
const PAPER_PATH := "res://media/image/界面_纸条_折痕_透明_v01.png"
const FONT_PATH := "res://media/fonts/HarborHand-Regular.ttf"

var token_id := ""
var display_text := ""
var font_size := 18
var base_font_size := 18
var line_count := 0
var font: Font
var _background: TextureRect
var _label: Label
var _selected := false
var _drag_started := false
var _drop_committed := false


func _ensure_nodes() -> void:
	if _background != null:
		return
	font = load(FONT_PATH) as Font
	if font == null:
		font = ThemeDB.fallback_font
	_background = TextureRect.new()
	_background.name = "SlipPaper"
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.texture = load(PAPER_PATH) as Texture2D
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)
	_label = Label.new()
	_label.name = "SlipText"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color("493321"))
	if font != null:
		_label.add_theme_font_override("font", font)
	add_child(_label)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func configure(value: String, token: String = "", max_width: float = 300.0, font_size: int = 18) -> void:
	_ensure_nodes()
	token_id = token
	display_text = value
	base_font_size = font_size
	font_size = UiKit.scaled_font_size(font_size)
	self.font_size = font_size
	var padding_x := 8.0
	var padding_y := 4.0
	var inner := maxf(1.0, max_width - padding_x * 2.0)
	var lines := _wrap(value, inner, font_size)
	var longest := 0.0
	for line in lines:
		longest = maxf(longest, _measure(line, font_size))
	var width := clampf(longest + padding_x * 2.0, 32.0, max_width)
	var line_height := font.get_height(font_size) * 1.05
	var height := maxf(line_height * float(lines.size()) + padding_y * 2.0, 34.0)
	size = Vector2(width, height)
	custom_minimum_size = size
	_background.size = size
	_background.position = Vector2.ZERO
	_label.text = "\n".join(lines)
	_label.position = Vector2(padding_x, padding_y)
	_label.size = Vector2(width - padding_x * 2.0, height - padding_y * 2.0)
	_label.add_theme_font_size_override("font_size", font_size)
	line_count = lines.size()
	set_selected(_selected)


func set_selected(value: bool) -> void:
	_selected = value
	modulate = Color("ffe3a1") if value else Color.WHITE


func _measure(value: String, font_size: int) -> float:
	if font == null or value.is_empty():
		return 0.0
	return font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _wrap(value: String, inner: float, font_size: int) -> PackedStringArray:
	var lines := PackedStringArray()
	var current := ""
	for index in value.length():
		var character := value.substr(index, 1)
		if character == "\n":
			lines.append(current)
			current = ""
			continue
		var candidate := current + character
		if not current.is_empty() and _measure(candidate, font_size) > inner:
			lines.append(current)
			current = character
		else:
			current = candidate
	lines.append(current)
	return lines


func _gui_input(event: InputEvent) -> void:
	# Do not consume the press: the viewport needs it to begin a drag after
	# the movement threshold. A plain click still emits selected.
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			selected.emit(self)
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			selected.emit(self)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if token_id.is_empty():
		return null
	_drag_started = true
	_drop_committed = false
	var preview := WordSlip.new()
	preview.configure(display_text, token_id, size.x, base_font_size)
	preview.modulate = Color(1.0, 1.0, 1.0, 0.92)
	set_drag_preview(preview)
	return {
		"kind": "word",
		"token_id": token_id,
		"text": display_text,
		"source": self,
	}


func mark_dropped() -> void:
	_drop_committed = true


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		# Godot broadcasts this notification to other controls too; only the
		# slip that produced the drag may report cancellation.
		if _drag_started and not _drop_committed:
			drag_cancelled.emit(self)
		_drag_started = false
		_drop_committed = false
