extends Node
## Generates Lantern Bay (mirrors & light) levels with the real rules and solver:
## place lanterns, mirrors, rocks and prisms; pick a goal mirror state and put
## crystals on its beam and night blooms where other states would shine; then
## scramble the round mirrors and measure par (fewest taps) with LightSolver.
## Deterministic.
##   godot --headless --path . res://tools/generate_light_levels.tscn [-- --from=N --to=M]
## Output: resources/islands/lantern_bay/levels/lb_lNN.json

const OUT := "res://resources/islands/lantern_bay/levels"
const NAMES := ["First Light", "Harbour Glow", "Turning Glass", "Night Ferry", "Beacon Steps",
	"Silver Wake", "Two Crystals", "Moth Lane", "Lamplighter", "Glass Harbour",
	"Night Bloom", "Mirror Pier", "Keeper's Path", "Moonlit Dock", "Quiet Lens",
	"First Prism", "Split Beam", "Fog Bank", "Signal Rock", "Tide Lamps",
	"Lantern Row", "Crystal Cove", "Twin Beacons", "Starlit Maze", "Bloom Garden",
	"Prism Reef", "Keeper's Watch", "Aurora Cliffs", "Long Night", "Heart of the Bay"]

var rng := RandomNumberGenerator.new()


## level index (1-based) -> spec
func spec(i: int) -> Dictionary:
	var s := {"w": 4, "h": 4, "rot": 1 + mini(i - 1, 1), "fixed": 0, "rocks": 0, "crystals": 1, "blooms": 0,
		"prisms": 0, "lanterns": 1, "min_par": 1, "max_par": 2, "max_solutions": 6}
	if i <= 3:
		return s
	if i <= 6:
		s.merge({"w": 4, "h": 5, "rot": 3, "fixed": 1, "rocks": 1, "min_par": 2, "max_par": 3}, true)
	elif i <= 10:
		s.merge({"w": 5, "h": 5, "rot": 4, "fixed": 1, "rocks": 2, "crystals": 2, "min_par": 2, "max_par": 4, "max_solutions": 3}, true)
	elif i <= 15:
		s.merge({"w": 5, "h": 6, "rot": 5, "fixed": 2, "rocks": 2, "crystals": 2, "blooms": 1, "min_par": 3, "max_par": 5, "max_solutions": 3}, true)
	elif i <= 20:
		s.merge({"w": 6, "h": 6, "rot": 6, "fixed": 2, "rocks": 3, "crystals": 2, "blooms": 2, "prisms": 1, "min_par": 3, "max_par": 6, "max_solutions": 3}, true)
	elif i <= 25:
		s.merge({"w": 6, "h": 7, "rot": 8, "fixed": 2, "rocks": 3, "crystals": 3, "blooms": 2, "prisms": 1,
			"lanterns": 2 if i >= 23 else 1, "min_par": 4, "max_par": 7, "max_solutions": 2}, true)
	else:
		s.merge({"w": 7, "h": 8, "rot": 10, "fixed": 3, "rocks": 4, "crystals": 3 if i < 28 else 4, "blooms": 3,
			"prisms": 1 if i < 28 else 2, "lanterns": 2, "min_par": 5, "max_par": 8, "max_solutions": 2}, true)
	return s


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
			rng.seed = i * 6151 + attempt * 92821
			lvl = _make(i, spec(i))
			attempt += 1
			if attempt > 4000:
				push_error("could not generate level %d" % i)
				get_tree().quit(1)
				return
		var info := [lvl["_c"], lvl["_b"], lvl["_s"]]
		for k in ["_c", "_b", "_s"]:
			lvl.erase(k)
		var f := FileAccess.open(OUT.path_join("lb_l%02d.json" % i), FileAccess.WRITE)
		f.store_string(JSON.stringify(lvl, "  ") + "\n")
		f.close()
		print("lb_l%02d  %dx%d mirrors=%d crystals=%d blooms=%d par=%d solutions=%d attempts=%d" % [i, lvl["w"], lvl["h"],
			LightBoard.from_dict(lvl).mirrors().size(), info[0], info[1], lvl["par"], info[2], attempt])
	get_tree().quit(0)


func _free_cells(cells: PackedStringArray) -> Array:
	var out: Array = []
	for k in cells.size():
		if cells[k] == ".":
			out.append(k)
	return out


func _put(cells: PackedStringArray, n: int, tokens: Array) -> bool:
	for _k in n:
		var free := _free_cells(cells)
		if free.is_empty():
			return false
		cells[free[rng.randi_range(0, free.size() - 1)]] = tokens[rng.randi_range(0, tokens.size() - 1)]
	return true


