class_name ContentDB
extends RefCounted
## Loads world, level, decoration and achievement definitions from JSON.
## Pure data access; no scene dependencies so it can be used by tests and tools.

const WORLDS_DIR := "res://resources/worlds"
const LEVELS_DIR := "res://resources/levels"
const ACHIEVEMENTS_PATH := "res://resources/balance/achievements.json"

var worlds: Array = []             ## world dicts in load order
var levels: Dictionary = {}        ## id -> LevelData
var level_order: Array[String] = []
var areas: Dictionary = {}         ## id -> area dict (with "world")
var area_order: Array[String] = []
var objects: Dictionary = {}       ## id -> object dict
var decorations: Dictionary = {}   ## id -> decoration dict
var decoration_order: Array[String] = []
var achievements: Array = []
var errors: Array[String] = []


static func load_default() -> ContentDB:
	var db := ContentDB.new()
	db.load_all()
	return db


static func read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed


func load_all() -> void:
	var world_files := _list_json(WORLDS_DIR)
	for wf in world_files:
		var w = read_json(WORLDS_DIR.path_join(wf))
		if typeof(w) != TYPE_DICTIONARY:
			errors.append("world file %s is not valid JSON" % wf)
			continue
		worlds.append(w)
		_index_world(w)
	var ach = read_json(ACHIEVEMENTS_PATH)
	if typeof(ach) == TYPE_DICTIONARY:
		achievements = ach.get("achievements", [])
	else:
		errors.append("achievements.json missing or invalid")


func _index_world(w: Dictionary) -> void:
	var wid: String = w.get("id", "")
	for a in w.get("areas", []):
		var area: Dictionary = a.duplicate(true)
		area["world"] = wid
		if areas.has(area["id"]):
			errors.append("duplicate area id %s" % area["id"])
		areas[area["id"]] = area
		area_order.append(area["id"])
		for lid in area.get("levels", []):
			var path := LEVELS_DIR.path_join(wid).path_join(str(lid) + ".json")
			var raw = read_json(path)
			if typeof(raw) != TYPE_DICTIONARY:
				errors.append("level %s missing or invalid JSON at %s" % [lid, path])
				continue
			var level := LevelData.from_dict(raw)
			if level.id != lid:
				errors.append("level file %s declares id %s" % [path, level.id])
			if levels.has(level.id):
				errors.append("duplicate level id %s" % level.id)
			for e in level.errors:
				errors.append("%s: %s" % [lid, e])
			levels[level.id] = level
			level_order.append(level.id)
	for o in w.get("objects", []):
		if objects.has(o["id"]):
			errors.append("duplicate object id %s" % o["id"])
		objects[o["id"]] = o
	for d in w.get("decorations", []):
		if decorations.has(d["id"]):
			errors.append("duplicate decoration id %s" % d["id"])
		decorations[d["id"]] = d
		decoration_order.append(d["id"])


func _list_json(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		errors.append("missing directory %s" % dir_path)
		return out
	for f in d.get_files():
		# Exported builds may list remapped names; only plain JSON is content.
		if f.ends_with(".json"):
			out.append(f)
	out.sort()
	return out


func get_level(id: String) -> LevelData:
	return levels.get(id, null)


func area_of_level(id: String) -> Dictionary:
	var l := get_level(id)
	if l == null:
		return {}
	return areas.get(l.area, {})


func level_number(id: String) -> int:
	return level_order.find(id) + 1


func objects_in_area(area_id: String) -> Array:
	var out: Array = []
	for o in objects.values():
		if o.get("area", "") == area_id:
			out.append(o)
	return out
