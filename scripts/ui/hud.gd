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

# أزرار قليلة ومدروسة: الإطلاق/التصويب/القفز/التلقيم/تبديل السلاح/القنبلة/العلاج/الانحناء
# والباقي يظهر فقط عند الحاجة (التفعيل قرب مركبة، كاميرا داخل مركبة).
const TOUCH_BUTTONS := [
	"fire", "aim", "jump", "reload", "weapon", "grenade", "heal",
	"crouch", "interact", "camera", "autofire", "view"
]

# مقاسات مستقلة لكل زر (بالبكسل قبل معامل تكبير الإعدادات)
const TOUCH_SIZES := {
	"fire": 148.0, "aim": 104.0, "jump": 88.0, "reload": 92.0, "weapon": 84.0,
	"grenade": 76.0, "heal": 76.0, "crouch": 74.0, "interact": 92.0,
	"camera": 82.0, "autofire": 60.0, "view": 56.0
}

const TOUCH_FONTS := {
	"fire": 26, "aim": 20, "jump": 19, "reload": 19, "weapon": 17,
	"grenade": 15, "heal": 16, "crouch": 15, "interact": 18,
	"camera": 16, "autofire": 13, "view": 13
}

# توزيع الإبهامين: يسار = عصا + انحناء، يمين = قوس إطلاق/تصويب/قفز ونظام تلقيم أسفله
const DEFAULT_LAYOUT := {
	"fire": {"x": 0.905, "y": 0.815},
	"aim": {"x": 0.905, "y": 0.500},
	"jump": {"x": 0.888, "y": 0.660},
	"reload": {"x": 0.775, "y": 0.848},
	"weapon": {"x": 0.668, "y": 0.888},
	"grenade": {"x": 0.566, "y": 0.905},
	"heal": {"x": 0.792, "y": 0.700},
	"crouch": {"x": 0.052, "y": 0.930},
	"interact": {"x": 0.300, "y": 0.790},
	"camera": {"x": 0.905, "y": 0.355},
	"autofire": {"x": 0.845, "y": 0.240},
	"view": {"x": 0.945, "y": 0.240}
}

const BUTTON_LABELS := {
	"fire": "touch_fire", "aim": "touch_aim", "reload": "touch_reload",
	"weapon": "touch_weapon", "jump": "touch_jump", "crouch": "touch_crouch",
	"grenade": "touch_grenade", "heal": "touch_heal", "interact": "touch_interact",
	"camera": "touch_switch_view", "autofire": "touch_autofire", "view": "touch_view"
}

