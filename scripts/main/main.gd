extends Node3D
## المنسّق الرئيسي: القوائم، بناء الخريطة، اللاعب، المهمة، المركبات،
## الحملة، اللعب الجماعي، والانتقال بين كل ذلك.

const PLAYER_SCRIPT := preload("res://scripts/player/player.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const MENU_SCRIPT := preload("res://scripts/ui/menu.gd")
const MISSION_SCRIPT := preload("res://scripts/missions/mission_manager.gd")
const WORLD_SCRIPT := preload("res://scripts/world/world_builder.gd")
const VEHICLE_SCRIPT := preload("res://scripts/vehicles/vehicle.gd")

var hud: CanvasLayer
var menu: CanvasLayer
var mission_manager: Node
var world: Node3D
var player: Node3D
var vehicles: Array = []

var current_mission := 0
var is_playing := false
var _play_seconds := 0.0
var _shake := 0.0
var _camera: Camera3D
var _mission_difficulty := 0.6


func _ready() -> void:
	randomize()
	_setup_input_actions()

	menu = MENU_SCRIPT.new()
	add_child(menu)
	_connect_menu()

	mission_manager = MISSION_SCRIPT.new()
	add_child(mission_manager)
	mission_manager.mission_completed.connect(_on_mission_completed)
	mission_manager.mission_failed.connect(_on_mission_failed)

	_rebuild_hud()

	GameSettings.apply_all()
	Loc.language_changed.connect(func(_code: String): _rebuild_hud())
	AudioManager.play_music("menu_theme")
	menu.show_main()


func _rebuild_hud() -> void:
	if hud != null and is_instance_valid(hud):
		hud.queue_free()
	hud = HUD_SCRIPT.new()
	add_child(hud)
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.weapon_pressed.connect(func():
		if player != null: player.next_weapon()
	)
	hud.reload_pressed.connect(func():
		if player != null: player.start_reload()
	)
	hud.jump_pressed.connect(func():
		if player != null and player.is_on_floor() and not player.is_crouching:
			player.velocity.y = 8.2
	)
	hud.crouch_pressed.connect(func():
		if player != null: player.toggle_crouch()
	)
	hud.grenade_pressed.connect(func():
		if player != null: player.throw_grenade()
	)
	hud.heal_pressed.connect(func():
		if player != null and not player.use_medkit():
			hud.show_message(Loc.t("hud_no_ammo"), 1.2)
	)
	hud.interact_pressed.connect(func():
		if player != null: player.interact()
	)
	hud.scope_pressed.connect(func():
		if player != null: player.cycle_scope()
	)
	hud.vehicle_camera_pressed.connect(_cycle_vehicle_camera)
	hud.visible = false


func _connect_menu() -> void:
	menu.new_game_requested.connect(func(): _start_campaign(0))
	menu.continue_requested.connect(_continue_campaign)
	menu.mission_selected.connect(func(index: int): _start_mission(index))
	menu.armory_equip_requested.connect(func(weapon_id: String):
		SaveSystem.equip(weapon_id)
		menu.show_armory()
	)
	menu.armory_unlock_requested.connect(func(weapon_id: String):
		var weapon := WeaponsDB.get_weapon(weapon_id)
		if weapon.is_empty():
			return
		if SaveSystem.unlock_weapon(weapon_id, int(weapon["unlock_cost"])):
			AudioManager.play_ui("ui_confirm")
		else:
			AudioManager.play_ui("ui_fail")
		menu.show_armory()
	)
	menu.resume_requested.connect(_resume_game)
	menu.retry_requested.connect(func(): _start_mission(current_mission))
	menu.next_mission_requested.connect(func():
		_start_mission(mini(current_mission + 1, mission_manager.mission_count() - 1))
	)
	menu.back_to_menu_requested.connect(_back_to_menu)
	menu.touch_editor_requested.connect(_open_touch_editor)
	menu.quit_requested.connect(func(): get_tree().quit())


# ------------------------------------------------------------- المحرك
func _process(delta: float) -> void:
	if not is_playing:
		return
	_play_seconds += delta

	if Input.is_action_just_pressed("pause"):
		_on_pause_pressed()
		return

	if player == null or not is_instance_valid(player):
		return

	if player.is_in_vehicle():
		_drive_vehicle(delta)
	else:
		_walk_input(delta)

	if Input.is_action_just_pressed("interact"):
		player.interact()
	if Input.is_action_just_pressed("throw_grenade"):
		player.throw_grenade()
	if Input.is_action_just_pressed("heal"):
		player.use_medkit()
	if Input.is_action_just_pressed("crouch"):
		player.toggle_crouch()
	if Input.is_action_just_pressed("cycle_scope"):
		player.cycle_scope()
	if Input.is_action_just_pressed("switch_vehicle_camera"):
		_cycle_vehicle_camera()

	# اهتزاز الكاميرا بعد الانفجارات
	if _shake > 0.0 and player.camera != null:
		_shake = maxf(0.0, _shake - delta * 2.6)
		var offset := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.09
		player.camera.h_offset = offset.x
		player.camera.v_offset = offset.y


func _walk_input(_delta: float) -> void:
	var direction := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	if direction.length() > 1.0:
		direction = direction.normalized()
	player.set_move_input(direction)
	player.set_sprinting(Input.is_action_pressed("sprint"))
	player.set_firing(Input.is_action_pressed("fire"))
	if Input.is_action_just_pressed("aim"):
		player.set_aiming(true)
	if Input.is_action_just_released("aim"):
		player.set_aiming(false)


func _drive_vehicle(delta: float) -> void:
	var vehicle = player.current_vehicle
	if vehicle == null or not is_instance_valid(vehicle):
		return
	if vehicle.get("is_air") == true:
		var move := Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
		)
		var vertical := 0.0
		if Input.is_action_pressed("jump"):
			vertical = 1.0
		elif Input.is_action_pressed("crouch"):
			vertical = -1.0
		vehicle.call("set_flight_input", move, 1.0)
		vehicle.set("throttle", vertical)
		vehicle.set("steer", Input.get_action_strength("move_right") -
				Input.get_action_strength("move_left"))
	else:
		var throttle := 0.0
		if Input.is_action_pressed("move_forward"):
			throttle = 1.0
		elif Input.is_action_pressed("move_back"):
			throttle = -1.0
		vehicle.set("throttle", throttle)
		vehicle.set("steer", Input.get_action_strength("move_right") -
				Input.get_action_strength("move_left"))
		vehicle.set("brake_input", 0.0)
		if Input.is_action_pressed("jump"):
			vehicle.set("brake_input", 1.0)
	vehicle.set("_remote_fire", Input.is_action_pressed("fire"))
	SaveSystem.add_driving_time(delta)


