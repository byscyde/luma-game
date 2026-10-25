extends Node
## Visual QA tour: drives the real game through its screens and saves
## screenshots from actual engine renders (not mockups).
##   xvfb-run godot --path . --resolution 720x1280 res://tools/screenshot_tour.tscn -- --save-path=user://tour.json [--out=dir]
## Requires a rendering-capable display (e.g. Xvfb + Mesa); not for --headless.

var out_dir := "res://build/screenshots"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	# Detach from the current scene so scene changes don't free the tour.
	await get_tree().process_frame
	var placeholder := Node.new()
	get_tree().root.add_child(placeholder)
	get_tree().current_scene = placeholder
	Game.reset_progress()
	await _wait(0.5)
	# 1. First-time experience: level 1 with the tutorial pointer
	await _go("gameplay", {"level_id": "w1_l01"}, 1.2)
	await _shot("01_tutorial_level1")
	await _solve_current(true)
	await _wait(2.4)
	await _shot("02_level1_result")
	# 2. Island restoration after level 1
	_press("ResultOverlay", "ContinueButton")
	await _wait(2.8)
	await _shot("03_island_restoring")
	# 3. A mid-game board with gates and mixed water
	_complete_through(22)
	await _go("gameplay", {"level_id": "w1_l23"}, 1.0)
	await _partial_solve(6)
	await _wait(1.0)
	await _shot("04_gates_level23")
	_complete_through(26)
	await _go("gameplay", {"level_id": "w1_l27"}, 1.0)
	await _partial_solve(9)
	await _wait(1.2)
	await _shot("05_cross_bonus_level27")
	# 4. Island with several areas restored
	await _go("island", {}, 1.5)
	await _shot("06_island_midgame")
	await _go("menu", {}, 1.5)
	await _shot("07_main_menu")
	await _go("collection", {}, 1.0)
	await _shot("08_collection")
	await _go("settings", {}, 1.0)
	await _shot("09_settings")
	_complete_through(30)
	for a in Game.content.area_order:
		Game.progression.unlock_area(a)
	_complete_through(30)
	await _go("island", {}, 2.0)
	await _shot("10_island_restored")
	print("screenshots written to ", ProjectSettings.globalize_path(out_dir))
	get_tree().quit(0)


func _complete_through(n: int) -> void:
	# Plays levels for real through the progression rules (solver solutions).
	for i in n:
		var lid: String = Game.content.level_order[i]
		var level := Game.content.get_level(lid)
		if Game.progression.is_completed(lid):
			continue
		if not Game.progression.is_area_unlocked(level.area):
			if not Game.progression.unlock_area(level.area):
				return
		var board := level.build_board()
		var sol := PuzzleSolver.solve(board, 400000, PuzzleSolver.GOAL_NO_LEAKS if level.has_optional(LevelData.OBJ_NO_LEAKS) else PuzzleSolver.GOAL_WITH_BONUS)
		if sol["status"] != PuzzleSolver.STATUS_SOLVED:
			sol = PuzzleSolver.solve(board)
		for p in sol["taps"]:
			board.tap(p)
		var sim := WaterSimulation.simulate(board)
		Game.complete_level(level, PuzzleValidator.evaluate(level, board, sim, sol["taps"].size()), sol["taps"].size())
	Game.pending_receipt = {}


func _scene() -> Node:
	return get_tree().current_scene


func _solve_current(all: bool) -> void:
	var s := _scene()
	var sol := PuzzleSolver.solve(s.board)
	for p in sol["taps"]:
		s._on_tile_tapped(p)
		await _wait(0.25)
	if not all:
		return


func _partial_solve(n: int) -> void:
	var s := _scene()
	var sol := PuzzleSolver.solve(s.board)
	var taps: Array = sol["taps"]
	for i in mini(n, taps.size() - 1):
		s._on_tile_tapped(taps[i])
		await _wait(0.12)


func _press(parent_name: String, button_name: String) -> void:
	var b := _scene().find_child(button_name, true, false) as Button
	if b:
		b.pressed.emit()


func _go(scene: String, params: Dictionary, settle: float) -> void:
	Router.go(scene, params)
	await _wait(settle)


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(out_dir.path_join(name + ".png"))
	img.save_png(path)
	print("saved ", path)
