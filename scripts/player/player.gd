extends CharacterBody3D
## اللاعب: جندي بمنظور الشخص الثالث — حركة، كاميرا، أسلحة، قنابل، علاج،
## مركبات، وضرر. كل خصائص الأسلحة تُقرأ من WeaponsDB.

signal health_changed(current: float, maximum: float)
signal armor_changed(current: float, maximum: float)
signal ammo_changed(magazine: int, reserve: int, weapon_name: String)
signal weapon_changed(weapon_name: String, weapon_id: String)
signal player_died
signal hit_confirmed(headshot: bool, killed: bool)
signal damaged_from(direction: Vector3)
signal grenades_changed(count: int)
signal medkits_changed(count: int)
signal interact_available(text: String)
signal interact_cleared
signal entered_vehicle(vehicle: Node)
signal exited_vehicle
signal killed_enemy(enemy: Node, headshot: bool)
signal scoped(zoom: float)

const WALK_SPEED := 5.4
const SPRINT_SPEED := 8.6
const CROUCH_SPEED := 2.7
const JUMP_VELOCITY := 8.2
const MOUSE_SENSITIVITY := 0.0022
const MAX_GRENADES := 4
const MAX_MEDKITS := 3
const INTERACT_RANGE := 3.4

var max_health := 100.0
var health := 100.0
var max_armor := 100.0
var armor := 100.0
var stamina := 100.0

var move_input := Vector2.ZERO
var look_delta := Vector2.ZERO
var is_firing := false
var is_aiming := false
var is_sprinting := false
var is_crouching := false
var alive := true
var team := 0
var display_name := ""

var weapons: Array = []
var weapon_index := 0
var grenades := 3
var medkits := 2
var kills := 0
var headshots := 0

var camera: Camera3D
var spring_arm: SpringArm3D
var muzzle: Node3D
var rig: SoldierRig
var view_weapon: ViewWeapon
var current_vehicle: Node = null
var first_person := false
var auto_fire := false

var _yaw := 0.0
var _pitch := -0.12
var _recoil := 0.0
var _fire_cooldown := 0.0
var _reload_timer := 0.0
var _is_reloading := false
var _base_fov := 75.0
var _scope_index := 0
var _zoom_hold := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
var _step_accum := 0.0
var _interact_target: Node = null
var _grenade_cooldown := 0.0
var _heal_cooldown := 0.0
var _air_time := 0.0
var _was_on_floor := true
var _headshot_sound_played := false


func _ready() -> void:
	add_to_group("player")
	add_to_group("damageable")
	set_collision_layer_value(2, true)
	set_collision_mask_value(1, true)
	_build_collision()
	_build_camera()
	_build_rig()
	_build_weapons()
	set_process_input(true)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)


func _build_camera() -> void:
	spring_arm = SpringArm3D.new()
	spring_arm.spring_length = 3.3
	spring_arm.position = Vector3(0.55, 1.74, 0)
	spring_arm.collision_mask = 1
	spring_arm.margin = 0.25
	add_child(spring_arm)

	camera = Camera3D.new()
	camera.fov = _base_fov
	camera.far = 900.0
	camera.current = true
	spring_arm.add_child(camera)


func _build_rig() -> void:
	rig = SoldierRig.new()
	rig.name = "Rig"
	add_child(rig)
	rig.setup(false, Color(0.30, 0.34, 0.24))

	view_weapon = ViewWeapon.new()
	view_weapon.name = "ViewWeapon"
	camera.add_child(view_weapon)

	muzzle = Node3D.new()
	muzzle.position = Vector3(0.16, 1.42, -0.72)
	add_child(muzzle)
	# الافتراضي: منظور ثالث يُظهر صدام بطل كامل بجسمه
	set_view_mode(false)


func _build_weapons() -> void:
	weapons.clear()
	var primary := SaveSystem.equipped()
	var secondary_id := SaveSystem.secondary()

	_add_weapon(primary)
	if secondary_id != primary:
		_add_weapon(secondary_id)
	_add_weapon("knife")
	_add_weapon("grenade")

	_equip(0)


func _add_weapon(weapon_id: String) -> void:
	var data := WeaponsDB.get_weapon(weapon_id)
	if data.is_empty():
		return
	var slot := data.duplicate(true)
	slot["magazine_current"] = int(data["magazine"])
	slot["reserve_current"] = int(data["reserve"])
	weapons.append(slot)


