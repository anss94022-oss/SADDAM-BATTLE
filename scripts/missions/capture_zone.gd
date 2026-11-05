extends Node3D
## منطقة سيطرة بصرية: حلقة أرضية يتغير لونها حسب الحالة.

var radius := 11.0
var owner_team := -1
var _ring: MeshInstance3D
var _material: StandardMaterial3D
var _light: OmniLight3D


func setup(zone_radius: float) -> void:
	radius = zone_radius
	if _ring != null:
		_ring.queue_free()
		_ring = null
		if _light != null:
			_light.queue_free()
			_light = null
	_build()


func _ready() -> void:
	if _ring == null:
		_build()


func _build() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.55
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 8
	_ring.mesh = torus
	_ring.position = Vector3(0, 0.12, 0)
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.3, 0.7, 1.0, 0.55)
	_material.emission_enabled = true
	_material.emission = Color(0.2, 0.5, 1.0)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = _material
	add_child(_ring)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.35, 0.6, 1.0)
	_light.light_energy = 1.4
	_light.omni_range = radius * 1.4
	_light.position = Vector3(0, 2.0, 0)
	add_child(_light)


func contains(position: Vector3) -> bool:
	var flat := Vector3(position.x - global_position.x, 0, position.z - global_position.z)
	return flat.length() <= radius


func set_progress(ratio: float, contested: bool = false) -> void:
	if _material == null:
		return
	var color := Color(0.3, 0.7, 1.0, 0.55)
	if contested:
		color = Color(1.0, 0.35, 0.25, 0.6)
	elif ratio > 0.0:
		color = Color(0.35, 1.0, 0.45, 0.55)
	_material.albedo_color = color
	if _light != null:
		_light.light_color = color
		_light.light_energy = 1.0 + ratio * 2.0
