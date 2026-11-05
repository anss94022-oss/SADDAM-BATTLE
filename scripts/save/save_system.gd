extends Node
## الحفظ المحلي الكامل — لا يحتاج إنترنت.
## يخزّن التقدم، الإنجازات، الأسلحة المفتوحة، نقاط الحفظ، والإعدادات المنفصلة.
## يتعامل بأمان مع الملفات التالفة (نسخة احتياطية .bak قبل كل كتابة).

signal progress_changed
signal achievement_unlocked(id: String)

const SAVE_PATH := "user://saddam_battle_save.json"
const BACKUP_PATH := "user://saddam_battle_save.bak.json"
const SAVE_VERSION := 3

const XP_PER_LEVEL_BASE := 400
const XP_PER_LEVEL_STEP := 250

var progress: Dictionary = {}
var last_error := ""


func _ready() -> void:
	load_progress()


func default_progress() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_name": "",
		"level": 1,
		"xp": 0,
		"coins": 0,
		"unlocked_weapons": ["rifle_ak", "pistol", "knife", "grenade", "shotgun", "smg"],
		"equipped_weapon": "rifle_ak",
		"equipped_secondary": "pistol",
		"missions_completed": [],
		"best_mission": 0,
		"total_kills": 0,
		"total_headshots": 0,
		"play_seconds": 0.0,
		"driving_seconds": 0.0,
		"flight_landings": 0,
		"demolitions": 0,
		"achievements": {},
		"checkpoint": {},
		"multiplayer_matches": 0
	}


func _migrate(data: Dictionary) -> Dictionary:
	var merged := default_progress()
	for key in merged.keys():
		if data.has(key):
			merged[key] = data[key]

	var version := int(data.get("version", 1))
	if version < 2:
		# إصدارات أقدم كانت تخزّن معرّفات أسلحة مختلفة.
		var legacy := {"rifle": "rifle_ak", "sniper": "sniper", "shotgun": "shotgun"}
		var unlocked: Array = []
		for weapon_id in merged.get("unlocked_weapons", []):
			unlocked.append(legacy.get(String(weapon_id), String(weapon_id)))
		merged["unlocked_weapons"] = unlocked
		merged["equipped_weapon"] = legacy.get(String(merged.get("equipped_weapon", "rifle")),
				String(merged.get("equipped_weapon", "rifle_ak")))

	merged["version"] = SAVE_VERSION
	return merged


func load_progress() -> void:
	last_error = ""
	var data := _read_dict(SAVE_PATH)
	if data.is_empty():
		data = _read_dict(BACKUP_PATH)
		if not data.is_empty():
			last_error = "recovered_from_backup"

	if data.is_empty():
		progress = default_progress()
		return

	progress = _migrate(data)


func _read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var raw := file.get_as_text()
	file.close()
	if raw.strip_edges() == "":
		return {}
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ملف حفظ غير صالح: %s" % path)
		return {}
	return parsed


func save_progress() -> bool:
	# نسخة احتياطية من الملف السليم قبل الكتابة.
	if FileAccess.file_exists(SAVE_PATH):
		var old := FileAccess.get_file_as_string(SAVE_PATH)
		if old.strip_edges() != "" and JSON.parse_string(old) != null:
			var backup := FileAccess.open(BACKUP_PATH, FileAccess.WRITE)
			if backup != null:
				backup.store_string(old)
				backup.close()

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("تعذر إنشاء ملف الحفظ.")
		return false
	file.store_string(JSON.stringify(progress, "\t"))
	file.close()
	progress_changed.emit()
	return true


func reset_progress() -> void:
	progress = default_progress()
	save_progress()


# ------------------------------------------------------------------ الخبرة
func xp_for_level(level: int) -> int:
	return XP_PER_LEVEL_BASE + maxi(0, level - 1) * XP_PER_LEVEL_STEP


func add_xp(amount: int) -> Dictionary:
	progress["xp"] = int(progress.get("xp", 0)) + maxi(0, amount)
	var leveled := false
	while int(progress["xp"]) >= xp_for_level(int(progress["level"])):
		progress["xp"] = int(progress["xp"]) - xp_for_level(int(progress["level"]))
		progress["level"] = int(progress["level"]) + 1
		progress["coins"] = int(progress.get("coins", 0)) + 150
		leveled = true
	save_progress()
	return {
		"level": int(progress["level"]),
		"xp": int(progress["xp"]),
		"needed": xp_for_level(int(progress["level"])),
		"leveled_up": leveled
	}


func add_coins(amount: int) -> void:
	progress["coins"] = int(progress.get("coins", 0)) + maxi(0, amount)
	save_progress()


func add_play_time(seconds: float) -> void:
	progress["play_seconds"] = float(progress.get("play_seconds", 0.0)) + maxf(0.0, seconds)


