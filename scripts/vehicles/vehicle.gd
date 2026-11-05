extends CharacterBody3D
## مركبة أرضية (سيارة/شاحنة/مدرعة/دراجة) — قيادة، مقاعد، ضرر، وكاميرا.
## كل الأرقام تُقرأ من VehiclesDB حتى تبقى الموازنة في البيانات لا في الكود.

signal destroyed
signal occupants_changed

var data: Dictionary = {}
var vehicle_id := "car_4x4"
var seats := 4
var occupants: Array = []
var health := 250.0
var max_health := 250.0
var destroyed_flag := false
var is_motorcycle := false
var is_air := false
var rotor_speed := 0.0
var _rotor_nodes: Array = []
var _rotor_spin := 0.0
var _was_airborne := false
var look_delta := Vector2.ZERO
var _cam_yaw := 0.0
var _cam_pitch := -0.16
var team := 0
var display_name := ""

# إدخال من السائق (محلي أو شبكي)
var throttle := 0.0
var steer := 0.0
var brake_input := 0.0
var input_enabled := true

var autopilot := false
var route: Array = []
var route_speed := 6.0
var _route_index := 0

var speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
var _yaw := 0.0
var _wheel_spin := 0.0
var _fire_cooldown := 0.0
var _lean := 0.0

var _camera: Camera3D
var _spring: SpringArm3D
var _camera_mode := 0
var _wheel_nodes: Array = []
var _steer_nodes: Array = []
var _body: MeshInstance3D
var _engine_player: AudioStreamPlayer3D
var _smoke: CPUParticles3D
var _fire: CPUParticles3D
var _seat_positions: Array = []
var _muzzle: Node3D
var _last_driver: Node = null
var _model_root: Node3D = null
var _model_wheels: Array = []
var _model_front_wheels: Array = []
var _using_model := false

const MODEL_MAP := {
	"car_4x4": "suv",
	"car_civilian": "sedan",
	"car_super": "race",
	"car_super2": "hatchback-sports",
	"truck_transport": "truck",
	"truck_supply": "truck-flat",
	"armored_apc": "van",
	"recon_buggy": "race",
	"technicals": "truck-flat",
	"heli_transport": "",
	"heli_recon": "",
	"heli_attack": "",
	"bike_military": "",
	"bike_civilian": ""
}


func setup(id: String) -> void:
	vehicle_id = id
	data = VehiclesDB.get_vehicle(id)
	if data.is_empty():
		data = VehiclesDB.get_vehicle("car_4x4")
	seats = int(data.get("seats", 4))
	max_health = float(data.get("health", 250.0))
	health = max_health
	is_motorcycle = String(data.get("class", "car")) == "motorcycle"
	is_air = String(data.get("class", "car")) == "helicopter"


func _ready() -> void:
	if data.is_empty():
		setup(vehicle_id)
	add_to_group("vehicle")
	add_to_group("damageable")
	set_collision_layer_value(5, true)
	set_collision_mask_value(1, true)
	_build_collision()
	_build_meshes()
	_build_camera()
	_build_audio()
	_yaw = rotation.y


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	if is_motorcycle:
		box.size = Vector3(0.7, 1.1, 2.1)
	else:
		var length := 4.4
		if String(data.get("class", "car")) == "truck":
			length = 6.4
		elif String(data.get("class", "car")) == "armored":
			length = 6.8
		box.size = Vector3(2.2, 1.6, length)
	shape.shape = box
	shape.position = Vector3(0, box.size.y * 0.5 + 0.35, 0)
	add_child(shape)


func _material(color: Color, metallic: float = 0.2) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = 0.55
	return mat


func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


func _wheel(position: Vector3, radius: float, steers: bool, rim_color: Color = Color(0.07, 0.07, 0.07),
		spokes: int = 0) -> void:
	var pivot := Node3D.new()
	pivot.position = position
	add_child(pivot)

	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = radius * 0.7
	mesh.mesh = cylinder
	mesh.rotation_degrees = Vector3(0, 0, 90)
	mesh.material_override = _material(rim_color, 0.0)
	if rim_color.v > 0.15:
		(mesh.material_override as StandardMaterial3D).metallic = 0.85
		(mesh.material_override as StandardMaterial3D).roughness = 0.22
	pivot.add_child(mesh)

	# جنوط متعددة الأضلاع
	if spokes > 0:
		for index in spokes:
			var angle := TAU * float(index) / float(spokes)
			var spoke := MeshInstance3D.new()
			var spoke_mesh := BoxMesh.new()
			spoke_mesh.size = Vector3(radius * 1.45, radius * 0.10, radius * 0.10)
			spoke.mesh = spoke_mesh
			spoke.position = Vector3(0, cos(angle) * radius * 0.45, sin(angle) * radius * 0.45)
			spoke.rotation.z = -angle
			var spoke_mat := StandardMaterial3D.new()
			spoke_mat.albedo_color = rim_color
			spoke_mat.metallic = 0.9
			spoke_mat.roughness = 0.18
			spoke.material_override = spoke_mat
			pivot.add_child(spoke)
		var hub := MeshInstance3D.new()
		var hub_mesh := CylinderMesh.new()
		hub_mesh.top_radius = radius * 0.18
		hub_mesh.bottom_radius = radius * 0.18
		hub_mesh.height = radius * 0.5
		hub.mesh = hub_mesh
		hub.rotation_degrees = Vector3(0, 0, 90)
		var hub_mat := StandardMaterial3D.new()
		hub_mat.albedo_color = rim_color
		hub_mat.metallic = 0.9
		hub_mat.roughness = 0.18
		hub.material_override = hub_mat
		pivot.add_child(hub)

	_wheel_nodes.append(mesh)
	if steers:
		_steer_nodes.append(pivot)


