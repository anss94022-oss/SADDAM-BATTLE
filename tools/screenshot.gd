extends Node
## أداة تطوير: لقطات من اللعب والقائمة داخل xvfb للتحقق البصري.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var mission := int(args[0]) if args.size() > 0 else 1
	var out := String(args[1]) if args.size() > 1 else "/tmp/shot.png"
	var mode := String(args[2]) if args.size() > 2 else "play"

	var scene = load("res://scenes/main/main.tscn")
	var main = scene.instantiate()
	add_child(main)
	for _i in 10:
		await get_tree().process_frame

	if mode == "menu":
		main.menu.show_main()
		for _i in 30:
			await get_tree().process_frame
	elif mode == "armory":
		main.menu.show_main()
		main.menu.show_armory()
		for _i in 30:
			await get_tree().process_frame
	elif mode == "settings":
		main.menu.show_main()
		main.menu.show_settings()
		for _i in 30:
			await get_tree().process_frame
	elif mode == "city":
		main.menu.hide_all()
		var world_script = load("res://scripts/world/world_builder.gd")
		var world = world_script.new()
		add_child(world)
		world.call("build", "city", "day", "clear")
		var cam := Camera3D.new()
		cam.fov = 62.0
		cam.position = Vector3(0.0, 6.2, 52.0)
		cam.rotation_degrees = Vector3(-3.0, 0.0, 0.0)
		add_child(cam)
		cam.make_current()
		for spec in [[Vector3(-9, 0.2, 34), 0.15, "car_super"],
				[Vector3(9, 0.2, 33), PI - 0.1, "car_super2"],
				[Vector3(-16, 0.2, 44), PI * 0.5, "car_civilian"]]:
			var car := CharacterBody3D.new()
			car.set_script(load("res://scripts/vehicles/vehicle.gd"))
			car.set("vehicle_id", String(spec[2]))
			add_child(car)
			car.global_position = spec[0]
			car.rotation.y = float(spec[1])
		for _i in 45:
			await get_tree().process_frame
	elif mode == "missions":
		main.menu.show_main()
		main.menu.show_missions()
		for _i in 30:
			await get_tree().process_frame
	else:
		main._start_mission(mission)
		for _i in 60:
			await get_tree().process_frame
		if main.hud != null:
			main.hud._touch_layer.visible = true
			main.hud.refresh_layout()
		if main.player != null:
			main.player._yaw = 0.0
			main.player._pitch = -0.12
			main.player.rotation.y = 0.0
		for _i in 20:
			await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	image.save_png(out)
	print("SHOT SAVED ", out)
	get_tree().quit(0)
