extends Node
## مدير المهام: يبني أهداف الحملة فعلياً (تصفية، صمود، إنقاذ رهائن، مرافقة قافلة،
## سيطرة على منطقة، تدمير أهداف، تصفية قادة، الزعيم)، يدير التعزيزات،
## نقاط الحفظ، الوقت، والنجاح/الفشل.

signal objective_updated(text: String)
signal progress_updated(current: int, total: int)
signal timer_updated(seconds_left: int)
signal hint(text: String)
signal mission_completed(index: int, xp: int, coins: int, unlock_id: String)
signal mission_failed(reason_key: String)
signal objective_stage(text: String, ratio: float)
signal enemies_changed(alive: int, total: int)

const MISSIONS_PATH := "res://data/missions/missions.json"
const ENEMIES_PATH := "res://data/enemies/enemies.json"
const ENEMY_SCRIPT := preload("res://scripts/ai/enemy.gd")
const HOSTAGE_SCRIPT := preload("res://scripts/missions/hostage.gd")
const CHARGE_SCRIPT := preload("res://scripts/missions/charge_target.gd")
const ZONE_SCRIPT := preload("res://scripts/missions/capture_zone.gd")
const PICKUP_SCRIPT := preload("res://scripts/missions/pickup.gd")
const VEHICLE_SCRIPT := preload("res://scripts/vehicles/vehicle.gd")

var campaign: Array = []
var archetypes: Dictionary = {}
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
var failed_flag := false

var marked_total := 0
var marked_killed := 0
var hostages_total := 0
var hostages_saved := 0
var hostages_lost := 0
var charges_total := 0
var charges_done := 0
var zone_hold := 0.0

var _objective: Dictionary = {}
var _objective_type := "eliminate_all"
var _reinforcements: Array = []
var _checkpoint_positions: Array = []
var _last_checkpoint := 0
var _elapsed := 0.0
var _zone_node: Node3D = null
var _convoy: Node3D = null
var _extraction: Node3D = null
var _hostages: Array = []
var _charge_targets: Array = []
var _marked_enemies: Array = []
var _pending_spawn: Array = []
var _spawn_cursor := 0


func _ready() -> void:
	_setup_actions()
	load_data()


func _setup_actions() -> void:
	_add_action("interact", [KEY_E])
	_add_action("throw_grenade", [KEY_G])
	_add_action("heal", [KEY_H])
	_add_action("crouch", [KEY_CTRL])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("cycle_scope", [KEY_V])
	_add_action("switch_vehicle_camera", [KEY_C])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)


func load_data() -> void:
	campaign = _read_array(MISSIONS_PATH, "campaign")
	archetypes = {}
	var parsed := _read_dict(ENEMIES_PATH)
	if parsed.has("archetypes") and typeof(parsed["archetypes"]) == TYPE_DICTIONARY:
		archetypes = parsed["archetypes"]


func _read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}


func _read_array(path: String, key: String) -> Array:
	var data := _read_dict(path)
	if data.has(key) and typeof(data[key]) == TYPE_ARRAY:
		return data[key]
	return []


func mission_count() -> int:
	return campaign.size()


func get_mission(index: int) -> Dictionary:
	if index < 0 or index >= campaign.size():
		return {}
	return campaign[index]


func mission_name(index: int) -> String:
	var mission := get_mission(index)
	return Loc.t(String(mission.get("name_key", "")))


# ------------------------------------------------------------------ البدء
func start_mission(index: int, world: Node3D, player_node: Node3D, points: Array,
		resume: bool = false) -> void:
	stop()
	current_index = index
	current = get_mission(index)
	world_root = world
	player = player_node
	spawn_points = points
	if current.is_empty():
		mission_failed.emit("err_not_found")
		return

	failed_flag = false
	kills = 0
	marked_total = 0
	marked_killed = 0
	hostages_total = 0
	hostages_saved = 0
	hostages_lost = 0
	charges_total = 0
	charges_done = 0
	zone_hold = 0.0
	_elapsed = 0.0
	_last_checkpoint = 0
	_spawn_cursor = 0
	_hostages.clear()
	_charge_targets.clear()
	_marked_enemies.clear()
	_pending_spawn.clear()

	_objective = current.get("objective", {}) if typeof(current.get("objective")) == TYPE_DICTIONARY else {}
	_objective_type = String(_objective.get("type", "eliminate_all"))
	time_left = float(current.get("time_limit", 0))
	is_running = true

	_reinforcements = current.get("reinforcements", []) if typeof(current.get("reinforcements")) == TYPE_ARRAY else []

	_spawn_all_enemies(resume)
	_setup_objective()
	_emit_objective()

	if time_left > 0.0:
		timer_updated.emit(int(time_left))
	else:
		timer_updated.emit(0)


