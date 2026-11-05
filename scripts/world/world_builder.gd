extends Node3D
class_name WorldBuilder
## بناء الخرائط برمجياً بخامات مولّدة: أرضية، مبانٍ، أغطية، إضاءة نهارية/ليلية،
## طقس (غبار/رياح)، ونقاط انتشار/أغطية/أهداف جاهزة للمهام.

const GROUND_SIZE := 190.0
const TEX := "res://assets/textures/"

var spawn_points: Array = []
var cover_points: Array = []
var charge_positions: Array = []
var hostage_positions: Array = []
var player_spawn := Vector3(0, 1.2, 20)
var _materials: Dictionary = {}
var _props: Array = []
var _time_of_day := "day"
var _weather := "clear"
var _sun: DirectionalLight3D
var _env: Environment
var _dust: CPUParticles3D


func build(map_name: String, time_of_day: String = "day", weather: String = "clear") -> Array:
	_time_of_day = time_of_day
	_weather = weather
	spawn_points.clear()
	cover_points.clear()
	charge_positions.clear()
	hostage_positions.clear()

	_add_environment()
	_add_ground(map_name)
	_add_lighting()
	_add_boundary(map_name)
	_add_weather()

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

	if charge_positions.is_empty():
		charge_positions = [Vector3(-18, 0, -14), Vector3(18, 0, -10),
				Vector3(0, 0, -22), Vector3(24, 0, 16)]
	if hostage_positions.is_empty():
		hostage_positions = [Vector3(-8, 0, 8), Vector3(6, 0, 10), Vector3(0, 0, 4)]

	return spawn_points


# --------------------------------------------------------------- الخامات
func _texture(name: String) -> Texture2D:
	var path := TEX + name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _material(texture_name: String, uv_scale: float = 1.0, tint: Color = Color.WHITE,
		roughness: float = 0.9) -> StandardMaterial3D:
	var key := "%s_%.1f_%s" % [texture_name, uv_scale, tint.to_html()]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	var albedo := _texture(texture_name)
	if albedo != null:
		mat.albedo_texture = albedo
		mat.uv1_scale = Vector3(uv_scale, uv_scale, 1.0)
		var normal := _texture(texture_name + "_normal")
		if normal != null:
			mat.normal_enabled = true
			mat.normal_texture = normal
			mat.normal_scale = 0.9
	mat.albedo_color = tint
	mat.roughness = roughness
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = mat
	return mat


# ------------------------------------------------------------- البيئة
func _add_environment() -> void:
	_env = Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()

	var top := Color(0.16, 0.30, 0.48)
	var horizon := Color(0.82, 0.72, 0.55)
	var ambient := Color(0.45, 0.50, 0.58)

	match _time_of_day:
		"dusk":
			top = Color(0.18, 0.16, 0.34)
			horizon = Color(0.92, 0.48, 0.28)
			ambient = Color(0.42, 0.36, 0.38)
		"night":
			top = Color(0.02, 0.04, 0.10)
			horizon = Color(0.08, 0.10, 0.18)
			ambient = Color(0.16, 0.19, 0.28)

	sky_material.sky_top_color = top
	sky_material.sky_horizon_color = horizon
	sky_material.ground_bottom_color = Color(0.12, 0.11, 0.10)
	sky_material.ground_horizon_color = horizon
	sky.sky_material = sky_material

	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_color = ambient
	_env.ambient_light_energy = 0.85 if _time_of_day != "night" else 0.35
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 0.78
	_env.glow_enabled = not GameSettings.is_performance()
	_env.glow_intensity = 0.45
	_env.ssao_enabled = false
	_env.fog_enabled = true
	_env.fog_density = 0.006
	_env.fog_light_color = horizon.lerp(Color(0.9, 0.8, 0.65), 0.4)

	if _weather == "dust" or _weather == "wind":
		_env.fog_density = 0.016 if _weather == "dust" else 0.010
		_env.fog_light_color = Color(0.78, 0.68, 0.50)
	elif _time_of_day == "night":
		_env.fog_density = 0.012

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)


