extends TestCase


func test_straight_line_reaches_target() -> void:
	var b := board_from(["S1 I1 T1", ". . .", ". . ."])
	var r := WaterSimulation.simulate(b)
	assert_true(r.all_required_reached, r.describe())
	assert_eq(r.distance[Vector2i(2, 0)], 2)
	assert_eq(r.leak_count(), 0)


func test_misaligned_tile_blocks_and_reports_mismatch() -> void:
	var b := board_from(["S1 I0 T1", ". . .", ". . ."])
	var r := WaterSimulation.simulate(b)
	assert_false(r.all_required_reached)
	assert_eq(r.leak_count(), 1)
	assert_eq(r.leaks[0]["reason"], WaterSimulation.LEAK_MISMATCH)


func test_edge_leak_and_blocked_rock() -> void:
	var b := board_from(["S0 # .", ". . .", ". . T1"])
	var r := WaterSimulation.simulate(b)
	assert_eq(r.leaks[0]["reason"], WaterSimulation.LEAK_EDGE)
	var b2 := board_from(["S1 # .", ". . .", ". . T1"])
	var r2 := WaterSimulation.simulate(b2)
	assert_eq(r2.leaks[0]["reason"], WaterSimulation.LEAK_BLOCKED)


func test_elbow_route() -> void:
	# S -> elbow (W,S) down -> straight -> target below
	var b := board_from(["S1 L2 .", ". I0 .", ". T1 ."])
	var r := WaterSimulation.simulate(b)
	assert_true(r.all_required_reached, r.describe())
	assert_eq(r.order, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2)] as Array[Vector2i])


func test_branching_tee_reaches_multiple_targets() -> void:
	# tee at (1,1) rotation 0 = N,E,S ; source above it facing south.
	var b := board_from([". S2 .", ". Y0 T2", ". T1 ."])
	var r := WaterSimulation.simulate(b)
	assert_true(r.all_required_reached, r.describe())
	assert_eq(r.reached_targets.size(), 2)


func test_cycle_terminates_and_counts_once() -> void:
	# tee + three elbows form a closed ring; BFS must not revisit cells.
	var b := board_from([
		"S1 Y1 L2",
		". L1 L0",
		". . T1",
	])
	var r := WaterSimulation.simulate(b)
	var seen := {}
	for p in r.order:
		assert_false(seen.has(p), "cell visited twice: %s" % str(p))
		seen[p] = true
	assert_true(r.order.size() <= 9)


func test_closed_gate_blocks_then_opens() -> void:
	var b := board_from(["S1 G1a T1", "Ka . .", ". . ."])
	var r := WaterSimulation.simulate(b)
	assert_false(r.all_required_reached)
	assert_eq(r.leaks[0]["reason"], WaterSimulation.LEAK_CLOSED)
	b.tap(Vector2i(0, 1))
	assert_true(WaterSimulation.simulate(b).all_required_reached)


func test_bonus_target_is_optional() -> void:
	var b := board_from(["S1 Y1 T1", ". B1 .", ". . ."])
	var r := WaterSimulation.simulate(b)
	assert_true(r.all_required_reached)
	assert_eq(r.reached_bonus, ["B1"] as Array[String])
	assert_eq(r.required_targets, ["T1"] as Array[String])


func test_target_is_a_sink_water_does_not_pass_through() -> void:
	var b := board_from(["S1 T1 I1", ". . .", ". . ."])
	var r := WaterSimulation.simulate(b)
	assert_false(r.is_wet(Vector2i(2, 0)))


func test_no_targets_is_never_complete() -> void:
	var b := board_from(["S1 I1 .", ". . .", ". . ."])
	assert_false(WaterSimulation.simulate(b).all_required_reached)


func test_simulation_is_deterministic() -> void:
	var b := board_from(["S1 Y1 L2", ". Y2 L0", ". T1 T2"])
	var a := WaterSimulation.simulate(b).describe()
	for i in 5:
		assert_eq(WaterSimulation.simulate(b).describe(), a)
