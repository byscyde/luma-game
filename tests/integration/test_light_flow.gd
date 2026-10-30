extends TestCase
## Lantern Bay end-to-end: unlocked from the café, played by real taps, progress
## and café coins saved on solve, hints always lead to a solution.

const LIGHT := "res://scenes/islands/light.tscn"

var screen: Control


func before_each() -> void:
	Router.dry_run = true
	Router.last_request = {}
	Game.reset_progress()
	Game.data["settings"]["reduced_motion"] = true


func after_each() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	await frames(2)
	Game.data["settings"]["reduced_motion"] = false
	Router.dry_run = false


func _unlock_bay() -> void:
	for lid in Game.content.level_order:
		Game.progression.p["completed"][lid] = {"best_moves": 1}
	(Game.merge_game().s["tasks_done"] as Array).append("c2_fountain")


func _open(index: int) -> Dictionary:
	var levels := Game.island_levels("lantern_bay")
	for i in index:
		Game.island_progress("lantern_bay")["completed"][levels[i]["id"]] = {"stars": 1}
	var lv: Dictionary = levels[index]
	Router.params = {"level_id": lv["id"]}
	screen = (load(LIGHT) as PackedScene).instantiate()
	screen.size = Vector2(720, 1280)
	tree.root.add_child(screen)
	await frames(3)
	return lv


func _tap(c: Vector2i) -> void:
	var bv: LightBoardView = screen.board_view
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = bv.cell_center(c)
	bv._gui_input(down)
	var emulated := InputEventMouseButton.new()
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	emulated.position = down.position
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	bv._gui_input(emulated)   # the same touch as an emulated click: must be ignored


func test_locked_until_the_cafe_task() -> void:
	assert_false(Game.island_unlocked("lantern_bay"))
	_unlock_bay()
	assert_true(Game.island_unlocked("lantern_bay"))
	assert_true(Game.island_level_unlocked("lantern_bay", 0))
	assert_false(Game.island_level_unlocked("lantern_bay", 1), "levels open in order")


func test_solve_level_one_with_taps() -> void:
	_unlock_bay()
	var lv: Dictionary = await _open(0)
	var coins := int(Game.merge_game().s["coins"])
	for c in lv["solution"]:
		_tap(Vector2i(int(c[0]), int(c[1])))
	assert_true(screen.solved, "every crystal is lit")
	assert_eq(screen.moves, (lv["solution"] as Array).size(), "one tap = one move")
	assert_true((Game.island_progress("lantern_bay")["completed"] as Dictionary).has(lv["id"]), "saved on solve")
	assert_eq(int(Game.merge_game().s["coins"]), coins + int(lv["rewards"]["cafe_coins"]), "pays the café")
	assert_true(Game.island_level_unlocked("lantern_bay", 1))


func test_hints_solve_after_wrong_taps_and_undo_restores() -> void:
	_unlock_bay()
	var lv: Dictionary = await _open(14)
	var lb: LightBoard = screen.lb
	var before := lb.mirror_state()
	var ms := lb.mirrors()
	screen._on_tap(ms[0])
	screen.undo()
	assert_eq(lb.mirror_state(), before, "undo flips the mirror back")
	assert_eq(screen.moves, 0)
	screen._on_tap(ms[ms.size() - 1])
	screen._on_tap(ms[1])
	var guard := 0
	while not screen.solved and guard < 30:
		var c: Vector2i = screen.next_tap()
		assert_true(c != Vector2i(-1, -1), "a hint is always available")
		screen._on_tap(c)
		guard += 1
	assert_true(screen.solved, "following hints always solves the level")
	assert_true((Game.island_progress("lantern_bay")["completed"] as Dictionary).has(lv["id"]))