func _add_ground(map_name: String) -> void:
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
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	mesh.mesh = plane

	var texture_name := "sand"
	var tint := Color(0.86, 0.80, 0.68)
	match map_name:
		"factory":
			texture_name = "asphalt"
		"base":
			texture_name = "sand_rock"
		"mountain":
			texture_name = "sand_rock"
			tint = Color(0.95, 0.93, 0.9)
		"village":
			texture_name = "sand"
	mesh.material_override = _material(texture_name, 26.0, tint, 1.0)
	ground.add_child(mesh)
	add_child(ground)


func _add_lighting() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = GameSettings.shadows_enabled
	_sun.directional_shadow_max_distance = 110.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if not GameSettings.is_performance() \
			else DirectionalLight3D.SHADOW_ORTHOGONAL

	match _time_of_day:
		"dusk":
			_sun.rotation_degrees = Vector3(-14, -128, 0)
			_sun.light_color = Color(1.0, 0.62, 0.36)
			_sun.light_energy = 1.15
		"night":
			_sun.rotation_degrees = Vector3(-58, 40, 0)
			_sun.light_color = Color(0.45, 0.55, 0.85)
			_sun.light_energy = 0.35
		_:
			_sun.rotation_degrees = Vector3(-52, -58, 0)
			_sun.light_color = Color(1.0, 0.95, 0.86)
			_sun.light_energy = 1.15
	add_child(_sun)


func _add_weather() -> void:
	if _weather == "clear" and _time_of_day != "night":
		return
	if not GameSettings.has_renderer():
		return
	_dust = CPUParticles3D.new()
	_dust.emitting = true
	_dust.amount = 90 if _weather == "dust" else 40
	_dust.lifetime = 4.0
	_dust.preprocess = 2.0
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(45, 8, 45)
	_dust.direction = Vector3(1, 0.1, 0.3)
	_dust.spread = 20.0
	_dust.gravity = Vector3(0.4, -0.2, 0.1)
	_dust.initial_velocity_min = 1.2
	_dust.initial_velocity_max = 4.0
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.6
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.82, 0.74, 0.58, 0.35 if _weather == "dust" else 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _texture("sand")
	mesh.material = mat
	_dust.mesh = mesh
	add_child(_dust)


func _add_boundary(map_name: String) -> void:
	var half := GROUND_SIZE * 0.5 - 2.0
	var texture := "rock" if map_name == "mountain" else "concrete"
	var material := _material(texture, 8.0, Color(0.8, 0.78, 0.72))
	for side in 4:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size := Vector3(GROUND_SIZE, 14.0, 2.0)
		var position := Vector3.ZERO
		if side < 2:
			position = Vector3(0, 7.0, -half if side == 0 else half)
		else:
			size = Vector3(2.0, 14.0, GROUND_SIZE)
			position = Vector3(-half if side == 2 else half, 7.0, 0)
		box.size = size
		mesh.mesh = box
		mesh.position = position
		mesh.material_override = material
		add_child(mesh)

		var body := StaticBody3D.new()
		body.collision_layer = 1
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		body.position = position
		add_child(body)


