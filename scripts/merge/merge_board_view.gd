class_name MergeBoardView
extends Control
## Draws a MergeGame board (7 x 9) and turns touches into taps and drags.
## Holds no rules: it emits `cell_tapped` / `cell_dropped` and redraws when
## the game changes.

signal cell_tapped(cell: Vector2i)
signal cell_dropped(from: Vector2i, to: Vector2i)

const TILE_A := Color("fff8ea")
const TILE_B := Color("f6ead2")
const TILE_EDGE := Color("e6d3b0")
const FRAME := Color("f3dcb2")
const FRAME_DARK := Color("b9874f")
const DRAG_START := 12.0

var game: MergeGame
var selected := Vector2i(-1, -1)
var needed: Dictionary = {}        ## item id -> true when an order asks for it
var cell := 90.0
var origin := Vector2.ZERO
var _press_cell := Vector2i(-1, -1)
var _press_pos := Vector2.ZERO
var _drag_pos := Vector2.ZERO
var _dragging := false
var _pops: Dictionary = {}         ## Vector2i -> start time (s) of a pop animation
var _bursts: Array = []            ## [Vector2 centre, start time]
var _t := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeBuilder.font_bold()
	resized.connect(_layout)


func setup(p_game: MergeGame) -> void:
	game = p_game
	_layout()


func _layout() -> void:
	if game == null:
		return
	var cols := float(game.db.cols)
	var rows := float(game.db.rows)
	cell = floorf(minf((size.x - 16.0) / cols, (size.y - 16.0) / rows))
	origin = ((size - Vector2(cols, rows) * cell) * 0.5).floor()
	queue_redraw()


func cell_rect(c: Vector2i) -> Rect2:
	return Rect2(origin + Vector2(c) * cell, Vector2(cell, cell))


func cell_center(c: Vector2i) -> Vector2:
	return cell_rect(c).get_center()


func cell_at(p: Vector2) -> Vector2i:
	var g := ((p - origin) / cell).floor()
	var c := Vector2i(int(g.x), int(g.y))
	return c if game != null and game.in_bounds(c) else Vector2i(-1, -1)


