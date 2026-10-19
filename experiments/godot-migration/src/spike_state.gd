extends RefCounted
## Isolated example state. This is not the full release rule engine.

const WORD_LABELS := {"word_sleep": "睡觉", "word_quiet": "安静", "word_dream": "梦"}
const INGREDIENT_LABELS := {"ing_sea_salt": "海盐", "ing_night_dew": "夜露", "ing_ashen_herb": "灰烬草", "ing_dried_petal": "干花瓣"}
var words: Dictionary = {"word_sleep": 3, "word_quiet": 2, "word_dream": 1}
var ingredients: Dictionary = {"ing_sea_salt": 3, "ing_night_dew": 3, "ing_ashen_herb": 3, "ing_dried_petal": 3}
var selected_word := ""
var selected_ingredient := ""
var batch_count := 0
var last_result := ""

func select_word(id: String) -> bool:
	if not words.has(id) or words[id] <= 0:
		return false
	selected_word = id
	return true

func select_ingredient(id: String) -> bool:
	if not ingredients.has(id) or ingredients[id] <= 0:
		return false
	selected_ingredient = id
	return true

func brew() -> Dictionary:
	if selected_word.is_empty() or not words.has(selected_word) or words[selected_word] <= 0:
		return {"ok": false, "message": "先选一张主词纸条。"}
	if not selected_ingredient.is_empty() and (not ingredients.has(selected_ingredient) or ingredients[selected_ingredient] <= 0):
		return {"ok": false, "message": "这份原料已经用完。"}
	words[selected_word] -= 1
	var ingredient_text := "未加辅料"
	if not selected_ingredient.is_empty():
		ingredients[selected_ingredient] -= 1
		ingredient_text = INGREDIENT_LABELS[selected_ingredient]
	last_result = "%s · %s" % [WORD_LABELS[selected_word], ingredient_text]
	batch_count += 1
	selected_word = ""
	selected_ingredient = ""
	return {"ok": true, "message": "验证配方完成：" + last_result}

func snapshot() -> Dictionary:
	return {"schema": 1, "words": words.duplicate(true), "ingredients": ingredients.duplicate(true),
		"selected_word": selected_word, "selected_ingredient": selected_ingredient,
		"batch_count": batch_count, "last_result": last_result}

func save_to(path: String) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(snapshot()))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK

func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	var data = json.data
	if not data is Dictionary or data.get("schema") != 1:
		return false
	for key in ["words", "ingredients"]:
		if not data.get(key) is Dictionary:
			return false
		var expected: Dictionary = words if key == "words" else ingredients
		if data[key].size() != expected.size():
			return false
		for id in expected:
			var value = data[key].get(id)
			if not (value is float or value is int) or not is_finite(value) or value < 0 or value > 9999 or floor(value) != value:
				return false
	if not data.get("selected_word") is String or not data.get("selected_ingredient") is String:
		return false
	if data.selected_word != "" and not data.words.has(data.selected_word):
		return false
	if data.selected_ingredient != "" and not data.ingredients.has(data.selected_ingredient):
		return false
	var count = data.get("batch_count")
	if not (count is float or count is int) or not is_finite(count) or count < 0 or count > 999999 or floor(count) != count:
		return false
	if not data.get("last_result") is String or data.last_result.length() > 200:
		return false
	words = data.words.duplicate(true)
	ingredients = data.ingredients.duplicate(true)
	for id in words:
		words[id] = int(words[id])
	for id in ingredients:
		ingredients[id] = int(ingredients[id])
	selected_word = data.selected_word
	selected_ingredient = data.selected_ingredient
	batch_count = int(count)
	last_result = data.last_result
	return true
