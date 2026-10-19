extends RefCounted

## Loads the three P0 scenes so GDScript parse/runtime errors are caught in
## headless CI, not only when a user opens the window.

const HomeLayersScript = preload("res://src/presentation/home_layers.gd")
const LayoutService = preload("res://src/app/layout_service.gd")

var assertions := 0
var completed := false


func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)


func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	tree.root.size = Vector2i(1920, 1080)
	var cases := [
		["res://scenes/title.tscn", "Title"],
		["res://scenes/home.tscn", "Home"],
		["res://scenes/brew.tscn", "Brew"],
	]
	for entry in cases:
		var packed := load(str(entry[0])) as PackedScene
		_check(failures, packed != null, "scene loads: " + str(entry[0]))
		if packed == null:
			continue
		var instance := packed.instantiate()
		var safe := Rect2(60.0, 0.0, 1800.0, 1080.0)
		instance.safe_override = safe
		tree.root.add_child(instance)
		await tree.process_frame
		await tree.process_frame
		_check(failures, instance.get_child_count() > 0, "scene builds children: " + str(entry[1]))
		if str(entry[1]) == "Title":
			var start := instance.find_child("StartGame", true, false)
			_check(failures, start != null, "title has StartGame")
			if start != null:
				_check(failures, safe.encloses(start.get_global_rect()), "title start stays in safe area")
		if str(entry[1]) == "Home":
			var layers := instance.find_child("HomeLayers", true, false)
			_check(failures, layers != null, "home has HomeLayers")
			if layers != null:
				_check(failures, layers.layer_size("net").x > 300.0 and layers.layer_size("net").x < 400.0,
					"home net keeps target width")
				_check(failures, layers.layer_size("net") != Vector2(1024.0, 1536.0),
					"home net is not native texture size")
				_check(failures, layers.backdrop_node != null, "home has sea backdrop")
				var expected_spots := LayoutService.object_hotspots(layers.manifest)
				var actual_spots: Array = []
				for child in layers.get_children():
					if child is HomeHotspot:
						actual_spots.append(child)
				_check(failures, actual_spots.size() == expected_spots.size(), "home hotspot count")
				for expected in expected_spots:
					var found: HomeHotspot = null
					for child in actual_spots:
						var candidate: HomeHotspot = child
						if candidate.object_id == str(expected["object_id"]) \
								and candidate.region_index == int(expected["region_index"]):
							found = candidate
							break
					_check(failures, found != null,
						"home hotspot exists: %s/%d" % [expected["object_id"], expected["region_index"]])
					if found != null:
						var spot_center: Vector2 = expected["center"]
						var spot_size: Vector2 = expected["size"]
						_check(failures, found.size.is_equal_approx(spot_size),
							"home hotspot size: %s/%d" % [expected["object_id"], expected["region_index"]])
						_check(failures, found.position.is_equal_approx(spot_center - spot_size * 0.5),
							"home hotspot position: %s/%d" % [expected["object_id"], expected["region_index"]])
						_check(failures, is_equal_approx(found.rotation_degrees, float(expected["rotation_degrees"])),
							"home hotspot rotation: %s/%d" % [expected["object_id"], expected["region_index"]])
						_check(failures, found._has_point(found.size * 0.5),
							"home hotspot center: %s/%d" % [expected["object_id"], expected["region_index"]])
			var ledger := instance.find_child("LedgerTag", true, false)
			var back := instance.find_child("HomeBack", true, false)
			_check(failures, ledger != null and back != null, "home HUD nodes exist")
			if ledger != null:
				_check(failures, safe.encloses(ledger.get_global_rect()), "home ledger stays in safe area")
			if back != null:
				_check(failures, safe.encloses(back.get_global_rect()), "home back stays in safe area")
			tree.root.size = Vector2i(2400, 1080)
			instance.safe_override = Rect2(0.0, 0.0, 2400.0, 1080.0)
			await tree.process_frame
			await tree.process_frame
			var left_edge := instance.find_child("HomeEdgeLeft", true, false)
			var right_edge := instance.find_child("HomeEdgeRight", true, false)
			_check(failures, left_edge != null and right_edge != null, "wide home has both edge extensions")
			if left_edge != null:
				_check(failures, is_equal_approx(left_edge.position.x, 0.0)
					and is_equal_approx(left_edge.size.x, 240.0)
					and is_equal_approx(left_edge.size.y, 1080.0),
					"left edge extension fills the margin")
			if right_edge != null:
				_check(failures, is_equal_approx(right_edge.position.x, 2160.0)
					and is_equal_approx(right_edge.size.x, 240.0),
					"right edge extension fills the margin")
			tree.root.size = Vector2i(1920, 1080)
			await tree.process_frame
			await tree.process_frame
		if str(entry[1]) == "Brew":
			_check(failures, instance.find_child("Cauldron", true, false) != null, "brew has cauldron")
			_check(failures, instance.find_child("IngredientTray", true, false) != null, "brew has tray")
			_check(failures, instance.find_child("BrewWordPanel", true, false) != null, "brew has word panel")
			_check(failures, instance.find_child("BrewBookPanel", true, false) != null, "brew has book panel")
			for node_name in ["BrewBack", "BrewToggleWords", "BrewToggleJournal", "BrewStart"]:
				var node := instance.find_child(node_name, true, false)
				_check(failures, node != null, "brew control exists: " + node_name)
				if node != null:
					_check(failures, safe.encloses(node.get_global_rect()),
						"brew control stays in safe area: " + node_name)
		instance.queue_free()
		await tree.process_frame
	completed = true
	return failures