## Pop animation on a tile (spawn, merge result).
func pop(c: Vector2i, burst := false) -> void:
	_pops[c] = _t
	if burst and not Game.reduced_motion():
		_bursts.append([cell_center(c), _t])


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()   # timers, bubbles and animations; a single cheap draw call list


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if game == null:
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
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _press_cell != Vector2i(-1, -1):
		moved = true
		pos = event.position
	if pressed:
		_press_cell = cell_at(pos)
		_press_pos = pos
		_drag_pos = pos
		_dragging = false
		accept_event()
	elif moved:
		_drag_pos = pos
		if not _dragging and pos.distance_to(_press_pos) > DRAG_START and game.at(_press_cell) != null:
			_dragging = true
		accept_event()
	elif released and _press_cell != Vector2i(-1, -1):
		var from := _press_cell
		_press_cell = Vector2i(-1, -1)
		if _dragging:
			_dragging = false
			var to := cell_at(pos)
			if to != Vector2i(-1, -1) and to != from:
				cell_dropped.emit(from, to)
		elif cell_at(pos) == from:
			cell_tapped.emit(from)
		accept_event()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if game == null:
		return
	var now := int(Time.get_unix_time_from_system())
	var board := Rect2(origin, Vector2(game.db.cols, game.db.rows) * cell)
	# soft shadow, wooden rim, cream tray, rounded tiles with a lip
	draw_style_box(_box(Color(0.1, 0.06, 0.02, 0.22), cell * 0.3), board.grow(cell * 0.2).grow_side(SIDE_BOTTOM, cell * 0.14))
	draw_style_box(_box(FRAME_DARK, cell * 0.28), board.grow(cell * 0.17).grow_side(SIDE_BOTTOM, cell * 0.07))
	draw_style_box(_box(FRAME, cell * 0.24), board.grow(cell * 0.12))
	for y in game.db.rows:
		for x in game.db.cols:
			var c := Vector2i(x, y)
			var tr := cell_rect(c).grow(-cell * 0.035)
			draw_style_box(_box(TILE_EDGE, cell * 0.16), tr.grow_side(SIDE_BOTTOM, cell * 0.03))
			draw_style_box(_box(TILE_A if (x + y) % 2 == 0 else TILE_B, cell * 0.16), tr)
	if selected != Vector2i(-1, -1) and game.at(selected) != null:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_style_box(_box(Color(0, 0, 0, 0), cell * 0.16, Color(1.0, 0.72, 0.2, 0.7 + 0.3 * pulse), maxf(3.0, cell * 0.05)), cell_rect(selected).grow(-cell * 0.02))
	# items
	for y in game.db.rows:
		for x in game.db.cols:
			var c := Vector2i(x, y)
			if _dragging and c == _press_cell:
				continue
			var v = game.at(c)
			if v != null:
				_draw_item(c, v, cell_rect(c), now)
	# merge sparkles
	var keep: Array = []
	for b in _bursts:
		var k: float = (_t - float(b[1])) / 0.45
		if k < 1.0:
			keep.append(b)
			for i in 8:
				var a := TAU * i / 8.0
				draw_circle(b[0] + Vector2(cos(a), sin(a)) * cell * (0.3 + 0.35 * k), cell * 0.05 * (1.0 - k), Color(1.0, 0.92, 0.5, 1.0 - k), true, -1, true)
			draw_arc(b[0], cell * (0.25 + 0.4 * k), 0, TAU, 32, Color(1, 1, 1, 0.7 * (1.0 - k)), cell * 0.04, true)
	_bursts = keep
	# dragged item follows the finger
	if _dragging:
		var v = game.at(_press_cell)
		if v != null:
			var r := Rect2(_drag_pos - Vector2(cell, cell) * 0.6, Vector2(cell, cell) * 1.2)
			draw_circle(_drag_pos + Vector2(0, cell * 0.35), cell * 0.35, Color(0, 0, 0, 0.12), true, -1, true)
			ItemArt.draw_3d(self, v["id"], r.grow(-cell * 0.06))
			var target := cell_at(_drag_pos)
			if target != Vector2i(-1, -1) and target != _press_cell:
				var tv = game.at(target)
				var col := Color(0.35, 0.85, 0.45, 0.8) if tv != null and tv["id"] == v["id"] and not game.db.is_max(v["id"]) else Color(1, 1, 1, 0.6)
				draw_style_box(_box(Color(0, 0, 0, 0), cell * 0.16, col, maxf(3.0, cell * 0.045)), cell_rect(target).grow(-cell * 0.04))


func _draw_item(c: Vector2i, v: Dictionary, r: Rect2, now: int) -> void:
	var id: String = v["id"]
	var scale := 1.0
	if _pops.has(c):
		var k: float = (_t - float(_pops[c])) / 0.28
		if k >= 1.0:
			_pops.erase(c)
		else:
			scale = 0.55 + 0.6 * sin(k * PI * 0.5) - 0.15 * sin(k * PI)
	var ir := Rect2(r.get_center() - r.size * 0.5 * scale, r.size * scale).grow(-cell * 0.05)
	var boxed: bool = v.get("boxed", false)
	var bubble := float(v.get("bubble_until", 0)) > 0.0
	if boxed:
		_draw_crate(r, id)
		return
	ItemArt.draw_3d(self, id, ir)
	if bubble:
		var left := maxi(0, int(v["bubble_until"]) - now)
		draw_circle(r.get_center(), cell * 0.46, Color(0.7, 0.9, 1.0, 0.28), true, -1, true)
		draw_arc(r.get_center(), cell * 0.46, 0, TAU, 36, Color(1, 1, 1, 0.85), maxf(2.0, cell * 0.03), true)
		draw_arc(r.get_center() + Vector2(-cell * 0.14, -cell * 0.14), cell * 0.12, PI * 1.1, PI * 1.6, 10, Color(1, 1, 1, 0.9), maxf(2.0, cell * 0.03), true)
		_badge_text(r.position + Vector2(r.size.x * 0.5, r.size.y - cell * 0.1), "%ds" % left, Color("2c97a3"))
		return
	var kind := game.db.kind(id)
	if kind == "generator":
		var free := int(game.db.gen_def(id, "energy", 1)) == 0
		if free:
			var charges := int(v.get("charges", game.db.gen_def(id, "charges", 0)))
			var until := int(v.get("cool_until", 0))
			if charges <= 0 and until > now:
				var total := float(game.db.gen_def(id, "cooldown", 1))
				draw_circle(r.get_center(), cell * 0.44, Color(0, 0, 0, 0.25), true, -1, true)
				draw_arc(r.get_center(), cell * 0.36, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - (until - now) / total), 32, Color("7fd6e0"), cell * 0.06, true)
				_badge_text(r.get_center() + Vector2(0, cell * 0.08), _clock(until - now), Color("35505a"))
			else:
				_corner_badge(r, str(maxi(0, charges)), Color("4fb36a"))
		else:
			_energy_badge(r)
	elif kind == "chest":
		var until := int(v.get("timer_until", 0))
		if until > now:
			_badge_text(r.position + Vector2(r.size.x * 0.5, r.size.y - cell * 0.1), _clock(until - now), Color("8a5a2b"))
		elif until > 0:
			_corner_badge(r, "!", Color("e2554f"))
	elif kind == "tool":
		_corner_badge(r, "x%d" % int(v.get("uses", 1)), Color("6c7a88"))
	if needed.has(id):
		var p := r.position + Vector2(r.size.x - cell * 0.18, cell * 0.18)
		draw_circle(p, cell * 0.13, Color.WHITE, true, -1, true)
		draw_circle(p, cell * 0.105, Color("4fb36a"), true, -1, true)
		draw_polyline(PackedVector2Array([p + Vector2(-cell * 0.05, 0), p + Vector2(-cell * 0.01, cell * 0.04), p + Vector2(cell * 0.06, -cell * 0.04)]), Color.WHITE, maxf(2.0, cell * 0.03), true)


