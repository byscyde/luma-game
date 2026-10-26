class_name BoardView
extends Control
## Renders a PuzzleBoard as a crisp top-down tray of tiles, turns touches into
## tile taps and animates water. Holds no rules: it emits `tile_tapped` and is
## told what the water did.

signal tile_tapped(cell: Vector2i)

const FILL_STEP := 0.075       ## seconds between consecutive BFS rings filling
const FILL_TIME := 0.16        ## seconds for one tile to fill
const PAD := 0.2               ## tray padding around the grid (cell units)
const MAX_CELL := 170.0        ## px; keeps tiny boards from looking bloated

const TRAY_TOP := Color("2f6461")
const TRAY_BOTTOM := Color("214a4c")
const TRAY_EDGE := Color("173638")
const SLOT := Color("1c3f41")
const SLOT_LIGHT := Color(1, 1, 1, 0.05)

var board: PuzzleBoard
var input_enabled := true
var views: Dictionary = {}     ## Vector2i -> TileView
var cell_size := 100.0         ## on-screen size of a cell in px
var origin := Vector2.ZERO     ## top-left of cell (0, 0)
var _wet_since: Dictionary = {}
var _bridges: Array = []       ## [Vector2 a, Vector2 b] water across the gaps between tiles
var _edges: Array = []         ## last simulation's water edges
var _pointer: Node2D
var _pointer_cell := Vector2i(-1, -1)
var _tiles: Node2D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _tiles == null:
		_ready_children()
	_pointer = PointerHand.new()
	_pointer.visible = false
	_pointer.z_index = 10
	add_child(_pointer)
	resized.connect(_layout)


func setup(p_board: PuzzleBoard) -> void:
	board = p_board
	if _tiles == null:
		_ready_children()
	for v in views.values():
		v.queue_free()
	views.clear()
	_wet_since.clear()
	_bridges.clear()
	# row-major so lower tiles draw over the shadows of the row above
	for y in board.height:
		for x in board.width:
			var p := Vector2i(x, y)
			var v := TileView.new()
			_tiles.add_child(v)
			v.setup(board.get_tile(p), board, p)
			views[p] = v
	_layout()


func _ready_children() -> void:
	_tiles = Node2D.new()
	add_child(_tiles)


func _layout() -> void:
	if board == null or size.x < 2 or size.y < 2:
		return
	var cols := float(board.width) + PAD * 2.0
	var rows := float(board.height) + PAD * 2.0 + 0.1
	cell_size = minf(MAX_CELL, minf(size.x / cols, size.y / rows))
	var grid := Vector2(board.width, board.height) * cell_size
	origin = ((size - grid) * 0.5).floor()
	for p in views:
		var v: TileView = views[p]
		v.position = cell_center(p)
		v.unit = cell_size
	_rebuild_bridges()
	queue_redraw()
	if _pointer_cell != Vector2i(-1, -1):
		show_pointer(_pointer_cell)


func cell_center(p: Vector2i) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cell_size


func cell_at(local: Vector2) -> Vector2i:
	if board == null or cell_size <= 0.0:
		return Vector2i(-1, -1)
	var g := (local - origin) / cell_size
	var c := Vector2i(floori(g.x), floori(g.y))
	return c if board.in_bounds(c) else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if not input_enabled or board == null:
		return
	# On touch screens Godot also emits an emulated mouse click for every touch
	# (emulate_mouse_from_touch); handling both rotated each tile twice per tap.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	if pressed:
		var c := cell_at(pos)
		if c != Vector2i(-1, -1):
			accept_event()
			tile_tapped.emit(c)


# ------------------------------------------------------------------ tray

