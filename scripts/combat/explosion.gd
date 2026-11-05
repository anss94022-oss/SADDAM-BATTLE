extends RefCounted
class_name Explosion
## انفجار مشترك: ضرر إشعاعي، تحقق من خط الرؤية، مؤثرات، وصوت.

static func detonate(tree: SceneTree, position: Vector3, damage: float,
		radius: float, source: Node = null) -> int:
	if tree == null:
		return 0
	var hit_count := 0
	var audio := tree.root.get_node_or_null("AudioManager")

	if audio != null:
		audio.play_3d("explosion", position, 2.0)

	_spawn_visuals(tree, position, radius)

	var space: PhysicsDirectSpaceState3D = null
	var world := tree.current_scene
	if world is Node3D:
		space = (world as Node3D).get_world_3d().direct_space_state

	for node in tree.get_nodes_in_group("damageable"):
		if not (node is Node3D) or not is_instance_valid(node):
			continue
		if source != null and node == source:
			continue
		var target := node as Node3D
		var offset := target.global_position + Vector3(0, 1.0, 0) - position
		var distance := offset.length()
		if distance > radius:
			continue
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(position, target.global_position + Vector3(0, 1.0, 0), 1)
			if source is CollisionObject3D:
				query.exclude = [(source as CollisionObject3D).get_rid()]
			var result := space.intersect_ray(query)
			if not result.is_empty() and result["collider"] != target:
				# الهدف خلف ساتر صلب — ضرر مخفّض بدل منع كامل
				if distance > radius * 0.6:
					continue
		var falloff := clampf(1.0 - distance / radius, 0.15, 1.0)
		var amount := damage * falloff * falloff
		if target.has_method("take_damage"):
			# التأجيل يمنع أي إعادة دخول، ولا نمرر مصدراً قد يكون محرَّراً
			target.call_deferred("take_damage", amount, false, null, position)
			hit_count += 1

	# اهتزاز الكاميرا عبر إشارة للمشهد الرئيسي
	if world != null and world.has_method("on_explosion"):
		world.on_explosion(position, radius)

	return hit_count


static func _spawn_visuals(tree: SceneTree, position: Vector3, radius: float) -> void:
	var root := tree.current_scene
	if root == null or not GameSettings.has_renderer():
		return

	var holder := Node3D.new()
	holder.name = "ExplosionFX"
	root.add_child(holder)
	holder.global_position = position + Vector3(0, 1.0, 0)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 9.0
	light.omni_range = maxf(8.0, radius * 2.2)
	holder.add_child(light)

	var fireball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	fireball.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.16, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.45, 0.1)
	material.emission_energy_multiplier = 4.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fireball.material_override = material
	holder.add_child(fireball)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(fireball, "scale", Vector3.ONE * maxf(1.5, radius * 0.42), 0.28)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.75)
	tween.tween_property(light, "light_energy", 0.0, 0.5)
	tween.chain().tween_interval(0.6)
	tween.chain().tween_callback(holder.queue_free)

	if GameSettings.has_renderer():
		var smoke := CPUParticles3D.new()
		smoke.emitting = true
		smoke.one_shot = true
		smoke.amount = 24
		smoke.lifetime = 1.8
		smoke.direction = Vector3.UP
		smoke.spread = 55.0
		smoke.gravity = Vector3(0, 1.2, 0)
		smoke.initial_velocity_min = 1.5
		smoke.initial_velocity_max = 5.0
		smoke.scale_amount_min = 0.7
		smoke.scale_amount_max = 2.2
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.42
		smoke_mesh.height = 0.84
		smoke.mesh = smoke_mesh
		var smoke_mat := StandardMaterial3D.new()
		smoke_mat.albedo_color = Color(0.18, 0.17, 0.16, 0.55)
		smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smoke_mesh.material = smoke_mat
		holder.add_child(smoke)
		smoke.position = Vector3(0, -0.2, 0)
		var smoke_tween := smoke.create_tween()
		smoke_tween.tween_interval(2.4)
		smoke_tween.tween_callback(smoke.queue_free)
