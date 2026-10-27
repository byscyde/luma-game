extends TestCase
## Merge-mode rules (MergeGame) on the real content in resources/merge.

const T0 := 1_800_000_000

var db: MergeDB


func before_each() -> void:
	db = MergeDB.load_default()


func _game() -> MergeGame:
	return MergeGame.new(db, {})


func _clear(g: MergeGame) -> void:
	for i in (g.s["board"] as Array).size():
		g.s["board"][i] = null


func test_content_is_valid() -> void:
	assert_true(db.errors.is_empty(), "content errors: %s" % str(db.errors))
	assert_eq(db.cols, 7)
	assert_eq(db.rows, 9)
	assert_true(db.food_chains(1).size() >= 2, "two chains from the start")
	for ch in db.chapters:
		assert_true((ch["tasks"] as Array).size() >= 5, "chapter %s has enough tasks" % ch["id"])


func test_new_game_layout_and_orders() -> void:
	var g := _game()
	assert_eq(int(g.s["level"]), 1)
	assert_eq(g.orders().size(), 3, "three orders on screen")
	var boxed := 0
	var gens := 0
	for v in g.s["board"]:
		if v != null and v.get("boxed", false):
			boxed += 1
		if v != null and g.is_generator(v["id"]):
			gens += 1
	assert_true(boxed >= 4, "crates on the starting board")
	assert_eq(gens, 2, "coffee grinder and flour sack")
	for o in g.orders():
		for id in o["items"]:
			assert_true(MergeDB.chain_of(id) in db.food_chains(1), "orders only ask for unlocked dishes")


func test_generator_spends_energy_and_spawns_next_to_it() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][g.idx(Vector2i(3, 4))] = {"id": "gen_coffee:1"}
	var e0 := g.energy(T0)
	var r := g.tap(Vector2i(3, 4), T0)
	assert_true(r["ok"])
	assert_eq(g.energy(T0), e0 - 1)
	var c: Vector2i = r["cell"]
	assert_true(maxi(absi(c.x - 3), absi(c.y - 4)) == 1, "spawned on an adjacent tile")
	assert_eq(MergeDB.chain_of(r["id"]), "coffee")


func test_no_energy_or_full_board_costs_nothing() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][g.idx(Vector2i(0, 0))] = {"id": "gen_coffee:1"}
	g.s["energy"] = 0
	g.s["energy_ts"] = T0
	assert_eq(g.tap(Vector2i(0, 0), T0)["reason"], "no_energy")
	for i in (g.s["board"] as Array).size():
		if g.s["board"][i] == null:
			g.s["board"][i] = {"id": "garden:1"}
	g.s["energy"] = 10
	assert_eq(g.tap(Vector2i(0, 0), T0)["reason"], "board_full")
	assert_eq(g.energy(T0), 10, "energy not spent when nothing could spawn")


func test_energy_regenerates_offline_up_to_cap() -> void:
	var g := _game()
	g.s["energy"] = 10
	g.s["energy_ts"] = T0
	assert_eq(g.energy(T0 + 119), 10)
	assert_eq(g.energy(T0 + 120), 11)
	assert_eq(g.energy(T0 + 120 * 50), 60, "2 minutes per point while closed")
	assert_eq(g.energy(T0 + 999999), 100, "never above the cap by itself")


func test_merge_two_identical_items() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][0] = {"id": "coffee:2"}
	g.s["board"][1] = {"id": "coffee:2"}
	var r := g.drop(Vector2i(0, 0), Vector2i(1, 0), T0)
	assert_eq(r["action"], "merge")
	assert_eq(g.at(Vector2i(1, 0))["id"], "coffee:3")
	assert_null_cell(g, Vector2i(0, 0))


func assert_null_cell(g: MergeGame, c: Vector2i) -> void:
	assert_true(g.at(c) == null, "cell %s empty" % str(c))


func test_different_items_swap_and_max_level_does_not_merge() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][0] = {"id": "coffee:2"}
	g.s["board"][1] = {"id": "bakery:2"}
	assert_eq(g.drop(Vector2i(0, 0), Vector2i(1, 0), T0)["action"], "swap")
	var top := MergeDB.make_id("coffee", db.max_level("coffee"))
	g.s["board"][0] = {"id": top}
	g.s["board"][1] = {"id": top}
	assert_eq(g.drop(Vector2i(0, 0), Vector2i(1, 0), T0)["action"], "swap", "max level items do not merge")


func test_crate_is_freed_by_merging_its_twin() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][0] = {"id": "coffee:2", "boxed": true}
	g.s["board"][1] = {"id": "coffee:2"}
	g.s["board"][2] = {"id": "bakery:1"}
	assert_eq(g.drop(Vector2i(0, 0), Vector2i(1, 0), T0)["action"], "none", "crates do not move")
	assert_eq(g.drop(Vector2i(2, 0), Vector2i(0, 0), T0)["action"], "none", "cannot swap onto a crate")
	assert_eq(g.drop(Vector2i(1, 0), Vector2i(0, 0), T0)["action"], "unbox")
	assert_eq(g.at(Vector2i(0, 0))["id"], "coffee:3")
	assert_false(g.at(Vector2i(0, 0)).get("boxed", false))


