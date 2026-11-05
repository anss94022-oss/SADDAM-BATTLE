extends CanvasLayer
## واجهة اللعب: صحة ودرع وذخيرة وهدف ومؤقت، مؤشرات إصابة، رسائل،
## ولوحة تحكم لمسية قابلة للتخصيص (سحب الأزرار، حجم وشفافية من الإعدادات).

signal pause_pressed
signal weapon_pressed
signal reload_pressed
signal jump_pressed
signal crouch_pressed
signal grenade_pressed
signal heal_pressed
signal interact_pressed
signal scope_pressed
signal vehicle_camera_pressed

const TOUCH_BUTTONS := [
	"fire", "aim", "reload", "weapon", "jump", "crouch",
	"grenade", "heal", "interact", "sprint", "scope", "camera",
	"autofire", "view"
]

const DEFAULT_LAYOUT := {
	"fire": {"x": 0.885, "y": 0.80},
	"aim": {"x": 0.775, "y": 0.705},
	"jump": {"x": 0.745, "y": 0.905},
	"crouch": {"x": 0.625, "y": 0.925},
	"reload": {"x": 0.915, "y": 0.625},
	"weapon": {"x": 0.795, "y": 0.545},
	"scope": {"x": 0.635, "y": 0.745},
	"grenade": {"x": 0.605, "y": 0.575},
	"heal": {"x": 0.515, "y": 0.865},
	"interact": {"x": 0.515, "y": 0.695},
	"sprint": {"x": 0.30, "y": 0.85},
	"camera": {"x": 0.965, "y": 0.385},
	"autofire": {"x": 0.90, "y": 0.255},
	"view": {"x": 0.90, "y": 0.135}
}

const BUTTON_LABELS := {
	"fire": "touch_fire", "aim": "touch_aim", "reload": "touch_reload",
	"weapon": "touch_weapon", "jump": "touch_jump", "crouch": "touch_crouch",
	"grenade": "touch_grenade", "heal": "touch_heal", "interact": "touch_interact",
	"sprint": "touch_sprint", "scope": "touch_scope", "camera": "touch_switch_view",
	"autofire": "touch_autofire", "view": "touch_view"
}

const TOUCH_BASE_SIZE := 104.0
const JOYSTICK_RADIUS := 96.0

var player: Node3D = null
var mission_manager: Node = null

var _root: Control
var _touch_layer: Control
var _look_area: Control

var _health_bar: ProgressBar
var _armor_bar: ProgressBar
var _health_label: Label
var _armor_label: Label
var _ammo_label: Label
var _weapon_label: Label
var _objective_label: Label
var _progress_bar: ProgressBar
var _timer_label: Label
var _kills_label: Label
var _message_label: Label
var _crosshair: Control
var _hit_marker: Control
var _damage_overlay: ColorRect
var _damage_indicators: Array = []
var _interact_label: Label
var _scope_overlay: ColorRect
var _vehicle_panel: VBoxContainer
var _vehicle_health: ProgressBar
var _vehicle_speed: Label
var _grenade_label: Label
var _medkit_label: Label
var _stamina_bar: ProgressBar
var _reload_bar: ProgressBar
var _killfeed: VBoxContainer

var _joystick_base: Control
var _joystick_knob: Control
var _joystick_touch := -1
var _look_touch := -1
var _look_last := Vector2.ZERO
var _look_moved := 0.0
var _buttons: Dictionary = {}
var _layout: Dictionary = {}
var _edit_mode := false
var _dragging := ""
var _drag_offset := Vector2.ZERO