func _draw() -> void:
	if board == null:
		return
	var c := cell_size
	var grid := Rect2(origin, Vector2(board.width, board.height) * c)
	var tray := grid.grow(PAD * c)
	var r := 0.3 * c
	# soft shadow, then the tray body with a darker lip and a lit top edge
	for i in 5:
		var k := float(i) / 4.0
		_round_rect(Rect2(tray.position + Vector2(0, c * 0.08), tray.size).grow(c * 0.05 * (1.0 - k)), r + c * 0.05, Color(0, 0, 0, 0.05 + 0.04 * k))
	_round_rect(Rect2(tray.position + Vector2(0, c * 0.07), tray.size), r, TRAY_EDGE)
	_gradient_round_rect(tray, r, TRAY_TOP, TRAY_BOTTOM)
	draw_polyline(_closed(_round_rect_points(tray, r)), Color(1, 1, 1, 0.1), maxf(1.5, c * 0.012), true)
	draw_line(tray.position + Vector2(r, c * 0.012), tray.position + Vector2(tray.size.x - r, c * 0.012), Color(1, 1, 1, 0.16), c * 0.02, true)
	# recessed slots
	var inset := c * 0.045
	for y in board.height:
		for x in board.width:
			var cell := Rect2(origin + Vector2(x, y) * c, Vector2(c, c)).grow(-inset)
			_round_rect(cell, c * 0.2, SLOT)
			_round_rect(Rect2(cell.position + Vector2(0, cell.size.y - c * 0.05), Vector2(cell.size.x, c * 0.05)).grow_individual(-c * 0.12, 0, -c * 0.12, 0), c * 0.025, SLOT_LIGHT)
	# water bridging the gaps between connected tiles
	for b in _bridges:
		draw_line(b[0], b[1], TileView.WATER_DEEP_COL, TileView.WATER * c, true)
		draw_line(b[0], b[1], TileView.WATER_COL, TileView.WATER * c * 0.72, true)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	pts.append(pts[0])
	return pts


func _round_rect(rect: Rect2, radius: float, col: Color) -> void:
	draw_colored_polygon(_round_rect_points(rect, radius), col)


func _gradient_round_rect(rect: Rect2, radius: float, top: Color, bottom: Color) -> void:
	var pts := _round_rect_points(rect, radius)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - rect.position.y) / rect.size.y, 0.0, 1.0)))
	draw_polygon(pts, cols)


func _round_rect_points(r: Rect2, radius: float) -> PackedVector2Array:
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - radius, radius), r.position + Vector2(r.size.x - radius, r.size.y - radius),
		r.position + Vector2(radius, r.size.y - radius), r.position + Vector2(radius, radius)]
	for ci in 4:
		var start := -PI * 0.5 + ci * PI * 0.5
		for k in 9:
			var a := start + PI * 0.5 * k / 8.0
			pts.append(corners[ci] + Vector2(cos(a), sin(a)) * radius)
	return pts


# ------------------------------------------------------------------ animation hooks

