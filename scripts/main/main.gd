extends Node3D
## المنسّق الرئيسي: القوائم، بناء الخريطة، اللاعب، المهمة، والانتقال بينها.

const PLAYER_SCRIPT := preload("res://scripts/player/player.gd")
const HUD_SCRIPT := preload("res://scripts/ui/hud.gd")
const MENU_SCRIPT := preload("res://scripts/ui/menu.gd")
const MISSION_SCRIPT := preload("res://scripts/missions/mission_manager.gd")
const WORLD_SCRIPT := preload("res://scripts/world/world_builder.gd")

var hud: CanvasLayer
var menu: CanvasLayer
var mission_manager: Node
var world: Node3D
var player: Node3D

var current_mission := 0
var is_playing := false
var _play_seconds := 0.0
var _last_kills := 0


func _ready() -> void:
	randomize()
	_setup_input_actions()

	menu = MENU_SCRIPT.new()
	add_child(menu)
	_connect_menu()

	hud = HUD_SCRIPT.new()
	add_child(hud)
	hud.visible = false
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.weapon_pressed.connect(_on_weapon_pressed)
	hud.reload_pressed.connect(_on_reload_pressed)
	hud.jump_pressed.connect(_on_jump_pressed)

	mission_manager = MISSION_SCRIPT.new()
	add_child(mission_manager)
	mission_manager.mission_completed.connect(_on_mission_completed)
	mission_manager.mission_failed.connect(_on_mission_failed)
	mission_manager.progress_updated.connect(_on_progress_updated)

	GameSettings.apply_to_viewport()
	menu.show_main()


func _process(delta: float) -> void:
	if is_playing:
		_play_seconds += delta

		if Input.is_action_just_pressed("pause"):
			_on_pause_pressed()

		# إعادة تعبئة بطيئة للصحة عند البقاء بلا ضرر (توازن اللعب).
		if player != null and is_instance_valid(player):
			if player.health > 0.0 and player.health < player.max_health:
				player.heal(delta * 0.9)

			# حركة لوحة المفاتيح (تعمل مع الحاسب، وتُترك للعصا على اللمس).
			var keyboard_direction := Vector2(
				Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
				Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
			)

			if keyboard_direction != Vector2.ZERO:
				player.set_move_input(keyboard_direction)


# --------------------------------------------------
# إعداد الإجراءات (لا نحتاج Input Map داخل المشروع)
# --------------------------------------------------
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


func _add_action(name: String, keys: Array, mouse_button: int = -1) -> void:
	if not InputMap.has_action(name):
		InputMap.add_action(name)

	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(name, event)

	if mouse_button >= 0:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = mouse_button
		InputMap.action_add_event(name, mouse_event)


func _unhandled_input(event: InputEvent) -> void:
	if not is_playing:
		return

	# إعادة قفل مؤشر الفأرة عند اللعب.
	if event is InputEventMouseButton and event.pressed \
		and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --------------------------------------------------
# قوائم
# --------------------------------------------------
func _connect_menu() -> void:
	menu.new_game_requested.connect(func(): _start_mission(0))
	menu.continue_requested.connect(func():
		_start_mission(clampi(int(SaveSystem.progress.get("best_mission", 0)), 0, 11))
	)
	menu.mission_selected.connect(func(index: int): _start_mission(index))
	menu.resume_requested.connect(_resume_game)
	menu.retry_requested.connect(func(): _start_mission(current_mission))
	menu.next_mission_requested.connect(func():
		_start_mission(mini(current_mission + 1, mission_manager.mission_count() - 1))
	)
	menu.back_to_menu_requested.connect(_back_to_menu)


func _start_mission(index: int) -> void:
	_cleanup_world()

	current_mission = index
	menu.hide_all()

	mission_manager.load_campaign()
	var mission: Dictionary = mission_manager.get_mission(index)

	if mission.is_empty():
		return

	world = WORLD_SCRIPT.new()
	add_child(world)

	var spawn_points: Array = world.build(String(mission.get("map", "training")))

	player = CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 1.2, 18)
	add_child(player)

	var equipped := String(SaveSystem.progress.get("equipped_weapon", "rifle"))
	player.set_weapon_by_id(equipped)

	hud.visible = true
	hud.bind_player(player)
	hud.bind_mission(mission_manager)
	hud.show_message(String(mission.get("name", "")), 3.0)

	_last_kills = 0
	mission_manager.start_mission(index, world, player, spawn_points)

	is_playing = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	SaveSystem.progress["equipped_weapon"] = equipped


func _cleanup_world() -> void:
	get_tree().paused = false
	is_playing = false

	if player != null and is_instance_valid(player):
		player.queue_free()
	player = null

	if world != null and is_instance_valid(world):
		world.queue_free()
	world = null

	if mission_manager != null:
		mission_manager.stop()

	hud.visible = false
	menu.hide_all()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_pause_pressed() -> void:
	if not is_playing:
		return

	get_tree().paused = true
	menu.show_pause()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _resume_game() -> void:
	menu.hide_all()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _back_to_menu() -> void:
	_cleanup_world()
	menu.show_main()


# --------------------------------------------------
# أحداث المهمة
# --------------------------------------------------
func _on_progress_updated(current: int, total: int) -> void:
	# تسجيل القتلى الجدد فقط (حتى لا تتضاعف الخبرة).
	if current > _last_kills:
		for _index in range(current - _last_kills):
			SaveSystem.register_kill(false)
		_last_kills = current
	elif current == 0:
		_last_kills = 0


func _on_mission_completed(index: int, xp: int) -> void:
	is_playing = false
	SaveSystem.progress["play_seconds"] = float(
		SaveSystem.progress.get("play_seconds", 0.0)
	) + _play_seconds
	SaveSystem.save_progress()

	var mission: Dictionary = mission_manager.get_mission(index)
	hud.show_message("تمت المهمة", 2.0)

	await get_tree().create_timer(1.4).timeout

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show_result(true, String(mission.get("name", "")), xp, mission_manager.kills)


func _on_mission_failed(reason: String) -> void:
	is_playing = false
	hud.show_message(reason, 2.0)

	await get_tree().create_timer(1.2).timeout

	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.show_result(false, String(mission_manager.current.get("name", "")), 0, mission_manager.kills)


func _on_weapon_pressed() -> void:
	if player != null and is_instance_valid(player):
		player.next_weapon()


func _on_reload_pressed() -> void:
	if player != null and is_instance_valid(player):
		player.start_reload()


func _on_jump_pressed() -> void:
	if player != null and is_instance_valid(player):
		if player.is_on_floor():
			player.velocity.y = 8.5
