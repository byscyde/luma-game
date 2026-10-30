extends Node
## Generates Rope Isles (Hashi) levels with the real rules and solver: grow a
## connected network of islets and bridges on the grid, write each islet's
## bridge count as its number, and keep only puzzles BridgeSolver proves to
## have exactly one solution. Deterministic.
##   godot --headless --path . res://tools/generate_bridge_levels.tscn [-- --from=N --to=M]
## Output: resources/islands/rope_isles/levels/ri_lNN.json

const OUT := "res://resources/islands/rope_isles/levels"
const NAMES := ["First Rope", "Two Shores", "Gull Rock", "Plank Walk", "Fishing Huts",
	"Knot Isle", "Sail Point", "Twin Ropes", "Coconut Cay", "Hammock Bay",
	"Driftwood", "Net Menders", "Windy Crossing", "Rope Market", "Lagoon Ring",
	"Long Span", "Kite Island", "Tangled Tide", "Mast Rock", "Island Hop",
	"Weavers' Reef", "Double Knot", "Sunset Spans", "Pelican Pass", "Storm Ropes",
	"Many Isles", "Rope Maze", "Tide Pools", "Last Ferry", "Heart of the Isles"]

var rng := RandomNumberGenerator.new()


func spec(i: int) -> Dictionary:
	if i <= 3:
		return {"w": 5, "h": 5, "islands": 4 + i, "double": 0.3}
	if i <= 8:
		return {"w": 6, "h": 7, "islands": 7 + (i - 4), "double": 0.35}
	if i <= 15:
		return {"w": 7, "h": 8, "islands": 11 + (i - 9) / 2, "double": 0.4}
	if i <= 22:
		return {"w": 8, "h": 9, "islands": 14 + (i - 16) / 2, "double": 0.45}
	return {"w": 9, "h": 11, "islands": 18 + (i - 23) / 2, "double": 0.45}


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
			rng.seed = i * 3571 + attempt * 77711
			lvl = _make(i, spec(i))
			attempt += 1
			if attempt > 5000:
				push_error("could not generate level %d" % i)
				get_tree().quit(1)
				return
		var f := FileAccess.open(OUT.path_join("ri_l%02d.json" % i), FileAccess.WRITE)
		f.store_string(JSON.stringify(lvl, "  ") + "\n")
		f.close()
		print("ri_l%02d  %dx%d islands=%d bridges=%d attempts=%d" % [i, lvl["w"], lvl["h"], (lvl["islands"] as Array).size(), lvl["par"], attempt])
	get_tree().quit(0)


func _make(i: int, s: Dictionary) -> Dictionary:
	var w: int = s["w"]
	var h: int = s["h"]
	var isl: Dictionary = {}          # Vector2i -> degree
	var water: Dictionary = {}        # cells under a bridge
	var bridges: Array = []           # [a, b, n]
	var start := Vector2i(rng.randi_range(0, w - 1), rng.randi_range(0, h - 1))
	isl[start] = 0
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var tries := 0
	while isl.size() < int(s["islands"]) and tries < 400:
		tries += 1
		var keys: Array = isl.keys()
		var from: Vector2i = keys[rng.randi_range(0, keys.size() - 1)]
		var d: Vector2i = dirs[rng.randi_range(0, 3)]
		var len := rng.randi_range(2, maxi(2, maxi(w, h) / 2))
		var to := from + d * len
		if to.x < 0 or to.y < 0 or to.x >= w or to.y >= h or isl.has(to) or water.has(to):
			continue
		var ok := true
		for k in range(1, len):
			var c := from + d * k
			if isl.has(c) or water.has(c):
				ok = false
				break
		for nd in dirs:
			if isl.has(to + nd):
				ok = false
		if not ok:
			continue
		var n := 2 if rng.randf() < float(s["double"]) else 1
		for k in range(1, len):
			water[from + d * k] = true
		isl[to] = 0
		bridges.append([from, to, n])
		isl[from] = int(isl[from]) + n
		isl[to] = int(isl[to]) + n
	if isl.size() < int(s["islands"]):
		return {}
	var islands: Array = []
	var cells: Array = isl.keys()
	cells.sort()
	for c in cells:
		islands.append([c.x, c.y, isl[c]])
	var lvl := {"w": w, "h": h, "islands": islands}
	var b := BridgeBoard.from_dict(lvl)
	var r := BridgeSolver.solve(b, 2)
	if r["status"] != BridgeSolver.SOLVED or int(r["solutions"]) != 1 or not r["complete"]:
		return {}
	# deeper puzzles need more search: skip trivially forced ones late on
	if i > 10 and int(r["nodes"]) < islands.size() * 3:
		return {}
	var sol: Array = []
	var par := 0
	var st: PackedInt32Array = r["state"]
	for k in b.links.size():
		if st[k] > 0:
			var a := b.cell(b.links[k][0])
			var c2 := b.cell(b.links[k][1])
			sol.append([a.x, a.y, c2.x, c2.y, st[k]])
			par += st[k]
	return {"format_version": 1, "id": "ri_l%02d" % i, "name": NAMES[i - 1], "island": "rope_isles",
		"w": w, "h": h, "islands": islands, "par": par, "solution": sol,
		"objectives": {"optional": [{"type": "moves_at_most", "value": par + 2 + par / 5}]},
		"rewards": {"essence": 16 + i, "cafe_coins": 8 + i * 2}}
