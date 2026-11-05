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
