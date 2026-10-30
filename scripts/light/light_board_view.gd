class_name LightBoardView
extends Control
## Draws a Lantern Bay board (night harbour tray, lanterns, mirrors, crystals,
## blooms, beams) and turns taps into `mirror_tapped(cell)`. Holds no rules:
## the screen owns the LightBoard and passes in each trace.
## Shapes carry the meaning, not only colour: round notched disc = tappable
## mirror, square riveted plate = fixed mirror, diamond = crystal, petals = bloom.

signal mirror_tapped(cell: Vector2i)

const PAD := 0.22
const MAX_CELL := 150.0
const TRAY_TOP := Color("27355a")
const TRAY_BOTTOM := Color("1b2442")
const TRAY_EDGE := Color("10162b")
const SLOT := Color("1f2a4b")
const SLOT_LIGHT := Color(1, 1, 1, 0.045)
const BEAM := Color("ffd76a")
const BEAM_CORE := Color("fff6d8")
const GLASS := Color("cfe6f2")
const GLASS_EDGE := Color("6f8fb0")
const DISC := Color("d9c7a3")
const DISC_EDGE := Color("8b7651")
const PLATE := Color("8f97a8")
const PLATE_EDGE := Color("4d5468")
const CRYSTAL := Color("7fd6e8")
const CRYSTAL_LIT := Color("e8fbff")
const BLOOM := Color("9b7fd1")
const BLOOM_BURNT := Color("e0604f")
const ROCK := Color("4b4f63")

var board: LightBoard
var trace_result: Dictionary = {}
var input_enabled := true
var cell_size := 100.0
var origin := Vector2.ZERO
var highlight := Vector2i(-1, -1)
var _beam_alpha := 1.0
var _spin: Dictionary = {}      ## cell -> remaining flip animation (0..1)
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_layout)


func setup(b: LightBoard) -> void:
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


func _gui_input(event: InputEvent) -> void:
	if not input_enabled or board == null:
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return   # touches also arrive as emulated mouse events
	var tap := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap = true
		pos = event.position
	elif event is InputEventScreenTouch and event.index == 0 and event.pressed:
		tap = true
		pos = event.position
	if tap:
		var c := cell_at(pos)
		if c != Vector2i(-1, -1):
			accept_event()
			mirror_tapped.emit(c)


## New beams after a change; fades them in unless `animate` is false.
func show_trace(t: Dictionary, animate: bool) -> void:
	trace_result = t
	if animate and not Game.reduced_motion():
		_beam_alpha = 0.0
		create_tween().tween_property(self, "_beam_alpha", 1.0, 0.22)
	else:
		_beam_alpha = 1.0
	queue_redraw()


func animate_flip(c: Vector2i) -> void:
	if Game.reduced_motion():
		return
	_spin[c] = 1.0


func _process(delta: float) -> void:
	_time += delta
	for c in _spin.keys():
		_spin[c] = float(_spin[c]) - delta / 0.16
		if float(_spin[c]) <= 0.0:
			_spin.erase(c)
	if board != null and is_visible_in_tree():
		queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if board == null:
		return
	var cs := cell_size
	var tray := Rect2(origin - Vector2.ONE * cs * PAD, Vector2(board.w, board.h) * cs + Vector2.ONE * cs * PAD * 2.0)
	draw_rect(Rect2(tray.position + Vector2(0, cs * 0.06), tray.size), Color(0, 0, 0, 0.25))
	draw_rect(tray, TRAY_EDGE)
	var inner := tray.grow(-cs * 0.05)
	var steps := 12
	for k in steps:
		var r := Rect2(inner.position + Vector2(0, inner.size.y * k / steps), Vector2(inner.size.x, inner.size.y / steps + 1))
		draw_rect(r, TRAY_TOP.lerp(TRAY_BOTTOM, float(k) / (steps - 1)))
	var lit: Dictionary = trace_result.get("lit", {})
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			var r := Rect2(origin + Vector2(c) * cs, Vector2.ONE * cs).grow(-cs * 0.04)
			draw_rect(r, SLOT)
			draw_rect(Rect2(r.position, Vector2(r.size.x, cs * 0.04)), SLOT_LIGHT)
			if lit.has(c) and board.token_at(c) == ".":
				draw_rect(r, Color(BEAM, 0.07 * _beam_alpha))
	_draw_beams()
	for y in board.h:
		for x in board.w:
			_draw_piece(Vector2i(x, y), lit)
	if highlight != Vector2i(-1, -1):
		var pulse := 0.5 + 0.5 * sin(_time * 6.0)
		draw_arc(cell_center(highlight), cs * (0.46 + 0.03 * pulse), 0, TAU, 40, Color(BEAM, 0.6 + 0.4 * pulse), cs * 0.05, true)


