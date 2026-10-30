extends TestCase
## Moon Grove (match-3): rules, determinism and every shipped level.

const SMALL := {"w": 5, "h": 5, "kinds": 4, "seed": 7,
	"grid": ["0 1 2 3 0", "1 0 3 0 1", "2 3 1 2 3", "3 2 0 1 2", "0 1 3 2 0"],
	"moss": ["00000", "00000", "00000", "00100", "00000"], "goals": {"moss": true}, "moves": 10}


func _levels() -> Array:
	return Game.island_levels("moon_grove")


func test_only_matching_swaps_are_moves() -> void:
	var b := MatchBoard.from_dict(SMALL)
	assert_false(b.swap(Vector2i(0, 0), Vector2i(2, 0)), "not neighbours")
	assert_false(b.swap(Vector2i(0, 0), Vector2i(1, 0)), "no match: nothing happens")
	assert_eq(b.moves_left, 10)
	var swaps := b.all_valid_swaps()
	assert_true(swaps.size() > 0)
	for s in swaps:
		assert_true(b.valid_swap(s[0], s[1]))
	assert_true(b.swap(swaps[0][0], swaps[0][1]))
	assert_eq(b.moves_left, 9)
	assert_true(b.find_runs().is_empty(), "the board settles with no matches left")
	for v in b.cells:
		assert_true(v >= 0, "every cell refilled")


func test_runs_make_specials() -> void:
	var b := MatchBoard.from_dict({"w": 5, "h": 3, "kinds": 4, "seed": 3,
		"grid": ["1 1 0 1 2", "2 3 1 3 3", "3 2 2 0 1"], "goals": {}, "moves": 5})
	assert_true(b.swap(Vector2i(2, 0), Vector2i(2, 1)), "1 1 1 1 in the top row")
	var made: Array = b.last_events[0]["made"]
	assert_eq(made.size(), 1)
	assert_eq(int(made[0][1]), MatchBoard.LINE_H, "a horizontal four makes a row lantern")
	assert_eq(made[0][0], Vector2i(2, 0), "it appears where the flower was swapped in")


func test_moss_fades_one_layer_per_match() -> void:
	var b := MatchBoard.from_dict({"w": 3, "h": 3, "kinds": 3, "seed": 1,
		"grid": ["0 1 2", "1 0 1", "2 2 0"], "moss": ["000", "020", "000"], "goals": {"moss": true}, "moves": 5})
	assert_eq(b.moss_left(), 2)
	b._clear_cells([Vector2i(1, 1)], [])
	assert_eq(b.moss_left(), 1, "thick moss needs two matches")
	assert_false(b.goals_met())


func test_same_swaps_replay_identically() -> void:
	var a := MatchBoard.from_dict(_levels()[5])
	var b := MatchBoard.from_dict(_levels()[5])
	for i in 4:
		var s := MatchBot.best_swap(a)
		a.swap(s[0], s[1])
		b.swap(s[0], s[1])
	assert_eq(a.cells, b.cells, "refills come from the level's own seed")
	assert_eq(a.moss, b.moss)


func test_thirty_levels_won_by_their_stored_solution() -> void:
	var levels := _levels()
	assert_eq(levels.size(), 30)
	var ids := {}
	for lv in levels:
		assert_false(ids.has(lv["id"]), "unique id " + str(lv["id"]))
		ids[lv["id"]] = true
		var b := MatchBoard.from_dict(lv)
		assert_true(b.find_runs().is_empty(), "%s starts with no ready matches" % lv["id"])
		assert_false(b.goals_met(), "%s starts unsolved" % lv["id"])
		for m in lv["solution"]:
			assert_true(b.swap(Vector2i(int(m[0]), int(m[1])), Vector2i(int(m[2]), int(m[3]))), "%s: legal swap %s" % [lv["id"], str(m)])
		assert_true(b.goals_met(), "%s: stored solution meets every goal" % lv["id"])
		assert_true(b.moves_left >= 0)
		assert_eq((lv["solution"] as Array).size(), int(lv["par"]), lv["id"])
		assert_true(int(lv["moves"]) >= int(lv["par"]), "%s: the move limit allows the solution" % lv["id"])
		for o in lv["objectives"]["optional"]:
			assert_true(int(o["value"]) >= int(lv["par"]), "%s: move goal is achievable" % lv["id"])


func test_difficulty_rises_across_the_island() -> void:
	var levels := _levels()
	var score := func(a: int, b: int) -> float:
		var s := 0.0
		for i in range(a, b):
			s += float(levels[i]["par"]) + MatchBoard.from_dict(levels[i]).moss_left() * 0.5 + int(levels[i]["kinds"])
		return s / (b - a)
	assert_true(score.call(0, 10) < score.call(10, 20), "middle levels are harder than the first ten")
	assert_true(score.call(10, 20) < score.call(20, 30), "last levels are the hardest")
