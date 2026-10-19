class_name PaperPanel
extends Control

const UiKit = preload("res://src/presentation/ui_kit.gd")

## Reusable paper surface. The caller owns the outer rect; children are placed
## in the inner content Control, already inset by the requested margin.

var content: Control
var _background: TextureRect
var _margin: MarginContainer


func configure(texture_path: String, margin_value: int = 24) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_background = TextureRect.new()
	_background.name = "PaperBackground"
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.texture = load(texture_path) as Texture2D
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)
	_margin = MarginContainer.new()
	_margin.name = "PaperMargin"
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin.add_theme_constant_override("margin_left", margin_value)
	_margin.add_theme_constant_override("margin_right", margin_value)
	_margin.add_theme_constant_override("margin_top", margin_value)
	_margin.add_theme_constant_override("margin_bottom", margin_value)
	add_child(_margin)
	content = Control.new()
	content.name = "PaperContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	_margin.add_child(content)
	mouse_filter = Control.MOUSE_FILTER_PASS


func add_label(text: String, position_value: Vector2, size_value: Vector2, font_size: int,
		color: Color, font: Font, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position_value
	label.size = size_value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", int(round(float(font_size) * UiKit.FONT_BOOST)))
	label.add_theme_color_override("font_color", color)
	content.add_child(label)
	return label
