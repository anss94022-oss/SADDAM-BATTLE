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


func _cylinder(parent: Node3D, top_r: float, bottom_r: float, height: float,
		position: Vector3, color: Color, scale_z: float = 1.0) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top_r
	cyl.bottom_radius = bottom_r
	cyl.height = height
	cyl.radial_segments = 20
	mesh.mesh = cyl
	mesh.position = position
	mesh.scale = Vector3(1.0, 1.0, scale_z)
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


func _sphere(parent: Node3D, radius: float, position: Vector3, color: Color,
		scale: Vector3 = Vector3.ONE, hemisphere: bool = false) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0 if not hemisphere else radius
	sph.is_hemisphere = hemisphere
	sph.radial_segments = 24
	sph.rings = 12
	mesh.mesh = sph
	mesh.position = position
	mesh.scale = scale
	mesh.material_override = _material(color)
	parent.add_child(mesh)
	return mesh


const MODEL_PATH := "res://assets/characters/soldier_vanguard.glb"

var _using_model := false
var _model_root: Node3D
var _anim: AnimationPlayer
var _model_inst: Node3D
var _hand_bone: Node3D


func _build() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var packed := load(MODEL_PATH) as PackedScene
		if packed != null and _build_from_model(packed):
			return
	_build_procedural()


func _build_from_model(packed: PackedScene) -> bool:
	var inst := packed.instantiate() as Node3D
	if inst == null:
		return false

	_model_root = Node3D.new()
	_model_root.name = "Model"
	add_child(_model_root)
	_model_root.add_child(inst)
	_model_inst = inst

	# ضبط الطول إلى 1.82 م وتثبيت القدمين على الأرض
	var aabb := _aabb_of_node(inst)
	var height := aabb.size.y
	var factor := 1.82 / height if height > 0.01 else 1.0
	inst.scale = Vector3.ONE * factor
	inst.position = Vector3(0, -aabb.position.y * factor, 0)
	# نماذج Mixamo تواجه +Z، ومحور Godot الأمامي -Z
	inst.rotation.y = 0.0

	_anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _anim != null:
		for anim_name in ["Idle", "Walk", "Run"]:
			if _anim.has_animation(anim_name):
				_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
		_anim.play("Idle")

	if is_enemy:
		_tint_enemy(inst)

	_hand_bone = inst.find_child("mixamorig:RightHand", true, false)
	_weapon_mount = Node3D.new()
	_weapon_mount.position = Vector3(0.24, 1.15, -0.30)
	_model_root.add_child(_weapon_mount)
	_build_weapon_mesh("rifle_ak")

	_head = _model_root
	_body_root = _model_root
	_using_model = true
	return true


func _aabb_of_node(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var local := mi.global_transform
		var instance_box := local * mi.mesh.get_aabb()
		box = instance_box if first else box.merge(instance_box)
		first = false
	if first:
		return AABB(Vector3.ZERO, Vector3(1.8, 1.8, 1.8))
	return box


func _tint_enemy(inst: Node3D) -> void:
	for child in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null:
			continue
		var base := mi.get_active_material(0)
		var mat: StandardMaterial3D
		if base is StandardMaterial3D:
			mat = (base as StandardMaterial3D).duplicate()
		else:
			mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.85, 0.32, 0.26)
		mat.roughness = minf(mat.roughness, 0.85)
		mi.material_override = mat


func _build_procedural() -> void:
	_body_root = Node3D.new()
	add_child(_body_root)

	# الحوض
	_box(_body_root, Vector3(0.40, 0.24, 0.28), Vector3(0, 0.94, 0), UNIFORM_DARK)
	_box(_body_root, Vector3(0.44, 0.07, 0.30), Vector3(0, 1.02, 0), Color(0.16, 0.15, 0.12))

	# الساقان: فخذ + ساق + رُكبة + حذاء
	for side in [-1, 1]:
		var thigh := Node3D.new()
		thigh.position = Vector3(0.11 * side, 0.92, 0)
		_body_root.add_child(thigh)
		_capsule(thigh, 0.115, 0.44, Vector3(0, -0.22, 0), uniform_color)

		var shin := Node3D.new()
		shin.position = Vector3(0, -0.44, 0)
		thigh.add_child(shin)
		_capsule(shin, 0.095, 0.42, Vector3(0, -0.21, 0), UNIFORM_DARK)
		_sphere(shin, 0.10, Vector3(0, 0.02, -0.02), UNIFORM_DARK, Vector3(1.0, 0.85, 1.0))
		# حذاء عسكري
		_box(shin, Vector3(0.17, 0.13, 0.30), Vector3(0, -0.44, 0.05), Color(0.10, 0.10, 0.09))
		_box(shin, Vector3(0.18, 0.05, 0.32), Vector3(0, -0.50, 0.05), Color(0.06, 0.06, 0.06))

		if side < 0:
			_thigh_l = thigh
			_shin_l = shin
			# جراب على الفخذ
			_box(thigh, Vector3(0.11, 0.16, 0.10), Vector3(-0.13, -0.18, 0), Color(0.14, 0.14, 0.12))
		else:
			_thigh_r = thigh
			_shin_r = shin

	# الجذع
	_torso = Node3D.new()
	_torso.position = Vector3(0, 1.06, 0)
	_body_root.add_child(_torso)
	_cylinder(_torso, 0.25, 0.19, 0.54, Vector3(0, 0.28, 0), uniform_color, 0.72)
	# سترة واقية مع جيوب
	_box(_torso, Vector3(0.46, 0.40, 0.30), Vector3(0, 0.30, 0), UNIFORM_DARK)
	for i in 3:
		_box(_torso, Vector3(0.12, 0.11, 0.06), Vector3(-0.13 + i * 0.13, 0.26, -0.17),
			Color(0.16, 0.17, 0.14))
	# كتفان
	_sphere(_torso, 0.115, Vector3(-0.26, 0.50, 0), UNIFORM_DARK, Vector3(1.0, 0.85, 1.0))
	_sphere(_torso, 0.115, Vector3(0.26, 0.50, 0), UNIFORM_DARK, Vector3(1.0, 0.85, 1.0))
	# حقيبة ظهر
	_box(_torso, Vector3(0.36, 0.40, 0.18), Vector3(0, 0.30, 0.22), Color(0.24, 0.24, 0.20))
	_box(_torso, Vector3(0.30, 0.10, 0.06), Vector3(0, 0.18, 0.32), Color(0.15, 0.15, 0.13))

	# الرقبة والرأس والخوذة
	_cylinder(_torso, 0.065, 0.075, 0.10, Vector3(0, 0.60, 0), SKIN)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.66, 0)
	_torso.add_child(_head)
	_sphere(_head, 0.115, Vector3(0, 0.08, 0), SKIN, Vector3(1.0, 1.18, 1.02))
	# خوذة نصف كرة
	_sphere(_head, 0.148, Vector3(0, 0.11, 0), UNIFORM_DARK, Vector3(1.0, 0.92, 1.05), true)
	_box(_head, Vector3(0.30, 0.035, 0.05), Vector3(0, 0.055, 0.11), Color(0.08, 0.09, 0.09))
	# نظارة/واقي عينين
	_box(_head, Vector3(0.21, 0.05, 0.045), Vector3(0, 0.075, 0.115), Color(0.12, 0.16, 0.20))
	# حامل جهاز الرؤية الليلية
	_box(_head, Vector3(0.06, 0.07, 0.05), Vector3(0, 0.10, -0.15), Color(0.10, 0.10, 0.11))

	# الذراعان: عضد + ساعد + قفاز
	_arm_r = Node3D.new()
	_arm_r.position = Vector3(0.28, 0.50, 0)
	_torso.add_child(_arm_r)
	_capsule(_arm_r, 0.075, 0.30, Vector3(0, -0.15, 0), uniform_color)
	_capsule(_arm_r, 0.062, 0.26, Vector3(0, -0.40, 0), UNIFORM_DARK)
	_box(_arm_r, Vector3(0.10, 0.11, 0.11), Vector3(0, -0.54, 0), Color(0.10, 0.10, 0.09))

	_arm_l = Node3D.new()
	_arm_l.position = Vector3(-0.28, 0.50, 0)
	_torso.add_child(_arm_l)
	_capsule(_arm_l, 0.075, 0.30, Vector3(0, -0.15, 0), uniform_color)
	_capsule(_arm_l, 0.062, 0.26, Vector3(0, -0.40, 0), UNIFORM_DARK)
	_box(_arm_l, Vector3(0.10, 0.11, 0.11), Vector3(0, -0.54, 0), Color(0.10, 0.10, 0.09))

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
	if _using_model:
		_animate_model(delta, speed, is_sprinting, is_crouching, is_aiming)
		return
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


func _animate_model(delta: float, speed: float, is_sprinting: bool,
		is_crouching: bool, is_aiming: bool) -> void:
	move_speed = lerpf(move_speed, speed, clampf(delta * 8.0, 0.0, 1.0))
	crouch_amount = lerpf(crouch_amount, 1.0 if is_crouching else 0.0,
			clampf(delta * 10.0, 0.0, 1.0))
	aim_amount = lerpf(aim_amount, 1.0 if is_aiming else 0.0, clampf(delta * 12.0, 0.0, 1.0))
	_phase += delta * (3.0 + move_speed * 0.9)

	if _anim != null:
		var target := "Idle"
		var rate := 1.0
		if move_speed > 4.6 or is_sprinting:
			target = "Run"
			rate = clampf(move_speed / 7.2, 0.85, 1.5)
		elif move_speed > 0.4:
			target = "Walk"
			rate = clampf(move_speed / 2.4, 0.8, 1.7)
		if _anim.current_animation != target and _anim.has_animation(target):
			_anim.play(target, 0.18)
		_anim.speed_scale = rate

	if _weapon_mount != null:
		_weapon_mount.position = Vector3(-0.02, 1.12, 0.26)
		_weapon_mount.rotation = Vector3(0.15, 0.0, -0.75)

	if _model_root != null:
		_model_root.position.y = -crouch_amount * 0.30
		_model_root.rotation.x = crouch_amount * 0.18 + aim_amount * 0.05
		_model_root.rotation.z = sin(_phase) * 0.015 * clampf(move_speed / 6.0, 0.0, 1.0)


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
	if _using_model:
		dead = true
		var t := create_tween()
		t.set_parallel(true)
		t.tween_property(self, "rotation_degrees:x", -84.0, 0.4)
		t.tween_property(_model_root, "position:y", -0.05, 0.4)
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
