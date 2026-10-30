class_name BridgeSolver
extends RefCounted
## Exhaustive solver for BridgeBoard: assigns 0/1/2 bridges link by link with
## pruning (an islet never exceeds its number and can still reach it; crossing
## links are exclusive) and checks connectivity at the leaves. Counts
## solutions up to `limit`, so the generator can insist on a unique answer.

const SOLVED := "solved"
const UNSOLVABLE := "unsolvable"
const BUDGET_EXCEEDED := "budget"


## Returns {"status", "state": PackedInt32Array (first solution), "solutions": int,
## "nodes": int, "complete": bool (false when the budget stopped the count early)}.
static func solve(board: BridgeBoard, limit: int = 2, budget: int = 400000) -> Dictionary:
	var b := board.duplicate_board()
	b.state.fill(0)
	var n := b.islands.size()
	# per islet: links touching it
	var touch: Array = []
	for i in n:
		touch.append([])
	for k in b.links.size():
		touch[b.links[k][0]].append(k)
		touch[b.links[k][1]].append(k)
	var ctx := {"count": 0, "first": PackedInt32Array(), "nodes": 0, "limit": limit, "budget": budget,
		"touch": touch, "deg": [], "blocked": []}
	# plain Arrays: packed arrays are copied on assignment, these must be shared
	(ctx["deg"] as Array).resize(n)
	(ctx["deg"] as Array).fill(0)
	(ctx["blocked"] as Array).resize(b.links.size())
	(ctx["blocked"] as Array).fill(0)
	_dfs(b, 0, ctx)
	var status := SOLVED if int(ctx["count"]) > 0 else UNSOLVABLE
	if int(ctx["nodes"]) > budget and int(ctx["count"]) < limit:
		status = BUDGET_EXCEEDED if int(ctx["count"]) == 0 else SOLVED
	return {"status": status, "state": ctx["first"], "solutions": ctx["count"], "nodes": ctx["nodes"],
		"complete": int(ctx["nodes"]) <= budget or int(ctx["count"]) >= limit}


static func _dfs(b: BridgeBoard, k: int, ctx: Dictionary) -> void:
	if int(ctx["count"]) >= int(ctx["limit"]) or int(ctx["nodes"]) > int(ctx["budget"]):
		return
	ctx["nodes"] = int(ctx["nodes"]) + 1
	var deg: Array = ctx["deg"]
	var blocked: Array = ctx["blocked"]
	if k == b.links.size():
		for i in b.islands.size():
			if int(deg[i]) != b.need(i):
				return
		if b.connected():
			if int(ctx["count"]) == 0:
				ctx["first"] = b.state.duplicate()
			ctx["count"] = int(ctx["count"]) + 1
		return
	var a: int = b.links[k][0]
	var c: int = b.links[k][1]
	var top: int = 0 if int(blocked[k]) > 0 else mini(2, mini(b.need(a) - int(deg[a]), b.need(c) - int(deg[c])))
	for v in range(top, -1, -1):
		b.state[k] = v
		deg[a] += v
		deg[c] += v
		if v > 0:
			for j in b.crossings(k):
				blocked[j] += 1
		if _feasible(b, k, a, ctx) and _feasible(b, k, c, ctx):
			_dfs(b, k + 1, ctx)
		if v > 0:
			for j in b.crossings(k):
				blocked[j] -= 1
		deg[a] -= v
		deg[c] -= v
		b.state[k] = 0
		if int(ctx["count"]) >= int(ctx["limit"]):
			return


## Islet i can still reach its number with the links after k.
static func _feasible(b: BridgeBoard, k: int, i: int, ctx: Dictionary) -> bool:
	var deg: Array = ctx["deg"]
	var blocked: Array = ctx["blocked"]
	var room := 0
	for j in ctx["touch"][i]:
		if j > k and int(blocked[j]) == 0:
			room += 2
	var left: int = b.need(i) - int(deg[i])
	return left >= 0 and left <= room
