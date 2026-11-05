extends Node
## قاعدة بيانات الأسلحة — تُحمّل من data/weapons/weapons.json.
## كل خصائص السلاح (ضرر، مدى، ارتداد، مخزن، تلقيم، صوت…) تعيش هنا فقط،
## حتى لا تكون مكرّرة داخل كود اللاعب.

const DATA_PATH := "res://data/weapons/weapons.json"

var weapons: Dictionary = {}
var order: Array = []


func _ready() -> void:
	load_data()


func load_data() -> bool:
	weapons.clear()
	order.clear()

	if not FileAccess.file_exists(DATA_PATH):
		push_error("WeaponsDB: missing %s" % DATA_PATH)
		return false

	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("weapons"):
		push_error("WeaponsDB: malformed data")
		return false

	for entry in parsed["weapons"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var weapon_id := String(entry.get("id", ""))
		if weapon_id == "":
			continue
		var weapon := _normalize(entry)
		weapons[weapon_id] = weapon
		order.append(weapon_id)

	return true


func _normalize(entry: Dictionary) -> Dictionary:
	var weapon := entry.duplicate(true)
	weapon["id"] = String(weapon.get("id", ""))
	weapon["damage"] = float(weapon.get("damage", 20.0))
	weapon["headshot_mult"] = float(weapon.get("headshot_mult", 2.0))
	weapon["rpm"] = max(1.0, float(weapon.get("rpm", 600.0)))
	weapon["magazine"] = int(weapon.get("magazine", 30))
	weapon["reserve"] = int(weapon.get("reserve", 90))
	weapon["spread"] = float(weapon.get("spread", 1.0))
	weapon["aim_spread"] = float(weapon.get("aim_spread", 0.3))
	weapon["range"] = float(weapon.get("range", 200.0))
	weapon["automatic"] = bool(weapon.get("automatic", true))
	weapon["pellets"] = int(weapon.get("pellets", 1))
	weapon["recoil"] = float(weapon.get("recoil", 1.0))
	weapon["reload_time"] = float(weapon.get("reload_time", 2.0))
	weapon["unlock_cost"] = int(weapon.get("unlock_cost", 0))
	weapon["start_unlocked"] = bool(weapon.get("start_unlocked", false))
	weapon["sound"] = String(weapon.get("sound", "shot_rifle"))
	weapon["name_key"] = String(weapon.get("name_key", weapon["id"]))
	weapon["class"] = String(weapon.get("class", "assault_rifle"))
	weapon["melee"] = bool(weapon.get("melee", false))
	weapon["throwable"] = bool(weapon.get("throwable", false))
	weapon["explosive"] = bool(weapon.get("explosive", false))
	weapon["stealth"] = bool(weapon.get("stealth", false))
	weapon["blast_radius"] = float(weapon.get("blast_radius", 0.0))
	weapon["fuse"] = float(weapon.get("fuse", 3.0))
	weapon["scope_zooms"] = weapon.get("zoom_levels", [1.0])

	var zooms: Array = []
	for value in weapon["scope_zooms"]:
		zooms.append(float(value))
	if zooms.is_empty():
		zooms = [1.0]
	weapon["scope_zooms"] = zooms

	return weapon


func has(id: String) -> bool:
	return weapons.has(id)


func get_weapon(id: String) -> Dictionary:
	if weapons.has(id):
		return weapons[id]
	return {}


func all_ids() -> Array:
	return order.duplicate()


func guns() -> Array:
	var result: Array = []
	for id in order:
		var weapon: Dictionary = weapons[id]
		if bool(weapon["melee"]) or bool(weapon["throwable"]):
			continue
		result.append(weapon)
	return result


func starting_loadout() -> Array:
	var result: Array = []
	for id in order:
		if bool(weapons[id]["start_unlocked"]):
			result.append(id)
	return result
