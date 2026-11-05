extends Node3D
class_name SoldierRig
## مجسّم جندي مبني من أجزاء ثلاثية الأبعاد مع تحريك إجرائي
## (وقوف، مشي، جري، انحناء، تصويب، إطلاق، سقوط) — بلا ملفات نماذج خارجية.

const UNIFORM := Color(0.29, 0.32, 0.23)
const UNIFORM_DARK := Color(0.20, 0.22, 0.17)
const ENEMY_UNIFORM := Color(0.33, 0.17, 0.14)
const SKIN := Color(0.72, 0.56, 0.42)
const METAL := Color(0.16, 0.16, 0.17)
const WOOD := Color(0.30, 0.22, 0.14)

var uniform_color := UNIFORM
var is_enemy := false
var crouch_amount := 0.0
var aim_amount := 0.0
var move_speed := 0.0
var sprinting := false
var firing := false
var dead := false

var _phase := 0.0
var _torso: Node3D
var _head: Node3D
var _arm_r: Node3D
var _arm_l: Node3D
var _thigh_r: Node3D
var _thigh_l: Node3D
var _shin_r: Node3D
var _shin_l: Node3D
var _weapon_mount: Node3D
var _body_root: Node3D
var _materials: Dictionary = {}


func setup(enemy: bool = false, uniform: Color = Color(0, 0, 0, 0)) -> void:
	is_enemy = enemy
	if enemy:
		uniform_color = ENEMY_UNIFORM
	if uniform.a > 0.0:
		uniform_color = uniform
	if _body_root != null:
		_apply_colors()
		return
	_build()


func _material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var key := "%s_%.2f" % [color.to_html(), roughness]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	_materials[key] = mat
	return mat


func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color,
		rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	mesh.rotation = rotation
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


func _capsule(parent: Node3D, radius: float, height: float, position: Vector3,
		color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	mesh.mesh = shape
	mesh.position = position
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


func _build() -> void:
	_body_root = Node3D.new()
	add_child(_body_root)

	# الحوض والساقان
	_box(_body_root, Vector3(0.42, 0.26, 0.30), Vector3(0, 0.92, 0), UNIFORM_DARK)

	_thigh_l = Node3D.new()
	_thigh_l.position = Vector3(-0.11, 0.90, 0)
	_body_root.add_child(_thigh_l)
	_capsule(_thigh_l, 0.10, 0.42, Vector3(0, -0.21, 0), uniform_color)

	_shin_l = Node3D.new()
	_shin_l.position = Vector3(0, -0.42, 0)
	_thigh_l.add_child(_shin_l)
	_capsule(_shin_l, 0.085, 0.44, Vector3(0, -0.22, 0), UNIFORM_DARK)
	_box(_shin_l, Vector3(0.14, 0.09, 0.24), Vector3(0, -0.45, 0.04), METAL)

	_thigh_r = Node3D.new()
	_thigh_r.position = Vector3(0.11, 0.90, 0)
	_body_root.add_child(_thigh_r)
	_capsule(_thigh_r, 0.10, 0.42, Vector3(0, -0.21, 0), uniform_color)

	_shin_r = Node3D.new()
	_shin_r.position = Vector3(0, -0.42, 0)
	_thigh_r.add_child(_shin_r)
	_capsule(_shin_r, 0.085, 0.44, Vector3(0, -0.22, 0), UNIFORM_DARK)
	_box(_shin_r, Vector3(0.14, 0.09, 0.24), Vector3(0, -0.45, 0.04), METAL)

	# الجذع
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.06, 0)
	_body_root.add_child(_torso)
	_box(_torso, Vector3(0.46, 0.56, 0.28), Vector3(0, 0.28, 0), uniform_color)
	# سترة واقية
	_box(_torso, Vector3(0.50, 0.42, 0.34), Vector3(0, 0.30, 0), UNIFORM_DARK)
	# حقيبة ظهر
	_box(_torso, Vector3(0.34, 0.36, 0.16), Vector3(0, 0.32, 0.22), Color(0.22, 0.22, 0.19))
	# حزام ذخيرة
	_box(_torso, Vector3(0.48, 0.08, 0.32), Vector3(0, 0.06, 0), Color(0.16, 0.15, 0.12))

	# الرقبة والرأس والخوذة
	_box(_torso, Vector3(0.14, 0.12, 0.14), Vector3(0, 0.60, 0), SKIN)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.68, 0)
	_torso.add_child(_head)
	_capsule(_head, 0.115, 0.26, Vector3(0, 0.06, 0), SKIN)
	var helmet := _capsule(_head, 0.145, 0.20, Vector3(0, 0.11, 0), UNIFORM_DARK)
	helmet.scale = Vector3(1.0, 0.85, 1.05)
	_box(_head, Vector3(0.24, 0.05, 0.05), Vector3(0, 0.04, 0.12), Color(0.10, 0.12, 0.10))

	# الذراعان
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.27, 0.48, 0)
	_torso.add_child(_arm_r)
	_capsule(_arm_r, 0.075, 0.30, Vector3(0, -0.15, 0), uniform_color)
	_capsule(_arm_r, 0.065, 0.28, Vector3(0, -0.40, 0), SKIN)
	_box(_arm_r, Vector3(0.10, 0.10, 0.10), Vector3(0, -0.53, 0), METAL)

	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.27, 0.48, 0)
	_torso.add_child(_arm_l)
	_capsule(_arm_l, 0.075, 0.30, Vector3(0, -0.15, 0), uniform_color)
	_capsule(_arm_l, 0.065, 0.28, Vector3(0, -0.40, 0), SKIN)
	_box(_arm_l, Vector3(0.10, 0.10, 0.10), Vector3(0, -0.53, 0), METAL)

	# موضع السلاح
	_weapon_mount = Node3D.new()
	_weapon_mount.position = Vector3(0.16, 0.32, -0.30)
	_torso.add_child(_weapon_mount)
	_build_weapon_mesh("rifle_ak")

	_apply_colors()


