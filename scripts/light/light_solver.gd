class_name LightSolver
extends RefCounted
## Exhaustive solver for LightBoard. A beam only depends on the mirrors it
## actually meets, so the search decides each round mirror the first time a
## beam reaches it (both states) and leaves the others as they are. Every leaf
## that lights all crystals and no bloom is a solution; the cheapest one (fewest
## mirrors flipped from the current state) gives par.

const SOLVED := "solved"
const UNSOLVABLE := "unsolvable"


## Returns {"status", "par": int, "state": String (mirror_state of the cheapest
## solution), "flips": Array of cells to tap, "solutions": int (distinct leaves),
## "nodes": int}.
static func solve(board: LightBoard, node_budget: int = 200000) -> Dictionary:
	var ctx := {"best": null, "best_cost": 1 << 30, "count": 0, "nodes": 0, "budget": node_budget}
	_search(board, {}, ctx)
	if ctx["best"] == null:
		return {"status": UNSOLVABLE, "par": -1, "state": "", "flips": [], "solutions": 0, "nodes": ctx["nodes"]}
	var b := board.duplicate_board()
	var assign: Dictionary = ctx["best"]
	var flips: Array = []
	for c in board.mirrors():
		if assign.has(c) and assign[c] != board.token_at(c):
			flips.append(c)
			b.toggle(c)
	return {"status": SOLVED, "par": flips.size(), "state": b.mirror_state(), "flips": flips,
		"solutions": ctx["count"], "nodes": ctx["nodes"]}


static func _search(board: LightBoard, assign: Dictionary, ctx: Dictionary) -> void:
	ctx["nodes"] = int(ctx["nodes"]) + 1
	if int(ctx["nodes"]) > int(ctx["budget"]):
		return
	var r := board._run(assign, true)
	if int(r["blooms_lit"]) > 0:
		return
	if r.has("branch"):
		var c: Vector2i = r["branch"]
		for tok in ["/", "\\"]:
			var a := assign.duplicate()
			a[c] = tok
			_search(board, a, ctx)
		return
	if not r["solved"]:
		return
	ctx["count"] = int(ctx["count"]) + 1
	var cost := 0
	for c in assign:
		if assign[c] != board.token_at(c):
			cost += 1
	if cost < int(ctx["best_cost"]):
		ctx["best_cost"] = cost
		ctx["best"] = assign


## Mirrors to tap from the current state towards `goal_state` (a mirror_state
## string from the level's stored solution).
static func taps_towards(board: LightBoard, goal_state: String) -> Array:
	var out: Array = []
	var ms := board.mirrors()
	for i in ms.size():
		if board.token_at(ms[i]) != goal_state[i]:
			out.append(ms[i])
	return out