func _build_meshes() -> void:
	if is_air:
		_build_helicopter_meshes()
		return

	if vehicle_id in ["car_super", "car_super2"]:
		_build_supercar(Color(0.015, 0.015, 0.02) if vehicle_id == "car_super" else Color(0.55, 0.03, 0.03))
		return

	if _build_gltf_model():
		_build_model_details()
		return

	var body_color := Color(0.28, 0.30, 0.22)
	var class_name_value := String(data.get("class", "car"))

	if is_motorcycle:
		body_color = Color(0.20, 0.22, 0.18)
		_box(self, Vector3(0.34, 0.34, 1.1), Vector3(0, 0.85, 0), body_color)
		_box(self, Vector3(0.5, 0.10, 0.44), Vector3(0, 1.02, 0.15), Color(0.10, 0.10, 0.10))
		_box(self, Vector3(0.10, 0.10, 0.6), Vector3(0, 0.62, -0.4), Color(0.32, 0.32, 0.32))
		_wheel(Vector3(0, 0.42, -0.78), 0.40, true)
		_wheel(Vector3(0, 0.42, 0.78), 0.40, false)
		_seat_positions = [Vector3(0, 1.0, -0.1), Vector3(0, 1.0, 0.5)]
		_camera_mode = 0
		return

	var length := 4.4
	var width := 2.0
	var height := 1.5
	if class_name_value == "truck":
		length = 6.4
		width = 2.3
		height = 2.6
	elif class_name_value == "armored":
		length = 6.8
		width = 2.5
		height = 2.4
	elif class_name_value == "recon":
		body_color = Color(0.34, 0.32, 0.20)
		length = 3.8
		height = 1.2

	_box(self, Vector3(width, height * 0.6, length), Vector3(0, 0.75 + height * 0.3, 0), body_color)
	# الكابينة
	var cab_length := 1.9 if class_name_value != "truck" else 2.4
	_box(self, Vector3(width * 0.86, height * 0.55, cab_length),
			Vector3(0, 0.75 + height * 0.85, -length * 0.5 + cab_length * 0.6),
			body_color.darkened(0.08))
	# زجاج
	var glass := _box(self, Vector3(width * 0.74, height * 0.34, 0.1),
			Vector3(0, 0.8 + height * 0.9, -length * 0.5 + cab_length * 1.45),
			Color(0.16, 0.24, 0.28))
	glass.material_override = _material(Color(0.16, 0.24, 0.28), 0.0)
	(glass.material_override as StandardMaterial3D).roughness = 0.15

	if class_name_value == "truck":
		# صندوق خلفي
		_box(self, Vector3(width, height * 1.15, length * 0.55),
				Vector3(0, 0.75 + height * 0.72, length * 0.22), Color(0.24, 0.24, 0.20))
	elif class_name_value == "armored":
		_box(self, Vector3(width * 0.9, 0.7, length * 0.55), Vector3(0, 0.75 + height * 0.65, 0),
				body_color.darkened(0.12))
		# برج دوّار
		var turret := Node3D.new()
		turret.position = Vector3(0, height + 0.9, 0)
		add_child(turret)
		_box(turret, Vector3(2.2, 0.7, 2.0), Vector3.ZERO, body_color)
		_box(turret, Vector3(0.12, 0.12, 1.4), Vector3(0, 0.1, -1.2), Color(0.12, 0.12, 0.12))
		_muzzle = Node3D.new()
		_muzzle.position = Vector3(0, 0.1, -1.9)
		turret.add_child(_muzzle)
	else:
		_box(self, Vector3(width * 0.92, 0.12, length * 0.7), Vector3(0, 0.75 + height * 0.62, 0.2),
				body_color.darkened(0.15))

	# مصابيح
	_box(self, Vector3(0.28, 0.16, 0.1), Vector3(-width * 0.35, 0.95, -length * 0.5),
			Color(1.0, 0.94, 0.7))
	_box(self, Vector3(0.28, 0.16, 0.1), Vector3(width * 0.35, 0.95, -length * 0.5),
			Color(1.0, 0.94, 0.7))

	var wheel_radius := 0.48
	var axle_z := length * 0.34
	_wheel(Vector3(-width * 0.5, wheel_radius, -axle_z), wheel_radius, true)
	_wheel(Vector3(width * 0.5, wheel_radius, -axle_z), wheel_radius, true)
	_wheel(Vector3(-width * 0.5, wheel_radius, axle_z), wheel_radius, false)
	_wheel(Vector3(width * 0.5, wheel_radius, axle_z), wheel_radius, false)

	# مصباح أمامي حقيقي
	var headlight := SpotLight3D.new()
	headlight.position = Vector3(0, 1.0, -length * 0.5)
	headlight.rotation_degrees = Vector3(-6, 0, 0)
	headlight.light_energy = 3.0
	headlight.spot_range = 42.0
	headlight.spot_angle = 34.0
	headlight.light_color = Color(1.0, 0.95, 0.82)
	add_child(headlight)

	_seat_positions = []
	_seat_positions.append(Vector3(0, 1.35, -length * 0.22))
	for index in range(1, seats):
		_seat_positions.append(Vector3(-0.55 if index % 2 == 1 else 0.55, 1.35,
				length * 0.12 * float(index)))

	if String(data.get("mounted_weapon", "")) != "":
		var mount := Node3D.new()
		mount.position = Vector3(0, height + 1.1 if class_name_value != "recon" else 1.9, 0.2)
		add_child(mount)
		_box(mount, Vector3(0.12, 0.12, 0.9), Vector3(0, 0, -0.4), Color(0.12, 0.12, 0.12))
		_muzzle = Node3D.new()
		_muzzle.position = Vector3(0, 0, -0.95)
		mount.add_child(_muzzle)


