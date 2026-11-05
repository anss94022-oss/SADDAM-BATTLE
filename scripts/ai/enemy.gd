extends CharacterBody3D
## عدوّ ذكي: حالات دورية/شك/تحقيق/مطاردة/قتال/ساتر/التفاف/انسحاب/موت،
## رؤية بمخروط وخط نظر، سمع، تنسيق جماعي، ومستويات صعوبة.

signal died(enemy: Node, headshot: bool)
signal damaged(amount: float)

enum State { PATROL, SUSPICIOUS, INVESTIGATE, COMBAT, RELOAD, FLANK, RETREAT, DEAD }

const EYE_HEIGHT := 1.58

var max_health := 100.0
var health := 100.0
var move_speed := 3.4
var accuracy := 0.62
var attack_damage := 9.0
var attack_interval := 1.35
var detection_range := 55.0
var fov_degrees := 110.0
var hearing_range := 34.0
var preferred_range := 18.0
var reaction_time := 0.55
var aggression := 0.6
var cover_usage := 0.55
var stationary := false
var difficulty := 0.6
var weapon_id := "rifle_ak"
var marked := false
var is_boss := false
var display_name := ""

var target: Node3D = null
var state: int = State.PATROL
var cover_points: Array = []

var _rig: SoldierRig
var _weapon: Dictionary = {}
var _magazine := 30
var _cooldown := 0.0
var _reload_timer := 0.0
var _state_timer := 0.0
var _awareness := 0.0
var _last_known := Vector3.ZERO
var _has_last_known := false
var _patrol_index := 0
var _patrol_points: Array = []
var _strafe_dir := 1.0
var _strafe_timer := 0.0
var _see_timer := 0.0
var _can_see := false
var _muzzle_light: OmniLight3D
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
var _reaction_timer := 0.0
var _flank_target := Vector3.ZERO
var _death_done := false
var _alert_share_timer := 0.0


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("damageable")
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	_strafe_dir = 1.0 if randf() > 0.5 else -1.0
	_weapon = WeaponsDB.get_weapon(weapon_id)
	if _weapon.is_empty():
		_weapon = WeaponsDB.get_weapon("rifle_ak")
	_magazine = int(_weapon.get("magazine", 30))
	_cooldown = randf_range(0.3, 1.2)
	_state_timer = randf_range(0.5, 2.0)
	_build_collision()
	_build_rig()
	if stationary:
		_patrol_points = [global_position]
	else:
		_patrol_points = _make_patrol_points()


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.75
	shape.shape = capsule
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)


func _build_rig() -> void:
	_rig = SoldierRig.new()
	_rig.name = "Rig"
	add_child(_rig)
	_rig.setup(true)
	if is_boss:
		_rig.scale = Vector3.ONE * 1.2
	_rig.set_weapon(weapon_id)

	_muzzle_light = OmniLight3D.new()
	_muzzle_light.light_color = Color(1.0, 0.55, 0.3)
	_muzzle_light.light_energy = 0.0
	_muzzle_light.omni_range = 6.0
	_muzzle_light.position = Vector3(0, 1.4, 0)
	add_child(_muzzle_light)


func _make_patrol_points() -> Array:
	var points: Array = [global_position]
	for index in 3:
		var angle := randf() * TAU
		var distance := randf_range(5.0, 16.0)
		points.append(global_position + Vector3(cos(angle) * distance, 0, sin(angle) * distance))
	return points


func set_cover_points(points: Array) -> void:
	cover_points = points


func is_head_position(world_position: Vector3) -> bool:
	var offset := 1.62 if not is_boss else 1.9
	return world_position.y >= global_position.y + offset - 0.18


func take_damage(amount: float, headshot: bool = false, source: Node = null,
		from_position: Variant = null) -> bool:
	if state == State.DEAD:
		return false

	health -= amount * (1.0 if not headshot else 1.0)
	damaged.emit(amount)

	if _rig != null:
		_rig.flash_damage()

	if state == State.PATROL or state == State.SUSPICIOUS or state == State.INVESTIGATE:
		_alert(source if source is Node3D else null, from_position)
		_awareness = 1.0
		_enter_combat()

	# الالتفاف أو الانسحاب عند انخفاض الصحة
	if health > 0.0:
		var ratio := health / max_health
		if ratio < 0.3 and difficulty > 0.7 and randf() < 0.35:
			_set_state(State.RETREAT)
		elif state == State.COMBAT and randf() < 0.25:
			_set_state(State.FLANK)

	if health <= 0.0:
		_die(headshot)
		return true
	return false


