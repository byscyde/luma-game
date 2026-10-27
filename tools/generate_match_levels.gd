extends Node
## Generates Moon Grove (match-3) levels with the real rules: lay out the grove
## (holes, dark moss), deal a start grid with no ready matches, pick goals, and
## let MatchBot play it with the level's own deterministic refills. The bot's
## winning swaps are stored as the solution and the move limit is set from its
## move count, tighter on later levels. Deterministic.
##   godot --headless --path . res://tools/generate_match_levels.tscn [-- --from=N --to=M]
## Output: resources/islands/moon_grove/levels/mg_lNN.json

const OUT := "res://resources/islands/moon_grove/levels"
const NAMES := ["First Bloom", "Moonbeam", "Silver Petals", "Night Garden", "Dewdrops",
	"Moss Ring", "Owl Hollow", "Star Lilies", "Quiet Pond", "Midnight Path",
	"Firefly Glade", "Mossy Steps", "Twin Moons", "Lantern Roots", "Glow Fern",
	"Hollow Oak", "Moonwell", "Thorn Gate", "Silver Brook", "Dream Meadow",
	"Shadow Moss", "Crescent Field", "Night Orchard", "Silas's Shed", "Lost Lanterns",
	"Deep Grove", "Blue Hour", "Full Moon", "Last Shadow", "Heart of the Grove"]

var rng := RandomNumberGenerator.new()


func spec(i: int) -> Dictionary:
	if i <= 3:
		return {"w": 7, "h": 7, "kinds": 4, "moss": 0, "layers": 1, "holes": 0, "collect": 1, "count": 30 + i * 6, "factor": 1.6}
	if i <= 8:
		return {"w": 7, "h": 8, "kinds": 5, "moss": 6 + (i - 4) * 2, "layers": 1, "holes": 0, "collect": 0, "count": 0, "factor": 1.5}
	if i <= 15:
		return {"w": 7, "h": 8, "kinds": 5, "moss": 10 + (i - 9), "layers": 2, "holes": 2, "collect": 1, "count": 30, "factor": 1.4}
	if i <= 22:
		return {"w": 8, "h": 9, "kinds": 5, "moss": 16 + (i - 16), "layers": 2, "holes": 4, "collect": 1, "count": 36, "factor": 1.3}
	return {"w": 8, "h": 9, "kinds": 6, "moss": 22 + (i - 23), "layers": 2, "holes": 6, "collect": 2, "count": 30, "factor": 1.2}


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
			rng.seed = i * 2909 + attempt * 50021
			lvl = _make(i, spec(i))
			attempt += 1
			if attempt > 300:
				push_error("could not generate level %d" % i)
				get_tree().quit(1)
				return
		var f := FileAccess.open(OUT.path_join("mg_l%02d.json" % i), FileAccess.WRITE)
		f.store_string(JSON.stringify(lvl, "  ") + "\n")
		f.close()
		print("mg_l%02d  %dx%d kinds=%d moss=%d moves=%d bot=%d attempts=%d" % [i, lvl["w"], lvl["h"], lvl["kinds"],
			MatchBoard.from_dict(lvl).moss_left(), lvl["moves"], lvl["par"], attempt])
	get_tree().quit(0)


func _make(i: int, s: Dictionary) -> Dictionary:
	var w: int = s["w"]
	var h: int = s["h"]
	var kinds: int = s["kinds"]
	var grid: Array = []
	var holes := {}
	# holes in symmetric pairs keep the grove tidy
	while holes.size() < int(s["holes"]):
		var c := Vector2i(rng.randi_range(0, w / 2 - 1), rng.randi_range(1, h - 2))
		holes[c] = true
		holes[Vector2i(w - 1 - c.x, c.y)] = true
	var cells: Array = []
	for y in h:
		for x in w:
			if holes.has(Vector2i(x, y)):
				cells.append(-2)
				continue
			var k := rng.randi_range(0, kinds - 1)
			var guard := 0
			while guard < 20 and ((x >= 2 and cells[y * w + x - 1] == k and cells[y * w + x - 2] == k)
					or (y >= 2 and cells[(y - 1) * w + x] == k and cells[(y - 2) * w + x] == k)):
				k = rng.randi_range(0, kinds - 1)
				guard += 1
			cells.append(k)
	for y in h:
		var row: Array = []
		for x in w:
			var v: int = cells[y * w + x]
			row.append("#" if v == -2 else str(v))
		grid.append(" ".join(row))
	# moss: a blob grown from the lower middle
	var moss := {}
	var frontier: Array = [Vector2i(w / 2, h - 2), Vector2i(w / 2 - 1, h - 2), Vector2i(w / 2, h - 3)]
	while moss.size() < int(s["moss"]) and not frontier.is_empty():
		var c: Vector2i = frontier.pop_at(rng.randi_range(0, frontier.size() - 1))
		if moss.has(c) or holes.has(c) or c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			continue
		moss[c] = 2 if int(s["layers"]) >= 2 and rng.randf() < 0.4 else 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			frontier.append(c + d)
	if moss.size() < int(s["moss"]):
		return {}
	var mrows: Array = []
	for y in h:
		var row := ""
		for x in w:
			row += str(moss.get(Vector2i(x, y), 0))
		mrows.append(row)
	var goals := {"moss": moss.size() > 0}
	if int(s["collect"]) > 0:
		var col := {}
		var picks: Array = range(kinds)
		for k in int(s["collect"]):
			var at := rng.randi_range(0, picks.size() - 1)
			col[str(picks[at])] = int(s["count"])
			picks.remove_at(at)
		goals["collect"] = col
	var lvl := {"format_version": 1, "id": "mg_l%02d" % i, "name": NAMES[i - 1], "island": "moon_grove",
		"w": w, "h": h, "kinds": kinds, "seed": rng.randi_range(1, 2000000000), "grid": grid, "moss": mrows,
		"goals": goals, "moves": 99}
	var b := MatchBoard.from_dict(lvl)
	if not b.find_runs().is_empty() or b.all_valid_swaps().size() < 3:
		return {}
	var r := MatchBot.play(b, 70)
	if not r["won"]:
		return {}
	var used: int = (r["moves"] as Array).size()
	if used < 5 + i / 3 or used > 16 + i:
		return {}
	var limit := maxi(used + 2, ceili(used * float(s["factor"])))
	lvl["moves"] = limit
	lvl["par"] = used
	lvl["solution"] = r["moves"]
	lvl["objectives"] = {"optional": [{"type": "moves_at_most", "value": used + (limit - used) / 2}]}
	lvl["rewards"] = {"essence": 18 + i, "cafe_coins": 9 + i * 2}
	return lvl
