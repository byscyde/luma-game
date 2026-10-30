extends TestCase
## Lantern Bay (mirrors & light): rules, solver and every shipped level.


func _levels() -> Array:
	return Game.island_levels("lantern_bay")


func test_mirrors_reflect_both_ways() -> void:
	assert_eq(LightBoard.reflect("/", Vector2i(1, 0)), Vector2i(0, -1), "/ turns an eastward beam north")
	assert_eq(LightBoard.reflect("/", Vector2i(0, 1)), Vector2i(-1, 0), "/ turns a southward beam west")
	assert_eq(LightBoard.reflect("\\", Vector2i(1, 0)), Vector2i(0, 1), "\\ turns an eastward beam south")
	assert_eq(LightBoard.reflect("f\\", Vector2i(0, -1)), Vector2i(-1, 0), "fixed \\ turns a northward beam west")


func test_beam_lights_a_crystal_through_a_mirror() -> void:
	var b := LightBoard.from_dict({"grid": ["LE . \\", ". . .", "C . ."]})
	assert_false(b.solved(), "the beam goes south past the crystal")
	assert_true(b.toggle(Vector2i(2, 0)))
	assert_false(b.solved(), "now it goes north, off the board")
	b = LightBoard.from_dict({"grid": ["LE . \\", ". . .", "C . /"]})
	assert_true(b.solved(), "east, down, then west along the bottom row to the crystal")
	assert_false(b.toggle(Vector2i(0, 0)), "lanterns cannot be tapped")


func test_blooms_must_stay_dark_and_stop_the_beam() -> void:
	var b := LightBoard.from_dict({"grid": ["LE D C"]})
	var t := b.trace()
	assert_eq(int(t["blooms_lit"]), 1)
	assert_false(t["lit"].has(Vector2i(2, 0)), "a bloom stops the beam")
	assert_false(b.solved())


func test_prism_splits_and_rock_stops() -> void:
	var b := LightBoard.from_dict({"grid": [". C .", "LE X #", ". C ."]})
	assert_true(b.solved(), "the prism lights both crystals")
	assert_false(b.trace()["lit"].has(Vector2i(2, 1)), "the beam ends at the prism")
	var loop := LightBoard.from_dict({"grid": ["LE f\\ . C", ". f/ f\\ ."]})
	loop.trace()   # beams that revisit a path terminate
	assert_true(true)


func test_solver_matches_brute_force() -> void:
	var b := LightBoard.from_dict({"grid": [
		"LE . / . \\",
		". C . D .",
		"\\ . / . C",
		". # . . /",
		"/ . \\ . ."]})
	var r := LightSolver.solve(b)
	# brute force over all 2^n mirror states
	var ms := b.mirrors()
	var best := 1 << 30
	var count_states := 0
	for mask in 1 << ms.size():
		var t := b.duplicate_board()
		var flips := 0
		for i in ms.size():
			if mask & (1 << i):
				t.toggle(ms[i])
				flips += 1
		if t.solved():
			count_states += 1
			best = mini(best, flips)
	if count_states == 0:
		assert_eq(r["status"], LightSolver.UNSOLVABLE)
	else:
		assert_eq(r["status"], LightSolver.SOLVED)
		assert_eq(int(r["par"]), best, "solver par is the fewest taps")
		var s := b.duplicate_board()
		s.set_mirror_state(r["state"])
		assert_true(s.solved())


func test_thirty_levels_each_solvable_by_their_stored_solution() -> void:
	var levels := _levels()
	assert_eq(levels.size(), 30)
	var ids := {}
	for lv in levels:
		assert_false(ids.has(lv["id"]), "unique id " + str(lv["id"]))
		ids[lv["id"]] = true
		var b := LightBoard.from_dict(lv)
		assert_eq(b.w, int(lv["w"]), lv["id"])
		assert_false(b.solved(), "%s starts unsolved" % lv["id"])
		var taps: Array = lv["solution"]
		for c in taps:
			assert_true(b.toggle(Vector2i(int(c[0]), int(c[1]))), "%s: tap %s is a round mirror" % [lv["id"], str(c)])
		assert_true(b.solved(), "%s: stored solution lights every crystal" % lv["id"])
		assert_eq(taps.size(), int(lv["par"]), lv["id"])
		var r := LightSolver.solve(LightBoard.from_dict(lv))
		assert_eq(int(r["par"]), int(lv["par"]), "%s: par is the fewest taps" % lv["id"])
		for o in lv["objectives"]["optional"]:
			assert_true(int(o["value"]) >= int(lv["par"]), "%s: move goal is achievable" % lv["id"])


func test_difficulty_rises_across_the_island() -> void:
	var levels := _levels()
	var score := func(a: int, b: int) -> float:
		var s := 0.0
		for i in range(a, b):
			var lb := LightBoard.from_dict(levels[i])
			s += float(levels[i]["par"]) + lb.mirrors().size() * 0.5 + lb.crystals().size() + lb.blooms().size() * 0.5
		return s / (b - a)
	assert_true(score.call(0, 10) < score.call(10, 20), "middle levels are harder than the first ten")
	assert_true(score.call(10, 20) < score.call(20, 30), "last levels are the hardest")