func _spawn_all_enemies(resume: bool) -> void:
	var groups: Array = current.get("enemies", []) if typeof(current.get("enemies")) == TYPE_ARRAY else []
	enemies_total = 0
	enemies_alive = 0
	var checkpoint := SaveSystem.get_checkpoint() if resume else {}
	var skip := 0
	if not checkpoint.is_empty() and int(checkpoint.get("mission", -1)) == current_index:
		skip = int(checkpoint.get("kills", 0))

	for group in groups:
		var count := int(group.get("count", 1))
		for index in count:
			var entry := {
				"archetype": String(group.get("archetype", "rifleman")),
				"difficulty": float(group.get("difficulty", 0.6)),
				"marked": bool(group.get("marked", false)),
				"boss": bool(group.get("boss", false)) or String(group.get("archetype", "")) == "boss"
			}
			enemies_total += 1
			_pending_spawn.append(entry)

	for index in _pending_spawn.size():
		if index < skip:
			continue
		_spawn_enemy(_pending_spawn[index], index)

	# تعزيزات مستقبلية تُحسب في الإجمالي
	for _wave in _reinforcements:
		enemies_total += int(_wave.get("count", 0))

	progress_updated.emit(kills, enemies_total)
	enemies_changed.emit(enemies_alive, enemies_total)


func _spawn_enemy(entry: Dictionary, index: int) -> Node3D:
	var archetype_id := String(entry.get("archetype", "rifleman"))
	var archetype: Dictionary = archetypes.get(archetype_id, {})
	var difficulty := float(entry.get("difficulty", 0.6))

	var enemy := CharacterBody3D.new()
	enemy.set_script(ENEMY_SCRIPT)

	var point := _spawn_point(index)
	enemy.position = point

	enemy.max_health = float(archetype.get("health", 100.0)) * (0.85 + difficulty * 0.45)
	enemy.health = enemy.max_health
	enemy.move_speed = float(archetype.get("speed", 3.4)) * (0.9 + difficulty * 0.25)
	enemy.accuracy = clampf(float(archetype.get("accuracy", 0.6)) * (0.75 + difficulty * 0.45), 0.1, 0.95)
	enemy.attack_damage = float(archetype.get("damage", 9.0)) * (0.8 + difficulty * 0.5)
	enemy.attack_interval = float(archetype.get("attack_interval", 1.35))
	enemy.detection_range = float(archetype.get("detection_range", 55.0))
	enemy.fov_degrees = float(archetype.get("fov", 110.0))
	enemy.hearing_range = float(archetype.get("hearing_range", 34.0))
	enemy.preferred_range = float(archetype.get("preferred_range", 18.0))
	enemy.reaction_time = float(archetype.get("reaction_time", 0.55))
	enemy.cover_usage = float(archetype.get("cover_usage", 0.55))
	enemy.aggression = float(archetype.get("aggression", 0.6))
	enemy.stationary = bool(archetype.get("stationary", false))
	enemy.weapon_id = String(archetype.get("weapon", "rifle_ak"))
	enemy.difficulty = difficulty
	enemy.marked = bool(entry.get("marked", false))
	enemy.is_boss = bool(entry.get("boss", false))
	enemy.target = player
	enemy.display_name = Loc.t(String(archetype.get("name_key", "e_rifleman")))

	enemy.died.connect(_on_enemy_died)
	world_root.add_child(enemy)
	enemy.global_position = point

	if world_root.has_method("get_cover_points"):
		enemy.set_cover_points(world_root.get_cover_points())

	enemies_alive += 1
	if enemy.marked:
		marked_total += 1
		_marked_enemies.append(enemy)
	return enemy


func _spawn_point(index: int) -> Vector3:
	if spawn_points.is_empty():
		return Vector3(randf_range(-30, 30), 1.0, randf_range(-30, 30))
	var base: Vector3 = spawn_points[index % spawn_points.size()]
	return base + Vector3(randf_range(-2.5, 2.5), 0.3, randf_range(-2.5, 2.5))


