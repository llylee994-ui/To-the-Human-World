extends RefCounted

var assertions := 0
var completed := false

func _check(failures: Array[String], condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func run(tree: SceneTree) -> Array[String]:
	var failures: Array[String] = []
	for fixture in [
		[Vector2i(1920,1080), Rect2(60,0,1800,1080)],
		[Vector2i(2412,1080), Rect2(0,48,2292,972)],
		[Vector2i(1920,1080), Rect2(120,40,1800,980)],
	]:
		tree.root.size = fixture[0]
		var safe: Rect2 = fixture[1]
		var scene = load("res://scenes/brew.tscn").instantiate()
		scene.safe_override = safe
		tree.root.add_child(scene)
		await tree.process_frame
		await tree.process_frame
		var panel = scene.find_child("BrewWordPanel",true,false)
		for child in panel.get_children():
			if child is WordSlip:
				_check(failures,safe.encloses(child.get_global_rect()),"safe word card: "+child.display_text+" in "+str(safe))
				_check(failures,child.font_size >= 36,"mobile word text remains larger than the previous 32px")
		var summary = scene.find_child("BrewSummary",true,false)
		var labels: Array = summary.find_children("*","Label",true,false)
		for i in labels.size():
			var label: Label = labels[i]
			_check(failures,summary.get_global_rect().encloses(label.get_global_rect()),"recipe text stays on paper: "+label.text)
			_check(failures,label.get_theme_font_size("font_size") >= 23,"recipe text has a readable mobile size")
			for j in range(i+1,labels.size()):
				_check(failures,not label.get_global_rect().intersects(labels[j].get_global_rect()),"recipe text does not overlap: "+label.text+" / "+labels[j].text)
		var tray = scene.find_child("IngredientTray",true,false)
		_check(failures,is_equal_approx(tray.size.x / tray.size.y,2034.0 / 483.0),"ingredient tray preserves its four square-cell source proportions")
		var buttons: Array[Button] = []
		for id in ["BrewStart","BrewClear","BrewToggleWords","BrewToggleJournal","BrewBack"]:
			var button: Button = scene.find_child(id,true,false)
			buttons.append(button)
			_check(failures,button.size.y >= 76.0,"large workbench touch target: "+id)
			_check(failures,button.get_theme_font_size("font_size") >= 40,"large workbench button text: "+id)
			_check(failures,safe.encloses(button.get_global_rect()),"large button respects the safe area: "+id)
			_check(failures,not button.get_global_rect().intersects(tray.get_global_rect()),"button stays outside the ingredient tray: "+id)
		for i in buttons.size():
			for j in range(i+1,buttons.size()):
				_check(failures,not buttons[i].get_global_rect().intersects(buttons[j].get_global_rect()),"large buttons do not overlap")
		_check(failures,panel.position.x == 0.0,"tray artwork stays against the left edge")
		_check(failures,panel.size.x < float(fixture[0].x) * 0.245,"side artwork is smaller than the previous panel")
		var book = scene.find_child("BrewBookPanel",true,false)
		_check(failures,is_equal_approx(book.position.x + book.size.x,float(fixture[0].x)),"book artwork stays against the right edge")
		var journal_scroll: ScrollContainer = book.find_child("JournalText",true,false)
		var header_labels: Array[Label] = []
		var header_positions: Array[Vector2] = []
		var first_entry: Label
		for label: Label in book.find_children("*","Label",true,false):
			if label.text in ["记录书","铁锚巷的一夜","已收集 0 / 8 支"]:
				header_labels.append(label)
				header_positions.append(label.global_position)
				_check(failures,not journal_scroll.is_ancestor_of(label),"journal header stays outside the scroll area: "+label.text)
				_check(failures,label.get_global_rect().end.y <= journal_scroll.global_position.y,"journal list starts below its fixed header: "+label.text)
			elif label.text == "1. ？？？":
				first_entry = label
		_check(failures,header_labels.size() == 3,"journal retains all three header labels")
		var entry_before: Vector2 = first_entry.global_position
		journal_scroll.scroll_vertical = 100
		await tree.process_frame
		await tree.process_frame
		_check(failures,journal_scroll.scroll_vertical > 0,"journal entries can scroll in the available paper area")
		_check(failures,first_entry.global_position.y < entry_before.y,"scrolling moves journal entries")
		for i in header_labels.size():
			_check(failures,header_labels[i].global_position.is_equal_approx(header_positions[i]),"scrolling keeps journal header fixed: "+header_labels[i].text)
		_check(failures,panel.size.y <= float(fixture[0].y)*0.90,"side pages leave vertical breathing room")
		for label in labels:
			_check(failures,not label.get_global_rect().intersects(tray.get_global_rect()),"recipe text does not overlap ingredient tray: "+label.text)
		scene.queue_free()
		await tree.process_frame
	completed = true
	return failures