var _hit_timer := 0.0
var _message_timer := 0.0
var _suppress := false
var _mission_bound := false
var _minimap: Control


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_apply_layout()
	set_process(true)
	set_process_input(true)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- شريط الصحة والدرع ----
	var stats := VBoxContainer.new()
	stats.position = Vector2(22, 18)
	stats.size = Vector2(300, 90)
	stats.add_theme_constant_override("separation", 4)
	_root.add_child(stats)

	_health_label = _label(Loc.t("hud_health") + " 100", 18, Color(0.92, 0.96, 1.0))
	stats.add_child(_health_label)
	_health_bar = _bar(Color(0.85, 0.24, 0.22), 300.0)
	stats.add_child(_health_bar)

	_armor_label = _label(Loc.t("hud_armor") + " 100", 15, Color(0.65, 0.82, 1.0))
	stats.add_child(_armor_label)
	_armor_bar = _bar(Color(0.30, 0.60, 0.95), 300.0)
	_armor_bar.custom_minimum_size = Vector2(300, 10)
	stats.add_child(_armor_bar)

	_stamina_bar = _bar(Color(0.55, 0.85, 0.45), 300.0)
	_stamina_bar.custom_minimum_size = Vector2(300, 6)
	stats.add_child(_stamina_bar)

	# ---- الهدف ----
	_objective_label = _label("", 20, Color(0.97, 0.89, 0.62))
	_objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_label.position = Vector2(-260, 14)
	_objective_label.size = Vector2(520, 30)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_objective_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progress_bar.show_percentage = false
	_progress_bar.max_value = 1.0
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.02, 0.03, 0.05, 0.55)
	bar_bg.set_corner_radius_all(3)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.95, 0.68, 0.28, 0.9)
	bar_fill.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", bar_bg)
	_progress_bar.add_theme_stylebox_override("fill", bar_fill)
	_root.add_child(_progress_bar)
	_progress_bar.offset_left = -140
	_progress_bar.offset_top = 46
	_progress_bar.offset_right = 140
	_progress_bar.offset_bottom = 52

	_timer_label = _label("", 16, Color(0.85, 0.92, 1.0))
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.position = Vector2(-90, 56)
	_timer_label.size = Vector2(180, 24)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_timer_label)

	# ---- القتلى ----
	_kills_label = _label("", 16, Color(0.90, 0.95, 1.0))
	_kills_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_kills_label.position = Vector2(-250, 20)
	_kills_label.size = Vector2(220, 24)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_kills_label)

	# ---- لوحة القتل ----
	_killfeed = VBoxContainer.new()
	_killfeed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_killfeed.position = Vector2(-320, 52)
	_killfeed.size = Vector2(290, 140)
	_killfeed.add_theme_constant_override("separation", 2)
	_root.add_child(_killfeed)

	# ---- الذخيرة ----
	_ammo_label = _label("", 34, Color(1.0, 0.94, 0.76))
	_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.position = Vector2(-220, -146)
	_ammo_label.size = Vector2(190, 42)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_ammo_label)

	_weapon_label = _label("", 15, Color(0.82, 0.88, 0.97))
	_weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.position = Vector2(-220, -104)
	_weapon_label.size = Vector2(190, 22)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_weapon_label)

	_grenade_label = _label("", 15, Color(0.85, 0.92, 0.85))
	_grenade_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_grenade_label.position = Vector2(-220, -82)
	_grenade_label.size = Vector2(190, 22)
	_grenade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_grenade_label)

	_medkit_label = _label("", 15, Color(0.95, 0.85, 0.85))
	_medkit_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_medkit_label.position = Vector2(-220, -60)
	_medkit_label.size = Vector2(190, 22)
	_medkit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_medkit_label)

	_reload_bar = ProgressBar.new()
	_reload_bar.set_anchors_preset(Control.PRESET_CENTER)
	_reload_bar.position = Vector2(-80, 62)
	_reload_bar.size = Vector2(160, 8)
	_reload_bar.show_percentage = false
	_reload_bar.max_value = 1.0
	_reload_bar.visible = false
	_root.add_child(_reload_bar)

	# ---- التصويب ----
	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.size = Vector2(32, 32)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-16, -16)
	_crosshair.draw.connect(_draw_crosshair)
	_root.add_child(_crosshair)

	_hit_marker = Control.new()
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_marker.size = Vector2(44, 44)
	_hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	_hit_marker.position = Vector2(-22, -22)
	_hit_marker.modulate.a = 0.0
	_hit_marker.draw.connect(_draw_hit_marker)
	_root.add_child(_hit_marker)

	_damage_overlay = ColorRect.new()
	_damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.color = Color(0.8, 0.05, 0.05, 0.0)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_damage_overlay)

	_scope_overlay = ColorRect.new()
	_scope_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_overlay.visible = false
	_scope_overlay.draw.connect(_draw_scope)
	_root.add_child(_scope_overlay)

	_minimap = Control.new()
	_minimap.position = Vector2(-186, 18)
	_minimap.size = Vector2(160, 160)
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.draw.connect(_draw_minimap)
	_root.add_child(_minimap)

	_interact_label = _label("", 20, Color(1.0, 0.95, 0.7))
	_interact_label.set_anchors_preset(Control.PRESET_CENTER)
	_interact_label.position = Vector2(-200, 90)
	_interact_label.size = Vector2(400, 30)
	_interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_interact_label.visible = false
	_root.add_child(_interact_label)

	# ---- رسالة مركزية ----
	_message_label = _label("", 40, Color(1.0, 0.9, 0.55))
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.position = Vector2(-320, -140)
	_message_label.size = Vector2(640, 90)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.modulate.a = 0.0
	_root.add_child(_message_label)

	# ---- زر الإيقاف ----
	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause_button.position = Vector2(22, 118)
	pause_button.size = Vector2(46, 40)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(func(): pause_pressed.emit())
	_root.add_child(pause_button)

	# ---- لوحة المركبة ----
	_vehicle_panel = VBoxContainer.new()
	_vehicle_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_vehicle_panel.position = Vector2(24, -150)
	_vehicle_panel.size = Vector2(260, 90)
	_vehicle_panel.visible = false
	_root.add_child(_vehicle_panel)
	var vehicle_label := _label(Loc.t("hud_vehicle_health"), 16, Color(0.9, 0.95, 1.0))
	_vehicle_panel.add_child(vehicle_label)
	_vehicle_health = _bar(Color(0.95, 0.70, 0.25), 240.0)
	_vehicle_panel.add_child(_vehicle_health)
	_vehicle_speed = _label("0 km/h", 18, Color(1.0, 0.92, 0.7))
	_vehicle_panel.add_child(_vehicle_speed)

	_build_touch_controls()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _bar(color: Color, width: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = 100
	bar.custom_minimum_size = Vector2(width, 14)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.06, 0.08, 0.75)
	background.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)
	return bar


