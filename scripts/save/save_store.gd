class_name SaveStore
extends RefCounted
## Versioned local save with atomic writes, a rolling backup and recovery.
##
## Write: serialize -> <path>.tmp -> verify it parses -> current file moves to
## <path>.bak -> tmp renamed to <path>. Load tries <path>, then <path>.bak, and
## only then falls back to a fresh default state. A corrupt file is kept as
## <path>.corrupt for diagnostics instead of being silently destroyed.

const SAVE_VERSION := 1

const STATUS_NEW := "new"
const STATUS_OK := "ok"
const STATUS_RECOVERED := "recovered_backup"
const STATUS_RESET := "reset_corrupt"

var path: String
var last_status: String = ""


func _init(p_path: String = "user://luma_save.json") -> void:
	path = p_path


static func default_data() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"created_at": int(Time.get_unix_time_from_system()),
		"updated_at": 0,
		"progress": {
			"completed": {},
			"essence": 0,
			"essence_earned_total": 0,
			"areas_unlocked": ["spring_glade"],
			"restoration": {},
			"discoveries": [],
			"decor_hidden": [],
			"achievements": [],
			"objective_counts": {},
		},
		"tutorial": {"done": [], "complete": false},
		"in_progress": {},
		"merge": {},
		"islands": {},
		"settings": {
			"music_volume": 0.7,
			"sfx_volume": 0.9,
			"haptics": true,
			"reduced_motion": false,
			"analytics": true,
			"theme": "system",  # system | light | dark
			"show_fps": false,
		},
		"stats": {"sessions": 0, "levels_started": 0},
	}


## Returns the loaded (migrated, defaults-filled) data. Check last_status.
func load_data() -> Dictionary:
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		last_status = STATUS_NEW
		return default_data()
	var main = _read(path)
	if main != null:
		last_status = STATUS_OK
		return normalize(main)
	if FileAccess.file_exists(path):
		_preserve_corrupt(path)
	var bak = _read(path + ".bak")
	if bak != null:
		last_status = STATUS_RECOVERED
		return normalize(bak)
	last_status = STATUS_RESET
	return default_data()


func save_data(data: Dictionary) -> bool:
	data["save_version"] = SAVE_VERSION
	data["updated_at"] = int(Time.get_unix_time_from_system())
	var text := JSON.stringify(data, "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("SaveStore: cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(text)
	f.flush()
	f.close()
	if _read(tmp) == null:
		push_warning("SaveStore: verification of temp save failed")
		return false
	var abs_main := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		var abs_bak := ProjectSettings.globalize_path(path + ".bak")
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(abs_bak)
		DirAccess.rename_absolute(abs_main, abs_bak)
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), abs_main)
	if err != OK:
		push_warning("SaveStore: rename failed: %s" % error_string(err))
		return false
	return true


func delete_all() -> void:
	for suffix in ["", ".bak", ".tmp", ".corrupt"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


## Parses a file; returns Dictionary or null if missing/corrupt/not a save.
func _read(p: String) -> Variant:
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	if text.strip_edges().is_empty():
		return null
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var d = json.data
	if typeof(d) != TYPE_DICTIONARY or not d.has("save_version"):
		return null
	return d


func _preserve_corrupt(p: String) -> void:
	var dst := ProjectSettings.globalize_path(p + ".corrupt")
	if FileAccess.file_exists(p + ".corrupt"):
		DirAccess.remove_absolute(dst)
	DirAccess.rename_absolute(ProjectSettings.globalize_path(p), dst)


## Migrates old versions, fills missing fields from defaults (never dropping
## unknown fields), and repairs invalid values.
static func normalize(src: Dictionary) -> Dictionary:
	var d := migrate(src)
	var merged := _merge_defaults(d, default_data())
	_repair(merged)
	return merged


static func migrate(src: Dictionary) -> Dictionary:
	var d := src.duplicate(true)
	var v := int(d.get("save_version", 1))
	if v < 1:
		v = 1
	# Future schema steps: if v == 1: <upgrade>; v = 2 ...
	# A save from a newer build is kept as-is (fields are preserved).
	d["save_version"] = maxi(v, SAVE_VERSION)
	return d


static func _merge_defaults(d: Dictionary, defaults: Dictionary) -> Dictionary:
	var out := d.duplicate(true)
	for k in defaults:
		if not out.has(k) or typeof(out[k]) != typeof(defaults[k]) and not _both_numbers(out[k], defaults[k]):
			out[k] = defaults[k].duplicate(true) if defaults[k] is Dictionary or defaults[k] is Array else defaults[k]
		elif defaults[k] is Dictionary and not (defaults[k] as Dictionary).is_empty():
			out[k] = _merge_defaults(out[k], defaults[k])
	return out


static func _both_numbers(a, b) -> bool:
	return (typeof(a) == TYPE_INT or typeof(a) == TYPE_FLOAT) and (typeof(b) == TYPE_INT or typeof(b) == TYPE_FLOAT)


static func _repair(d: Dictionary) -> void:
	var p: Dictionary = d["progress"]
	p["essence"] = maxi(0, int(p["essence"]))
	p["essence_earned_total"] = maxi(0, int(p["essence_earned_total"]))
	for key in ["areas_unlocked", "discoveries", "decor_hidden", "achievements"]:
		var seen := {}
		var clean: Array = []
		for v in p[key]:
			if typeof(v) == TYPE_STRING and not seen.has(v):
				seen[v] = true
				clean.append(v)
		p[key] = clean
	if not p["areas_unlocked"].has("spring_glade"):
		p["areas_unlocked"].insert(0, "spring_glade")
	for k in p["restoration"].keys():
		p["restoration"][k] = maxi(0, int(p["restoration"][k]))
	var s: Dictionary = d["settings"]
	s["music_volume"] = clampf(float(s["music_volume"]), 0.0, 1.0)
	s["sfx_volume"] = clampf(float(s["sfx_volume"]), 0.0, 1.0)
