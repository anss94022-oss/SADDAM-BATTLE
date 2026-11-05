extends Node
## فحص بنية المشروع: ملفات ضرورية، JSON صالح، مراجع res:// موجودة، لا ملفات فارغة.

var failures: Array = []

func _ready() -> void:
	var required := [
		"project.godot", "scenes/main/main.tscn", "scripts/main/main.gd",
		"scripts/player/player.gd", "scripts/player/soldier_rig.gd",
		"scripts/ai/enemy.gd", "scripts/missions/mission_manager.gd",
		"scripts/vehicles/vehicle.gd", "scripts/world/world_builder.gd",
		"scripts/ui/hud.gd", "scripts/ui/menu.gd",
		"scripts/save/save_system.gd", "scripts/settings/game_settings.gd",
		"scripts/localization/locale.gd", "scripts/core/weapons_db.gd",
		"scripts/core/vehicles_db.gd", "scripts/audio/audio_manager.gd",
		"data/weapons/weapons.json", "data/vehicles/vehicles.json",
		"data/enemies/enemies.json", "data/missions/missions.json",
		"data/i18n/ar.json", "data/i18n/en.json",
		"assets/fonts/NotoSansArabic-Regular.ttf", "icon.png", "LICENSE", "README.md"
	]
	for path in required:
		_check(FileAccess.file_exists("res://" + path), "exists: " + path)

	_check(WeaponsDB.all_ids().size() >= 12, "weapons >= 12 (got %d)" % WeaponsDB.all_ids().size())
	_check(VehiclesDB.all_ids().size() >= 10, "vehicles >= 10 (got %d)" % VehiclesDB.all_ids().size())

	var missions: Array = []
	if FileAccess.file_exists("res://data/missions/missions.json"):
		var file := FileAccess.open("res://data/missions/missions.json", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("campaign"):
			missions = parsed["campaign"]
	_check(missions.size() >= 12, "campaign missions loaded (%d, expected 12+)" % missions.size())

	var objective_types := {}
	for mission in missions:
		var objective = mission.get("objective", {})
		var type := String(objective.get("type", "")) if typeof(objective) == TYPE_DICTIONARY else ""
		_check(type != "", "mission %s has objective" % mission.get("id", "?"))
		objective_types[type] = true
		_check(mission.has("map"), "mission %s has map" % mission.get("id", "?"))
	_check(objective_types.size() >= 5, "at least 5 objective types (%s)" % str(objective_types.keys()))

	# الأسلحة المطلوبة في بيانات الأعداء موجودة
	for archetype_id in ["rifleman", "scout", "gunner", "sniper", "rocketeer", "officer", "boss"]:
		_check(archetypes().has(archetype_id), "archetype: " + archetype_id)

	# مراجع res:// داخل السكربتات والبيانات
	var missing: Array = []
	for path in _all_files("res://scripts"):
		if path.ends_with(".gd"):
			_scan_references(path, missing)
	for id in WeaponsDB.all_ids():
		var weapon: Dictionary = WeaponsDB.get_weapon(id)
		var sound_path := "res://assets/audio/sfx/%s.wav" % String(weapon["sound"])
		if not ResourceLoader.exists(sound_path):
			missing.append(sound_path)
	for id in VehiclesDB.all_ids():
		var engine_path := "res://assets/audio/sfx/%s.wav" % String(VehiclesDB.get_vehicle(id).get("engine", ""))
		if not ResourceLoader.exists(engine_path):
			missing.append(engine_path)

	_check(missing.is_empty(), "all referenced assets exist (%d missing)" % missing.size())
	for item in missing.slice(0, 10):
		print("   missing: ", item)

	# لا ملفات مصدر فارغة
	var empty: Array = []
	for path in _all_files("res://scripts") + _all_files("res://data"):
		var content := FileAccess.get_file_as_string(path)
		if content.strip_edges().length() < 20:
			empty.append(path)
	_check(empty.is_empty(), "no empty source files")

	# ترجمات متطابقة المفاتيح
	var ar := _json_keys("res://data/i18n/ar.json")
	var en := _json_keys("res://data/i18n/en.json")
	var missing_keys: Array = []
	for key in ar:
		if not en.has(key):
			missing_keys.append(key)
	_check(missing_keys.is_empty(), "ar/en key parity (%d missing in en)" % missing_keys.size())

	if failures.is_empty():
		print("PROJECT CHECK OK")
		get_tree().quit(0)
	else:
		print("PROJECT CHECK FAILED (%d)" % failures.size())
		get_tree().quit(1)


func archetypes() -> Dictionary:
	var data := {}
	if FileAccess.file_exists("res://data/enemies/enemies.json"):
		var file := FileAccess.open("res://data/enemies/enemies.json", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("archetypes"):
			data = parsed["archetypes"]
	return data


func _json_keys(path: String) -> Array:
	var keys: Array = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return keys
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		keys = parsed.keys()
	return keys


func _all_files(root: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(root)
	if dir == null:
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := root.path_join(name)
		if dir.current_is_dir():
			result.append_array(_all_files(full))
		else:
			result.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return result


func _scan_references(path: String, missing: Array) -> void:
	var content := FileAccess.get_file_as_string(path)
	var index := content.find("res://")
	while index != -1:
		var end := index
		while end < content.length() and not content[end] in ["\"", "'", ")", " ", "\n"]:
			end += 1
		var ref := content.substr(index, end - index)
		if ref.contains(".") and not ref.ends_with(".gd") and not ref.contains("%") \
				and not ref.contains("*"):
			if not ResourceLoader.exists(ref) and not FileAccess.file_exists(ref):
				missing.append(ref)
		index = content.find("res://", index + 6)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		print("  FAIL ", message)
		failures.append(message)
