class_name PushSolver
extends RefCounted
## Breadth-first search over PushBoard states (Luma's cell + boulder cells):
## finds a shortest list of steps that fills every socket, within a state
## budget. Pushes onto "dead" cells (from which no boulder can ever reach a
## socket) are pruned; this never removes a solution.

const SOLVED := "solved"
const UNSOLVABLE := "unsolvable"
const BUDGET_EXCEEDED := "budget"


## Cells a boulder can stand on and still reach some socket (reverse pulls).
static func live_cells(b: PushBoard) -> Dictionary:
	var live := {}
	var queue: Array = []
	for s in b.sockets:
		live[s] = true
		queue.append(s)
	var head := 0
	while head < queue.size():
		var q: Vector2i = queue[head]
		head += 1
		for d in PushBoard.DIRS.values():
			var from: Vector2i = q - d          # boulder came from here...
			var stand: Vector2i = q - d * 2     # ...pushed by Luma standing here
			if b.open(from) and b.open(stand) and not live.has(from):
				live[from] = true
				queue.append(from)
	return live


## Returns {"status", "moves": Array of directions, "expanded": int}.
static func solve(board: PushBoard, budget: int = 200000) -> Dictionary:
	var b := board.duplicate_board()
	if b.solved():
		return {"status": SOLVED, "moves": [], "expanded": 0}
	var live := live_cells(b)
	var start_key := b.key()
	var parent := {start_key: null}
	var frontier: Array = [[b.player, b.boulders.duplicate()]]
	var head := 0
	while head < frontier.size():
		var node: Array = frontier[head]
		head += 1
		if head > budget:
			return {"status": BUDGET_EXCEEDED, "moves": [], "expanded": head}
		var pk := _key(node[0], node[1])
		for dir in PushBoard.DIRS:
			b.player = node[0]
			b.boulders = node[1]
			var d: Vector2i = PushBoard.DIRS[dir]
			var n: Vector2i = b.player + d
			if not b.open(n):
				continue
			var nb: Dictionary = node[1]
			if nb.has(n):
				var beyond := n + d
				if not b.open(beyond) or nb.has(beyond) or not live.has(beyond):
					continue
				nb = nb.duplicate()
				nb.erase(n)
				nb[beyond] = true
			var k := _key(n, nb)
			if parent.has(k):
				continue
			parent[k] = [pk, dir]
			b.player = n
			b.boulders = nb
			if b.solved():
				return {"status": SOLVED, "moves": _path(parent, k), "expanded": head}
			frontier.append([n, nb])
	return {"status": UNSOLVABLE, "moves": [], "expanded": head}


static func _key(p: Vector2i, bs: Dictionary) -> String:
	var cells: Array = bs.keys()
	cells.sort()
	return "%d,%d|%s" % [p.x, p.y, str(cells)]


static func _path(parent: Dictionary, k: String) -> Array:
	var out: Array = []
	var cur := k
	while parent[cur] != null:
		out.push_front(parent[cur][1])
		cur = parent[cur][0]
	return out