# ---------------------------------------------------------- أزرار اللمس
func _touch_available() -> bool:
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") \
		or OS.has_feature("android")


func _build_touch_controls() -> void:
	_touch_layer = Control.new()
	_touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_layer.visible = _touch_available()
	_root.add_child(_touch_layer)

	_look_area = Control.new()
	_look_area.set_anchors_preset(Control.PRESET_FULL_RECT)
	_look_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_touch_layer.add_child(_look_area)

	_joystick_base = Control.new()
	_joystick_base.custom_minimum_size = Vector2(TOUCH_BASE_SIZE * 1.5, TOUCH_BASE_SIZE * 1.5)
	_joystick_base.size = Vector2(TOUCH_BASE_SIZE * 1.5, TOUCH_BASE_SIZE * 1.5)
	_joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick_base.position = Vector2(30, -TOUCH_BASE_SIZE * 1.5 - 30)
	_joystick_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joystick_base.draw.connect(_draw_joystick_base)
	_joystick_base.gui_input.connect(_on_joystick_input)
	_touch_layer.add_child(_joystick_base)

	_joystick_knob = Control.new()
	_joystick_knob.size = Vector2(54, 54)
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_knob.draw.connect(_draw_joystick_knob)
	_joystick_base.add_child(_joystick_knob)

	for name in TOUCH_BUTTONS:
		var button := Button.new()
		button.text = Loc.t(String(BUTTON_LABELS.get(name, name)))
		button.focus_mode = Control.FOCUS_NONE
		button.size = Vector2(TOUCH_BASE_SIZE, TOUCH_BASE_SIZE)
		button.set_meta("touch_name", name)
		_style_button(button, name in ["fire", "aim"])
		_connect_button(button, name)
		_touch_layer.add_child(button)
		_buttons[name] = button


