extends TestCase

var db: ContentDB
var data: Dictionary
var prog: ProgressionModel


func before_each() -> void:
	db = ContentDB.load_default()
	data = SaveStore.default_data()
	prog = ProgressionModel.new(db, data["progress"])


## Solves a level for real and applies it. Optional objectives follow `goal`.
func _play(lid: String, goal: int = PuzzleSolver.GOAL_REQUIRED, extra_moves: int = 0) -> Dictionary:
	var level := db.get_level(lid)
	var board := level.build_board()
	var sol := PuzzleSolver.solve(board, 400000, goal)
	for p in sol["taps"]:
		board.tap(p)
	var moves: int = sol["taps"].size() + extra_moves
	var ev := PuzzleValidator.evaluate(level, board, WaterSimulation.simulate(board), moves)
	return prog.apply_level_result(level, ev, moves)


func test_content_loads_cleanly() -> void:
	assert_eq(db.errors.size(), 0, str(db.errors))
	assert_eq(db.level_order.size(), 30)
	assert_eq(db.area_order.size(), 6)


func test_first_completion_awards_once() -> void:
	var r1 := _play("w1_l01")
	assert_true(r1["first_completion"])
	assert_eq(r1["essence"], 10)
	var r2 := _play("w1_l01")
	assert_false(r2["first_completion"])
	assert_eq(r2["essence"], 0, "replay grants no base essence again")
	assert_eq(prog.essence(), 10)
	assert_eq(int(prog.level_record("w1_l01")["times"]), 2)


func test_optional_objective_awarded_once_and_later() -> void:
	# finish badly first (over the move target), then perfectly
	_play("w1_l01")
	_play("w1_l02")
	var r1 := _play("w1_l03", PuzzleSolver.GOAL_REQUIRED, 20)
	assert_eq(r1["essence"], 10)
	assert_eq(r1["new_optional"].size(), 0)
	var r2 := _play("w1_l03")
	assert_eq(r2["essence"], 5, "optional objective earns its reward on a replay")
	var r3 := _play("w1_l03")
	assert_eq(r3["essence"], 0)
	assert_eq(prog.objective_count("moves_at_most"), 1, "only l03 has a move objective so far")


func test_restoration_only_moves_forward() -> void:
	_play("w1_l01")
	_play("w1_l02")
	assert_eq(prog.object_stage("glade_tree_1"), 1)
	for lid in ["w1_l03", "w1_l04", "w1_l05"]:
		_play(lid)
	assert_eq(prog.object_stage("glade_tree_1"), 2)
	var r := _play("w1_l02")
	assert_eq(r["restoration"].size(), 0, "replay does not re-animate or regress")
	assert_eq(prog.object_stage("glade_tree_1"), 2)
	assert_true(prog.area_restored("spring_glade"))


func test_locked_level_cannot_be_completed() -> void:
	var r := _play("w1_l03")
	assert_false(r["first_completion"])
	assert_false(prog.is_completed("w1_l03"))
	assert_eq(prog.essence(), 0)


func test_unsolved_result_changes_nothing() -> void:
	var level := db.get_level("w1_l01")
	var r := prog.apply_level_result(level, {"solved": false, "objectives": []}, 3)
	assert_false(prog.is_completed("w1_l01"))
	assert_eq(r["essence"], 0)


func test_discovery_granted_once() -> void:
	for lid in ["w1_l01", "w1_l02"]:
		_play(lid)
	var r := _play("w1_l03")
	assert_eq(r["discoveries"], ["deco_lantern"])
	assert_eq(_play("w1_l03")["discoveries"], [])
	assert_eq(prog.p["discoveries"].count("deco_lantern"), 1)


func test_area_unlock_rules() -> void:
	assert_eq(prog.can_unlock_area("willow_brook")["reason"], "previous_area")
	for lid in ["w1_l01", "w1_l02", "w1_l03", "w1_l04", "w1_l05"]:
		_play(lid)
	assert_false(prog.is_level_unlocked("w1_l06"), "area still locked")
	var before := prog.essence()
	assert_true(prog.unlock_area("willow_brook"))
	assert_eq(prog.essence(), before - 40)
	assert_true(prog.is_level_unlocked("w1_l06"))
	assert_false(prog.unlock_area("willow_brook"), "cannot unlock twice")
	assert_eq(prog.essence(), before - 40, "no double charge")


func test_not_enough_essence_blocks_unlock() -> void:
	for lid in ["w1_l01", "w1_l02", "w1_l03", "w1_l04", "w1_l05"]:
		_play(lid)
	prog.p["essence"] = 5
	var chk := prog.can_unlock_area("willow_brook")
	assert_eq(chk["reason"], "essence")
	assert_eq(chk["missing"], 35)
	assert_false(prog.unlock_area("willow_brook"))
	assert_eq(prog.essence(), 5)


func test_full_playthrough_with_base_rewards_never_soft_locks() -> void:
	# Worst-case player: never meets an optional objective.
	for lid in db.level_order:
		var area := db.get_level(lid).area
		if not prog.is_area_unlocked(area):
			assert_true(prog.unlock_area(area), "could afford %s" % area)
		var r := _play(lid, PuzzleSolver.GOAL_REQUIRED, 50)
		assert_true(r["first_completion"], lid)
	assert_eq(prog.completed_count(), 30)
	assert_eq(prog.next_level_id(), "")
	for a in db.area_order:
		assert_true(prog.area_restored(a), "area %s fully restored" % a)
	assert_true(prog.essence() >= 0)


func test_achievements_unlock_and_are_unique() -> void:
	var r := _play("w1_l01")
	assert_has(r["achievements"], "first_flow")
	_play("w1_l02")
	assert_has(prog.p["achievements"], "green_again")
	_play("w1_l01")
	assert_eq(prog.p["achievements"].count("first_flow"), 1)


func test_decoration_visibility_requires_discovery() -> void:
	prog.set_decoration_visible("deco_spire", true)
	assert_false(prog.is_decoration_visible("deco_spire"))
	prog.p["discoveries"].append("deco_spire")
	assert_true(prog.is_decoration_visible("deco_spire"))
	prog.set_decoration_visible("deco_spire", false)
	assert_false(prog.is_decoration_visible("deco_spire"))


func test_tutorial_model_completes_after_onboarding() -> void:
	var t := TutorialModel.new(data["tutorial"])
	assert_true(t.should_show("tap_to_rotate"))
	for s in TutorialModel.ONBOARDING:
		assert_false(t.is_complete())
		t.mark_done(s)
	assert_true(t.is_complete())
	assert_false(t.should_show("tap_to_rotate"))
	assert_false(t.mark_done("tap_to_rotate"), "idempotent")
