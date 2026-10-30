extends TestCase
## Rope Isles (Hashi): rules, solver and every shipped level.


func _levels() -> Array:
	return Game.island_levels("rope_isles")


func test_links_join_nearest_islets_only() -> void:
	var b := BridgeBoard.from_dict({"w": 5, "h": 3, "islands": [[0, 0, 1], [2, 0, 2], [4, 0, 1]]})
	assert_eq(b.links.size(), 2, "the outer islets cannot see past the middle one")
	assert_true(b.link_between(0, 2) == -1)


func test_taps_cycle_and_crossings_block() -> void:
	# a plus shape: a horizontal and a vertical link that cross in the middle
	var b := BridgeBoard.from_dict({"w": 3, "h": 3, "islands": [[0, 1, 1], [2, 1, 1], [1, 0, 1], [1, 2, 1]]})
	var hz := b.link_between(b.island_at(Vector2i(0, 1)), b.island_at(Vector2i(2, 1)))
	var vt := b.link_between(b.island_at(Vector2i(1, 0)), b.island_at(Vector2i(1, 2)))
	assert_true(b.crossings(hz).has(vt))
	assert_true(b.tap(hz))
	assert_eq(b.state[hz], 1)
	assert_false(b.tap(vt), "a bridge cannot cross another")
	assert_true(b.tap(hz))
	assert_eq(b.state[hz], 2)
	assert_true(b.tap(hz))
	assert_eq(b.state[hz], 0, "third tap removes it")
	assert_true(b.tap(vt))


func test_solved_needs_numbers_and_one_group() -> void:
	var b := BridgeBoard.from_dict({"w": 4, "h": 3, "islands": [[0, 0, 1], [2, 0, 1], [0, 2, 1], [2, 2, 1]]})
	b.tap(b.link_between(0, 1))
	b.tap(b.link_between(2, 3))
	assert_eq(b.complete_count(), 4)
	assert_false(b.solved(), "two separate pairs are not one archipelago")


func test_solver_counts_solutions() -> void:
	var unique := BridgeBoard.from_dict({"w": 3, "h": 3, "islands": [[0, 0, 2], [2, 0, 3], [2, 2, 1]]})
	var r := BridgeSolver.solve(unique)
	assert_eq(r["status"], BridgeSolver.SOLVED)
	assert_eq(int(r["solutions"]), 1)
	var ring := BridgeBoard.from_dict({"w": 3, "h": 3, "islands": [[0, 0, 3], [2, 0, 3], [0, 2, 3], [2, 2, 3]]})
	assert_eq(int(BridgeSolver.solve(ring)["solutions"]), 2, "a square of 3s has two answers (doubles across or down)")
	var bad := BridgeBoard.from_dict({"w": 3, "h": 1, "islands": [[0, 0, 1], [2, 0, 2]]})
	assert_eq(BridgeSolver.solve(bad)["status"], BridgeSolver.UNSOLVABLE)


func test_thirty_levels_unique_and_solved_by_their_stored_solution() -> void:
	var levels := _levels()
	assert_eq(levels.size(), 30)
	var ids := {}
	for lv in levels:
		assert_false(ids.has(lv["id"]), "unique id " + str(lv["id"]))
		ids[lv["id"]] = true
		var b := BridgeBoard.from_dict(lv)
		var taps := 0
		for e in lv["solution"]:
			var k := b.link_between(b.island_at(Vector2i(int(e[0]), int(e[1]))), b.island_at(Vector2i(int(e[2]), int(e[3]))))
			assert_true(k >= 0, "%s: solution uses a real link" % lv["id"])
			for n in int(e[4]):
				assert_true(b.tap(k), "%s: bridge can be built" % lv["id"])
				taps += 1
		assert_true(b.solved(), "%s: stored solution joins every islet" % lv["id"])
		assert_eq(taps, int(lv["par"]), lv["id"])
		var r := BridgeSolver.solve(BridgeBoard.from_dict(lv), 2)
		assert_eq(int(r["solutions"]), 1, "%s has exactly one solution" % lv["id"])
		for o in lv["objectives"]["optional"]:
			assert_true(int(o["value"]) >= int(lv["par"]), "%s: move goal is achievable" % lv["id"])


func test_difficulty_rises_across_the_island() -> void:
	var levels := _levels()
	var score := func(a: int, b: int) -> float:
		var s := 0.0
		for i in range(a, b):
			s += (levels[i]["islands"] as Array).size() + float(levels[i]["par"]) * 0.5
		return s / (b - a)
	assert_true(score.call(0, 10) < score.call(10, 20), "middle levels are harder than the first ten")
	assert_true(score.call(10, 20) < score.call(20, 30), "last levels are the hardest")