func _style_button(button: Button, primary: bool) -> void:
	var alpha := 0.32 + GameSettings.sfx_volume * 0.0
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.18, 0.28, 0.62 if primary else 0.52)
	normal.border_color = Color(0.80, 0.93, 1.0, 0.95)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(62)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.28, 0.68, 1.0, 0.85)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_font_size_override("font_size", 21)


func _connect_button(button: Button, name: String) -> void:
	match name:
		"fire":
			button.button_down.connect(func():
				if player != null:
					player.set_firing(true)
			)
			button.button_up.connect(func():
				if player != null:
					player.set_firing(false)
			)
		"aim":
			button.button_down.connect(func():
				if player != null:
					player.set_aiming(true)
			)
			button.button_up.connect(func():
				if player != null:
					player.set_aiming(false)
			)
		"reload":
			button.pressed.connect(func(): reload_pressed.emit())
		"weapon":
			button.pressed.connect(func(): weapon_pressed.emit())
		"jump":
			button.pressed.connect(func(): jump_pressed.emit())
		"crouch":
			button.pressed.connect(func(): crouch_pressed.emit())
		"grenade":
			button.pressed.connect(func(): grenade_pressed.emit())
		"heal":
			button.pressed.connect(func(): heal_pressed.emit())
		"interact":
			button.pressed.connect(func(): interact_pressed.emit())
		"sprint":
			button.button_down.connect(func():
				if player != null:
					player.set_sprinting(true)
			)
			button.button_up.connect(func():
				if player != null:
					player.set_sprinting(false)
			)
		"scope":
			button.pressed.connect(func(): scope_pressed.emit())
		"camera":
			button.pressed.connect(func(): vehicle_camera_pressed.emit())
		"autofire":
			button.toggle_mode = true
			button.toggled.connect(func(value: bool):
				if player != null:
					player.auto_fire = value
				button.modulate = Color(0.6, 1.0, 0.7) if value else Color.WHITE
			)
		"view":
			button.pressed.connect(func():
				if player != null:
					player.toggle_view_mode()
			)


func _apply_layout() -> void:
	_layout = GameSettings.touch_layout.duplicate(true)
	if _layout.is_empty():
		_layout = DEFAULT_LAYOUT.duplicate(true)
	_apply_positions()


func _apply_positions() -> void:
	var viewport_size := get_viewport().get_visible_rect().size if get_viewport() != null else Vector2(1280, 720)
	var scale := GameSettings.touch_scale
	var size := TOUCH_BASE_SIZE * scale
	for name in _buttons.keys():
		var button: Button = _buttons[name]
		var entry: Dictionary = _layout.get(name, DEFAULT_LAYOUT.get(name, {"x": 0.8, "y": 0.8}))
		button.size = Vector2(size, size)
		button.position = Vector2(viewport_size.x * float(entry.get("x", 0.8)),
				viewport_size.y * float(entry.get("y", 0.8))) - button.size * 0.5


func refresh_layout() -> void:
	_apply_positions()
	for name in _buttons.keys():
		(_buttons[name] as Button).text = Loc.t(String(BUTTON_LABELS.get(name, name)))


func resize_layout(viewport_size: Vector2) -> void:
	for name in _buttons.keys():
		var button: Button = _buttons[name]
		var entry: Dictionary = _layout.get(name, DEFAULT_LAYOUT.get(name, {"x": 0.8, "y": 0.8}))
		button.position = Vector2(viewport_size.x * float(entry.get("x", 0.8)),
				viewport_size.y * float(entry.get("y", 0.8))) - button.size * 0.5


