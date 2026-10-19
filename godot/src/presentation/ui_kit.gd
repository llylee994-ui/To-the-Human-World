class_name UiKit
extends RefCounted

## Shared P0 chrome. These are deliberately simple flat styles; the approved
## art remains in the textures and is not replaced by code-drawn decoration.

const FONT_REGULAR := "res://media/fonts/HarborHand-Regular.ttf"
const FONT_MEDIUM := "res://media/fonts/HarborHand-Medium.ttf"
const PAPER := "res://media/image/界面_柔边纸面_透明_v01_20261013070534.png"
const WOOD := "res://media/image/界面_深木牌_透明_v01_20261013070534.png"
const STRIP := "res://media/image/界面_纸条_折痕_透明_v01.png"
const BUTTON_SKINS := "res://media/image/story-result/button-skins-v01.png"

const INK := Color("493321")
const CREAM := Color("f7e8c6")
const MUTED := Color("d8c19a")
const DARK := Color("2b241d")
const GOLD := Color("c59c61")
const NAVY := Color("1f303c")
const FONT_BOOST := 1.8


static func scaled_font_size(base_size: int) -> int:
	return int(round(float(base_size) * FONT_BOOST))


static func regular() -> Font:
	return load(FONT_REGULAR) as Font


static func medium() -> Font:
	return load(FONT_MEDIUM) as Font


static func style_box(background: Color, border: Color, width: int = 1, radius: int = 6,
		margin: int = 6) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_top = margin
	style.content_margin_bottom = margin
	return style


static func label(parent: Node, text: String, position_value: Vector2, size_value: Vector2,
		font_size: int, color: Color = INK, font: Font = null, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT,
		wrap: bool = false, shadow: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.position = position_value
	node.size = size_value
	node.custom_minimum_size = size_value
	node.horizontal_alignment = alignment
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = regular()
	if font != null:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", int(round(float(font_size) * FONT_BOOST)))
	node.add_theme_color_override("font_color", color)
	if shadow:
		node.add_theme_color_override("font_shadow_color", Color(0.03, 0.02, 0.01, 0.72))
		node.add_theme_constant_override("shadow_offset_x", 2)
		node.add_theme_constant_override("shadow_offset_y", 3)
		node.add_theme_constant_override("shadow_outline_size", 5)
	parent.add_child(node)
	return node


static func _texture_style(texture_path: String, region: Rect2, tint: Color) -> StyleBoxTexture:
	var source := load(texture_path) as Texture2D
	var style := StyleBoxTexture.new()
	if source != null:
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = region
		style.texture = atlas
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.modulate_color = tint
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


static func _wood_style(tint: Color) -> StyleBoxTexture:
	var source := load(WOOD) as Texture2D
	if source == null:
		return null
	var size := source.get_size()
	return _texture_style(WOOD, Rect2(0.0, size.y * 0.21, size.x, size.y * 0.13), tint)


static func button(parent: Node, text: String, position_value: Vector2, size_value: Vector2,
		callback: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = position_value
	node.size = size_value
	node.custom_minimum_size = size_value
	node.focus_mode = Control.FOCUS_NONE
	var font := regular()
	if font != null:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size",
		scaled_font_size(26 if primary else 24))
	node.add_theme_color_override("font_color", CREAM if primary else Color("fff4da"))
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color.WHITE)
	node.add_theme_color_override("font_disabled_color", Color("b9a887"))
	if primary:
		var primary_region := Rect2(33.0, 150.0, 1470.0, 290.0)
		node.add_theme_stylebox_override("normal", _texture_style(BUTTON_SKINS, primary_region, Color.WHITE))
		node.add_theme_stylebox_override("hover", _texture_style(BUTTON_SKINS, primary_region, Color(1.08, 1.06, 1.02)))
		node.add_theme_stylebox_override("pressed", _texture_style(BUTTON_SKINS, primary_region, Color(0.82, 0.80, 0.76)))
		node.add_theme_stylebox_override("disabled", _texture_style(BUTTON_SKINS, primary_region, Color(0.46, 0.45, 0.43, 0.85)))
	else:
		var normal := _wood_style(Color.WHITE)
		var hover := _wood_style(Color(1.0, 0.94, 0.84))
		var pressed := _wood_style(Color(0.82, 0.78, 0.72))
		var disabled := _wood_style(Color(0.55, 0.52, 0.48, 0.8))
		if normal != null:
			node.add_theme_stylebox_override("normal", normal)
			node.add_theme_stylebox_override("hover", hover)
			node.add_theme_stylebox_override("pressed", pressed)
			node.add_theme_stylebox_override("disabled", disabled)
		else:
			node.add_theme_stylebox_override("normal", style_box(DARK, GOLD, 2, 6, 8))
			node.add_theme_stylebox_override("hover", style_box(DARK.lightened(0.14), GOLD, 2, 6, 8))
			node.add_theme_stylebox_override("pressed", style_box(DARK.darkened(0.14), GOLD, 2, 6, 8))
			node.add_theme_stylebox_override("disabled", style_box(Color("3a332b"), Color("6f5c43"), 1, 6, 8))
	node.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	node.pressed.connect(callback)
	parent.add_child(node)
	return node


