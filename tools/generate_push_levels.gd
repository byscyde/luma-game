extends Node
## Generates Stone Steps (Sokoban) levels with the real rules and solver: carve
## a terrace, put boulders on their sockets, then walk Luma backwards pulling
## boulders away (every reverse move is a legal forward move undone), and
## measure the shortest solution with PushSolver. Deterministic.
##   godot --headless --path . res://tools/generate_push_levels.tscn [-- --from=N --to=M]
## Output: resources/islands/stone_steps/levels/ss_lNN.json

const OUT := "res://resources/islands/stone_steps/levels"
const NAMES := ["First Stone", "Moss Step", "Tea Path", "Two Boulders", "Rice Terrace",
	"Old Spillway", "Mountain Tea", "Narrow Ledge", "Pebble Run", "Dragon Steps",
	"Stone Lantern", "Bamboo Gate", "Fog Terrace", "Three Stones", "Hidden Spring",
	"Cloud Steps", "Clay Wall", "Monk's Stair", "Pine Ridge", "Tea Garden",
	"Long Terrace", "Rockfall", "Waterwheel", "Mist Valley", "Crane Ledge",
	"Four Stones", "Temple Steps", "High Paddy", "Summit Dam", "Heart of the Steps"]

var rng := RandomNumberGenerator.new()


func spec(i: int) -> Dictionary:
	if i <= 3:
		return {"w": 6, "h": 6, "boulders": 1, "walls": 2, "min_par": 4 + i, "min_push": 2, "budget": 40000}
	if i <= 8:
		return {"w": 7, "h": 7, "boulders": 2, "walls": 3, "min_par": 10 + (i - 4), "min_push": 4, "budget": 80000}
	if i <= 15:
		return {"w": 7, "h": 8, "boulders": 2 if i < 12 else 3, "walls": 4, "min_par": 16 + (i - 9), "min_push": 6, "budget": 150000}
	if i <= 22:
		return {"w": 8, "h": 8, "boulders": 3, "walls": 5, "min_par": 24 + (i - 16), "min_push": 8, "budget": 250000}
	return {"w": 8, "h": 9, "boulders": 3 if i < 27 else 4, "walls": 7, "min_par": 32 + (i - 23) / 2, "min_push": 10 + (i - 23) / 2, "budget": 300000}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var first := 1
	var last := 30
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			first = int(a.substr(7))
		elif a.begins_with("--to="):
			last = int(a.substr(5))
	for i in range(first, last + 1):
		# keep the hardest of several valid candidates
		var lvl := {}
		var attempt := 0
		var found := 0
		var want := 40 if i <= 15 else (16 if i <= 22 else 4)
		while found < want:
			rng.seed = i * 4099 + attempt * 65537
			var cand := _make(i, spec(i))
			attempt += 1
			if not cand.is_empty():
				found += 1
				if lvl.is_empty() or float(cand["_score"]) > float(lvl["_score"]):
					lvl = cand
			if attempt > 6000:
				break
		if lvl.is_empty():
			push_error("could not generate level %d" % i)
			get_tree().quit(1)
			return
		var score: float = lvl["_score"]
		lvl.erase("_score")
		var f := FileAccess.open(OUT.path_join("ss_l%02d.json" % i), FileAccess.WRITE)
		f.store_string(JSON.stringify(lvl, "  ") + "\n")
		f.close()
		print("ss_l%02d  %dx%d boulders=%d par=%d pushes=%d score=%.1f attempts=%d" % [i, lvl["w"], lvl["h"],
			PushBoard.from_dict(lvl).boulders.size(), lvl["par"], lvl["pushes"], score, attempt])
	get_tree().quit(0)


func _make(i: int, s: Dictionary) -> Dictionary:
	var w: int = s["w"]
	var h: int = s["h"]
	var b := PushBoard.new()
	b.w = w
	b.h = h
	var inner: Array = []
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				b.walls[c] = true
			else:
				inner.append(c)
	_shuffle(inner)
	for k in int(s["walls"]):
		b.walls[inner[k]] = true
	var free: Array = []
	for c in inner:
		if not b.walls.has(c):
			free.append(c)
	if not _connected(b, free):
		return {}
	# solved state: boulders on sockets, Luma somewhere free
	for k in int(s["boulders"]):
		b.sockets[free[k]] = true
		b.boulders[free[k]] = true
	b.player = free[int(s["boulders"]) + rng.randi_range(0, free.size() - int(s["boulders"]) - 1)]
	# walk backwards: pulls drag a boulder from in front of Luma to where she stood
	var dirs: Array = PushBoard.DIRS.keys()
	for _k in 80 + int(s["min_par"]) * 8:
		var dir: String = dirs[rng.randi_range(0, 3)]
		var d: Vector2i = PushBoard.DIRS[dir]
		var to := b.player + d
		if not b.open(to) or b.boulders.has(to):
			continue
		var behind := b.player - d
		if b.boulders.has(behind) and rng.randf() < 0.85:
			b.boulders.erase(behind)
			b.boulders[b.player] = true
		b.player = to
	if b.filled() > 0 and int(s["boulders"]) <= 2:
		return {}
	if b.filled() > 1 or b.solved():
		return {}
	var r := PushSolver.solve(b, int(s["budget"]))
	if r["status"] != PushSolver.SOLVED:
		return {}
	var moves: Array = r["moves"]
	var stats := _push_stats(b, moves)
	var pushes: int = stats[0]
	if moves.size() < int(s["min_par"]) or moves.size() > int(s["min_par"]) * 2 + 6 or pushes < int(s["min_push"]):
		return {}
	var score: float = sqrt(float(r["expanded"])) + int(stats[1]) * 4.0 + pushes
	return {"format_version": 1, "id": "ss_l%02d" % i, "name": NAMES[i - 1], "island": "stone_steps",
		"w": w, "h": h, "grid": b.to_grid(), "par": moves.size(), "pushes": pushes, "solution": moves,
		"objectives": {"optional": [{"type": "moves_at_most", "value": moves.size() + 2 + moves.size() / 6}]},
		"rewards": {"essence": 14 + i, "cafe_coins": 7 + i * 2}, "_score": score}


## [pushes, switches]: how often the solution changes which boulder it pushes.
func _push_stats(start: PushBoard, moves: Array) -> Array:
	var b := start.duplicate_board()
	var n := 0
	var switches := 0
	var last := Vector2i(-99, -99)
	for m in moves:
		var at: Vector2i = b.player + PushBoard.DIRS[m]
		if b.step(m) == "push":
			n += 1
			if at != last:
				switches += 1
			last = at + (PushBoard.DIRS[m] as Vector2i)
	return [n, switches]


func _connected(b: PushBoard, free: Array) -> bool:
	if free.is_empty():
		return false
	var seen := {free[0]: true}
	var queue: Array = [free[0]]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in PushBoard.DIRS.values():
			var n: Vector2i = c + d
			if b.open(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen.size() == free.size()


func _shuffle(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = a[k]
		a[k] = a[j]
		a[j] = tmp
