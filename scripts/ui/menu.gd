extends CanvasLayer
## كل قوائم اللعبة: الرئيسية، اختيار المهمة، الإعدادات، الإيقاف، ونتيجة المهمة.

signal new_game_requested
signal continue_requested
signal mission_selected(index: int)
signal resume_requested
signal retry_requested
signal next_mission_requested
signal back_to_menu_requested
signal hero_selected(index: int)

const ACCENT := Color(0.95, 0.62, 0.25)
const TEXT := Color(0.93, 0.96, 1.0)
const MUTED := Color(0.62, 0.72, 0.85)
const BG := Color(0.03, 0.05, 0.08, 0.96)

var campaign_size := 12
var selected_hero := 0

var _main_panel: Control
var _missions_panel: Control
var _settings_panel: Control
var _pause_panel: Control
var _result_panel: Control
var _mission_list: VBoxContainer
var _result_title: Label
var _result_body: Label
var _hero_buttons: Array = []
var _hero_names := ["صدام", "يوسري", "سارة", "عبدالله", "مريم", "لمار", "آدم"]


func _ready() -> void:
	layer = 20
	_build_main()
	_build_missions()
	_build_settings()
	_build_pause()
	_build_result()
	hide_all()


func hide_all() -> void:
	for panel in [_main_panel, _missions_panel, _settings_panel, _pause_panel, _result_panel]:
		if panel != null:
			panel.visible = false

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_main() -> void:
	hide_all()
	_main_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_mission_select() -> void:
	hide_all()
	_refresh_missions()
	_missions_panel.visible = true


func show_settings() -> void:
	hide_all()
	_settings_panel.visible = true


func show_pause() -> void:
	hide_all()
	_pause_panel.visible = true


func show_result(success: bool, mission_name: String, xp: int, kills: int) -> void:
	hide_all()
	_result_panel.visible = true

	_result_title.text = "تمت المهمة" if success else "فشلت المهمة"
	_result_title.add_theme_color_override(
		"font_color", Color(0.55, 0.95, 0.6) if success else Color(1.0, 0.45, 0.4)
	)

	_result_body.text = "%s\nالقتلى: %d\nالخبرة: +%d\nالمستوى: %d" % [
		mission_name, kills, xp, int(SaveSystem.progress.get("level", 1))
	]
	_result_panel.set_meta("success", success)


func hide_result() -> void:
	_result_panel.visible = false


func _panel(title: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0

	var style := StyleBoxFlat.new()
	style.bg_color = BG
	panel.add_theme_stylebox_override("panel", style)

	add_child(panel)
	_last_panel = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)

	if title != "":
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", 34)
		heading.add_theme_color_override("font_color", ACCENT)
		box.add_child(heading)

	return box


func _button(parent: Node, text: String, on_press: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", TEXT if not primary else Color(0.08, 0.06, 0.03))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.16, 0.24, 0.95) if not primary else ACCENT
	style.set_corner_radius_all(8)
	style.border_color = Color(0.25, 0.4, 0.55, 0.8)
	style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)

	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.16, 0.26, 0.36, 0.98) if not primary else Color(1.0, 0.72, 0.35)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)

	button.pressed.connect(on_press)
	parent.add_child(button)
	return button


func _build_main() -> void:
	var box := _panel("")

	var title := Label.new()
	title.text = "SADDAM BATTLE"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "لعبة أكشن عسكرية — قنص، مهام، وتقدّم"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", MUTED)
	box.add_child(subtitle)

	box.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)

	# صورة البطل.
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(240, 0)
	row.add_child(portrait_panel)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(240, 400)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture = load("res://assets/characters/hero_key.png")
	portrait_panel.add_child(portrait)

	var buttons := VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 12)
	row.add_child(buttons)

	_button(buttons, "بدء الحملة", func(): new_game_requested.emit(), true)
	_button(buttons, "متابعة المهمة", func(): continue_requested.emit())
	_button(buttons, "اختيار المهمة", func(): show_mission_select())
	_button(buttons, "الإعدادات", func(): show_settings())
	_button(buttons, "خروج", func(): get_tree().quit())

	var stats := Label.new()
	stats.text = "المستوى: %d   |   العملات: %d   |   القتلى: %d" % [
		int(SaveSystem.progress.get("level", 1)),
		int(SaveSystem.progress.get("coins", 0)),
		int(SaveSystem.progress.get("total_kills", 0))
	]
	stats.add_theme_font_size_override("font_size", 15)
	stats.add_theme_color_override("font_color", MUTED)
	buttons.add_child(stats)

	_main_panel = _last_panel


var _last_panel: Control


func _build_missions() -> void:
	var box := _panel("اختيار المهمة")

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 460)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)

	_mission_list = VBoxContainer.new()
	_mission_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_mission_list)

	_button(box, "رجوع", func(): show_main())

	_missions_panel = _last_panel