static func text_button(parent: Node, text: String, position_value: Vector2, size_value: Vector2,
		callback: Callable, primary: bool = false, disabled: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = position_value
	node.size = size_value
	node.custom_minimum_size = size_value
	node.focus_mode = Control.FOCUS_NONE
	node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var font := medium() if primary else regular()
	if font != null:
		node.add_theme_font_override("font", font)
	node.add_theme_font_size_override("font_size", int(round(24.0 * FONT_BOOST)))
	node.add_theme_color_override("font_color", CREAM)
	node.add_theme_color_override("font_hover_color", Color.WHITE)
	node.add_theme_color_override("font_pressed_color", Color("ffe7ad"))
	node.add_theme_color_override("font_disabled_color", Color("a99a82"))
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 36
	empty.content_margin_right = 8
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		node.add_theme_stylebox_override(state, empty)
	node.pressed.connect(callback)
	node.disabled = disabled
	parent.add_child(node)
	if primary:
		var diamond := Panel.new()
		diamond.name = "TextButtonDiamond"
		diamond.position = Vector2(10.0, size_value.y * 0.5 - 6.0)
		diamond.size = Vector2(12.0, 12.0)
		diamond.rotation_degrees = 45.0
		diamond.mouse_filter = Control.MOUSE_FILTER_IGNORE
		diamond.add_theme_stylebox_override("panel",
			style_box(Color("d8b05e"), Color("f5e3b6"), 1, 1, 0))
		node.add_child(diamond)
		var underline := ColorRect.new()
		underline.name = "TextButtonUnderline"
		underline.color = Color(0.80, 0.64, 0.38, 0.72)
		underline.position = Vector2(36.0, size_value.y - 8.0)
		underline.size = Vector2(maxf(0.0, size_value.x - 36.0), 1.0)
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.add_child(underline)
	return node


static func tag(parent: Node, text: String, position_value: Vector2, size_value: Vector2,
		font_size: int = 14) -> Label:
	var node := label(parent, text, position_value, size_value, font_size, CREAM, regular())
	node.add_theme_stylebox_override("normal", style_box(Color(0.15, 0.11, 0.08, 0.78), Color(0.0, 0.0, 0.0, 0.0), 0, 8, 6))
	return node


static func ledger_tag(parent: Node, text: String, position_value: Vector2, size_value: Vector2) -> Label:
	var node := label(parent, text, position_value, size_value, 18, INK, regular())
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_theme_stylebox_override("normal", style_box(Color("efe0bf"), GOLD, 1, 6, 6))
	return node


static func portrait_guard(parent: Node, viewport_size: Vector2) -> Control:
	var overlay := ColorRect.new()
	overlay.name = "PortraitGuard"
	overlay.color = Color(0.08, 0.06, 0.05, 0.94)
	overlay.position = Vector2.ZERO
	overlay.size = viewport_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(overlay)
	var box := UiKit.tag(overlay, "横过手机，走进小屋", Vector2.ZERO, Vector2(viewport_size.x, 64), 20)
	box.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.position = Vector2(0, viewport_size.y * 0.5 - 32)
	box.size = Vector2(viewport_size.x, 64)
	return overlay