## سيارة خارقة بشكل انسيابي مبني بالمجسمات (بدل الصناديق)
func _build_supercar(paint: Color) -> void:
	var glass_color := Color(0.05, 0.07, 0.10)
	# الهيكل السفلي
	var gloss := StandardMaterial3D.new()
	gloss.albedo_color = paint
	gloss.metallic = 0.85
	gloss.roughness = 0.10
	gloss.clearcoat_enabled = true
	gloss.clearcoat = 1.0
	var body_mesh := _box(self, Vector3(2.24, 0.46, 4.95), Vector3(0, 0.52, 0), paint)
	body_mesh.material_override = gloss
	# مقدمة منخفضة
	_box(self, Vector3(2.10, 0.30, 1.46), Vector3(0, 0.58, -1.94), paint.darkened(0.06))
	# مؤخرة مرتفعة
	_box(self, Vector3(2.20, 0.38, 1.35), Vector3(0, 0.68, 1.82), paint.darkened(0.04))
	# أقواس العجلات
	_box(self, Vector3(2.34, 0.34, 1.24), Vector3(0, 0.47, -1.64), paint.darkened(0.10))
	_box(self, Vector3(2.38, 0.38, 1.35), Vector3(0, 0.49, 1.64), paint.darkened(0.10))
	# الكابينة الزجاجية
	var cabin := _box(self, Vector3(1.66, 0.46, 2.10), Vector3(0, 0.98, 0.17), glass_color)
	cabin.material_override = _material(glass_color, 0.0)
	(cabin.material_override as StandardMaterial3D).roughness = 0.12
	(cabin.material_override as StandardMaterial3D).metallic = 0.5
	# سقف
	_box(self, Vector3(1.48, 0.12, 1.24), Vector3(0, 1.20, 0.20), paint.darkened(0.02))
	# صاري خلفي
	_box(self, Vector3(1.72, 0.18, 1.02), Vector3(0, 0.90, 1.40), paint.darkened(0.03))
	# جنح خلفي
	_box(self, Vector3(2.22, 0.08, 0.52), Vector3(0, 1.15, 2.28), paint.darkened(0.14))
	_box(self, Vector3(0.11, 0.30, 0.18), Vector3(-0.70, 1.01, 2.28), Color(0.10, 0.10, 0.12))
	_box(self, Vector3(0.11, 0.30, 0.18), Vector3(0.70, 1.01, 2.28), Color(0.10, 0.10, 0.12))
	# مشتت أمامي وألواح جانبية
	_box(self, Vector3(2.15, 0.09, 0.48), Vector3(0, 0.34, -2.37), Color(0.08, 0.08, 0.09))
	_box(self, Vector3(2.30, 0.11, 2.92), Vector3(0, 0.31, 0.05), Color(0.08, 0.08, 0.09))
	# مصابيح أمامية
	_box(self, Vector3(0.52, 0.11, 0.14), Vector3(-0.70, 0.68, -2.60), Color(1.0, 0.95, 0.85))
	_box(self, Vector3(0.52, 0.11, 0.14), Vector3(0.70, 0.68, -2.60), Color(1.0, 0.95, 0.85))
	# مصابيح خلفية
	_box(self, Vector3(1.80, 0.09, 0.09), Vector3(0, 0.81, 2.52), Color(1.0, 0.15, 0.12))
	# عجلات كبيرة
	var wheel_radius := 0.54
	for side in [-1.0, 1.0]:
		_wheel(Vector3(1.06 * side, wheel_radius, -1.64), wheel_radius, true, Color(0.78, 0.80, 0.84), 6)
		_wheel(Vector3(1.08 * side, wheel_radius, 1.64), wheel_radius + 0.03, false, Color(0.78, 0.80, 0.84), 6)

	_seat_positions = [Vector3(0, 1.15, -0.1), Vector3(0, 1.15, 0.6)]
	_camera_mode = 0
	_using_model = false


