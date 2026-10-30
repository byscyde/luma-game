extends TestCase
## Moon Grove end-to-end: unlocked by café chapter 5, played with real swipes,
## progress saved on solve, running out of moves offers a retry.

const MATCH := "res://scenes/islands/match.tscn"

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


func _unlock_grove() -> void:
	for lid in Game.content.level_order:
		Game.progression.p["completed"][lid] = {"best_moves": 1}
	(Game.merge_game().s["tasks_done"] as Array).append("c5_grove")


func _open(index: int) -> Dictionary:
	var levels := Game.island_levels("moon_grove")
	for i in index:
		Game.island_progress("moon_grove")["completed"][levels[i]["id"]] = {"stars": 1}
	var lv: Dictionary = levels[index]
	Router.params = {"level_id": lv["id"]}
	screen = (load(MATCH) as PackedScene).instantiate()
	screen.size = Vector2(720, 1280)
	tree.root.add_child(screen)
	await frames(3)
	return lv


func _swipe(a: Vector2i, b: Vector2i) -> void:
	var bv: MatchBoardView = screen.board_view
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = bv.cell_center(a)
	bv._gui_input(down)
	var drag := InputEventScreenDrag.new()
	drag.position = down.position + Vector2(b - a) * bv.cell_size * 0.7
	bv._gui_input(drag)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = drag.position
	bv._gui_input(up)


func test_locked_until_the_cafe_task() -> void:
	assert_false(Game.island_unlocked("moon_grove"))
	_unlock_grove()
	assert_true(Game.island_unlocked("moon_grove"))


func test_solve_level_one_with_swipes() -> void:
	_unlock_grove()
	var lv: Dictionary = await _open(0)
	for m in lv["solution"]:
		_swipe(Vector2i(int(m[0]), int(m[1])), Vector2i(int(m[2]), int(m[3])))
	assert_true(screen.solved, "the grove's goals are met")
	assert_eq(screen.moves, int(lv["par"]))
	assert_true((Game.island_progress("moon_grove")["completed"] as Dictionary).has(lv["id"]), "saved on solve")


func test_out_of_moves_offers_retry_and_saves_nothing() -> void:
	_unlock_grove()
	var lv: Dictionary = await _open(4)
	var mb: MatchBoard = screen.mb
	mb.moves_left = 1
	var s: Array = mb.all_valid_swaps()[0]
	var won_now := false
	var t := mb.duplicate_board()
	t.swap(s[0], s[1])
	won_now = t.goals_met()
	screen.try_swap(s[0], s[1])
	if not won_now:
		assert_true(screen.failed)
		assert_true(screen.find_child("RetryButton", true, false) != null)
		assert_false((Game.island_progress("moon_grove")["completed"] as Dictionary).has(lv["id"]))


func test_hint_shows_a_playable_swap() -> void:
	_unlock_grove()
	await _open(10)
	screen.hint()
	var pair: Array = screen.board_view.hint_pair
	assert_eq(pair.size(), 2)
	assert_true(screen.mb.valid_swap(pair[0], pair[1]))
