class_name SlideBoard
extends RefCounted
## Ember Reef rules: a w x h grid of channel blocks inside a fixed frame. The
## player slides a whole row (left/right) or column (up/down) by one step;
## blocks wrap around. The spring and the targets sit on the frame. Water is
## simulated with the shared WaterSimulation on a (w+2) x (h+2) PuzzleBoard,
## so the connectivity rules are exactly the ones of the rest of the game.
##
## A move is [kind, index, dir]: kind "r" (row, dir +1 = right) or "c"
## (column, dir +1 = down).

var w := 3
var h := 3
var cells: PackedStringArray = []    ## inner tokens, row-major ("I0", "L1", "Y2", "+", ".", "#")
var source := {"side": "W", "index": 0}
var targets: Array = []              ## [{"side", "index", "id"}]
var locked_rows: Array = []
var locked_cols: Array = []
var _pb: PuzzleBoard


static func from_dict(d: Dictionary) -> SlideBoard:
	var b := SlideBoard.new()
	var rows: Array = d.get("grid", [])
	b.h = rows.size()
	b.w = str(rows[0]).split(" ", false).size() if b.h > 0 else 0
	for r in rows:
		for tok in str(r).split(" ", false):
			b.cells.append(tok)
	b.source = d.get("source", b.source)
	b.targets = d.get("targets", [])
	b.locked_rows = d.get("locked_rows", [])
	b.locked_cols = d.get("locked_cols", [])
	b._build()
	return b


func to_grid() -> Array:
	var out: Array = []
	for y in h:
		out.append(" ".join(cells.slice(y * w, y * w + w)))
	return out


func duplicate_board() -> SlideBoard:
	var b := SlideBoard.new()
	b.w = w
	b.h = h
	b.cells = cells.duplicate()
	b.source = source
	b.targets = targets
	b.locked_rows = locked_rows
	b.locked_cols = locked_cols
	b._build()
	return b


# ------------------------------------------------------------------ frame mapping

## Frame cell (in the (w+2) x (h+2) board) for a side/index pair.
func frame_cell(side: String, index: int) -> Vector2i:
	match side:
		"W":
			return Vector2i(0, index + 1)
		"E":
			return Vector2i(w + 1, index + 1)
		"N":
			return Vector2i(index + 1, 0)
		_:
			return Vector2i(index + 1, h + 1)


static func inward_rotation(side: String) -> int:
	# SOURCE opens north at rotation 0; turn it to face into the grid
	return {"W": 1, "N": 2, "E": 3, "S": 0}[side]


func _build() -> void:
	_pb = PuzzleBoard.new(w + 2, h + 2)
	var s := PuzzleTile.new(TileTypes.SOURCE, inward_rotation(str(source["side"])))
	_pb.set_tile(frame_cell(str(source["side"]), int(source["index"])), s)
	for t in targets:
		var tt := PuzzleTile.new(TileTypes.TARGET)
		tt.target_id = str(t["id"])
		_pb.set_tile(frame_cell(str(t["side"]), int(t["index"])), tt)
	_sync()


func _sync() -> void:
	for y in h:
		for x in w:
			var r := LevelData.parse_token(cells[y * w + x])
			var t: PuzzleTile = r["tile"] if r.has("tile") else PuzzleTile.new()
			t.pinned = true      # blocks slide; they never rotate
			_pb.set_tile(Vector2i(x + 1, y + 1), t)


func puzzle_board() -> PuzzleBoard:
	return _pb


func token_at(x: int, y: int) -> String:
	return cells[y * w + x]


# ------------------------------------------------------------------ moves

func is_locked(kind: String, index: int) -> bool:
	return locked_rows.has(index) if kind == "r" else locked_cols.has(index)


func legal_moves() -> Array:
	var out: Array = []
	for y in h:
		if not locked_rows.has(y):
			out.append(["r", y, 1])
			out.append(["r", y, -1])
	for x in w:
		if not locked_cols.has(x):
			out.append(["c", x, 1])
			out.append(["c", x, -1])
	return out


## Applies a move; returns false when the line is locked or out of range.
func apply(move: Array) -> bool:
	var kind := str(move[0])
	var i := int(move[1])
	var d := int(move[2])
	if is_locked(kind, i):
		return false
	if kind == "r":
		if i < 0 or i >= h:
			return false
		var row := cells.slice(i * w, i * w + w)
		for x in w:
			cells[i * w + posmod(x + d, w)] = row[x]
	else:
		if i < 0 or i >= w:
			return false
		var col: Array = []
		for y in h:
			col.append(cells[y * w + i])
		for y in h:
			cells[posmod(y + d, h) * w + i] = col[y]
	_sync()
	return true


static func inverse(move: Array) -> Array:
	return [move[0], move[1], -int(move[2])]


func simulate() -> WaterResult:
	return WaterSimulation.simulate(_pb)


func solved() -> bool:
	return simulate().all_required_reached


func key() -> String:
	return ",".join(cells)


func snapshot() -> PackedStringArray:
	return cells.duplicate()


func restore(snap: PackedStringArray) -> void:
	cells = snap.duplicate()
	_sync()
