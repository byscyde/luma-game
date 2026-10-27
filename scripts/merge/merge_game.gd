class_name MergeGame
extends RefCounted
## Merge-2 rules on a plain Dictionary state (save["merge"]), so they are
## testable without scenes and persist as JSON. Time is always passed in as
## unix seconds (`now`) so tests can move the clock.
##
## Cell entries are null or {"id": "chain:level", ...flags}:
##   boxed        item is in a crate: it cannot move; merging its twin onto it frees it
##   bubble_until bonus bubble: pop with gems before this time, else it turns into a coin
##   charges, cool_until   free generators (no energy) with a cooldown
##   timer_until  chest: 0 = closed, >0 = opening, ready when now >= timer_until
##   uses         scissors stack

signal changed
signal leveled_up(level: int)

const STATE_VERSION := 1

var db: MergeDB
var s: Dictionary
var rng := RandomNumberGenerator.new()
var last_sale: Dictionary = {}    ## {"cell", "item", "coins", "until"} for undo; not saved


func _init(p_db: MergeDB, state: Dictionary) -> void:
	db = p_db
	s = state
	if s.is_empty() or int(s.get("version", 0)) < STATE_VERSION:
		_new_state(int(Time.get_unix_time_from_system()))
	rng.seed = int(s.get("rng_seed", 1))
	if s.has("rng_state"):
		rng.state = str(s["rng_state"]).to_int()   # stored as text: JSON floats lose 64-bit precision


func _new_state(now: int) -> void:
	var b: Dictionary = db.balance
	s.clear()
	s["version"] = STATE_VERSION
	s["board"] = []
	(s["board"] as Array).resize(db.cols * db.rows)
	s["inventory"] = []
	s["inv_slots"] = int(b.get("inventory_start", 4))
	s["energy"] = int(b.get("start_energy", 100))
	s["energy_ts"] = now
	s["coins"] = int(b.get("start_coins", 0))
	s["gems"] = int(b.get("start_gems", 0))
	s["xp"] = 0
	s["level"] = 1
	s["orders"] = []
	s["order_seq"] = 0
	s["tasks_done"] = []
	s["designs"] = {}
	s["chapter_rewards"] = []
	s["refills"] = {"day": 0, "n": 0}
	s["gifts"] = []                       ## items waiting for a free tile
	s["rng_seed"] = 20261027
	for e in b.get("start_board", []):
		var it := {"id": str(e["id"])}
		if bool(e.get("boxed", false)):
			it["boxed"] = true
		_put(Vector2i(int(e["cell"][0]), int(e["cell"][1])), it)
	rng.seed = int(s["rng_seed"])
	_save_rng()
	_fill_orders()


func _save_rng() -> void:
	s["rng_state"] = str(rng.state)


# ------------------------------------------------------------------ board access

func idx(c: Vector2i) -> int:
	return c.y * db.cols + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < db.cols and c.y < db.rows


func at(c: Vector2i):
	return s["board"][idx(c)] if in_bounds(c) else null


func _put(c: Vector2i, item) -> void:
	s["board"][idx(c)] = item


func free_cells() -> int:
	var n := 0
	for v in s["board"]:
		if v == null:
			n += 1
	return n


