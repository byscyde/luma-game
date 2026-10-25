extends TestCase
## End-to-end tests on the real scenes: input events go through BoardView's
## _gui_input exactly as touches/clicks would on a device.

const GAMEPLAY := "res://scenes/gameplay/gameplay.tscn"
const ISLAND := "res://scenes/island/island.tscn"

var screen: Control


func before_each() -> void:
	Router.dry_run = true
	Router.last_request = {}
	Game.reset_progress()
	Game.data["settings"]["reduced_motion"] = true  # keep animations short


func after_each() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	await frames(2)
	Game.data["settings"]["reduced_motion"] = false
	Router.dry_run = false


func _open(path: String, params: Dictionary = {}) -> Control:
	Router.params = params
	screen = (load(path) as PackedScene).instantiate()
	screen.size = Vector2(720, 1280)
	tree.root.add_child(screen)
	await frames(3)
	return screen


func _tap_cell(cell: Vector2i) -> void:
	var bv: BoardView = screen.board_view
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = bv.cell_center(cell)
	bv._gui_input(ev)


func _complete_first_levels(n: int) -> void:
	for i in n:
		var lid: String = Game.content.level_order[i]
		var level := Game.content.get_level(lid)
		if not Game.progression.is_area_unlocked(level.area):
			Game.unlock_area(level.area)
		var b := level.build_board()
		var sol := PuzzleSolver.solve(b)
		for p in sol["taps"]:
			b.tap(p)
		Game.complete_level(level, PuzzleValidator.evaluate(level, b, WaterSimulation.simulate(b), sol["taps"].size()), sol["taps"].size())


func test_first_level_tutorial_to_completion() -> void:
	await _open(GAMEPLAY, {"level_id": "w1_l01"})
	assert_eq(screen.level.id, "w1_l01")
	assert_true(screen._caption_panel.visible, "tutorial caption shown")
	assert_true(screen.board_view._pointer.visible, "pointing hand shown")
	_tap_cell(Vector2i(1, 1))
	assert_eq(screen.moves, 1)
	assert_true(screen.solved, "logical solve is immediate, not tied to animation")
	assert_true(Game.progression.is_completed("w1_l01"), "progress saved on solve")
	assert_true(Game.tutorial.is_done("tap_to_rotate"))
	await tree.create_timer(0.6).timeout
	var overlay := screen.find_child("ResultOverlay", true, false)
	assert_not_null(overlay, "result card shown")
	var cont := screen.find_child("ContinueButton", true, false) as Button
	cont.pressed.emit()
	assert_eq(Router.last_request.get("scene", ""), "island")


func test_input_ignored_on_non_interactive_tiles() -> void:
	await _open(GAMEPLAY, {"level_id": "w1_l01"})
	_tap_cell(Vector2i(0, 1))  # source
	_tap_cell(Vector2i(1, 0))  # rock
	assert_eq(screen.moves, 0, "taps on fixed tiles are not moves")
	assert_false(screen.solved)


func test_undo_and_reset() -> void:
	_complete_first_levels(2)
	await _open(GAMEPLAY, {"level_id": "w1_l03"})
	var t := Vector2i(1, 0)
	var r0: int = screen.board.get_tile(t).rotation
	_tap_cell(t)
	_tap_cell(t)
	assert_eq(screen.moves, 2)
	screen.undo()
	assert_eq(screen.moves, 1)
	assert_eq(screen.board.get_tile(t).rotation, (r0 + 1) % 4)
	screen.reset()
	assert_eq(screen.moves, 0)
	assert_eq(screen.board.get_tile(t).rotation, r0)
	assert_true(screen.history.is_empty())
	assert_true(Game.in_progress_for("w1_l03").is_empty(), "reset clears the resumable state")


func test_hint_points_to_progress() -> void:
	_complete_first_levels(4)
	await _open(GAMEPLAY, {"level_id": "w1_l05"})
	var before := int(PuzzleSolver.solve(screen.board)["moves"])
	screen.hint()
	var hl := Vector2i(-1, -1)
	for c in screen.board_view.views:
		if screen.board_view.views[c].highlight:
			hl = c
	assert_ne(hl, Vector2i(-1, -1), "a tile is highlighted")
	_tap_cell(hl)
	assert_eq(int(PuzzleSolver.solve(screen.board)["moves"]), before - 1)
	assert_eq(screen.hints_used, 1)


func test_full_level_through_input_with_objectives() -> void:
	_complete_first_levels(2)
	await _open(GAMEPLAY, {"level_id": "w1_l03"})
	var sol := PuzzleSolver.solve(screen.board)
	for p in sol["taps"]:
		_tap_cell(p)
	assert_true(screen.solved)
	var rec := Game.progression.level_record("w1_l03")
	assert_eq(int(rec["best_moves"]), int(sol["moves"]))
	assert_eq(Game.progression.optional_met_count("w1_l03"), 1, "move target met with an optimal solve")
	assert_eq(Game.progression.essence(), 10 + 10 + 15)
	assert_has(Game.progression.p["discoveries"], "deco_lantern")


func test_locked_level_redirects_to_island() -> void:
	await _open(GAMEPLAY, {"level_id": "w1_l10"})
	await frames(2)
	assert_eq(Router.last_request.get("scene", ""), "island")


func test_interrupted_level_resumes() -> void:
	_complete_first_levels(2)
	await _open(GAMEPLAY, {"level_id": "w1_l03"})
	_tap_cell(Vector2i(1, 0))
	_tap_cell(Vector2i(2, 2))
	var rots: Array = []
	for t in screen.board.tiles:
		rots.append(t.rotation)
	# simulate the OS suspending the app, then a cold start from disk
	Game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	Game._load()
	screen.queue_free()
	await frames(2)
	await _open(GAMEPLAY, {"level_id": "w1_l03"})
	assert_eq(screen.moves, 2)
	var now: Array = []
	for t in screen.board.tiles:
		now.append(t.rotation)
	assert_eq(now, rots)