func _die(headshot: bool) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	remove_from_group("enemy")
	remove_from_group("damageable")
	set_physics_process(false)
	if _rig != null:
		_rig.play_death()
	died.emit(self, headshot)

	if not _death_done:
		_death_done = true
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(self):
				queue_free()
		)


# ------------------------------------------------------------------ الذكاء
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	_see_timer -= delta
	if _see_timer <= 0.0:
		_see_timer = 0.15 + randf() * 0.1
		_can_see = _check_vision()

	_update_awareness(delta)

	match state:
		State.PATROL:
			_do_patrol(delta)
		State.SUSPICIOUS:
			_do_suspicious(delta)
		State.INVESTIGATE:
			_do_investigate(delta)
		State.COMBAT:
			_do_combat(delta)
		State.RELOAD:
			_do_reload(delta)
		State.FLANK:
			_do_flank(delta)
		State.RETREAT:
			_do_retreat(delta)

	move_and_slide()

	if _rig != null:
		var speed := Vector2(velocity.x, velocity.z).length()
		_rig.animate(delta, speed, speed > 5.5, false,
				state == State.COMBAT or state == State.FLANK, _cooldown > 0.55 and _reaction_timer > 0.0)


func _update_awareness(delta: float) -> void:
	if _can_see:
		var distance := global_position.distance_to(target.global_position) if target != null else 999.0
		var gain := clampf(1.6 - distance / maxf(1.0, detection_range), 0.25, 1.6)
		if is_boss:
			gain *= 1.4
		_awareness = minf(1.0, _awareness + gain * delta * 1.6)
		_last_known = target.global_position
		_has_last_known = true
	else:
		_awareness = maxf(0.0, _awareness - delta * 0.22)

	if _awareness >= 0.75 and state in [State.PATROL, State.SUSPICIOUS, State.INVESTIGATE]:
		_enter_combat()
	elif _awareness > 0.2 and state == State.PATROL:
		_set_state(State.SUSPICIOUS)


func _check_vision() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.has_method("is_alive") and not target.is_alive():
		return false
	var to_target := target.global_position - global_position
	var distance := to_target.length()
	if distance > detection_range:
		return false

	var flat := Vector3(to_target.x, 0, to_target.z)
	if flat.length() > 0.1:
		var facing := -global_transform.basis.z
		var angle := rad_to_deg(facing.angle_to(flat.normalized()))
		if angle > fov_degrees * 0.5:
			return false

	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, EYE_HEIGHT, 0)
	var to := target.global_position + Vector3(0, 1.2, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1, [get_rid()])
	var result := space.intersect_ray(query)
	if result.is_empty():
		return true
	return result["collider"] == target


func _enter_combat() -> void:
	if state == State.DEAD:
		return
	_set_state(State.COMBAT)
	_reaction_timer = reaction_time
	_share_alert()


func _share_alert() -> void:
	if _alert_share_timer > 0.0:
		return
	_alert_share_timer = 4.0
	get_tree().call_group("enemy", "on_ally_alert", self, _last_known)


func on_ally_alert(ally: Node, position: Vector3) -> void:
	if state == State.DEAD or ally == self:
		return
	if state in [State.PATROL, State.SUSPICIOUS, State.INVESTIGATE]:
		if global_position.distance_to(position) < 45.0:
			_last_known = position
			_has_last_known = true
			_awareness = maxf(_awareness, 0.6)
			_set_state(State.INVESTIGATE)
			_state_timer = 6.0