## Nearest empty tile to `from` (ring by ring), or (-1, -1) when the board is full.
func nearest_free(from: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := INF
	for y in db.rows:
		for x in db.cols:
			var c := Vector2i(x, y)
			if at(c) == null:
				var d := float(maxi(absi(c.x - from.x), absi(c.y - from.y))) + 0.01 * (absi(c.x - from.x) + absi(c.y - from.y))
				if d < best_d:
					best_d = d
					best = c
	return best


func count_on_board(id: String) -> int:
	var n := 0
	for v in s["board"]:
		if v != null and v["id"] == id and _usable(v):
			n += 1
	return n


func _usable(v: Dictionary) -> bool:
	return not v.get("boxed", false) and float(v.get("bubble_until", 0)) <= 0.0


# ------------------------------------------------------------------ energy

func energy_cap() -> int:
	return int(db.balance.get("energy_cap", 100))


## Regenerates energy from wall-clock time (also while the app was closed).
func energy(now: int) -> int:
	var cap := energy_cap()
	var e := int(s["energy"])
	var regen := int(db.balance.get("energy_regen_s", 120))
	if e >= cap:
		s["energy_ts"] = now
		return e
	var gained := int((now - int(s["energy_ts"])) / regen)
	if gained > 0:
		e = mini(cap, e + gained)
		s["energy"] = e
		s["energy_ts"] = now if e >= cap else int(s["energy_ts"]) + gained * regen
	return e


## Seconds until the next energy point (0 when full).
func energy_eta(now: int) -> int:
	if energy(now) >= energy_cap():
		return 0
	return int(db.balance.get("energy_regen_s", 120)) - (now - int(s["energy_ts"]))


func _spend_energy(n: int, now: int) -> bool:
	var e := energy(now)
	if e < n:
		return false
	var was_full := e >= energy_cap()
	s["energy"] = e - n
	if was_full:
		s["energy_ts"] = now
	return true


func refill_price(now: int) -> int:
	var day := int(now / 86400)
	var prices: Array = db.balance.get("energy_refill_gems", [10])
	var n := int(s["refills"]["n"]) if int(s["refills"]["day"]) == day else 0
	return int(prices[mini(n, prices.size() - 1)])


func buy_energy_refill(now: int) -> bool:
	var price := refill_price(now)
	if int(s["gems"]) < price:
		return false
	var day := int(now / 86400)
	if int(s["refills"]["day"]) != day:
		s["refills"] = {"day": day, "n": 0}
	s["refills"]["n"] = int(s["refills"]["n"]) + 1
	s["gems"] = int(s["gems"]) - price
	s["energy"] = maxi(energy(now), 0) + energy_cap()
	changed.emit()
	return true


# ------------------------------------------------------------------ generators & chests

func is_generator(id: String) -> bool:
	return db.kind(id) == "generator"


func generator_ready(c: Vector2i, now: int) -> bool:
	var v = at(c)
	if v == null or not is_generator(v["id"]) or not _usable(v):
		return false
	if int(db.gen_def(v["id"], "energy", 1)) > 0:
		return true
	_refresh_charges(v, now)
	return int(v.get("charges", 0)) > 0


func _refresh_charges(v: Dictionary, now: int) -> void:
	var maxc := int(db.gen_def(v["id"], "charges", 0))
	if not v.has("charges"):
		v["charges"] = maxc
	if int(v["charges"]) <= 0 and int(v.get("cool_until", 0)) > 0 and now >= int(v["cool_until"]):
		v["charges"] = maxc
		v["cool_until"] = 0


## Tap on a tile: generators produce, chests open, resources are collected.
## Returns {"ok": bool, "reason": String, "cell": Vector2i (spawned/affected)}.
func tap(c: Vector2i, now: int) -> Dictionary:
	var v = at(c)
	if v == null:
		return {"ok": false, "reason": "empty"}
	if v.get("boxed", false):
		return {"ok": false, "reason": "boxed"}
	if float(v.get("bubble_until", 0)) > 0.0:
		return {"ok": false, "reason": "bubble"}
	match db.kind(v["id"]):
		"generator":
			return _tap_generator(c, v, now)
		"chest":
			return _tap_chest(c, v, now)
		"resource":
			return collect(c, now)
	return {"ok": false, "reason": "nothing"}


func _tap_generator(c: Vector2i, v: Dictionary, now: int) -> Dictionary:
	var cost := int(db.gen_def(v["id"], "energy", 1))
	if cost == 0:
		_refresh_charges(v, now)
		if int(v["charges"]) <= 0:
			return {"ok": false, "reason": "cooldown", "until": int(v.get("cool_until", 0))}
	var dest := nearest_free(c)
	if dest == Vector2i(-1, -1):
		return {"ok": false, "reason": "board_full"}
	if cost > 0 and not _spend_energy(cost, now):
		return {"ok": false, "reason": "no_energy"}
	if cost == 0:
		v["charges"] = int(v["charges"]) - 1
		if int(v["charges"]) <= 0:
			v["cool_until"] = now + int(db.gen_def(v["id"], "cooldown", 1800))
	var drop := _roll(db.gen_def(v["id"], "drops", []))
	_put(dest, {"id": drop})
	_save_rng()
	changed.emit()
	return {"ok": true, "cell": dest, "id": drop}


func _roll(table: Array) -> String:
	var total := 0
	for d in table:
		total += int(d[2])
	var r := rng.randi_range(1, maxi(1, total))
	for d in table:
		r -= int(d[2])
		if r <= 0:
			return MergeDB.make_id(str(d[0]), int(d[1]))
	return MergeDB.make_id(str(table[0][0]), int(table[0][1]))


func _tap_chest(c: Vector2i, v: Dictionary, now: int) -> Dictionary:
	var until := int(v.get("timer_until", 0))
	if until == 0:
		v["timer_until"] = now + int(db.gen_def(v["id"], "timer", 900))
		changed.emit()
		return {"ok": true, "reason": "opening", "cell": c}
	if now < until:
		return {"ok": false, "reason": "chest_timer", "until": until}
	return _open_chest(c, v)


func rush_chest(c: Vector2i, now: int) -> bool:
	var v = at(c)
	if v == null or db.kind(v["id"]) != "chest" or not _usable(v):
		return false
	var price := chest_rush_price(c, now)
	if int(s["gems"]) < price:
		return false
	s["gems"] = int(s["gems"]) - price
	_open_chest(c, v)
	return true


func chest_rush_price(c: Vector2i, now: int) -> int:
	var v = at(c)
	if v == null:
		return 0
	var full := int(db.gen_def(v["id"], "rush_gems", 4))
	var until := int(v.get("timer_until", 0))
	if until == 0:
		return full
	var total := float(db.gen_def(v["id"], "timer", 900))
	return maxi(1, ceili(full * clampf((until - now) / total, 0.0, 1.0)))


func _open_chest(c: Vector2i, v: Dictionary) -> Dictionary:
	_put(c, null)
	var contents: Array = db.gen_def(v["id"], "contents", [])
	for d in contents:
		_give(MergeDB.make_id(str(d[0]), int(d[1])), c)
	changed.emit()
	return {"ok": true, "reason": "opened", "cell": c}


## Places an item near `near`, or queues it as a gift when the board is full.
func _give(id: String, near: Vector2i) -> void:
	var dest := nearest_free(near)
	if dest == Vector2i(-1, -1):
		(s["gifts"] as Array).append(id)
	else:
		_put(dest, {"id": id})


## Moves queued gifts onto the board while there is room.
func deliver_gifts() -> int:
	var n := 0
	while not (s["gifts"] as Array).is_empty():
		var dest := nearest_free(Vector2i(db.cols / 2, db.rows / 2))
		if dest == Vector2i(-1, -1):
			break
		_put(dest, {"id": (s["gifts"] as Array).pop_front()})
		n += 1
	if n > 0:
		changed.emit()
	return n


func collect(c: Vector2i, now: int) -> Dictionary:
	var v = at(c)
	if v == null or db.kind(v["id"]) != "resource" or not _usable(v):
		return {"ok": false, "reason": "not_resource"}
	var res := str(db.chains[MergeDB.chain_of(v["id"])]["resource"])
	var amount := db.resource_value(v["id"])
	_put(c, null)
	match res:
		"coins":
			s["coins"] = int(s["coins"]) + amount
		"gems":
			s["gems"] = int(s["gems"]) + amount
		"energy":
			s["energy"] = energy(now) + amount
	changed.emit()
	return {"ok": true, "reason": "collected", "resource": res, "amount": amount, "cell": c}


# ------------------------------------------------------------------ drag & drop

## Drops the item at `from` onto `to`. Returns {"ok", "action"} where action is
## move / swap / merge / unbox / split / none.
func drop(from: Vector2i, to: Vector2i, now: int) -> Dictionary:
	if from == to or not in_bounds(from) or not in_bounds(to):
		return {"ok": false, "action": "none"}
	var a = at(from)
	if a == null or a.get("boxed", false) or float(a.get("bubble_until", 0)) > 0.0:
		return {"ok": false, "action": "none"}
	var b = at(to)
	if b == null:
		_put(to, a)
		_put(from, null)
		changed.emit()
		return {"ok": true, "action": "move"}
	if db.kind(a["id"]) == "tool" and b != null and _usable(b) and db.level_of(b["id"]) >= 2 \
			and db.kind(b["id"]) != "tool":
		return _split(from, to, a, b)
	if a["id"] == b["id"] and not db.is_max(a["id"]) and float(b.get("bubble_until", 0)) <= 0.0:
		return _merge(from, to, a, b, now)
	if a["id"] == b["id"] and db.kind(a["id"]) == "tool":
		b["uses"] = int(b.get("uses", 1)) + int(a.get("uses", 1))
		_put(from, null)
		changed.emit()
		return {"ok": true, "action": "stack"}
	if b.get("boxed", false) or float(b.get("bubble_until", 0)) > 0.0:
		return {"ok": false, "action": "none"}
	_put(to, a)
	_put(from, b)
	changed.emit()
	return {"ok": true, "action": "swap"}


func _merge(from: Vector2i, to: Vector2i, a: Dictionary, b: Dictionary, now: int) -> Dictionary:
	var unbox := bool(b.get("boxed", false))
	var nid := db.next_id(a["id"])
	var merged := {"id": nid}
	if is_generator(nid) and int(db.gen_def(nid, "energy", 1)) == 0:
		merged["charges"] = int(db.gen_def(nid, "charges", 0))   # merging resets the timer
	_put(from, null)
	_put(to, merged)
	var bubble := Vector2i(-1, -1)
	if db.level_of(nid) >= int(db.balance.get("bubble_min_level", 4)) and db.kind(nid) == "food" \
			and rng.randf() < float(db.balance.get("bubble_chance", 0.08)):
		var dest := nearest_free(to)
		if dest != Vector2i(-1, -1):
			_put(dest, {"id": nid, "bubble_until": now + int(db.balance.get("bubble_seconds", 60))})
			bubble = dest
	_save_rng()
	changed.emit()
	return {"ok": true, "action": "unbox" if unbox else "merge", "id": nid, "bubble": bubble}


func _split(from: Vector2i, to: Vector2i, tool: Dictionary, b: Dictionary) -> Dictionary:
	var dest := nearest_free(to)
	if dest == Vector2i(-1, -1):
		return {"ok": false, "action": "none", "reason": "board_full"}
	var lower := MergeDB.make_id(MergeDB.chain_of(b["id"]), db.level_of(b["id"]) - 1)
	_put(to, {"id": lower})
	_put(dest, {"id": lower})
	var uses := int(tool.get("uses", 1)) - 1
	if uses <= 0:
		_put(from, null)
	else:
		tool["uses"] = uses
	changed.emit()
	return {"ok": true, "action": "split", "cell": dest}


# ------------------------------------------------------------------ bubbles

func bubble_price(c: Vector2i) -> int:
	var v = at(c)
	return 0 if v == null else db.level_of(v["id"]) * int(db.balance.get("bubble_gems_per_level", 3))


func pop_bubble(c: Vector2i, now: int) -> bool:
	var v = at(c)
	if v == null or float(v.get("bubble_until", 0)) <= 0.0 or now >= int(v["bubble_until"]):
		return false
	var price := bubble_price(c)
	if int(s["gems"]) < price:
		return false
	s["gems"] = int(s["gems"]) - price
	v.erase("bubble_until")
	changed.emit()
	return true


## Expired bubbles turn into a coin. Call regularly.
func tick(now: int) -> bool:
	var any := false
	for i in (s["board"] as Array).size():
		var v = s["board"][i]
		if v != null and float(v.get("bubble_until", 0)) > 0.0 and now >= int(v["bubble_until"]):
			s["board"][i] = {"id": "coins:1"}
			any = true
	if any:
		changed.emit()
	return any


# ------------------------------------------------------------------ inventory & selling

func inventory() -> Array:
	return s["inventory"]


func store(c: Vector2i) -> bool:
	var v = at(c)
	if v == null or not _usable(v) or (s["inventory"] as Array).size() >= int(s["inv_slots"]):
		return false
	(s["inventory"] as Array).append(v)
	_put(c, null)
	changed.emit()
	return true


func take_out(i: int, near := Vector2i(3, 4)) -> bool:
	var inv: Array = s["inventory"]
	if i < 0 or i >= inv.size():
		return false
	var dest := nearest_free(near)
	if dest == Vector2i(-1, -1):
		return false
	_put(dest, inv[i])
	inv.remove_at(i)
	changed.emit()
	return true


func slot_price() -> int:
	var prices: Array = db.balance.get("inventory_slot_gems", [10])
	var bought := int(s["inv_slots"]) - int(db.balance.get("inventory_start", 4))
	return int(prices[mini(bought, prices.size() - 1)])


func buy_slot() -> bool:
	if int(s["inv_slots"]) >= int(db.balance.get("inventory_max", 16)) or int(s["gems"]) < slot_price():
		return false
	s["gems"] = int(s["gems"]) - slot_price()
	s["inv_slots"] = int(s["inv_slots"]) + 1
	changed.emit()
	return true


func can_sell(c: Vector2i) -> bool:
	var v = at(c)
	return v != null and _usable(v) and not is_generator(v["id"])


func sell(c: Vector2i, now: int) -> int:
	if not can_sell(c):
		return 0
	var v: Dictionary = at(c)
	var coins := db.sell_value(v["id"])
	_put(c, null)
	s["coins"] = int(s["coins"]) + coins
	last_sale = {"cell": c, "item": v, "coins": coins, "until": now + int(db.balance.get("sell_undo_s", 5))}
	changed.emit()
	return coins


func undo_sale(now: int) -> bool:
	if last_sale.is_empty() or now > int(last_sale["until"]) or at(last_sale["cell"]) != null:
		return false
	_put(last_sale["cell"], last_sale["item"])
	s["coins"] = maxi(0, int(s["coins"]) - int(last_sale["coins"]))
	last_sale = {}
	changed.emit()
	return true


# ------------------------------------------------------------------ orders

func orders() -> Array:
	return s["orders"]


func _fill_orders() -> void:
	var slots := int(db.balance.get("order_slots", 3))
	while (s["orders"] as Array).size() < slots:
		(s["orders"] as Array).append(_new_order())
	_save_rng()


func _new_order() -> Dictionary:
	var level := int(s["level"])
	var foods := db.food_chains(level)
	var n := 1 if level < 2 else rng.randi_range(1, 2 if level < 6 else 3)
	var max_l := clampi(2 + level / 2, 2, 9)
	var min_l := clampi(1 + level / 4, 1, max_l)
	var items: Array = []
	var coins := 0
	var xp := 0
	var coin_t: Array = db.balance.get("order_coins_per_level", [0, 2])
	var xp_t: Array = db.balance.get("order_xp_per_level", [0, 1])
	for i in n:
		var chain: String = foods[rng.randi_range(0, foods.size() - 1)]
		var l := rng.randi_range(min_l, mini(max_l, db.max_level(chain)))
		items.append(MergeDB.make_id(chain, l))
		coins += int(coin_t[mini(l, coin_t.size() - 1)])
		xp += int(xp_t[mini(l, xp_t.size() - 1)])
	var who: Array = db.cast.keys().filter(func(k): return k != "nell" and k != "pip")
	s["order_seq"] = int(s["order_seq"]) + 1
	return {"id": int(s["order_seq"]), "who": who[rng.randi_range(0, who.size() - 1)], "items": items,
		"coins": coins, "xp": maxi(1, xp)}


## Which board tiles would serve this order (empty when it cannot be served yet).
func order_cells(o: Dictionary) -> Array[Vector2i]:
	var used := {}
	var out: Array[Vector2i] = []
	for id in o["items"]:
		var found := false
		for y in db.rows:
			for x in db.cols:
				var c := Vector2i(x, y)
				var v = at(c)
				if v != null and v["id"] == id and _usable(v) and not used.has(c):
					used[c] = true
					out.append(c)
					found = true
					break
			if found:
				break
		if not found:
			return []
	return out


func can_serve(i: int) -> bool:
	return i >= 0 and i < (s["orders"] as Array).size() and not order_cells(s["orders"][i]).is_empty()


func serve(i: int) -> Dictionary:
	if not can_serve(i):
		return {"ok": false}
	var o: Dictionary = s["orders"][i]
	for c in order_cells(o):
		_put(c, null)
	s["coins"] = int(s["coins"]) + int(o["coins"])
	(s["orders"] as Array).remove_at(i)
	var lv := add_xp(int(o["xp"]))
	_fill_orders()
	changed.emit()
	return {"ok": true, "coins": int(o["coins"]), "xp": int(o["xp"]), "leveled": lv}


# ------------------------------------------------------------------ xp & levels

static func xp_to_next(level: int) -> int:
	return int(round(12.0 * pow(float(level), 1.45)))


## Adds XP; returns the number of levels gained. Each level refills energy,
## grants gems and unlocks content (new generators arrive as gifts).
func add_xp(amount: int) -> int:
	s["xp"] = int(s["xp"]) + amount
	var gained := 0
	while int(s["xp"]) >= xp_to_next(int(s["level"])):
		s["xp"] = int(s["xp"]) - xp_to_next(int(s["level"]))
		s["level"] = int(s["level"]) + 1
		gained += 1
		var gems_t: Array = db.balance.get("level_up_gems", [5])
		s["gems"] = int(s["gems"]) + int(gems_t[mini(int(s["level"]) - 2, gems_t.size() - 1)])
		s["energy"] = maxi(int(s["energy"]), energy_cap())
		for id in db.balance.get("level_unlock_items", {}).get(str(s["level"]), []):
			(s["gifts"] as Array).append(str(id))
		leveled_up.emit(int(s["level"]))
	if gained > 0:
		deliver_gifts()
	return gained


# ------------------------------------------------------------------ renovation tasks

func chapter_index() -> int:
	var done: Array = s["tasks_done"]
	for i in db.chapters.size():
		for t in db.chapters[i]["tasks"]:
			if not done.has(t["id"]):
				return i
	return db.chapters.size()


## The next tasks the player can do (in order within the current chapter).
func open_tasks() -> Array:
	var ci := chapter_index()
	if ci >= db.chapters.size():
		return []
	var out: Array = []
	for t in db.chapters[ci]["tasks"]:
		if not (s["tasks_done"] as Array).has(t["id"]):
			out.append(t)
			if out.size() >= 2:
				break
	return out


func can_do_task(task_id: String) -> bool:
	var t := db.task(task_id)
	if t.is_empty() or (s["tasks_done"] as Array).has(task_id):
		return false
	var ok := false
	for o in open_tasks():
		if o["id"] == task_id:
			ok = true
	return ok and int(s["coins"]) >= int(t["cost"])


## Pays for a task. Returns {"ok", "dialogue", "chapter_done", "reward"}.
func do_task(task_id: String, design := 0) -> Dictionary:
	if not can_do_task(task_id):
		return {"ok": false}
	var t := db.task(task_id)
	var ci := chapter_index()
	s["coins"] = int(s["coins"]) - int(t["cost"])
	(s["tasks_done"] as Array).append(task_id)
	if t.has("designs"):
		s["designs"][task_id] = clampi(design, 0, (t["designs"] as Array).size() - 1)
	var lv := add_xp(maxi(2, int(t["cost"]) / 10))
	var res := {"ok": true, "dialogue": t.get("dialogue", []), "chapter_done": false, "leveled": lv}
	if chapter_index() > ci and not (s["chapter_rewards"] as Array).has(db.chapters[ci]["id"]):
		var r: Dictionary = db.chapters[ci].get("reward", {})
		s["gems"] = int(s["gems"]) + int(r.get("gems", 0))
		s["energy"] = int(s["energy"]) + int(r.get("energy", 0))
		(s["chapter_rewards"] as Array).append(db.chapters[ci]["id"])
		res["chapter_done"] = true
		res["reward"] = r
	changed.emit()
	return res


## Restored objects can switch between their designs for free.
func set_design(task_id: String, design: int) -> bool:
	var t := db.task(task_id)
	if not (s["tasks_done"] as Array).has(task_id) or not t.has("designs"):
		return false
	s["designs"][task_id] = clampi(design, 0, (t["designs"] as Array).size() - 1)
	changed.emit()
	return true