func test_progress_survives_restart() -> void:
	_complete_first_levels(5)
	Game.unlock_area("willow_brook")
	Game.save()
	var essence := Game.progression.essence()
	Game._load()  # reload from disk as a fresh launch would
	assert_eq(Game.progression.completed_count(), 5)
	assert_eq(Game.progression.essence(), essence)
	assert_true(Game.progression.is_area_unlocked("willow_brook"))
	assert_true(Game.tutorial.is_complete(), "tutorial not repeated after restart")
	assert_eq(Game.progression.object_stage("glade_rabbits"), 1)


func test_island_plays_restoration_and_matches_save() -> void:
	_complete_first_levels(1)
	var level := Game.content.get_level("w1_l02")
	var b := level.build_board()
	for p in PuzzleSolver.solve(b)["taps"]:
		b.tap(p)
	Game.complete_level(level, PuzzleValidator.evaluate(level, b, WaterSimulation.simulate(b), 1), 1)
	assert_false(Game.pending_receipt.is_empty())
	await _open(ISLAND)
	assert_true(Game.pending_receipt.is_empty(), "receipt consumed")
	await tree.create_timer(1.5).timeout
	var view: IslandView = screen.view
	assert_eq(float(view.display_stage["glade_tree_1"]), 1.0)
	var primary := screen.find_child("PrimaryButton", true, false) as Button
	assert_false(primary.disabled)
	primary.pressed.emit()
	assert_eq(Router.last_request.get("params", {}).get("level_id", ""), "w1_l03")


func test_island_offers_area_unlock() -> void:
	_complete_first_levels(5)
	Game.pending_receipt = {}
	await _open(ISLAND)
	await tree.create_timer(0.3).timeout
	screen._on_area_selected("willow_brook")
	var primary := screen.find_child("PrimaryButton", true, false) as Button
	assert_eq(primary.get_meta("action"), "unlock")
	assert_false(primary.disabled)
	var before := Game.progression.essence()
	primary.pressed.emit()
	await tree.create_timer(0.6).timeout
	assert_true(Game.progression.is_area_unlocked("willow_brook"))
	assert_eq(Game.progression.essence(), before - 40)


func test_every_screen_opens_and_closes_cleanly() -> void:
	for path in ["res://scenes/menus/main_menu.tscn", "res://scenes/menus/collection.tscn",
			"res://scenes/menus/settings.tscn", "res://scenes/island/island.tscn"]:
		await _open(path)
		await frames(2)
		screen.queue_free()
		await frames(2)
	await _open("res://scenes/boot/boot.tscn")
	await tree.create_timer(0.5).timeout
	assert_eq(Router.last_request.get("scene", ""), "gameplay", "first launch goes straight into level 1")


func test_returning_player_boots_to_menu() -> void:
	_complete_first_levels(1)
	var r: Dictionary = load("res://scripts/ui/boot_screen.gd").first_scene()
	assert_eq(r["scene"], "menu")


func test_settings_apply_and_persist() -> void:
	await _open("res://scenes/menus/settings.tscn")
	var t := screen.find_child("Toggle_haptics", true, false) as CheckButton
	t.button_pressed = false
	assert_false(bool(Game.setting("haptics")))
	var s := screen.find_child("Slider_music_volume", true, false) as HSlider
	s.value = 0.0
	assert_true(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")))
	Game._load()
	assert_false(bool(Game.setting("haptics")), "persisted")
	Game.set_setting("music_volume", 0.7)
	Game.set_setting("haptics", true)


func test_reset_progress_requires_confirmation() -> void:
	_complete_first_levels(3)
	await _open("res://scenes/menus/settings.tscn")
	(screen.find_child("ResetProgressButton", true, false) as Button).pressed.emit()
	await frames(1)
	(screen.find_child("ConfirmNo", true, false) as Button).pressed.emit()
	assert_eq(Game.progression.completed_count(), 3, "cancel keeps progress")
	(screen.find_child("ResetProgressButton", true, false) as Button).pressed.emit()
	await frames(1)
	(screen.find_child("ConfirmYes", true, false) as Button).pressed.emit()
	assert_eq(Game.progression.completed_count(), 0)


func test_analytics_whitelists_params_and_respects_opt_out() -> void:
	Analytics.recent.clear()
	Analytics.log_event("level_started", {"level_id": "w1_l01", "email": "x@y.z", "name": "Bob"})
	var ev: Dictionary = Analytics.recent[-1]
	assert_eq(ev["p"].keys(), ["level_id"])
	Game.set_setting("analytics", false)
	Analytics.log_event("level_started", {"level_id": "w1_l02"})
	assert_eq(Analytics.recent.size(), 1, "nothing recorded when opted out")
	Game.set_setting("analytics", true)


func test_licences_screen_shows_engine_licence() -> void:
	await _open("res://scenes/menus/settings.tscn")
	(screen.find_child("LicencesButton", true, false) as Button).pressed.emit()
	await frames(1)
	var overlay := screen.find_child("LicencesOverlay", true, false)
	assert_not_null(overlay)
	var found := false
	for l in overlay.find_children("*", "Label", true, false):
		if (l as Label).text.contains("Godot Engine") and (l as Label).text.contains("Permission is hereby granted"):
			found = true
	assert_true(found, "Godot MIT notice displayed")
	(screen.find_child("CloseLicences", true, false) as Button).pressed.emit()
