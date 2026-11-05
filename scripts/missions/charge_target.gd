extends StaticBody3D
## هدف قابل للتدمير: مستودع ذخيرة/خزان — يُزرع فيه تفجير بالتفاعل ثم ينفجر.

signal destroyed(target: Node)
signal planted(target: Node)

var armed := false
var destroyed_flag := false
var blast_radius := 9.0
var blast_damage := 260.0
var health := 240.0
var marker: Node3D = null
var display_name := ""

var _mesh: MeshInstance3D
var _light: OmniLight3D
var _timer := 0.0
var _pending := false


func _ready() -> void:
	add_to_group("charge_target")
	add_to_group("damageable")
	collision_layer = 1

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4, 2.8, 3.4)
	shape.shape = box
	shape.position = Vector3(0, 1.4, 0)
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var mesh_box := BoxMesh.new()
	mesh_box.size = Vector3(3.4, 2.8, 3.4)
	_mesh.mesh = mesh_box
	_mesh.position = Vector3(0, 1.4, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.34, 0.36, 0.28)
	mat.roughness = 0.8
	_mesh.material_override = mat
	add_child(_mesh)

	# علامة صفراء تسهّل رؤية الهدف
	var marker_mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.18
	cylinder.bottom_radius = 0.18
	cylinder.height = 0.5
	marker_mesh.mesh = cylinder
	marker_mesh.position = Vector3(0, 3.0, 0)
	var marker_mat := StandardMaterial3D.new()
	marker_mat.albedo_color = Color(1.0, 0.78, 0.2)
	marker_mat.emission_enabled = true
	marker_mat.emission = Color(1.0, 0.6, 0.1)
	marker_mesh.material_override = marker_mat
	add_child(marker_mesh)
	marker = marker_mesh

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.6, 0.2)
	_light.light_energy = 0.6
	_light.omni_range = 6.0
	_light.position = Vector3(0, 2.6, 0)
	add_child(_light)


func can_interact(_player: Node) -> bool:
	return not armed and not destroyed_flag


func interact_prompt() -> String:
	return Loc.t("hud_plant_charge")


func interact(_player: Node) -> void:
	if armed or destroyed_flag:
		return
	armed = true
	_pending = true
	_timer = 2.2
	if _light != null:
		_light.light_energy = 2.0
	if marker != null:
		var mat := marker.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(1.0, 0.2, 0.15)
			mat.emission = Color(1.0, 0.1, 0.05)
	planted.emit(self)


func update_charge_progress() -> float:
	return 0.0


func _physics_process(delta: float) -> void:
	if not _pending:
		return
	_timer -= delta
	if _light != null:
		_light.light_energy = 1.5 + sin(Time.get_ticks_msec() * 0.02) * 1.2
	if _timer <= 0.0:
		_pending = false
		_detonate()


func _detonate() -> void:
	if destroyed_flag:
		return
	destroyed_flag = true
	if marker != null:
		marker.visible = false
	var tree := get_tree()
	var position := global_position + Vector3(0, 1.4, 0)
	Explosion.detonate(tree, position, blast_damage, blast_radius, self)
	SaveSystem.register_demolition()
	destroyed.emit(self)
	queue_free()


func take_damage(amount: float, _headshot: bool = false, _source: Node = null,
		_from_position: Variant = null) -> bool:
	if destroyed_flag:
		return false
	health -= amount
	if health <= 0.0:
		_detonate()
		return true
	return false
