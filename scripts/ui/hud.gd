extends CanvasLayer
## واجهة اللعب: الصحة، الذخيرة، الهدف، المؤقت، التصويب، وأزرار اللمس.

signal pause_pressed
signal weapon_pressed
signal reload_pressed
signal jump_pressed
signal aim_changed(pressed: bool)

const TOUCH_SIZE := 132.0
const JOYSTICK_RADIUS := 68.0

var player: Node3D = null
var mission_manager: Node = null

var _health_bar: ProgressBar
var _health_label: Label
var _ammo_label: Label
var _weapon_label: Label
var _objective_label: Label
var _timer_label: Label
var _kills_label: Label
var _message_label: Label
var _crosshair: Control
var _hit_marker: Control
var _damage_overlay: ColorRect
var _touch_layer: Control

var _joystick_base: Control
var _joystick_knob: Control
var _joystick_touch := -1
var _joystick_center := Vector2.ZERO

var _look_touch := -1
var _look_last := Vector2.ZERO
var _look_moved := 0.0

var _hit_timer := 0.0
var _message_timer := 0.0


func _ready() -> void:
	layer = 10
	_build()
	set_process(true)
	set_process_input(true)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ---- شريط الصحة ----
	var health_box := VBoxContainer.new()
	health_box.position = Vector2(24, 20)
	health_box.size = Vector2(280, 60)
	root.add_child(health_box)

	_health_label = Label.new()
	_health_label.text = "الصحة 100"
	_health_label.add_theme_font_size_override("font_size", 18)
	_health_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	health_box.add_child(_health_label)

	_health_bar = ProgressBar.new()
	_health_bar.min_value = 0
	_health_bar.max_value = 100
	_health_bar.value = 100
	_health_bar.custom_minimum_size = Vector2(280, 16)
	_health_bar.show_percentage = false
	health_box.add_child(_health_bar)

	# ---- الهدف والمؤقت ----
	_objective_label = Label.new()
	_objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective_label.position = Vector2(-320, 18)
	_objective_label.size = Vector2(640, 30)
	_objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_label.add_theme_font_size_override("font_size", 17)
	_objective_label.add_theme_color_override("font_color", Color(0.95, 0.87, 0.6))
	root.add_child(_objective_label)

	_timer_label = Label.new()
	_timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_timer_label.position = Vector2(-120, 48)
	_timer_label.size = Vector2(240, 26)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 16)
	_timer_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	root.add_child(_timer_label)

	# ---- العدّادات ----
	_kills_label = Label.new()
	_kills_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_kills_label.position = Vector2(-260, 20)
	_kills_label.size = Vector2(230, 26)
	_kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_kills_label.add_theme_font_size_override("font_size", 16)
	_kills_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	root.add_child(_kills_label)

	# ---- الذخيرة ----
	_ammo_label = Label.new()
	_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.position = Vector2(-230, -120)
	_ammo_label.size = Vector2(200, 40)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label.add_theme_font_size_override("font_size", 30)
	_ammo_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.75))
	root.add_child(_ammo_label)

	_weapon_label = Label.new()
	_weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.position = Vector2(-230, -78)
	_weapon_label.size = Vector2(200, 24)
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_weapon_label.add_theme_font_size_override("font_size", 14)
	_weapon_label.add_theme_color_override("font_color", Color(0.8, 0.86, 0.95))
	root.add_child(_weapon_label)

	# ---- مؤشر التصويب ----
	_crosshair = Control.new()
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.size = Vector2(28, 28)
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.position = Vector2(-14, -14)
	_crosshair.draw.connect(_draw_crosshair)
	root.add_child(_crosshair)

	_hit_marker = Control.new()
	_hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_marker.size = Vector2(40, 40)
	_hit_marker.set_anchors_preset(Control.PRESET_CENTER)
	_hit_marker.position = Vector2(-20, -20)
	_hit_marker.modulate.a = 0.0
	_hit_marker.draw.connect(_draw_hit_marker)
	root.add_child(_hit_marker)

	# ---- وميض الضرر ----
	_damage_overlay = ColorRect.new()
	_damage_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_overlay.color = Color(0.8, 0.05, 0.05, 0.0)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_overlay)

	# ---- رسائل المركز ----
	_message_label = Label.new()
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.position = Vector2(-300, -120)
	_message_label.size = Vector2(600, 80)
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", 40)
	_message_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	_message_label.modulate.a = 0.0
	root.add_child(_message_label)

	# ---- زر الإيقاف ----
	var pause_button := Button.new()
	pause_button.text = "II"
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.position = Vector2(-64, 16)
	pause_button.size = Vector2(48, 48)
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.pressed.connect(func(): pause_pressed.emit())
	root.add_child(pause_button)

	_build_touch_controls(root)