## تحميل نموذج مركبة حقيقي (Kenney Car Kit — CC0) بدل الصناديق.
func _build_gltf_model() -> bool:
	var model_name := String(MODEL_MAP.get(vehicle_id, ""))
	if model_name == "":
		return false
	var path := "res://assets/models/vehicles/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return false

	var packed: PackedScene = load(path)
	if packed == null:
		return false
	var instance := packed.instantiate()
	if instance == null:
		return false

	_model_root = Node3D.new()
	_model_root.name = "Model"
	add_child(_model_root)
	_model_root.add_child(instance)

	var target_length := 4.6
	var class_name_value := String(data.get("class", "car"))
	if is_motorcycle:
		target_length = 2.2
	elif class_name_value == "truck":
		target_length = 6.6
	elif class_name_value == "armored":
		target_length = 5.6
	elif class_name_value == "recon":
		target_length = 4.0

	var aabb := _aabb_of(instance)
	var span := maxf(aabb.size.x, aabb.size.z)
	if span <= 0.01:
		span = 1.0
	var factor := target_length / span
	instance.scale = Vector3.ONE * factor
	var center := aabb.position + aabb.size * 0.5
	instance.position = Vector3(-center.x * factor, -aabb.position.y * factor,
			-center.z * factor)

	# ترتيب المحاور: نماذج Kenney تواجه -Z افتراضياً
	if absf(aabb.size.x) > absf(aabb.size.z) * 1.4:
		instance.rotation.y = PI * 0.5

	for node in instance.find_children("*", "Node3D", true, false):
		var node_name := String(node.name).to_lower()
		if node_name.begins_with("wheel"):
			_model_wheels.append(node)
			if node_name.contains("front"):
				_model_front_wheels.append(node)

	_using_model = true
	return true


func _aabb_of(node: Node) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh.global_transform * mesh.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result


func _build_model_details() -> void:
	# إضاءات المركبة فقط (النموذج يحتوي الهيكل والعجلات)
	var length := 4.6
	var class_name_value := String(data.get("class", "car"))
	if class_name_value == "truck":
		length = 6.6
	elif class_name_value == "armored":
		length = 5.6

	var headlight := SpotLight3D.new()
	headlight.position = Vector3(-0.62, 0.85, -length * 0.48)
	headlight.rotation_degrees = Vector3(-5, 0, 0)
	headlight.light_energy = 4.0
	headlight.spot_range = 48.0
	headlight.spot_angle = 32.0
	headlight.light_color = Color(1.0, 0.95, 0.82)
	add_child(headlight)

	var headlight_r := SpotLight3D.new()
	headlight_r.position = Vector3(0.62, 0.85, -length * 0.48)
	headlight_r.rotation_degrees = Vector3(-5, 0, 0)
	headlight_r.light_energy = 4.0
	headlight_r.spot_range = 48.0
	headlight_r.spot_angle = 32.0
	headlight_r.light_color = Color(1.0, 0.95, 0.82)
	add_child(headlight_r)

	_seat_positions = []
	_seat_positions.append(Vector3(-0.42, 1.25, -length * 0.12))
	_seat_positions.append(Vector3(0.42, 1.25, -length * 0.12))
	for index in range(2, seats):
		_seat_positions.append(Vector3(-0.42 if index % 2 == 0 else 0.42, 1.25,
				length * 0.10 * float(index - 1)))

	if String(data.get("mounted_weapon", "")) != "":
		var mount := Node3D.new()
		mount.position = Vector3(0, 1.95, 0.4)
		add_child(mount)
		_box(mount, Vector3(0.12, 0.12, 0.9), Vector3(0, 0, -0.4), Color(0.12, 0.12, 0.12))
		_muzzle = Node3D.new()
		_muzzle.position = Vector3(0, 0, -0.95)
		mount.add_child(_muzzle)