func _make(i: int, s: Dictionary) -> Dictionary:
	var w: int = s["w"]
	var h: int = s["h"]
	var cells := PackedStringArray()
	cells.resize(w * h)
	cells.fill(".")
	# lanterns on the edge, facing inward
	for _k in int(s["lanterns"]):
		var side: String = ["N", "E", "S", "W"][rng.randi_range(0, 3)]
		var c := Vector2i()
		var face := ""
		match side:
			"W":
				c = Vector2i(0, rng.randi_range(0, h - 1))
				face = "E"
			"E":
				c = Vector2i(w - 1, rng.randi_range(0, h - 1))
				face = "W"
			"N":
				c = Vector2i(rng.randi_range(0, w - 1), 0)
				face = "S"
			_:
				c = Vector2i(rng.randi_range(0, w - 1), h - 1)
				face = "N"
		if cells[c.y * w + c.x] != ".":
			return {}
		cells[c.y * w + c.x] = "L" + face
	if not (_put(cells, int(s["rot"]), ["/", "\\"]) and _put(cells, int(s["fixed"]), ["f/", "f\\"])
			and _put(cells, int(s["rocks"]), ["#"]) and _put(cells, int(s["prisms"]), ["X"])):
		return {}
	var b := LightBoard.new()
	b.w = w
	b.h = h
	b.cells = cells
	var ms := b.mirrors()
	# goal state: the beam must meet most round mirrors
	var t := b.trace()
	var lit: Dictionary = t["lit"]
	var on_path := 0
	for m in ms:
		if lit.has(m):
			on_path += 1
	if on_path < mini(ms.size(), int(s["min_par"]) + 1):
		return {}
	# crystals on lit open water, preferring cells far from the lanterns
	var cand: Array = []
	for c in lit:
		if b.token_at(c) == ".":
			cand.append(c)
	if cand.size() < int(s["crystals"]):
		return {}
	_shuffle(cand)
	var placed := 0
	for c in cand:
		if placed >= int(s["crystals"]):
			break
		if _near_lantern(b, c):
			continue
		b.cells[c.y * w + c.x] = "C"
		placed += 1
	if placed < int(s["crystals"]):
		return {}
	# blooms where other mirror states would shine but the goal state does not
	var tempt := {}
	var goal := b.mirror_state()
	for _k in 24:
		var alt := b.duplicate_board()
		for m in ms:
			if rng.randf() < 0.5:
				alt.toggle(m)
		for c in alt.trace()["lit"]:
			if not lit.has(c) and b.token_at(c) == ".":
				tempt[c] = true
	var bl: Array = tempt.keys()
	if bl.size() < int(s["blooms"]):
		return {}
	_shuffle(bl)
	for k in int(s["blooms"]):
		b.cells[bl[k].y * w + bl[k].x] = "D"
	if not b.solved():
		return {}
	# scramble: flip about half the round mirrors (always at least the minimum)
	var start := b.duplicate_board()
	var order := ms.duplicate()
	_shuffle(order)
	var n_flip := clampi(int(round(ms.size() * rng.randf_range(0.45, 0.8))), int(s["min_par"]), ms.size())
	for k in n_flip:
		start.toggle(order[k])
	if start.solved():
		return {}
	var r := LightSolver.solve(start)
	if r["status"] != LightSolver.SOLVED:
		return {}
	var par := int(r["par"])
	if par < int(s["min_par"]) or par > int(s["max_par"]) or int(r["solutions"]) > int(s["max_solutions"]):
		return {}
	var solution: Array = []
	for c in r["flips"]:
		solution.append([c.x, c.y])
	assert(goal != "")
	return {"format_version": 1, "id": "lb_l%02d" % i, "name": NAMES[i - 1], "island": "lantern_bay",
		"w": w, "h": h, "grid": start.to_grid(), "par": par, "solution": solution,
		"objectives": {"optional": [{"type": "moves_at_most", "value": par + (1 if i <= 10 else 2)}]},
		"rewards": {"essence": 12 + i, "cafe_coins": 6 + i * 2},
		"_c": int(s["crystals"]), "_b": int(s["blooms"]), "_s": int(r["solutions"])}


func _near_lantern(b: LightBoard, c: Vector2i) -> bool:
	for d in LightBoard.DIRS.values():
		var n: Vector2i = c + d
		if b.inside(n) and b.token_at(n).begins_with("L"):
			return true
	return false


## Fisher-Yates with the seeded generator (Array.shuffle uses the global one).
func _shuffle(a: Array) -> void:
	for k in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, k)
		var tmp = a[k]
		a[k] = a[j]
		a[j] = tmp