func _equip(index: int) -> void:
	if weapons.is_empty():
		return
	weapon_index = wrapi(index, 0, weapons.size())
	_is_reloading = false
	_reload_timer = 0.0
	_scope_index = 0

	var weapon := current_weapon()
	if rig != null:
		rig.set_weapon(String(weapon["id"]))
	if view_weapon != null:
		view_weapon.build(String(weapon["id"]))
	ammo_changed.emit(int(weapon["magazine_current"]), int(weapon["reserve_current"]),
			Loc.t(String(weapon["name_key"])))
	weapon_changed.emit(Loc.t(String(weapon["name_key"])), String(weapon["id"]))
	grenades_changed.emit(grenades)
	medkits_changed.emit(medkits)


func current_weapon() -> Dictionary:
	if weapons.is_empty():
		return {}
	return weapons[weapon_index]


func next_weapon() -> void:
	if is_reloading():
		return
	_equip(weapon_index + 1)


func choose_weapon(weapon_id: String) -> void:
	for index in weapons.size():
		if String(weapons[index]["id"]) == weapon_id:
			_equip(index)
			return


# --------------------------------------------------------------- الإدخال
func _unhandled_input(event: InputEvent) -> void:
	if not alive or current_vehicle != null:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_delta += event.relative


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if current_vehicle != null:
		return
	_tick_cooldowns(delta)
	_apply_look(delta)
	_apply_move(delta)
	_tick_weapon(delta)
	_tick_interaction()
	_update_rig(delta)


func _tick_cooldowns(delta: float) -> void:
	_grenade_cooldown = maxf(0.0, _grenade_cooldown - delta)
	_heal_cooldown = maxf(0.0, _heal_cooldown - delta)


func _apply_look(delta: float) -> void:
	var sensitivity := GameSettings.look_sensitivity

	if look_delta != Vector2.ZERO:
		_yaw -= look_delta.x * sensitivity * 0.015
		var dy := look_delta.y * sensitivity * 0.015
		if GameSettings.invert_y:
			dy = -dy
		_pitch = clampf(_pitch - dy, -1.15, 0.95)
		look_delta = Vector2.ZERO

	rotation.y = _yaw
	if _recoil > 0.001:
		_recoil = lerpf(_recoil, 0.0, clampf(delta * 7.0, 0.0, 1.0))
	spring_arm.rotation.x = clampf(_pitch + _recoil, -1.25, 1.0)

	var weapon := current_weapon()
	var target_fov := _base_fov
	if is_aiming and not weapon.is_empty():
		var zooms: Array = weapon["scope_zooms"]
		_scope_index = clampi(_scope_index, 0, zooms.size() - 1)
		var zoom := float(zooms[_scope_index])
		if zoom <= 0.0:
			zoom = 1.0
		target_fov = _base_fov / zoom
		camera.position = Vector3(0.0, 0.06, -0.12) if zoom > 2.0 else Vector3.ZERO
	else:
		_scope_index = 0
		camera.position = Vector3.ZERO

	camera.fov = lerpf(camera.fov, target_fov, clampf(delta * 9.0, 0.0, 1.0))
	if not first_person:
		var target_length := 1.35 if is_aiming else 3.3
		spring_arm.spring_length = lerpf(spring_arm.spring_length, target_length,
				clampf(delta * 10.0, 0.0, 1.0))
		spring_arm.position.x = lerpf(spring_arm.position.x, 0.42 if is_aiming else 0.52,
				clampf(delta * 10.0, 0.0, 1.0))
	else:
		spring_arm.position.y = lerpf(spring_arm.position.y,
				1.50 if is_crouching else 1.62, clampf(delta * 8.0, 0.0, 1.0))
		camera.position = Vector3.ZERO