func _refresh_missions() -> void:
	for child in _mission_list.get_children():
		child.queue_free()

	var campaign: Array = []
	if FileAccess.file_exists("res://data/missions/missions.json"):
		var file := FileAccess.open("res://data/missions/missions.json", FileAccess.READ)
		var parsed = JSON.parse_string(file.get_as_text())
		file.close()
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("campaign"):
			campaign = parsed["campaign"]

	campaign_size = campaign.size()

	for index in campaign.size():
		var mission: Dictionary = campaign[index]
		var completed := SaveSystem.is_mission_completed(index)
		var locked := index > 0 and not SaveSystem.is_mission_completed(index - 1)

		var label := "المهمة %d — %s%s" % [
			int(mission.get("id", index + 1)),
			String(mission.get("name", "")),
			"   ✓" if completed else ("   🔒" if locked else "")
		]

		var target_index := index
		var button := _button(_mission_list, label, func(): mission_selected.emit(target_index))
		button.disabled = locked


func _build_settings() -> void:
	var box := _panel("الإعدادات")

	var sensitivity_label := Label.new()
	sensitivity_label.text = "حساسية النظر"
	sensitivity_label.add_theme_color_override("font_color", TEXT)
	box.add_child(sensitivity_label)

	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.05
	sensitivity.max_value = 0.8
	sensitivity.step = 0.01
	sensitivity.value = GameSettings.look_sensitivity
	sensitivity.custom_minimum_size = Vector2(420, 32)
	sensitivity.value_changed.connect(func(value: float):
		GameSettings.look_sensitivity = value
		GameSettings.save_settings()
	)
	box.add_child(sensitivity)

	var invert := CheckButton.new()
	invert.text = "عكس اتجاه النظر عمودياً"
	invert.button_pressed = GameSettings.invert_y
	invert.toggled.connect(func(pressed: bool):
		GameSettings.invert_y = pressed
		GameSettings.save_settings()
	)
	box.add_child(invert)

	var quality_label := Label.new()
	quality_label.text = "جودة الرسوم"
	quality_label.add_theme_color_override("font_color", TEXT)
	box.add_child(quality_label)

	var quality := OptionButton.new()
	quality.add_item("فائقة", 0)
	quality.add_item("عالية", 1)
	quality.add_item("أداء", 2)
	quality.selected = 0 if GameSettings.quality == GameSettings.QUALITY_ULTRA else (
		1 if GameSettings.quality == GameSettings.QUALITY_HIGH else 2
	)
	quality.item_selected.connect(func(index: int):
		var value := GameSettings.QUALITY_ULTRA
		if index == 1:
			value = GameSettings.QUALITY_HIGH
		elif index == 2:
			value = GameSettings.QUALITY_PERFORMANCE
		GameSettings.set_quality(value)
	)
	box.add_child(quality)

	var volume_label := Label.new()
	volume_label.text = "مستوى الصوت"
	volume_label.add_theme_color_override("font_color", TEXT)
	box.add_child(volume_label)

	var volume := HSlider.new()
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = GameSettings.master_volume
	volume.custom_minimum_size = Vector2(420, 32)
	volume.value_changed.connect(func(value: float):
		GameSettings.master_volume = value
		GameSettings.save_settings()
		GameSettings.apply_to_viewport()
	)
	box.add_child(volume)

	box.add_child(HSeparator.new())

	_button(box, "إعادة ضبط التقدّم", func():
		SaveSystem.reset_progress()
		show_main()
	)
	_button(box, "رجوع", func(): show_main())

	_settings_panel = _last_panel


func _build_pause() -> void:
	var box := _panel("إيقاف مؤقت")

	_button(box, "متابعة", func(): resume_requested.emit(), true)
	_button(box, "إعادة المحاولة", func(): retry_requested.emit())
	_button(box, "الإعدادات", func(): show_settings())
	_button(box, "القائمة الرئيسية", func(): back_to_menu_requested.emit())

	_pause_panel = _last_panel


func _build_result() -> void:
	var box := _panel("")

	_result_title = Label.new()
	_result_title.text = "تمت المهمة"
	_result_title.add_theme_font_size_override("font_size", 40)
	_result_title.add_theme_color_override("font_color", Color(0.55, 0.95, 0.6))
	box.add_child(_result_title)

	_result_body = Label.new()
	_result_body.add_theme_font_size_override("font_size", 20)
	_result_body.add_theme_color_override("font_color", TEXT)
	box.add_child(_result_body)

	box.add_child(HSeparator.new())

	_button(box, "المهمة التالية", func(): next_mission_requested.emit(), true)
	_button(box, "إعادة", func(): retry_requested.emit())
	_button(box, "القائمة الرئيسية", func(): back_to_menu_requested.emit())

	_result_panel = _last_panel