func test_bubble_pops_with_gems_or_turns_into_a_coin() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][0] = {"id": "coffee:5", "bubble_until": T0 + 60}
	assert_eq(g.drop(Vector2i(0, 0), Vector2i(1, 0), T0)["action"], "none", "bubbles are locked")
	g.s["gems"] = 100
	assert_true(g.pop_bubble(Vector2i(0, 0), T0 + 10))
	assert_eq(int(g.s["gems"]), 100 - g.db.level_of("coffee:5") * 3)
	assert_false(g.at(Vector2i(0, 0)).has("bubble_until"))
	g.s["board"][1] = {"id": "coffee:5", "bubble_until": T0 + 60}
	assert_false(g.pop_bubble(Vector2i(1, 0), T0 + 61), "too late")
	g.tick(T0 + 61)
	assert_eq(g.at(Vector2i(1, 0))["id"], "coins:1")


func test_bubbles_appear_on_high_merges_sometimes() -> void:
	var g := _game()
	db.balance["bubble_chance"] = 1.0
	_clear(g)
	g.s["board"][0] = {"id": "coffee:3"}
	g.s["board"][1] = {"id": "coffee:3"}
	var r := g.drop(Vector2i(0, 0), Vector2i(1, 0), T0)
	assert_ne(r["bubble"], Vector2i(-1, -1), "bubble spawned")
	assert_true(float(g.at(r["bubble"]).get("bubble_until", 0)) > 0.0)


func test_resources_collect_and_merge() -> void:
	var g := _game()
	_clear(g)
	g.s["coins"] = 0
	g.s["board"][0] = {"id": "coins:2"}
	g.s["board"][1] = {"id": "coins:2"}
	g.drop(Vector2i(0, 0), Vector2i(1, 0), T0)
	var r := g.tap(Vector2i(1, 0), T0)
	assert_eq(r["resource"], "coins")
	assert_eq(int(g.s["coins"]), db.resource_value("coins:3"))
	g.s["energy"] = 100
	g.s["board"][2] = {"id": "energy:2"}
	g.tap(Vector2i(2, 0), T0)
	assert_eq(g.energy(T0), 112, "energy bottles may exceed the cap")


func test_free_generator_charges_and_cooldown_reset_by_merge() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][0] = {"id": "gen_planter:1"}
	var n := int(db.gen_def("gen_planter:1", "charges", 0))
	var e := g.energy(T0)
	for i in n:
		assert_true(g.tap(Vector2i(0, 0), T0)["ok"])
	assert_eq(g.energy(T0), e, "free generator costs no energy")
	assert_eq(g.tap(Vector2i(0, 0), T0)["reason"], "cooldown")
	var cd := int(db.gen_def("gen_planter:1", "cooldown", 0))
	assert_true(g.tap(Vector2i(0, 0), T0 + cd)["ok"], "charges back after the cooldown")
	g.s["board"][1] = {"id": "gen_planter:1", "charges": 0, "cool_until": T0 + 9999}
	g.s["board"][2] = {"id": "gen_planter:1", "charges": 0, "cool_until": T0 + 9999}
	g.drop(Vector2i(1, 0), Vector2i(2, 0), T0)
	assert_eq(int(g.at(Vector2i(2, 0))["charges"]), int(db.gen_def("gen_planter:2", "charges", 0)), "merging resets the timer")


func test_chest_timer_rush_and_contents() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][10] = {"id": "chest:1"}
	assert_eq(g.tap(Vector2i(3, 1), T0)["reason"], "opening")
	assert_eq(g.tap(Vector2i(3, 1), T0 + 10)["reason"], "chest_timer")
	var r := g.tap(Vector2i(3, 1), T0 + int(db.gen_def("chest:1", "timer", 0)))
	assert_eq(r["reason"], "opened")
	assert_eq(63 - g.free_cells(), (db.gen_def("chest:1", "contents", []) as Array).size())
	_clear(g)
	g.s["board"][0] = {"id": "chest:2"}
	g.s["gems"] = 100
	assert_true(g.rush_chest(Vector2i(0, 0), T0))
	assert_eq(int(g.s["gems"]), 100 - int(db.gen_def("chest:2", "rush_gems", 0)))


