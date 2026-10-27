extends TestCase
## Ember Reef end-to-end: unlocked from the café, played by real swipes,
## progress and café coins saved on solve.

const SLIDE := "res://scenes/islands/slide.tscn"

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


func _unlock_reef() -> void:
	for lid in Game.content.level_order:
		Game.progression.p["completed"][lid] = {"best_moves": 1}
	(Game.merge_game().s["tasks_done"] as Array).append("c1_open")


func _swipe(m: Array) -> void:
	var bv: SlideBoardView = screen.board_view
	var cell := Vector2i(int(m[1]) + 1, 1) if m[0] == "c" else Vector2i(1, int(m[1]) + 1)
	var p := bv.cell_center(cell)
	var dvec := Vector2(int(m[2]), 0) if m[0] == "r" else Vector2(0, int(m[2]))
	var down := InputEventScreenTouch.new()
	down.pressed = true
	down.position = p
	bv._gui_input(down)
	var drag := InputEventScreenDrag.new()
	drag.position = p + dvec * bv.cell_size * 0.8
	bv._gui_input(drag)
	var up := InputEventScreenTouch.new()
	up.pressed = false
	up.position = drag.position
	bv._gui_input(up)


func test_locked_until_the_cafe_task() -> void:
	assert_false(Game.island_unlocked("ember_reef"))
	_unlock_reef()
	assert_true(Game.island_unlocked("ember_reef"))
	assert_true(Game.island_level_unlocked("ember_reef", 0))
	assert_false(Game.island_level_unlocked("ember_reef", 1), "levels open in order")


func test_solve_level_one_with_swipes() -> void:
	_unlock_reef()
	var lv: Dictionary = Game.island_levels("ember_reef")[0]
	Router.params = {"level_id": lv["id"]}
	screen = (load(SLIDE) as PackedScene).instantiate()
	screen.size = Vector2(720, 1280)
	tree.root.add_child(screen)
	await frames(3)
	var coins := int(Game.merge_game().s["coins"])
	for m in lv["solution"]:
		_swipe(m)
	assert_true(screen.solved, "water reaches every sapling")
	assert_eq(screen.moves, (lv["solution"] as Array).size())
	assert_true((Game.island_progress("ember_reef")["completed"] as Dictionary).has(lv["id"]), "saved on solve")
	assert_eq(int(Game.merge_game().s["coins"]), coins + int(lv["rewards"]["cafe_coins"]), "pays the café")
	assert_true(Game.island_level_unlocked("ember_reef", 1))


func test_hint_follows_a_valid_plan_after_wrong_moves() -> void:
	_unlock_reef()
	var lv: Dictionary = Game.island_levels("ember_reef")[5]
	for i in 5:
		Game.island_progress("ember_reef")["completed"][Game.island_levels("ember_reef")[i]["id"]] = {"stars": 1}
	Router.params = {"level_id": lv["id"]}
	screen = (load(SLIDE) as PackedScene).instantiate()
	screen.size = Vector2(720, 1280)
	tree.root.add_child(screen)
	await frames(3)
	var sb: SlideBoard = screen.sb
	var wrong: Array = sb.legal_moves()[0]
	if wrong == lv["solution"][0]:
		wrong = sb.legal_moves()[1]
	screen._on_slide(wrong)
	screen._on_slide(sb.legal_moves()[3])
	var guard := 0
	while not screen.solved and guard < 40:
		screen._on_slide(screen.plan[0])
		guard += 1
	assert_true(screen.solved, "following the hint plan always solves the level")
	screen.undo()
	assert_true(screen.solved, "no undo after solving")