## Called after the tile's logical rotation changed; animates the turn.
func animate_rotation(p: Vector2i) -> void:
	var v: TileView = views.get(p)
	if v == null:
		return
	v.set_meta("mask", v.tile.shape_mask())
	var reduced := Game.reduced_motion()
	v.rot_offset = -PI * 0.5
	var tw := v.create_tween().set_parallel(true)
	tw.tween_property(v, "rot_offset", 0.0, 0.06 if reduced else 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	v.press = 0.93
	tw.tween_property(v, "press", 1.0, 0.2).set_trans(Tween.TRANS_SINE)


func animate_press(p: Vector2i) -> void:
	var v: TileView = views.get(p)
	if v == null:
		return
	v.press = 0.93
	v.create_tween().tween_property(v, "press", 1.0, 0.14)


## Applies a simulation result. Newly wet tiles fill ring by ring from the
## source; tiles that lost water drain immediately. Returns the time in seconds
## until the last tile finishes filling.
func apply_water(sim: WaterResult, animate: bool = true) -> float:
	var entry: Dictionary = {}
	for e in sim.edges:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		entry[b] = int(entry.get(b, 0)) | _dir_between(b, a)
	var leaks: Dictionary = {}
	for l in sim.leaks:
		leaks[l["pos"]] = int(leaks.get(l["pos"], 0)) | int(l["dir"])
	var reduced := Game.reduced_motion() or not animate
	var longest := 0.0
	var base_dist := 999
	for p in sim.order:
		if not _wet_since.has(p):
			base_dist = mini(base_dist, int(sim.distance[p]))
	for p in views:
		var v: TileView = views[p]
		if v.tile.shape_mask() != int(v.get_meta("mask", -1)):
			v.set_meta("mask", v.tile.shape_mask())
		var now_wet := sim.is_wet(p)
		v.entry_mask = int(entry.get(p, 0))
		v.leak_mask = int(leaks.get(p, 0))
		if now_wet and not v.wet:
			v.wet = true
			_wet_since[p] = true
			var delay := 0.0 if reduced else maxf(0.0, (int(sim.distance[p]) - base_dist) * FILL_STEP)
			v.water = 0.0
			var tw := v.create_tween()
			tw.tween_interval(delay)
			tw.tween_property(v, "water", 1.0, 0.01 if reduced else FILL_TIME)
			if v.tile.is_sink():
				tw.tween_property(v, "bloom", 1.0, 0.05 if reduced else 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			longest = maxf(longest, delay + FILL_TIME + (0.6 if v.tile.is_sink() else 0.0))
		elif not now_wet and v.wet:
			v.wet = false
			_wet_since.erase(p)
			v.water = 0.0
			if v.tile.is_sink():
				v.create_tween().tween_property(v, "bloom", 0.0, 0.2)
		v.queue_redraw()
	_edges = sim.edges.duplicate()
	_rebuild_bridges()
	queue_redraw()
	return longest


func _rebuild_bridges() -> void:
	_bridges.clear()
	for e in _edges:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var ca := cell_center(a)
		var cb := cell_center(b)
		var dir := (cb - ca).normalized()
		_bridges.append([ca + dir * cell_size * (_reach(a) - 0.03), cb - dir * cell_size * (_reach(b) - 0.03)])


## How far a tile's own channel reaches from its centre (cell units).
func _reach(p: Vector2i) -> float:
	var t := board.get_tile(p)
	if t.is_sink():
		return 0.3
	if t.is_rotatable():
		return TileView.DISC_R
	return TileView.SLAB * 0.5


func _dir_between(from: Vector2i, to: Vector2i) -> int:
	var d := to - from
	for dir in Dir.LIST:
		if Dir.offset(dir) == d:
			return dir
	return 0


## A ripple of hops across all wet tiles when the puzzle is solved.
func celebrate(sim: WaterResult) -> void:
	if Game.reduced_motion():
		return
	for p in sim.order:
		var v: TileView = views[p]
		var tw := v.create_tween()
		tw.tween_interval(int(sim.distance[p]) * 0.05)
		tw.tween_property(v, "celebrate", 1.0, 0.35)
		tw.tween_property(v, "celebrate", 0.0, 0.01)


func set_highlight(p: Vector2i) -> void:
	for c in views:
		views[c].highlight = c == p


func show_pointer(p: Vector2i) -> void:
	_pointer_cell = p
	if p == Vector2i(-1, -1):
		_pointer.visible = false
		return
	_pointer.visible = true
	(_pointer as PointerHand).unit = cell_size
	_pointer.position = cell_center(p) + Vector2(cell_size * 0.16, cell_size * 0.12)


func hide_pointer() -> void:
	show_pointer(Vector2i(-1, -1))


## Tutorial pointer: a soft hand that taps.
class PointerHand extends Node2D:
	var unit := 100.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var tap := absf(sin(_t * 3.0))
		var off := Vector2(0, -unit * 0.08 * tap)
		var s := unit * 0.3
		var ph := fmod(_t * 1.5, 1.0)
		draw_arc(Vector2(-s * 0.55, -s * 0.9), unit * 0.12 + ph * unit * 0.25, 0, TAU, 24, Color(1, 1, 1, 0.8 * (1.0 - ph)), 4.0, true)
		var col := Color("fffaf0")
		var outline := Color(0.18, 0.24, 0.24, 0.85)
		var finger_a := off + Vector2(-s * 0.55, -s * 0.9)
		var finger_b := off + Vector2(-s * 0.1, s * 0.1)
		draw_line(finger_a, finger_b, outline, s * 0.44, true)
		draw_line(finger_a, finger_b, col, s * 0.32, true)
		draw_circle(off + Vector2(s * 0.15, s * 0.45), s * 0.48, outline, true, -1, true)
		draw_circle(off + Vector2(s * 0.15, s * 0.45), s * 0.42, col, true, -1, true)
		draw_circle(finger_a, s * 0.22, outline, true, -1, true)
		draw_circle(finger_a, s * 0.16, col, true, -1, true)
