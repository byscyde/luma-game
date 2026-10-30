extends Node
## Generates Ember Reef (sliding blocks) levels with the real rules and solver:
## build a solved grid from random channel paths, add decoys, scramble with
## legal moves, then measure the shortest solution with SlideSolver (falls back
## to the scramble length when the search budget is exceeded). Deterministic.
##   godot --headless --path . res://tools/generate_slide_levels.tscn [-- --from=N --to=M]
## Output: resources/islands/ember_reef/levels/er_lNN.json

const OUT := "res://resources/islands/ember_reef/levels"
const NAMES := ["First Current", "Warm Tide", "Coral Turn", "Ember Path", "Sea Glass", "Driftway",
	"Twin Shoals", "Kelp Maze", "Red Lagoon", "Salt Steps", "Lava Rock", "Tidal Lock",
	"Sunken Arch", "Fire Coral", "Ash Beach", "Split Stream", "Crab Crossing", "Reef Knot",
	"Steam Vent", "Glow Pools", "Deep Ember", "Clam Garden", "Coral Crown", "Magma Bay",
	"Twin Vents", "Pearl Run", "Smoke Reef", "Lantern Shoal", "Cinder Tide", "Heart of Embers"]

## level index (1-based) -> spec
func spec(i: int) -> Dictionary:
	if i <= 3:
		return {"w": 3, "h": 3, "targets": 1, "scramble": 1, "min_par": 1, "decoys": 0.0, "rocks": 0, "locks": 0}
	if i <= 6:
		return {"w": 3, "h": 3, "targets": 1, "scramble": 2, "min_par": 2, "decoys": 0.4, "rocks": 0, "locks": 0}
	if i <= 10:
		return {"w": 4, "h": 4, "targets": 1, "scramble": 3, "min_par": 2, "decoys": 0.5, "rocks": 0, "locks": 0}
	if i <= 15:
		return {"w": 4, "h": 4, "targets": 1, "scramble": 4, "min_par": 3, "decoys": 0.6, "rocks": 1, "locks": 1 if i >= 13 else 0}
	if i <= 20:
		return {"w": 5, "h": 4, "targets": 2, "scramble": 4, "min_par": 3, "decoys": 0.6, "rocks": 1, "locks": 1}
	if i <= 25:
		return {"w": 5, "h": 5, "targets": 2, "scramble": 5, "min_par": 4, "decoys": 0.7, "rocks": 2, "locks": 1}
	return {"w": 5, "h": 5, "targets": 2 if i < 28 else 3, "scramble": 6, "min_par": 5, "decoys": 0.75, "rocks": 2, "locks": 2}


var rng := RandomNumberGenerator.new()


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
		var lvl := {}
		var attempt := 0
		while lvl.is_empty():
			rng.seed = i * 7919 + attempt * 104729
			lvl = _make(i, spec(i))
			attempt += 1
			if attempt > 400:
				push_error("could not generate level %d" % i)
				get_tree().quit(1)
				return
		var path := OUT.path_join("er_l%02d.json" % i)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(lvl, "  ") + "\n")
		f.close()
		print("er_l%02d  %dx%d targets=%d par=%d proven=%s" % [i, lvl["w"], lvl["h"], (lvl["targets"] as Array).size(), lvl["par"], lvl["par_proven"]])
	get_tree().quit(0)


func _side_cell(side: String, index: int, w: int, h: int) -> Vector2i:
	match side:
		"W":
			return Vector2i(0, index)
		"E":
			return Vector2i(w - 1, index)
		"N":
			return Vector2i(index, 0)
		_:
			return Vector2i(index, h - 1)


func _outward(side: String) -> int:
	return {"W": Dir.W, "E": Dir.E, "N": Dir.N, "S": Dir.S}[side]


