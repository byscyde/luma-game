class_name MatchBoard
extends RefCounted
## Moon Grove rules (match-3 with restoration goals). Swap two neighbouring
## moonflowers to line up three or more of a kind; matched flowers bloom away,
## the ones above fall and new ones drop in from a deterministic generator, so
## a level replays exactly the same for the same swaps (CI replays the stored
## solution). Dark moss under a flower fades one layer when that flower is
## matched. Goals: clear all moss and/or gather flowers of some kinds within
## the move limit.
##
## Specials: four in a row -> a lantern that clears its row (made by a
## horizontal run) or column (vertical run); an L or T -> a seed bomb (3x3);
## five in a row -> a moon orb, which swapped with a flower clears every
## flower of that kind (orb + orb clears the board).
##
## Level data: {"w", "h", "kinds": int, "seed": int, "grid": rows of
## space-separated tokens ("0".."5" = kind, "#" = no cell), "moss": rows of
## digits (layers 0-2), "goals": {"moss": bool, "collect": {kind: count}},
## "moves": int}.

const NONE := -1
const HOLE := -2
const LINE_H := 1   ## clears its row
const LINE_V := 2   ## clears its column
const BOMB := 3
const ORB := 4

var w := 0
var h := 0
var kinds := 5
var cells: PackedInt32Array = []     ## kind per cell, NONE (empty) or HOLE
var special: PackedInt32Array = []   ## 0 or LINE_H / LINE_V / BOMB / ORB
var moss: PackedInt32Array = []
var collected: PackedInt32Array = [] ## flowers gathered per kind
var goal_moss := false
var goal_collect := {}               ## kind -> count
var moves_left := 0
var rng_state := 1
var last_events: Array = []          ## per cascade step: {"cleared": [Vector2i], "made": [[cell, special]]}


static func from_dict(d: Dictionary) -> MatchBoard:
	var b := MatchBoard.new()
	var rows: Array = d.get("grid", [])
	b.h = rows.size()
	b.w = str(rows[0]).split(" ", false).size() if b.h > 0 else 0
	b.kinds = int(d.get("kinds", 5))
	b.rng_state = int(d.get("seed", 1)) & 0x7fffffff
	for r in rows:
		for tok in str(r).split(" ", false):
			b.cells.append(HOLE if tok == "#" else int(tok))
	b.special.resize(b.w * b.h)
	b.special.fill(0)
	b.moss.resize(b.w * b.h)
	b.moss.fill(0)
	var mrows: Array = d.get("moss", [])
	for y in mrows.size():
		var row := str(mrows[y])
		for x in mini(row.length(), b.w):
			b.moss[y * b.w + x] = int(row[x])
	b.collected.resize(b.kinds)
	b.collected.fill(0)
	var g: Dictionary = d.get("goals", {})
	b.goal_moss = bool(g.get("moss", false))
	for k in g.get("collect", {}):
		b.goal_collect[int(k)] = int(g["collect"][k])
	b.moves_left = int(d.get("moves", 20))
	return b


func duplicate_board() -> MatchBoard:
	var b := MatchBoard.new()
	b.w = w
	b.h = h
	b.kinds = kinds
	b.cells = cells.duplicate()
	b.special = special.duplicate()
	b.moss = moss.duplicate()
	b.collected = collected.duplicate()
	b.goal_moss = goal_moss
	b.goal_collect = goal_collect
	b.moves_left = moves_left
	b.rng_state = rng_state
	return b


func idx(c: Vector2i) -> int:
	return c.y * w + c.x


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


func kind_at(c: Vector2i) -> int:
	return cells[idx(c)]


func special_at(c: Vector2i) -> int:
	return special[idx(c)]


func playable(c: Vector2i) -> bool:
	return inside(c) and cells[idx(c)] >= 0


func _rand(n: int) -> int:
	rng_state = (rng_state * 1103515245 + 12345) & 0x7fffffff
	return (rng_state >> 8) % n


# ------------------------------------------------------------------ goals

func moss_left() -> int:
	var n := 0
	for v in moss:
		n += v
	return n


