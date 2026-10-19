class_name HomeHotspot
extends Control

## Invisible touch target. The primary region may be an ellipse, mirroring the
## Maker interaction map; a rectangular fallback keeps simple regions cheap.

signal activated(object_id: String)

var object_id := ""
var region_index := 0
var shape := "rect"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func _has_point(point: Vector2) -> bool:
	if shape == "ellipse":
		var radius := size * 0.5
		if radius.x <= 0.0 or radius.y <= 0.0:
			return false
		var offset := point - radius
		return pow(offset.x / radius.x, 2.0) + pow(offset.y / radius.y, 2.0) <= 1.0
	return Rect2(Vector2.ZERO, size).has_point(point)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			activated.emit(object_id)
			accept_event()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			activated.emit(object_id)
			accept_event()
