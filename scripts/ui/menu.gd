extends CanvasLayer
## كل قوائم اللعبة: الرئيسية، الحملة، اختيار المهمة، اللعب الجماعي، صالة الانتظار،
## مستودع الأسلحة، الإنجازات، الإعدادات (رسومات/صوت/تحكم/لغة)، الإيقاف، النتائج.

signal new_game_requested
signal continue_requested
signal mission_selected(index: int)
signal armory_equip_requested(weapon_id: String)
signal armory_unlock_requested(weapon_id: String)
signal mp_host_requested(config: Dictionary)
signal mp_join_requested(config: Dictionary)
signal mp_leave_requested
signal mp_ready_toggled(value: bool)
signal mp_start_requested
signal mp_mode_changed(mode: int)
signal resume_requested
signal retry_requested
signal next_mission_requested
signal back_to_menu_requested
signal touch_editor_requested
signal quit_requested

const ACCENT := Color(0.96, 0.66, 0.26)
const TEXT := Color(0.94, 0.96, 1.0)
const MUTED := Color(0.66, 0.74, 0.86)
const BG := Color(0.03, 0.05, 0.08, 0.97)

const ACHIEVEMENTS := [
	["first_blood", "ach_first_blood_name", "ach_first_blood_desc"],
	["marksman", "ach_marksman_name", "ach_marksman_desc"],
	["survivor", "ach_survivor_name", "ach_survivor_desc"],
	["campaign", "ach_campaign_name", "ach_campaign_desc"],
	["crew", "ach_crew_name", "ach_crew_desc"],
	["driver", "ach_driver_name", "ach_driver_desc"],
	["pilot", "ach_pilot_name", "ach_pilot_desc"],
	["demolition", "ach_demolition_name", "ach_demolition_desc"],
	["untouchable", "ach_untouchable_name", "ach_untouchable_desc"],
	["collector", "ach_collector_name", "ach_collector_desc"]
]

const MAPS := ["village", "base", "factory", "mountain", "convoy", "training"]

var _panels: Dictionary = {}
var _current := "main"
var _back_target := "main"
var _campaign: Array = []
var _lobby_state: Dictionary = {}
var _mp_mode := 0
var _mp_map := "village"
var _mp_max := 5
var _mp_password := ""
var _mp_ip := "192.168.1.10"
var _mp_port := 7777
var _result_stats: Dictionary = {}


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	Loc.language_changed.connect(func(_code: String): _rebuild())
	_build_all()


func _rebuild() -> void:
	for panel in _panels.values():
		if is_instance_valid(panel):
			panel.queue_free()
	_panels.clear()
	_build_all()
	_match_back_target()


func _match_back_target() -> void:
	match _back_target:
		"pause":
			show_pause()
		"missions":
			show_missions()
		"lobby":
			show_lobby(_lobby_state)
		"settings_from_lobby":
			show_lobby(_lobby_state)
		_:
			show_main()


func _load_campaign() -> void:
	_campaign = []
	if FileAccess.file_exists("res://data/missions/missions.json"):
		var file := FileAccess.open("res://data/missions/missions.json", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("campaign"):
			_campaign = parsed["campaign"]


# ---------------------------------------------------------------- البناء
func _build_all() -> void:
	_load_campaign()
	_build_main()
	_build_missions()
	_build_multiplayer()
	_build_lobby()
	_build_armory()
	_build_achievements()
	_build_settings()
	_build_pause()
	_build_result()
	hide_all()


func _panel(key: String, title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.layout_direction = Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR

	var style := StyleBoxFlat.new()
	style.bg_color = BG
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)

	if title != "":
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", 30)
		heading.add_theme_color_override("font_color", ACCENT)
		box.add_child(heading)

	_panels[key] = panel
	return box


func _button(parent: Node, text: String, on_press: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 50)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color(0.08, 0.06, 0.03) if primary else TEXT)

	var style := StyleBoxFlat.new()
	style.bg_color = ACCENT if primary else Color(0.10, 0.16, 0.24, 0.95)
	style.set_corner_radius_all(7)
	style.border_color = Color(0.28, 0.44, 0.6, 0.7)
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.74, 0.38) if primary else Color(0.16, 0.26, 0.36, 0.98)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("disabled", style)
	button.pressed.connect(func():
		AudioManager.play_ui("ui_click", -6.0)
		on_press.call()
	)
	parent.add_child(button)
	return button


func _text(parent: Node, value: String, size: int = 15, color: Color = MUTED) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _slider(parent: Node, label_text: String, min_value: float, max_value: float,
		step: float, value: float, on_change: Callable) -> void:
	_text(parent, label_text, 15, TEXT)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 34)
	slider.value_changed.connect(on_change)
	parent.add_child(slider)


# --------------------------------------------------------------- الرئيسية
func _build_main() -> void:
	var box := _panel("main", "")

	var title := Label.new()
	title.text = Loc.t("app_title")
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	_text(box, Loc.t("app_subtitle"), 17, MUTED)
	box.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)

	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(210, 0)
	row.add_child(portrait_panel)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(210, 330)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/characters/hero_key.png"):
		portrait.texture = load("res://assets/characters/hero_key.png")
	portrait_panel.add_child(portrait)

	var buttons := VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 9)
	row.add_child(buttons)

	_button(buttons, Loc.t("menu_new_campaign"), func(): new_game_requested.emit(), true)
	_button(buttons, Loc.t("menu_continue"), func(): continue_requested.emit())
	_button(buttons, Loc.t("menu_missions"), func(): show_missions())
	_button(buttons, Loc.t("menu_multiplayer"), func(): show_multiplayer())
	_button(buttons, Loc.t("menu_armory"), func(): show_armory())
	_button(buttons, Loc.t("menu_achievements"), func(): show_achievements())
	_button(buttons, Loc.t("menu_settings"), func(): show_settings())
	_button(buttons, Loc.t("menu_quit"), func(): quit_requested.emit())

	var stats := _text(buttons, "%s: %d   |   %s: %d   |   %s: %d" % [
		Loc.t("level"), int(SaveSystem.progress.get("level", 1)),
		Loc.t("coins"), int(SaveSystem.progress.get("coins", 0)),
		Loc.t("kills_total"), int(SaveSystem.progress.get("total_kills", 0))
	], 15, MUTED)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# --------------------------------------------------------------- الحملة
func _build_missions() -> void:
	var box := _panel("missions", Loc.t("menu_missions"))

	for index in _campaign.size():
		var mission: Dictionary = _campaign[index]
		var completed := SaveSystem.is_mission_completed(index)
		var unlocked := SaveSystem.is_mission_unlocked(index)
		var title := "%d. %s" % [int(mission.get("id", index + 1)),
				Loc.t(String(mission.get("name_key", "")))]
		if completed:
			title += "  ✓"
		elif not unlocked:
			title += "  🔒"

		var button := _button(box, title, func(): mission_selected.emit(index))
		button.disabled = not unlocked
		var info := _text(box, Loc.t(String(mission.get("brief_key", ""))), 13, MUTED)
		info.custom_minimum_size = Vector2(0, 30)

	_button(box, Loc.t("menu_back"), func(): show_main())


# --------------------------------------------------------- اللعب الجماعي
func _build_multiplayer() -> void:
	var box := _panel("multiplayer", Loc.t("mp_title"))
	_text(box, Loc.t("mp_offline_banner"), 14, Color(0.6, 0.85, 0.7))

	box.add_child(HSeparator.new())
	_text(box, Loc.t("mp_host"), 20, ACCENT)

	_text(box, Loc.t("mp_map"), 15, TEXT)
	var map_select := OptionButton.new()
	for map_name in MAPS:
		map_select.add_item(_map_label(map_name))
	map_select.selected = 0
	map_select.item_selected.connect(func(index: int):
		_mp_map = MAPS[index]
	)
	box.add_child(map_select)

	_text(box, Loc.t("mp_mode"), 15, TEXT)
	var mode_select := OptionButton.new()
	mode_select.add_item(Loc.t("mp_mode_ffa"))
	mode_select.add_item(Loc.t("mp_mode_tdm"))
	mode_select.add_item(Loc.t("mp_mode_domination"))
	mode_select.selected = 0
	mode_select.item_selected.connect(func(index: int): _mp_mode = index)
	box.add_child(mode_select)

	var max_row := HBoxContainer.new()
	box.add_child(max_row)
	_text(max_row, Loc.t("mp_max_players"), 15, TEXT)
	var max_select := OptionButton.new()
	for count in range(2, 6):
		max_select.add_item(str(count))
	max_select.selected = 3
	max_select.item_selected.connect(func(index: int): _mp_max = index + 2)
	max_row.add_child(max_select)

	var password_edit := LineEdit.new()
	password_edit.placeholder_text = Loc.t("mp_room_password")
	password_edit.text = ""
	password_edit.text_changed.connect(func(value: String): _mp_password = value)
	box.add_child(password_edit)

	_button(box, Loc.t("mp_host"), func():
		mp_host_requested.emit({
			"map": _mp_map, "mode": _mp_mode, "max_players": _mp_max,
			"password": _mp_password, "port": _mp_port
		})
	, true)

	box.add_child(HSeparator.new())
	_text(box, Loc.t("mp_join"), 20, ACCENT)

	var ip_edit := LineEdit.new()
	ip_edit.placeholder_text = Loc.t("mp_ip_address")
	ip_edit.text = _mp_ip
	ip_edit.text_changed.connect(func(value: String): _mp_ip = value)
	box.add_child(ip_edit)

	var join_password := LineEdit.new()
	join_password.placeholder_text = Loc.t("mp_room_password")
	join_password.text_changed.connect(func(value: String): _mp_password = value)
	box.add_child(join_password)

	_button(box, Loc.t("mp_connect"), func():
		mp_join_requested.emit({
			"ip": _mp_ip, "port": _mp_port, "password": _mp_password
		})
	)

	_text(box, Loc.t("net_local_only"), 13, MUTED)
	_button(box, Loc.t("menu_back"), func(): show_main())


func _map_label(map_name: String) -> String:
	match map_name:
		"village":
			return Loc.t("m2_name")
		"base":
			return Loc.t("m7_name")
		"factory":
			return Loc.t("m11_name")
		"mountain":
			return Loc.t("m10_name")
		"convoy":
			return Loc.t("m5_name")
		_:
			return Loc.t("m1_name")


func _build_lobby() -> void:
	var box := _panel("lobby", Loc.t("mp_waiting"))
	_text(box, Loc.t("mp_room_code") + ": " + str(_lobby_state.get("code", "----")), 18, ACCENT)
	_text(box, Loc.t("mp_players"), 16, TEXT)

	var list := VBoxContainer.new()
	list.name = "PlayerList"
	box.add_child(list)

	var ready_button := _button(box, Loc.t("mp_ready"), func(): mp_ready_toggled.emit(true))
	ready_button.name = "ReadyButton"

	var start_button := _button(box, Loc.t("mp_start"), func(): mp_start_requested.emit(), true)
	start_button.name = "StartButton"

	_button(box, Loc.t("mp_leave"), func(): mp_leave_requested.emit())


func _build_armory() -> void:
	var box := _panel("armory", Loc.t("armory_title"))
	var coins := _text(box, "%s: %d" % [Loc.t("coins"), int(SaveSystem.progress.get("coins", 0))],
			17, ACCENT)
	coins.name = "Coins"

	for weapon in WeaponsDB.guns():
		var weapon_id := String(weapon["id"])
		var unlocked := SaveSystem.is_weapon_unlocked(weapon_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_text(info, Loc.t(String(weapon["name_key"])), 18, TEXT)
		_text(info, Loc.t("armory_stats") % [int(weapon["damage"]), int(weapon["range"]),
				int(weapon["magazine"])], 13, MUTED)

		if unlocked:
			var equipped := SaveSystem.equipped() == weapon_id
			var button := _button(row, Loc.t("armory_equipped") if equipped else Loc.t("armory_equip"),
					func(): armory_equip_requested.emit(weapon_id))
			button.custom_minimum_size = Vector2(140, 44)
			button.disabled = equipped
		else:
			var button := _button(row, "%s (%d)" % [Loc.t("armory_unlock"), int(weapon["unlock_cost"])],
					func(): armory_unlock_requested.emit(weapon_id))
			button.custom_minimum_size = Vector2(160, 44)

	_button(box, Loc.t("menu_back"), func(): show_main())


func _build_achievements() -> void:
	var box := _panel("achievements", Loc.t("ach_title"))
	_text(box, Loc.t("ach_progress") % [SaveSystem.achievement_count(), ACHIEVEMENTS.size()],
			15, MUTED)

	for entry in ACHIEVEMENTS:
		var achievement_id := String(entry[0])
		var unlocked := SaveSystem.has_achievement(achievement_id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var mark := Label.new()
		mark.text = "✓" if unlocked else "•"
		mark.add_theme_font_size_override("font_size", 22)
		mark.add_theme_color_override("font_color", Color(0.5, 0.9, 0.55) if unlocked else MUTED)
		row.add_child(mark)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		_text(info, Loc.t(String(entry[1])), 17, TEXT if unlocked else MUTED)
		_text(info, Loc.t(String(entry[2])), 13, MUTED)

	_button(box, Loc.t("menu_back"), func(): show_main())


# --------------------------------------------------------------- الإعدادات
func _build_settings() -> void:
	var box := _panel("settings", Loc.t("menu_settings"))

	_text(box, Loc.t("settings_language"), 19, ACCENT)
	var language_select := OptionButton.new()
	for code in Loc.SUPPORTED:
		language_select.add_item("العربية" if code == "ar" else "English")
	language_select.selected = 0 if Loc.language == "ar" else 1
	language_select.item_selected.connect(func(index: int):
		GameSettings.set_language("ar" if index == 0 else "en")
	)
	box.add_child(language_select)

	box.add_child(HSeparator.new())
	_text(box, Loc.t("settings_graphics"), 19, ACCENT)

	var quality_select := OptionButton.new()
	quality_select.add_item(Loc.t("settings_quality_auto"))
	quality_select.add_item(Loc.t("settings_quality_ultra"))
	quality_select.add_item(Loc.t("settings_quality_high"))
	quality_select.add_item(Loc.t("settings_quality_performance"))
	var order := [GameSettings.QUALITY_AUTO, GameSettings.QUALITY_ULTRA,
			GameSettings.QUALITY_HIGH, GameSettings.QUALITY_PERFORMANCE]
	quality_select.selected = maxi(0, order.find(GameSettings.quality))
	quality_select.item_selected.connect(func(index: int):
		GameSettings.set_quality(String(order[index]))
	)
	box.add_child(quality_select)
	_text(box, Loc.t("settings_auto_detected") + " (" + GameSettings.resolved_quality + ")",
			13, MUTED)

	_slider(box, Loc.t("settings_fov"), 60.0, 100.0, 1.0, GameSettings.fov, func(value: float):
		GameSettings.fov = value
		GameSettings.save_settings()
		GameSettings.apply_video()
	)

	var shadows := CheckButton.new()
	shadows.text = Loc.t("settings_shadows")
	shadows.button_pressed = GameSettings.shadows_enabled
	shadows.toggled.connect(func(value: bool):
		GameSettings.shadows_enabled = value
		GameSettings.save_settings()
		GameSettings.apply_video()
	)
	box.add_child(shadows)

	box.add_child(HSeparator.new())
	_text(box, Loc.t("settings_audio"), 19, ACCENT)
	_slider(box, Loc.t("settings_master"), 0.0, 1.0, 0.05, GameSettings.master_volume, func(value: float):
		GameSettings.master_volume = value
		GameSettings.apply_audio()
		GameSettings.save_settings()
	)
	_slider(box, Loc.t("settings_music"), 0.0, 1.0, 0.05, GameSettings.music_volume, func(value: float):
		GameSettings.music_volume = value
		GameSettings.apply_audio()
		GameSettings.save_settings()
	)
	_slider(box, Loc.t("settings_sfx"), 0.0, 1.0, 0.05, GameSettings.sfx_volume, func(value: float):
		GameSettings.sfx_volume = value
		GameSettings.apply_audio()
		GameSettings.save_settings()
	)
	_slider(box, Loc.t("settings_vehicles"), 0.0, 1.0, 0.05, GameSettings.vehicle_volume, func(value: float):
		GameSettings.vehicle_volume = value
		GameSettings.apply_audio()
		GameSettings.save_settings()
	)

	box.add_child(HSeparator.new())
	_text(box, Loc.t("settings_controls"), 19, ACCENT)
	_slider(box, Loc.t("settings_sensitivity"), 0.06, 0.6, 0.01, GameSettings.look_sensitivity, func(value: float):
		GameSettings.look_sensitivity = value
		GameSettings.save_settings()
	)
	var invert := CheckButton.new()
	invert.text = Loc.t("settings_invert_y")
	invert.button_pressed = GameSettings.invert_y
	invert.toggled.connect(func(value: bool):
		GameSettings.invert_y = value
		GameSettings.save_settings()
	)
	box.add_child(invert)

	_slider(box, Loc.t("settings_edit_touch"), 0.7, 1.4, 0.05, GameSettings.touch_scale, func(value: float):
		GameSettings.touch_scale = value
		GameSettings.save_settings()
	)
	_button(box, Loc.t("settings_edit_touch"), func(): touch_editor_requested.emit())
	_button(box, Loc.t("settings_touch_reset"), func():
		GameSettings.reset_touch_layout()
	)
	_text(box, Loc.t("settings_touch_hint"), 13, MUTED)

	box.add_child(HSeparator.new())
	_button(box, Loc.t("settings_reset_progress"), func():
		SaveSystem.reset_progress()
		_rebuild()
	)
	_button(box, Loc.t("menu_back"), func(): _go_back())


func _build_pause() -> void:
	var box := _panel("pause", Loc.t("pause_title"))
	_button(box, Loc.t("menu_resume"), func(): resume_requested.emit(), true)
	_button(box, Loc.t("menu_retry"), func(): retry_requested.emit())
	_button(box, Loc.t("pause_options"), func():
		_back_target = "pause"
		show_settings()
	)
	_button(box, Loc.t("menu_main"), func(): back_to_menu_requested.emit())


func _build_result() -> void:
	var box := _panel("result", "")
	var title := Label.new()
	title.name = "ResultTitle"
	title.text = Loc.t("result_success")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	box.add_child(title)

	var body := Label.new()
	body.name = "ResultBody"
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", TEXT)
	box.add_child(body)

	box.add_child(HSeparator.new())
	_button(box, Loc.t("menu_next"), func(): next_mission_requested.emit(), true)
	_button(box, Loc.t("menu_replay"), func(): retry_requested.emit())
	_button(box, Loc.t("menu_main"), func(): back_to_menu_requested.emit())


# --------------------------------------------------------------- التنقل
func hide_all() -> void:
	for panel in _panels.values():
		if is_instance_valid(panel):
			panel.visible = false
	_current = ""


func _show(key: String) -> void:
	hide_all()
	if _panels.has(key):
		_panels[key].visible = true
		_current = key
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_main() -> void:
	_rebuild_stats()
	_show("main")


func _rebuild_stats() -> void:
	pass


func show_missions() -> void:
	_show("missions")


func show_multiplayer() -> void:
	_show("multiplayer")


func show_lobby(state: Dictionary = {}) -> void:
	_lobby_state = state
	_back_target = "lobby"
	_show("lobby")
	_update_lobby()


func _update_lobby() -> void:
	if not _panels.has("lobby"):
		return
	var panel: Control = _panels["lobby"]
	var list = panel.find_child("PlayerList", true, false)
	if list == null:
		return
	for child in list.get_children():
		child.queue_free()
	for player_entry in _lobby_state.get("players", []):
		var row := HBoxContainer.new()
		list.add_child(row)
		var name_label := _text(row, String(player_entry.get("name", "?")), 16, TEXT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var ready := bool(player_entry.get("ready", false))
		_text(row, Loc.t("mp_ready") if ready else Loc.t("mp_not_ready"), 14,
				Color(0.5, 0.95, 0.6) if ready else MUTED)


func show_armory() -> void:
	_show("armory")


func show_achievements() -> void:
	_show("achievements")


func show_settings() -> void:
	if _current != "pause":
		_back_target = _current if _current != "" else "main"
	_show("settings")


func show_pause() -> void:
	_show("pause")


func show_result(success: bool, mission_name: String, stats: Dictionary) -> void:
	_result_stats = stats
	_show("result")
	var panel: Control = _panels["result"]
	var title = panel.find_child("ResultTitle", true, false)
	if title != null:
		(title as Label).text = Loc.t("result_success") if success else Loc.t("result_failed")
		(title as Label).add_theme_color_override("font_color",
				Color(0.55, 0.95, 0.6) if success else Color(1.0, 0.45, 0.4))

	var body = panel.find_child("ResultBody", true, false)
	if body != null:
		var lines := [mission_name]
		lines.append("%s: %d" % [Loc.t("result_kills"), int(stats.get("kills", 0))])
		lines.append("%s: %d" % [Loc.t("result_headshots"), int(stats.get("headshots", 0))])
		lines.append("%s: +%d" % [Loc.t("result_xp_gained"), int(stats.get("xp", 0))])
		lines.append("%s: +%d" % [Loc.t("result_coins_gained"), int(stats.get("coins", 0))])
		if String(stats.get("unlock", "")) != "":
			lines.append(Loc.t("result_unlock") % Loc.t(String(stats["unlock"])))
		lines.append("%s: %d" % [Loc.t("level"), int(stats.get("level", 1))])
		(body as Label).text = "\n".join(lines)


func _go_back() -> void:
	match _back_target:
		"pause":
			show_pause()
		"lobby":
			show_lobby(_lobby_state)
		"missions":
			show_missions()
		_:
			show_main()


func current_panel() -> String:
	return _current


func is_open() -> bool:
	return _current != ""
