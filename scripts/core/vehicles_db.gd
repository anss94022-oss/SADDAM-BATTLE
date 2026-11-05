extends Node
## قاعدة بيانات المركبات — data/vehicles/vehicles.json

const DATA_PATH := "res://data/vehicles/vehicles.json"

var vehicles: Dictionary = {}
var order: Array = []


func _ready() -> void:
	load_data()


func load_data() -> bool:
	vehicles.clear()
	order.clear()
	if not FileAccess.file_exists(DATA_PATH):
		push_error("VehiclesDB: missing data")
		return false
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("vehicles"):
		return false

	for entry in parsed["vehicles"]:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var id := String(entry.get("id", ""))
		if id == "":
			continue
		var data: Dictionary = entry.duplicate(true)
		data["max_speed"] = float(data.get("max_speed", 20.0))
		data["reverse_speed"] = float(data.get("reverse_speed", 7.0))
		data["acceleration"] = float(data.get("acceleration", 9.0))
		data["brake"] = float(data.get("brake", 20.0))
		data["turn_rate"] = float(data.get("turn_rate", 1.2))
		data["mass"] = float(data.get("mass", 1500.0))
		data["health"] = float(data.get("health", 250.0))
		data["armor"] = float(data.get("armor", 0.0))
		data["seats"] = maxi(1, int(data.get("seats", 2)))
		data["climb_rate"] = float(data.get("climb_rate", 9.0))
		data["camera_distance"] = float(data.get("camera_distance", 8.0))
		data["camera_height"] = float(data.get("camera_height", 2.6))
		data["engine"] = String(data.get("engine", "engine_car_loop"))
		data["class"] = String(data.get("class", "car"))
		data["name_key"] = String(data.get("name_key", id))
		data["lean_angle"] = float(data.get("lean_angle", 0.0))
		data["mounted_weapon"] = String(data.get("mounted_weapon", ""))
		vehicles[id] = data
		order.append(id)

	return true


func get_vehicle(id: String) -> Dictionary:
	if vehicles.has(id):
		return vehicles[id]
	return {}


func ids_by_class(vehicle_class: String) -> Array:
	var result: Array = []
	for id in order:
		if String(vehicles[id]["class"]) == vehicle_class:
			result.append(id)
	return result


func all_ids() -> Array:
	return order.duplicate()
