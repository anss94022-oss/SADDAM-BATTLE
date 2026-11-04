extends Node
## نظام الحفظ المحلي — يعمل بلا إنترنت بالكامل.
## يُخزّن التقدّم (الخبرة، المستوى، العملات، الأسلحة المفتوحة، أفضل مهمة)
## في ملف JSON داخل مساحة التطبيق: user://saddam_battle_save.json

const SAVE_PATH := "user://saddam_battle_save.json"
const SAVE_VERSION := 1

## المستويات: كل مستوى يحتاج خبرة أكبر تدريجياً.
const XP_PER_LEVEL_BASE := 400
const XP_PER_LEVEL_STEP := 250

var progress: Dictionary = {}


func _ready() -> void:
	load_progress()


func default_progress() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"player_name": "صدام",
		"level": 1,
		"xp": 0,
		"coins": 0,
		"unlocked_weapons": ["rifle"],
		"equipped_weapon": "rifle",
		"missions_completed": [],
		"best_mission": 0,
		"total_kills": 0,
		"total_headshots": 0,
		"play_seconds": 0.0
	}


func load_progress() -> void:
	progress = default_progress()

	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("تعذر فتح ملف الحفظ.")
		return

	var raw := file.get_as_text()
	file.close()

	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("ملف الحفظ تالف — سيتم البدء من جديد.")
		return

	# دمج آمن: أي مفتاح جديد يُضاف بالقيمة الافتراضية.
	for key in default_progress().keys():
		if parsed.has(key):
			progress[key] = parsed[key]

	progress["version"] = SAVE_VERSION


func save_progress() -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("تعذر إنشاء ملف الحفظ.")
		return false

	file.store_string(JSON.stringify(progress, "\t"))
	file.close()
	return true


func reset_progress() -> void:
	progress = default_progress()
	save_progress()


func xp_for_level(level: int) -> int:
	return XP_PER_LEVEL_BASE + (level - 1) * XP_PER_LEVEL_STEP


func add_xp(amount: int) -> Dictionary:
	progress["xp"] = int(progress.get("xp", 0)) + max(0, amount)

	var leveled_up := false
	while progress["xp"] >= xp_for_level(int(progress["level"])):
		progress["xp"] -= xp_for_level(int(progress["level"]))
		progress["level"] = int(progress["level"]) + 1
		progress["coins"] = int(progress.get("coins", 0)) + 150
		leveled_up = true

	save_progress()

	return {
		"level": int(progress["level"]),
		"xp": int(progress["xp"]),
		"needed": xp_for_level(int(progress["level"])),
		"leveled_up": leveled_up
	}


func add_coins(amount: int) -> void:
	progress["coins"] = int(progress.get("coins", 0)) + max(0, amount)
	save_progress()


func register_kill(headshot: bool = false) -> void:
	progress["total_kills"] = int(progress.get("total_kills", 0)) + 1
	if headshot:
		progress["total_headshots"] = int(progress.get("total_headshots", 0)) + 1
	add_xp(40 if headshot else 20)
	add_coins(5 if headshot else 3)


func complete_mission(index: int) -> void:
	var completed: Array = progress.get("missions_completed", [])
	if not completed.has(index):
		completed.append(index)
	progress["missions_completed"] = completed
	progress["best_mission"] = max(int(progress.get("best_mission", 0)), index)
	add_xp(250)
	add_coins(120)
	save_progress()


func is_mission_completed(index: int) -> bool:
	return (progress.get("missions_completed", []) as Array).has(index)


func is_weapon_unlocked(weapon_id: String) -> bool:
	return (progress.get("unlocked_weapons", ["rifle"]) as Array).has(weapon_id)


func unlock_weapon(weapon_id: String, cost: int) -> bool:
	if is_weapon_unlocked(weapon_id):
		return true

	if int(progress.get("coins", 0)) < cost:
		return false

	progress["coins"] = int(progress["coins"]) - cost
	var weapons: Array = progress.get("unlocked_weapons", ["rifle"])
	weapons.append(weapon_id)
	progress["unlocked_weapons"] = weapons
	save_progress()
	return true
