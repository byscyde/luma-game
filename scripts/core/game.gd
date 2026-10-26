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
	content = ContentDB.load_default()
	for e in content.errors:
		push_error("Content: " + e)
	store = SaveStore.new(_save_path())
	_load()
	Palette.apply(wants_dark())
	get_tree().root.theme = ThemeBuilder.build()
	if DisplayServer.has_method("set_system_theme_change_callback"):
		DisplayServer.call("set_system_theme_change_callback", refresh_theme)
	_build_fps_overlay()
	data["stats"]["sessions"] = int(data["stats"]["sessions"]) + 1
	apply_settings()
	Analytics.log_event("app_started", {"build": ProjectSettings.get_setting("application/config/version", "")})
	if load_status == SaveStore.STATUS_RECOVERED or load_status == SaveStore.STATUS_RESET:
		Analytics.log_event("save_recovered", {"status": load_status})
	save()
	if "--smoke-test" in OS.get_cmdline_user_args():
		_smoke_test.call_deferred()


## Packaging check used by CI on exported builds: content must load from the
## exported pack, every level must parse and the main scene must exist.
func _smoke_test() -> void:
	var ok := content.errors.is_empty() and content.level_order.size() >= 30 \
		and ResourceLoader.exists("res://scenes/gameplay/gameplay.tscn") \
		and TranslationServer.translate("PLAY") == "Play"
	for lid in content.level_order:
		if not content.get_level(lid).errors.is_empty():
			ok = false
	print("SMOKE_TEST levels=%d errors=%d translated=%s result=%s" % [
		content.level_order.size(), content.errors.size(), TranslationServer.translate("PLAY"), "PASS" if ok else "FAIL"])
	await get_tree().create_timer(1.0).timeout  # let the boot scene run a little
	get_tree().quit(0 if ok else 1)


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
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			# the device theme may have changed while we were in the background
			if data:
				refresh_theme()
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
	if _fps_label:
		_fps_label.visible = bool(data["settings"].get("show_fps", false))
	if get_tree().root.theme:
		refresh_theme()


# ---------------------------------------------------------------- theme

## Dark UI when the player chose it, or when "system" and the device is dark.
func wants_dark() -> bool:
	match str(data["settings"].get("theme", "system")):
		"dark":
			return true
		"light":
			return false
	return DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode()


## Re-themes the UI if the wanted mode changed; the current screen is rebuilt
## (gameplay resumes from its saved in-progress state).
func refresh_theme() -> void:
	var want := wants_dark()
	if want == Palette.dark:
		return
	Palette.apply(want)
	ThemeBuilder.invalidate()
	get_tree().root.theme = ThemeBuilder.build()
	Router.reload()


# ---------------------------------------------------------------- fps overlay

var _fps_label: Label
var _fps_t := 0.0


func _build_fps_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(16, 8)
	_fps_label.add_theme_font_size_override("font_size", 22)
	_fps_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_fps_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_fps_label.add_theme_constant_override("outline_size", 6)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.visible = bool(data["settings"].get("show_fps", false))
	layer.add_child(_fps_label)


func _process(delta: float) -> void:
	if _fps_label and _fps_label.visible:
		_fps_t += delta
		if _fps_t >= 0.5:
			_fps_t = 0.0
			_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


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
