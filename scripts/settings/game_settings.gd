extends Node
## الإعدادات: رسومات، صوت (نواقل منفصلة)، تحكم، لغة، وتخطيط اللمس.
## تُحفظ في user://saddam_battle_settings.json

signal settings_changed

const SETTINGS_PATH := "user://saddam_battle_settings.json"

const QUALITY_ULTRA := "ultra"
const QUALITY_HIGH := "high"
const QUALITY_PERFORMANCE := "performance"
const QUALITY_AUTO := "auto"

var look_sensitivity: float = 0.22
var invert_y: bool = false
var fov: float = 75.0
var quality: String = QUALITY_AUTO
var language: String = "ar"

var master_volume: float = 0.9
var music_volume: float = 0.55
var sfx_volume: float = 0.85
var vehicle_volume: float = 0.8
var ui_volume: float = 0.7

var shadows_enabled: bool = true
var effects_enabled: bool = true
var touch_scale: float = 1.0
var touch_layout: Dictionary = {}

var resolved_quality: String = QUALITY_HIGH


func _ready() -> void:
	load_settings()
	resolve_quality()
	call_deferred("apply_all")


func defaults() -> Dictionary:
	return {
		"look_sensitivity": 0.22,
		"invert_y": false,
		"fov": 75.0,
		"quality": QUALITY_AUTO,
		"language": "ar",
		"master_volume": 0.9,
		"music_volume": 0.55,
		"sfx_volume": 0.85,
		"vehicle_volume": 0.8,
		"ui_volume": 0.7,
		"shadows_enabled": true,
		"effects_enabled": true,
		"touch_scale": 1.0,
		"touch_layout": {}
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

	look_sensitivity = clampf(float(data["look_sensitivity"]), 0.05, 0.9)
	invert_y = bool(data["invert_y"])
	fov = clampf(float(data["fov"]), 55.0, 100.0)
	quality = String(data["quality"])
	if quality not in [QUALITY_ULTRA, QUALITY_HIGH, QUALITY_PERFORMANCE, QUALITY_AUTO]:
		quality = QUALITY_AUTO
	language = String(data["language"])
	master_volume = clampf(float(data["master_volume"]), 0.0, 1.0)
	music_volume = clampf(float(data["music_volume"]), 0.0, 1.0)
	sfx_volume = clampf(float(data["sfx_volume"]), 0.0, 1.0)
	vehicle_volume = clampf(float(data["vehicle_volume"]), 0.0, 1.0)
	ui_volume = clampf(float(data["ui_volume"]), 0.0, 1.0)
	shadows_enabled = bool(data["shadows_enabled"])
	effects_enabled = bool(data["effects_enabled"])
	touch_scale = clampf(float(data["touch_scale"]), 0.7, 1.5)
	touch_layout = data["touch_layout"] if typeof(data["touch_layout"]) == TYPE_DICTIONARY else {}


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"look_sensitivity": look_sensitivity,
		"invert_y": invert_y,
		"fov": fov,
		"quality": quality,
		"language": language,
		"master_volume": master_volume,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"vehicle_volume": vehicle_volume,
		"ui_volume": ui_volume,
		"shadows_enabled": shadows_enabled,
		"effects_enabled": effects_enabled,
		"touch_scale": touch_scale,
		"touch_layout": touch_layout
	}, "\t"))
	file.close()
	settings_changed.emit()


# --------------------------------------------------------------- الجودة
## اقتراح جودة حسب قدرات الجهاز — لا نضمن أداءً متماثلاً على كل الهواتف.
func suggest_quality() -> String:
	var cores := OS.get_processor_count()
	var adapter := RenderingServer.get_video_adapter_name().to_lower()
	var mobile := OS.has_feature("mobile") or OS.has_feature("android")

	if not mobile:
		return QUALITY_ULTRA

	var score := 0
	if cores >= 8:
		score += 2
	elif cores >= 6:
		score += 1
	for keyword in ["adreno 7", "adreno 6", "mali-g7", "mali-g6", "apple a1", "apple a9"]:
		if adapter.findn(keyword) != -1:
			score += 1
			break

	if score >= 3:
		return QUALITY_HIGH
	return QUALITY_PERFORMANCE


func resolve_quality() -> String:
	resolved_quality = suggest_quality() if quality == QUALITY_AUTO else quality
	return resolved_quality


func set_quality(value: String) -> void:
	quality = value
	save_settings()
	resolve_quality()
	apply_video()


## هل يوجد معالج رسومات حقيقي؟ (تشغيل الاختبارات headless بلا رسومات)
func has_renderer() -> bool:
	return DisplayServer.get_name() != "headless"


func is_ultra() -> bool:
	return resolved_quality == QUALITY_ULTRA


func is_performance() -> bool:
	return resolved_quality == QUALITY_PERFORMANCE


# --------------------------------------------------------------- التطبيق
func apply_all() -> void:
	apply_video()
	apply_audio()
	apply_locale()


func apply_video() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var msaa := Viewport.MSAA_2X
	var shadow_size := 2048
	var scale_3d := 1.0

	match resolved_quality:
		QUALITY_ULTRA:
			msaa = Viewport.MSAA_4X
			shadow_size = 4096
			scale_3d = 1.0
		QUALITY_PERFORMANCE:
			msaa = Viewport.MSAA_DISABLED
			shadow_size = 1024
			scale_3d = 0.82
		_:
			msaa = Viewport.MSAA_2X
			shadow_size = 2048
			scale_3d = 1.0

	if not shadows_enabled:
		shadow_size = 512
		scale_3d = minf(scale_3d, 0.9)

	viewport.msaa_3d = msaa
	viewport.scaling_3d_scale = scale_3d
	RenderingServer.directional_shadow_atlas_set_size(shadow_size, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM if resolved_quality != QUALITY_ULTRA
		else RenderingServer.SHADOW_QUALITY_SOFT_HIGH
	)


func apply_audio() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	audio.ensure_buses()
	audio.set_bus_volume("Master", master_volume)
	audio.set_bus_volume("Music", master_volume * music_volume)
	audio.set_bus_volume("SFX", master_volume * sfx_volume)
	audio.set_bus_volume("Weapons", master_volume * sfx_volume)
	audio.set_bus_volume("Vehicles", master_volume * vehicle_volume)
	audio.set_bus_volume("UI", master_volume * ui_volume)


func apply_locale() -> void:
	var locale := get_node_or_null("/root/Loc")
	if locale != null and locale.language != language:
		locale.set_language(language)


func set_language(code: String) -> void:
	language = code
	save_settings()
	apply_locale()
	settings_changed.emit()


func set_touch_layout(layout: Dictionary) -> void:
	touch_layout = layout
	save_settings()


func reset_touch_layout() -> void:
	touch_layout = {}
	save_settings()
