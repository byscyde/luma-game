class_name MatchBoardView
extends Control
## Draws a Moon Grove board (night meadow, dark moss, moonflowers, specials)
## and turns a swipe from a flower — or a tap on a flower and then on its
## neighbour — into `swap_requested(a, b)`. Holds no rules; the screen owns
## the MatchBoard and calls `play_result` after a swap.
## Each kind has its own shape as well as colour (circle, diamond, triangle,
## square, star, hexagon); specials carry an extra mark.

signal swap_requested(a: Vector2i, b: Vector2i)

const PAD := 0.18
const MAX_CELL := 120.0
const SWIPE_MIN := 20.0
const MEADOW_TOP := Color("2b2f57")
const MEADOW_BOTTOM := Color("1d2142")
const SLOT := Color("343a68")
const MOSS_1 := Color("4f6b3a")
const MOSS_2 := Color("2f4a24")
const KIND_COLORS := [Color("f2c14e"), Color("e86a8c"), Color("6fc3e8"), Color("8fd16a"), Color("b78be8"), Color("f29a52")]

var board: MatchBoard
var input_enabled := true
var cell_size := 100.0
var origin := Vector2.ZERO
var selected := Vector2i(-1, -1)
var hint_pair: Array = []
var _drop: Dictionary = {}      ## cell -> remaining drop offset (cells)
var _pops: Array = []           ## [position Vector2, age float, Color]
var _swap_anim := 1.0
var _swap_a := Vector2i(-1, -1)
var _swap_b := Vector2i(-1, -1)
var _time := 0.0
var _down := false
var _down_pos := Vector2.ZERO
var _down_cell := Vector2i(-1, -1)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func setup(b: MatchBoard) -> void:
	board = b
	_layout()


func _layout() -> void:
	if board == null or size.x < 2 or size.y < 2:
		return
	var cols := float(board.w) + PAD * 2.0
	var rows := float(board.h) + PAD * 2.0
	cell_size = minf(MAX_CELL, minf(size.x / cols, size.y / rows))
	origin = ((size - Vector2(board.w, board.h) * cell_size) * 0.5).floor()
	queue_redraw()


func cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell_size


func cell_at(local: Vector2) -> Vector2i:
	var q := ((local - origin) / cell_size).floor()
	var c := Vector2i(int(q.x), int(q.y))
	return c if board != null and board.inside(c) else Vector2i(-1, -1)


## After a swap: bursts where flowers bloomed away, new flowers drop in.
func play_result(a: Vector2i, b: Vector2i, events: Array, before: PackedInt32Array) -> void:
	selected = Vector2i(-1, -1)
	hint_pair = []
	if Game.reduced_motion():
		queue_redraw()
		return
	_swap_a = a
	_swap_b = b
	_swap_anim = 0.0
	for e in events:
		for c in e["cleared"]:
			var k := before[board.idx(c)]
			_pops.append([cell_center(c), 0.0, KIND_COLORS[k % KIND_COLORS.size()] if k >= 0 else Color.WHITE])
	for i in board.cells.size():
		if board.cells[i] >= 0 and board.cells[i] != before[i]:
			var c := Vector2i(i % board.w, i / board.w)
			_drop[c] = 0.6