func _build_camera() -> void:
	_spring = SpringArm3D.new()
	_spring.spring_length = float(data.get("camera_distance", 8.0))
	_spring.position = Vector3(0, float(data.get("camera_height", 2.6)), 0)
	_spring.collision_mask = 1
	_spring.margin = 0.3
	add_child(_spring)

	_camera = Camera3D.new()
	_camera.fov = 78.0
	_camera.far = 900.0
	_camera.current = false
	_spring.add_child(_camera)


func _build_audio() -> void:
	_engine_player = AudioStreamPlayer3D.new()
	_engine_player.bus = "Vehicles"
	_engine_player.unit_size = 18.0
	_engine_player.max_distance = 110.0
	var path := "res://assets/audio/sfx/%s.wav" % String(data.get("engine", "engine_car_loop"))
	if ResourceLoader.exists(path):
		var stream := load(path) as AudioStreamWAV
		if stream != null:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
			_engine_player.stream = stream
			_engine_player.volume_db = -18.0
			add_child(_engine_player)
			_engine_player.play()


func _build_damage_effects() -> void:
	if _smoke != null or not GameSettings.has_renderer():
		return
	_smoke = CPUParticles3D.new()
	_smoke.emitting = false
	_smoke.amount = 18
	_smoke.lifetime = 1.6
	_smoke.direction = Vector3.UP
	_smoke.spread = 25.0
	_smoke.gravity = Vector3(0, 1.5, 0)
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 3.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.4
	mesh.height = 0.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.14, 0.13, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = mat
	_smoke.mesh = mesh
	add_child(_smoke)
	_smoke.position = Vector3(0, 1.6, -0.6)

	_fire = CPUParticles3D.new()
	_fire.emitting = false
	_fire.amount = 12
	_fire.lifetime = 0.7
	_fire.direction = Vector3.UP
	_fire.spread = 20.0
	_fire.initial_velocity_min = 1.5
	_fire.initial_velocity_max = 3.5
	var fire_mesh := SphereMesh.new()
	fire_mesh.radius = 0.28
	fire_mesh.height = 0.56
	var fire_mat := StandardMaterial3D.new()
	fire_mat.albedo_color = Color(1.0, 0.55, 0.2, 0.85)
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.4, 0.1)
	fire_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_mesh.material = fire_mat
	_fire.mesh = fire_mesh
	add_child(_fire)
	_fire.position = Vector3(0, 1.4, -0.6)


# --------------------------------------------------------------- القيادة
func _physics_process(delta: float) -> void:
	if destroyed_flag:
		return

	_apply_camera_look(delta)

	if autopilot:
		_autopilot_tick(delta)

	if is_air:
		_flight_physics(delta)
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.5

	var max_speed := float(data.get("max_speed", 20.0))
	var reverse_speed := float(data.get("reverse_speed", 7.0))
	var acceleration := float(data.get("acceleration", 9.0))
	var brake_force := float(data.get("brake", 20.0))
	var turn_rate := float(data.get("turn_rate", 1.2))

	var target_speed := throttle * max_speed if throttle >= 0.0 else throttle * reverse_speed
	if brake_input > 0.1:
		target_speed = move_toward(speed, 0.0, brake_force)
		speed = target_speed
	else:
		speed = move_toward(speed, target_speed, acceleration * delta * 3.0)

	# احتكاك وتباطؤ طبيعي
	if absf(throttle) < 0.05 and brake_input < 0.1:
		speed = move_toward(speed, 0.0, acceleration * delta * 0.7)

	# التوجيه يحتاج سرعة
	var speed_ratio := clampf(absf(speed) / max_speed, 0.0, 1.0)
	if absf(speed) > 0.4:
		_yaw -= steer * turn_rate * delta * (0.35 + speed_ratio) * signf(speed)
	rotation.y = _yaw

	var forward := -global_transform.basis.z
	var velocity_target := forward * speed
	var lateral := velocity - forward * velocity.dot(forward)
	velocity.x = velocity_target.x + lateral.x * 0.86
	velocity.z = velocity_target.z + lateral.z * 0.86
	move_and_slide()

	# ميل الدراجة في المنعطفات
	if is_motorcycle:
		_lean = lerpf(_lean, -steer * deg_to_rad(float(data.get("lean_angle", 30.0))) *
				speed_ratio, clampf(delta * 5.0, 0.0, 1.0))
		rotation.z = _lean
		rotation.x = lerpf(rotation.x, clampf(-throttle * 0.05, -0.12, 0.12), delta * 4.0)

	_wheel_spin += speed * delta / 0.45
	for wheel in _wheel_nodes:
		(wheel as MeshInstance3D).rotation.x = _wheel_spin
	for pivot in _steer_nodes:
		(pivot as Node3D).rotation.y = lerp_angle((pivot as Node3D).rotation.y,
				steer * 0.5, clampf(delta * 8.0, 0.0, 1.0))

	if _using_model:
		for wheel in _model_wheels:
			var wheel_node := wheel as Node3D
			if wheel_node == null:
				continue
			wheel_node.rotate_object_local(Vector3.RIGHT, speed * delta / 0.34)
		for wheel in _model_front_wheels:
			var front := wheel as Node3D
			if front != null:
				front.rotation.y = lerp_angle(front.rotation.y, steer * 0.45,
						clampf(delta * 8.0, 0.0, 1.0))

	if _engine_player != null:
		_engine_player.pitch_scale = 0.75 + speed_ratio * 1.25
		_engine_player.volume_db = -20.0 + speed_ratio * 6.0

	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _muzzle != null and (Input.is_action_pressed("fire") or _remote_fire):
		_fire_mounted(delta)

	_update_damage_state()
	_check_landing()