# --------------------------------------------------------------- الأهداف
func _setup_objective() -> void:
	match _objective_type:
		"rescue_hostages":
			_setup_hostages()
		"escort_convoy":
			_setup_convoy()
		"capture_zone":
			_setup_zone()
		"destroy_targets":
			_setup_charges()
		"survive":
			if time_left <= 0.0:
				time_left = 180.0
		"assassinate":
			if marked_total == 0:
				# في حال لم تُعلَّم المجموعة، اعتبر أول قتيل هدفاً
				marked_total = 1
		_:
			pass


func _setup_hostages() -> void:
	hostages_total = int(_objective.get("hostages", 3))
	var extraction: Array = _objective.get("extraction", [0, 34])
	var origin := Vector3(float(extraction[0]), 0.0, float(extraction[1]))

	_extraction = _make_zone_marker(origin, 7.0, Color(0.3, 1.0, 0.45))

	for index in hostages_total:
		var angle := TAU * float(index) / float(maxi(1, hostages_total))
		var position := Vector3(cos(angle) * 6.0, 0.0, sin(angle) * 6.0) + origin * 0.35
		var hostage := CharacterBody3D.new()
		hostage.set_script(HOSTAGE_SCRIPT)
		world_root.add_child(hostage)
		hostage.global_position = Vector3(position.x, 1.0, position.z)
		hostage.freed.connect(_on_hostage_freed)
		hostage.died.connect(_on_hostage_died)
		_hostages.append(hostage)


func _make_zone_marker(position: Vector3, radius: float, color: Color) -> Node3D:
	var zone := Node3D.new()
	zone.set_script(ZONE_SCRIPT)
	zone.set("radius", radius)
	world_root.add_child(zone)
	zone.global_position = position
	zone.call("setup", radius)
	if zone.get("_material") != null:
		(zone.get("_material") as StandardMaterial3D).albedo_color = color
	return zone


func _setup_convoy() -> void:
	var route_data: Array = _objective.get("route", [])
	var route: Array = []
	for point in route_data:
		if typeof(point) == TYPE_ARRAY and point.size() >= 2:
			route.append(Vector3(float(point[0]), 0.0, float(point[1])))

	if route.is_empty():
		route = [Vector3(0, 0, -40), Vector3(0, 0, 40)]

	_convoy = CharacterBody3D.new()
	_convoy.set_script(VEHICLE_SCRIPT)
	_convoy.set("vehicle_id", "truck_transport")
	world_root.add_child(_convoy)
	_convoy.call("setup", "truck_transport")
	_convoy.global_position = route[0]
	_convoy.set("route", route)
	_convoy.set("route_speed", float(_objective.get("speed", 6.5)))
	_convoy.set("autopilot", true)
	_convoy.set("health", 520.0)
	_convoy.connect("destroyed", _on_convoy_destroyed)


func _setup_zone() -> void:
	var data: Array = _objective.get("zone", [0, 0])
	var radius := float(_objective.get("radius", 10.0))
	_zone_node = Node3D.new()
	_zone_node.set_script(ZONE_SCRIPT)
	world_root.add_child(_zone_node)
	_zone_node.global_position = Vector3(float(data[0]), 0.0, float(data[1]))
	_zone_node.call("setup", radius)
	zone_hold = 0.0


func _setup_charges() -> void:
	charges_total = int(_objective.get("targets", 2))
	var positions: Array = []
	if world_root.has_method("get_charge_positions"):
		positions = world_root.get_charge_positions()
	if positions.is_empty():
		for index in charges_total:
			var angle := TAU * float(index) / float(maxi(1, charges_total))
			positions.append(Vector3(cos(angle) * 18.0, 0.0, sin(angle) * 18.0))

	for index in charges_total:
		var target := StaticBody3D.new()
		target.set_script(CHARGE_SCRIPT)
		world_root.add_child(target)
		target.global_position = positions[index % positions.size()]
		target.connect("destroyed", _on_charge_destroyed)
		_charge_targets.append(target)


# ------------------------------------------------------------------ الأحداث
func _on_enemy_died(enemy: Node, headshot: bool) -> void:
	if not is_running:
		return
	enemies_alive = maxi(0, enemies_alive - 1)
	kills += 1
	progress_updated.emit(kills, enemies_total)
	enemies_changed.emit(enemies_alive, enemies_total)

	if enemy.get("marked") == true:
		marked_killed += 1
		hint.emit(Loc.t("hud_target_down"))

	_check_completion()
	_maybe_checkpoint()


func _on_hostage_freed(hostage: Node) -> void:
	hint.emit(Loc.t("hud_hostage_following"))
	hostage.set_meta("freed", true)


