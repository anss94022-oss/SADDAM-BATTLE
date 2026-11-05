extends RigidBody3D
## قنبلة يدوية: ارتداد، فتيل، ثم انفجار.

var damage := 140.0
var blast_radius := 6.5
var fuse_time := 3.2
var thrower: Node = null

var _timer := 0.0
var _exploded := false


func _ready() -> void:
	mass = 0.6
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	collision_layer = 4
	collision_mask = 1

	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	mesh.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.26, 0.18)
	mat.roughness = 0.7
	mesh.material_override = mat
	add_child(mesh)

	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.12
	shape.shape = sphere_shape
	add_child(shape)

	_timer = fuse_time


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_timer -= delta
	if _timer <= 0.0:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var tree := get_tree()
	var position := global_position
	var damage_value := damage
	var radius := blast_radius
	var source := thrower
	set_physics_process(false)
	queue_free()

	await tree.process_frame
	Explosion.detonate(tree, position, damage_value, radius, source)
