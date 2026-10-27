extends TestCase
## Stone Steps end-to-end: unlocked from the café, played by real swipes and
## taps, progress saved on solve, undo restores, hints lead to a solution.

const PUSH := "res://scenes/islands/push.tscn"

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


func _unlock_steps() -> void:
	for lid in Game.content.level_order:
		Game.progression.p["completed"][lid] = {"best_moves": 1}
	(Game.merge_game().s["tasks_done"] as Array).append("c3_festival")


func _open(index: int) -> Dictionary:
	var levels := Game.island_levels("stone_steps")
	for i in index:
		Game.island_progress("stone_steps")["completed"][levels[i]["id"]] = {"stars": 1}
	var lv: Dictionary = levels[index]
	Router.params = {"level_id": lv["id"]}
	screen = (load(PUSH) as PackedScene).instantiate()
	screen.size = Vector2(720, 1280)
	tree.root.add_child(screen)
	await frames(3)
	return lv


func _swipe(dir: String) -> void:
	var bv: PushBoardView = screen.board_view
	var p := bv.cell_center(screen.pb.player)
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = p
	bv._gui_input(down)
	var drag := InputEventScreenDrag.new()
	drag.position = p + Vector2(PushBoard.DIRS[dir]) * bv.cell_size * 0.7
	bv._gui_input(drag)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = drag.position
	bv._gui_input(up)


func test_locked_until_the_cafe_task() -> void:
	assert_false(Game.island_unlocked("stone_steps"))
	_unlock_steps()
	assert_true(Game.island_unlocked("stone_steps"))
	assert_false(Game.island_level_unlocked("stone_steps", 1), "levels open in order")


func test_solve_level_one_with_swipes() -> void:
	_unlock_steps()
	var lv: Dictionary = await _open(0)
	var coins := int(Game.merge_game().s["coins"])
	for d in lv["solution"]:
		_swipe(d)
	assert_true(screen.solved, "every socket holds a boulder")
	assert_eq(screen.moves, (lv["solution"] as Array).size())
	assert_true((Game.island_progress("stone_steps")["completed"] as Dictionary).has(lv["id"]), "saved on solve")
	assert_eq(int(Game.merge_game().s["coins"]), coins + int(lv["rewards"]["cafe_coins"]), "pays the café")


func test_tap_walks_and_undo_restores_the_whole_walk() -> void:
	_unlock_steps()
	await _open(3)
	var pb: PushBoard = screen.pb
	var paths := pb.walk_paths()
	var far := pb.player
	for c in paths:
		if (paths[c] as Array).size() > (paths[far] as Array).size():
			far = c
	var bv: PushBoardView = screen.board_view
	var tap := InputEventScreenTouch.new()
	tap.pressed = true
	tap.position = bv.cell_center(far)
	bv._gui_input(tap)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = tap.position
	bv._gui_input(up)
	assert_eq(pb.player, far, "a tap walks to a reachable cell")
	assert_eq(screen.moves, (paths[far] as Array).size(), "each step counts")
	screen.undo()
	assert_eq(screen.moves, 0)
	assert_eq(pb.to_grid(), PushBoard.from_dict(Game.island_levels("stone_steps")[3]).to_grid(), "undo takes back the whole walk")


func test_hints_solve_after_wrong_moves() -> void:
	_unlock_steps()
	var lv: Dictionary = await _open(9)
	var first: String = lv["solution"][0]
	for d in PushBoard.DIRS:
		if d != first and screen.do_steps([d]) > 0:
			break
	var guard := 0
	while not screen.solved and guard < 200:
		var d: String = screen.next_step()
		if d == "":
			screen.undo()
		else:
			screen.do_steps([d])
		guard += 1
	assert_true(screen.solved, "following hints (and undo when stuck) always solves the level")