const TOUCH_BASE_SIZE := 92.0
const JOYSTICK_RADIUS := 94.0
const JOYSTICK_CENTER := Vector2(0.105, 0.745)

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
var _last_aim_press := 0
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
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- شريط الصحة والدرع ----
	var stats := VBoxContainer.new()
	stats.set_anchors_preset(Control.PRESET_CENTER_TOP)
	stats.position = Vector2(-200, 8)
	stats.size = Vector2(400, 100)
	stats.add_theme_constant_override("separation", 3)
	_root.add_child(stats)

	_health_label = _label(Loc.t("hud_health") + " 100", 20, Color(0.92, 0.96, 1.0))
	_health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(_health_label)
	_health_bar = _bar(Color(0.85, 0.24, 0.22), 400.0)
	_health_bar.custom_minimum_size = Vector2(400, 18)
	stats.add_child(_health_bar)

	_armor_label = _label(Loc.t("hud_armor") + " 100", 15, Color(0.65, 0.82, 1.0))
	_armor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_child(_armor_label)
	_armor_bar = _bar(Color(0.30, 0.60, 0.95), 400.0)
	_armor_bar.custom_minimum_size = Vector2(400, 10)
	stats.add_child(_armor_bar)

	_stamina_bar = _bar(Color(0.55, 0.85, 0.45), 400.0)
	_stamina_bar.custom_minimum_size = Vector2(400, 5)
	stats.add_child(_stamina_bar)

	# ---- الهدف ----
	_objective_label = _label("", 20, Color(0.97, 0.89, 0.62))
	_objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_label.position = Vector2(-260, 116)
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
	_progress_bar.offset_top = 150
	_progress_bar.offset_right = 140
	_progress_bar.offset_bottom = 156

	_timer_label = _label("", 16, Color(0.85, 0.92, 1.0))
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.position = Vector2(-90, 160)
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
	_ammo_label = _label("", 36, Color(1.0, 0.94, 0.76))
	_ammo_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_ammo_label.position = Vector2(-230, 128)
	_ammo_label.size = Vector2(210, 46)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_ammo_label)

	_weapon_label = _label("", 18, Color(0.82, 0.88, 0.97))
	_weapon_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_weapon_label.position = Vector2(-250, 100)
	_weapon_label.size = Vector2(230, 26)
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
	_minimap.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_minimap.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_minimap.offset_left = 18.0
	_minimap.offset_top = 86.0
	_minimap.offset_right = 226.0
	_minimap.offset_bottom = 294.0
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
	pause_button.layout_direction = Control.LAYOUT_DIRECTION_LTR
	pause_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause_button.offset_left = 18.0
	pause_button.offset_top = 14.0
	pause_button.offset_right = 82.0
	pause_button.offset_bottom = 78.0
	pause_button.focus_mode = Control.FOCUS_NONE
	var pause_style := StyleBoxFlat.new()
	pause_style.bg_color = Color(0.04, 0.08, 0.12, 0.55)
	pause_style.border_color = Color(0.75, 0.88, 1.0, 0.8)
	pause_style.set_border_width_all(2)
	pause_style.set_corner_radius_all(32)
	var pause_pressed_style := pause_style.duplicate() as StyleBoxFlat
	pause_pressed_style.bg_color = Color(0.30, 0.70, 1.0, 0.85)
	pause_button.add_theme_stylebox_override("normal", pause_style)
	pause_button.add_theme_stylebox_override("hover", pause_style)
	pause_button.add_theme_stylebox_override("pressed", pause_pressed_style)
	pause_button.add_theme_font_size_override("font_size", 24)
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
func touch_controls_visible() -> bool:
	return _touch_layer != null and _touch_layer.visible


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
	_joystick_base.size = Vector2(JOYSTICK_RADIUS * 2.0, JOYSTICK_RADIUS * 2.0)
	_joystick_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joystick_base.draw.connect(_draw_joystick_base)
	_joystick_base.gui_input.connect(_on_joystick_input)
	_touch_layer.add_child(_joystick_base)

	_joystick_knob = Control.new()
	_joystick_knob.size = Vector2(56, 56)
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_knob.draw.connect(_draw_joystick_knob)
	_joystick_base.add_child(_joystick_knob)

	for name in TOUCH_BUTTONS:
		var button := Button.new()
		button.text = ""
		button.focus_mode = Control.FOCUS_NONE
		var base_size := float(TOUCH_SIZES.get(name, TOUCH_BASE_SIZE))
		button.size = Vector2(base_size, base_size)
		button.set_meta("touch_name", name)
		_style_button(button, name in ["fire", "aim"], name)
		_connect_button(button, name)
		button.draw.connect(func(): _draw_touch_icon(button, name))
		_touch_layer.add_child(button)
		_buttons[name] = button

	# أزرار تظهر عند الحاجة فقط حتى تبقى الشاشة نظيفة
	for hidden_by_default in ["interact", "camera"]:
		var hidden_button = _buttons.get(hidden_by_default)
		if hidden_button != null:
			(hidden_button as Button).visible = false
	_reset_joystick()