func _autopilot_tick(delta: float) -> void:
	if route.is_empty():
		return
	var target_point: Vector3 = route[mini(_route_index, route.size() - 1)]
	var to_point := target_point - global_position
	to_point.y = 0.0
	if to_point.length() < 4.0 and _route_index < route.size() - 1:
		_route_index += 1
	var desired_yaw := atan2(to_point.x, to_point.z) + PI
	var diff := wrapf(desired_yaw - rotation.y, -PI, PI)
	steer = clampf(-diff * 1.4, -1.0, 1.0)
	throttle = clampf(route_speed / float(data.get("max_speed", 20.0)), 0.0, 1.0)


var _remote_fire := false


func set_remote_fire(value: bool) -> void:
	_remote_fire = value


func _fire_mounted(_delta: float) -> void:
	if _fire_cooldown > 0.0 or _muzzle == null:
		return
	var weapon_id := String(data.get("mounted_weapon", "hmg"))
	var weapon := WeaponsDB.get_weapon(weapon_id)
	if weapon.is_empty():
		return
	_fire_cooldown = 60.0 / float(weapon.get("rpm", 500.0))
	AudioManager.play_weapon(String(weapon.get("sound", "shot_hmg")), _muzzle.global_position)
	AudioManager.play_3d("impact_metal", _muzzle.global_position, -10.0)

	var origin := _muzzle.global_position
	var direction := -_camera.global_transform.basis.z if _camera != null else -global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 300.0, 0b111, [get_rid()])
	var result := space.intersect_ray(query)
	if result.is_empty():
		return
	var collider = result["collider"]
	if collider != null and collider.has_method("take_damage"):
		var killed: bool = collider.take_damage(float(weapon.get("damage", 30.0)),
				collider.has_method("is_head_position") and collider.is_head_position(result["position"]),
				self)
		if killed and collider.is_in_group("enemy"):
			SaveSystem.register_kill(false)


# --------------------------------------------------------------- المقاعد
func free_seat() -> int:
	for index in seats:
		if index >= occupants.size() or occupants[index] == null:
			return index
	return -1


func can_interact(_player: Node) -> bool:
	return not destroyed_flag and free_seat() != -1


func interact_prompt() -> String:
	return Loc.t("hud_enter_vehicle")


func interact(player: Node) -> void:
	if player.has_method("enter_vehicle"):
		player.enter_vehicle(self, true)


func add_occupant(node: Node, as_driver: bool = false) -> bool:
	var seat := 0 if (as_driver and (occupants.is_empty() or occupants[0] == null)) else free_seat()
	if seat == -1:
		return false
	while occupants.size() <= seat:
		occupants.append(null)
	occupants[seat] = node

	if seat == 0:
		_last_driver = node
		_camera.current = true
		_attach_driver_visual(node)
	occupants_changed.emit()
	return true


func remove_occupant(node: Node) -> void:
	for index in occupants.size():
		if occupants[index] == node:
			occupants[index] = null
			if index == 0:
				_camera.current = false
				if node.has_method("get_node_or_null"):
					var rig = node.get_node_or_null("Rig")
					if rig != null:
						rig.visible = true
	occupants_changed.emit()


func has_driver() -> bool:
	return occupants.size() > 0 and occupants[0] != null


func _attach_driver_visual(node: Node) -> void:
	if node.has_method("get_node_or_null"):
		var rig = node.get_node_or_null("Rig")
		if rig != null:
			rig.visible = false


func driver() -> Node:
	return occupants[0] if occupants.size() > 0 else null


func camera() -> Camera3D:
	return _camera


