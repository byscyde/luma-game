class_name SlideBoardView
extends BoardView
## BoardView for Ember Reef: a swipe across the grid slides that row or column.
## Emits `slide_requested(move)`; the screen applies it to the SlideBoard.

signal slide_requested(move: Array)

const SWIPE_MIN := 18.0

var inner_w := 3
var inner_h := 3
var _down := false
var _down_pos := Vector2.ZERO
var _down_cell := Vector2i(-1, -1)


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
		if d.length() >= SWIPE_MIN * maxf(1.0, cell_size / 100.0):
			_down = false
			_emit_swipe(d)
		elif released:
			_down = false
		accept_event()


func _emit_swipe(d: Vector2) -> void:
	var c := _down_cell
	if c == Vector2i(-1, -1):
		return
	var ix := c.x - 1
	var iy := c.y - 1
	if absf(d.x) >= absf(d.y):
		if iy < 0 or iy >= inner_h:
			return
		slide_requested.emit(["r", iy, 1 if d.x > 0 else -1])
	else:
		if ix < 0 or ix >= inner_w:
			return
		slide_requested.emit(["c", ix, 1 if d.y > 0 else -1])


## Highlights a whole row or column (hint).
func highlight_line(move: Array) -> void:
	for p in views:
		var on: bool = not move.is_empty() and ((move[0] == "r" and p.y == int(move[1]) + 1 and p.x >= 1 and p.x <= inner_w) \
			or (move[0] == "c" and p.x == int(move[1]) + 1 and p.y >= 1 and p.y <= inner_h))
		views[p].highlight = on
