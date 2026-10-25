extends Node
## Game autoload: owns content, the save, progression and settings, and is the
## single place that persists state. Scenes talk to it; it never talks to scenes
## except through signals.

signal essence_changed(value: int)
signal settings_changed
signal progress_reset

var content: ContentDB
var store: SaveStore
var data: Dictionary
var progression: ProgressionModel
var tutorial: TutorialModel
var load_status := ""

## Set when a level is completed; the island scene consumes it to animate.
var pending_receipt: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = ThemeBuilder.build()
	content = ContentDB.load_default()
	for e in content.errors:
		push_error("Content: " + e)
	store = SaveStore.new(_save_path())
	_load()
	data["stats"]["sessions"] = int(data["stats"]["sessions"]) + 1
	apply_settings()
	Analytics.log_event("app_started", {"build": ProjectSettings.get_setting("application/config/version", "")})
	if load_status == SaveStore.STATUS_RECOVERED or load_status == SaveStore.STATUS_RESET:
		Analytics.log_event("save_recovered", {"status": load_status})
	save()


func _save_path() -> String:
	# Tests and tools may redirect the save with --save-path=user://x.json
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--save-path="):
			return a.substr(12)
	return "user://luma_save.json"


func _load() -> void:
	data = store.load_data()
	load_status = store.last_status
	_bind()


func _bind() -> void:
	progression = ProgressionModel.new(content, data["progress"])
	tutorial = TutorialModel.new(data["tutorial"])


func save() -> bool:
	return store.save_data(data)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if data:
				save()
		NOTIFICATION_PREDELETE:
			pass
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Analytics.log_event("session_ended", {"session_s": Analytics.session_seconds()})


# ---------------------------------------------------------------- settings

func setting(key: String):
	return data["settings"].get(key)


func set_setting(key: String, value) -> void:
	data["settings"][key] = value
	apply_settings()
	save()
	settings_changed.emit()


func apply_settings() -> void:
	Analytics.enabled = bool(data["settings"]["analytics"])
	Audio.apply_volumes(float(data["settings"]["music_volume"]), float(data["settings"]["sfx_volume"]))


func reduced_motion() -> bool:
	return bool(data["settings"]["reduced_motion"])


func haptic(ms: int = 12) -> void:
	if bool(data["settings"]["haptics"]):
		PlatformServices.vibrate(ms)


# ---------------------------------------------------------------- gameplay

func level_started(level_id: String) -> void:
	data["stats"]["levels_started"] = int(data["stats"]["levels_started"]) + 1
	var level := content.get_level(level_id)
	if level and level.tutorial == TutorialModel.ONBOARDING[0] and not tutorial.is_done(level.tutorial):
		Analytics.log_event("tutorial_started", {"level_id": level_id})
	Analytics.log_event("level_started", {"level_id": level_id})


## Called by gameplay once the logical puzzle is solved.
func complete_level(level: LevelData, evaluation: Dictionary, moves: int, extra: Dictionary = {}) -> Dictionary:
	var was_complete := tutorial.is_complete()
	var receipt := progression.apply_level_result(level, evaluation, moves)
	if level.tutorial != "":
		tutorial.mark_done(level.tutorial)
	if not was_complete and tutorial.is_complete():
		Analytics.log_event("tutorial_completed", {"level_id": level.id})
	clear_in_progress()
	pending_receipt = receipt
	var params := {"level_id": level.id, "moves": moves, "par": level.par_moves,
		"optional_met": int(evaluation.get("optional_met", 0))}
	params.merge(extra)
	Analytics.log_event("level_completed", params)
	for d in receipt["discoveries"]:
		Analytics.log_event("decoration_unlocked", {"decoration_id": d})
	for a in receipt["achievements"]:
		Analytics.log_event("achievement_unlocked", {"achievement_id": a})
		PlatformServices.report_achievement(a)
	if not receipt["restoration"].is_empty() and progression.area_restored(level.area):
		Analytics.log_event("island_restoration_completed", {"area_id": level.area})
	save()
	essence_changed.emit(progression.essence())
	return receipt


func unlock_area(area_id: String) -> bool:
	if progression.unlock_area(area_id):
		var ach := progression.check_achievements()
		for a in ach:
			Analytics.log_event("achievement_unlocked", {"achievement_id": a})
		Analytics.log_event("area_unlocked", {"area_id": area_id})
		save()
		essence_changed.emit(progression.essence())
		return true
	return false


func set_decoration_visible(id: String, v: bool) -> void:
	progression.set_decoration_visible(id, v)
	save()


## Mid-level state so an interrupted puzzle resumes where it was.
func store_in_progress(level_id: String, board: PuzzleBoard, moves: int) -> void:
	var snap := board.snapshot()
	data["in_progress"] = {
		"level": level_id,
		"rotations": Array(snap["rotations"]),
		"switches": snap["switches"],
		"moves": moves,
	}


func in_progress_for(level_id: String) -> Dictionary:
	var ip: Dictionary = data.get("in_progress", {})
	if ip.get("level", "") == level_id:
		return ip
	return {}


func clear_in_progress() -> void:
	data["in_progress"] = {}


func reset_progress() -> void:
	var settings: Dictionary = data["settings"].duplicate(true)
	data = SaveStore.default_data()
	data["settings"] = settings
	_bind()
	pending_receipt = {}
	save()
	essence_changed.emit(0)
	progress_reset.emit()
