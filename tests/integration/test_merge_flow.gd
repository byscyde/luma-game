extends TestCase
## Merge mode end-to-end on the real scene: input goes through MergeBoardView
## exactly as touches would on a device.

const MERGE := "res://scenes/merge/merge.tscn"

var screen: Control


func before_each() -> void:
	Router.dry_run = true
	Router.last_request = {}
	Router.params = {}
	Game.reset_progress()
	Game.data["merge"] = {"intro_seen": true}
	Game.data["merge"].erase("intro_seen")
	Game._bind()
	Game.merge_game()
	Game.data["merge"]["intro_seen"] = true
	Game.data["settings"]["reduced_motion"] = true


func after_each() -> void:
	if is_instance_valid(screen):
		screen.queue_free()
	await frames(2)
	Game.data["settings"]["reduced_motion"] = false
	Router.dry_run = false


func _open() -> void:
	screen = (load(MERGE) as PackedScene).instantiate()
	screen.size = Vector2(720, 1280)
	tree.root.add_child(screen)
	await frames(3)


func _touch(c: Vector2i, pressed: bool) -> void:
	var bv: MergeBoardView = screen.board_view
	var ev := InputEventScreenTouch.new()
	ev.index = 0
	ev.pressed = pressed
	ev.position = bv.cell_center(c)
	bv._gui_input(ev)


func _drag(from: Vector2i, to: Vector2i) -> void:
	var bv: MergeBoardView = screen.board_view
	_touch(from, true)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = bv.cell_center(to)
	bv._gui_input(d)
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = bv.cell_center(to)
	bv._gui_input(up)


func _clear(g: MergeGame) -> void:
	for i in (g.s["board"] as Array).size():
		g.s["board"][i] = null


func test_unlocks_only_after_the_last_level() -> void:
	assert_false(Game.merge_unlocked())
	for lid in Game.content.level_order:
		Game.progression.p["completed"][lid] = {"best_moves": 1}
	assert_true(Game.merge_unlocked())


func test_tap_generator_through_touch() -> void:
	await _open()
	var g: MergeGame = screen.game
	var e := g.energy(int(Time.get_unix_time_from_system()))
	var free := g.free_cells()
	_touch(Vector2i(3, 4), true)
	_touch(Vector2i(3, 4), false)
	assert_eq(g.free_cells(), free - 1, "an item appeared")
	assert_eq(g.energy(int(Time.get_unix_time_from_system())), e - 1)
	# an emulated mouse click for the same touch must not tap again
	var em := InputEventMouseButton.new()
	em.device = InputEvent.DEVICE_ID_EMULATION
	em.button_index = MOUSE_BUTTON_LEFT
	em.pressed = true
	em.position = screen.board_view.cell_center(Vector2i(3, 4))
	screen.board_view._gui_input(em)
	assert_eq(g.free_cells(), free - 1)


func test_drag_merges_two_items() -> void:
	await _open()
	var g: MergeGame = screen.game
	_clear(g)
	g.s["board"][g.idx(Vector2i(0, 2))] = {"id": "coffee:1"}
	g.s["board"][g.idx(Vector2i(4, 6))] = {"id": "coffee:1"}
	_drag(Vector2i(0, 2), Vector2i(4, 6))
	assert_eq(g.at(Vector2i(4, 6))["id"], "coffee:2")
	assert_true(g.at(Vector2i(0, 2)) == null)
	assert_eq(screen.board_view.selected, Vector2i(4, 6), "result is selected")


func test_serve_button_pays_the_order() -> void:
	await _open()
	var g: MergeGame = screen.game
	_clear(g)
	var o: Dictionary = g.orders()[0]
	for i in (o["items"] as Array).size():
		g.s["board"][i] = {"id": o["items"][i]}
	screen._refresh()
	await frames(1)
	var b := screen.find_child("Serve0", true, false) as Button
	assert_not_null(b, "serve button shown when the order can be filled")
	var coins := int(g.s["coins"])
	b.pressed.emit()
	assert_eq(int(g.s["coins"]), coins + int(o["coins"]))


func test_task_plays_story_and_saves() -> void:
	await _open()
	var g: MergeGame = screen.game
	g.s["coins"] = 1000
	screen._refresh()
	(screen.find_child("TasksButton", true, false) as Button).pressed.emit()
	await frames(1)
	var t := screen.find_child("Task_c1_debris", true, false) as Button
	assert_not_null(t)
	assert_false(t.disabled)
	t.pressed.emit()
	await frames(1)
	var dlg = screen.find_child("Dialogue", true, false)
	assert_not_null(dlg, "story scene shown")
	assert_true((g.s["tasks_done"] as Array).has("c1_debris"))
	for i in 10:
		if not is_instance_valid(dlg) or dlg.is_queued_for_deletion():
			break
		var ev := InputEventScreenTouch.new()
		ev.pressed = true
		dlg._gui_input(ev)
	await frames(1)
	Game._load()
	assert_true((Game.data["merge"]["tasks_done"] as Array).has("c1_debris"), "saved")


func test_sell_and_store_from_the_info_bar() -> void:
	await _open()
	var g: MergeGame = screen.game
	_clear(g)
	g.s["board"][0] = {"id": "bakery:3"}
	_touch(Vector2i(0, 0), true)
	_touch(Vector2i(0, 0), false)
	assert_eq(screen.board_view.selected, Vector2i(0, 0))
	assert_true(g.store(Vector2i(0, 0)))
	assert_eq(g.inventory().size(), 1)