func _style_button(button: Button, primary: bool, name: String = "") -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.02, 0.03, 0.05, 0.42 if primary else 0.34)
	normal.border_color = Color(1.0, 1.0, 1.0, 0.20 if primary else 0.14)
	normal.set_border_width_all(2)
	var radius := int((TOUCH_SIZES.get(name, TOUCH_BASE_SIZE)) * 0.5)
	normal.set_corner_radius_all(radius)
	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(1.0, 1.0, 1.0, 0.30)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _draw_touch_icon(button: Button, icon: String) -> void:
	var s2: Vector2 = button.size
	var c := s2 * 0.5
	var r := minf(s2.x, s2.y) * 0.5
	var white := Color(1.0, 1.0, 1.0, 0.92)
	var thick := maxf(2.0, r * 0.075)
	match icon:
		"fire":
			button.draw_arc(c, r * 0.36, 0, TAU, 32, Color(1, 1, 1, 0.35), thick * 0.7)
			for offset in [Vector2(0, -1), Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0)]:
				var d: Vector2 = offset
				button.draw_line(c + d * r * 0.46, c + d * r * 0.72, white, thick)
			button.draw_circle(c, r * 0.10, white)
		"aim":
			button.draw_arc(c, r * 0.44, 0, TAU, 36, white, thick * 0.8)
			button.draw_line(c + Vector2(-r * 0.62, 0), c + Vector2(-r * 0.30, 0), white, thick * 0.8)
			button.draw_line(c + Vector2(r * 0.30, 0), c + Vector2(r * 0.62, 0), white, thick * 0.8)
			button.draw_line(c + Vector2(0, -r * 0.62), c + Vector2(0, -r * 0.30), white, thick * 0.8)
			button.draw_line(c + Vector2(0, r * 0.30), c + Vector2(0, r * 0.62), white, thick * 0.8)
			button.draw_circle(c, r * 0.09, white)
		"jump":
			button.draw_line(c + Vector2(0, r * 0.50), c + Vector2(0, -r * 0.44), white, thick)
			button.draw_line(c + Vector2(0, -r * 0.44), c + Vector2(-r * 0.26, -r * 0.14), white, thick)
			button.draw_line(c + Vector2(0, -r * 0.44), c + Vector2(r * 0.26, -r * 0.14), white, thick)
		"reload":
			button.draw_arc(c, r * 0.40, deg_to_rad(-50), deg_to_rad(215), 28, white, thick)
			var tip := c + Vector2(r * 0.40, 0).rotated(deg_to_rad(-50))
			button.draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-r * 0.12, -r * 0.16),
				tip + Vector2(r * 0.16, r * 0.06),
				tip + Vector2(-r * 0.16, r * 0.10)
			]), white)
		"weapon":
			button.draw_line(c + Vector2(-r * 0.44, -r * 0.16), c + Vector2(r * 0.42, -r * 0.16), white, thick * 0.85)
			button.draw_line(c + Vector2(-r * 0.44, r * 0.16), c + Vector2(r * 0.42, r * 0.16), white, thick * 0.85)
			button.draw_colored_polygon(PackedVector2Array([
				c + Vector2(r * 0.42, -r * 0.34), c + Vector2(r * 0.62, -r * 0.16), c + Vector2(r * 0.42, r * 0.02)
			]), white)
			button.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 0.44, -r * 0.02), c + Vector2(-r * 0.64, r * 0.16), c + Vector2(-r * 0.44, r * 0.34)
			]), white)
		"grenade":
			button.draw_circle(c + Vector2(0, r * 0.08), r * 0.30, Color(1, 1, 1, 0.85))
			button.draw_line(c + Vector2(0, -r * 0.22), c + Vector2(0, -r * 0.44), white, thick * 0.8)
			button.draw_line(c + Vector2(r * 0.10, -r * 0.40), c + Vector2(r * 0.30, -r * 0.46), white, thick * 0.7)
		"heal":
			button.draw_rect(Rect2(c + Vector2(-r * 0.10, -r * 0.36), Vector2(r * 0.20, r * 0.72)), white)
			button.draw_rect(Rect2(c + Vector2(-r * 0.36, -r * 0.10), Vector2(r * 0.72, r * 0.20)), white)
		"crouch":
			button.draw_circle(c + Vector2(-r * 0.16, -r * 0.34), r * 0.13, white)
			button.draw_line(c + Vector2(-r * 0.16, -r * 0.20), c + Vector2(-r * 0.10, r * 0.10), white, thick)
			button.draw_line(c + Vector2(-r * 0.10, r * 0.10), c + Vector2(r * 0.30, r * 0.24), white, thick)
			button.draw_line(c + Vector2(-r * 0.16, -r * 0.06), c + Vector2(r * 0.22, -r * 0.10), white, thick)
		"interact":
			button.draw_arc(c, r * 0.40, deg_to_rad(-40), deg_to_rad(40), 16, Color(1, 1, 1, 0.25), thick * 0.7)
			button.draw_circle(c, r * 0.16, Color(1, 1, 1, 0.85))
		"camera":
			button.draw_rect(Rect2(c + Vector2(-r * 0.40, -r * 0.24), Vector2(r * 0.80, r * 0.50)), Color(1, 1, 1, 0.85),
					false, thick)
			button.draw_circle(c + Vector2(0, r * 0.02), r * 0.13, Color(1, 1, 1, 0.85))
		"autofire":
			button.draw_arc(c, r * 0.34, 0, TAU, 24, Color(1, 1, 1, 0.75), thick * 0.8)
			button.draw_circle(c, r * 0.10, white)
			button.draw_line(c + Vector2(-r * 0.45, -r * 0.30), c + Vector2(-r * 0.20, -r * 0.12), Color(1, 1, 1, 0.7), thick * 0.7)
		"view":
			button.draw_arc(c, r * 0.30, 0, TAU, 24, Color(1, 1, 1, 0.80), thick * 0.8)
			button.draw_circle(c, r * 0.09, white)
			button.draw_line(c + Vector2(-r * 0.46, 0), c + Vector2(-r * 0.28, 0), Color(1, 1, 1, 0.6), thick * 0.7)
			button.draw_line(c + Vector2(r * 0.28, 0), c + Vector2(r * 0.46, 0), Color(1, 1, 1, 0.6), thick * 0.7)


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
				# ضغطتان سريعتان تبدّلان تقريب المنظار بدون زر إضافي
				var now := Time.get_ticks_msec()
				if now - _last_aim_press < 320:
					scope_pressed.emit()
				_last_aim_press = now
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
	for name in _buttons.keys():
		var button: Button = _buttons[name]
		var entry: Dictionary = _layout.get(name, DEFAULT_LAYOUT.get(name, {"x": 0.8, "y": 0.8}))
		var size := float(TOUCH_SIZES.get(name, TOUCH_BASE_SIZE)) * scale
		button.size = Vector2(size, size)
		button.position = Vector2(viewport_size.x * float(entry.get("x", 0.8)),
				viewport_size.y * float(entry.get("y", 0.8))) - button.size * 0.5
	if _joystick_base != null:
		var joy_size := JOYSTICK_RADIUS * 2.0 * scale
		_joystick_base.size = Vector2(joy_size, joy_size)
		_joystick_base.position = Vector2(viewport_size.x * JOYSTICK_CENTER.x,
				viewport_size.y * JOYSTICK_CENTER.y) - _joystick_base.size * 0.5
		_reset_joystick()