func _apply_move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
		_air_time += delta
	else:
		if not _was_on_floor and _air_time > 0.35:
			AudioManager.play_3d("footstep_1", global_position, -6.0)
		_air_time = 0.0
		if Input.is_action_just_pressed("jump") and not is_crouching:
			jump()
	_was_on_floor = is_on_floor()

	var direction := Vector3(move_input.x, 0, move_input.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	direction = (transform.basis * direction)
	direction.y = 0.0
	if direction.length() > 1.0:
		direction = direction.normalized()

	var sprinting := is_sprinting and not is_aiming and not is_crouching and stamina > 2.0 \
		and move_input.length() > 0.6
	if sprinting:
		stamina = maxf(0.0, stamina - delta * 22.0)
	else:
		stamina = minf(100.0, stamina + delta * 14.0)

	var speed := WALK_SPEED
	if sprinting:
		speed = SPRINT_SPEED
	if is_crouching:
		speed = CROUCH_SPEED
	if is_aiming:
		speed *= 0.55
	if _is_reloading:
		speed *= 0.85

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	# أصوات الخطوات حسب المسافة المقطوعة
	if is_on_floor() and move_input.length() > 0.15:
		_step_accum += absf(velocity.length()) * delta
		if _step_accum > (1.7 if sprinting else 2.4):
			_step_accum = 0.0
			AudioManager.play_3d("footstep_%d" % randi_range(1, 3), global_position, -12.0,
					randf_range(0.9, 1.1))



func jump() -> void:
	if not is_on_floor():
		return
	velocity.y = JUMP_VELOCITY


# ------------------------------------------------------------------ السلاح
func _tick_weapon(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)

	if _is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	var weapon := current_weapon()
	if weapon.is_empty():
		return

	if Input.is_action_just_pressed("reload"):
		start_reload()
	if Input.is_action_just_pressed("next_weapon"):
		next_weapon()
	if Input.is_action_just_pressed("aim"):
		set_aiming(true)
	if Input.is_action_just_released("aim"):
		set_aiming(false)

	var wants_fire := is_firing or Input.is_action_pressed("fire")
	if auto_fire and _fire_cooldown <= 0.0 and _target_in_crosshair():
		wants_fire = true
	if not wants_fire:
		_fired_once = false
	elif _fire_cooldown <= 0.0:
		if bool(weapon["automatic"]) or not _fired_once:
			_shoot()


## إطلاق تلقائي: يتحقق من وجود عدو في مركز الشاشة فقط.
func _target_in_crosshair() -> bool:
	if not alive:
		return false
	var origin := camera.global_position
	var direction := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 120.0,
			0b111, [get_rid()])
	var result := space.intersect_ray(query)
	if result.is_empty():
		return false
	var collider = result["collider"]
	return collider != null and collider.is_in_group("enemy")


var _fired_once := false


func release_trigger() -> void:
	_fired_once = false
	is_firing = false


func _shoot() -> void:
	var weapon := current_weapon()
	if weapon.is_empty():
		return

	if bool(weapon["throwable"]):
		throw_grenade()
		return
	if bool(weapon["melee"]):
		_melee(weapon)
		return

	var magazine := int(weapon["magazine_current"])
	if magazine <= 0:
		start_reload()
		return

	weapon["magazine_current"] = magazine - 1
	_fired_once = true
	_fire_cooldown = 60.0 / float(weapon["rpm"])
	_recoil += float(weapon["recoil"]) * 0.012
	ammo_changed.emit(int(weapon["magazine_current"]), int(weapon["reserve_current"]),
			Loc.t(String(weapon["name_key"])))

	AudioManager.play_weapon(String(weapon["sound"]), muzzle.global_position, 0.0)
	if view_weapon != null:
		view_weapon.on_fire(float(weapon["recoil"]))
	_muzzle_flash()
	# اهتزاز الهاتف عند الإطلاق
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(24)

	if bool(weapon["explosive"]):
		_fire_rocket(weapon)
		return

	var spread := float(weapon["aim_spread"] if is_aiming else weapon["spread"])
	if not is_aiming:
		spread += clampf(Vector2(velocity.x, velocity.z).length() * 0.22, 0.0, 2.6)
	if is_crouching:
		spread *= 0.7

	for _pellet in int(weapon["pellets"]):
		_fire_ray(spread, weapon)