# ------------------------------------------------------------------ ربط
func bind_player(node: Node3D, manager: Node = null) -> void:
	player = node
	if player == null:
		return
	player.health_changed.connect(_on_health_changed)
	player.armor_changed.connect(_on_armor_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.hit_confirmed.connect(_on_hit_confirmed)
	player.damaged_from.connect(_on_damaged_from)
	player.grenades_changed.connect(_on_grenades_changed)
	player.medkits_changed.connect(_on_medkits_changed)
	player.interact_available.connect(_on_interact_available)
	player.interact_cleared.connect(_on_interact_cleared)
	player.entered_vehicle.connect(_on_entered_vehicle)
	player.exited_vehicle.connect(_on_exited_vehicle)

	_on_health_changed(player.health, player.max_health)
	_on_armor_changed(player.armor, player.max_armor)
	_on_grenades_changed(player.grenades)
	_on_medkits_changed(player.medkits)


func bind_mission(manager: Node) -> void:
	if mission_manager == manager and _mission_bound:
		return
	_mission_bound = true
	mission_manager = manager
	if manager == null:
		return
	manager.objective_updated.connect(func(text: String): _objective_label.text = text)
	manager.objective_stage.connect(func(text: String, ratio: float):
		_objective_label.text = text
		_progress_bar.value = clampf(ratio, 0.0, 1.0)
	)
	manager.timer_updated.connect(_on_timer_updated)
	manager.hint.connect(show_message)
	manager.progress_updated.connect(func(current: int, total: int):
		_kills_label.text = "%s: %d / %d" % [Loc.t("hud_kills"), current, total]
	)


func show_message(text: String, duration: float = 2.4) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	_message_timer = duration


func add_killfeed(text: String) -> void:
	var label := _label(text, 14, Color(0.95, 0.95, 0.9))
	_killfeed.add_child(label)
	var tween := label.create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
	while _killfeed.get_child_count() > 5:
		_killfeed.get_child(0).queue_free()
		break


# ------------------------------------------------------------ التحديثات
func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "%s %d" % [Loc.t("hud_health"), int(current)]
	if current < maximum * 0.35:
		_flash_damage(0.22)
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.38))
	else:
		_health_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))


func _on_armor_changed(current: float, maximum: float) -> void:
	_armor_bar.max_value = maximum
	_armor_bar.value = current
	_armor_label.text = "%s %d" % [Loc.t("hud_armor"), int(current)]


func _on_ammo_changed(magazine: int, reserve: int, weapon_name: String) -> void:
	if magazine < 0:
		_ammo_label.text = "∞"
	else:
		_ammo_label.text = "%d | %d" % [magazine, reserve]
	_weapon_label.text = weapon_name


func _on_weapon_changed(weapon_name: String, _weapon_id: String) -> void:
	_weapon_label.text = weapon_name


func _on_grenades_changed(count: int) -> void:
	_grenade_label.text = "%s x%d" % [Loc.t("touch_grenade"), count]


func _on_medkits_changed(count: int) -> void:
	_medkit_label.text = "%s x%d" % [Loc.t("touch_heal"), count]


func _on_timer_updated(seconds_left: int) -> void:
	if seconds_left <= 0:
		_timer_label.text = ""
		return
	_timer_label.text = "%s %02d:%02d" % [Loc.t("hud_time"), seconds_left / 60, seconds_left % 60]


func _on_hit_confirmed(headshot: bool, killed: bool) -> void:
	_hit_timer = 0.2
	_hit_marker.modulate = Color(1, 0.85, 0.3, 1.0) if headshot else Color(1, 1, 1, 1)
	if killed:
		_hit_timer = 0.35
	_hit_marker.queue_redraw()


func _on_damaged_from(direction: Vector3) -> void:
	_flash_damage(0.18)


