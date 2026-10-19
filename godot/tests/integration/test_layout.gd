extends RefCounted

const LayoutService = preload("res://src/app/layout_service.gd")
const HomeLayersScript = preload("res://src/presentation/home_layers.gd")
const WordSlipScript = preload("res://src/presentation/word_slip.gd")
const PotDropScript = preload("res://src/presentation/pot_drop.gd")

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func _rect_array(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


func _expected_hotspots(manifest: Dictionary) -> Array:
	# Independent projection used to check both LayoutService and the controls.
	var expected: Array = []
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
			expected.append({
				"object_id": str(object.get("id", "")),
				"region_index": region_index,
				"shape": str(region.get("kind", "rect")),
				"center": layer_center + rotated,
				"size": region_size,
				"rotation": layer_rotation + float(region.get("rotation", 0.0)),
			})
			region_index += 1
	return expected


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	var report := {
		"generated_at": Time.get_datetime_string_from_system(),
		"sizes": [],
	}
	var sizes := [
		Vector2(1920.0, 1080.0),
		Vector2(2340.0, 1080.0),
		Vector2(2400.0, 1080.0),
		Vector2(2412.0, 1080.0),
	]
	for size in sizes:
		var layout := LayoutService.layout(size, Rect2(Vector2.ZERO, size))
		var content: Rect2 = layout["content"]
		var background: Rect2 = layout["background"]
		var room := LayoutService.room_rect(size)
		var room_rect: Rect2 = room["rect"]
		_check(failures, is_equal_approx(content.size.y, 1080.0),
			"content height at %s" % str(size))
		_check(failures, content.position.x >= -0.01 and content.end.x <= size.x + 0.01,
			"content stays inside viewport at %s" % str(size))
		_check(failures, background.position.x <= 0.01 and background.position.y <= 0.01
			and background.end.x >= size.x - 0.01 and background.end.y >= size.y - 0.01,
			"background covers viewport at %s" % str(size))
		var edges := LayoutService.edge_rects(size, room_rect)
		var left_edge: Rect2 = edges["left"]
		var right_edge: Rect2 = edges["right"]
		if size.x / size.y >= 1920.0 / 1080.0:
			_check(failures, is_equal_approx(room_rect.size.x, 1920.0)
				and is_equal_approx(room_rect.size.y, 1080.0),
				"wide room keeps 1920x1080 composition at %s" % str(size))
			_check(failures, is_equal_approx(room_rect.position.x, (size.x - 1920.0) * 0.5),
				"wide room stays centered at %s" % str(size))
			_check(failures, is_equal_approx(left_edge.size.x, room_rect.position.x)
				and is_equal_approx(right_edge.size.x, size.x - room_rect.end.x),
				"edge extension covers both side margins at %s" % str(size))
			_check(failures, is_equal_approx(left_edge.position.x, 0.0)
				and is_equal_approx(right_edge.end.x, size.x),
				"edge extension reaches the viewport edges at %s" % str(size))
			_check(failures, is_equal_approx(left_edge.size.y, 1080.0)
				and is_equal_approx(right_edge.size.y, 1080.0),
				"edge extension keeps room height at %s" % str(size))
		report["sizes"].append({
			"viewport": [size.x, size.y],
			"content": _rect_array(content),
			"background": _rect_array(background),
			"room": _rect_array(room_rect),
			"edges": {"left": _rect_array(left_edge), "right": _rect_array(right_edge)},
			"portrait": bool(layout["portrait"]),
		})

	var safe := Rect2(60.0, 0.0, 2412.0 - 120.0, 1080.0)
	var safe_layout := LayoutService.layout(Vector2(2412.0, 1080.0), safe)
	_check(failures, safe_layout["safe"] == safe, "safe rect is passed through")
	var portrait := LayoutService.layout(Vector2(1080.0, 1920.0), Rect2(0.0, 0.0, 1080.0, 1920.0))
	_check(failures, bool(portrait["portrait"]), "portrait is detected")

	var home := HomeLayersScript.new()
	_check(failures, home.load_manifest("res://media/home-layout.json"), "home layout loads")
	home.hidden_keys = ["case-file"]
	home.backdrop_path = "res://media/image/misty-harbor-r1/sea-calm.png"
	home.backdrop_rect = Rect2(0.0, -115.0, 1920.0, 1080.0)
	home.build()
	tree.root.add_child(home)
	home.apply_room(LayoutService.room_rect(Vector2(1920.0, 1080.0)))
	await tree.process_frame
	_check(failures, home.backdrop_node != null, "home sea backdrop exists")
	if home.backdrop_node != null:
		_check(failures, home.get_child(0) == home.backdrop_node, "sea backdrop is behind room layers")
		_check(failures, home.backdrop_node.position.is_equal_approx(Vector2(0.0, -115.0))
			and home.backdrop_node.size.is_equal_approx(Vector2(1920.0, 1080.0)),
			"sea backdrop keeps the design offset")

	var layers: Array = home.manifest.get("layers", [])
	for row in layers:
		var key := str(row.get("key", ""))
		if home.hidden_keys.has(key) or not bool(row.get("visible", true)):
			continue
		var expected_size := Vector2(float(row.get("width", 0.0)), float(row.get("height", 0.0)))
		var expected_position := Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0))) - expected_size * 0.5
		var node := home.layer_node(key)
		_check(failures, node != null, "layer exists: " + key)
		if node != null:
			_check(failures, node.size.is_equal_approx(expected_size), "layer %s keeps manifest size" % key)
			_check(failures, node.position.is_equal_approx(expected_position), "layer %s keeps manifest position" % key)
			_check(failures, is_equal_approx(node.rotation_degrees, float(row.get("rotation", 0.0))),
				"layer %s keeps manifest rotation" % key)
	_check(failures, home.layer_size("net") != Vector2(1024.0, 1536.0),
		"net must not use native texture size")
	_check(failures, home.layer_size("merchant-ship") != Vector2(1319.0, 1192.0),
		"merchant ship must not use native texture size")
	_check(failures, home.layer_size("stove") != Vector2(1313.0, 1198.0),
		"stove must not use native texture size")

	var expected_spots := _expected_hotspots(home.manifest)
	var projected_spots := LayoutService.object_hotspots(home.manifest)
	_check(failures, projected_spots.size() == expected_spots.size(), "hotspot projection count")
	for index in expected_spots.size():
		var expected: Dictionary = expected_spots[index]
		if index >= projected_spots.size():
			break
		var projected: Dictionary = projected_spots[index]
		var expected_center: Vector2 = expected["center"]
		var expected_size: Vector2 = expected["size"]
		var projected_center: Vector2 = projected["center"]
		var projected_size: Vector2 = projected["size"]
		_check(failures, str(projected["object_id"]) == str(expected["object_id"])
			and int(projected["region_index"]) == int(expected["region_index"]),
			"hotspot identity: %s/%d" % [expected["object_id"], expected["region_index"]])
		_check(failures, projected_center.is_equal_approx(expected_center),
			"hotspot projected center: %s/%d" % [expected["object_id"], expected["region_index"]])
		_check(failures, projected_size.is_equal_approx(expected_size),
			"hotspot projected size: %s/%d" % [expected["object_id"], expected["region_index"]])
		_check(failures, is_equal_approx(float(projected["rotation_degrees"]), float(expected["rotation"])),
			"hotspot projected rotation: %s/%d" % [expected["object_id"], expected["region_index"]])
	var spot_report := []
	for spot in projected_spots:
		var center: Vector2 = spot["center"]
		var spot_size: Vector2 = spot["size"]
		spot_report.append({
			"object_id": str(spot["object_id"]),
			"region_index": int(spot["region_index"]),
			"shape": str(spot["shape"]),
			"center": [center.x, center.y],
			"size": [spot_size.x, spot_size.y],
			"rotation": float(spot["rotation_degrees"]),
		})
	report["hotspots"] = spot_report

	var slip := WordSlipScript.new()
	tree.root.add_child(slip)
	await tree.process_frame
	slip.configure("神志不清", "word_candidate_e01_c1", 54.0, 17)
	_check(failures, slip.size.x <= 55.0, "long word respects max width")
	_check(failures, slip.line_count >= 2, "long word wraps into multiple lines")
	_check(failures, slip.token_id == "word_candidate_e01_c1", "slip keeps token identity")
	var short_slip := WordSlipScript.new()
	tree.root.add_child(short_slip)
	await tree.process_frame
	short_slip.configure("困", "word_candidate_elias_sleep_alt", 200.0, 18)
	_check(failures, short_slip.line_count == 1, "short word stays on one line")
	_check(failures, short_slip.size.y >= 34.0, "short word keeps a readable height")
	var fitted_slip := WordSlipScript.new()
	tree.root.add_child(fitted_slip)
	await tree.process_frame
	fitted_slip.configure("合上眼", "word_candidate_elias_sleep", 200.0, 20)
	_check(failures, fitted_slip.size.x < 200.0,
		"word slip paper follows the text instead of a fixed slot")
	_check(failures, fitted_slip.size.y >= 34.0, "word slip keeps a readable height")
	var drop := PotDropScript.new()
	tree.root.add_child(drop)
	await tree.process_frame
	_check(failures, drop._can_drop_data(Vector2.ZERO,
		{"kind": "word", "token_id": "word_candidate_e01_c1", "source": null}),
		"pot accepts word drag data")
	var received := [""]
	drop.dropped.connect(func(token_id): received[0] = token_id)
	drop._drop_data(Vector2.ZERO,
		{"kind": "word", "token_id": "word_candidate_e01_c1", "source": null})
	_check(failures, received[0] == "word_candidate_e01_c1", "pot emits the dropped token")

	report["failures"] = failures
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/evidence"))
	var evidence := FileAccess.open("res://docs/evidence/p0-layout.json", FileAccess.WRITE)
	if evidence != null:
		evidence.store_string(JSON.stringify(report, "  ") + "\n")
	home.queue_free()
	slip.queue_free()
	short_slip.queue_free()
	fitted_slip.queue_free()
	drop.queue_free()
	await tree.process_frame
	completed = true
	return failures