func _process(delta: float) -> void:
	_time += delta
	if _swap_anim < 1.0:
		_swap_anim = minf(1.0, _swap_anim + delta / 0.12)
	for c in _drop.keys():
		_drop[c] = float(_drop[c]) - delta * 4.0
		if float(_drop[c]) <= 0.0:
			_drop.erase(c)
	for p in _pops:
		p[1] = float(p[1]) + delta
	_pops = _pops.filter(func(p): return float(p[1]) < 0.35)
	if is_visible_in_tree():
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if not input_enabled or board == null:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return   # touches also arrive as emulated mouse events
	var pressed := false
	var released := false
	var moved := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif event is InputEventScreenTouch and event.index == 0:
		pressed = event.pressed
		released = not event.pressed
		pos = event.position
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _down:
		moved = true
		pos = event.position
	if pressed:
		_down = true
		_down_pos = pos
		_down_cell = cell_at(pos)
		accept_event()
	elif (moved or released) and _down:
		var d := pos - _down_pos
		if _down_cell != Vector2i(-1, -1) and d.length() >= SWIPE_MIN * maxf(1.0, cell_size / 100.0):
			_down = false
			var dir := Vector2i(signi(int(d.x)), 0) if absf(d.x) >= absf(d.y) else Vector2i(0, signi(int(d.y)))
			selected = Vector2i(-1, -1)
			swap_requested.emit(_down_cell, _down_cell + dir)
		elif released:
			_down = false
			_tap(cell_at(pos))
		accept_event()


func _tap(c: Vector2i) -> void:
	if c == Vector2i(-1, -1) or not board.playable(c):
		selected = Vector2i(-1, -1)
		return
	if selected != Vector2i(-1, -1) and absi(selected.x - c.x) + absi(selected.y - c.y) == 1:
		var a := selected
		selected = Vector2i(-1, -1)
		swap_requested.emit(a, c)
		return
	selected = c if selected != c else Vector2i(-1, -1)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if board == null:
		return
	var cs := cell_size
	var r := Rect2(origin - Vector2.ONE * cs * PAD, Vector2(board.w, board.h) * cs + Vector2.ONE * cs * PAD * 2.0)
	draw_rect(Rect2(r.position + Vector2(0, cs * 0.08), r.size), Color(0, 0, 0, 0.25))
	var steps := 12
	for k in steps:
		draw_rect(Rect2(r.position + Vector2(0, r.size.y * k / steps), Vector2(r.size.x, r.size.y / steps + 1)), MEADOW_TOP.lerp(MEADOW_BOTTOM, float(k) / (steps - 1)))
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			if board.kind_at(c) == MatchBoard.HOLE:
				continue
			var cr := Rect2(origin + Vector2(c) * cs, Vector2.ONE * cs).grow(-cs * 0.03)
			draw_rect(cr, SLOT)
			var m := board.moss[board.idx(c)]
			if m > 0:
				_draw_moss(cr, m)
	for h in hint_pair:
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		draw_arc(cell_center(h), cs * 0.46, 0, TAU, 32, Color(1, 0.9, 0.5, 0.5 + 0.4 * pulse), cs * 0.05, true)
	if selected != Vector2i(-1, -1):
		draw_arc(cell_center(selected), cs * 0.46, 0, TAU, 32, Color.WHITE, cs * 0.05, true)
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			var k := board.kind_at(c)
			if k < 0:
				continue
			var p := cell_center(c)
			if _swap_anim < 1.0 and (c == _swap_a or c == _swap_b):
				var other := _swap_b if c == _swap_a else _swap_a
				p = cell_center(other).lerp(p, _swap_anim)
			if _drop.has(c):
				p.y -= float(_drop[c]) * cs
			_draw_flower(p, k, board.special_at(c))
	for pop in _pops:
		var t := float(pop[1]) / 0.35
		var col: Color = pop[2]
		draw_arc(pop[0], cs * (0.2 + 0.35 * t), 0, TAU, 20, Color(col, 1.0 - t), cs * 0.06 * (1.0 - t), true)
		for k in 5:
			var a := TAU * k / 5.0 + t
			draw_circle(pop[0] + Vector2(cos(a), sin(a)) * cs * 0.4 * t, cs * 0.05 * (1.0 - t), Color(1, 1, 0.9, 1.0 - t))


func _draw_moss(r: Rect2, layers: int) -> void:
	var cs := cell_size
	draw_rect(r, MOSS_1 if layers == 1 else MOSS_2)
	# tufts: two rows for two layers, so the layer count reads without colour
	for row in layers:
		for k in 3:
			var p := r.position + Vector2(r.size.x * (0.2 + k * 0.3), r.size.y * (0.85 - row * 0.62))
			draw_circle(p, cs * 0.07, MOSS_1.lightened(0.15))