func _on_interact_available(text: String) -> void:
	_interact_label.text = "[E] " + text
	_interact_label.visible = true
	var interact_button = _buttons.get("interact")
	if interact_button != null:
		(interact_button as Button).modulate = Color(1.0, 1.0, 0.6)


func _on_interact_cleared() -> void:
	_interact_label.visible = false
	var interact_button = _buttons.get("interact")
	if interact_button != null:
		(interact_button as Button).modulate = Color.WHITE


func _on_entered_vehicle(vehicle: Node) -> void:
	_vehicle_panel.visible = true
	_crosshair.visible = false
	if vehicle.has_method("get") and vehicle.get("max_health") != null:
		_vehicle_health.max_value = float(vehicle.get("max_health"))
		_vehicle_health.value = float(vehicle.get("health"))


func _on_exited_vehicle() -> void:
	_vehicle_panel.visible = false
	_crosshair.visible = true


func _flash_damage(alpha: float) -> void:
	_damage_overlay.color = Color(0.8, 0.05, 0.05, alpha)


# --------------------------------------------------------------- الرسم
func _draw_crosshair() -> void:
	var center := _crosshair.size * 0.5
	var gap := 7.0
	var length := 11.0
	var color := Color(0.90, 1.0, 0.92, 0.85)
	for offset in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
		var direction: Vector2 = offset
		_crosshair.draw_line(center + direction * gap, center + direction * (gap + length),
				color, 2.0)
	_crosshair.draw_circle(center, 1.6, color)


func _draw_hit_marker() -> void:
	var center := _hit_marker.size * 0.5
	var color := Color(1.0, 0.45, 0.35, 0.95)
	_hit_marker.draw_line(center + Vector2(-13, -13), center + Vector2(-4, -4), color, 2.5)
	_hit_marker.draw_line(center + Vector2(13, 13), center + Vector2(4, 4), color, 2.5)
	_hit_marker.draw_line(center + Vector2(-13, 13), center + Vector2(-4, 4), color, 2.5)
	_hit_marker.draw_line(center + Vector2(13, -13), center + Vector2(4, -4), color, 2.5)


## رادار مصغّر: اللاعب في المركز، الأعداء أحمر، المركبات أزرق، الأهداف أصفر.
func _draw_minimap() -> void:
	if _minimap == null or player == null:
		return
	var center := _minimap.size * 0.5
	var radius := center.x - 8.0
	_minimap.draw_circle(center, radius + 6.0, Color(0.03, 0.06, 0.08, 0.62))
	_minimap.draw_arc(center, radius, 0, TAU, 48, Color(0.55, 0.78, 1.0, 0.5), 1.5)
	_minimap.draw_arc(center, radius * 0.55, 0, TAU, 40, Color(0.55, 0.78, 1.0, 0.18), 1.0)
	_minimap.draw_line(center + Vector2(-4, 0), center + Vector2(4, 0),
			Color(1, 1, 1, 0.5), 1.0)
	_minimap.draw_line(center + Vector2(0, -4), center + Vector2(0, 4),
			Color(1, 1, 1, 0.5), 1.0)

	var yaw: float = float(player.rotation.y)
	var scale := radius / 55.0

	for node in get_tree().get_nodes_in_group("enemy"):
		_draw_blip(node, center, float(yaw) if false else yaw, scale, Color(0.95, 0.25, 0.2))
	for node in get_tree().get_nodes_in_group("hostage"):
		_draw_blip(node, center, yaw, scale, Color(0.35, 0.95, 0.45))
	for node in get_tree().get_nodes_in_group("charge_target"):
		_draw_blip(node, center, yaw, scale, Color(1.0, 0.8, 0.2))
	for node in get_tree().get_nodes_in_group("vehicle"):
		_draw_blip(node, center, yaw, scale, Color(0.35, 0.65, 1.0))

	# سهم اللاعب
	var arrow := Color(0.95, 0.98, 1.0)
	_minimap.draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -7), center + Vector2(5, 6), center + Vector2(0, 3),
		center + Vector2(-5, 6)
	]), arrow)


