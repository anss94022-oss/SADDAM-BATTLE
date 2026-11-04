extends Node3D
class_name WorldBuilder
## بناء ساحات المعركة برمجياً: أرضية، إضاءة، بيئة، تغطية، ومباني.
## كل خريطة لها طابع مختلف (قرية، قاعدة، مصنع، جبل، معسكر تدريب).

const GROUND_SIZE := 160.0

var spawn_points: Array = []
var cover_material: StandardMaterial3D
var accent_material: StandardMaterial3D


func _ready() -> void:
	cover_material = StandardMaterial3D.new()
	cover_material.albedo_color = Color(0.34, 0.33, 0.29)
	cover_material.roughness = 0.95

	accent_material = StandardMaterial3D.new()
	accent_material.albedo_color = Color(0.42, 0.24, 0.16)
	accent_material.roughness = 0.9


func build(map_name: String) -> Array:
	spawn_points.clear()

	_add_environment(map_name)
	_add_ground()
	_add_lighting(map_name)
	_add_boundary()

	match map_name:
		"training":
			_build_training()
		"village":
			_build_village()
		"base":
			_build_base()
		"factory":
			_build_factory()
		"mountain":
			_build_mountain()
		"convoy":
			_build_convoy()
		_:
			_build_training()

	return spawn_points


func _add_environment(map_name: String) -> void:
	var env := Environment.new()

	match map_name:
		"mountain":
			env.background_mode = Environment.BG_SKY
			env.sky = _make_sky(Color(0.42, 0.55, 0.72), Color(0.85, 0.9, 1.0))
			env.ambient_light_color = Color(0.55, 0.62, 0.72)
			env.fog_light_color = Color(0.72, 0.8, 0.9)
			env.fog_density = 0.0035
		"factory":
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.08, 0.07, 0.07)
			env.ambient_light_color = Color(0.32, 0.28, 0.24)
			env.fog_light_color = Color(0.28, 0.22, 0.18)
			env.fog_density = 0.012
		_:
			env.background_mode = Environment.BG_SKY
			env.sky = _make_sky(Color(0.16, 0.28, 0.42), Color(0.9, 0.72, 0.5))
			env.ambient_light_color = Color(0.45, 0.5, 0.58)
			env.fog_light_color = Color(0.6, 0.62, 0.68)
			env.fog_density = 0.006

	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.ssao_enabled = GameSettings.quality == GameSettings.QUALITY_ULTRA
	env.fog_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _make_sky(top: Color, horizon: Color) -> Sky:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_bottom_color = Color(0.16, 0.14, 0.12)
	sky_material.ground_horizon_color = horizon

	var sky := Sky.new()
	sky.sky_material = sky_material
	return sky


func _add_ground() -> void:
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(GROUND_SIZE, 1.0, GROUND_SIZE)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)

	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SIZE, GROUND_SIZE)
	mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.29, 0.24)
	mat.roughness = 1.0
	mat.uv1_scale = Vector3(24, 24, 1)
	mesh.material_override = mat
	ground.add_child(mesh)

	add_child(ground)


func _add_lighting(map_name: String) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -62, 0)
	sun.light_energy = 1.25 if map_name != "factory" else 0.55
	sun.light_color = Color(1.0, 0.95, 0.86) if map_name != "factory" else Color(0.8, 0.7, 0.6)
	sun.shadow_enabled = GameSettings.quality != GameSettings.QUALITY_PERFORMANCE
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	if map_name == "factory":
		for index in 4:
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(-24 + index * 16, 7.0, 0)
			lamp.light_energy = 3.0
			lamp.omni_range = 26.0
			lamp.light_color = Color(1.0, 0.82, 0.55)
			add_child(lamp)


func _add_boundary() -> void:
	var half := GROUND_SIZE * 0.5 - 1.0

	_add_wall(Vector3(0, 4, -half), Vector3(GROUND_SIZE, 8, 1))
	_add_wall(Vector3(0, 4, half), Vector3(GROUND_SIZE, 8, 1))
	_add_wall(Vector3(-half, 4, 0), Vector3(1, 8, GROUND_SIZE))
	_add_wall(Vector3(half, 4, 0), Vector3(1, 8, GROUND_SIZE))