func cycle_camera() -> void:
	_camera_mode = (_camera_mode + 1) % 3
	match _camera_mode:
		0:
			_spring.spring_length = float(data.get("camera_distance", 8.0))
			_spring.position.y = float(data.get("camera_height", 2.6))
		1:
			_spring.spring_length = float(data.get("camera_distance", 8.0)) * 1.9
			_spring.position.y = float(data.get("camera_height", 2.6)) + 3.0
		2:
			_spring.spring_length = 0.6
			_spring.position.y = float(data.get("camera_height", 2.6))


# ------------------------------------------------------------------ الضرر
func take_damage(amount: float, _headshot: bool = false, source: Node = null,
		from_position: Variant = null) -> bool:
	if destroyed_flag:
		return false
	var armor := float(data.get("armor", 0.0))
	health -= amount * (1.0 - armor)
	if health <= max_health * 0.5:
		_build_damage_effects()
		if _smoke != null:
			_smoke.emitting = true
	if health <= max_health * 0.22:
		if _fire != null:
			_fire.emitting = true
	if health <= 0.0:
		# التأجيل يمنع تعديل الشجرة أثناء استدعاء فيزيائي/انفجار
		call_deferred("_explode", source, from_position)
		return true
	return false


func _update_damage_state() -> void:
	if _smoke == null:
		return
	if health < max_health * 0.5 and not _smoke.emitting:
		_smoke.emitting = true


func _explode(source: Node, from_position: Variant) -> void:
	if destroyed_flag:
		return
	destroyed_flag = true
	var position := global_position
	# إخراج الركاب قبل الانفجار
	for occupant in occupants.duplicate():
		if occupant != null and is_instance_valid(occupant):
			if occupant.has_method("exit_vehicle"):
				occupant.exit_vehicle(true)
	occupants.clear()
	_camera.current = false
	if _engine_player != null:
		_engine_player.stop()
	Explosion.detonate(get_tree(), position + Vector3(0, 0.8, 0), 160.0, 8.0, source)
	destroyed.emit()
	var tree := get_tree()
	queue_free()
	if from_position is Vector3:
		pass


func _apply_camera_look(delta: float) -> void:
	if look_delta != Vector2.ZERO:
		_cam_yaw -= look_delta.x * GameSettings.look_sensitivity * 0.45
		_cam_pitch = clampf(_cam_pitch - look_delta.y * GameSettings.look_sensitivity * 0.35,
				-0.9, 0.55)
		look_delta = Vector2.ZERO
	if _spring != null:
		_spring.rotation.y = lerp_angle(_spring.rotation.y, _cam_yaw,
				clampf(delta * 14.0, 0.0, 1.0))
		_spring.rotation.x = lerp_angle(_spring.rotation.x, _cam_pitch,
				clampf(delta * 14.0, 0.0, 1.0))


func add_look_input(delta: Vector2) -> void:
	look_delta += delta


func _check_landing() -> void:
	if is_air:
		return
	var airborne := not is_on_floor()
	if _was_airborne and not airborne:
		if absf(speed) < 3.0:
			SaveSystem.register_landing()
	_was_airborne = airborne


# --------------------------------------------------------------- المروحيات
func _build_helicopter_meshes() -> void:
	var body_color := Color(0.26, 0.30, 0.24)
	var length := 5.4
	if vehicle_id == "heli_attack":
		body_color = Color(0.22, 0.24, 0.20)
		length = 6.2
	elif vehicle_id == "heli_recon":
		length = 4.6

	_box(self, Vector3(1.9, 1.5, 3.4), Vector3(0, 0.4, 0), body_color)
	_box(self, Vector3(1.6, 1.2, 1.4), Vector3(0, 0.55, -1.9), body_color.darkened(0.06))
	# زجاج القمرة
	var glass := _box(self, Vector3(1.45, 0.9, 0.12), Vector3(0, 0.75, -2.6),
			Color(0.14, 0.2, 0.24))
	(glass.material_override as StandardMaterial3D).roughness = 0.1
	# الذيل
	_box(self, Vector3(0.42, 0.42, 2.8), Vector3(0, 0.7, 2.6), body_color.darkened(0.1))
	_box(self, Vector3(1.3, 0.12, 0.5), Vector3(0, 1.25, 3.9), body_color.darkened(0.2))
	# معدات الهبوط
	_box(self, Vector3(0.12, 0.9, 0.12), Vector3(-0.8, -0.35, -0.9), Color(0.14, 0.14, 0.14))
	_box(self, Vector3(0.12, 0.9, 0.12), Vector3(0.8, -0.35, -0.9), Color(0.14, 0.14, 0.14))
	_box(self, Vector3(0.12, 0.7, 0.12), Vector3(-0.7, -0.35, 1.2), Color(0.14, 0.14, 0.14))
	_box(self, Vector3(0.12, 0.7, 0.12), Vector3(0.7, -0.35, 1.2), Color(0.14, 0.14, 0.14))

	# الدوّار الرئيسي
	var rotor_mount := Node3D.new()
	rotor_mount.position = Vector3(0, 1.35, 0)
	add_child(rotor_mount)
	_box(rotor_mount, Vector3(0.2, 0.3, 0.2), Vector3.ZERO, Color(0.12, 0.12, 0.12))
	for index in 4:
		var blade := _box(rotor_mount, Vector3(5.6, 0.05, 0.22), Vector3.ZERO,
				Color(0.10, 0.10, 0.10))
		blade.rotation_degrees.y = index * 90.0
	_rotor_nodes.append(rotor_mount)

	# دوّار الذيل
	var tail_rotor := Node3D.new()
	tail_rotor.position = Vector3(0.35, 1.25, 4.0)
	add_child(tail_rotor)
	for index in 2:
		var blade := _box(tail_rotor, Vector3(0.06, 1.1, 0.14), Vector3.ZERO,
				Color(0.10, 0.10, 0.10))
		blade.rotation_degrees.z = index * 90.0
	_rotor_nodes.append(tail_rotor)

	_seat_positions = [Vector3(0, 0.9, -1.6)]
	for index in range(1, seats):
		_seat_positions.append(Vector3(-0.4 + 0.8 * (index % 2), 0.8, -0.4 + 0.5 * float(index / 2)))

	if String(data.get("mounted_weapon", "")) != "":
		var mount := Node3D.new()
		mount.position = Vector3(0.55, -0.15, -2.1)
		add_child(mount)
		_muzzle = Node3D.new()
		mount.add_child(_muzzle)
		_box(mount, Vector3(0.1, 0.1, 0.8), Vector3(0, 0, -0.3), Color(0.1, 0.1, 0.1))