func _draw_blip(node: Node, center: Vector2, yaw: float, scale: float, color: Color) -> void:
	if not (node is Node3D) or not is_instance_valid(node):
		return
	var offset: Vector3 = (node as Node3D).global_position - player.global_position
	var flat := Vector2(offset.x, offset.z)
	if flat.length() > 55.0:
		return
	var rotated := flat.rotated(yaw)
	var point := center + Vector2(rotated.x, rotated.y) * scale
	var faded := color
	faded.a = clampf(1.0 - flat.length() / 60.0, 0.35, 1.0)
	_minimap.draw_circle(point, 2.6, faded)


func _draw_scope() -> void:
	var size := _scope_overlay.size
	if size.x <= 0 or size.y <= 0:
		return
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.42
	# تعتيم خارج الدائرة
	_scope_overlay.draw_arc(center, radius, 0, TAU, 64, Color(0.85, 0.9, 0.85, 0.9), 2.0)
	_scope_overlay.draw_line(center + Vector2(-radius, 0), center + Vector2(radius, 0),
			Color(0.1, 0.1, 0.1, 0.9), 1.0)
	_scope_overlay.draw_line(center + Vector2(0, -radius), center + Vector2(0, radius),
			Color(0.1, 0.1, 0.1, 0.9), 1.0)
	for index in 5:
		var offset := (float(index) - 2.0) * radius * 0.16
		_scope_overlay.draw_line(center + Vector2(offset, -6), center + Vector2(offset, 6),
				Color(0.9, 0.9, 0.9, 0.6), 1.0)


func _draw_joystick_base() -> void:
	var center := _joystick_base.size * 0.5
	var radius := JOYSTICK_RADIUS * GameSettings.touch_scale
	_joystick_base.draw_circle(center, radius, Color(0.05, 0.12, 0.2, 0.35))
	_joystick_base.draw_arc(center, radius, 0, TAU, 48, Color(0.55, 0.8, 1.0, 0.55), 2.0)


func _draw_joystick_knob() -> void:
	var center := _joystick_knob.size * 0.5
	_joystick_knob.draw_circle(center, 26, Color(0.38, 0.72, 1.0, 0.75))


# --------------------------------------------------------------- الإدخال
func _input(event: InputEvent) -> void:
	if _edit_mode:
		_handle_edit_input(event)
		return

	if _look_area == null or not _look_area.is_visible_in_tree():
		return

	if event is InputEventScreenTouch:
		if event.pressed and _look_touch == -1:
			var viewport_width := get_viewport().get_visible_rect().size.x
			if event.position.x > viewport_width * 0.34:
				_look_touch = event.index
				_look_last = event.position
				_look_moved = 0.0
		elif not event.pressed and event.index == _look_touch:
			_look_touch = -1
	elif event is InputEventScreenDrag and event.index == _look_touch:
		var delta: Vector2 = event.position - _look_last
		_look_last = event.position
		_look_moved += delta.length()
		if _look_moved > 12.0:
			_send_look(delta * 1.4)


func _send_look(delta: Vector2) -> void:
	if player == null:
		return
	if player.is_in_vehicle():
		var vehicle = player.current_vehicle
		if vehicle != null and vehicle.has_method("add_look_input"):
			vehicle.add_look_input(delta * 1.4)
	else:
		player.add_look_input(delta * 1.4)


func _on_joystick_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _joystick_touch == -1:
			_joystick_touch = event.index
			_update_joystick(event.position)
		elif not event.pressed and event.index == _joystick_touch:
			_joystick_touch = -1
			_reset_joystick()
	elif event is InputEventScreenDrag and event.index == _joystick_touch:
		_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_update_joystick(event.position)
		else:
			_reset_joystick()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_joystick(event.position)


