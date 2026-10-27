class_name LightBoard
extends RefCounted
## Lantern Bay rules: lanterns shine lumen beams across a w x h grid. Tapping a
## round mirror flips it between "/" and "\"; square mirrors are fixed. A level
## is solved when every crystal is lit and no night bloom is.
##
## Tokens (space-separated, row-major):
##   .  open water        #  rock (stops a beam)
##   /  \  rotatable mirror (the token is its current state)
##   f/ f\ fixed mirror  X  prism: splits a beam into its two side directions
##   C  crystal (must be lit; the beam passes through)
##   D  night bloom (must stay dark; a beam that reaches it stops there)
##   LN LE LS LW  lantern facing that way

const DIRS := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}

var w := 0
var h := 0
var cells: PackedStringArray = []


static func from_dict(d: Dictionary) -> LightBoard:
	var b := LightBoard.new()
	var rows: Array = d.get("grid", [])
	b.h = rows.size()
	b.w = str(rows[0]).split(" ", false).size() if b.h > 0 else 0
	for r in rows:
		for tok in str(r).split(" ", false):
			b.cells.append(tok)
	return b


func duplicate_board() -> LightBoard:
	var b := LightBoard.new()
	b.w = w
	b.h = h
	b.cells = cells.duplicate()
	return b


func to_grid() -> Array:
	var out: Array = []
	for y in h:
		out.append(" ".join(cells.slice(y * w, y * w + w)))
	return out


func token_at(c: Vector2i) -> String:
	return cells[c.y * w + c.x]


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h


static func is_rotatable(tok: String) -> bool:
	return tok == "/" or tok == "\\"


## Cells of the round (tappable) mirrors, row-major.
func mirrors() -> Array:
	var out: Array = []
	for y in h:
		for x in w:
			if is_rotatable(cells[y * w + x]):
				out.append(Vector2i(x, y))
	return out


func crystals() -> Array:
	return _cells_of("C")


func blooms() -> Array:
	return _cells_of("D")


func _cells_of(tok: String) -> Array:
	var out: Array = []
	for y in h:
		for x in w:
			if cells[y * w + x] == tok:
				out.append(Vector2i(x, y))
	return out


## Flips a round mirror; returns false for any other cell.
func toggle(c: Vector2i) -> bool:
	if not inside(c) or not is_rotatable(token_at(c)):
		return false
	cells[c.y * w + c.x] = "\\" if token_at(c) == "/" else "/"
	return true


## The state of every round mirror as a string of "/" and "\" (row-major).
func mirror_state() -> String:
	var s := ""
	for c in mirrors():
		s += token_at(c)
	return s


func set_mirror_state(state: String) -> void:
	var ms := mirrors()
	for i in ms.size():
		cells[ms[i].y * w + ms[i].x] = state[i]


# ------------------------------------------------------------------ beams

static func reflect(tok: String, d: Vector2i) -> Vector2i:
	# "/" joins E<->N and W<->S; "\" joins E<->S and W<->N (y grows downward)
	if tok.ends_with("/"):
		return Vector2i(-d.y, -d.x)
	return Vector2i(d.y, d.x)


## Traces every beam. Returns {"lit": {cell: true}, "segments": [[from, to]],
## "crystals_lit", "crystals", "blooms_lit", "solved"}. Segments run between
## cell centres (cell coordinates), ending at the cell where a beam stops or
## half a cell past the edge.
func trace() -> Dictionary:
	return _run({}, false)


## Shared beam walk. With `lazy`, round mirrors take their state from `assign`
## (cell -> "/" or "\\"); the first round mirror without one stops the walk and
## is returned as {"branch": cell}, together with whether a bloom is already lit.
func _run(assign: Dictionary, lazy: bool) -> Dictionary:
	var lit := {}
	var segments: Array = []
	var seen := {}
	var heads: Array = []
	for y in h:
		for x in w:
			var t := cells[y * w + x]
			if t.length() == 2 and t[0] == "L":
				var c := Vector2i(x, y)
				lit[c] = true
				heads.append([c, DIRS[t[1]]])
	while not heads.is_empty():
		var hd: Array = heads.pop_back()
		var start: Vector2i = hd[0]
		var d: Vector2i = hd[1]
		var key := "%d,%d,%d,%d" % [start.x, start.y, d.x, d.y]
		if seen.has(key):
			continue
		seen[key] = true
		var c := start
		var end := Vector2(start)
		while true:
			c += d
			if not inside(c):
				end = Vector2(c) - Vector2(d) * 0.5
				break
			lit[c] = true
			var t := token_at(c)
			end = Vector2(c)
			if lazy and is_rotatable(t):
				if not assign.has(c):
					var bl := false
					for b in blooms():
						bl = bl or lit.has(b)
					return {"branch": c, "blooms_lit": 1 if bl else 0}
				t = assign[c]
			if t == "#" or t == "D" or t.begins_with("L"):
				break
			if t == "X":
				heads.append([c, Vector2i(d.y, -d.x)])
				heads.append([c, Vector2i(-d.y, d.x)])
				break
			if t.ends_with("/") or t.ends_with("\\"):
				heads.append([c, reflect(t, d)])
				break
		segments.append([Vector2(start), end])
	var cr := crystals()
	var n_cr := 0
	for c in cr:
		if lit.has(c):
			n_cr += 1
	var n_bl := 0
	for c in blooms():
		if lit.has(c):
			n_bl += 1
	return {"lit": lit, "segments": segments, "crystals_lit": n_cr, "crystals": cr.size(),
		"blooms_lit": n_bl, "solved": cr.size() > 0 and n_cr == cr.size() and n_bl == 0}


func solved() -> bool:
	return trace()["solved"]