func _draw_flower(p: Vector2, k: int, sp: int) -> void:
	var cs := cell_size
	var col: Color = KIND_COLORS[k % KIND_COLORS.size()]
	var rr := cs * 0.34
	draw_circle(p + Vector2(0, cs * 0.04), rr * 1.02, Color(0, 0, 0, 0.25))
	if sp == MatchBoard.ORB:
		draw_circle(p, rr * 1.1, Color("e9ecff"))
		draw_circle(p + Vector2(rr * 0.35, -rr * 0.2), rr * 0.85, Color("c9cff5"))
		draw_circle(p + Vector2(rr * 0.5, -rr * 0.35), rr * 0.75, Color("e9ecff"))
		for a in 6:
			var ang := _time * 1.5 + TAU * a / 6.0
			draw_circle(p + Vector2(cos(ang), sin(ang)) * rr * 1.25, cs * 0.03, KIND_COLORS[a])
		return
	var pts := shape_pts(p, k, rr)
	draw_colored_polygon(pts, col)
	var inner := shape_pts(p + Vector2(-rr * 0.08, -rr * 0.1), k, rr * 0.55)
	draw_colored_polygon(inner, col.lightened(0.35))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, col.darkened(0.4), cs * 0.03, true)
	draw_circle(p + Vector2(-rr * 0.3, -rr * 0.35), rr * 0.12, Color(1, 1, 1, 0.7))
	if sp == MatchBoard.LINE_H or sp == MatchBoard.LINE_V:
		var v := Vector2(1, 0) if sp == MatchBoard.LINE_H else Vector2(0, 1)
		for s in [-1, 1]:
			var tip: Vector2 = p + v * s * rr * 1.25
			var side := Vector2(-v.y, v.x)
			draw_colored_polygon(PackedVector2Array([tip, tip - v * s * rr * 0.35 + side * rr * 0.25, tip - v * s * rr * 0.35 - side * rr * 0.25]), Color.WHITE)
		draw_line(p - v * rr * 0.8, p + v * rr * 0.8, Color(1, 1, 1, 0.85), cs * 0.05, true)
	elif sp == MatchBoard.BOMB:
		draw_arc(p, rr * 1.15, 0, TAU, 24, Color.WHITE, cs * 0.05, true)
		for a in 4:
			var ang := TAU * a / 4.0 + PI / 4.0
			draw_circle(p + Vector2(cos(ang), sin(ang)) * rr * 1.15, cs * 0.05, Color.WHITE)


static func shape_pts(c: Vector2, k: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	match k % 6:
		0:   # round moonflower
			for i in 20:
				var a := TAU * i / 20.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
		1:   # diamond
			pts = PackedVector2Array([c + Vector2(0, -r * 1.1), c + Vector2(r * 0.9, 0), c + Vector2(0, r * 1.1), c + Vector2(-r * 0.9, 0)])
		2:   # triangle (drop)
			pts = PackedVector2Array([c + Vector2(0, -r * 1.05), c + Vector2(r * 1.0, r * 0.8), c + Vector2(-r * 1.0, r * 0.8)])
		3:   # rounded square (leaf bud)
			var q := r * 0.85
			pts = PackedVector2Array([c + Vector2(-q, -q * 0.7), c + Vector2(-q * 0.7, -q), c + Vector2(q * 0.7, -q), c + Vector2(q, -q * 0.7),
				c + Vector2(q, q * 0.7), c + Vector2(q * 0.7, q), c + Vector2(-q * 0.7, q), c + Vector2(-q, q * 0.7)])
		4:   # five-point star
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * (r * 1.1 if i % 2 == 0 else r * 0.5))
		_:   # hexagon
			for i in 6:
				var a := TAU * i / 6.0
				pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts
