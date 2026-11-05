extends Node3D
class_name ViewWeapon
## سلاح المنظور الأول: مجسّم مبني من أجزاء، مع يدان، وتذبذب وارتداد وتلقيم.
## يُبنى برمجياً لكل نوع سلاح حتى لا يعتمد المشروع على نماذج خارجية.

const GUNMETAL := Color(0.10, 0.11, 0.12)
const POLYMER := Color(0.14, 0.16, 0.13)
const OLIVE := Color(0.26, 0.30, 0.18)
const GLASS := Color(0.25, 0.55, 0.45)
const GLOVE := Color(0.18, 0.17, 0.14)
const SKIN := Color(0.68, 0.52, 0.40)

var weapon_id := "rifle_ak"
var is_aiming := false
var is_reloading := false
var move_speed := 0.0

var _root: Node3D
var _muzzle: Node3D
var _time := 0.0
var _recoil := 0.0
var _reload_blend := 0.0
var _sway := Vector2.ZERO
var _bob := 0.0
var _materials: Dictionary = {}


func _ready() -> void:
	_root = Node3D.new()
	_root.position = Vector3(0.30, -0.27, -0.58)
	_root.scale = Vector3.ONE * 0.62
	add_child(_root)
	build(weapon_id)


func _mat(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f" % [color.to_html(), metallic, roughness]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	_materials[key] = mat
	return mat


func _box(size: Vector3, position: Vector3, color: Color, metallic: float = 0.55,
		roughness: float = 0.45, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	mesh.rotation = rotation
	mesh.material_override = _mat(color, metallic, roughness)
	_root.add_child(mesh)
	return mesh


func _cylinder(radius: float, height: float, position: Vector3, color: Color,
		rotation: Vector3 = Vector3(90, 0, 0), metallic: float = 0.8,
		roughness: float = 0.3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	mesh.mesh = cylinder
	mesh.position = position
	mesh.rotation = rotation
	mesh.material_override = _mat(color, metallic, roughness)
	_root.add_child(mesh)
	return mesh


func build(id: String) -> void:
	weapon_id = id
	for child in _root.get_children():
		child.queue_free()
	_materials.clear()

	var weapon_class := "rifle"
	var db := get_node_or_null("/root/WeaponsDB")
	if db != null and db.has(id):
		weapon_class = String(db.get_weapon(id)["class"])

	match weapon_class:
		"pistol":
			_build_pistol()
		"melee":
			_build_knife()
		"launcher":
			_build_launcher()
		"shotgun":
			_build_shotgun()
		"sniper":
			_build_sniper()
		_:
			_build_rifle()

	_build_arms()
	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0, 0.02, -0.95)
	_root.add_child(_muzzle)


func _common_receiver(length: float = 0.30) -> void:
	_box(Vector3(0.075, 0.095, length), Vector3(0, 0, -0.05), GUNMETAL, 0.75, 0.35)
	_box(Vector3(0.085, 0.055, length * 0.72), Vector3(0, -0.005, -0.03), POLYMER, 0.2, 0.6)
	# مقبض المسدس
	_box(Vector3(0.055, 0.145, 0.075), Vector3(0, -0.11, 0.06), POLYMER, 0.15, 0.65,
			Vector3(0.22, 0, 0))
	# الزناد
	_box(Vector3(0.02, 0.045, 0.02), Vector3(0, -0.075, 0.005), GUNMETAL, 0.8, 0.3)
	# المخزن
	_box(Vector3(0.05, 0.15, 0.085), Vector3(0, -0.115, -0.13), OLIVE, 0.25, 0.55,
			Vector3(-0.18, 0, 0))
	# الأخمص
	_box(Vector3(0.06, 0.075, 0.19), Vector3(0, 0.005, 0.24), POLYMER, 0.2, 0.55)


func _build_rifle() -> void:
	_common_receiver(0.30)
	# اليد الأمامية
	_box(Vector3(0.065, 0.07, 0.24), Vector3(0, 0.005, -0.33), POLYMER, 0.2, 0.6)
	# السبطانة
	_cylinder(0.017, 0.34, Vector3(0, 0.02, -0.55), GUNMETAL)
	# الفوهة
	_cylinder(0.026, 0.06, Vector3(0, 0.02, -0.73), GUNMETAL)
	# منظار
	_cylinder(0.028, 0.15, Vector3(0, 0.085, -0.10), GUNMETAL, Vector3(90, 0, 0), 0.7, 0.35)
	_cylinder(0.023, 0.005, Vector3(0, 0.085, -0.175), GLASS, Vector3(90, 0, 0), 0.1, 0.1)
	_box(Vector3(0.03, 0.045, 0.03), Vector3(0, 0.055, -0.045), GUNMETAL)
	_box(Vector3(0.03, 0.045, 0.03), Vector3(0, 0.055, -0.165), GUNMETAL)


func _build_sniper() -> void:
	_common_receiver(0.34)
	_box(Vector3(0.07, 0.075, 0.30), Vector3(0, 0.005, -0.36), POLYMER, 0.2, 0.6)
	_cylinder(0.016, 0.50, Vector3(0, 0.02, -0.72), GUNMETAL)
	_cylinder(0.026, 0.07, Vector3(0, 0.02, -0.98), GUNMETAL)
	# منظار كبير
	_cylinder(0.038, 0.30, Vector3(0, 0.10, -0.12), GUNMETAL, Vector3(90, 0, 0), 0.75, 0.3)
	_cylinder(0.034, 0.006, Vector3(0, 0.10, -0.275), GLASS, Vector3(90, 0, 0), 0.1, 0.05)
	_cylinder(0.030, 0.006, Vector3(0, 0.10, 0.035), GLASS, Vector3(90, 0, 0), 0.1, 0.05)
	_box(Vector3(0.03, 0.05, 0.04), Vector3(0, 0.06, -0.02), GUNMETAL)
	_box(Vector3(0.03, 0.05, 0.04), Vector3(0, 0.06, -0.22), GUNMETAL)
	# أرجل ثنائية
	_box(Vector3(0.015, 0.16, 0.015), Vector3(-0.02, -0.10, -0.55), GUNMETAL, 0.8, 0.3,
			Vector3(0, 0, 0.35))
	_box(Vector3(0.015, 0.16, 0.015), Vector3(0.02, -0.10, -0.55), GUNMETAL, 0.8, 0.3,
			Vector3(0, 0, -0.35))


func _build_shotgun() -> void:
	_common_receiver(0.28)
	_box(Vector3(0.07, 0.07, 0.22), Vector3(0, 0.0, -0.32), OLIVE, 0.2, 0.6)
	_cylinder(0.020, 0.44, Vector3(0, 0.025, -0.55), GUNMETAL)
	_cylinder(0.015, 0.40, Vector3(0, -0.02, -0.55), GUNMETAL)
	_box(Vector3(0.06, 0.06, 0.10), Vector3(0, 0.005, 0.20), Color(0.32, 0.22, 0.14),
			0.0, 0.8)


func _build_pistol() -> void:
	_box(Vector3(0.05, 0.075, 0.22), Vector3(0, 0.03, -0.08), GUNMETAL, 0.8, 0.3)
	_box(Vector3(0.045, 0.12, 0.065), Vector3(0, -0.06, 0.02), POLYMER, 0.2, 0.65,
			Vector3(0.18, 0, 0))
	_box(Vector3(0.02, 0.035, 0.02), Vector3(0, -0.025, -0.03), GUNMETAL)
	_cylinder(0.014, 0.05, Vector3(0, 0.035, -0.21), GUNMETAL)
	_box(Vector3(0.02, 0.02, 0.015), Vector3(0, 0.075, -0.16), GUNMETAL)


func _build_knife() -> void:
	_box(Vector3(0.012, 0.03, 0.30), Vector3(0, 0.02, -0.22), Color(0.72, 0.74, 0.78),
			0.9, 0.15)
	_box(Vector3(0.03, 0.045, 0.10), Vector3(0, 0.0, -0.02), Color(0.10, 0.10, 0.11),
			0.3, 0.7)


func _build_launcher() -> void:
	_cylinder(0.055, 0.95, Vector3(0, 0.0, -0.30), Color(0.24, 0.26, 0.20), Vector3(90, 0, 0),
			0.4, 0.55)
	_cylinder(0.075, 0.16, Vector3(0, 0.0, -0.74), GUNMETAL, Vector3(90, 0, 0))
	_box(Vector3(0.05, 0.10, 0.05), Vector3(0, -0.10, -0.10), POLYMER, 0.2, 0.6)
	_box(Vector3(0.04, 0.12, 0.06), Vector3(0, -0.09, 0.18), POLYMER, 0.2, 0.6)
	_box(Vector3(0.03, 0.05, 0.20), Vector3(0, 0.075, -0.20), GUNMETAL)


func _build_arms() -> void:
	# forearm + glove on the grip (يمين)
	_box(Vector3(0.075, 0.075, 0.20), Vector3(0.075, -0.14, 0.20), SKIN, 0.0, 0.75,
			Vector3(-0.35, 0.15, 0))
	_box(Vector3(0.085, 0.09, 0.10), Vector3(0.045, -0.095, 0.115), GLOVE, 0.0, 0.8)
	# left arm supporting the handguard
	_box(Vector3(0.07, 0.07, 0.24), Vector3(-0.045, -0.13, -0.15), SKIN, 0.0, 0.75,
			Vector3(0.55, -0.25, 0))
	_box(Vector3(0.08, 0.085, 0.10), Vector3(-0.015, -0.075, -0.30), GLOVE, 0.0, 0.8)


func on_fire(recoil_amount: float) -> void:
	_recoil = minf(0.14, _recoil + 0.035 * clampf(recoil_amount, 0.4, 3.0))


func add_sway(delta: Vector2) -> void:
	_sway = _sway.lerp(delta, 0.2)


func _process(delta: float) -> void:
	_time += delta
	_recoil = lerpf(_recoil, 0.0, clampf(delta * 9.0, 0.0, 1.0))
	_reload_blend = lerpf(_reload_blend, 1.0 if is_reloading else 0.0,
			clampf(delta * 8.0, 0.0, 1.0))
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))

	var speed_ratio := clampf(move_speed / 8.0, 0.0, 1.0)
	_bob += delta * (6.0 + speed_ratio * 7.0)
	var bob_amount := speed_ratio * 0.018 * (1.0 - 0.6 * (1.0 if is_aiming else 0.0))
	var bob_x := sin(_bob) * bob_amount
	var bob_y := absf(cos(_bob)) * bob_amount * 0.8

	var hip := Vector3(0.30, -0.27, -0.58)
	var ads := Vector3(0.0, -0.115, -0.40)
	var target := hip.lerp(ads, 1.0 if is_aiming else 0.0)
	target.x += bob_x + _sway.x * 0.0006
	target.y += bob_y + _sway.y * 0.0006 - _reload_blend * 0.10
	target.z += _recoil * 0.55

	_root.position = _root.position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
	var target_rot := Vector3(_recoil * 3.0 - _reload_blend * 0.55, 0.0,
			_reload_blend * 0.5)
	_root.rotation = _root.rotation.lerp(target_rot, clampf(delta * 12.0, 0.0, 1.0))


func muzzle_position() -> Vector3:
	if _muzzle == null:
		return global_position
	return _muzzle.global_position


func muzzle_node() -> Node3D:
	return _muzzle