## استجابة لإطلاق النار/الانفجارات — يُنادى عبر مجموعة enemy.
func hear_noise(position: Vector3, radius: float, loudness: float = 1.0) -> void:
	if state == State.DEAD:
		return
	if global_position.distance_to(position) > minf(hearing_range, radius):
		return
	if state in [State.PATROL, State.SUSPICIOUS, State.INVESTIGATE]:
		_last_known = position
		_has_last_known = true
		_awareness = maxf(_awareness, 0.45 * loudness)
		_set_state(State.INVESTIGATE)
		_state_timer = 7.0


func _alert(source: Node, from_position: Variant) -> void:
	if source is Node3D:
		target = source
		_last_known = source.global_position
	elif from_position is Vector3:
		_last_known = from_position
	_has_last_known = true


func _set_state(new_state: int) -> void:
	state = new_state
	_state_timer = 0.0


func _set_target_if_needed() -> void:
	if target != null and is_instance_valid(target):
		return
	var players := get_tree().get_nodes_in_group("player")
	for candidate in players:
		if candidate is Node3D and candidate.has_method("is_alive") and candidate.is_alive():
			target = candidate
			return


func _move_to(point: Vector3, speed_scale: float = 1.0, delta: float = 0.016) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length() < 0.6:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	direction = direction.normalized()
	var speed := move_speed * speed_scale
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	_face(direction)


func _face(direction: Vector3) -> void:
	if direction.length() < 0.05:
		return
	var target_yaw := atan2(direction.x, direction.z) + PI
	rotation.y = lerp_angle(rotation.y, target_yaw, 0.18)


# ---------------------------------------------------------------- الحالات
func _do_patrol(delta: float) -> void:
	_set_target_if_needed()
	if _patrol_points.is_empty():
		return
	var point: Vector3 = _patrol_points[_patrol_index]
	if global_position.distance_to(point) < 1.5:
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		_state_timer = randf_range(0.4, 1.4)
		return
	_state_timer += delta
	if _state_timer > 0.0:
		_move_to(point, 0.45, delta)


func _do_suspicious(delta: float) -> void:
	_state_timer += delta
	# يقف وينظر حوله ثم يذهب للتحقيق
	if _state_timer > 1.4:
		if _has_last_known:
			_set_state(State.INVESTIGATE)
			_state_timer = 0.0
		else:
			_set_state(State.PATROL)
	rotate_y(delta * 0.9)
	velocity.x = 0.0
	velocity.z = 0.0


func _do_investigate(delta: float) -> void:
	_state_timer += delta
	if not _has_last_known:
		_set_state(State.PATROL)
		return
	if global_position.distance_to(_last_known) > 2.2:
		_move_to(_last_known, 0.78, delta)
	else:
		rotate_y(delta * 1.2)
		velocity.x = 0.0
		velocity.z = 0.0
		if _state_timer > 6.0:
			_set_state(State.PATROL)
	if _state_timer > 14.0:
		_set_state(State.PATROL)


func _do_combat(delta: float) -> void:
	_set_target_if_needed()
	if target == null:
		_set_state(State.PATROL)
		return
	if _can_see:
		_last_known = target.global_position
		_has_last_known = true
	elif _has_last_known and global_position.distance_to(_last_known) > 2.5:
		_move_to(_last_known, 0.85, delta)

	_reaction_timer = maxf(0.0, _reaction_timer - delta)

	var distance := global_position.distance_to(target.global_position)
	var to_target := target.global_position - global_position
	to_target.y = 0.0

	if to_target.length() > 0.1 and _can_see:
		_face(to_target.normalized())

	# الحركة التكتيكية: اقتراب/ابتعاد/التفاف جانبي
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.8, 2.2)
		if randf() < cover_usage and not stationary:
			_seek_cover()
		else:
			_strafe_dir *= -1.0

	if not stationary:
		var desired := Vector3.ZERO
		if distance > preferred_range * 1.35:
			desired += to_target.normalized() * move_speed
		elif distance < preferred_range * 0.55:
			desired -= to_target.normalized() * move_speed * 0.7
		if _can_see:
			var side := to_target.normalized().cross(Vector3.UP) * _strafe_dir
			desired += side * move_speed * 0.45 * (0.4 + aggression)
		velocity.x = desired.x
		velocity.z = desired.z

	# إطلاق النار
	_cooldown -= delta
	if _can_see and _reaction_timer <= 0.0 and _cooldown <= 0.0 and _magazine > 0:
		_attack(distance)
	elif _magazine <= 0:
		_start_reload()


