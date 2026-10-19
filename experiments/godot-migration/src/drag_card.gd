extends Button

var kind := ""
var item_id := ""

func _get_drag_data(_at_position: Vector2) -> Variant:
	if disabled:
		return null
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 34)
	preview.add_theme_color_override("font_color", Color("f8e9c4"))
	preview.add_theme_color_override("font_shadow_color", Color("24190f"))
	preview.add_theme_constant_override("shadow_outline_size", 5)
	set_drag_preview(preview)
	return {"kind": kind, "id": item_id}