func _on_hostage_died(_hostage: Node) -> void:
	hostages_lost += 1
	if hostages_lost >= hostages_total:
		_finish(false, "reason_hostages_lost")


func _on_charge_destroyed(_target: Node) -> void:
	charges_done += 1
	_emit_objective()
	_check_completion()


func _on_convoy_destroyed() -> void:
	_finish(false, "reason_convoy_destroyed")


# ------------------------------------------------------------------ الحلقة
func _process(delta: float) -> void:
	if not is_running:
		return
	_elapsed += delta

	if time_left > 0.0:
		time_left = maxf(0.0, time_left - delta)
		timer_updated.emit(int(ceil(time_left)))
		if time_left <= 0.0:
			if _objective_type == "survive":
				_finish(true)
			else:
				_finish(false, "reason_timeout")

	_tick_reinforcements(delta)

	match _objective_type:
		"rescue_hostages":
			_tick_hostages()
		"escort_convoy":
			_tick_convoy()
		"capture_zone":
			_tick_zone(delta)
		"assassinate":
			_tick_assassinate()
		"destroy_targets":
			_tick_charges()
		"eliminate_all":
			_tick_eliminate()
		"survive":
			pass


func _tick_eliminate() -> void:
	if enemies_alive <= 0 and _pending_reinforcements_done():
		_finish(true)


func _pending_reinforcements_done() -> bool:
	for wave in _reinforcements:
		if not bool(wave.get("_spawned", false)):
			return false
	return true


func _tick_reinforcements(delta: float) -> void:
	for wave in _reinforcements:
		if bool(wave.get("_spawned", false)):
			continue
		var at_seconds := float(wave.get("at_seconds", 30.0))
		wave["_elapsed"] = float(wave.get("_elapsed", 0.0)) + delta
		if float(wave["_elapsed"]) >= at_seconds:
			wave["_spawned"] = true
			var count := int(wave.get("count", 2))
			for index in count:
				_spawn_enemy({
					"archetype": String(wave.get("archetype", "scout")),
					"difficulty": float(wave.get("difficulty", 0.7))
				}, _spawn_cursor)
				_spawn_cursor += 1
			hint.emit(Loc.t("hud_reinforcements"))


func _tick_hostages() -> void:
	var saved := 0
	for hostage in _hostages:
		if not is_instance_valid(hostage):
			continue
		if bool(hostage.get("rescued")):
			saved += 1
			continue
		if bool(hostage.get("freed_flag")) and _extraction != null:
			if _extraction.call("contains", hostage.global_position):
				hostage.call("mark_rescued")
				saved += 1
	hostages_saved = saved
	if hostages_saved >= hostages_total:
		_finish(true)
	elif hostages_lost >= hostages_total:
		_finish(false, "reason_hostages_lost")
	_emit_objective()


func _tick_convoy() -> void:
	if _convoy == null or not is_instance_valid(_convoy):
		return
	if bool(_convoy.get("destroyed_flag")):
		_finish(false, "reason_convoy_destroyed")
		return
	var route: Array = _convoy.get("route")
	var index := int(_convoy.get("_route_index"))
	if route.size() > 0 and index >= route.size() - 1:
		var last_point: Vector3 = route[route.size() - 1]
		if _convoy.global_position.distance_to(last_point) < 8.0:
			_finish(true)
	_emit_objective()


func _tick_zone(delta: float) -> void:
	if _zone_node == null or player == null:
		return
	var radius := float(_zone_node.get("radius"))
	var inside: bool = _zone_node.call("contains", player.global_position)
	var enemies_inside := 0
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node3D and (node as Node3D).global_position.distance_to(_zone_node.global_position) < radius:
			enemies_inside += 1
	var contested := enemies_inside > 0

	if inside:
		if contested:
			zone_hold = maxf(0.0, zone_hold - delta * 0.5)
		else:
			zone_hold += delta
	else:
		zone_hold = maxf(0.0, zone_hold - delta * 0.7)

	var required := float(_objective.get("hold_time", 45.0))
	var ratio := clampf(zone_hold / maxf(1.0, required), 0.0, 1.0)
	_zone_node.call("set_progress", ratio, contested)
	objective_stage.emit(
		Loc.t("hud_zone_contested") if contested else Loc.t("hud_zone_capturing"),
		ratio)
	if ratio >= 1.0:
		_finish(true)


func _tick_assassinate() -> void:
	if marked_total > 0 and marked_killed >= marked_total:
		_finish(true)
	elif marked_total == 0 and enemies_alive <= 0:
		_finish(true)