func _draw_beams() -> void:
	var cs := cell_size
	var flicker := 0.85 + 0.15 * sin(_time * 3.1)
	for seg in trace_result.get("segments", []):
		var a := origin + (Vector2(seg[0]) + Vector2(0.5, 0.5)) * cs
		var b := origin + (Vector2(seg[1]) + Vector2(0.5, 0.5)) * cs
		draw_line(a, b, Color(BEAM, 0.18 * _beam_alpha * flicker), cs * 0.3, true)
		draw_line(a, b, Color(BEAM, 0.55 * _beam_alpha), cs * 0.12, true)
		draw_line(a, b, Color(BEAM_CORE, 0.95 * _beam_alpha), cs * 0.045, true)


func _draw_piece(c: Vector2i, lit: Dictionary) -> void:
	var t := board.token_at(c)
	var p := cell_center(c)
	var cs := cell_size
	if t == ".":
		return
	if t == "#":
		var pts := PackedVector2Array()
		for k in 9:
			var ang := TAU * k / 9.0
			var rr := cs * (0.34 + 0.05 * sin(k * 2.7 + c.x * 1.3 + c.y))
			pts.append(p + Vector2(cos(ang), sin(ang)) * rr)
		draw_colored_polygon(_shift(pts, Vector2(0, cs * 0.05)), Color(0, 0, 0, 0.3))
		draw_colored_polygon(pts, ROCK)
		draw_colored_polygon(_shift(_scale(pts, p, 0.55), Vector2(-cs * 0.06, -cs * 0.07)), ROCK.lightened(0.15))
	elif t.begins_with("L"):
		_draw_lantern(p, LightBoard.DIRS[t[1]])
	elif t == "C":
		var on := lit.has(c)
		var s := cs * 0.3
		var pts := PackedVector2Array([p + Vector2(0, -s * 1.15), p + Vector2(s * 0.8, 0), p + Vector2(0, s * 1.15), p + Vector2(-s * 0.8, 0)])
		if on:
			draw_circle(p, cs * 0.42, Color(CRYSTAL_LIT, 0.22 * _beam_alpha))
		draw_colored_polygon(pts, CRYSTAL_LIT if on else CRYSTAL.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([pts[0], pts[1], p]), Color(1, 1, 1, 0.35))
		draw_polyline(_closed(pts), Color("e9fbff") if on else Color("3f7f90"), cs * 0.035, true)
		if on:
			var tw := cs * (0.16 + 0.04 * sin(_time * 4.0 + c.x))
			draw_line(p + Vector2(-tw, -s * 1.3), p + Vector2(tw, -s * 1.3), Color(1, 1, 1, 0.8), cs * 0.02, true)
	elif t == "D":
		var burnt := lit.has(c)
		var col := BLOOM_BURNT if burnt else BLOOM
		for k in 5:
			var ang := TAU * k / 5.0 - PI / 2.0
			draw_circle(p + Vector2(cos(ang), sin(ang)) * cs * 0.17, cs * 0.13, col)
		draw_circle(p, cs * 0.1, Color("f3e3a0") if not burnt else Color("40201c"))
		if burnt:
			var e := cs * 0.3
			draw_line(p + Vector2(-e, -e), p + Vector2(e, e), Color.WHITE, cs * 0.05, true)
			draw_line(p + Vector2(e, -e), p + Vector2(-e, e), Color.WHITE, cs * 0.05, true)
	elif t == "X":
		var s := cs * 0.34
		var pts := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s * 0.95, s * 0.7), p + Vector2(-s * 0.95, s * 0.7)])
		draw_colored_polygon(_shift(pts, Vector2(0, cs * 0.05)), Color(0, 0, 0, 0.3))
		draw_colored_polygon(pts, GLASS)
		draw_colored_polygon(PackedVector2Array([pts[0], p + Vector2(0, s * 0.7), pts[2]]), Color("f7c8e8", 0.6))
		draw_polyline(_closed(pts), GLASS_EDGE, cs * 0.035, true)
	else:
		_draw_mirror(c, p, t)