# ------------------------------------------------------------- عناصر مشتركة
func _prop_box(position: Vector3, size: Vector3, texture_name: String,
		tint: Color = Color.WHITE, uv_scale: float = 1.0, adds_cover: bool = true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = _material(texture_name, uv_scale, tint)
	body.add_child(mesh)

	if GameSettings.is_performance():
		mesh.visibility_range_end = 140.0

	add_child(body)
	_props.append(body)
	if adds_cover:
		cover_points.append(position + Vector3(0, 0, size.z * 0.5 + 0.9))
		cover_points.append(position + Vector3(0, 0, -size.z * 0.5 - 0.9))
		cover_points.append(position + Vector3(size.x * 0.5 + 0.9, 0, 0))
		cover_points.append(position + Vector3(-size.x * 0.5 - 0.9, 0, 0))
	return body


func _building(center: Vector3, size: Vector3, texture_name: String,
		roof_texture: String, tint: Color, rotation: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = center
	body.rotation.y = rotation

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)

	var walls := MeshInstance3D.new()
	var walls_mesh := BoxMesh.new()
	walls_mesh.size = size
	walls.mesh = walls_mesh
	walls.material_override = _material(texture_name, maxf(1.0, size.x / 4.0), tint)
	body.add_child(walls)

	var roof := MeshInstance3D.new()
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(size.x + 0.5, 0.35, size.z + 0.5)
	roof.mesh = roof_mesh
	roof.position = Vector3(0, size.y * 0.5 + 0.17, 0)
	roof.material_override = _material(roof_texture, 2.0, Color(0.75, 0.72, 0.68))
	body.add_child(roof)

	# نوافذ مضيئة ليلاً
	if _time_of_day != "day":
		for index in 2:
			var lamp := OmniLight3D.new()
			lamp.light_color = Color(1.0, 0.82, 0.55)
			lamp.light_energy = 1.4
			lamp.omni_range = 9.0
			lamp.position = Vector3(randf_range(-size.x * 0.3, size.x * 0.3),
					size.y * 0.2, size.z * 0.5 + 0.4)
			body.add_child(lamp)

	add_child(body)
	_props.append(body)
	var forward := Vector3(sin(rotation), 0, cos(rotation))
	cover_points.append(center + forward * (size.z * 0.5 + 1.0))
	cover_points.append(center - forward * (size.z * 0.5 + 1.0))
	cover_points.append(center + forward.cross(Vector3.UP) * (size.x * 0.5 + 1.0))


func _crate(position: Vector3, size: float = 1.2) -> void:
	_prop_box(position + Vector3(0, size * 0.5, 0), Vector3(size, size, size), "wood",
			Color(0.95, 0.9, 0.8), 1.0)


func _barrel(position: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position + Vector3(0, 0.55, 0)

	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.35
	cylinder.height = 1.1
	shape.shape = cylinder
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = 0.34
	cylinder_mesh.bottom_radius = 0.34
	cylinder_mesh.height = 1.1
	mesh.mesh = cylinder_mesh
	var colors := [Color(0.55, 0.25, 0.18), Color(0.32, 0.36, 0.28), Color(0.28, 0.30, 0.34)]
	mesh.material_override = _material("metal", 1.0, colors[randi() % colors.size()])
	body.add_child(mesh)

	add_child(body)
	cover_points.append(position + Vector3(1.0, 0, 0))


func _sandbag_line(start: Vector3, count: int, direction: Vector3) -> void:
	for index in count:
		var position := start + direction * float(index) * 1.3
		_prop_box(position + Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 0.8), "sand",
				Color(0.85, 0.78, 0.62), 1.0, index % 2 == 0)


func _palm(position: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.18
	cylinder.bottom_radius = 0.26
	cylinder.height = 6.5
	trunk.mesh = cylinder
	trunk.position = position + Vector3(0, 3.25, 0)
	trunk.material_override = _material("wood", 1.0, Color(0.8, 0.7, 0.55))
	add_child(trunk)

	for index in 7:
		var leaf := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.35, 0.12, 2.6)
		leaf.mesh = box
		leaf.position = position + Vector3(0, 6.4, 0)
		leaf.rotation_degrees.y = index * (360.0 / 7.0)
		leaf.rotation_degrees.x = -24.0
		leaf.translate_object_local(Vector3(0, 0, -1.2))
		leaf.material_override = _material("camo", 1.0, Color(0.55, 0.65, 0.35))
		add_child(leaf)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position + Vector3(0, 3, 0)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 6.0
	shape.shape = capsule
	body.add_child(shape)
	add_child(body)
	cover_points.append(position + Vector3(1.2, 0, 0))


func _tower(position: Vector3) -> void:
	_prop_box(position + Vector3(0, 2.2, 0), Vector3(2.6, 4.4, 2.6), "concrete",
			Color(0.85, 0.83, 0.78), 1.0)
	_prop_box(position + Vector3(0, 4.8, 0), Vector3(3.4, 0.5, 3.4), "wood",
			Color(0.8, 0.75, 0.65), 1.0, false)
	spawn_points.append(position + Vector3(0, 1.2, 0))


func _vehicle_prop(position: Vector3, rotation: float = 0.0) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position
	body.rotation.y = rotation

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 1.7, 4.6)
	shape.shape = box
	shape.position = Vector3(0, 0.85, 0)
	body.add_child(shape)

	var hull := MeshInstance3D.new()
	var hull_mesh := BoxMesh.new()
	hull_mesh.size = Vector3(2.1, 1.1, 4.4)
	hull.mesh = hull_mesh
	hull.position = Vector3(0, 0.75, 0)
	hull.material_override = _material("metal", 1.5, Color(0.55, 0.52, 0.40))
	body.add_child(hull)

	var cab := MeshInstance3D.new()
	var cab_mesh := BoxMesh.new()
	cab_mesh.size = Vector3(1.9, 0.9, 1.8)
	cab.mesh = cab_mesh
	cab.position = Vector3(0, 1.6, -0.6)
	cab.material_override = _material("metal", 1.2, Color(0.45, 0.44, 0.36))
	body.add_child(cab)

	add_child(body)
	cover_points.append(position + Vector3(2.2, 0, 0))
	cover_points.append(position + Vector3(-2.2, 0, 0))


