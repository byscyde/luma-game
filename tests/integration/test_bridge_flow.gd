extends TestCase
## Rope Isles end-to-end: unlocked by the café's chapter 4 ferry, played with
## real drags, progress saved on solve, undo and hints work.

const BRIDGES := "res://scenes/islands/bridges.tscn"

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


func _unlock_isles() -> void:
	for lid in Game.content.level_order:
		Game.progression.p["completed"][lid] = {"best_moves": 1}
	(Game.merge_game().s["tasks_done"] as Array).append("c4_ferry")


func _open(index: int) -> Dictionary:
	var levels := Game.island_levels("rope_isles")
	for i in index:
		Game.island_progress("rope_isles")["completed"][levels[i]["id"]] = {"stars": 1}
	var lv: Dictionary = levels[index]
	Router.params = {"level_id": lv["id"]}
	screen = (load(BRIDGES) as PackedScene).instantiate()
	screen.size = Vector2(720, 1280)
	tree.root.add_child(screen)
	await frames(3)
	return lv


func _drag(from: Vector2i, to: Vector2i) -> void:
	var bv: BridgeBoardView = screen.board_view
	var p := bv.cell_center(from)
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = p
	bv._gui_input(down)
	var drag := InputEventScreenDrag.new()
	drag.position = p + Vector2(to - from).normalized() * bv.cell_size * 0.6
	bv._gui_input(drag)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = drag.position
	bv._gui_input(up)


func test_locked_until_the_ferry_task() -> void:
	assert_false(Game.island_unlocked("rope_isles"))
	_unlock_isles()
	assert_true(Game.island_unlocked("rope_isles"))
	assert_false(Game.island_level_unlocked("rope_isles", 1))


func test_solve_level_one_with_drags() -> void:
	_unlock_isles()
	var lv: Dictionary = await _open(0)
	for e in lv["solution"]:
		for n in int(e[4]):
			_drag(Vector2i(int(e[0]), int(e[1])), Vector2i(int(e[2]), int(e[3])))
	assert_true(screen.solved, "all islets joined")
	assert_eq(screen.moves, int(lv["par"]))
	assert_true((Game.island_progress("rope_isles")["completed"] as Dictionary).has(lv["id"]), "saved on solve")


func test_undo_and_hints_after_wrong_bridges() -> void:
	_unlock_isles()
	await _open(12)
	var bb: BridgeBoard = screen.bb
	for k in bb.links.size():
		if screen._goal[k] == 0 and bb.link_free(k):
			screen._on_tap(k)
			break
	screen._on_tap(0)
	screen.undo()
	assert_eq(screen.moves, 1, "undo takes back one tap")
	var guard := 0
	while not screen.solved and guard < 200:
		var k: int = screen.next_tap()
		assert_true(k >= 0, "a hint is always available")
		screen._on_tap(k)
		guard += 1
	assert_true(screen.solved, "following hints solves the level")