func _fire_ray(spread_degrees: float, weapon: Dictionary) -> void:
	var origin := camera.global_position
	var basis := camera.global_transform.basis
	var forward := -basis.z

	var spread_rad := deg_to_rad(spread_degrees)
	var offset := Vector3(randf_range(-spread_rad, spread_rad),
			randf_range(-spread_rad, spread_rad), 0.0)
	var direction := (forward + basis.x * offset.x + basis.y * offset.y).normalized()
	var max_range := float(weapon["range"])

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * max_range,
			0b111, [get_rid()])
	query.collide_with_areas = false
	var result := space.intersect_ray(query)

	if result.is_empty():
		return

	var collider = result["collider"]
	var hit_position: Vector3 = result["position"]
	var damage := float(weapon["damage"])

	# تلاشي الضرر مع المسافة بعد 65% من المدى
	var distance := origin.distance_to(hit_position)
	var falloff := clampf(1.0 - maxf(0.0, distance - max_range * 0.65) / (max_range * 0.6),
			0.45, 1.0)
	damage *= falloff

	if collider != null and collider.has_method("take_damage"):
		var headshot := false
		if collider.has_method("is_head_position"):
			headshot = collider.is_head_position(hit_position)
		var multiplier := float(weapon["headshot_mult"]) if headshot else 1.0
		var killed: bool = collider.take_damage(damage * multiplier, headshot, self)
		hit_confirmed.emit(headshot, killed)
		if collider.is_in_group("enemy") and killed:
			kills += 1
			if headshot:
				headshots += 1
			SaveSystem.register_kill(headshot)
			killed_enemy.emit(collider, headshot)
		elif not collider.is_in_group("enemy"):
			AudioManager.play_3d("impact_flesh" if collider.is_in_group("damageable")
					else "impact_metal", hit_position, -6.0)
	else:
		if result.has("normal") and result["normal"].y > 0.6:
			AudioManager.play_3d("impact_dirt", hit_position, -9.0)
		else:
			AudioManager.play_3d("impact_metal", hit_position, -8.0)
		_spawn_impact(hit_position)


func _fire_rocket(weapon: Dictionary) -> void:
	var rocket_script := preload("res://scripts/combat/rocket.gd")
	var rocket := CharacterBody3D.new()
	rocket.set_script(rocket_script)
	rocket.damage = float(weapon["damage"])
	rocket.blast_radius = float(weapon["blast_radius"])
	rocket.shooter = self
	get_tree().current_scene.add_child(rocket)
	rocket.global_position = camera.global_position - camera.global_transform.basis.z * 0.8
	rocket.direction = -camera.global_transform.basis.z


func _melee(weapon: Dictionary) -> void:
	_fire_cooldown = 60.0 / float(weapon["rpm"])
	AudioManager.play_3d("weapon_switch", global_position, -6.0, 1.6)

	var origin := global_position + Vector3(0, 1.1, 0)
	var forward := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin,
			origin + forward * float(weapon["range"]), 0b111, [get_rid()])
	var result := space.intersect_ray(query)
	if result.is_empty():
		return
	var collider = result["collider"]
	if collider != null and collider.has_method("take_damage"):
		var killed: bool = collider.take_damage(float(weapon["damage"]), false, self)
		hit_confirmed.emit(false, killed)
		if collider.is_in_group("enemy") and killed:
			kills += 1
			SaveSystem.register_kill(false)
			killed_enemy.emit(collider, false)


func start_reload() -> void:
	var weapon := current_weapon()
	if weapon.is_empty() or _is_reloading:
		return
	if bool(weapon["melee"]) or bool(weapon["throwable"]):
		return
	if int(weapon["magazine_current"]) >= int(weapon["magazine"]) or int(weapon["reserve_current"]) <= 0:
		return

	_is_reloading = true
	_reload_timer = float(weapon["reload_time"])
	AudioManager.play_3d("reload", global_position, -4.0)


func _finish_reload() -> void:
	var weapon := current_weapon()
	if weapon.is_empty():
		return
	var capacity := int(weapon["magazine"])
	var current := int(weapon["magazine_current"])
	var needed := capacity - current
	var available := int(weapon["reserve_current"])
	var taken := mini(needed, available)
	weapon["magazine_current"] = current + taken
	weapon["reserve_current"] = available - taken
	_is_reloading = false
	ammo_changed.emit(int(weapon["magazine_current"]), int(weapon["reserve_current"]),
			Loc.t(String(weapon["name_key"])))


func is_reloading() -> bool:
	return _is_reloading


func reload_progress() -> float:
	var weapon := current_weapon()
	if not _is_reloading or weapon.is_empty():
		return 0.0
	var total := maxf(0.1, float(weapon["reload_time"]))
	return clampf(1.0 - _reload_timer / total, 0.0, 1.0)


func cycle_scope() -> void:
	var weapon := current_weapon()
	if weapon.is_empty():
		return
	var zooms: Array = weapon["scope_zooms"]
	if zooms.size() <= 1:
		return
	_scope_index = (_scope_index + 1) % zooms.size()
	scoped.emit(float(zooms[_scope_index]))


func scope_level() -> float:
	var weapon := current_weapon()
	if weapon.is_empty() or not is_aiming:
		return 1.0
	var zooms: Array = weapon["scope_zooms"]
	return float(zooms[clampi(_scope_index, 0, zooms.size() - 1)])


