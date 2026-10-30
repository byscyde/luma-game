class_name PuzzleBoard
extends RefCounted
## Grid of PuzzleTiles plus switch state. Holds the mutable puzzle state and
## the rules for player moves. Rendering lives in scenes/puzzle.

signal changed(pos: Vector2i)

var width: int = 0
var height: int = 0
var tiles: Array[PuzzleTile] = []
var switches: Dictionary = {}  ## link id -> bool (ON)


func _init(w: int = 0, h: int = 0) -> void:
	width = w
	height = h
	tiles.resize(w * h)
	for i in tiles.size():
		tiles[i] = PuzzleTile.new()


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func index_of(p: Vector2i) -> int:
	return p.y * width + p.x


func pos_of(i: int) -> Vector2i:
	return Vector2i(i % width, i / width)


func get_tile(p: Vector2i) -> PuzzleTile:
	if not in_bounds(p):
		return null
	return tiles[index_of(p)]


func set_tile(p: Vector2i, t: PuzzleTile) -> void:
	tiles[index_of(p)] = t


func is_gate_open(t: PuzzleTile) -> bool:
	if not t.is_gate():
		return true
	var on := bool(switches.get(t.link, false))
	return on != t.inverted


## Effective openings, accounting for closed gates.
func effective_mask(p: Vector2i) -> int:
	var t := get_tile(p)
	if t == null:
		return 0
	if t.is_gate() and not is_gate_open(t):
		return 0
	return t.shape_mask()


func positions_of_type(type_id: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in tiles.size():
		if tiles[i].type == type_id:
			out.append(pos_of(i))
	return out


func sources() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in tiles.size():
		if tiles[i].is_source():
			out.append(pos_of(i))
	return out


## Player tap. Returns true if the tap changed the board (counts as a move).
func tap(p: Vector2i) -> bool:
	var t := get_tile(p)
	if t == null:
		return false
	if t.is_rotatable():
		t.rotation = (t.rotation + 1) % 4
		changed.emit(p)
		return true
	if t.is_toggle():
		switches[t.link] = not bool(switches.get(t.link, false))
		changed.emit(p)
		return true
	return false


## Minimal state for undo / hashing: rotations of every tile and switch states.
func snapshot() -> Dictionary:
	var rots := PackedByteArray()
	rots.resize(tiles.size())
	for i in tiles.size():
		rots[i] = tiles[i].rotation
	return {"rotations": rots, "switches": switches.duplicate()}


func restore(snap: Dictionary) -> void:
	var rots: PackedByteArray = snap["rotations"]
	for i in tiles.size():
		tiles[i].rotation = rots[i]
	switches = (snap["switches"] as Dictionary).duplicate()
	changed.emit(Vector2i(-1, -1))


func duplicate_board() -> PuzzleBoard:
	var b := PuzzleBoard.new(width, height)
	for i in tiles.size():
		b.tiles[i] = tiles[i].duplicate_tile()
	b.switches = switches.duplicate()
	return b


func target_ids(include_bonus: bool = false) -> Array[String]:
	var out: Array[String] = []
	for t in tiles:
		if t.type == TileTypes.TARGET or (include_bonus and t.type == TileTypes.BONUS):
			out.append(t.target_id)
	return out