func _flight_physics(delta: float) -> void:
	var max_speed := float(data.get("max_speed", 36.0))
	var climb_rate := float(data.get("climb_rate", 9.0))
	rotor_speed = lerpf(rotor_speed, 1.0 if absf(throttle) > 0.01 or true else 0.0,
			clampf(delta * 1.6, 0.0, 1.0))

	# الارتفاع: throttle موجب = صعود، سالب = هبوط
	var vertical_target := throttle * climb_rate
	if absf(throttle) < 0.05:
		vertical_target = -0.6  # هبوط بطيء عند ترك العصا

	var horizontal := Vector3(move_input_air.x, 0, move_input_air.y)
	if horizontal.length() > 1.0:
		horizontal = horizontal.normalized()
	horizontal = global_transform.basis * horizontal
	horizontal.y = 0.0

	var forward_speed := max_speed
	var desired_velocity := horizontal * forward_speed * absf(_air_throttle)
	desired_velocity.y = vertical_target

	velocity = velocity.lerp(desired_velocity, clampf(delta * 1.9, 0.0, 1.0))

	# دوران المروحية: yaw من الإدخال الجانبي، وميل بصري مع الحركة
	var yaw_input := steer
	rotation.y -= yaw_input * float(data.get("turn_rate", 1.1)) * delta
	rotation.z = lerp_angle(rotation.z, -horizontal.dot(global_transform.basis.x) * 0.12,
			clampf(delta * 3.0, 0.0, 1.0))
	rotation.x = lerp_angle(rotation.x, horizontal.dot(global_transform.basis.z) * 0.10,
			clampf(delta * 3.0, 0.0, 1.0))

	move_and_slide()

	_rotor_spin += delta * (14.0 + absf(velocity.y) * 0.6)
	for node in _rotor_nodes:
		(node as Node3D).rotation.y = _rotor_spin if node == _rotor_nodes[0] else 				(node as Node3D).rotation.y
	if _rotor_nodes.size() > 1:
		(_rotor_nodes[1] as Node3D).rotation.z = _rotor_spin * 2.0

	if _engine_player != null:
		_engine_player.pitch_scale = 0.85 + clampf(velocity.length() / 40.0, 0.0, 0.6)
		_engine_player.volume_db = -14.0 + clampf(velocity.length() / 40.0, 0.0, 1.0) * 4.0

	if _muzzle != null and (Input.is_action_pressed("fire") or _remote_fire):
		_fire_mounted(delta)

	_update_damage_state()
	_check_landing_air()


var move_input_air := Vector2.ZERO
var _air_throttle := 1.0


func set_flight_input(move: Vector2, vertical: float) -> void:
	move_input_air = move
	_air_throttle = clampf(vertical, 0.0, 1.0)


func _check_landing_air() -> void:
	var grounded := is_on_floor()
	if _was_airborne and grounded:
		if velocity.length() < 4.0:
			SaveSystem.register_landing()
		elif velocity.length() > 18.0:
			take_damage(40.0, false, null)
	_was_airborne = not grounded


func is_destroyed() -> bool:
	return destroyed_flag


func speed_kmh() -> float:
	return absf(speed) * 3.6
