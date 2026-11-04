extends CharacterBody3D
## اللاعب: حركة ثلاثية الأبعاد، كاميرا خلف الكتف، إطلاق نار، صحة وذخيرة.
## يعمل بلوحة المفاتيح والفأرة على الحاسب، وبعصا لمسية على أندرويد.

signal health_changed(current: float, maximum: float)
signal ammo_changed(magazine: int, reserve: int, weapon_name: String)
signal weapon_changed(weapon_name: String)
signal player_died
signal hit_confirmed(headshot: bool, killed: bool)

const WALK_SPEED := 5.6
const SPRINT_SPEED := 8.4
const CROUCH_SPEED := 2.8
const JUMP_VELOCITY := 8.5
const MOUSE_SENSITIVITY := 0.0022

var max_health := 100.0
var health := 100.0

var move_input := Vector2.ZERO      # من لوحة المفاتيح أو العصا اللمسية
var look_delta := Vector2.ZERO      # فرق النظر (فأرة أو سحب الإصبع)
var is_firing := false
var is_aiming := false
var is_sprinting := false
var is_crouching := false

var weapons: Array = []
var weapon_index := 0
var magazine := 0
var reserve := 0

var camera: Camera3D
var spring_arm: SpringArm3D
var muzzle: Node3D

var _yaw := 0.0
var _pitch := -0.15
var _fire_cooldown := 0.0
var _reload_timer := 0.0
var _is_reloading := false
var _recoil := 0.0
var _base_fov := 75.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)


func _ready() -> void:
	add_to_group("player")
	_build_body()
	_build_camera()
	_load_weapons()
	_equip(0)


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)

	# مجسّم مبسّط للاعب من الخلف (لأن الكاميرا خلف الكتف).
	var mesh := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.42
	body_mesh.height = 1.8
	mesh.mesh = body_mesh
	mesh.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.22, 0.28, 0.2)
	mat.roughness = 0.85
	mesh.material_override = mat
	add_child(mesh)

	muzzle = Node3D.new()
	muzzle.position = Vector3(0.25, 1.45, -0.8)
	add_child(muzzle)


func _build_camera() -> void:
	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = 3.1
	spring_arm.position = Vector3(0.55, 1.55, 0)
	spring_arm.collision_mask = 1
	add_child(spring_arm)

	camera = Camera3D.new()
	camera.fov = _base_fov
	camera.current = true
	spring_arm.add_child(camera)


func _load_weapons() -> void:
	weapons = [
		{
			"id": "rifle",
			"name": "بندقية هجومية",
			"damage": 24.0,
			"rpm": 620.0,
			"magazine": 30,
			"reserve": 180,
			"spread": 1.4,
			"aim_spread": 0.35,
			"range": 220.0,
			"automatic": true,
			"zoom": 1.5,
			"pellets": 1,
			"recoil": 0.9
		},
		{
			"id": "sniper",
			"name": "قناصة",
			"damage": 110.0,
			"rpm": 48.0,
			"magazine": 5,
			"reserve": 25,
			"spread": 3.0,
			"aim_spread": 0.02,
			"range": 600.0,
			"automatic": false,
			"zoom": 6.0,
			"pellets": 1,
			"recoil": 3.2
		},
		{
			"id": "shotgun",
			"name": "شوزن",
			"damage": 14.0,
			"rpm": 75.0,
			"magazine": 7,
			"reserve": 42,
			"spread": 7.5,
			"aim_spread": 2.2,
			"range": 60.0,
			"automatic": false,
			"zoom": 1.0,
			"pellets": 7,
			"recoil": 4.0
		}
	]


func set_weapon_by_id(weapon_id: String) -> void:
	for index in weapons.size():
		if String(weapons[index]["id"]) == weapon_id:
			_equip(index)
			return


func _equip(index: int) -> void:
	weapon_index = clampi(index, 0, weapons.size() - 1)
	var weapon: Dictionary = weapons[weapon_index]
	magazine = int(weapon["magazine"])
	reserve = int(weapon["reserve"])
	_is_reloading = false
	ammo_changed.emit(magazine, reserve, String(weapon["name"]))
	weapon_changed.emit(String(weapon["name"]))


func next_weapon() -> void:
	_equip((weapon_index + 1) % weapons.size())


func current_weapon() -> Dictionary:
	return weapons[weapon_index]


func _unhandled_input(event: InputEvent) -> void:
	# نظر الفأرة (يُستهلك هنا حتى لا تتحرك القوائم).
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_delta += event.relative


func _physics_process(delta: float) -> void:
	_apply_look(delta)
	_apply_move(delta)
	_tick_weapon(delta)
	_apply_recoil(delta)


func _apply_look(delta: float) -> void:
	var sensitivity := GameSettings.look_sensitivity

	if look_delta != Vector2.ZERO:
		_yaw -= look_delta.x * sensitivity * 0.45
		var dy := look_delta.y * sensitivity * 0.45
		if GameSettings.invert_y:
			dy = -dy
		_pitch = clampf(_pitch - dy, -1.2, 1.0)
		look_delta = Vector2.ZERO

	rotation.y = _yaw
	spring_arm.rotation.x = _pitch

	# تقريب القناصة عند التصويب.
	var weapon: Dictionary = current_weapon()
	var target_fov := _base_fov
	if is_aiming:
		target_fov = _base_fov / max(1.0, float(weapon["zoom"]))
	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 10.0, 0.0, 1.0))


