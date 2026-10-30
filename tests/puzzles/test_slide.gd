extends TestCase
## Ember Reef (sliding rows/columns): rules and every shipped level.

const SIMPLE := {"grid": ["I1 I1 L2", ". . I0", ". . I0"], "source": {"side": "W", "index": 0},
	"targets": [{"side": "S", "index": 2, "id": "T1"}]}


func _levels() -> Array:
	return Game.island_levels("ember_reef")


func test_rows_and_columns_wrap_around() -> void:
	var b := SlideBoard.from_dict({"grid": ["I0 L1 Y2", ". # +", "L0 L1 L2"], "source": {"side": "W", "index": 0}, "targets": []})
	b.apply(["r", 0, 1])
	assert_eq(b.to_grid()[0], "Y2 I0 L1", "row slides right with wrap")
	b.apply(["r", 0, -1])
	assert_eq(b.to_grid()[0], "I0 L1 Y2", "and back")
	b.apply(["c", 1, 1])
	assert_eq(b.token_at(1, 0), "L1", "column slides down: bottom wraps to the top")
	assert_eq(b.token_at(1, 1), "L1")
	assert_eq(b.token_at(1, 2), "#")


func test_locked_lines_do_not_move() -> void:
	var b := SlideBoard.from_dict({"grid": ["I0 L1", "L0 L1"], "source": {"side": "W", "index": 0}, "targets": [], "locked_rows": [1], "locked_cols": [0]})
	assert_false(b.apply(["r", 1, 1]))
	assert_false(b.apply(["c", 0, -1]))
	assert_true(b.apply(["r", 0, 1]))
	for m in b.legal_moves():
		assert_false(m[0] == "r" and m[1] == 1)
		assert_false(m[0] == "c" and m[1] == 0)


func test_water_runs_from_frame_spring_to_frame_sapling() -> void:
	var b := SlideBoard.from_dict(SIMPLE)
	assert_true(b.solved(), "spring W0 -> I1 I1 L2 -> I0 -> I0 -> sapling S2")
	b.apply(["r", 0, 1])
	assert_false(b.solved())
	var sol := SlideSolver.solve(b)
	assert_eq(sol["status"], SlideSolver.SOLVED)
	assert_eq((sol["moves"] as Array).size(), 1)
	assert_eq(sol["moves"][0], ["r", 0, -1])


func test_thirty_levels_each_solvable_by_its_stored_solution() -> void:
	var levels := _levels()
	assert_eq(levels.size(), 30)
	var ids := {}
	for lv in levels:
		assert_false(ids.has(lv["id"]), "unique id " + str(lv["id"]))
		ids[lv["id"]] = true
		var b := SlideBoard.from_dict(lv)
		assert_eq(b.w, int(lv["w"]), lv["id"])
		assert_false(b.solved(), "%s starts unsolved" % lv["id"])
		for m in lv["solution"]:
			assert_true(b.apply(m), "%s: legal move %s" % [lv["id"], str(m)])
		assert_true(b.solved(), "%s: stored solution reaches every sapling" % lv["id"])
		assert_eq((lv["solution"] as Array).size(), int(lv["par"]), lv["id"])
		var target := 0
		for o in lv["objectives"]["optional"]:
			target = int(o["value"])
		assert_true(target >= int(lv["par"]), "%s: move goal is achievable" % lv["id"])


func test_difficulty_rises_across_the_island() -> void:
	var levels := _levels()
	var avg := func(a: int, b: int) -> float:
		var s := 0.0
		for i in range(a, b):
			s += float(levels[i]["par"]) + float(int(levels[i]["w"]) * int(levels[i]["h"])) * 0.2 + (levels[i]["targets"] as Array).size()
		return s / (b - a)
	assert_true(avg.call(0, 10) < avg.call(10, 20), "middle levels are harder than the first ten")
	assert_true(avg.call(10, 20) < avg.call(20, 30), "last levels are the hardest")
	assert_true(int(levels[29]["w"]) * int(levels[29]["h"]) >= 25, "the finale uses a 5x5 grid")


func test_short_levels_have_proven_optimal_par() -> void:
	for lv in _levels().slice(0, 10):
		var b := SlideBoard.from_dict(lv)
		var r := SlideSolver.solve(b, 50000)
		assert_eq(r["status"], SlideSolver.SOLVED, lv["id"])
		assert_eq((r["moves"] as Array).size(), int(lv["par"]), "%s par is the shortest solution" % lv["id"])
