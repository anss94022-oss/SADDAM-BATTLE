extends Node
## مدير الصوت: نواقل مستقلة، مؤثرات ثلاثية الأبعاد، موسيقى وأجواء.

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const BUS_WEAPONS := "Weapons"
const BUS_VEHICLES := "Vehicles"
const BUS_UI := "UI"

const SFX_ROOT := "res://assets/audio/sfx/"
const MUSIC_ROOT := "res://assets/audio/music/"

var _cache: Dictionary = {}
var _music_player: AudioStreamPlayer
var _music_track := ""
var _ambience_player: AudioStreamPlayer
var _ambience_track := ""
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_buses()
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = BUS_MUSIC
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)

	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = BUS_SFX
	add_child(_ambience_player)

	call_deferred("apply_volumes_from_settings")


func ensure_buses() -> void:
	for bus_name in [BUS_MUSIC, BUS_SFX, BUS_WEAPONS, BUS_VEHICLES, BUS_UI]:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		var parent_index := AudioServer.get_bus_index(BUS_MASTER)
		AudioServer.set_bus_send(index, BUS_MASTER if parent_index >= 0 else "Master")


func apply_volumes_from_settings() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	if settings == null:
		return
	settings.apply_audio()


func set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	var value := clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(max(0.001, value)))


func _load_stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path)
	if stream != null:
		_cache[path] = stream
	return stream


func sfx_path(name: String) -> String:
	if name.begins_with("res://"):
		return name
	if name.ends_with(".wav") or name.ends_with(".ogg"):
		return SFX_ROOT + name
	return SFX_ROOT + name + ".wav"


## مؤثر صوتي ثلاثي الأبعاد في نقطة داخل العالم، يُحرَّر تلقائياً.
func play_3d(sound: String, position: Vector3, volume_db: float = 0.0,
		pitch: float = 1.0, bus: String = BUS_SFX,
		max_distance: float = 120.0) -> AudioStreamPlayer3D:
	var stream := _load_stream(sfx_path(sound))
	if stream == null:
		return null
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null

	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.4, 2.4)
	player.max_distance = max_distance
	player.unit_size = 12.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.attenuation_filter_cutoff_hz = 12000.0
	tree.current_scene.add_child(player)
	player.global_position = position
	player.play()

	var length := stream.get_length() / max(0.4, player.pitch_scale)
	player.finished.connect(player.queue_free)
	tree.create_timer(max(0.05, length + 0.15)).timeout.connect(func():
		if is_instance_valid(player):
			player.queue_free()
	)
	return player


## مؤثر واجهة/غير موضعي.
func play_ui(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	play_2d(sound, BUS_UI, volume_db, pitch)


func play_2d(sound: String, bus: String = BUS_SFX, volume_db: float = 0.0,
		pitch: float = 1.0) -> void:
	var stream := _load_stream(sfx_path(sound))
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	player.volume_db = volume_db
	player.pitch_scale = clampf(pitch, 0.4, 2.4)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func play_weapon(sound: String, position: Vector3, volume_db: float = 0.0) -> void:
	play_3d(sound, position, volume_db, randf_range(0.94, 1.06), BUS_WEAPONS, 220.0)


func play_vehicle(sound: String, position: Vector3, volume_db: float = -6.0) -> void:
	play_3d(sound, position, volume_db, randf_range(0.9, 1.05), BUS_VEHICLES, 90.0)


func play_music(track: String, fade: float = 1.2) -> void:
	if _music_track == track and _music_player.playing:
		return
	var stream := _load_stream(MUSIC_ROOT + track + ".wav")
	if stream == null:
		return
	_music_track = track
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_begin = 0
		(stream as AudioStreamWAV).loop_end = int((stream as AudioStreamWAV).get_length() * (stream as AudioStreamWAV).mix_rate)

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()

	_music_player.stream = stream
	_music_player.volume_db = -40.0
	_music_player.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", 0.0, fade)


func stop_music(fade: float = 0.8) -> void:
	if not _music_player.playing:
		return
	_music_track = ""
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_player, "volume_db", -40.0, fade)
	_music_tween.tween_callback(_music_player.stop)


func play_ambience(track: String, volume_db: float = -14.0) -> void:
	if _ambience_track == track and _ambience_player.playing:
		return
	_ambience_track = track
	var stream := _load_stream(SFX_ROOT + track + ".wav")
	if stream == null:
		return
	if stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		(stream as AudioStreamWAV).loop_begin = 0
		(stream as AudioStreamWAV).loop_end = int((stream as AudioStreamWAV).get_length() * (stream as AudioStreamWAV).mix_rate)
	_ambience_player.stream = stream
	_ambience_player.volume_db = volume_db
	_ambience_player.play()


func stop_ambience() -> void:
	_ambience_track = ""
	_ambience_player.stop()


func play_ambience_loop(path: String, volume_db: float = -14.0) -> void:
	play_ambience(path, volume_db)