## A wooden crate with a paper label showing what is inside.
func _draw_crate(r: Rect2, id: String) -> void:
	ItemArt.draw_3d(self, "crate:1", r.grow(-cell * 0.04))
	var label := Rect2(r.get_center() - Vector2(cell * 0.22, cell * 0.19), Vector2(cell * 0.44, cell * 0.44))
	draw_style_box(_box(Color(1, 0.98, 0.92, 0.92), cell * 0.08), label)
	ItemArt.draw_3d(self, id, label.grow(-cell * 0.04))


func _energy_badge(r: Rect2) -> void:
	var p := r.position + Vector2(cell * 0.17, cell * 0.17)
	draw_circle(p, cell * 0.12, Color.WHITE, true, -1, true)
	draw_circle(p, cell * 0.1, Color("4fb36a"), true, -1, true)
	var b := cell * 0.06
	draw_colored_polygon(PackedVector2Array([p + Vector2(b * 0.2, -b), p + Vector2(-b * 0.6, b * 0.15), p + Vector2(0, b * 0.15),
		p + Vector2(-b * 0.2, b), p + Vector2(b * 0.6, -b * 0.15), p + Vector2(0, -b * 0.15)]), Color("fff36b"))


func _corner_badge(r: Rect2, text: String, col: Color) -> void:
	var p := r.position + Vector2(r.size.x - cell * 0.2, r.size.y - cell * 0.2)
	draw_circle(p, cell * 0.15, Color.WHITE, true, -1, true)
	draw_circle(p, cell * 0.125, col, true, -1, true)
	var fs := int(cell * 0.17)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, p + Vector2(-w * 0.5, fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _badge_text(center: Vector2, text: String, col: Color) -> void:
	var fs := int(cell * 0.17)
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var rr := Rect2(center - Vector2(w * 0.5 + cell * 0.07, fs * 0.65), Vector2(w + cell * 0.14, fs * 1.3))
	draw_style_box(_box(col, fs * 0.6), rr)
	draw_string(_font, Vector2(center.x - w * 0.5, center.y + fs * 0.33), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


static func _clock(sec: int) -> String:
	if sec >= 3600:
		return "%dh%02dm" % [sec / 3600, (sec % 3600) / 60]
	return "%d:%02d" % [sec / 60, sec % 60]


func _box(col: Color, radius: float, border := Color(0, 0, 0, 0), border_w := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if border_w > 0.0:
		sb.border_color = border
		sb.set_border_width_all(int(border_w))
	return sb