func _muzzle_flash() -> void:
	var source := muzzle
	if first_person and view_weapon != null and view_weapon.muzzle_node() != null:
		source = view_weapon.muzzle_node()
	if source == null:
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.82, 0.45)
	light.light_energy = 4.0
	light.omni_range = 7.0
	source.add_child(light)
	var flash_tween := light.create_tween()
	flash_tween.tween_interval(0.05)
	flash_tween.tween_callback(light.queue_free)


func _spawn_impact(position: Vector3) -> void:
	var impact := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.045
	sphere.height = 0.09
	impact.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.78, 0.36)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.6, 0.2)
	impact.material_override = mat
	get_tree().current_scene.add_child(impact)
	impact.global_position = position
	var impact_tween := impact.create_tween()
	impact_tween.tween_interval(0.9)
	impact_tween.tween_callback(impact.queue_free)


# ------------------------------------------------------------- القنابل/العلاج
func throw_grenade() -> void:
	if grenades <= 0 or _grenade_cooldown > 0.0:
		return
	grenades -= 1
	_grenade_cooldown = 0.9
	grenades_changed.emit(grenades)
	AudioManager.play_3d("weapon_switch", global_position, -6.0, 0.8)

	var data := WeaponsDB.get_weapon("grenade")
	var grenade_script := preload("res://scripts/combat/grenade.gd")
	var grenade := RigidBody3D.new()
	grenade.set_script(grenade_script)
	grenade.damage = float(data.get("damage", 140.0))
	grenade.blast_radius = float(data.get("blast_radius", 6.5))
	grenade.fuse_time = float(data.get("fuse", 3.2))
	grenade.thrower = self
	get_tree().current_scene.add_child(grenade)
	grenade.global_position = camera.global_position - camera.global_transform.basis.z * 0.6
	var throw_dir := (-camera.global_transform.basis.z + Vector3.UP * 0.22).normalized()
	grenade.linear_velocity = throw_dir * 16.0 + Vector3(0, 3.0, 0)
	grenade.angular_velocity = Vector3(randf_range(-4, 4), randf_range(-4, 4), 0)


func use_medkit() -> bool:
	if medkits <= 0 or _heal_cooldown > 0.0 or health >= max_health:
		return false
	medkits -= 1
	_heal_cooldown = 1.6
	heal(45.0)
	AudioManager.play_3d("heal", global_position, -4.0)
	medkits_changed.emit(medkits)
	return true


func add_medkit(count: int = 1) -> void:
	medkits = mini(MAX_MEDKITS, medkits + count)
	medkits_changed.emit(medkits)


func add_grenades(count: int = 1) -> void:
	grenades = mini(MAX_GRENADES, grenades + count)
	grenades_changed.emit(grenades)


func add_ammo(fraction: float = 0.5) -> void:
	for weapon in weapons:
		if bool(weapon["melee"]) or bool(weapon["throwable"]):
			continue
		var reserve := int(weapon["reserve"])
		weapon["reserve_current"] = mini(reserve,
				int(weapon["reserve_current"]) + int(reserve * fraction))
	var current := current_weapon()
	if not current.is_empty():
		ammo_changed.emit(int(current["magazine_current"]), int(current["reserve_current"]),
				Loc.t(String(current["name_key"])))


# ------------------------------------------------------------------ الضرر
func take_damage(amount: float, headshot: bool = false, _source: Node = null,
		from_position: Variant = null) -> bool:
	if not alive:
		return false
	var incoming := amount
	if headshot:
		incoming *= 1.9

	if armor > 0.0:
		var absorbed := minf(armor, incoming * 0.55)
		armor -= absorbed
		incoming -= absorbed
		armor_changed.emit(armor, max_armor)

	health = maxf(0.0, health - incoming)
	health_changed.emit(health, max_health)

	if from_position is Vector3:
		damaged_from.emit((from_position - global_position).normalized())

	AudioManager.play_3d("player_hurt", global_position, -6.0)

	if health <= 0.0:
		_die()
	return health <= 0.0


func _die() -> void:
	if not alive:
		return
	alive = false
	is_firing = false
	if rig != null and not first_person:
		rig.play_death()
	if view_weapon != null:
		view_weapon.visible = false
	spring_arm.spring_length = 5.0
	player_died.emit()
	if current_vehicle != null:
		exit_vehicle(true)


