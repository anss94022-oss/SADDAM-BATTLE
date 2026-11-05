extends Area3D
## صندوق ذخيرة/علاج/قنابل — يُلتقط عند المرور عليه.

enum Kind { AMMO, MEDKIT, GRENADE }

var kind: int = Kind.AMMO
var _mesh: MeshInstance3D
var _taken := false
var _time := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	shape.shape = sphere
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.6, 0.45, 0.6)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	match kind:
		Kind.AMMO:
			mat.albedo_color = Color(0.72, 0.62, 0.28)
			mat.emission = Color(0.9, 0.75, 0.3)
		Kind.MEDKIT:
			mat.albedo_color = Color(0.85, 0.25, 0.25)
			mat.emission = Color(0.9, 0.2, 0.2)
		_:
			mat.albedo_color = Color(0.3, 0.55, 0.3)
			mat.emission = Color(0.3, 0.8, 0.3)
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 0.6
	_mesh.material_override = mat
	_mesh.position = Vector3(0, 0.5, 0)
	add_child(_mesh)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _mesh != null:
		_mesh.rotation.y += delta * 1.8
		_mesh.position.y = 0.5 + sin(_time * 2.0) * 0.12


func _on_body_entered(body: Node) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	if body.has_method("add_ammo"):
		match kind:
			Kind.AMMO:
				body.add_ammo(0.5)
			Kind.MEDKIT:
				body.add_medkit(1)
			_:
				body.add_grenades(1)
	AudioManager.play_3d("ui_confirm", global_position, -8.0)
	queue_free()
