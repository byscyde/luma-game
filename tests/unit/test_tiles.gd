extends TestCase


func test_rotate_mask_cycles_clockwise() -> void:
	assert_eq(Dir.rotate_mask(Dir.N, 1), Dir.E)
	assert_eq(Dir.rotate_mask(Dir.N, 2), Dir.S)
	assert_eq(Dir.rotate_mask(Dir.N, 3), Dir.W)
	assert_eq(Dir.rotate_mask(Dir.N, 4), Dir.N)
	assert_eq(Dir.rotate_mask(Dir.W, 1), Dir.N)
	assert_eq(Dir.rotate_mask(Dir.N | Dir.E, 1), Dir.E | Dir.S)
	assert_eq(Dir.rotate_mask(Dir.N | Dir.E, -1), Dir.N | Dir.W)


func test_opposites_and_offsets_are_consistent() -> void:
	for d in Dir.LIST:
		assert_eq(Dir.opposite(Dir.opposite(d)), d)
		assert_eq(Dir.offset(d) + Dir.offset(Dir.opposite(d)), Vector2i.ZERO)


func test_straight_has_two_distinct_rotations() -> void:
	var t := PuzzleTile.new(TileTypes.STRAIGHT)
	assert_eq(t.distinct_rotations().size(), 2)
	assert_eq(t.shape_mask(), Dir.N | Dir.S)
	t.rotation = 1
	assert_eq(t.shape_mask(), Dir.E | Dir.W)


func test_elbow_and_tee_have_four_rotations_cross_one() -> void:
	assert_eq(PuzzleTile.new(TileTypes.ELBOW).distinct_rotations().size(), 4)
	assert_eq(PuzzleTile.new(TileTypes.TEE).distinct_rotations().size(), 4)
	assert_eq(PuzzleTile.new(TileTypes.CROSS).distinct_rotations().size(), 1)


func test_tap_rotates_rotatable_and_ignores_fixed() -> void:
	var b := board_from(["S1 L0 I0!", "# . T1", ". . ."])
	assert_true(b.tap(Vector2i(1, 0)), "elbow rotates")
	assert_eq(b.get_tile(Vector2i(1, 0)).rotation, 1)
	for i in 3:
		b.tap(Vector2i(1, 0))
	assert_eq(b.get_tile(Vector2i(1, 0)).rotation, 0, "four taps return to start")
	assert_false(b.tap(Vector2i(2, 0)), "pinned straight does not rotate")
	assert_false(b.tap(Vector2i(0, 0)), "source does not rotate")
	assert_false(b.tap(Vector2i(0, 1)), "rock does not rotate")
	assert_false(b.tap(Vector2i(9, 9)), "out of bounds tap ignored")


func test_switch_toggles_linked_gates() -> void:
	var b := board_from(["S1 G1a g1a", "Ka . T1", ". . ."])
	var gate := b.get_tile(Vector2i(1, 0))
	var inv := b.get_tile(Vector2i(2, 0))
	assert_false(b.is_gate_open(gate))
	assert_true(b.is_gate_open(inv))
	assert_eq(b.effective_mask(Vector2i(1, 0)), 0)
	assert_true(b.tap(Vector2i(0, 1)))
	assert_true(b.is_gate_open(gate))
	assert_false(b.is_gate_open(inv))
	assert_eq(b.effective_mask(Vector2i(1, 0)), Dir.E | Dir.W)


func test_snapshot_restore_round_trip() -> void:
	var b := board_from(["S1 L0 L2", "Ka . T1", ". . ."])
	var snap := b.snapshot()
	b.tap(Vector2i(1, 0))
	b.tap(Vector2i(0, 1))
	b.restore(snap)
	assert_eq(b.get_tile(Vector2i(1, 0)).rotation, 0)
	assert_false(bool(b.switches["a"]))


func test_parse_token_errors() -> void:
	assert_true(LevelData.parse_token("Q").has("error"))
	assert_true(LevelData.parse_token("L7").has("error"))
	assert_true(LevelData.parse_token("L").has("error"))
	assert_true(LevelData.parse_token("T").has("error"))
	assert_true(LevelData.parse_token("G1").has("error"))
	assert_true(LevelData.parse_token("#3").has("error"))
	assert_false(LevelData.parse_token("L3!").has("error"))
	assert_eq((LevelData.parse_token("B2")["tile"] as PuzzleTile).target_id, "B2")
