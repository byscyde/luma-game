class_name PushBoardView
extends Control
## Draws a Stone Steps terrace (rock walls, paths, spillway sockets, boulders,
## Luma) and turns input into requests: a swipe asks for one step, a tap on a
## reachable cell asks to walk there, a tap on a boulder next to Luma asks to
## push it. Holds no rules; the screen owns the PushBoard.
## Shapes, not only colour: sockets are notched square grooves, boulders are
## round; a boulder in a socket shows a water ring and a band.

signal step_requested(dir: String)
signal walk_requested(path: Array)

const PAD := 0.15
const MAX_CELL := 140.0
const SWIPE_MIN := 22.0
const STEP_TIME := 0.09
const ROCK_TOP := Color("8d8a7a")
const ROCK_SIDE := Color("5e5b4f")
const MOSS := Color("7fa35a")
const PATH_A := Color("d9c49a")
const PATH_B := Color("cfb98d")
const SOCKET := Color("6d5a3e")
const WATER := Color("57b8d6")
const BOULDER := Color("a7a39a")
const BOULDER_DARK := Color("6f6a61")

var board: PushBoard
var input_enabled := true
var cell_size := 100.0
var origin := Vector2.ZERO
var highlight := Vector2i(-1, -1)
var _path: Array = []           ## cells Luma passes through in the current animation
var _boulder_from := Vector2i(-1, -1)
var _boulder_to := Vector2i(-1, -1)
var _t := 1.0
var _time := 0.0
var _down := false
var _down_pos := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func setup(b: PushBoard) -> void:
	board = b
	_path = [b.player]
	_t = 1.0
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
	return c if board != null and c.x >= 0 and c.y >= 0 and c.x < board.w and c.y < board.h else Vector2i(-1, -1)


## Animates the last action: Luma along `path` (cells, ending where she is
## now); a pushed boulder slides from `b_from` to `b_to`.
func animate_walk(path: Array, b_from: Vector2i, b_to: Vector2i) -> void:
	_path = path
	_boulder_from = b_from
	_boulder_to = b_to
	_t = 0.0 if not Game.reduced_motion() else 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _t < 1.0:
		_t = minf(1.0, _t + delta / (STEP_TIME * maxi(1, _path.size() - 1)))
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
		accept_event()
	elif (moved or released) and _down:
		var d := pos - _down_pos
		if d.length() >= SWIPE_MIN * maxf(1.0, cell_size / 100.0):
			_down = false
			if absf(d.x) >= absf(d.y):
				step_requested.emit("E" if d.x > 0 else "W")
			else:
				step_requested.emit("S" if d.y > 0 else "N")
		elif released:
			_down = false
			_tap(cell_at(pos))
		accept_event()


func _tap(c: Vector2i) -> void:
	if c == Vector2i(-1, -1) or c == board.player:
		return
	var delta := c - board.player
	if board.boulders.has(c) and absi(delta.x) + absi(delta.y) == 1:
		for dir in PushBoard.DIRS:
			if PushBoard.DIRS[dir] == delta:
				step_requested.emit(dir)
		return
	var paths := board.walk_paths()
	if paths.has(c):
		walk_requested.emit(paths[c])


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if board == null:
		return
	var cs := cell_size
	var tray := Rect2(origin - Vector2.ONE * cs * PAD, Vector2(board.w, board.h) * cs + Vector2.ONE * cs * PAD * 2.0)
	draw_rect(Rect2(tray.position + Vector2(0, cs * 0.08), tray.size), Color(0, 0, 0, 0.22))
	draw_rect(tray, ROCK_SIDE)
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			var r := Rect2(origin + Vector2(c) * cs, Vector2.ONE * cs)
			if board.walls.has(c):
				continue
			draw_rect(r, PATH_A if (x + y) % 2 == 0 else PATH_B)
			draw_rect(Rect2(r.position + Vector2(0, r.size.y - cs * 0.05), Vector2(r.size.x, cs * 0.05)), Color(0, 0, 0, 0.06))
			if board.sockets.has(c):
				_draw_socket(r, board.boulders.has(c))
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			if board.walls.has(c):
				_draw_wall(c)
	if highlight != Vector2i(-1, -1):
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		var hr := Rect2(origin + Vector2(highlight) * cs, Vector2.ONE * cs).grow(-cs * 0.06)
		draw_rect(hr, Color(1, 0.85, 0.3, 0.5 + 0.4 * pulse), false, cs * 0.06)
	var e := _ease(_t) if _path.size() <= 2 else _t
	for c in board.boulders:
		var at := Vector2(c)
		if c == _boulder_to and _t < 1.0:
			at = Vector2(_boulder_from).lerp(Vector2(c), e)
		_draw_boulder(origin + (at + Vector2(0.5, 0.5)) * cs, board.sockets.has(c) and _t >= 1.0)
	_draw_luma(origin + (_luma_at(e) + Vector2(0.5, 0.5)) * cs)


