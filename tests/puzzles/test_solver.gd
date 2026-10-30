extends TestCase


func _apply(b: PuzzleBoard, taps: Array) -> void:
	for p in taps:
		b.tap(p)


func test_solved_board_needs_zero_moves() -> void:
	var b := board_from(["S1 I1 T1", ". . .", ". . ."])
	var r := PuzzleSolver.solve(b)
	assert_eq(r["status"], PuzzleSolver.STATUS_SOLVED)
	assert_eq(r["moves"], 0)


func test_single_rotation_found() -> void:
	var b := board_from(["S1 I0 T1", ". . .", ". . ."])
	var r := PuzzleSolver.solve(b)
	assert_eq(r["moves"], 1)
	_apply(b, r["taps"])
	assert_true(WaterSimulation.simulate(b).all_required_reached)


func test_minimum_uses_cheapest_equivalent_rotation() -> void:
	# straight at rotation 1 already horizontal; at 0 one tap suffices (not 3)
	var b := board_from(["S1 I0 I0 T1", ". . . .", ". . . ."])
	var r := PuzzleSolver.solve(b)
	assert_eq(r["moves"], 2)


func test_elbow_needs_three_taps_when_counter_clockwise() -> void:
	# needed elbow W,S = rotation 2. Start at 3 -> 3 taps (3->0->1->2).
	var b := board_from(["S1 L3 .", ". I0! .", ". T1 ."])
	var r := PuzzleSolver.solve(b)
	assert_eq(r["moves"], 3)
	_apply(b, r["taps"])
	assert_true(WaterSimulation.simulate(b).all_required_reached)


func test_impossible_board_detected() -> void:
	var b := board_from(["S1 # T1", "# # .", ". . ."])
	assert_eq(PuzzleSolver.solve(b)["status"], PuzzleSolver.STATUS_IMPOSSIBLE)


func test_switch_solution() -> void:
	var b := board_from(["S1 G1a T1", "Ka . .", ". . ."])
	var r := PuzzleSolver.solve(b)
	assert_eq(r["moves"], 1)
	assert_eq(r["taps"][0], Vector2i(0, 1))


func test_budget_exhaustion_is_unverified_not_solved() -> void:
	var b := board_from([
		"S1 L0 L0 L0 L0",
		"L0 L0 L0 L0 L0",
		"L0 L0 L0 L0 L0",
		"L0 L0 L0 L0 L0",
		"L0 L0 L0 L0 T1",
	])
	var r := PuzzleSolver.solve(b, 3)
	assert_eq(r["status"], PuzzleSolver.STATUS_UNVERIFIED)


func test_multi_target_solution_valid() -> void:
	var b := board_from([
		"S2 . . .",
		"Y1 I0 L0 .",
		"I1 . I1 .",
		"T1 . T2 .",
	])
	var r := PuzzleSolver.solve(b)
	assert_eq(r["status"], PuzzleSolver.STATUS_SOLVED)
	_apply(b, r["taps"])
	var sim := WaterSimulation.simulate(b)
	assert_true(sim.all_required_reached, sim.describe())


func test_hint_returns_progress_tap() -> void:
	var b := board_from(["S1 I0 L0", ". . I1", ". . T1"])
	var before := int(PuzzleSolver.solve(b)["moves"])
	var h := PuzzleSolver.hint(b)
	assert_ne(h, Vector2i(-1, -1))
	b.tap(h)
	assert_eq(int(PuzzleSolver.solve(b)["moves"]), before - 1)


func test_goal_with_bonus_requires_bonus() -> void:
	var b := board_from(["S1 Y0 T1", ". I1 .", ". B1 ."])
	var req := PuzzleSolver.solve(b)
	var bon := PuzzleSolver.solve(b, PuzzleSolver.DEFAULT_BUDGET, PuzzleSolver.GOAL_WITH_BONUS)
	assert_eq(bon["status"], PuzzleSolver.STATUS_SOLVED)
	assert_true(int(bon["moves"]) >= int(req["moves"]))
	_apply(b, bon["taps"])
	var sim := WaterSimulation.simulate(b)
	assert_has(sim.reached_bonus, "B1")


func test_goal_no_leaks() -> void:
	# a tee is forced to spill unless its third arm feeds the bonus
	var b := board_from(["S1 Y1 T1", ". . .", ". . ."])
	assert_eq(PuzzleSolver.solve(b)["status"], PuzzleSolver.STATUS_SOLVED)
	assert_eq(PuzzleSolver.solve(b, 1000, PuzzleSolver.GOAL_NO_LEAKS)["status"], PuzzleSolver.STATUS_IMPOSSIBLE)
	var c := board_from(["S1 L0 .", ". I1 .", ". T1 ."])
	var r := PuzzleSolver.solve(c, 1000, PuzzleSolver.GOAL_NO_LEAKS)
	assert_eq(r["status"], PuzzleSolver.STATUS_SOLVED)
	_apply(c, r["taps"])
	assert_eq(WaterSimulation.simulate(c).leak_count(), 0)