func _cycle_vehicle_camera() -> void:
	if player != null and player.is_in_vehicle() and player.current_vehicle != null:
		if player.current_vehicle.has_method("cycle_camera"):
			player.current_vehicle.cycle_camera()


func _setup_input_actions() -> void:
	_add_action("move_forward", [KEY_W, KEY_UP])
	_add_action("move_back", [KEY_S, KEY_DOWN])
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE])
	_add_action("fire", [], MOUSE_BUTTON_LEFT)
	_add_action("aim", [], MOUSE_BUTTON_RIGHT)
	_add_action("reload", [KEY_R])
	_add_action("next_weapon", [KEY_Q])
	_add_action("pause", [KEY_ESCAPE])
	_add_action("sprint", [KEY_SHIFT])
	_add_action("crouch", [KEY_CTRL])
	_add_action("interact", [KEY_E])
	_add_action("throw_grenade", [KEY_G])
	_add_action("heal", [KEY_H])
	_add_action("cycle_scope", [KEY_V])
	_add_action("switch_vehicle_camera", [KEY_C])


func _add_action(action: String, keys: Array, mouse_button: int = -1) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if mouse_button >= 0:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = mouse_button
		InputMap.action_add_event(action, mouse_event)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return
	if event is InputEventMouseButton and event.pressed \
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------- الحملة
func _start_campaign(index: int) -> void:
	_start_mission(index)


func _continue_campaign() -> void:
	var checkpoint := SaveSystem.get_checkpoint()
	if not checkpoint.is_empty() and checkpoint.has("mission"):
		_start_mission(int(checkpoint["mission"]), true)
		return
	var best := clampi(int(SaveSystem.progress.get("best_mission", 0)), 0,
			maxi(0, mission_manager.mission_count() - 1))
	_start_mission(best)


func _start_mission(index: int, resume: bool = false) -> void:
	_cleanup_world()
	current_mission = index
	menu.hide_all()

	mission_manager.load_data()
	var mission: Dictionary = mission_manager.get_mission(index)
	if mission.is_empty():
		menu.show_main()
		return

	var map_name := String(mission.get("map", "training"))
	world = WORLD_SCRIPT.new()
	add_child(world)
	var spawn_points: Array = world.call("build", map_name,
			String(mission.get("time_of_day", "day")), String(mission.get("weather", "clear")))

	var spawn: Vector3 = world.call("get_player_spawn")
	var checkpoint := SaveSystem.get_checkpoint() if resume else {}
	if not checkpoint.is_empty() and checkpoint.has("position"):
		var saved_position: Array = checkpoint["position"]
		if saved_position.size() >= 3:
			spawn = Vector3(float(saved_position[0]), float(saved_position[1]),
					float(saved_position[2]))

	# سلاح المهمة (مثل مهمة القنص) يُجهّز قبل إنشاء اللاعب
	var forced_weapon := String(mission.get("player_weapon", ""))
	if forced_weapon != "" and SaveSystem.is_weapon_unlocked(forced_weapon):
		SaveSystem.equip(forced_weapon)

	player = CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	add_child(player)
	player.global_position = spawn
	player.display_name = String(SaveSystem.progress.get("player_name", ""))
	player.team = 0

	if not checkpoint.is_empty() and checkpoint.has("health"):
		player.health = clampf(float(checkpoint["health"]), 30.0, player.max_health)

	player.player_died.connect(_on_player_died)
	player.killed_enemy.connect(_on_enemy_killed)
	player.entered_vehicle.connect(func(_vehicle): hud.show_message(Loc.t("hud_exit_vehicle"), 1.2))

	_spawn_vehicles(map_name, spawn)

	hud.visible = true
	hud.bind_player(player, mission_manager)
	hud.bind_mission(mission_manager)
	hud.show_message(Loc.t(String(mission.get("name_key", ""))), 3.0)

	mission_manager.start_mission(index, world, player, spawn_points, resume)

	is_playing = true
	_play_seconds = 0.0
	get_tree().paused = false
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	AudioManager.play_music("battle_theme")
	AudioManager.play_ambience("ambience_wind_loop" if String(mission.get("time_of_day", "day")) != "night"
			else "ambience_night_loop")