func _build_weapon_mesh(weapon_id: String) -> void:
	for child in _weapon_mount.get_children():
		child.queue_free()

	var weapon_class := "rifle"
	var db := get_node_or_null("/root/WeaponsDB")
	if db != null and db.has(weapon_id):
		weapon_class = String(db.get_weapon(weapon_id)["class"])

	match weapon_class:
		"melee":
			_box(_weapon_mount, Vector3(0.04, 0.04, 0.34), Vector3(0, 0, -0.1), Color(0.7, 0.72, 0.75))
		"launcher":
			var tube := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.07
			cylinder.bottom_radius = 0.08
			cylinder.height = 1.1
			tube.mesh = cylinder
			tube.rotation_degrees = Vector3(90, 0, 0)
			tube.position = Vector3(0, 0, -0.15)
			tube.material_override = _material(Color(0.24, 0.26, 0.20), 0.7)
			_weapon_mount.add_child(tube)
		"sniper":
			_box(_weapon_mount, Vector3(0.07, 0.09, 1.05), Vector3(0, 0, -0.3), Color(0.15, 0.16, 0.15))
			_box(_weapon_mount, Vector3(0.06, 0.06, 0.26), Vector3(0, 0.10, -0.18), METAL)
			_box(_weapon_mount, Vector3(0.05, 0.05, 0.12), Vector3(0, 0.10, -0.44), Color(0.3, 0.45, 0.55))
		"pistol":
			_box(_weapon_mount, Vector3(0.06, 0.12, 0.26), Vector3(0, -0.02, -0.12), METAL)
		_:
			_box(_weapon_mount, Vector3(0.07, 0.10, 0.62), Vector3(0, 0, -0.18), Color(0.15, 0.16, 0.15))
			_box(_weapon_mount, Vector3(0.05, 0.05, 0.30), Vector3(0, 0.01, -0.56), METAL)
			_box(_weapon_mount, Vector3(0.06, 0.16, 0.10), Vector3(0, -0.12, -0.14), WOOD)


