extends TestCase
## Stone Steps (Sokoban): rules, solver and every shipped level.


func _levels() -> Array:
	return Game.island_levels("stone_steps")


func test_walk_push_and_blocked_steps() -> void:
	var b := PushBoard.from_dict({"grid": ["#####", "#@Bo#", "#..B#", "#####"]})
	assert_eq(b.step("E"), "push", "pushes the boulder into the socket")
	assert_true(b.solved())
	assert_eq(b.step("E"), "", "a boulder against a wall does not move")
	assert_eq(b.step("S"), "walk")
	assert_eq(b.player, Vector2i(2, 2))


func test_cannot_push_two_boulders_or_through_walls() -> void:
	var b := PushBoard.from_dict({"grid": ["######", "#@BBo#", "######"]})
	assert_eq(b.step("E"), "", "two boulders in a row are too heavy")
	assert_eq(b.step("N"), "", "walls block")
	assert_eq(b.player, Vector2i(1, 1))


func test_unstep_reverses_a_push() -> void:
	var b := PushBoard.from_dict({"grid": ["#####", "#@B.#", "#..o#", "#####"]})
	var before := b.to_grid()
	assert_eq(b.step("E"), "push")
	b.unstep("E", true)
	assert_eq(b.to_grid(), before)


func test_grid_round_trip_and_sockets_under_things() -> void:
	var g := ["#####", "#+*B#", "#..o#", "#####"]
	var b := PushBoard.from_dict({"grid": g})
	assert_eq(b.to_grid(), g)
	assert_eq(b.filled(), 1)
	assert_false(b.solved())


func test_solver_finds_shortest_solution_and_rejects_dead_ends() -> void:
	var b := PushBoard.from_dict({"grid": ["######", "#@...#", "#.B..#", "#...o#", "######"]})
	var r := PushSolver.solve(b)
	assert_eq(r["status"], PushSolver.SOLVED)
	var t := b.duplicate_board()
	for m in r["moves"]:
		t.step(m)
	assert_true(t.solved())
	assert_eq((r["moves"] as Array).size(), 6, "six steps is the minimum (one push down, two right, three walks)")
	var corner := PushBoard.from_dict({"grid": ["#####", "#B..#", "#.@o#", "#####"]})
	assert_eq(PushSolver.solve(corner)["status"], PushSolver.UNSOLVABLE, "a boulder in a corner is lost")
	assert_false(PushSolver.live_cells(corner).has(Vector2i(1, 1)))


func test_thirty_levels_each_solvable_by_their_stored_solution() -> void:
	var levels := _levels()
	assert_eq(levels.size(), 30)
	var ids := {}
	for lv in levels:
		assert_false(ids.has(lv["id"]), "unique id " + str(lv["id"]))
		ids[lv["id"]] = true
		var b := PushBoard.from_dict(lv)
		assert_eq(b.w, int(lv["w"]), lv["id"])
		assert_eq(b.boulders.size(), b.sockets.size(), "%s: one boulder per socket" % lv["id"])
		assert_false(b.solved(), "%s starts unsolved" % lv["id"])
		for m in lv["solution"]:
			assert_true(b.step(m) != "", "%s: legal step %s" % [lv["id"], m])
		assert_true(b.solved(), "%s: stored solution fills every socket" % lv["id"])
		assert_eq((lv["solution"] as Array).size(), int(lv["par"]), lv["id"])
		for o in lv["objectives"]["optional"]:
			assert_true(int(o["value"]) >= int(lv["par"]), "%s: move goal is achievable" % lv["id"])


func test_early_levels_have_proven_optimal_par() -> void:
	for lv in _levels().slice(0, 8):
		var r := PushSolver.solve(PushBoard.from_dict(lv), 100000)
		assert_eq(r["status"], PushSolver.SOLVED, lv["id"])
		assert_eq((r["moves"] as Array).size(), int(lv["par"]), "%s par is the shortest solution" % lv["id"])


func test_difficulty_rises_across_the_island() -> void:
	var levels := _levels()
	var score := func(a: int, b: int) -> float:
		var s := 0.0
		for i in range(a, b):
			s += float(levels[i]["par"]) + float(levels[i]["pushes"]) + PushBoard.from_dict(levels[i]).boulders.size() * 3.0
		return s / (b - a)
	assert_true(score.call(0, 10) < score.call(10, 20), "middle levels are harder than the first ten")
	assert_true(score.call(10, 20) < score.call(20, 30), "last levels are the hardest")