func _add_box(position: Vector3, size: Vector3, color: Color = Color(0.34, 0.33, 0.29)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var mesh_box := BoxMesh.new()
	mesh_box.size = size
	mesh.mesh = mesh_box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mesh.material_override = mat
	body.add_child(mesh)

	add_child(body)
	return body


func _add_wall(position: Vector3, size: Vector3) -> void:
	_add_box(position, size, Color(0.3, 0.29, 0.26))


func _build_training() -> void:
	# حواجز تدريب وأكياس رمل.
	for index in 8:
		var x := -18.0 + index * 5.0
		_add_box(Vector3(x, 0.6, -6.0), Vector3(3.2, 1.2, 1.0), Color(0.42, 0.38, 0.24))

	for index in 6:
		var z := -18.0 + index * 7.0
		_add_box(Vector3(10.0, 0.7, z), Vector3(1.0, 1.4, 3.0), Color(0.38, 0.35, 0.22))
		_add_box(Vector3(-12.0, 0.7, z), Vector3(1.0, 1.4, 3.0), Color(0.38, 0.35, 0.22))

	# أبراج مراقبة خشبية.
	for index in 3:
		_add_box(Vector3(-22.0 + index * 22.0, 1.6, -26.0), Vector3(2.4, 3.2, 2.4), Color(0.3, 0.26, 0.2))
		spawn_points.append(Vector3(-22.0 + index * 22.0, 1.0, -30.0))

	spawn_points.append(Vector3(0, 1.0, -18))
	spawn_points.append(Vector3(16, 1.0, -14))


func _build_village() -> void:
	# منازل قرية بأحجام متفرقة وشوارع ضيقة.
	var houses := [
		Vector3(-20, 0, -16), Vector3(6, 0, -20), Vector3(24, 0, -6),
		Vector3(-14, 0, 12), Vector3(10, 0, 16), Vector3(-4, 0, -2),
		Vector3(28, 0, 18), Vector3(-28, 0, 0)
	]

	for house in houses:
		var height := randf_range(3.2, 5.2)
		_add_box(house + Vector3(0, height * 0.5, 0), Vector3(7, height, 7), Color(0.62, 0.55, 0.44))
		_add_box(house + Vector3(0, height + 0.25, 0), Vector3(7.6, 0.5, 7.6), accent_material.albedo_color)

	for index in 10:
		var x := randf_range(-34, 34)
		var z := randf_range(-34, 34)
		_add_box(Vector3(x, 0.5, z), Vector3(2.2, 1.0, 2.2), Color(0.4, 0.36, 0.3))

	spawn_points.append(Vector3(-24, 1.0, -24))
	spawn_points.append(Vector3(20, 1.0, -26))
	spawn_points.append(Vector3(30, 1.0, 12))
	spawn_points.append(Vector3(-30, 1.0, 6))


func _build_base() -> void:
	# قاعدة عسكرية: مبانٍ مستطيلة، أبراج، وحاويات.
	for index in 5:
		var x := -26.0 + index * 13.0
		_add_box(Vector3(x, 2.4, -24.0), Vector3(10, 4.8, 7), Color(0.32, 0.34, 0.3))

	for index in 4:
		var z := -6.0 + index * 9.0
		_add_box(Vector3(-26.0, 1.3, z), Vector3(4.0, 2.6, 4.0), Color(0.36, 0.42, 0.3))

	for index in 6:
		var x := -20.0 + index * 8.0
		_add_box(Vector3(x, 1.3, 14.0), Vector3(3.0, 2.6, 5.0), Color(0.45, 0.38, 0.24))

	# أبراج حراسة.
	_add_box(Vector3(-34, 3.0, 34), Vector3(5, 6, 5), Color(0.3, 0.31, 0.27))
	_add_box(Vector3(34, 3.0, 34), Vector3(5, 6, 5), Color(0.3, 0.31, 0.27))

	spawn_points.append(Vector3(-30, 1.0, -30))
	spawn_points.append(Vector3(0, 1.0, -32))
	spawn_points.append(Vector3(30, 1.0, -28))
	spawn_points.append(Vector3(-18, 1.0, 8))
	spawn_points.append(Vector3(18, 1.0, 6))


func _build_factory() -> void:
	# مصنع مهجور: خطوط إنتاج، أعمدة، وحاويات معدنية.
	for index in 6:
		var z := -22.0 + index * 8.0
		_add_box(Vector3(-14.0, 1.4, z), Vector3(20, 2.8, 3.0), Color(0.3, 0.3, 0.32))

	for index in 5:
		var x := -24.0 + index * 12.0
		_add_box(Vector3(x, 0.9, 20.0), Vector3(4.0, 1.8, 4.0), Color(0.35, 0.33, 0.3))

	for index in 8:
		var x := -30.0 + index * 8.5
		_add_box(Vector3(x, 4.0, 0.0), Vector3(1.2, 8.0, 1.2), Color(0.24, 0.24, 0.26))

	spawn_points.append(Vector3(-26, 1.0, -18))
	spawn_points.append(Vector3(24, 1.0, -12))
	spawn_points.append(Vector3(0, 1.0, 24))


func _build_mountain() -> void:
	# مرتفعات: تلال متدرجة على الأطراف وصخور كبيرة.
	for index in 7:
		var angle := TAU * float(index) / 7.0
		var radius := 46.0
		var x := cos(angle) * radius
		var z := sin(angle) * radius
		var height := randf_range(6.0, 13.0)
		_add_box(Vector3(x, height * 0.5, z), Vector3(10, height, 10), Color(0.3, 0.31, 0.28))

	for index in 14:
		var x := randf_range(-36, 36)
		var z := randf_range(-36, 36)
		var size := randf_range(1.2, 3.4)
		_add_box(Vector3(x, size * 0.5, z), Vector3(size, size, size), Color(0.36, 0.35, 0.33))

	spawn_points.append(Vector3(-30, 1.0, -30))
	spawn_points.append(Vector3(34, 1.0, -20))
	spawn_points.append(Vector3(26, 1.0, 30))
	spawn_points.append(Vector3(-34, 1.0, 24))


func _build_convoy() -> void:
	# قافلة: شاحنات وستائر حماية على خط مستقيم.
	for index in 5:
		var z := -24.0 + index * 12.0
		_add_box(Vector3(0.0, 1.9, z), Vector3(5.0, 3.2, 10.0), Color(0.34, 0.4, 0.3))
		_add_box(Vector3(0.0, 3.7, z + 3.0), Vector3(4.2, 1.2, 3.6), Color(0.28, 0.33, 0.26))

	for index in 10:
		var z := -30.0 + index * 6.5
		_add_box(Vector3(-12.0, 0.6, z), Vector3(4.4, 1.2, 1.0), Color(0.44, 0.4, 0.26))
		_add_box(Vector3(12.0, 0.6, z), Vector3(4.4, 1.2, 1.0), Color(0.44, 0.4, 0.26))

	spawn_points.append(Vector3(-26, 1.0, -28))
	spawn_points.append(Vector3(26, 1.0, -28))
	spawn_points.append(Vector3(-26, 1.0, 28))
	spawn_points.append(Vector3(26, 1.0, 28))