# --------------------------------------------------------------- الخرائط
func _build_training() -> void:
	player_spawn = Vector3(0, 1.2, 26)
	# حواجز تدريب
	for index in 8:
		var x := -21.0 + index * 6.0
		_prop_box(Vector3(x, 0.6, 2.0), Vector3(4.0, 1.2, 1.1), "concrete",
				Color(0.86, 0.84, 0.78), 1.6)
	for index in 5:
		_sandbag_line(Vector3(-16, 0, -8 - index * 4), 4, Vector3(1, 0, 0))
	for index in 3:
		_tower(Vector3(-24.0 + index * 24.0, 0, -26.0))
	for index in 6:
		_crate(Vector3(randf_range(-30, 30), 0, randf_range(-24, 18)), randf_range(0.9, 1.4))
	for index in 4:
		_palm(Vector3(randf_range(-36, 36), 0, randf_range(6, 34)))
	for index in 5:
		_barrel(Vector3(randf_range(-20, 20), 0, randf_range(-20, -6)))
	spawn_points.append(Vector3(0, 1.0, -20))
	spawn_points.append(Vector3(16, 1.0, -16))
	spawn_points.append(Vector3(-16, 1.0, -14))
	charge_positions = [Vector3(-20, 0, -18), Vector3(20, 0, -18), Vector3(0, 0, -26)]
	hostage_positions = [Vector3(-6, 0, 6), Vector3(6, 0, 6), Vector3(0, 0, 12)]


func _build_village() -> void:
	player_spawn = Vector3(0, 1.2, 34)
	var houses := [
		[Vector3(-22, 0, -18), Vector3(9, 5.0, 8)],
		[Vector3(8, 0, -22), Vector3(8, 4.2, 9)],
		[Vector3(26, 0, -6), Vector3(10, 5.6, 8)],
		[Vector3(-16, 0, 10), Vector3(8, 3.8, 7)],
		[Vector3(14, 0, 12), Vector3(9, 4.6, 8)],
		[Vector3(-30, 0, 2), Vector3(7, 4.0, 9)],
		[Vector3(2, 0, -2), Vector3(6, 3.2, 6)],
		[Vector3(30, 0, 22), Vector3(8, 4.4, 7)]
	]
	var index := 0
	for house in houses:
		var center: Vector3 = house[0] + Vector3(0, float(house[1].y) * 0.5, 0)
		var tint := Color(0.98, 0.92, 0.84) if index % 2 == 0 else Color(0.90, 0.84, 0.76)
		_building(center, house[1], "plaster", "wood", tint, randf_range(-0.15, 0.15))
		spawn_points.append(house[0] + Vector3(0, 1.0, -6.0))
		index += 1

	for index2 in 12:
		_crate(Vector3(randf_range(-34, 34), 0, randf_range(-30, 26)), randf_range(0.8, 1.3))
	for index3 in 8:
		_barrel(Vector3(randf_range(-30, 30), 0, randf_range(-26, 26)))
	for index4 in 6:
		_palm(Vector3(randf_range(-34, 34), 0, randf_range(-28, 28)))
	for index5 in 4:
		_sandbag_line(Vector3(-10 + index5 * 8, 0, -30), 4, Vector3(1, 0, 0))

	spawn_points.append(Vector3(-24, 1.0, -26))
	spawn_points.append(Vector3(22, 1.0, -28))
	spawn_points.append(Vector3(28, 1.0, 14))
	charge_positions = [Vector3(-20, 0, -10), Vector3(18, 0, 2), Vector3(0, 0, 22)]
	hostage_positions = [Vector3(-12, 0, 2), Vector3(4, 0, 20), Vector3(20, 0, 6)]