func test_scissors_split_and_stack() -> void:
	var g := _game()
	_clear(g)
	g.s["board"][0] = {"id": "scissors:1"}
	g.s["board"][1] = {"id": "scissors:1"}
	assert_eq(g.drop(Vector2i(0, 0), Vector2i(1, 0), T0)["action"], "stack")
	assert_eq(int(g.at(Vector2i(1, 0))["uses"]), 2)
	g.s["board"][5] = {"id": "bakery:4"}
	assert_eq(g.drop(Vector2i(1, 0), Vector2i(5, 0), T0)["action"], "split")
	assert_eq(g.count_on_board("bakery:3"), 2)
	assert_eq(int(g.at(Vector2i(1, 0))["uses"]), 1, "one use left")


func test_sell_and_undo_and_inventory() -> void:
	var g := _game()
	_clear(g)
	g.s["coins"] = 0
	g.s["board"][0] = {"id": "bakery:5"}
	var got := g.sell(Vector2i(0, 0), T0)
	assert_eq(got, db.sell_value("bakery:5"))
	assert_true(g.undo_sale(T0 + 3))
	assert_eq(int(g.s["coins"]), 0)
	assert_eq(g.at(Vector2i(0, 0))["id"], "bakery:5")
	g.sell(Vector2i(0, 0), T0)
	assert_false(g.undo_sale(T0 + 60), "undo window is short")
	g.s["board"][0] = {"id": "gen_coffee:1"}
	assert_false(g.can_sell(Vector2i(0, 0)), "generators cannot be sold")
	assert_true(g.store(Vector2i(0, 0)))
	assert_eq(g.inventory().size(), 1)
	assert_true(g.take_out(0))
	g.s["gems"] = 0
	assert_false(g.buy_slot(), "slots cost gems")
	g.s["gems"] = 100
	var slots := int(g.s["inv_slots"])
	assert_true(g.buy_slot())
	assert_eq(int(g.s["inv_slots"]), slots + 1)


func test_serving_an_order_pays_and_refills_the_row() -> void:
	var g := _game()
	_clear(g)
	var o: Dictionary = g.orders()[0]
	assert_false(g.can_serve(0))
	var x := 0
	for id in o["items"]:
		g.s["board"][x] = {"id": id}
		x += 1
	g.s["board"][x] = {"id": o["items"][0], "boxed": true}
	assert_true(g.can_serve(0))
	var coins := int(g.s["coins"])
	var r := g.serve(0)
	assert_true(r["ok"])
	assert_eq(int(g.s["coins"]), coins + int(o["coins"]))
	assert_eq(g.orders().size(), 3, "a new order takes its place")
	assert_true(g.at(Vector2i(x, 0)).get("boxed", false), "crated items are never used for orders")


func test_level_up_refills_energy_grants_gems_and_unlocks() -> void:
	var g := _game()
	_clear(g)
	g.s["energy"] = 3
	g.s["energy_ts"] = T0
	var gems := int(g.s["gems"])
	var need := 0
	for l in [1, 2]:
		need += MergeGame.xp_to_next(l)
	assert_eq(g.add_xp(need), 2)
	assert_eq(int(g.s["level"]), 3)
	assert_true(int(g.s["energy"]) >= g.energy_cap(), "level-up refills energy")
	assert_true(int(g.s["gems"]) > gems)
	assert_eq(g.count_on_board("gen_catch:1"), 1, "level 3 unlocks the fishing net")


func test_renovation_tasks_story_and_chapter_reward() -> void:
	var g := _game()
	var first: Dictionary = g.open_tasks()[0]
	g.s["coins"] = 0
	assert_false(g.can_do_task(first["id"]), "needs coins")
	g.s["coins"] = 100000
	var r := g.do_task(first["id"])
	assert_true(r["ok"])
	assert_true((r["dialogue"] as Array).size() > 0, "every task plays a story scene")
	assert_false(g.do_task(first["id"])["ok"], "a task is paid only once")
	var gems := int(g.s["gems"])
	for t in db.chapters[0]["tasks"]:
		if not (g.s["tasks_done"] as Array).has(t["id"]):
			r = g.do_task(t["id"], 2)
	assert_true(r["chapter_done"])
	assert_eq(g.chapter_index(), 1)
	assert_true(int(g.s["gems"]) >= gems + int(db.chapters[0]["reward"]["gems"]))
	assert_true(g.set_design("c1_floor", 1))
	assert_eq(int(g.s["designs"]["c1_floor"]), 1, "designs switch for free")


func test_state_survives_json_roundtrip() -> void:
	var g := _game()
	g.tap(Vector2i(3, 4), T0)
	var copy = JSON.parse_string(JSON.stringify(g.s))
	var g2 := MergeGame.new(db, copy)
	assert_eq(int(g2.s["level"]), int(g.s["level"]))
	assert_eq(g2.orders().size(), 3)
	var a := g.tap(Vector2i(3, 4), T0)
	var b := g2.tap(Vector2i(3, 4), T0)
	assert_eq(a["id"], b["id"], "same random sequence after reload")