func register_kill(headshot: bool = false) -> void:
	progress["total_kills"] = int(progress.get("total_kills", 0)) + 1
	if headshot:
		progress["total_headshots"] = int(progress.get("total_headshots", 0)) + 1
	add_xp(25 if headshot else 12)
	if headshot and int(progress["total_headshots"]) >= 25:
		unlock_achievement("marksman")
	if int(progress["total_kills"]) >= 1:
		unlock_achievement("first_blood")


func register_demolition() -> void:
	progress["demolitions"] = int(progress.get("demolitions", 0)) + 1
	if int(progress["demolitions"]) >= 10:
		unlock_achievement("demolition")


func register_landing() -> void:
	progress["flight_landings"] = int(progress.get("flight_landings", 0)) + 1
	if int(progress["flight_landings"]) >= 10:
		unlock_achievement("pilot")


func add_driving_time(seconds: float) -> void:
	progress["driving_seconds"] = float(progress.get("driving_seconds", 0.0)) + maxf(0.0, seconds)
	if float(progress["driving_seconds"]) >= 600.0:
		unlock_achievement("driver")


# ------------------------------------------------------------- الإنجازات
func unlock_achievement(id: String) -> bool:
	var achievements: Dictionary = progress.get("achievements", {})
	if bool(achievements.get(id, false)):
		return false
	achievements[id] = true
	progress["achievements"] = achievements
	save_progress()
	achievement_unlocked.emit(id)
	return true


func has_achievement(id: String) -> bool:
	return bool((progress.get("achievements", {}) as Dictionary).get(id, false))


func achievement_count() -> int:
	return (progress.get("achievements", {}) as Dictionary).size()


# ----------------------------------------------------------------- المهام
func complete_mission(index: int, xp_reward: int, coins_reward: int,
		unlock_weapon_id: String = "") -> Dictionary:
	var completed: Array = progress.get("missions_completed", [])
	if not completed.has(index):
		completed.append(index)
	progress["missions_completed"] = completed
	progress["best_mission"] = maxi(int(progress.get("best_mission", 0)), index)
	var level_info := add_xp(xp_reward)
	add_coins(coins_reward)

	if unlock_weapon_id != "":
		_force_unlock(unlock_weapon_id)

	progress.erase("checkpoint")
	save_progress()

	if completed.size() >= 12:
		unlock_achievement("campaign")
	if _all_weapons_unlocked():
		unlock_achievement("collector")

	return {
		"level": level_info["level"],
		"leveled_up": level_info["leveled_up"],
		"unlocked": unlock_weapon_id
	}


func is_mission_completed(index: int) -> bool:
	return (progress.get("missions_completed", []) as Array).has(index)


func is_mission_unlocked(index: int) -> bool:
	return index <= 0 or is_mission_completed(index - 1)


# ------------------------------------------------------------- نقاط الحفظ
func store_checkpoint(data: Dictionary) -> void:
	progress["checkpoint"] = data
	save_progress()


func get_checkpoint() -> Dictionary:
	return progress.get("checkpoint", {})


func clear_checkpoint() -> void:
	progress.erase("checkpoint")
	save_progress()


# --------------------------------------------------------------- الأسلحة
func is_weapon_unlocked(weapon_id: String) -> bool:
	return (progress.get("unlocked_weapons", []) as Array).has(weapon_id)


func unlock_weapon(weapon_id: String, cost: int) -> bool:
	if is_weapon_unlocked(weapon_id):
		return true
	if int(progress.get("coins", 0)) < cost:
		return false
	progress["coins"] = int(progress["coins"]) - cost
	var weapons: Array = progress.get("unlocked_weapons", [])
	weapons.append(weapon_id)
	progress["unlocked_weapons"] = weapons
	if _all_weapons_unlocked():
		unlock_achievement("collector")
	save_progress()
	return true


func _force_unlock(weapon_id: String) -> void:
	if is_weapon_unlocked(weapon_id):
		return
	var weapons: Array = progress.get("unlocked_weapons", [])
	weapons.append(weapon_id)
	progress["unlocked_weapons"] = weapons


func _all_weapons_unlocked() -> bool:
	var db := get_node_or_null("/root/WeaponsDB")
	if db == null:
		return false
	for id in db.all_ids():
		if not is_weapon_unlocked(String(id)):
			return false
	return true


func equip(weapon_id: String) -> void:
	if not is_weapon_unlocked(weapon_id):
		return
	progress["equipped_weapon"] = weapon_id
	save_progress()


func equipped() -> String:
	return String(progress.get("equipped_weapon", "rifle_ak"))


func secondary() -> String:
	return String(progress.get("equipped_secondary", "pistol"))


func equip_secondary(weapon_id: String) -> void:
	if not is_weapon_unlocked(weapon_id):
		return
	progress["equipped_secondary"] = weapon_id
	save_progress()
