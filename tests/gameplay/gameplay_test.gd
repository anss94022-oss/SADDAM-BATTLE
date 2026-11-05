extends Node
## اختبار تشغيل شامل: يحمّل المشهد الرئيسي، يبدأ كل نوع مهمة، يشغّل إطارات،
## ويتحقق من اللاعب والعالم والأعداء والهدف والمركبات والأسلحة والحفظ.
## يُشغّل:  godot --headless --path . --script tests/gameplay/smoke_test.gd

var _failures: Array = []
var main: Node = null


func _ready() -> void:
	_run()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   ", message)
	else:
		print("  FAIL ", message)
		_failures.append(message)


func _frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _physics_frames(count: int) -> void:
	for _index in count:
		await get_tree().physics_frame


func _run() -> void:
	var scene = load("res://scenes/main/main.tscn")
	if scene == null:
		print("SMOKE FAILED: main scene missing")
		get_tree().quit(1)
		return

	main = scene.instantiate()
	add_child(main)
	await _frames(6)

	print("— menu —")
	_check(main.menu != null, "menu built")
	_check(main.hud != null, "hud built")
	_check(SaveSystem.progress.has("level"), "save system loaded")
	_check(WeaponsDB.all_ids().size() >= 12, "weapon database loaded (%d)" % WeaponsDB.all_ids().size())
	_check(VehiclesDB.all_ids().size() >= 10, "vehicle database loaded (%d)" % VehiclesDB.all_ids().size())

	print("— mission 1 (eliminate) —")
	main._start_mission(0)
	await _frames(4)
	await _physics_frames(40)
	_check(main.player != null, "player spawned")
	_check(main.world != null, "world built")
	_check(main.player.health > 0.0, "player alive")
	_check(main.mission_manager.enemies_alive > 0, "enemies spawned (%d)" % main.mission_manager.enemies_alive)
	_check(main.hud._objective_label.text != "", "objective text present")

	print("— weapons —")
	var player = main.player
	var weapon = player.current_weapon()
	_check(not weapon.is_empty(), "weapon equipped: %s" % weapon.get("id", "?"))
	var ammo_before: int = int(weapon["magazine_current"])
	player.is_firing = true
	await _physics_frames(12)
	player.is_firing = false
	_check(int(player.current_weapon()["magazine_current"]) < ammo_before, "firing consumed ammo")
	var mag_after: int = int(player.current_weapon()["magazine_current"])
	player.start_reload()
	await _physics_frames(200)
	_check(int(player.current_weapon()["magazine_current"]) >= mag_after, "reload finished")
	_check(player.weapons.size() >= 3, "multiple weapon slots (%d)" % player.weapons.size())
	player.next_weapon()
	_check(String(player.current_weapon()["id"]) != String(weapon["id"]), "weapon switch works")
	player.choose_weapon("grenade")
	var grenades_before: int = int(player.grenades)
	player.throw_grenade()
	await _frames(2)
	_check(player.grenades == grenades_before - 1, "grenade thrown")

	print("— damage & armor —")
	var health_before: float = float(player.health)
	var armor_before: float = float(player.armor)
	player.take_damage(20.0)
	_check(player.health < health_before or player.armor < armor_before, "damage applied")
	player.armor = 100.0
	player.health = 100.0

	print("— vehicles —")
	main.is_playing = false
	var vehicle = null
	for node in main.vehicles:
		if is_instance_valid(node) and not bool(node.get("destroyed_flag")):
			vehicle = node
			break
	_check(vehicle != null, "vehicle spawned")
	if vehicle != null:
		player.global_position = vehicle.global_position + Vector3(0, 1.0, 0)
		player.enter_vehicle(vehicle, true)
		_check(player.is_in_vehicle(), "player entered vehicle")
		vehicle.throttle = 1.0
		await _physics_frames(60)
		_check(absf(float(vehicle.get("speed"))) > 0.5, "vehicle drives (speed %.1f)" % float(vehicle.get("speed")))
		player.exit_vehicle(true)
		await _frames(2)
		_check(not player.is_in_vehicle(), "player exited vehicle")
		vehicle.take_damage(10000.0)
		await _frames(3)
		_check(not is_instance_valid(vehicle) or bool(vehicle.get("destroyed_flag")), "vehicle destroyed")
		player.alive = true
		player.health = 100.0

	main.is_playing = true
	print("— enemy AI states —")
	var enemy_states := {}
	for node in get_tree().get_nodes_in_group("enemy"):
		if node is Node and node.has_method("state_name"):
			enemy_states[node.state_name()] = true
	_check(enemy_states.size() > 0, "enemy AI running (%s)" % str(enemy_states.keys()))

	print("— mission types —")
	var mission_types := {
		3: "rescue_hostages",
		4: "escort_convoy",
		5: "capture_zone",
		7: "destroy_targets"
	}
	for index in mission_types.keys():
		main._start_mission(index)
		await _frames(3)
		await _physics_frames(20)
		var expected := String(mission_types[index])
		var actual := String(main.mission_manager.objective_type())
		_check(actual == expected, "mission %d objective = %s" % [index + 1, actual])
		_check(main.mission_manager.is_running, "mission %d running" % [index + 1])

	print("— save / load —")
	SaveSystem.store_checkpoint({"mission": 4, "kills": 2, "health": 80.0, "position": [0, 2, 0]})
	_check(not SaveSystem.get_checkpoint().is_empty(), "checkpoint stored")
	SaveSystem.load_progress()
	_check(SaveSystem.get_checkpoint().get("mission") == 4, "checkpoint survives reload")
	SaveSystem.clear_checkpoint()

	print("— audio —")
	_check(AudioServer.get_bus_index("Weapons") >= 0, "audio buses created")
	_check(AudioServer.get_bus_index("Music") >= 0, "music bus created")

	main._cleanup_world()
	await _frames(3)

	if _failures.is_empty():
		print("SMOKE OK — all checks passed")
		get_tree().quit(0)
	else:
		print("SMOKE FAILED: %d issue(s)" % _failures.size())
		for failure in _failures:
			print("   - ", failure)
		get_tree().quit(1)