func _apply_move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		if Input.is_action_just_pressed("jump") and not is_crouching:
			velocity.y = JUMP_VELOCITY

	var direction := Vector3(move_input.x, 0, move_input.y)
	direction = (transform.basis * direction).normalized()

	var speed := WALK_SPEED
	if is_sprinting and not is_aiming:
		speed = SPRINT_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	if is_aiming:
		speed *= 0.55

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()


func _tick_weapon(delta: float) -> void:
	_fire_cooldown = max(0.0, _fire_cooldown - delta)

	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	if Input.is_action_just_pressed("reload"):
		start_reload()

	if Input.is_action_just_pressed("next_weapon"):
		next_weapon()

	if Input.is_action_just_pressed("aim"):
		is_aiming = true
	if Input.is_action_just_released("aim"):
		is_aiming = false

	var should_fire := is_firing || Input.is_action_pressed("fire")
	if should_fire and _fire_cooldown <= 0.0:
		_shoot()


func _apply_recoil(delta: float) -> void:
	if _recoil > 0.0:
		_pitch = clampf(_pitch + _recoil * delta * 1.4, -1.2, 1.0)
		_recoil = lerpf(_recoil, 0.0, clampf(delta * 6.0, 0.0, 1.0))


func start_reload() -> void:
	var weapon: Dictionary = current_weapon()
	if _is_reloading or magazine >= int(weapon["magazine"]) or reserve <= 0:
		return

	_is_reloading = true
	_reload_timer = 2.1 if String(weapon["id"]) != "sniper" else 2.8


func _finish_reload() -> void:
	var weapon: Dictionary = current_weapon()
	var capacity := int(weapon["magazine"])
	var needed := capacity - magazine
	var taken: int = min(needed, reserve)

	magazine += taken
	reserve -= taken
	_is_reloading = false
	ammo_changed.emit(magazine, reserve, String(weapon["name"]))


func _shoot() -> void:
	var weapon: Dictionary = current_weapon()

	if magazine <= 0:
		start_reload()
		return

	magazine -= 1
	_fire_cooldown = 60.0 / max(1.0, float(weapon["rpm"]))
	_recoil += float(weapon["recoil"]) * 0.01
	ammo_changed.emit(magazine, reserve, String(weapon["name"]))

	var spread := float(weapon["aim_spread"] if is_aiming else weapon["spread"])
	var pellets := int(weapon["pellets"])
	var damage := float(weapon["damage"])
	var max_range := float(weapon["range"])

	_muzzle_flash()

	for _pellet in pellets:
		_fire_ray(spread, damage, max_range)


func _fire_ray(spread_degrees: float, damage: float, max_range: float) -> void:
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z

	# تشتيت عشوائي داخل مخروط.
	var spread_rad := deg_to_rad(spread_degrees)
	var random_offset := Vector3(
		randf_range(-spread_rad, spread_rad),
		randf_range(-spread_rad, spread_rad),
		0.0
	)
	var direction := (forward + camera.global_transform.basis.x * random_offset.x +
		camera.global_transform.basis.y * random_offset.y).normalized()

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		origin, origin + direction * max_range, 0b111, [get_rid()]
	)
	var result := space.intersect_ray(query)

	if result.is_empty():
		return

	var collider = result["collider"]
	var hit_position: Vector3 = result["position"]

	if collider != null and collider.has_method("take_damage"):
		var headshot := false
		if collider.has_method("is_head_position"):
			headshot = collider.is_head_position(hit_position)

		collider.take_damage(damage, headshot)
		hit_confirmed.emit(headshot, false)
	else:
		_spawn_impact(hit_position)


func _spawn_impact(position: Vector3) -> void:
	var impact := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	impact.mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.75, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	impact.material_override = mat

	get_tree().current_scene.add_child(impact)
	impact.global_position = position

	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(func():
		if is_instance_valid(impact):
			impact.queue_free()
	)


func _muzzle_flash() -> void:
	if muzzle == null:
		return

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.45)
	light.light_energy = 3.0
	light.omni_range = 6.0
	muzzle.add_child(light)

	get_tree().create_timer(0.05).timeout.connect(func():
		if is_instance_valid(light):
			light.queue_free()
	)


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return

	health = max(0.0, health - amount)
	health_changed.emit(health, max_health)

	if health <= 0.0:
		player_died.emit()


func heal(amount: float) -> void:
	health = min(max_health, health + amount)
	health_changed.emit(health, max_health)


func refill_ammo() -> void:
	var weapon: Dictionary = current_weapon()
	reserve = int(weapon["reserve"])
	ammo_changed.emit(magazine, reserve, String(weapon["name"]))


# ---------- واجهة اللمس ----------

func set_move_input(value: Vector2) -> void:
	move_input = value


func add_look_input(delta: Vector2) -> void:
	look_delta += delta


func set_firing(value: bool) -> void:
	is_firing = value


func set_aiming(value: bool) -> void:
	is_aiming = value


func set_sprinting(value: bool) -> void:
	is_sprinting = value


func set_crouching(value: bool) -> void:
	is_crouching = value
