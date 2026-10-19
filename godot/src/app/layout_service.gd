class_name LayoutService
extends RefCounted

## Pure layout geometry for the 1920x1080 design baseline.
## The interactive composition stays contained and centered; the backdrop
## covers the whole viewport so wide phones get extra scenery, not black bars.

const DESIGN_SIZE := Vector2(1920.0, 1080.0)


static func layout(viewport_size: Vector2, safe_rect: Rect2 = Rect2()) -> Dictionary:
	var size := Vector2(maxf(viewport_size.x, 1.0), maxf(viewport_size.y, 1.0))
	var fit_scale := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var cover_scale := maxf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var content_size := DESIGN_SIZE * fit_scale
	var background_size := DESIGN_SIZE * cover_scale
	var safe := safe_rect
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		safe = Rect2(Vector2.ZERO, size)
	return {
		"design": DESIGN_SIZE,
		"viewport": Rect2(Vector2.ZERO, size),
		"content": Rect2((size - content_size) * 0.5, content_size),
		"background": Rect2((size - background_size) * 0.5, background_size),
		"safe": safe,
		"fit_scale": fit_scale,
		"cover_scale": cover_scale,
		"portrait": size.x < size.y,
	}


static func current_safe_rect(viewport_size: Vector2) -> Rect2:
	# Desktop tests and Windows use the full client area. Android/iOS expose a
	# display safe area in physical pixels; convert it to the logical viewport.
	var platform := OS.get_name()
	if platform != "Android" and platform != "iOS":
		return Rect2(Vector2.ZERO, viewport_size)
	if not DisplayServer.has_method("get_display_safe_area"):
		return Rect2(Vector2.ZERO, viewport_size)
	var physical = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if physical.size.x <= 0 or physical.size.y <= 0 or window_size.x <= 0 or window_size.y <= 0:
		return Rect2(Vector2.ZERO, viewport_size)
	var sx := viewport_size.x / float(window_size.x)
	var sy := viewport_size.y / float(window_size.y)
	return Rect2(
		Vector2(physical.position.x * sx, physical.position.y * sy),
		Vector2(physical.size.x * sx, physical.size.y * sy)
	)


static func cover_rect(source_size: Vector2, viewport_size: Vector2, anchor_left: bool = false) -> Rect2:
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)
	var scale := maxf(viewport_size.x / source_size.x, viewport_size.y / source_size.y)
	var target := source_size * scale
	var position := Vector2.ZERO
	if anchor_left:
		position = Vector2(0.0, (viewport_size.y - target.y) * 0.5)
	else:
		position = (viewport_size - target) * 0.5
	return Rect2(position, target)


static func room_rect(viewport_size: Vector2) -> Dictionary:
	# The room keeps its original 1920x1080 composition. Wide screens get
	# side extensions from the room's own wall edge instead of a crop or bars.
	var layout := layout(viewport_size, Rect2(Vector2.ZERO, viewport_size))
	return {"rect": layout["content"], "scale": layout["fit_scale"]}


static func edge_rects(viewport_size: Vector2, room: Rect2) -> Dictionary:
	var left_width := maxf(0.0, room.position.x)
	var right_width := maxf(0.0, viewport_size.x - room.end.x)
	return {
		"left": Rect2(0.0, room.position.y, left_width, room.size.y),
		"right": Rect2(room.end.x, room.position.y, right_width, room.size.y),
	}


static func object_hotspots(manifest: Dictionary) -> Array:
	# Mirrors the home hotspot construction; tests compare this projection with
	# the actual controls and the manifest's rotated regions.
	var result: Array = []
	var layers: Array = manifest.get("layers", [])
	for object in manifest.get("objects", []):
		if bool(object.get("developerOnly", false)):
			continue
		var layer_index := int(object.get("layer", 1)) - 1
		if layer_index < 0 or layer_index >= layers.size():
			continue
		var row: Dictionary = layers[layer_index]
		var layer_center := Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0)))
		var layer_size := Vector2(float(row.get("width", 1.0)), float(row.get("height", 1.0)))
		var layer_rotation := float(row.get("rotation", 0.0))
		var angle := deg_to_rad(layer_rotation)
		var region_index := 0
		for region in object.get("regions", []):
			var min_touch := maxf(44.0, float(region.get("minTouch", object.get("minTouch", 44.0))))
			var region_size := Vector2(
				maxf(float(region.get("w", 0.0)) * layer_size.x, min_touch),
				maxf(float(region.get("h", 0.0)) * layer_size.y, min_touch)
			)
			var local := Vector2(
				(float(region.get("cx", 0.5)) - 0.5) * layer_size.x,
				(float(region.get("cy", 0.5)) - 0.5) * layer_size.y
			)
			var rotated := Vector2(
				local.x * cos(angle) - local.y * sin(angle),
				local.x * sin(angle) + local.y * cos(angle)
			)
			result.append({
				"object_id": str(object.get("id", "")),
				"region_index": region_index,
				"shape": str(region.get("kind", "rect")),
				"center": layer_center + rotated,
				"size": region_size,
				"rotation_degrees": layer_rotation + float(region.get("rotation", 0.0)),
			})
			region_index += 1
	return result
