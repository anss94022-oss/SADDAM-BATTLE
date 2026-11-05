extends Node
## الترجمة: العربية (RTL) والإنجليزية (LTR) — تعمل دون إنترنت.

signal language_changed(code: String)

const SUPPORTED := ["ar", "en"]
const FALLBACK := "en"

var language := "ar"

var _tables: Dictionary = {}
var _rtl := true


func _ready() -> void:
	_load_table("ar")
	_load_table("en")
	var saved := "ar"
	if FileAccess.file_exists("user://saddam_battle_settings.json"):
		var file := FileAccess.open("user://saddam_battle_settings.json", FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			file.close()
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("language"):
				saved = String(parsed["language"])
	set_language(saved, false)


func _load_table(code: String) -> void:
	var path := "res://data/i18n/%s.json" % code
	if not FileAccess.file_exists(path):
		push_error("Locale: missing table %s" % path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_tables[code] = parsed


func set_language(code: String, notify: bool = true) -> void:
	if not _tables.has(code):
		code = FALLBACK
	language = code
	_rtl = bool(String(_tables.get(code, {}).get("ui_rtl", "false")) == "true")
	if notify:
		language_changed.emit(code)


func is_rtl() -> bool:
	return _rtl


func current_table() -> Dictionary:
	return _tables.get(language, {})


## ترجمة نص حسب المفتاح، مع دعم تنسيق المعاملات.
func t(key: String, ...args: Array) -> String:
	var table: Dictionary = _tables.get(language, {})
	var text := String(table.get(key, ""))
	if text == "":
		table = _tables.get(FALLBACK, {})
		text = String(table.get(key, key))
	if args.size() > 0:
		return text % args
	return text


## اسم مترجم لمفتاح قد يكون مفتاحاً مباشراً أو نصاً حراً.
func name_of(key: String) -> String:
	if key.begins_with("m") or key.begins_with("w_") or key.begins_with("v_") \
		or key.begins_with("e_") or key.begins_with("ach_") or key.begins_with("menu_"):
		return t(key)
	return key


func apply_direction(control: Control) -> void:
	control.layout_direction = Control.LAYOUT_DIRECTION_RTL if _rtl else Control.LAYOUT_DIRECTION_LTR
	for child in control.get_children():
		if child is Control:
			apply_direction(child)


func get_language_names() -> Array:
	var names: Array = []
	for code in SUPPORTED:
		names.append(String(_tables.get(code, {}).get("lang_name", code)))
	return names
