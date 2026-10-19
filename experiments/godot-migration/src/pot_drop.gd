extends TextureRect

signal item_dropped(kind: String, item_id: String)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("kind") in ["word", "ingredient"] and data.get("id") is String

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	item_dropped.emit(data.kind, data.id)