func _build_base() -> void:
	player_spawn = Vector3(0, 1.2, 40)
	# ثكنات
	for index in 5:
		var x := -30.0 + index * 15.0
		_building(Vector3(x, 2.8, -26.0), Vector3(11, 5.6, 8), "concrete", "metal",
				Color(0.80, 0.80, 0.74))
		spawn_points.append(Vector3(x, 1.0, -34))
	# مستودعات جانبية
	for index2 in 4:
		_prop_box(Vector3(-32.0, 1.6, -6.0 + index2 * 10.0), Vector3(6, 3.2, 6), "metal",
				Color(0.62, 0.60, 0.50), 1.6)
	for index3 in 6:
		_prop_box(Vector3(-20.0 + index3 * 8.0, 1.4, 18.0), Vector3(4.0, 2.8, 5.0), "metal",
				Color(0.58, 0.56, 0.48), 1.4)
	# أبراج حراسة
	_tower(Vector3(-36, 0, 36))
	_tower(Vector3(36, 0, 36))
	_tower(Vector3(0, 0, -2))
	# سواتر ومركبات
	for index4 in 5:
		_sandbag_line(Vector3(-18 + index4 * 9, 0, 6), 4, Vector3(1, 0, 0))
	_vehicle_prop(Vector3(-8, 0, 24), 0.3)
	_vehicle_prop(Vector3(12, 0, 28), -0.2)
	for index5 in 6:
		_barrel(Vector3(randf_range(-30, 30), 0, randf_range(-20, 20)))
	for index6 in 6:
		_crate(Vector3(randf_range(-30, 30), 0, randf_range(-20, 30)))

	spawn_points.append(Vector3(-26, 1.0, -34))
	spawn_points.append(Vector3(26, 1.0, -34))
	spawn_points.append(Vector3(0, 1.0, -12))
	charge_positions = [Vector3(-32, 0, -6), Vector3(-32, 0, 14), Vector3(20, 0, 18),
			Vector3(0, 0, 20)]
	hostage_positions = [Vector3(-6, 0, 8), Vector3(6, 0, 8), Vector3(0, 0, 2)]


func _build_factory() -> void:
	player_spawn = Vector3(0, 1.2, 38)
	# خطوط إنتاج وأعمدة
	for index in 6:
		var z := -24.0 + index * 8.0
		_prop_box(Vector3(-14.0, 1.3, z), Vector3(22, 2.6, 3.0), "metal",
				Color(0.55, 0.54, 0.50), 2.0)
	for index2 in 8:
		var x := -30.0 + index2 * 8.5
		_prop_box(Vector3(x, 4.0, 0.0), Vector3(1.2, 8.0, 1.2), "concrete",
				Color(0.62, 0.62, 0.58), 1.2, false)
	# مخازن
	for index3 in 4:
		_prop_box(Vector3(-24.0 + index3 * 16.0, 1.8, 20.0), Vector3(6.0, 3.6, 6.0), "metal",
				Color(0.50, 0.52, 0.48), 1.8)
	for index4 in 8:
		_barrel(Vector3(randf_range(-32, 32), 0, randf_range(-20, 26)))
	for index5 in 6:
		_crate(Vector3(randf_range(-30, 30), 0, randf_range(-26, 26)), randf_range(1.0, 1.5))
	_vehicle_prop(Vector3(-20, 0, 6), 1.2)
	_vehicle_prop(Vector3(20, 0, -8), -0.6)

	spawn_points.append(Vector3(-26, 1.0, -20))
	spawn_points.append(Vector3(24, 1.0, -14))
	spawn_points.append(Vector3(0, 1.0, -26))
	spawn_points.append(Vector3(30, 1.0, 8))
	charge_positions = [Vector3(-24, 0, 20), Vector3(-8, 0, 20), Vector3(8, 0, 20),
			Vector3(24, 0, 20)]
	hostage_positions = [Vector3(-4, 0, 10), Vector3(4, 0, 10), Vector3(0, 0, 16)]

	# إضاءة صناعية داخلية
	for index6 in 5:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.85, 0.6)
		lamp.light_energy = 3.0
		lamp.omni_range = 26.0
		lamp.position = Vector3(-24 + index6 * 12, 7.0, 0)
		add_child(lamp)