func _seek_cover() -> void:
	if cover_points.is_empty():
		return
	var best := Vector3.ZERO
	var best_score := -INF
	var threat := target.global_position if target != null else global_position
	for point in cover_points:
		var position: Vector3 = point
		var distance := position.distance_to(global_position)
		if distance > 18.0 or distance < 1.5:
			continue
		var cover_from_threat := position.distance_to(threat)
		var score := cover_from_threat * 0.1 - distance
		if score > best_score:
			best_score = score
			best = position
	if best != Vector3.ZERO:
		_flank_target = best
		if state == State.COMBAT:
			_set_state(State.FLANK)


func _do_flank(delta: float) -> void:
	_state_timer += delta
	_move_to(_flank_target, 0.95, delta)
	if global_position.distance_to(_flank_target) < 1.6 or _state_timer > 4.0:
		_set_state(State.COMBAT)


func _do_retreat(delta: float) -> void:
	_state_timer += delta
	if target != null:
		var away := global_position - target.global_position
		away.y = 0.0
		if away.length() > 0.1:
			_move_to(global_position + away.normalized() * 6.0, 1.0, delta)
	if _state_timer > 3.5:
		_set_state(State.COMBAT)


func _do_reload(delta: float) -> void:
	_reload_timer -= delta
	velocity.x = 0.0
	velocity.z = 0.0
	if _reload_timer <= 0.0:
		_magazine = int(_weapon.get("magazine", 30))
		_set_state(State.COMBAT)


func _start_reload() -> void:
	if state in [State.RELOAD, State.DEAD]:
		return
	_set_state(State.RELOAD)
	_reload_timer = float(_weapon.get("reload_time", 2.2)) * randf_range(0.9, 1.25)


func _attack(distance: float) -> void:
	_magazine -= 1
	_cooldown = attack_interval * randf_range(0.85, 1.2)
	_reaction_timer = reaction_time * 0.35

	if _muzzle_light != null:
		_muzzle_light.light_energy = 3.0
		get_tree().create_timer(0.05).timeout.connect(func():
			if is_instance_valid(_muzzle_light):
				_muzzle_light.light_energy = 0.0
		)

	AudioManager.play_3d(String(_weapon.get("sound", "shot_rifle")),
			global_position + Vector3(0, 1.4, 0), -4.0, randf_range(0.95, 1.05))

	# دقة تعتمد على المسافة والحركة والصعوبة
	var moving_penalty := 0.65 if Vector2(velocity.x, velocity.z).length() > 2.0 else 1.0
	var range_factor := clampf(1.25 - distance / maxf(1.0, detection_range), 0.18, 1.0)
	var hit_chance := accuracy * moving_penalty * range_factor * (0.75 + difficulty * 0.35)

	if randf() <= hit_chance and target != null and target.has_method("take_damage"):
		var damage_amount := attack_damage * randf_range(0.85, 1.15)
		if bool(_weapon.get("explosive", false)):
			var rocket_script := preload("res://scripts/combat/rocket.gd")
			var rocket := CharacterBody3D.new()
			rocket.set_script(rocket_script)
			rocket.damage = attack_damage * 3.0
			rocket.blast_radius = 5.0
			rocket.shooter = self
			get_tree().current_scene.add_child(rocket)
			rocket.global_position = global_position + Vector3(0, 1.4, 0) - \
					global_transform.basis.z * 0.8
			rocket.direction = (target.global_position + Vector3(0, 1.0, 0) - \
					rocket.global_position).normalized()
		else:
			target.take_damage(damage_amount, false, self, global_position)
			AudioManager.play_3d("impact_flesh", target.global_position, -12.0)
	# صوت الرصاص يجذب بقية الأعداء
	get_tree().call_group("enemy", "hear_noise", global_position, 30.0, 0.7)


func is_alive() -> bool:
	return state != State.DEAD


func state_name() -> String:
	return State.keys()[state]
