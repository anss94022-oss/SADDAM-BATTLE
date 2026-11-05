extends CharacterBody3D
## رهينة: تُحرَّر بالتفاعل ثم تتبع اللاعب حتى منطقة الإخلاء.

signal freed(hostage: Node)
signal died(hostage: Node)

var freed_flag := false
var rescued := false
var health := 60.0
var follow_target: Node3D = null
var display_name := ""

var _rig: SoldierRig
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 24.0)
var _offset := Vector3.ZERO


func _ready() -> void:
	add_to_group("hostage")
	add_to_group("damageable")
	set_collision_layer_value(6, true)
	set_collision_mask_value(1, true)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.7
	shape.shape = capsule
	shape.position = Vector3(0, 0.85, 0)
	add_child(shape)

	_rig = SoldierRig.new()
	add_child(_rig)
	_rig.setup(false, Color(0.55, 0.52, 0.42))
	_rig.set_weapon("knife")
	_offset = Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))


func can_interact(_player: Node) -> bool:
	return not freed_flag and not rescued


func interact_prompt() -> String:
	return Loc.t("hud_rescue")


func interact(player: Node) -> void:
	if freed_flag or rescued:
		return
	freed_flag = true
	follow_target = player as Node3D
	if _rig != null:
		_rig.set_weapon("knife")
	freed.emit(self)


func _physics_process(delta: float) -> void:
	if rescued:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	if freed_flag and follow_target != null and is_instance_valid(follow_target):
		var goal := follow_target.global_position + _offset
		var to_goal := goal - global_position
		to_goal.y = 0.0
		if to_goal.length() > 2.4:
			var direction := to_goal.normalized()
			velocity.x = direction.x * 5.4
			velocity.z = direction.z * 5.4
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z) + PI, 0.2)
			if _rig != null:
				_rig.animate(delta, 5.4, false, false, false, false)
		else:
			velocity.x = 0.0
			velocity.z = 0.0
			if _rig != null:
				_rig.animate(delta, 0.0, false, false, false, false)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		if _rig != null:
			_rig.animate(delta, 0.0, false, false, false, false)

	move_and_slide()


func take_damage(amount: float, _headshot: bool = false, _source: Node = null,
		_from_position: Variant = null) -> bool:
	if rescued:
		return false
	health -= amount
	if health <= 0.0:
		rescued = true
		if _rig != null:
			_rig.play_death()
		died.emit(self)
		set_physics_process(false)
		return true
	return false


func mark_rescued() -> void:
	rescued = true
	set_physics_process(false)
	visible = false
	set_collision_layer_value(6, false)


func is_alive() -> bool:
	return not rescued
