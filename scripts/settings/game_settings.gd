extends Node
## إعدادات اللعبة: الحساسية، جودة الرسوم، الصوتيات، اللغة.
## تُحفظ محلياً في user://saddam_battle_settings.json

const SETTINGS_PATH := "user://saddam_battle_settings.json"

const QUALITY_ULTRA := "ultra"
const QUALITY_HIGH := "high"
const QUALITY_PERFORMANCE := "performance"

var look_sensitivity: float = 0.22
var invert_y: bool = false
var quality: String = QUALITY_HIGH
var master_volume: float = 0.9
var fov: float = 75.0
var language: String = "ar"


func _ready() -> void:
	load_settings()


func defaults() -> Dictionary:
	return {
		"look_sensitivity": 0.22,
		"invert_y": false,
		"quality": QUALITY_HIGH,
		"master_volume": 0.9,
		"fov": 75.0,
		"language": "ar"
	}


func load_settings() -> void:
	var data := defaults()

	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY:
				for key in data.keys():
					if parsed.has(key):
						data[key] = parsed[key]

	look_sensitivity = clampf(float(data["look_sensitivity"]), 0.05, 0.8)
	invert_y = bool(data["invert_y"])
	quality = String(data["quality"])
	master_volume = clampf(float(data["master_volume"]), 0.0, 1.0)
	fov = clampf(float(data["fov"]), 55.0, 100.0)
	language = String(data["language"])

	_apply_audio()


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return

	file.store_string(JSON.stringify({
		"look_sensitivity": look_sensitivity,
		"invert_y": invert_y,
		"quality": quality,
		"master_volume": master_volume,
		"fov": fov,
		"language": language
	}, "\t"))
	file.close()


func set_quality(value: String) -> void:
	quality = value
	save_settings()
	apply_to_viewport()


func _apply_audio() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(max(0.0001, master_volume)))


func apply_to_viewport() -> void:
	_apply_audio()

	match quality:
		QUALITY_ULTRA:
			RenderingServer.viewport_set_msaa_3d(
				get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_4X
			)
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
		QUALITY_PERFORMANCE:
			RenderingServer.viewport_set_msaa_3d(
				get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_DISABLED
			)
			RenderingServer.directional_shadow_atlas_set_size(1024, true)
		_:
			RenderingServer.viewport_set_msaa_3d(
				get_viewport().get_viewport_rid(), RenderingServer.VIEWPORT_MSAA_2X
			)
			RenderingServer.directional_shadow_atlas_set_size(2048, true)