func _update_joystick(local_position: Vector2) -> void:
	var center := _joystick_base.size * 0.5
	var offset := local_position - center
	var radius := JOYSTICK_RADIUS * GameSettings.touch_scale
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_joystick_knob.position = center + offset - _joystick_knob.size * 0.5
	if player != null:
		player.set_move_input(Vector2(offset.x, offset.y) / radius)


func _reset_joystick() -> void:
	_joystick_knob.position = _joystick_base.size * 0.5 - _joystick_knob.size * 0.5
	if player != null:
		player.set_move_input(Vector2.ZERO)


# ------------------------------------------------------- تخصيص التخطيط
func set_edit_mode(value: bool) -> void:
	_edit_mode = value
	_touch_layer.visible = _touch_available() or value
	for name in _buttons.keys():
		var button: Button = _buttons[name]
		button.button_mask = 0
		if value:
			button.modulate = Color(1.0, 1.0, 0.7, 1.0)
		else:
			button.modulate = Color.WHITE
	if not value:
		GameSettings.set_touch_layout(_layout)
	_refresh_button_labels()


func _refresh_button_labels() -> void:
	for name in _buttons.keys():
		(_buttons[name] as Button).text = Loc.t(String(BUTTON_LABELS.get(name, name)))


func _handle_edit_input(event: InputEvent) -> void:
	var position := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch:
		position = event.position
		pressed = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		position = event.position
		pressed = event.pressed
	elif event is InputEventMouseMotion:
		position = event.position
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _dragging != "":
			_drag_to(position)
		return
	elif event is InputEventScreenDrag:
		if _dragging != "":
			_drag_to(event.position)
		return
	else:
		return

	if pressed:
		for name in _buttons.keys():
			var button: Button = _buttons[name]
			if button.get_global_rect().has_point(position):
				_dragging = name
				_drag_offset = position - button.position
				break
	else:
		_dragging = ""
		GameSettings.set_touch_layout(_layout)


func _drag_to(position: Vector2) -> void:
	var button: Button = _buttons.get(_dragging)
	if button == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var target := position - _drag_offset
	button.position = target
	_layout[_dragging] = {
		"x": clampf((target.x + button.size.x * 0.5) / viewport_size.x, 0.02, 0.98),
		"y": clampf((target.y + button.size.y * 0.5) / viewport_size.y, 0.02, 0.98)
	}


# --------------------------------------------------------------- الحلقة
func _process(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer -= delta
		_hit_marker.modulate.a = clampf(_hit_timer / 0.2, 0.0, 1.0)

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.6:
			_message_label.modulate.a = clampf(_message_timer / 0.6, 0.0, 1.0)

	if _damage_overlay.color.a > 0.0:
		_damage_overlay.color.a = maxf(0.0, _damage_overlay.color.a - delta * 0.7)

	if player == null:
		return
	if _minimap != null:
		_minimap.queue_redraw()
	if player.get("stamina") != null:
		_stamina_bar.value = float(player.stamina)

	var weapon = player.current_weapon()
	if weapon is Dictionary and not (weapon as Dictionary).is_empty():
		var reloading: bool = player.is_reloading()
		_reload_bar.visible = reloading
		if reloading:
			_reload_bar.value = player.reload_progress()

	# منظار
	var scope: float = player.scope_level()
	var use_scope: bool = scope > 2.05 and bool(player.is_aiming) and not bool(player.is_in_vehicle())
	if use_scope != _scope_overlay.visible:
		_scope_overlay.visible = use_scope
		_crosshair.visible = not use_scope
		_hit_marker.visible = not use_scope
		_scope_overlay.queue_redraw()

	# مركبة
	if player.is_in_vehicle() and player.current_vehicle != null:
		var vehicle = player.current_vehicle
		_vehicle_panel.visible = true
		_vehicle_health.value = float(vehicle.get("health"))
		_vehicle_speed.text = "%d km/h" % int(vehicle.call("speed_kmh"))
	else:
		_vehicle_panel.visible = false