func _tick_charges() -> void:
	if charges_total > 0 and charges_done >= charges_total:
		_finish(true)
	_emit_objective()


func _emit_objective() -> void:
	var text := ""
	var ratio := 0.0
	match _objective_type:
		"eliminate_all":
			text = "%s: %d / %d" % [Loc.t("hud_kills"), kills, enemies_total]
			ratio = float(kills) / maxf(1.0, float(enemies_total))
		"survive":
			text = "%s: %s" % [Loc.t("hud_time"), _format_time(int(ceil(time_left)))]
			ratio = 1.0 - clampf(time_left / maxf(1.0, float(current.get("time_limit", 180))), 0.0, 1.0)
		"rescue_hostages":
			text = "%s: %d / %d" % [Loc.t("hud_rescue"), hostages_saved, hostages_total]
			ratio = float(hostages_saved) / maxf(1.0, float(hostages_total))
		"escort_convoy":
			var health := 0.0
			if _convoy != null and is_instance_valid(_convoy):
				health = float(_convoy.get("health")) / maxf(1.0, float(_convoy.get("max_health")))
			text = "%s: %d%%" % [Loc.t("hud_convoy_health"), int(health * 100.0)]
			ratio = health
		"capture_zone":
			text = "%s %d%%" % [Loc.t("hud_zone_capturing"),
					int(clampf(zone_hold / maxf(1.0, float(_objective.get("hold_time", 45.0))), 0.0, 1.0) * 100.0)]
			ratio = clampf(zone_hold / maxf(1.0, float(_objective.get("hold_time", 45.0))), 0.0, 1.0)
		"destroy_targets":
			text = "%s: %d / %d" % [Loc.t("hud_charge_planted"), charges_done, charges_total]
			ratio = float(charges_done) / maxf(1.0, float(charges_total))
		"assassinate":
			text = "%s: %d / %d" % [Loc.t("hud_objective"), marked_killed, marked_total]
			ratio = float(marked_killed) / maxf(1.0, float(marked_total))
	objective_updated.emit(text)
	objective_stage.emit(text, ratio)


func _format_time(total_seconds: int) -> String:
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _check_completion() -> void:
	match _objective_type:
		"eliminate_all":
			_tick_eliminate()
		"assassinate":
			_tick_assassinate()
		"rescue_hostages", "capture_zone", "destroy_targets", "escort_convoy":
			_emit_objective()


# ------------------------------------------------------------- نقاط الحفظ
func _maybe_checkpoint() -> void:
	var total_checkpoints := int(current.get("checkpoints", 1))
	if total_checkpoints <= 0:
		return
	var thresholds := total_checkpoints
	var ratio := float(kills) / maxf(1.0, float(enemies_total))
	var achieved := int(ratio * float(thresholds + 1))
	if achieved <= _last_checkpoint:
		return
	_last_checkpoint = achieved
	SaveSystem.store_checkpoint({
		"mission": current_index,
		"kills": kills,
		"health": float(player.get("health")) if player != null else 100.0,
		"position": [player.global_position.x, player.global_position.y, player.global_position.z]
	} if player != null else {"mission": current_index, "kills": kills})
	hint.emit("✔")


func _finish(success: bool, reason_key: String = "") -> void:
	if not is_running:
		return
	is_running = false
	SaveSystem.clear_checkpoint()
	if success:
		mission_completed.emit(current_index, int(current.get("reward_xp", 150)),
				int(current.get("reward_coins", 60)), String(current.get("unlock_weapon", "")))
	else:
		mission_failed.emit(reason_key if reason_key != "" else "reason_player_died")


func stop() -> void:
	is_running = false
	for node in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(node):
			node.queue_free()
	for hostage in _hostages:
		if is_instance_valid(hostage):
			hostage.queue_free()
	_hostages.clear()
	for target in _charge_targets:
		if is_instance_valid(target):
			target.queue_free()
	_charge_targets.clear()
	if _convoy != null and is_instance_valid(_convoy):
		_convoy.queue_free()
	_convoy = null
	if _zone_node != null and is_instance_valid(_zone_node):
		_zone_node.queue_free()
	_zone_node = null
	if _extraction != null and is_instance_valid(_extraction):
		_extraction.queue_free()
	_extraction = null


func remaining_enemies() -> int:
	return enemies_alive


func objective_type() -> String:
	return _objective_type


func on_player_died() -> void:
	_finish(false, "reason_player_died")
