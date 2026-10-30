class_name SlideSolver
extends RefCounted
## Breadth-first search over SlideBoard states: finds a shortest move list
## that makes water reach every target, within a state budget.

const SOLVED := "solved"
const UNSOLVABLE := "unsolvable"
const BUDGET_EXCEEDED := "budget"


## Returns {"status", "moves": Array, "expanded": int}.
static func solve(board: SlideBoard, budget: int = 60000, max_depth: int = 30) -> Dictionary:
	var b := board.duplicate_board()
	if b.solved():
		return {"status": SOLVED, "moves": [], "expanded": 0}
	var start := b.snapshot()
	var parent: Dictionary = {b.key(): null}
	var frontier: Array = [[start, 0]]
	var head := 0
	var moves := b.legal_moves()
	while head < frontier.size():
		var node: Array = frontier[head]
		head += 1
		if head > budget:
			return {"status": BUDGET_EXCEEDED, "moves": [], "expanded": head}
		if int(node[1]) >= max_depth:
			continue
		for m in moves:
			b.restore(node[0])
			b.apply(m)
			var k := b.key()
			if parent.has(k):
				continue
			parent[k] = [",".join(node[0]), m]
			if b.solved():
				return {"status": SOLVED, "moves": _path(parent, k), "expanded": head}
			frontier.append([b.snapshot(), int(node[1]) + 1])
	return {"status": UNSOLVABLE, "moves": [], "expanded": head}


static func _path(parent: Dictionary, k: String) -> Array:
	var out: Array = []
	var cur := k
	while parent[cur] != null:
		out.push_front(parent[cur][1])
		cur = parent[cur][0]
	return out


## First move of a shortest solution from the current state, or [] if none
## is found within the (small) budget.
static func hint(board: SlideBoard, budget: int = 8000) -> Array:
	var r := solve(board, budget)
	return r["moves"][0] if r["status"] == SOLVED and not (r["moves"] as Array).is_empty() else []
