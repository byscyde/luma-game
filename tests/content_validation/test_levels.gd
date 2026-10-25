extends TestCase
## Content gate: every shipped level parses, is not pre-solved, is solvable
## within budget, and its move target is achievable. (tools/validate_levels.gd
## performs the full report; this keeps the gate inside the test suite too.)


func test_every_level_is_valid_and_solvable() -> void:
	var db := ContentDB.load_default()
	assert_eq(db.errors.size(), 0, str(db.errors))
	var seen := {}
	for lid in db.level_order:
		assert_false(seen.has(lid), "duplicate " + lid)
		seen[lid] = true
		var level := db.get_level(lid)
		assert_eq(level.errors.size(), 0, lid + " " + str(level.errors))
		var board := level.build_board()
		assert_false(WaterSimulation.simulate(board).all_required_reached, lid + " is solved before any move")
		var r := PuzzleSolver.solve(board, 400000)
		assert_eq(r["status"], PuzzleSolver.STATUS_SOLVED, lid)
		if r["status"] != PuzzleSolver.STATUS_SOLVED:
			continue
		var target := level.optional_value(LevelData.OBJ_MOVES_AT_MOST, 9999)
		assert_true(int(r["moves"]) <= target, "%s move target %d below minimum %d" % [lid, target, r["moves"]])
		assert_eq(level.par_moves, int(r["moves"]), lid + " par_moves matches proven minimum")
		for p in r["taps"]:
			board.tap(p)
		assert_true(WaterSimulation.simulate(board).all_required_reached, lid + " solution replays")


func test_board_sizes_within_mobile_limits() -> void:
	var db := ContentDB.load_default()
	for lid in db.level_order:
		var l := db.get_level(lid)
		assert_true(l.width <= 6 and l.height <= 7, "%s is %dx%d" % [lid, l.width, l.height])


func test_first_five_levels_teach_one_idea_each() -> void:
	var db := ContentDB.load_default()
	var tutorials := []
	for i in 5:
		tutorials.append(db.get_level(db.level_order[i]).tutorial)
	assert_eq(tutorials, TutorialModel.ONBOARDING)
	assert_eq(db.get_level("w1_l01").width, 3, "tutorial board is 3x3")


func test_all_player_text_has_translations() -> void:
	var keys := {}
	var f := FileAccess.open("res://resources/localization/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			keys[row[0]] = row[1]
			assert_ne(row[1].strip_edges(), "", "empty translation for " + row[0])
	for k in TutorialModel.CAPTIONS.values():
		assert_true(keys.has(k), "missing translation " + k)
