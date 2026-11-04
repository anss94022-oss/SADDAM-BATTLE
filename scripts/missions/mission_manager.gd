extends Node
## مدير المهام: يحمّل بيانات الحملة، يُنشئ الأعداء، يتابع الهدف والوقت،
## ويعلن النجاح أو الفشل.

signal objective_updated(text: String)
signal progress_updated(current: int, total: int)
signal timer_updated(seconds_left: int)
signal mission_completed(index: int, xp: int)
signal mission_failed(reason: String)

const MISSIONS_PATH := "res://data/missions/missions.json"

var campaign: Array = []
var current_index := 0
var current: Dictionary = {}

var world_root: Node3D
var player: Node3D
var spawn_points: Array = []

var enemies_alive := 0
var enemies_total := 0
var kills := 0
var time_left := 0.0
var is_running := false

var _enemy_scene_script: Script


func _ready() -> void:
	_enemy_scene_script = load("res://scripts/ai/enemy.gd")
	load_campaign()


func load_campaign() -> void:
	if not FileAccess.file_exists(MISSIONS_PATH):
		push_error("ملف المهام غير موجود.")
		return

	var file := FileAccess.open(MISSIONS_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("campaign"):
		campaign = parsed["campaign"]


func mission_count() -> int:
	return campaign.size()


func get_mission(index: int) -> Dictionary:
	if index < 0 or index >= campaign.size():
		return {}
	return campaign[index]


func start_mission(index: int, world: Node3D, player_node: Node3D, points: Array) -> void:
	current_index = index
	current = get_mission(index)
	world_root = world
	player = player_node
	spawn_points = points

	if current.is_empty():
		mission_failed.emit("المهمة غير موجودة.")
		return

	enemies_total = int(current.get("enemy_count", 6))
	enemies_alive = enemies_total
	kills = 0
	time_left = float(current.get("time_limit", 0))
	is_running = true

	objective_updated.emit(String(current.get("brief", "")))
	progress_updated.emit(0, enemies_total)

	_spawn_enemies()


func _spawn_enemies() -> void:
	var is_boss := bool(current.get("boss", false))
	var spawned := 0

	while spawned < enemies_total:
		var point: Vector3 = Vector3.ZERO
		if spawn_points.size() > 0:
			point = spawn_points[spawned % spawn_points.size()] + Vector3(
				randf_range(-3.0, 3.0), 0.2, randf_range(-3.0, 3.0)
			)
		else:
			point = Vector3(randf_range(-35, 35), 1.0, randf_range(-35, 35))

		var enemy := CharacterBody3D.new()
		enemy.set_script(_enemy_scene_script)
		enemy.position = point

		enemy.max_health = float(current.get("enemy_health", 100))
		enemy.health = enemy.max_health
		enemy.move_speed = float(current.get("enemy_speed", 3.2))
		enemy.accuracy = float(current.get("enemy_accuracy", 0.6))
		enemy.target = player

		# القائد في المهمة الأخيرة أقوى وأكبر.
		if is_boss and spawned == 0:
			enemy.max_health *= 2.2
			enemy.health = enemy.max_health
			enemy.attack_damage = 18.0
			enemy.scale = Vector3(1.25, 1.25, 1.25)
			enemy.move_speed *= 0.85

		enemy.died.connect(_on_enemy_died)
		world_root.add_child(enemy)
		spawned += 1


func _on_enemy_died(_enemy: Node) -> void:
	if not is_running:
		return

	enemies_alive = max(0, enemies_alive - 1)
	kills += 1
	progress_updated.emit(kills, enemies_total)

	if enemies_alive <= 0:
		_finish(true)


func _process(delta: float) -> void:
	if not is_running:
		return

	if float(current.get("time_limit", 0)) > 0.0:
		time_left -= delta
		timer_updated.emit(int(ceil(max(0.0, time_left))))

		if time_left <= 0.0:
			# مهام "الصمود" تنجح بانتهاء الوقت، والبقية تفشل.
			if String(current.get("objective", "")) == "survive":
				_finish(true)
			else:
				_finish(false, "انتهى الوقت قبل إكمال الهدف.")


func _finish(success: bool, reason: String = "") -> void:
	if not is_running:
		return

	is_running = false

	if success:
		SaveSystem.complete_mission(current_index)
		mission_completed.emit(current_index, int(current.get("reward_xp", 150)))
	else:
		mission_failed.emit(reason if reason != "" else "فشلت المهمة.")


func stop() -> void:
	is_running = false


func remaining_enemies() -> int:
	return enemies_alive