func _draw_lantern(p: Vector2, d: Vector2i) -> void:
	var cs := cell_size
	draw_circle(p, cs * 0.44, Color(BEAM, 0.18))
	var body := Rect2(p - Vector2(cs * 0.2, cs * 0.24), Vector2(cs * 0.4, cs * 0.48))
	draw_rect(Rect2(body.position + Vector2(0, cs * 0.04), body.size), Color(0, 0, 0, 0.3))
	draw_rect(body, Color("3b2f24"))
	draw_rect(body.grow(-cs * 0.06), Color("ffe08a"))
	draw_rect(Rect2(p - Vector2(cs * 0.24, cs * 0.3), Vector2(cs * 0.48, cs * 0.08)), Color("3b2f24"))
	# direction tab: a triangle on the side the light leaves from
	var f := Vector2(d)
	var side := Vector2(-f.y, f.x)
	var tip := p + f * cs * 0.46
	draw_colored_polygon(PackedVector2Array([tip, p + f * cs * 0.3 + side * cs * 0.12, p + f * cs * 0.3 - side * cs * 0.12]), BEAM)


func _draw_mirror(c: Vector2i, p: Vector2, t: String) -> void:
	var cs := cell_size
	var fixed := t.begins_with("f")
	var ang := -PI / 4.0 if t.ends_with("/") else PI / 4.0
	if _spin.has(c):
		ang += float(_spin[c]) * PI / 2.0
	if fixed:
		var r := Rect2(p - Vector2.ONE * cs * 0.38, Vector2.ONE * cs * 0.76)
		draw_rect(Rect2(r.position + Vector2(0, cs * 0.05), r.size), Color(0, 0, 0, 0.3))
		draw_rect(r, PLATE)
		draw_rect(r, PLATE_EDGE, false, cs * 0.03)
		for k in 4:
			var q := Vector2(-1 if k % 2 == 0 else 1, -1 if k < 2 else 1) * cs * 0.29
			draw_circle(p + q, cs * 0.04, PLATE_EDGE)
	else:
		draw_circle(p + Vector2(0, cs * 0.05), cs * 0.4, Color(0, 0, 0, 0.3))
		draw_circle(p, cs * 0.4, DISC)
		draw_arc(p, cs * 0.4, 0, TAU, 40, DISC_EDGE, cs * 0.03, true)
		for k in 4:
			var na := ang + PI / 4.0 + k * PI / 2.0
			draw_line(p + Vector2(cos(na), sin(na)) * cs * 0.3, p + Vector2(cos(na), sin(na)) * cs * 0.38, DISC_EDGE, cs * 0.04, true)
	var v := Vector2(cos(ang), sin(ang)) * cs * 0.36
	draw_line(p - v, p + v, Color("2d3a55"), cs * 0.13, true)
	draw_line(p - v, p + v, Color("e8f4ff"), cs * 0.08, true)
	draw_line(p - v * 0.9 + Vector2(0, -cs * 0.015), p + v * 0.9 + Vector2(0, -cs * 0.015), Color(1, 1, 1, 0.9), cs * 0.02, true)


func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(q + d)
	return out


func _scale(pts: PackedVector2Array, center: Vector2, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in pts:
		out.append(center + (q - center) * f)
	return out