func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func revive(at_position: Vector3, health_ratio: float = 1.0) -> void:
	alive = true
	health = max_health * clampf(health_ratio, 0.1, 1.0)
	armor = max_armor * 0.5
	health_changed.emit(health, max_health)
	armor_changed.emit(armor, max_armor)
	global_position = at_position
	velocity = Vector3.ZERO
	if rig != null:
		rig.dead = false
		rig.rotation_degrees = Vector3.ZERO
		rig.visible = not first_person
	if view_weapon != null:
		view_weapon.visible = first_person
	spring_arm.spring_length = 3.3


func is_head_position(world_position: Vector3) -> bool:
	return world_position.y >= global_position.y + 1.45


# ------------------------------------------------------------- التفاعل
func _tick_interaction() -> void:
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * INTERACT_RANGE,
			0b111, [get_rid()])
	query.collide_with_areas = true
	var result := space.intersect_ray(query)

	var target: Node = null
	if not result.is_empty():
		var collider = result["collider"]
		if collider is Node:
			target = _resolve_interactable(collider)

	if target == _interact_target:
		return

	_interact_target = target
	if target == null:
		interact_cleared.emit()
		return

	if target.has_method("interact_prompt"):
		interact_available.emit(String(target.interact_prompt()))
	else:
		interact_available.emit(Loc.t("hud_interact"))


func _resolve_interactable(node: Node) -> Node:
	var current := node
	while current != null:
		if current.has_method("can_interact") and current.can_interact(self):
			return current
		current = current.get_parent()
	return null


func interact() -> void:
	if _interact_target == null:
		return
	if _interact_target.has_method("interact"):
		_interact_target.interact(self)


# ------------------------------------------------------------- المركبات
func enter_vehicle(vehicle: Node, as_driver: bool = true) -> void:
	if vehicle == null or current_vehicle != null:
		return
	if not vehicle.has_method("add_occupant"):
		return
	if not vehicle.add_occupant(self, as_driver):
		return
	current_vehicle = vehicle
	rig.visible = false
	if view_weapon != null:
		view_weapon.visible = false
	camera.current = false
	velocity = Vector3.ZERO
	entered_vehicle.emit(vehicle)


func exit_vehicle(force: bool = false) -> void:
	if current_vehicle == null:
		return
	var vehicle := current_vehicle
	current_vehicle = null
	if vehicle.has_method("remove_occupant"):
		vehicle.remove_occupant(self)

	if not force:
		var exit_point: Vector3 = vehicle.global_position + vehicle.global_transform.basis.x * 2.0
		global_position = exit_point + Vector3(0, 1.0, 0)
	rig.visible = alive and not first_person
	if view_weapon != null:
		view_weapon.visible = alive and first_person
	if camera != null:
		camera.current = true
	exited_vehicle.emit()


func is_in_vehicle() -> bool:
	return current_vehicle != null


# --------------------------------------------------------------- التحريك
func _update_rig(delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	if view_weapon != null:
		view_weapon.move_speed = speed
		view_weapon.is_aiming = is_aiming and not _is_reloading
		view_weapon.is_reloading = _is_reloading
		view_weapon.add_sway(look_delta + Vector2(randf_range(-0.4, 0.4), randf_range(-0.4, 0.4)))
	if rig == null or first_person:
		return
	rig.animate(delta, speed, is_sprinting and speed > 6.0, is_crouching, is_aiming,
			_fire_cooldown > 0.0 and _is_reloading == false and weapons.size() > 0)


## تبديل بين منظور أول (مثل مراجع FPS) ومنظور ثالث.
func set_view_mode(fp: bool) -> void:
	first_person = fp
	if rig != null:
		rig.visible = not fp and alive
	if view_weapon != null:
		view_weapon.visible = fp and alive
	if first_person:
		spring_arm.spring_length = 0.0
		spring_arm.position = Vector3(0.0, 1.62, 0.0)
		camera.position = Vector3.ZERO
	else:
		spring_arm.spring_length = 3.3
		spring_arm.position = Vector3(0.52, 1.52, 0.0)


func toggle_view_mode() -> void:
	set_view_mode(not first_person)


# -------------------------------------------------------------- واجهة لمسية
func set_move_input(value: Vector2) -> void:
	move_input = value


func add_look_input(delta: Vector2) -> void:
	look_delta += delta


func set_firing(value: bool) -> void:
	if value and not is_firing:
		_fired_once = false
	is_firing = value
	if not value:
		_fired_once = false


func set_aiming(value: bool) -> void:
	is_aiming = value


func set_sprinting(value: bool) -> void:
	is_sprinting = value


func set_crouching(value: bool) -> void:
	is_crouching = value


func toggle_crouch() -> void:
	is_crouching = not is_crouching
