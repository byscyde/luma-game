class_name BridgeBoardView
extends Control
## Draws a Rope Isles board (sea, islets with their numbers, rope bridges) and
## turns input into `link_tapped(k)`: drag from an islet toward a neighbour, or
## tap the water between two islets. Holds no rules; the screen owns the board.
## Status is shown by shape too: a finished islet gets a ring and a tick, an
## overfull one a broken ring and a cross.

signal link_tapped(k: int)

const PAD := 0.35
const MAX_CELL := 120.0
const DRAG_MIN := 24.0
const SEA_TOP := Color("4aa6c8")
const SEA_BOTTOM := Color("2f7fa8")
const SAND := Color("f2deb0")
const SAND_EDGE := Color("c9a86a")
const GRASS := Color("7fbf5a")
const ROPE := Color("8a5a2b")
const PLANK := Color("c9935a")
const DONE := Color("2c97a3")
const OVER := Color("d9534f")

var board: BridgeBoard
var input_enabled := true
var cell_size := 100.0
var origin := Vector2.ZERO
var highlight := -1
var _time := 0.0
var _down := false
var _down_pos := Vector2.ZERO
var _down_island := -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func setup(b: BridgeBoard) -> void:
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


func _process(delta: float) -> void:
	_time += delta
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
		_down_island = _island_near(pos)
		accept_event()
	elif (moved or released) and _down:
		var d := pos - _down_pos
		if _down_island >= 0 and d.length() >= DRAG_MIN * maxf(1.0, cell_size / 100.0):
			_down = false
			var k := _link_from(_down_island, d)
			if k >= 0:
				link_tapped.emit(k)
		elif released:
			_down = false
			var k := link_at(pos)
			if k >= 0:
				link_tapped.emit(k)
		accept_event()


func _island_near(pos: Vector2) -> int:
	for i in board.islands.size():
		if pos.distance_to(cell_center(board.cell(i))) <= cell_size * 0.5:
			return i
	return -1


## The link leaving islet i in the direction of drag d.
func _link_from(i: int, d: Vector2) -> int:
	var dir := Vector2i(signi(int(d.x)), 0) if absf(d.x) >= absf(d.y) else Vector2i(0, signi(int(d.y)))
	for k in board.links.size():
		var a: int = board.links[k][0]
		var b: int = board.links[k][1]
		if a == i and (board.cell(b) - board.cell(a)).sign() == dir:
			return k
		if b == i and (board.cell(a) - board.cell(b)).sign() == dir:
			return k
	return -1


## The link whose open-water span contains pos (between, not on, the islets).
func link_at(pos: Vector2) -> int:
	var best := -1
	var best_d := cell_size * 0.42
	for k in board.links.size():
		var a := cell_center(board.cell(board.links[k][0]))
		var b := cell_center(board.cell(board.links[k][1]))
		var t := clampf((pos - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		var along := (b - a).length() * t
		if along < cell_size * 0.4 or along > (b - a).length() - cell_size * 0.4:
			continue
		var dist := pos.distance_to(a.lerp(b, t))
		if dist < best_d:
			best_d = dist
			best = k
	return best


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if board == null:
		return
	var cs := cell_size
	var r := Rect2(origin - Vector2.ONE * cs * PAD, Vector2(board.w, board.h) * cs + Vector2.ONE * cs * PAD * 2.0)
	draw_rect(Rect2(r.position + Vector2(0, cs * 0.08), r.size), Color(0, 0, 0, 0.2))
	var steps := 14
	for k in steps:
		var sr := Rect2(r.position + Vector2(0, r.size.y * k / steps), Vector2(r.size.x, r.size.y / steps + 1))
		draw_rect(sr, SEA_TOP.lerp(SEA_BOTTOM, float(k) / (steps - 1)))
	# gentle wave marks
	for y in board.h:
		for x in board.w:
			if (x * 5 + y * 3) % 4 == 0:
				var p := cell_center(Vector2i(x, y)) + Vector2(sin(_time * 0.8 + x) * cs * 0.06, cs * 0.1)
				draw_arc(p, cs * 0.12, PI * 1.15, PI * 1.85, 8, Color(1, 1, 1, 0.22), cs * 0.025, true)
	for k in board.links.size():
		if k == highlight:
			var a := cell_center(board.cell(board.links[k][0]))
			var b := cell_center(board.cell(board.links[k][1]))
			var pulse := 0.5 + 0.5 * sin(_time * 6.0)
			draw_line(a, b, Color(1, 0.88, 0.35, 0.35 + 0.35 * pulse), cs * 0.34, true)
		if board.state[k] > 0:
			_draw_bridge(k)
	for i in board.islands.size():
		_draw_islet(i)


func _draw_bridge(k: int) -> void:
	var cs := cell_size
	var a := cell_center(board.cell(board.links[k][0]))
	var b := cell_center(board.cell(board.links[k][1]))
	var dir := (b - a).normalized()
	var side := Vector2(-dir.y, dir.x)
	var n := int(board.state[k])
	for m in n:
		var off := side * cs * (0.0 if n == 1 else (-0.13 if m == 0 else 0.13))
		var pa := a + off + dir * cs * 0.3
		var pb := b + off - dir * cs * 0.3
		draw_line(pa + Vector2(0, cs * 0.04), pb + Vector2(0, cs * 0.04), Color(0, 0, 0, 0.2), cs * 0.12, true)
		var len := pa.distance_to(pb)
		var planks := maxi(2, int(len / (cs * 0.16)))
		for p in planks:
			var q := pa.lerp(pb, (p + 0.5) / planks)
			draw_line(q - side * cs * 0.07, q + side * cs * 0.07, PLANK, cs * 0.07)
		draw_line(pa - side * cs * 0.065, pb - side * cs * 0.065, ROPE, cs * 0.025, true)
		draw_line(pa + side * cs * 0.065, pb + side * cs * 0.065, ROPE, cs * 0.025, true)


func _draw_islet(i: int) -> void:
	var cs := cell_size
	var p := cell_center(board.cell(i))
	var deg := board.degree(i)
	var need := board.need(i)
	draw_circle(p + Vector2(0, cs * 0.06), cs * 0.38, Color(0, 0, 0, 0.2))
	draw_circle(p, cs * 0.38, SAND_EDGE)
	draw_circle(p + Vector2(0, -cs * 0.02), cs * 0.34, SAND)
	draw_arc(p + Vector2(-cs * 0.1, -cs * 0.12), cs * 0.12, PI, TAU, 10, GRASS, cs * 0.05, true)
	if deg == need:
		draw_arc(p, cs * 0.43, 0, TAU, 36, DONE, cs * 0.05, true)
		draw_polyline(PackedVector2Array([p + Vector2(cs * 0.2, -cs * 0.34), p + Vector2(cs * 0.26, -cs * 0.28), p + Vector2(cs * 0.38, -cs * 0.42)]), DONE, cs * 0.05, true)
	elif deg > need:
		for k in 6:
			draw_arc(p, cs * 0.43, TAU * k / 6.0, TAU * k / 6.0 + 0.6, 6, OVER, cs * 0.05, true)
		var e := cs * 0.07
		var q := p + Vector2(cs * 0.3, -cs * 0.34)
		draw_line(q - Vector2(e, e), q + Vector2(e, e), OVER, cs * 0.04, true)
		draw_line(q + Vector2(e, -e), q - Vector2(e, -e), OVER, cs * 0.04, true)
	var font := get_theme_default_font()
	var fs := int(cs * 0.42)
	var txt := str(need)
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var col := Color("23423a") if deg <= need else OVER
	draw_string(font, p + Vector2(-tw.x * 0.5, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