func _build_touch_controls(root: Control) -> void:
	var touch_available := DisplayServer.is_touchscreen_available() \
		or OS.has_feature("mobile") or OS.has_feature("android")

	_touch_layer = Control.new()
	_touch_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_layer.visible = touch_available
	root.add_child(_touch_layer)

	# عصا الحركة (يسار أسفل).
	_joystick_base = Control.new()
	_joystick_base.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick_base.position = Vector2(30, -180)
	_joystick_base.size = Vector2(TOUCH_SIZE + 30, TOUCH_SIZE + 30)
	_joystick_base.mouse_filter = Control.MOUSE_FILTER_STOP
	_joystick_base.draw.connect(_draw_joystick_base)
	_joystick_base.gui_input.connect(_on_joystick_input)
	_touch_layer.add_child(_joystick_base)

	_joystick_knob = Control.new()
	_joystick_knob.size = Vector2(56, 56)
	_joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_joystick_knob.draw.connect(_draw_joystick_knob)
	_joystick_base.add_child(_joystick_knob)
	_joystick_knob.position = _joystick_base.size * 0.5 - Vector2(28, 28)

	# زر الإطلاق.
	var fire := _make_touch_button("إطلاق", Vector2(-170, -170), Vector2(120, 120))
	fire.button_down.connect(func():
		if player != null:
			player.set_firing(true)
	)
	fire.button_up.connect(func():
		if player != null:
			player.set_firing(false)
	)
	_touch_layer.add_child(fire)

	# تصويب.
	var aim := _make_touch_button("تصويب", Vector2(-300, -210), Vector2(96, 96))
	aim.button_down.connect(func():
		if player != null:
			player.set_aiming(true)
		aim_changed.emit(true)
	)
	aim.button_up.connect(func():
		if player != null:
			player.set_aiming(false)
		aim_changed.emit(false)
	)
	_touch_layer.add_child(aim)

	# إعادة تلقيم.
	var reload := _make_touch_button("تلقيم", Vector2(-180, -290), Vector2(86, 86))
	reload.pressed.connect(func(): reload_pressed.emit())
	_touch_layer.add_child(reload)

	# تبديل السلاح.
	var weapon := _make_touch_button("سلاح", Vector2(-290, -110), Vector2(80, 80))
	weapon.pressed.connect(func(): weapon_pressed.emit())
	_touch_layer.add_child(weapon)

	# قفز.
	var jump := _make_touch_button("قفز", Vector2(-390, -150), Vector2(74, 74))
	jump.pressed.connect(func(): jump_pressed.emit())
	_touch_layer.add_child(jump)


func _make_touch_button(text: String, offset: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.position = offset
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 16)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.1, 0.35, 0.55, 0.42)
	normal.border_color = Color(0.5, 0.8, 1.0, 0.65)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(40)
	button.add_theme_stylebox_override("normal", normal)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.2, 0.6, 0.9, 0.7)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("hover", normal)

	return button


func _draw_joystick_base() -> void:
	var center := _joystick_base.size * 0.5
	_joystick_base.draw_circle(center, JOYSTICK_RADIUS, Color(0.05, 0.12, 0.2, 0.35))
	_joystick_base.draw_arc(center, JOYSTICK_RADIUS, 0, TAU, 48, Color(0.5, 0.75, 1.0, 0.55), 2.0)


func _draw_joystick_knob() -> void:
	var center := _joystick_knob.size * 0.5
	_joystick_knob.draw_circle(center, 28, Color(0.35, 0.7, 1.0, 0.75))


func _draw_crosshair() -> void:
	var c := _crosshair.size * 0.5
	var gap := 6.0
	var length := 10.0
	var color := Color(0.85, 1.0, 0.9, 0.85)

	_crosshair.draw_line(c + Vector2(0, -gap), c + Vector2(0, -gap - length), color, 2.0)
	_crosshair.draw_line(c + Vector2(0, gap), c + Vector2(0, gap + length), color, 2.0)
	_crosshair.draw_line(c + Vector2(-gap, 0), c + Vector2(-gap - length, 0), color, 2.0)
	_crosshair.draw_line(c + Vector2(gap, 0), c + Vector2(gap + length, 0), color, 2.0)
	_crosshair.draw_circle(c, 2.0, color)