func refresh_layout() -> void:
	_apply_positions()
	for name in _buttons.keys():
		(_buttons[name] as Button).text = ""
		(_buttons[name] as Button).queue_redraw()


func resize_layout(viewport_size: Vector2) -> void:
	_apply_positions()
	# احتياط: إن اختلف حجم الـviewport عن المقروء داخل _apply_positions
	if _joystick_base != null:
		var scale := GameSettings.touch_scale
		var joy_size := JOYSTICK_RADIUS * 2.0 * scale
		_joystick_base.position = Vector2(viewport_size.x * JOYSTICK_CENTER.x,
				viewport_size.y * JOYSTICK_CENTER.y) - Vector2(joy_size, joy_size) * 0.5


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
	_set_button_visible("grenade", count > 0)


func _on_medkits_changed(count: int) -> void:
	_medkit_label.text = "%s x%d" % [Loc.t("touch_heal"), count]
	_set_button_visible("heal", count > 0)


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
	_interact_label.text = text
	_interact_label.visible = true
	_set_button_visible("interact", true)


func _on_interact_cleared() -> void:
	_interact_label.visible = false
	_set_button_visible("interact", false)


func _set_button_visible(button_name: String, value: bool) -> void:
	var button = _buttons.get(button_name)
	if button != null:
		(button as Button).visible = value


func _on_entered_vehicle(vehicle: Node) -> void:
	_vehicle_panel.visible = true
	_crosshair.visible = false
	_set_button_visible("camera", true)
	_set_button_visible("jump", false)
	_set_button_visible("crouch", false)
	_set_button_visible("view", false)
	if vehicle.has_method("get") and vehicle.get("max_health") != null:
		_vehicle_health.max_value = float(vehicle.get("max_health"))
		_vehicle_health.value = float(vehicle.get("health"))


func _on_exited_vehicle() -> void:
	_vehicle_panel.visible = false
	_crosshair.visible = true
	_set_button_visible("camera", false)
	_set_button_visible("jump", true)
	_set_button_visible("crouch", true)
	_set_button_visible("view", true)


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
	var radius := _joystick_base.size.x * 0.5
	_joystick_base.draw_circle(center, radius, Color(0.05, 0.12, 0.2, 0.30))
	_joystick_base.draw_arc(center, radius - 2.0, 0, TAU, 56, Color(0.55, 0.8, 1.0, 0.45), 2.0)


func _draw_joystick_knob() -> void:
	var center := _joystick_knob.size * 0.5
	_joystick_knob.draw_circle(center, 28, Color(0.38, 0.72, 1.0, 0.70))


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
	var radius := _joystick_base.size.x * 0.5
	if offset.length() > radius:
		offset = offset.normalized() * radius
	_joystick_knob.position = center + offset - _joystick_knob.size * 0.5
	if player != null:
		player.set_move_input(Vector2(offset.x, offset.y) / radius)
		# دفع العصا لآخرها = ركض تلقائي، بدون زر إضافي
		player.set_sprinting(offset.length() > radius * 0.92)


func _reset_joystick() -> void:
	_joystick_knob.position = _joystick_base.size * 0.5 - _joystick_knob.size * 0.5
	if player != null:
		player.set_move_input(Vector2.ZERO)
		player.set_sprinting(false)


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
		(_buttons[name] as Button).text = ""
		(_buttons[name] as Button).tooltip_text = Loc.t(String(BUTTON_LABELS.get(name, name)))


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
