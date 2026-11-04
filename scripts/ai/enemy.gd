extends CharacterBody3D
## عدوّ بذكاء اصطناعي بسيط ومؤثر:
## يطارد اللاعب، يبحث عن خط رؤية، يطلق النار على فترات، ويتراجع عند الاقتراب.

signal died(enemy: Node)
signal damaged(amount: float)

const EYE_HEIGHT := 1.55
const HEAD_HEIGHT := 1.72

var max_health := 100.0
var health := 100.0
var move_speed := 3.4
var attack_range := 30.0
var attack_damage := 9.0
var attack_interval := 1.35
var accuracy := 0.72          # احتمال الإصابة
var xp_reward := 20

var target: Node3D = null
var is_dead := false

var _cooldown := 0.0
var _strafe_dir := 1.0
var _strafe_timer := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)

var _head: MeshInstance3D
var _muzzle_light: OmniLight3D


func _ready() -> void:
	add_to_group("enemy")
	_build_body()
	_strafe_dir = 1.0 if randf() > 0.5 else -1.0
	_cooldown = randf_range(0.4, 1.6)


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position = Vector3(0, 0.9, 0)

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.36, 0.12, 0.12)
	body_mat.roughness = 0.9
	body.material_override = body_mat
	add_child(body)

	_head = MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	_head.mesh = head_mesh
	_head.position = Vector3(0, HEAD_HEIGHT, 0)

	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color(0.55, 0.42, 0.32)
	_head.material_override = head_mat
	add_child(_head)

	# ضوء طفيف ليسهل رؤية العدو في الأجواء المعتمة.
	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.4, 0.3)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 5.0
	_muzzle_light.position = Vector3(0, 1.4, 0)
	add_child(_muzzle_light)


func is_head_position(world_position: Vector3) -> bool:
	return world_position.y >= global_position.y + 1.5


func take_damage(amount: float, headshot: bool = false) -> void:
	if is_dead:
		return

	var final_damage := amount * (2.6 if headshot else 1.0)
	health -= final_damage
	damaged.emit(final_damage)

	_flash()

	if health <= 0.0:
		_die()


func _flash() -> void:
	var body := get_child(1) as MeshInstance3D
	if body == null:
		return

	var mat := body.material_override as StandardMaterial3D
	if mat == null:
		return

	mat.emission_enabled = true
	mat.emission = Color(1, 0.2, 0.2)

	get_tree().create_timer(0.08).timeout.connect(func():
		if is_instance_valid(mat):
			mat.emission_enabled = false
	)


func _die() -> void:
	is_dead = true
	remove_from_group("enemy")
	died.emit(self)

	if target != null and target.has_method("on_enemy_killed"):
		target.on_enemy_killed(self)

	# سقوط بسيط ثم إزالة.
	var tween := create_tween()
	tween.tween_property(self, "rotation_degrees:x", 85.0, 0.35)
	tween.tween_interval(0.6)
	tween.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y -= _gravity * delta

	if target == null or not is_instance_valid(target):
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var to_target := target.global_position - global_position
	var flat := Vector3(to_target.x, 0, to_target.z)
	var distance := flat.length()

	var can_see := _has_line_of_sight()

	if can_see and distance < attack_range:
		_face(flat)
		# اقتراب مع مناورة جانبية خفيفة حتى لا يتكدس الأعداء في خط واحد.
		var forward := flat.normalized()
		var side := forward.cross(Vector3.UP) * _strafe_dir

		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = randf_range(1.2, 2.6)
			_strafe_dir *= -1.0

		var desired := forward * move_speed * 0.35 + side * move_speed * 0.25
		if distance < 7.0:
			desired = -forward * move_speed * 0.6 + side * move_speed * 0.4

		velocity.x = desired.x
		velocity.z = desired.z

		_cooldown -= delta
		if _cooldown <= 0.0:
			_cooldown = attack_interval * randf_range(0.8, 1.25)
			_attack()
	else:
		# لا رؤية: يتقدّم باتجاه آخر موقع معروف.
		if distance > 2.0:
			velocity.x = flat.normalized().x * move_speed
			velocity.z = flat.normalized().z * move_speed
			_face(flat)

	move_and_slide()


func _face(flat_direction: Vector3) -> void:
	if flat_direction.length() < 0.01:
		return

	rotation.y = atan2(flat_direction.x, flat_direction.z)


func _has_line_of_sight() -> bool:
	if target == null:
		return false

	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, EYE_HEIGHT, 0)
	var to := target.global_position + Vector3(0, 1.2, 0)

	var query := PhysicsRayQueryParameters3D.create(from, to, 0b111, [get_rid()])
	var result := space.intersect_ray(query)

	if result.is_empty():
		return true

	return result["collider"] == target


func _attack() -> void:
	if target == null:
		return

	if _muzzle_light != null:
		_muzzle_light.light_energy = 2.0
		get_tree().create_timer(0.06).timeout.connect(func():
			if is_instance_valid(_muzzle_light):
				_muzzle_light.light_energy = 0.0
		)

	# دقة مبنية على المسافة: كلما ابتعد زاد الخطأ.
	var distance := global_position.distance_to(target.global_position)
	var hit_chance := accuracy * clampf(1.25 - distance / attack_range, 0.25, 1.0)

	if randf() <= hit_chance and target.has_method("take_damage"):
		target.take_damage(attack_damage * randf_range(0.85, 1.15))