func _draw_hit_marker() -> void:
	var c := _hit_marker.size * 0.5
	var color := Color(1.0, 0.45, 0.35, 0.95)
	_hit_marker.draw_line(c + Vector2(-12, -12), c + Vector2(-4, -4), color, 2.5)
	_hit_marker.draw_line(c + Vector2(12, 12), c + Vector2(4, 4), color, 2.5)
	_hit_marker.draw_line(c + Vector2(-12, 12), c + Vector2(-4, 4), color, 2.5)
	_hit_marker.draw_line(c + Vector2(12, -12), c + Vector2(4, -4), color, 2.5)


func bind_player(node: Node3D) -> void:
	player = node

	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.player_died.connect(_on_player_died)
	player.hit_confirmed.connect(_on_hit_confirmed)

	_on_health_changed(player.health, player.max_health)


func bind_mission(manager: Node) -> void:
	mission_manager = manager

	manager.objective_updated.connect(func(text: String): _objective_label.text = text)
	manager.progress_updated.connect(func(current: int, total: int):
		_kills_label.text = "القتلى: %d / %d" % [current, total]
	)
	manager.timer_updated.connect(func(seconds_left: int):
		_timer_label.text = "الوقت: %s" % _format_time(seconds_left)
	)


func _format_time(total_seconds: int) -> String:
	var minutes := int(total_seconds) / 60
	var seconds := int(total_seconds) % 60
	return "%02d:%02d" % [minutes, seconds]


func _on_health_changed(current: float, maximum: float) -> void:
	_health_bar.max_value = maximum
	_health_bar.value = current
	_health_label.text = "الصحة %d" % int(current)

	if current < maximum * 0.35:
		_flash_damage(0.25)
		_health_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	else:
		_health_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))


func _on_ammo_changed(magazine: int, reserve: int, weapon_name: String) -> void:
	_ammo_label.text = "%d | %d" % [magazine, reserve]
	_weapon_label.text = weapon_name


func _on_weapon_changed(weapon_name: String) -> void:
	_weapon_label.text = weapon_name


func _on_player_died() -> void:
	show_message("لقد سقطت!", 2.0)


func _on_hit_confirmed(headshot: bool, _killed: bool) -> void:
	_hit_timer = 0.18
	_hit_marker.modulate = Color(1, 1, 1, 1) if not headshot else Color(1.0, 0.85, 0.3, 1)


func _flash_damage(alpha: float) -> void:
	_damage_overlay.color = Color(0.8, 0.05, 0.05, alpha)


func show_message(text: String, duration: float = 2.5) -> void:
	_message_label.text = text
	_message_label.modulate.a = 1.0
	_message_timer = duration


func _process(delta: float) -> void:
	if _hit_timer > 0.0:
		_hit_timer -= delta
		_hit_marker.modulate.a = clampf(_hit_timer / 0.18, 0.0, 1.0)

	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.6:
			_message_label.modulate.a = clampf(_message_timer / 0.6, 0.0, 1.0)

	if _damage_overlay.color.a > 0.0:
		_damage_overlay.color.a = maxf(0.0, _damage_overlay.color.a - delta * 0.8)


func _input(event: InputEvent) -> void:
	# سحب الإصبع على يمين الشاشة = تدوير الكاميرا.
	if event is InputEventScreenTouch:
		if event.pressed and _look_touch == -1:
			if event.position.x > get_viewport().get_visible_rect().size.x * 0.38:
				_look_touch = event.index
				_look_last = event.position
				_look_moved = 0.0
		elif not event.pressed and event.index == _look_touch:
			_look_touch = -1

	elif event is InputEventScreenDrag:
		if event.index == _look_touch:
			var delta: Vector2 = event.position - _look_last
			_look_last = event.position
			_look_moved += delta.length()

			# تجاهل النقرات القصيرة حتى لا تتعارض مع الأزرار.
			if _look_moved > 14.0 and player != null:
				player.add_look_input(delta * 1.35)


func _on_joystick_input(event: InputEvent) -> void:
	# دعم اللمس والفأرة معاً (الفأرة للتجربة على الحاسب).
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
	var radius := JOYSTICK_RADIUS

	if offset.length() > radius:
		offset = offset.normalized() * radius

	_joystick_knob.position = center + offset - _joystick_knob.size * 0.5

	if player != null:
		player.set_move_input(Vector2(offset.x, offset.y) / radius)


func _reset_joystick() -> void:
	_joystick_knob.position = _joystick_base.size * 0.5 - _joystick_knob.size * 0.5
	if player != null:
		player.set_move_input(Vector2.ZERO)


func set_touch_visible(value: bool) -> void:
	if _touch_layer != null:
		_touch_layer.visible = value