func _build_mountain() -> void:
	player_spawn = Vector3(0, 1.2, 40)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var radius := 52.0
		var height := randf_range(9.0, 17.0)
		_prop_box(Vector3(cos(angle) * radius, height * 0.5, sin(angle) * radius),
				Vector3(16, height, 16), "rock", Color(0.92, 0.9, 0.86), 3.0)
	for index2 in 18:
		var size := randf_range(1.4, 4.0)
		_prop_box(Vector3(randf_range(-40, 40), size * 0.5, randf_range(-40, 40)),
				Vector3(size, size, size), "rock", Color(0.9, 0.88, 0.84), 1.2)
	# ممر ضيق
	for index3 in 7:
		var z := -30.0 + index3 * 8.0
		_prop_box(Vector3(-12.0, 1.5, z), Vector3(5.0, 3.0, 5.0), "rock", Color(0.88, 0.86, 0.82), 1.5)
		_prop_box(Vector3(12.0, 1.5, z), Vector3(5.0, 3.0, 5.0), "rock", Color(0.88, 0.86, 0.82), 1.5)
	for index4 in 5:
		_sandbag_line(Vector3(-6 + index4 * 3, 0, -6 + index4 * 4), 3, Vector3(1, 0, 0))

	_tower(Vector3(-30, 0, -34))
	_tower(Vector3(30, 0, -34))

	spawn_points.append(Vector3(-34, 1.0, -30))
	spawn_points.append(Vector3(34, 1.0, -28))
	spawn_points.append(Vector3(-30, 1.0, 10))
	spawn_points.append(Vector3(30, 1.0, 14))
	spawn_points.append(Vector3(0, 1.0, -30))
	charge_positions = [Vector3(-18, 0, -14), Vector3(18, 0, -14), Vector3(0, 0, 6)]
	hostage_positions = [Vector3(-8, 0, -4), Vector3(8, 0, -4), Vector3(0, 0, 12)]


func _build_convoy() -> void:
	player_spawn = Vector3(0, 1.2, 34)
	# طريق ضيق بمبانٍ على الجانبين
	for index in 5:
		var z := -34.0 + index * 15.0
		_building(Vector3(-16, 2.2, z), Vector3(8, 4.4, 8), "plaster", "wood",
				Color(0.9, 0.85, 0.76), 0.05)
		_building(Vector3(16, 2.2, z), Vector3(8, 4.4, 8), "plaster", "wood",
				Color(0.86, 0.82, 0.74), -0.05)
		spawn_points.append(Vector3(-12, 1.0, z))
		spawn_points.append(Vector3(12, 1.0, z))

	for index2 in 10:
		var z := -32.0 + index2 * 7.0
		_prop_box(Vector3(-7.0, 0.6, z), Vector3(3.0, 1.2, 1.0), "concrete",
				Color(0.85, 0.82, 0.76), 1.4, index2 % 2 == 0)
		_prop_box(Vector3(7.0, 0.6, z), Vector3(3.0, 1.2, 1.0), "concrete",
				Color(0.85, 0.82, 0.76), 1.4, index2 % 2 == 1)

	for index3 in 8:
		_barrel(Vector3(randf_range(-12, 12), 0, randf_range(-30, 30)))
	for index4 in 4:
		_vehicle_prop(Vector3(-11, 0, -20 + index4 * 14), PI * 0.5)

	charge_positions = [Vector3(-12, 0, -20), Vector3(12, 0, -4), Vector3(0, 0, 14)]
	hostage_positions = [Vector3(-10, 0, -8), Vector3(10, 0, -8), Vector3(0, 0, -16)]


# --------------------------------------------------------------- استعلامات
func getcover_points() -> Array:
	return cover_points


func get_charge_positions() -> Array:
	return charge_positions


func get_hostage_positions() -> Array:
	return hostage_positions


func get_player_spawn() -> Vector3:
	return player_spawn
