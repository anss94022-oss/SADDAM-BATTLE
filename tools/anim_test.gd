extends Node
## أداة تطوير: عرض عدة حركات Mixamo في صورة واحدة للتحقق البصري.

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := String(args[0]) if args.size() > 0 else "/tmp/anim_test.png"
	var path := String(args[1]) if args.size() > 1 else "res://assets/characters/hero_mixamo.glb"

	var ps: PackedScene = load(path)
	var poses := [["idle", 1.0], ["fire", 0.55], ["reload", 1.20]]
	if args.size() > 3:
		poses = [[String(args[2]), float(args[3])]]
	else:
		poses = [["idle", 1.0], ["fire", 0.55], ["reload", 1.20], ["crouch", 0.80]]
	var x := 0.0
	for spec in poses:
		var inst = ps.instantiate()
		inst.position = Vector3(x, 0.0, 0.0)
		x += 1.15
		add_child(inst)
		var ap := inst.find_child("AnimationPlayer", true, false)
		if ap == null:
			print("NO ANIMPLAYER on ", spec[0])
			continue
		print("clips: ", ap.get_animation_list())
		ap.play(spec[0])
		ap.seek(float(spec[1]), true)
		ap.pause()

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.13, 0.15, 0.18)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.58, 0.62)
	e.ambient_light_energy = 1.2
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 38, 0)
	sun.light_energy = 2.0
	add_child(sun)

	var floor_mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 20)
	floor_mesh.mesh = pm
	add_child(floor_mesh)

	var cam := Camera3D.new()
	cam.fov = 42.0
	cam.position = Vector3(x * 0.5 - 0.55, 1.6, 6.4)
	add_child(cam)
	cam.look_at(Vector3(x * 0.5 - 0.6, 1.05, 0.0))
	cam.make_current()

	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out)
	print("saved ", out, " ", img.get_width(), "x", img.get_height())
	get_tree().quit()
