class_name WaterSimulation
extends RefCounted
## Deterministic breadth-first water propagation. Independent of rendering and
## timing: a puzzle is solved the instant the logical result says so.

const LEAK_EDGE := "edge"           ## water runs off the board
const LEAK_BLOCKED := "blocked"     ## neighbour cannot hold water (rock, empty, switch)
const LEAK_MISMATCH := "mismatch"   ## neighbour holds water but has no opening facing us
const LEAK_CLOSED := "closed_gate"  ## neighbour is a closed gate


## `unknown` (index -> true) marks cells whose orientation is undecided; water
## stops in front of them and they are reported as frontier. Gameplay passes {}.
static func simulate(board: PuzzleBoard, unknown: Dictionary = {}) -> WaterResult:
	var res := WaterResult.new()
	res.required_targets = board.target_ids(false)
	var queue: Array[Vector2i] = []
	for s in board.sources():
		res.distance[s] = 0
		res.order.append(s)
		queue.append(s)
	var frontier_seen := {}
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var tile := board.get_tile(p)
		if not tile.transmits_water():
			continue
		var mask := board.effective_mask(p)
		for d in Dir.LIST:
			if not (mask & d):
				continue
			var n := p + Dir.offset(d)
			if not board.in_bounds(n):
				res.leaks.append({"pos": p, "dir": d, "reason": LEAK_EDGE})
				continue
			var ni := board.index_of(n)
			if unknown.has(ni):
				if not frontier_seen.has(ni):
					frontier_seen[ni] = true
					res.frontier.append(n)
				continue
			var nt := board.get_tile(n)
			if nt.is_source() and (board.effective_mask(n) & Dir.opposite(d)):
				continue  # joined back to a source outlet: sealed, not a leak
			if not nt.accepts_water():
				res.leaks.append({"pos": p, "dir": d, "reason": LEAK_BLOCKED})
				continue
			if nt.is_gate() and not board.is_gate_open(nt):
				res.leaks.append({"pos": p, "dir": d, "reason": LEAK_CLOSED})
				continue
			if not (board.effective_mask(n) & Dir.opposite(d)):
				res.leaks.append({"pos": p, "dir": d, "reason": LEAK_MISMATCH})
				continue
			# Each undirected connection is recorded once, from the side reached first.
			if not res.distance.has(n):
				res.distance[n] = int(res.distance[p]) + 1
				res.order.append(n)
				res.edges.append([p, n])
				queue.append(n)
			elif int(res.distance[n]) > int(res.distance[p]):
				res.edges.append([p, n])
	for p in res.order:
		var t := board.get_tile(p)
		if t.type == TileTypes.TARGET:
			res.reached_targets.append(t.target_id)
		elif t.type == TileTypes.BONUS:
			res.reached_bonus.append(t.target_id)
	res.all_required_reached = res.required_targets.size() > 0
	for id in res.required_targets:
		if not res.reached_targets.has(id):
			res.all_required_reached = false
			break
	return res
