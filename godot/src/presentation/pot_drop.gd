class_name PotDrop
extends Control

## Invisible presentation-only drop target. Receiving a word never alters inventory.
signal dropped(token_id: String)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and str(data.get("kind", "")) == "word" \
		and not str(data.get("token_id", "")).is_empty()

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	var source = data.get("source", null)
	if is_instance_valid(source) and source.has_method("mark_dropped"):
		source.mark_dropped()
	dropped.emit(str(data["token_id"]))
