class_name BoardView
extends Control
## Renders a PuzzleBoard, turns touches into tile taps and animates water.
## Holds no rules: it emits `tile_tapped` and is told what the water did.

signal tile_tapped(cell: Vector2i)

const FILL_STEP := 0.075       ## seconds between consecutive BFS rings filling
const FILL_TIME := 0.16        ## seconds for one tile to fill

var board: PuzzleBoard
var cell_size := 100.0
var origin := Vector2.ZERO
var input_enabled := true
var views: Dictionary = {}     ## Vector2i -> TileView
var _wet_since: Dictionary = {}
var _pointer: Node2D
var _pointer_cell := Vector2i(-1, -1)
var _time := 0.0
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)
	_pointer = PointerHand.new()
	_pointer.visible = false
	_pointer.z_index = 10
	add_child(_pointer)


func setup(p_board: PuzzleBoard) -> void:
	board = p_board
	for v in views.values():
		v.queue_free()
	views.clear()
	for y in board.height:
		for x in board.width:
			var p := Vector2i(x, y)
			var v := TileView.new()
			add_child(v)
			views[p] = v
	move_child(_pointer, -1)
	_layout()


func _layout() -> void:
	if board == null:
		return
	var pad := 18.0
	cell_size = floorf(minf((size.x - pad * 2) / board.width, (size.y - pad * 2) / board.height))
	cell_size = minf(cell_size, 175.0)
	var board_px := Vector2(board.width, board.height) * cell_size
	origin = ((size - board_px) * 0.5).floor()
	for p in views:
		var v: TileView = views[p]
		v.setup(board.get_tile(p), board, p, cell_size)
		v.position = cell_center(p)
	if _pointer_cell != Vector2i(-1, -1):
		show_pointer(_pointer_cell)
	queue_redraw()


func cell_center(p: Vector2i) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cell_size


func cell_at(local: Vector2) -> Vector2i:
	var q := (local - origin) / cell_size
	var c := Vector2i(floori(q.x), floori(q.y))
	return c if board and board.in_bounds(c) else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if not input_enabled or board == null:
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


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if board == null:
		return
	# A carved stone tray under the tiles gives the board a physical base.
	var r := Rect2(origin, Vector2(board.width, board.height) * cell_size).grow(cell_size * 0.12)
	_sb.set_corner_radius_all(int(cell_size * 0.3))
	_sb.anti_aliasing = true
	_sb.bg_color = Color(0.02, 0.06, 0.06, 0.35)
	draw_style_box(_sb, Rect2(r.position + Vector2(0, cell_size * 0.1), r.size))
	_sb.bg_color = Palette.STONE_DEEP
	draw_style_box(_sb, r)
	_sb.bg_color = Palette.STONE_DARK
	draw_style_box(_sb, Rect2(r.position, r.size - Vector2(0, cell_size * 0.06)))
	_sb.bg_color = Color(Palette.LEAF_DEEP, 0.55)
	draw_style_box(_sb, r.grow(-cell_size * 0.06))


# ------------------------------------------------------------------ animation hooks

## Called after the tile's logical rotation changed; animates the turn.
func animate_rotation(p: Vector2i) -> void:
	var v: TileView = views.get(p)
	if v == null:
		return
	var reduced := Game.reduced_motion()
	v.rot_offset = -PI * 0.5
	var tw := v.create_tween().set_parallel(true)
	tw.tween_property(v, "rot_offset", 0.0, 0.06 if reduced else 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	v.press = 0.94
	tw.tween_property(v, "press", 1.0, 0.16).set_trans(Tween.TRANS_SINE)


func animate_press(p: Vector2i) -> void:
	var v: TileView = views.get(p)
	if v == null:
		return
	v.press = 0.94
	v.create_tween().tween_property(v, "press", 1.0, 0.14)


## Applies a simulation result. Newly wet tiles fill ring by ring from the
## source; tiles that lost water drain immediately. Returns the time in seconds
## until the last tile finishes filling.
func apply_water(sim: WaterResult, animate: bool = true) -> float:
	var entry: Dictionary = {}
	for e in sim.edges:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		var d := _dir_between(b, a)
		entry[b] = int(entry.get(b, 0)) | d
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
				tw.tween_property(v, "bloom", 1.0, 0.05 if reduced else 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			longest = maxf(longest, delay + FILL_TIME + (0.55 if v.tile.is_sink() else 0.0))
		elif not now_wet and v.wet:
			v.wet = false
			_wet_since.erase(p)
			v.water = 0.0
			if v.tile.is_sink():
				v.create_tween().tween_property(v, "bloom", 0.0, 0.2)
		elif now_wet and v.tile.is_source():
			v.water = 1.0
	return longest


func _dir_between(from: Vector2i, to: Vector2i) -> int:
	var d := to - from
	for dir in Dir.LIST:
		if Dir.offset(dir) == d:
			return dir
	return 0


## Glow wave across all wet tiles when the puzzle is solved.
func celebrate(sim: WaterResult) -> void:
	if Game.reduced_motion():
		return
	for p in sim.order:
		var v: TileView = views[p]
		var tw := v.create_tween()
		tw.tween_interval(int(sim.distance[p]) * 0.05)
		tw.tween_property(v, "celebrate", 1.0, 0.15)
		tw.tween_property(v, "celebrate", 0.0, 0.45)


func set_highlight(p: Vector2i) -> void:
	for c in views:
		views[c].highlight = c == p


func show_pointer(p: Vector2i) -> void:
	_pointer_cell = p
	if p == Vector2i(-1, -1):
		_pointer.visible = false
		return
	_pointer.visible = true
	_pointer.position = cell_center(p) + Vector2(cell_size * 0.18, cell_size * 0.22)
	(_pointer as PointerHand).unit = cell_size


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
		var s := unit * 0.32
		# ripple at fingertip
		var ph := fmod(_t * 1.5, 1.0)
		draw_arc(Vector2(-s * 0.55, -s * 0.9), unit * 0.12 + ph * unit * 0.25, 0, TAU, 24, Color(1, 1, 1, 0.7 * (1.0 - ph)), 3.0, true)
		var col := Color("fff7e6")
		var outline := Color(0.15, 0.2, 0.2, 0.9)
		var finger_a := off + Vector2(-s * 0.55, -s * 0.9)
		var finger_b := off + Vector2(-s * 0.1, s * 0.1)
		draw_line(finger_a, finger_b, outline, s * 0.42, true)
		draw_line(finger_a, finger_b, col, s * 0.3, true)
		draw_circle(off + Vector2(s * 0.15, s * 0.45), s * 0.46, outline, true, -1, true)
		draw_circle(off + Vector2(s * 0.15, s * 0.45), s * 0.4, col, true, -1, true)
		draw_circle(finger_a, s * 0.21, outline, true, -1, true)
		draw_circle(finger_a, s * 0.15, col, true, -1, true)
