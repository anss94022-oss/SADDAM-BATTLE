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

const MAPS := ["city", "village", "base", "factory", "mountain", "convoy", "training"]

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
var _main_stats: Label


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
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.016, 0.026, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func(): _draw_menu_bg(bg))
	panel.add_child(bg)

	var margin := MarginContainer.new()
	margin.layout_direction = Control.LAYOUT_DIRECTION_LTR
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.layout_direction = Control.LAYOUT_DIRECTION_LTR
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)

	var box := VBoxContainer.new()
	box.layout_direction = Control.LAYOUT_DIRECTION_LTR
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)

	if title != "":
		var heading := _hero_label(title, 40, Color(1.0, 0.74, 0.30), 4)
		heading.add_theme_color_override("font_outline_color", Color(0.38, 0.18, 0.02, 0.9))
		heading.custom_minimum_size = Vector2(0, 58)
		box.add_child(heading)

		var rule := ColorRect.new()
		rule.color = Color(0.95, 0.62, 0.22, 0.75)
		rule.custom_minimum_size = Vector2(0, 3)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(rule)

	_panels[key] = panel
	return box


func _button(parent: Node, text: String, on_press: Callable, primary: bool = false,
		compact: bool = false) -> Control:
	var holder := Control.new()
	if compact:
		holder.custom_minimum_size = Vector2(300, 58)
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	else:
		holder.custom_minimum_size = Vector2(0, 74 if primary else 62)
		holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)

	var button := Control.new()
	button.set_script(load("res://scripts/ui/hero_button.gd"))
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(button)
	button.call("setup", text, primary, 26 if primary else (20 if compact else 21))
	button.connect("pressed", func():
		AudioManager.play_ui("ui_click", -6.0)
		on_press.call()
	)
	return button


func _text(parent: Node, value: String, size: int = 19, color: Color = MUTED) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label


func _slider(parent: Node, label_text: String, min_value: float, max_value: float,
		step: float, value: float, on_change: Callable) -> void:
	_text(parent, label_text, 17, TEXT)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(460, 36)
	slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	slider.value_changed.connect(on_change)
	parent.add_child(slider)


# --------------------------------------------------------------- الرئيسية
func _build_main() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.012, 0.016, 0.026, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	# تخطيط مطلق: نثبّت الاتجاه LTR حتى لا تنعكس الإحداثيات مع واجهة عربية
	panel.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(panel)
	_panels["main"] = panel

	var stage := Control.new()
	stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	stage.layout_direction = Control.LAYOUT_DIRECTION_LTR
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(stage)

	# ---- خلفية تصميمية: تدرّج ليلي + شبكة خفيفة + توهج ----
	var bg := Control.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.draw.connect(func(): _draw_menu_bg(bg))
	stage.add_child(bg)

	# ---- العنوان ----
	var title_wrap := VBoxContainer.new()
	title_wrap.layout_direction = Control.LAYOUT_DIRECTION_LTR
	title_wrap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_wrap.offset_left = 56.0
	title_wrap.offset_top = 16.0
	title_wrap.offset_right = 720.0
	title_wrap.offset_bottom = 166.0
	title_wrap.add_theme_constant_override("separation", 0)
	title_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(title_wrap)

	var latin := _hero_label("SADDAM HERO", 16, Color(0.62, 0.72, 0.86, 0.9), 5)
	latin.custom_minimum_size = Vector2(0, 22)
	title_wrap.add_child(latin)

	var title := _hero_label(Loc.t("app_title"), 46, Color(1.0, 0.72, 0.26), 4)
	title.add_theme_color_override("font_outline_color", Color(0.42, 0.20, 0.02, 0.85))
	title.custom_minimum_size = Vector2(0, 64)
	title_wrap.add_child(title)

	var subtitle := _hero_label(Loc.t("app_subtitle"), 14, Color(0.70, 0.80, 0.92), 2)
	subtitle.custom_minimum_size = Vector2(0, 20)
	title_wrap.add_child(subtitle)

	# ---- عمود الأزرار ----
	var column := VBoxContainer.new()
	column.layout_direction = Control.LAYOUT_DIRECTION_LTR
	column.set_anchors_preset(Control.PRESET_TOP_LEFT)
	column.offset_left = 56.0
	column.offset_top = 172.0
	column.offset_right = 600.0
	column.offset_bottom = 640.0
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(column)

	_hero_button(column, Loc.t("menu_new_campaign"), func(): new_game_requested.emit(), true)
	_hero_button(column, Loc.t("menu_continue"), func(): continue_requested.emit())
	_hero_button(column, Loc.t("menu_missions"), func(): show_missions())
	_hero_button(column, Loc.t("menu_multiplayer"), func(): show_multiplayer())
	_hero_button(column, Loc.t("menu_armory"), func(): show_armory())
	_hero_button(column, Loc.t("menu_achievements"), func(): show_achievements())
	_hero_button(column, Loc.t("menu_settings"), func(): show_settings())
	_hero_button(column, Loc.t("menu_quit"), func(): quit_requested.emit())

	# ---- بطاقة الشخصية يمين الشاشة ----
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.anchor_left = 1.0
	card.anchor_right = 1.0
	card.anchor_top = 0.0
	card.anchor_bottom = 0.0
	card.offset_left = -470.0
	card.offset_right = -56.0
	card.offset_top = 88.0
	card.offset_bottom = 668.0
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.04, 0.06, 0.09, 0.92)
	card_style.border_color = Color(0.92, 0.62, 0.22, 0.55)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)
	stage.add_child(card)

	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(406, 572)
	portrait_holder.clip_contents = true
	portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(portrait_holder)

	var portrait := TextureRect.new()
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists("res://assets/characters/hero_key.png"):
		portrait.texture = load("res://assets/characters/hero_key.png")
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_holder.add_child(portrait)

	var name_tag := _hero_label(Loc.t("app_title"), 26, Color(1.0, 0.92, 0.78), 3)
	name_tag.layout_direction = Control.LAYOUT_DIRECTION_LTR
	name_tag.anchor_top = 1.0
	name_tag.anchor_bottom = 1.0
	name_tag.offset_left = 18.0
	name_tag.offset_top = -52.0
	name_tag.offset_right = 338.0
	name_tag.offset_bottom = -18.0
	portrait_holder.add_child(name_tag)

	# ---- شريط الإحصاءات والتذييل ----
	_main_stats = _hero_label("", 14, Color(0.66, 0.76, 0.90), 2)
	_main_stats.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_main_stats.anchor_top = 1.0
	_main_stats.anchor_bottom = 1.0
	_main_stats.offset_left = 58.0
	_main_stats.offset_top = -44.0
	_main_stats.offset_right = 560.0
	_main_stats.offset_bottom = -20.0
	stage.add_child(_main_stats)
	_rebuild_stats()

	var footer := _hero_label("تطوير GENSPARK  -  (C) 2026", 15, Color(0.48, 0.56, 0.68), 2)
	footer.layout_direction = Control.LAYOUT_DIRECTION_LTR
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.anchor_left = 1.0
	footer.anchor_right = 1.0
	footer.offset_left = -430.0
	footer.offset_top = -44.0
	footer.offset_right = -56.0
	footer.offset_bottom = -20.0
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage.add_child(footer)