func goals_met() -> bool:
	if goal_moss and moss_left() > 0:
		return false
	for k in goal_collect:
		if collected[k] < int(goal_collect[k]):
			return false
	return true


func lost() -> bool:
	return moves_left <= 0 and not goals_met()


# ------------------------------------------------------------------ moves

## Whether swapping a and b makes something happen (a match or a moon orb).
func valid_swap(a: Vector2i, b: Vector2i) -> bool:
	if not playable(a) or not playable(b) or absi(a.x - b.x) + absi(a.y - b.y) != 1:
		return false
	if special_at(a) == ORB or special_at(b) == ORB:
		return true
	if special_at(a) != 0 and special_at(b) != 0:
		return true
	_swap_cells(a, b)
	var ok := _has_run_at(a) or _has_run_at(b)
	_swap_cells(a, b)
	return ok


func all_valid_swaps() -> Array:
	var out: Array = []
	for y in h:
		for x in w:
			var a := Vector2i(x, y)
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				if valid_swap(a, a + d):
					out.append([a, a + d])
	return out


## Plays one swap: resolves every cascade, counts a move. Returns false (and
## changes nothing) for a swap that does nothing or when out of moves.
func swap(a: Vector2i, b: Vector2i) -> bool:
	if moves_left <= 0 or not valid_swap(a, b):
		return false
	moves_left -= 1
	last_events = []
	var sa := special_at(a)
	var sb := special_at(b)
	_swap_cells(a, b)
	# a = where the first flower went (b's old cell), b = the other
	if sa == ORB or sb == ORB:
		var orb_cell := b if sa == ORB else a
		var other := a if sa == ORB else b
		var clear := {}
		if sa == ORB and sb == ORB:
			for i in cells.size():
				if cells[i] >= 0:
					clear[Vector2i(i % w, i / w)] = true
		else:
			var k := kind_at(other)
			var os := special_at(other)
			clear[orb_cell] = true
			for i in cells.size():
				if cells[i] == k:
					clear[Vector2i(i % w, i / w)] = true
					if os == LINE_H or os == LINE_V:
						special[i] = LINE_H if (i % 2 == 0) else LINE_V
		special[idx(orb_cell)] = 0
		_clear_cells(clear.keys(), [])
		_settle()
	elif sa != 0 and sb != 0:
		# two specials: both go off, plus a cross through the meeting point
		var clear := {a: true, b: true}
		for x in w:
			clear[Vector2i(x, b.y)] = true
		for y in h:
			clear[Vector2i(b.x, y)] = true
		_clear_cells(clear.keys(), [])
		_settle()
	else:
		_resolve([a, b])
	ensure_moves()
	return true


func _swap_cells(a: Vector2i, b: Vector2i) -> void:
	var ia := idx(a)
	var ib := idx(b)
	var k := cells[ia]
	cells[ia] = cells[ib]
	cells[ib] = k
	var s := special[ia]
	special[ia] = special[ib]
	special[ib] = s


func _has_run_at(c: Vector2i) -> bool:
	var k := kind_at(c)
	if k < 0:
		return false
	var n := 1
	var x := c.x - 1
	while x >= 0 and cells[c.y * w + x] == k:
		n += 1
		x -= 1
	x = c.x + 1
	while x < w and cells[c.y * w + x] == k:
		n += 1
		x += 1
	if n >= 3:
		return true
	n = 1
	var y := c.y - 1
	while y >= 0 and cells[y * w + c.x] == k:
		n += 1
		y -= 1
	y = c.y + 1
	while y < h and cells[y * w + c.x] == k:
		n += 1
		y += 1
	return n >= 3


## Runs of 3+ as arrays of cells: [cells, horizontal: bool].
func find_runs() -> Array:
	var runs: Array = []
	for y in h:
		var x := 0
		while x < w:
			var k := cells[y * w + x]
			var e := x + 1
			while e < w and k >= 0 and cells[y * w + e] == k:
				e += 1
			if k >= 0 and e - x >= 3:
				var r: Array = []
				for i in range(x, e):
					r.append(Vector2i(i, y))
				runs.append([r, true])
			x = e
	for x in w:
		var y := 0
		while y < h:
			var k := cells[y * w + x]
			var e := y + 1
			while e < h and k >= 0 and cells[e * w + x] == k:
				e += 1
			if k >= 0 and e - y >= 3:
				var r: Array = []
				for i in range(y, e):
					r.append(Vector2i(x, i))
				runs.append([r, false])
			y = e
	return runs