func _luma_at(e: float) -> Vector2:
	if _t >= 1.0 or _path.size() < 2:
		return Vector2(board.player)
	var f := e * (_path.size() - 1)
	var k := mini(int(f), _path.size() - 2)
	return Vector2(_path[k]).lerp(Vector2(_path[k + 1]), f - k)


func _ease(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


func _draw_wall(c: Vector2i) -> void:
	var cs := cell_size
	var r := Rect2(origin + Vector2(c) * cs, Vector2.ONE * cs)
	draw_rect(r, ROCK_SIDE)
	var top := Rect2(r.position + Vector2(cs * 0.03, cs * 0.02), Vector2(cs * 0.94, cs * 0.8))
	draw_rect(top, ROCK_TOP)
	# stone joints and a tuft of moss make walls read as rock, not as colour
	draw_line(top.position + Vector2(0, top.size.y * 0.5), top.position + Vector2(top.size.x, top.size.y * 0.5), Color(0, 0, 0, 0.12), cs * 0.02)
	var jx := top.size.x * (0.35 if (c.x + c.y) % 2 == 0 else 0.65)
	draw_line(top.position + Vector2(jx, 0), top.position + Vector2(jx, top.size.y * 0.5), Color(0, 0, 0, 0.12), cs * 0.02)
	if (c.x * 7 + c.y * 3) % 4 == 0:
		draw_circle(top.position + Vector2(top.size.x * 0.25, cs * 0.06), cs * 0.09, MOSS)
		draw_circle(top.position + Vector2(top.size.x * 0.38, cs * 0.04), cs * 0.07, MOSS.lightened(0.15))


func _draw_socket(r: Rect2, full: bool) -> void:
	var cs := cell_size
	var g := r.grow(-cs * 0.16)
	draw_rect(g, SOCKET)
	draw_rect(g.grow(-cs * 0.05), Color("2f6f8a"))
	# notches on all four sides: a spillway groove
	for k in 4:
		var d := Vector2(PushBoard.DIRS.values()[k])
		var p := r.get_center() + d * cs * 0.34
		draw_rect(Rect2(p - Vector2.ONE * cs * 0.05, Vector2.ONE * cs * 0.1), SOCKET)
	if not full:
		var wave := sin(_time * 2.5) * cs * 0.02
		for k in 2:
			var y := g.position.y + g.size.y * (0.4 + k * 0.25) + wave
			draw_line(Vector2(g.position.x + cs * 0.08, y), Vector2(g.end.x - cs * 0.08, y), Color(WATER.lightened(0.3), 0.8), cs * 0.03, true)


func _draw_boulder(p: Vector2, seated: bool) -> void:
	var cs := cell_size
	if seated:
		draw_arc(p, cs * 0.44, 0, TAU, 36, Color(WATER, 0.8), cs * 0.05, true)
	draw_circle(p + Vector2(0, cs * 0.06), cs * 0.36, Color(0, 0, 0, 0.25))
	draw_circle(p, cs * 0.36, BOULDER_DARK)
	draw_circle(p + Vector2(-cs * 0.02, -cs * 0.03), cs * 0.32, BOULDER)
	draw_circle(p + Vector2(-cs * 0.12, -cs * 0.13), cs * 0.09, BOULDER.lightened(0.3))
	draw_arc(p + Vector2(cs * 0.06, cs * 0.04), cs * 0.12, 0.3, 1.8, 10, BOULDER_DARK, cs * 0.025, true)
	if seated:
		draw_line(p + Vector2(-cs * 0.3, cs * 0.06), p + Vector2(cs * 0.3, cs * 0.06), Color(WATER, 0.9), cs * 0.06, true)


func _draw_luma(p: Vector2) -> void:
	var cs := cell_size
	var bob := sin(_time * 3.0) * cs * 0.02
	var c := p + Vector2(0, bob)
	draw_circle(c, cs * 0.42, Color(1.0, 0.92, 0.55, 0.22))
	draw_circle(p + Vector2(0, cs * 0.3), cs * 0.2, Color(0, 0, 0, 0.15))
	draw_circle(c, cs * 0.26, Color("fff2b3"))
	draw_circle(c, cs * 0.21, Color("ffe07a"))
	# leaf hat
	draw_colored_polygon(PackedVector2Array([c + Vector2(-cs * 0.02, -cs * 0.2), c + Vector2(cs * 0.2, -cs * 0.38), c + Vector2(cs * 0.06, -cs * 0.16)]), Color("5fb648"))
	draw_circle(c + Vector2(-cs * 0.08, -cs * 0.02), cs * 0.035, Color("3a2a22"))
	draw_circle(c + Vector2(cs * 0.08, -cs * 0.02), cs * 0.035, Color("3a2a22"))
	draw_arc(c + Vector2(0, cs * 0.05), cs * 0.06, 0.4, PI - 0.4, 8, Color("3a2a22"), cs * 0.02, true)