func _hero_label(text: String, font_size: int, color: Color, outline: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", load("res://assets/fonts/NotoSansArabic-Bold.ttf"))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _hero_button(parent: Node, text: String, on_press: Callable, primary: bool = false) -> void:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 64 if primary else 54)
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)

	var button_script := load("res://scripts/ui/hero_button.gd")
	var button := Control.new()
	button.set_script(button_script)
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(button)
	button.call("setup", text, primary, 28 if primary else 23)
	button.connect("pressed", func():
		AudioManager.play_ui("ui_click", -6.0)
		on_press.call()
	)


func _draw_menu_bg(control: Control) -> void:
	var w := control.size.x
	var h := control.size.y
	if w <= 0.0 or h <= 0.0:
		return
	var steps := 48
	for index in steps:
		var t := float(index) / float(steps - 1)
		var color := Color(0.05, 0.09, 0.15).lerp(Color(0.01, 0.015, 0.025), t)
		control.draw_rect(Rect2(0, h * float(index) / float(steps), w, h / float(steps) + 1.0), color)
	# شبكة خفيفة توحي بشاشات القيادة
	var grid := Color(0.35, 0.55, 0.85, 0.06)
	for index in range(1, 18):
		var x := w * float(index) / 18.0
		control.draw_line(Vector2(x, 0), Vector2(x, h), grid, 1.0)
	for index in range(1, 10):
		var y := h * float(index) / 10.0
		control.draw_line(Vector2(0, y), Vector2(w, y), grid, 1.0)
	# توهج برتقالي خافت خلف عمود الأزرار
	for index in 6:
		var expand := float(index) * 26.0
		control.draw_rect(Rect2(20.0 - expand * 0.5, 150.0 - expand * 0.5,
				560.0 + expand, 640.0 + expand), Color(0.95, 0.55, 0.15, 0.012))
	# ظل سفلي
	control.draw_rect(Rect2(0, h - 90.0, w, 90.0), Color(0.0, 0.0, 0.0, 0.35))


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
		var card := PanelContainer.new()
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = Color(0.05, 0.08, 0.12, 0.75)
		card_style.border_color = Color(0.85, 0.55, 0.20, 0.45)
		card_style.border_width_left = 3
		card_style.set_corner_radius_all(4)
		card_style.content_margin_left = 16
		card_style.content_margin_right = 16
		card_style.content_margin_top = 10
		card_style.content_margin_bottom = 10
		card.add_theme_stylebox_override("panel", card_style)
		box.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(info)
		_text(info, Loc.t(String(weapon["name_key"])), 18, TEXT)
		_text(info, Loc.t("armory_stats") % [int(weapon["damage"]), int(weapon["range"]),
				int(weapon["magazine"])], 13, MUTED)

		if unlocked:
			var equipped := SaveSystem.equipped() == weapon_id
			var button := _button(row, Loc.t("armory_equipped") if equipped else Loc.t("armory_equip"),
					func(): armory_equip_requested.emit(weapon_id), false, true)
			button.disabled = equipped
		else:
			var button := _button(row, "%s (%d)" % [Loc.t("armory_unlock"), int(weapon["unlock_cost"])],
					func(): armory_unlock_requested.emit(weapon_id), false, true)

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
	language_select.custom_minimum_size = Vector2(460, 46)
	language_select.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	quality_select.custom_minimum_size = Vector2(460, 46)
	quality_select.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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
	if _main_stats == null or not is_instance_valid(_main_stats):
		return
	_main_stats.text = "%s %d    %s %d    %s %d" % [
		Loc.t("level"), int(SaveSystem.progress.get("level", 1)),
		Loc.t("coins"), int(SaveSystem.progress.get("coins", 0)),
		Loc.t("kills_total"), int(SaveSystem.progress.get("total_kills", 0))
	]


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
