class_name PuzzleSolver
extends RefCounted
## Bounded, deterministic solver. Finds the minimum number of taps that makes
## water reach every required target.
##
## Search: uniform-cost search over *partial* assignments. Only tiles that water
## actually reaches matter, so we flood from the sources treating undecided
## rotatable tiles as walls (the frontier), branch on the first frontier tile's
## distinct orientations, and repeat. Water reach is monotone in the set of
## decided tiles, so the first goal popped is optimal. Switch states are decided
## up front (2^k combinations, k is tiny). The expansion budget keeps the solver
## bounded; exceeding it yields status "unverified", never a guess.

const STATUS_SOLVED := "solved"
const STATUS_IMPOSSIBLE := "impossible"
const STATUS_UNVERIFIED := "unverified"
const DEFAULT_BUDGET := 200000

## Goals: required targets only; required + every bonus target; required with
## no water spilling anywhere (a fully sealed network).
const GOAL_REQUIRED := 0
const GOAL_WITH_BONUS := 1
const GOAL_NO_LEAKS := 2


class SearchNode:
	var cost: int
	var seq: int
	var assign: Dictionary  ## tile index -> rotation
	var switches: Dictionary

	func _init(c: int, s: int, a: Dictionary, sw: Dictionary) -> void:
		cost = c
		seq = s
		assign = a
		switches = sw


## Returns {status, moves, rotations: {index: rot}, switches: {link: bool},
##          taps: [Vector2i...], expansions}
static func solve(board: PuzzleBoard, budget: int = DEFAULT_BUDGET, goal: int = GOAL_REQUIRED) -> Dictionary:
	var work := board.duplicate_board()
	var bonus_ids := board.target_ids(true).filter(func(id): return id.begins_with("B"))
	var rotatable: Dictionary = {}  # index -> true
	for i in work.tiles.size():
		if work.tiles[i].is_rotatable():
			rotatable[i] = true
	var links: Array = work.switches.keys()
	links.sort()
	var heap: Array = []
	var seq := 0
	var seen := {}
	for combo in (1 << links.size()):
		var sw := {}
		var cost := 0
		for k in links.size():
			var flip := (combo >> k) & 1 == 1
			sw[links[k]] = bool(board.switches[links[k]]) != flip
			if flip:
				cost += 1
		_heap_push(heap, SearchNode.new(cost, seq, {}, sw))
		seq += 1
	var expansions := 0
	while not heap.is_empty():
		var node: SearchNode = _heap_pop(heap)
		var key := _key(node)
		if seen.has(key):
			continue
		seen[key] = true
		expansions += 1
		if expansions > budget:
			return {"status": STATUS_UNVERIFIED, "expansions": expansions}
		# Apply node state to work board.
		work.switches = node.switches.duplicate()
		var unknown := {}
		for i in rotatable:
			if node.assign.has(i):
				work.tiles[i].rotation = node.assign[i]
			else:
				unknown[i] = true
		var sim := WaterSimulation.simulate(work, unknown)
		if goal == GOAL_NO_LEAKS and sim.leak_count() > 0:
			continue  # leaks between decided tiles can never be repaired
		if _goal_met(sim, goal, bonus_ids):
			return _finish(board, node, expansions)
		if sim.frontier.is_empty():
			continue
		var f: Vector2i = sim.frontier[0]
		var fi := work.index_of(f)
		var tile: PuzzleTile = board.tiles[fi]
		for r in tile.distinct_rotations():
			# cheapest tap count to reach any rotation with the same openings
			var best := 4
			var mask := tile.shape_mask_at(r)
			for rr in 4:
				if tile.shape_mask_at(rr) == mask:
					best = mini(best, posmod(rr - tile.rotation, 4))
			var a := node.assign.duplicate()
			a[fi] = posmod(tile.rotation + best, 4)
			_heap_push(heap, SearchNode.new(node.cost + best, seq, a, node.switches))
			seq += 1
	return {"status": STATUS_IMPOSSIBLE, "expansions": expansions}


static func _goal_met(sim: WaterResult, goal: int, bonus_ids: Array) -> bool:
	if not sim.all_required_reached:
		return false
	match goal:
		GOAL_WITH_BONUS:
			for id in bonus_ids:
				if not sim.reached_bonus.has(id):
					return false
		GOAL_NO_LEAKS:
			# undecided tiles water would enter could still spill
			return sim.frontier.is_empty()
	return true


static func _finish(board: PuzzleBoard, node: SearchNode, expansions: int) -> Dictionary:
	var taps: Array[Vector2i] = []
	var links: Array = node.switches.keys()
	links.sort()
	for link in links:
		if bool(node.switches[link]) != bool(board.switches.get(link, false)):
			for i in board.tiles.size():
				var t := board.tiles[i]
				if t.is_toggle() and t.link == link:
					taps.append(board.pos_of(i))
					break
	var idx: Array = node.assign.keys()
	idx.sort()
	for i in idx:
		var n := posmod(int(node.assign[i]) - board.tiles[i].rotation, 4)
		for k in n:
			taps.append(board.pos_of(i))
	return {
		"status": STATUS_SOLVED,
		"moves": node.cost,
		"rotations": node.assign,
		"switches": node.switches,
		"taps": taps,
		"expansions": expansions,
	}


## Next helpful tap from the board's current state, or null-equivalent (-1,-1).
static func hint(board: PuzzleBoard, budget: int = 40000) -> Vector2i:
	var r := solve(board, budget)
	if r.get("status") != STATUS_SOLVED or (r["taps"] as Array).is_empty():
		return Vector2i(-1, -1)
	return r["taps"][0]


static func _key(n: SearchNode) -> String:
	var idx: Array = n.assign.keys()
	idx.sort()
	var parts := PackedStringArray()
	for i in idx:
		parts.append("%d:%d" % [i, n.assign[i]])
	var links: Array = n.switches.keys()
	links.sort()
	for l in links:
		parts.append("%s=%d" % [l, int(n.switches[l])])
	return ",".join(parts)


static func _less(a: SearchNode, b: SearchNode) -> bool:
	if a.cost != b.cost:
		return a.cost < b.cost
	return a.seq < b.seq


static func _heap_push(h: Array, n: SearchNode) -> void:
	h.append(n)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if _less(h[i], h[p]):
			var tmp = h[i]
			h[i] = h[p]
			h[p] = tmp
			i = p
		else:
			break


static func _heap_pop(h: Array) -> SearchNode:
	var top: SearchNode = h[0]
	var last: SearchNode = h.pop_back()
	if not h.is_empty():
		h[0] = last
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < h.size() and _less(h[l], h[m]):
				m = l
			if r < h.size() and _less(h[r], h[m]):
				m = r
			if m == i:
				break
			var tmp = h[i]
			h[i] = h[m]
			h[m] = tmp
			i = m
	return top