## Resolves matches until the board is still. `focus` are the swapped cells
## (where a special appears when the run includes one).
func _resolve(focus: Array) -> void:
	var first := true
	while true:
		var runs := find_runs()
		if runs.is_empty():
			return
		var clear := {}
		var made: Array = []
		var used := {}
		# L / T shapes: a horizontal and a vertical run sharing a cell
		for i in runs.size():
			if not runs[i][1]:
				continue
			for j in runs.size():
				if runs[j][1]:
					continue
				for c in runs[i][0]:
					if (runs[j][0] as Array).has(c) and not used.has(i) and not used.has(j):
						used[i] = true
						used[j] = true
						made.append([c, BOMB, kind_at(c)])
		for i in runs.size():
			var r: Array = runs[i][0]
			for c in r:
				clear[c] = true
			if used.has(i):
				continue
			if r.size() >= 4:
				var at: Vector2i = r[r.size() / 2]
				if first:
					for f in focus:
						if r.has(f):
							at = f
				made.append([at, ORB if r.size() >= 5 else (LINE_H if runs[i][1] else LINE_V), kind_at(at)])
		_clear_cells(clear.keys(), made)
		_settle()
		first = false


## Clears cells (setting off any specials among them), fades moss, counts
## flowers, then places the newly made specials.
func _clear_cells(start: Array, made: Array) -> void:
	var clear := {}
	var queue: Array = start.duplicate()
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if clear.has(c) or not playable(c):
			continue
		clear[c] = true
		var sp := special_at(c)
		if sp == LINE_H:
			for x in w:
				queue.append(Vector2i(x, c.y))
		elif sp == LINE_V:
			for y in h:
				queue.append(Vector2i(c.x, y))
		elif sp == BOMB:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					queue.append(c + Vector2i(dx, dy))
		elif sp == ORB:
			var k := kind_at(c)
			for i in cells.size():
				if cells[i] == k:
					queue.append(Vector2i(i % w, i / w))
	var cleared: Array = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if not clear.has(c):
				continue
			var i := idx(c)
			cleared.append(c)
			if moss[i] > 0:
				moss[i] -= 1
			if cells[i] >= 0 and cells[i] < kinds:
				collected[cells[i]] += 1
			cells[i] = NONE
			special[i] = 0
	for m in made:
		var i := idx(m[0])
		cells[i] = int(m[2])
		special[i] = int(m[1])
	last_events.append({"cleared": cleared, "made": made})


## Gravity, then refill from the top with the deterministic generator.
func _settle() -> void:
	for x in w:
		var write := h - 1
		for y in range(h - 1, -1, -1):
			var i := y * w + x
			if cells[i] == HOLE:
				write = y - 1
				continue
			if cells[i] >= 0:
				if write != y:
					var j := write * w + x
					cells[j] = cells[i]
					special[j] = special[i]
					cells[i] = NONE
					special[i] = 0
				write -= 1
		for y in h:
			var i := y * w + x
			if cells[i] == NONE:
				cells[i] = _rand(kinds)


## Something to swap exists; if not, the flowers are reshuffled in place
## (deterministically) until one does.
func ensure_moves() -> void:
	var guard := 0
	while all_valid_swaps().is_empty() and guard < 50:
		guard += 1
		for i in cells.size():
			if cells[i] >= 0 and special[i] == 0:
				cells[i] = _rand(kinds)
		_resolve([])


func to_grid() -> Array:
	var out: Array = []
	for y in h:
		var row: Array = []
		for x in w:
			var v := cells[y * w + x]
			row.append("#" if v == HOLE else str(v))
		out.append(" ".join(row))
	return out