func _make(i: int, sp: Dictionary) -> Dictionary:
	var w: int = sp["w"]
	var h: int = sp["h"]
	var sides := ["W", "E", "N", "S"]
	var src_side: String = sides[rng.randi_range(0, 3)]
	var used := {}
	var src_idx := rng.randi_range(0, (h if src_side in ["W", "E"] else w) - 1)
	used[src_side + str(src_idx)] = true
	var targets: Array = []
	var masks := {}
	var entry := _side_cell(src_side, src_idx, w, h)
	masks[entry] = _outward(src_side)
	var network: Array[Vector2i] = [entry]
	for t in sp["targets"]:
		var side: String = sides[rng.randi_range(0, 3)]
		if side == src_side and rng.randf() < 0.7:
			side = sides[(sides.find(src_side) + 1 + rng.randi_range(0, 2)) % 4]
		var idx := rng.randi_range(0, (h if side in ["W", "E"] else w) - 1)
		if used.has(side + str(idx)):
			return {}
		used[side + str(idx)] = true
		var exit := _side_cell(side, idx, w, h)
		var start: Vector2i = network[rng.randi_range(0, network.size() - 1)] if t > 0 else entry
		var path := _walk(start, exit, w, h, masks, t > 0)
		if path.is_empty():
			return {}
		for k in path.size() - 1:
			var a: Vector2i = path[k]
			var b: Vector2i = path[k + 1]
			masks[a] = int(masks.get(a, 0)) | _dir_to(a, b)
			masks[b] = int(masks.get(b, 0)) | _dir_to(b, a)
			if not network.has(b):
				network.append(b)
		masks[exit] = int(masks.get(exit, 0)) | _outward(side)
		targets.append({"side": side, "index": idx, "id": "T%d" % (t + 1)})
	# masks -> tokens
	var cells := PackedStringArray()
	cells.resize(w * h)
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			if masks.has(c):
				var tok := _token_for(int(masks[c]))
				if tok == "":
					return {}
				cells[y * w + x] = tok
			else:
				cells[y * w + x] = "."
	# decoys and rocks on free cells
	var free: Array[int] = []
	for k in cells.size():
		if cells[k] == ".":
			free.append(k)
	for k in free:
		if rng.randf() < float(sp["decoys"]):
			cells[k] = ["I", "L", "L", "Y"][rng.randi_range(0, 3 if i > 10 else 2)] + str(rng.randi_range(0, 3))
	for r in sp["rocks"]:
		if free.is_empty():
			break
		cells[free[rng.randi_range(0, free.size() - 1)]] = "#"
	var grid: Array = []
	for y in h:
		grid.append(" ".join(cells.slice(y * w, y * w + w)))
	var d := {"grid": grid, "source": {"side": src_side, "index": src_idx}, "targets": targets,
		"locked_rows": [], "locked_cols": []}
	var b := SlideBoard.from_dict(d)
	if not b.solved():
		return {}
	# locks: lines that do not need to move in the scramble
	var lockable: Array = []
	for y in h:
		lockable.append(["r", y])
	for x in w:
		lockable.append(["c", x])
	var locks: Array = []
	for n in sp["locks"]:
		var l: Array = lockable[rng.randi_range(0, lockable.size() - 1)]
		if not locks.has(l):
			locks.append(l)
	for l in locks:
		if l[0] == "r":
			d["locked_rows"].append(l[1])
		else:
			d["locked_cols"].append(l[1])
	b = SlideBoard.from_dict(d)
	# scramble with legal moves, never undoing the previous one
	var moves := b.legal_moves()
	var scramble: Array = []
	for n in sp["scramble"]:
		var m: Array = moves[rng.randi_range(0, moves.size() - 1)]
		if not scramble.is_empty() and m == SlideBoard.inverse(scramble.back()):
			m = moves[(moves.find(m) + 2) % moves.size()]
		b.apply(m)
		scramble.append(m)
	if b.solved():
		return {}
	d["grid"] = b.to_grid()
	# big boards: a smaller search budget; when it runs out, the (replayed) scramble is the par
	var sol := SlideSolver.solve(b, 120000 if i <= 26 else 25000, int(sp["scramble"]))
	var proven: bool = sol["status"] == SlideSolver.SOLVED
	var solution: Array = sol["moves"] if proven else _inverse_all(scramble)
	if solution.size() < int(sp["min_par"]):
		return {}
	# replay the stored solution with the real rules
	var check := SlideBoard.from_dict(d)
	for m in solution:
		check.apply(m)
	if not check.solved():
		return {}
	return {"format_version": 1, "id": "er_l%02d" % i, "name": NAMES[i - 1], "island": "ember_reef",
		"w": w, "h": h, "grid": d["grid"], "source": d["source"], "targets": targets,
		"locked_rows": d["locked_rows"], "locked_cols": d["locked_cols"],
		"par": solution.size(), "par_proven": proven, "solution": solution,
		"objectives": {"optional": [{"type": "moves_at_most", "value": solution.size() + (1 if i <= 10 else 2)}]},
		"rewards": {"essence": 10 + i, "cafe_coins": 5 + i * 2}}


func _inverse_all(moves: Array) -> Array:
	var out: Array = []
	for k in range(moves.size() - 1, -1, -1):
		out.append(SlideBoard.inverse(moves[k]))
	return out


func _dir_to(a: Vector2i, b: Vector2i) -> int:
	for d in Dir.LIST:
		if Dir.offset(d) == b - a:
			return d
	return 0


## Random self-avoiding walk from start to goal through cells not yet used by
## the network (except the start). Returns the cell list or [].
func _walk(start: Vector2i, goal: Vector2i, w: int, h: int, masks: Dictionary, branch: bool) -> Array:
	for tries in 60:
		var path: Array = [start]
		var seen := {start: true}
		var cur := start
		var ok := false
		for step in w * h * 2:
			if cur == goal:
				ok = true
				break
			var opts: Array = []
			for d in Dir.LIST:
				var n := cur + Dir.offset(d)
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen.has(n):
					continue
				if masks.has(n) and n != goal:
					continue
				if n == goal and masks.has(n):
					continue
				opts.append(n)
			if opts.is_empty():
				break
			# bias toward the goal, with some wandering
			opts.sort_custom(func(a, b): return (a - goal).length_squared() < (b - goal).length_squared())
			var pick: Vector2i = opts[0] if rng.randf() < 0.6 else opts[rng.randi_range(0, opts.size() - 1)]
			path.append(pick)
			seen[pick] = true
			cur = pick
		if ok and path.size() >= 2 and (not branch or Dir.count(int(masks.get(start, 0))) < 3):
			return path
		if ok and path.size() == 1 and not branch:
			return path
	return []


## Channel token whose openings equal `mask`, or "" if no tile has them.
func _token_for(mask: int) -> String:
	for t in [["I", TileTypes.STRAIGHT], ["L", TileTypes.ELBOW], ["Y", TileTypes.TEE]]:
		for r in 4:
			if Dir.rotate_mask(TileTypes.base_mask(t[1]), r) == mask:
				return "%s%d" % [t[0], r]
	if mask == Dir.ALL:
		return "+"
	return ""