func _spawn_vehicles(map_name: String, origin: Vector3) -> void:
	vehicles.clear()
	var layout: Array = []
	match map_name:
		"training":
			layout = ["car_4x4", "bike_military"]
		"village":
			layout = ["car_civilian", "bike_civilian", "truck_transport"]
		"base":
			layout = ["armored_apc", "car_4x4", "heli_transport"]
		"factory":
			layout = ["truck_supply", "bike_military"]
		"mountain":
			layout = ["recon_buggy", "bike_military"]
		"convoy":
			layout = ["technicals", "truck_transport"]
		_:
			layout = ["car_civilian"]

	var offsets := [Vector3(7, 0.4, -6), Vector3(-8, 0.4, -8), Vector3(12, 0.4, -14)]
	for index in layout.size():
		var vehicle_id := String(layout[index])
		var vehicle := CharacterBody3D.new()
		vehicle.set_script(VEHICLE_SCRIPT)
		vehicle.set("vehicle_id", vehicle_id)
		add_child(vehicle)
		var offset: Vector3 = offsets[index % offsets.size()]
		vehicle.global_position = origin + offset
		vehicle.rotation.y = randf_range(-PI, PI)
		vehicles.append(vehicle)


func _cleanup_world() -> void:
	get_tree().paused = false
	is_playing = false

	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null

	if mission_manager != null:
		mission_manager.stop()

	if world != null and is_instance_valid(world):
		world.queue_free()
	world = null

	for vehicle in vehicles:
		if is_instance_valid(vehicle):
			vehicle.queue_free()
	vehicles.clear()

	if hud != null:
		hud.visible = false
	menu.hide_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.stop_ambience()


func _on_pause_pressed() -> void:
	if not is_playing:
		return
	if menu.current_panel() == "pause":
		_resume_game()
		return
	get_tree().paused = true
	is_playing = false
	menu.show_pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	menu.hide_all()
	get_tree().paused = false
	is_playing = true
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _back_to_menu() -> void:
	_cleanup_world()
	menu.show_main()
	AudioManager.play_music("menu_theme")


func _open_touch_editor() -> void:
	_hide_menu_keep_state()


func _hide_menu_keep_state() -> void:
	menu.hide_all()
	if hud != null:
		hud.call("set_edit_mode", true)


# ---------------------------------------------------------------- الأحداث
func _on_player_died() -> void:
	mission_manager.on_player_died()


func _on_enemy_killed(_enemy: Node, headshot: bool) -> void:
	if hud != null:
		hud.add_killfeed("☠ " + ("HEADSHOT" if headshot else "KILL"))


func on_explosion(position: Vector3, _radius: float) -> void:
	if player == null or player.camera == null:
		return
	var distance := player.global_position.distance_to(position)
	_shake = clampf(1.0 - distance / 40.0, 0.0, 1.0)


func _on_mission_completed(index: int, xp: int, coins: int, unlock_id: String) -> void:
	is_playing = false
	SaveSystem.add_play_time(_play_seconds)
	var reward := SaveSystem.complete_mission(index, xp, coins, unlock_id)
	if hud != null and player != null:
		if player.health >= player.max_health:
			SaveSystem.unlock_achievement("untouchable")
		if mission_manager.hostages_lost == 0 and mission_manager.objective_type() == "rescue_hostages":
			SaveSystem.unlock_achievement("survivor")
	hud.show_message(Loc.t("result_success"), 2.0)

	await get_tree().create_timer(1.3).timeout
	get_tree().paused = true
	menu.show_result(true, mission_manager.mission_name(index), {
		"kills": mission_manager.kills,
		"headshots": player.headshots if player != null else 0,
		"xp": xp, "coins": coins, "level": reward.get("level", 1),
		"unlock": unlock_id
	})
	AudioManager.play_ui("ui_confirm")


func _on_mission_failed(reason_key: String) -> void:
	if not is_playing and not get_tree().paused:
		return
	is_playing = false
	hud.show_message(Loc.t(reason_key), 2.0)
	AudioManager.play_ui("ui_fail")

	await get_tree().create_timer(1.4).timeout
	get_tree().paused = true
	menu.show_result(false, mission_manager.mission_name(current_mission), {
		"kills": mission_manager.kills,
		"headshots": player.headshots if player != null else 0,
		"xp": 0, "coins": 0, "level": int(SaveSystem.progress.get("level", 1)),
		"reason": Loc.t(reason_key)
	})