func set_weapon(weapon_id: String) -> void:
	_build_weapon_mesh(weapon_id)


func _apply_colors() -> void:
	if _torso == null:
		return
	for mesh in _body_root.find_children("*", "MeshInstance3D", true, false):
		var instance := mesh as MeshInstance3D
		if instance == null or instance.material_override == null:
			continue
		var mat := instance.material_override as StandardMaterial3D
		if mat == null:
			continue
		var current := mat.albedo_color
		if current.is_equal_approx(UNIFORM):
			mat.albedo_color = uniform_color
		elif current.is_equal_approx(UNIFORM_DARK):
			mat.albedo_color = uniform_color.darkened(0.25)


## تُحدَّث الحركة كل إطار من كود اللاعب/العدو.
func animate(delta: float, speed: float, is_sprinting: bool,
		is_crouching: bool, is_aiming: bool, is_firing: bool) -> void:
	if _torso == null:
		return

	move_speed = lerpf(move_speed, speed, clampf(delta * 8.0, 0.0, 1.0))
	sprinting = is_sprinting
	firing = is_firing
	crouch_amount = lerpf(crouch_amount, 1.0 if is_crouching else 0.0, clampf(delta * 10.0, 0.0, 1.0))
	aim_amount = lerpf(aim_amount, 1.0 if is_aiming else 0.0, clampf(delta * 12.0, 0.0, 1.0))

	var stride := clampf(move_speed / 6.0, 0.0, 1.6)
	_phase += delta * (4.0 + move_speed * 1.05)

	var swing := sin(_phase) * stride * 0.75
	_thigh_l.rotation.x = swing
	_thigh_r.rotation.x = -swing
	_shin_l.rotation.x = maxf(0.0, -swing) * 0.9
	_shin_r.rotation.x = maxf(0.0, swing) * 0.9

	# انحناء: إنزال الجذع وثني الساقين
	var crouch_drop := crouch_amount * 0.34
	_body_root.position.y = -crouch_drop
	_thigh_l.rotation.x += crouch_amount * 0.55
	_thigh_r.rotation.x += crouch_amount * 0.55
	_shin_l.rotation.x += crouch_amount * 0.95
	_shin_r.rotation.x += crouch_amount * 0.95

	# ميل الجذع مع السرعة + اهتزاز الجري
	_torso.rotation.x = lerpf(_torso.rotation.x,
		-stride * 0.12 + crouch_amount * 0.22, clampf(delta * 12.0, 0.0, 1.0))
	_torso.rotation.z = sin(_phase * 0.5) * stride * 0.05
	_torso.position.y = 1.06 + sin(_phase * 2.0) * stride * 0.02 - crouch_drop * 0.2

	# التصويب يرفع الذراعين إلى الأمام
	var aim_pitch := lerpf(0.0, -1.15, aim_amount)
	_arm_r.rotation.x = aim_pitch
	_arm_l.rotation.x = aim_pitch + 0.12
	_arm_r.rotation.z = lerpf(0.0, -0.30, aim_amount)
	_arm_l.rotation.z = lerpf(0.0, 0.55, aim_amount)
	_arm_l.rotation.y = lerpf(0.0, -0.35, aim_amount)

	if firing and aim_amount > 0.2:
		var kick := sin(_phase * 14.0) * 0.05
		_arm_r.rotation.x += kick
		_torso.rotation.x += kick * 0.5


func flash_damage() -> void:
	if _torso == null:
		return
	var mat := _material(Color(0.8, 0.25, 0.2), 0.6)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.15, 0.1)
	mat.emission_energy_multiplier = 2.5
	var flash_tween := create_tween()
	flash_tween.tween_interval(0.09)
	flash_tween.tween_callback(func(): mat.emission_enabled = false)


func play_death() -> void:
	if dead or _body_root == null:
		return
	dead = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees:x", -84.0, 0.45)
	tween.tween_property(_body_root, "position:y", 0.25, 0.45)


func head_height() -> float:
	return 1.70


func is_head_position(world_position: Vector3) -> bool:
	return world_position.y >= global_position.y + 1.48
