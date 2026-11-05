extends Control
## زر قائمة بتصميم عسكري: زوايا مشطوفة، إطار نحاسي، توهج للزر الرئيسي.

signal pressed

var label_text := ""
var hint_text := ""
var primary := false
var disabled := false:
	set(value):
		disabled = value
		modulate = Color(1, 1, 1, 0.38) if value else Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_IGNORE if value else Control.MOUSE_FILTER_STOP
		queue_redraw()
var _hover := false
var _held := false
var _font: Font
var _font_size := 28
var _time := 0.0

const GOLD_A := Color(1.0, 0.72, 0.24)
const GOLD_B := Color(0.94, 0.52, 0.06)
const GOLD_EDGE := Color(1.0, 0.87, 0.52)
const STEEL := Color(0.09, 0.13, 0.18, 0.94)
const STEEL_EDGE := Color(0.72, 0.52, 0.26, 0.85)
const LABEL := Color(0.90, 0.95, 1.0)
const LABEL_ACTIVE := Color(0.10, 0.07, 0.02)


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://assets/fonts/NotoSansArabic-Bold.ttf")
	if _font == null:
		_font = ThemeDB.fallback_font
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; _held = false; queue_redraw())
	set_process(true)


func setup(text: String, is_primary: bool, font_size: int = 28, hint: String = "") -> void:
	label_text = text
	primary = is_primary
	_font_size = font_size
	hint_text = hint
	queue_redraw()


func _process(delta: float) -> void:
	if primary:
		_time += delta
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = true
			queue_redraw()
		elif _held:
			_held = false
			queue_redraw()
			AudioManager.play_ui("ui_click", -6.0)
			pressed.emit()


func _shape(width: float, height: float, inset: float) -> PackedVector2Array:
	var cut := clampf(height * 0.26, 10.0, 26.0)
	var left := inset
	var top := inset
	var right := width - inset
	var bottom := height - inset
	return PackedVector2Array([
		Vector2(left + cut, top),
		Vector2(right - cut * 0.45, top),
		Vector2(right, top + height * 0.22),
		Vector2(right, bottom - height * 0.30),
		Vector2(right - cut * 0.7, bottom),
		Vector2(left + cut * 0.45, bottom),
		Vector2(left, bottom - height * 0.24),
		Vector2(left, top + height * 0.18)
	])


func _draw() -> void:
	var w := size.x
	var h := size.y
	var alpha := 1.0 if (_hover or _held) else 0.92

	if primary:
		var pulse := 0.55 + 0.20 * sin(_time * 2.4)
		draw_colored_polygon(_shape(w, h, 0.5), Color(GOLD_A.r, GOLD_A.g, GOLD_A.b, 0.22 * pulse))
		var glow := _shape(w, h, 0.5)
		draw_polyline(_closed(glow), Color(GOLD_A.r, GOLD_A.g, GOLD_A.b, 0.35 * pulse), 6.0)

	# خلفية متدرجة يدوياً عبر مثلثات
	var body := _shape(w, h, 3.0)
	if primary:
		var top_color := GOLD_A.lerp(GOLD_EDGE, 0.35)
		var bottom_color := GOLD_B
		_fill_vertical(body, top_color, bottom_color, 1.0)
		draw_polyline(_closed(_shape(w, h, 2.0)), GOLD_EDGE if _hover else Color(1.0, 0.82, 0.42, 0.9), 3.0)
	elif _held or _hover:
		_fill_vertical(body, STEEL.lerp(GOLD_B, 0.30), STEEL.lerp(GOLD_B, 0.12), alpha)
		draw_polyline(_closed(_shape(w, h, 2.0)), GOLD_A, 2.0)
	else:
		_fill_vertical(body, STEEL, Color(0.05, 0.08, 0.12, 0.96), alpha)
		draw_polyline(_closed(_shape(w, h, 2.0)), STEEL_EDGE, 2.0)

	# شريط نحاسي أسفل الزر (تأكيد بصري للحد)
	var y_line := h - 6.0
	draw_line(Vector2(w * 0.12, y_line), Vector2(w * 0.72, y_line),
			Color(1.0, 0.72, 0.30, 0.75 if primary else 0.45), 2.0)

	# سهم صغير في الطرف
	var arrow_color := LABEL_ACTIVE if primary else Color(0.95, 0.72, 0.32, 0.9)
	var ax := w - 34.0
	var ay := h * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax - 10, ay - 10), Vector2(ax + 4, ay), Vector2(ax - 10, ay + 10)
	]), arrow_color)

	var color := LABEL_ACTIVE if primary else LABEL
	var baseline := h * 0.5 + _font_size * 0.34
	draw_string(_font, Vector2(28, baseline), label_text, HORIZONTAL_ALIGNMENT_LEFT,
			w - 80.0, _font_size, color)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out := points.duplicate()
	out.append(points[0])
	return out


func _fill_vertical(points: PackedVector2Array, top_color: Color, bottom_color: Color, alpha: float) -> void:
	if points.size() < 3:
		return
	var min_y := points[0].y
	var max_y := points[0].y
	for point in points:
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	var span := maxf(max_y - min_y, 1.0)
	var top := Color(top_color.r, top_color.g, top_color.b, top_color.a * alpha)
	var bottom := Color(bottom_color.r, bottom_color.g, bottom_color.b, bottom_color.a * alpha)
	var colors := PackedColorArray()
	for point in points:
		var t := clampf((point.y - min_y) / span, 0.0, 1.0)
		colors.append(top.lerp(bottom, t))
	draw_polygon(points, colors)
