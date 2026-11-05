extends CharacterBody3D
## صاروخ موجه بسرعة ثابتة: يرتد عن السطح ويصيب من يلمسه ثم ينفجر.

var damage := 210.0
var blast_radius := 7.0
var speed := 72.0
var direction := Vector3.FORWARD
var shooter: Node = null

var _life := 0.0
var _exploded := false


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.18
	shape.shape = sphere
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.09
	capsule.height = 0.6
	mesh.mesh = capsule
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.32, 0.28)
	mesh.material_override = mat
	mesh.rotation_degrees = Vector3(90, 0, 0)
	add_child(mesh)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 2.0
	light.omni_range = 4.0
	add_child(light)

	if direction.length() > 0.01:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_life += delta
	velocity = -global_transform.basis.z * speed
	var collision := move_and_collide(velocity * delta)
	if collision != null:
		_explode()
		return
	if _life > 6.0:
		_explode()


func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	var tree := get_tree()
	var position := global_position
	var damage_value := damage
	var radius := blast_radius
	var source := shooter
	set_physics_process(false)
	queue_free()
	await tree.process_frame
	Explosion.detonate(tree, position, damage_value, radius, source)
