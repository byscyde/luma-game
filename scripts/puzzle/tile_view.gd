class_name TileView
extends Node2D
## One puzzle tile, drawn crisp and top-down at its cell centre. Purely visual:
## reads logical state from its PuzzleTile/PuzzleBoard and animates toward it.
##
## Visual language (never colour-only):
##  * rotatable tiles are raised ivory discs with four notches; the disc turns
##  * pinned / fixed tiles are raised square slabs with bronze corner rivets
##  * channels are dark carved grooves that fill with bright, flowing water;
##    spills show falling droplets
##  * gates are wooden planks across the groove, tagged with the link's colour
##    and shape; levers are toggle pills with the same tag
##  * targets are dry saplings on soil that leaf out when water reaches them

const DISC_R := 0.44           ## disc radius (cell units)
const SLAB := 0.86             ## slab side (cell units)
const LIFT := 0.05             ## visible thickness of raised tiles
const GROOVE := 0.25           ## carved groove width
const WATER := 0.165           ## water ribbon width

const DISC_FACE := Color("f6eedb")
const DISC_FACE_LOW := Color("eadcbd")
const DISC_SIDE := Color("c7ae80")
const NOTCH := Color("d3bd91")
const SLAB_FACE := Color("e4dfd4")
const SLAB_FACE_LOW := Color("cec6b6")
const SLAB_SIDE := Color("9d9586")
const RIVET := Color("b9853f")
const GROOVE_FLOOR := Color("33434d")
const GROOVE_DEEP := Color("27343c")
const WATER_COL := Color("2cc3e0")
const WATER_DEEP_COL := Color("1593b8")
const WATER_SHINE := Color("c9fbff")
const SOIL := Color("8a6243")
const SOIL_DARK := Color("6b4a31")
const BARK := Color("7a5534")

var tile: PuzzleTile
var board: PuzzleBoard
var cell := Vector2i.ZERO
var unit := 100.0:             ## cell size in pixels
	set(v):
		unit = v
		queue_redraw()

var rot_offset := 0.0:         ## radians, animates to 0 after a rotation
	set(v):
		rot_offset = v
		queue_redraw()
var press := 1.0:
	set(v):
		press = v
		queue_redraw()
var water := 0.0:
	set(v):
		water = v
		queue_redraw()
var wet := false
var entry_mask := 0
var leak_mask := 0:
	set(v):
		leak_mask = v
		queue_redraw()
var bloom := 0.0:
	set(v):
		bloom = v
		queue_redraw()
var highlight := false:
	set(v):
		highlight = v
		queue_redraw()
var celebrate := 0.0:
	set(v):
		celebrate = v
		queue_redraw()

var block := false             ## Ember Reef sliding block: slab without rivets
var quiet := false             ## frame cell: draw nothing for empty tiles
var _t := 0.0
var _seed := 0
var _gate_open := 0.0          ## 0 closed .. 1 open (eased toward the board state)
var _switch_on := 0.0


func setup(p_tile: PuzzleTile, p_board: PuzzleBoard, p_cell: Vector2i) -> void:
	tile = p_tile
	board = p_board
	cell = p_cell
	_seed = p_cell.x * 31 + p_cell.y * 17
	set_meta("mask", tile.shape_mask())
	if tile.is_gate():
		_gate_open = 1.0 if board.is_gate_open(tile) else 0.0
	if tile.type == TileTypes.SWITCH:
		_switch_on = 1.0 if bool(board.switches.get(tile.link, false)) else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if tile == null:
		return
	_t += delta
	var redraw := not Game.reduced_motion() and (wet or highlight or tile.is_source() or leak_mask != 0)
	if tile.is_gate():
		var want := 1.0 if board.is_gate_open(tile) else 0.0
		if not is_equal_approx(_gate_open, want):
			_gate_open = move_toward(_gate_open, want, delta * 5.0)
			redraw = true
	if tile.type == TileTypes.SWITCH:
		var on := 1.0 if bool(board.switches.get(tile.link, false)) else 0.0
		if not is_equal_approx(_switch_on, on):
			_switch_on = move_toward(_switch_on, on, delta * 7.0)
			redraw = true
	if redraw:
		queue_redraw()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if tile == null:
		return
	var u := unit
	var hop := -sin(celebrate * PI) * 0.08 * u
	draw_set_transform(Vector2(0, hop), 0.0, Vector2(press, press))
	match tile.type:
		TileTypes.EMPTY:
			if not quiet:
				_draw_moss()
		TileTypes.ROCK:
			_draw_rock()
		TileTypes.TARGET:
			_draw_target()
		TileTypes.BONUS:
			_draw_bonus()
		TileTypes.SWITCH:
			_draw_switch()
		TileTypes.SOURCE:
			_draw_slab()
			_draw_channels(SLAB * 0.5, 0.0)
			_draw_spring()
		_:
			if tile.is_rotatable():
				_draw_disc_body()
				_draw_disc_top(rot_offset)
			else:
				_draw_slab()
				_draw_channels(SLAB * 0.5, 0.0)
				if tile.is_gate():
					_draw_gate()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if leak_mask != 0 and wet and water >= 0.99:
		_draw_leaks()
	if highlight:
		var pulse := 0.5 + 0.5 * sin(_t * 6.0)
		draw_arc(Vector2.ZERO, u * (0.53 + 0.02 * pulse), 0, TAU, 48, Color(1.0, 0.8, 0.28, 0.55 + 0.4 * pulse), u * 0.055, true)


## Soft drop shadow under a raised tile (several stacked translucent shapes).
func _shadow_circle(r: float) -> void:
	var u := unit
	for i in 4:
		var k := float(i) / 3.0
		draw_circle(Vector2(0, u * (LIFT + 0.03)), r + u * 0.03 * (1.0 - k), Color(0, 0, 0, 0.07 + 0.05 * k), true, -1, true)


func _shadow_rect(half: float, radius: float) -> void:
	var u := unit
	for i in 4:
		var k := float(i) / 3.0
		var g := u * 0.03 * (1.0 - k)
		_round_rect(Rect2(Vector2(-half - g, -half - g + u * (LIFT + 0.03)), Vector2(half + g, half + g) * 2.0), radius + g, Color(0, 0, 0, 0.07 + 0.05 * k))


func _draw_disc_body() -> void:
	var u := unit
	var r := DISC_R * u
	_shadow_circle(r)
	draw_circle(Vector2(0, u * LIFT), r, DISC_SIDE, true, -1, true)
	# face: base colour, then a lighter upper half for a soft top light
	draw_circle(Vector2.ZERO, r, DISC_FACE_LOW, true, -1, true)
	draw_circle(Vector2(0, -r * 0.06), r * 0.94, DISC_FACE, true, -1, true)
	draw_arc(Vector2.ZERO, r - u * 0.012, PI * 1.08, PI * 1.92, 32, Color(1, 1, 1, 0.65), u * 0.02, true)


func _draw_disc_top(angle: float) -> void:
	var u := unit
	draw_set_transform(Vector2(0, -sin(celebrate * PI) * 0.08 * u), angle, Vector2(press, press))
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		var p := Vector2(cos(a), sin(a)) * DISC_R * u * 0.74
		draw_circle(p, u * 0.036, NOTCH, true, -1, true)
		draw_circle(p + Vector2(0, -u * 0.008), u * 0.026, NOTCH.darkened(0.12), true, -1, true)
	_draw_channels(DISC_R, angle)


func _draw_slab() -> void:
	var u := unit
	var half := SLAB * 0.5 * u
	var rad := 0.16 * u
	_shadow_rect(half, rad)
	_round_rect(Rect2(Vector2(-half, -half + u * LIFT), Vector2(half, half) * 2.0), rad, SLAB_SIDE)
	_round_rect(Rect2(Vector2(-half, -half), Vector2(half, half) * 2.0), rad, SLAB_FACE_LOW)
	_round_rect(Rect2(Vector2(-half + u * 0.02, -half + u * 0.01), Vector2(half - u * 0.02, half - u * 0.05) * 2.0), rad * 0.9, SLAB_FACE)
	if block:
		# sliding block: grip ridges instead of rivets (it moves with its row/column)
		for k in [-1.0, 1.0]:
			draw_line(Vector2(-half * 0.55, k * half * 0.78), Vector2(half * 0.55, k * half * 0.78), Color(0, 0, 0, 0.12), u * 0.025, true)
		return
	for v in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var p: Vector2 = v * half * 0.72
		draw_circle(p + Vector2(0, u * 0.01), u * 0.04, RIVET.darkened(0.3), true, -1, true)
		draw_circle(p, u * 0.038, RIVET, true, -1, true)
		draw_circle(p + Vector2(-u * 0.01, -u * 0.012), u * 0.014, Color(1, 0.92, 0.7, 0.9), true, -1, true)


## Carved grooves from the centre to `reach` (cell units) along each opening,
## filled with water as the tile gets wet. `angle` is the visual rotation.
func _draw_channels(reach: float, angle: float) -> void:
	var u := unit
	var mask := tile.shape_mask()
	if mask == 0:
		return
	var lip := Color(0, 0, 0, 0.16)
	var len := reach * u
	# rotate the logical mask back by the in-flight animation so arms turn smoothly
	for d in Dir.LIST:
		if mask & d:
			var dir := _dir_vec(d)
			draw_line(Vector2.ZERO, dir * len, lip, (GROOVE + 0.07) * u, true)
	draw_circle(Vector2.ZERO, (GROOVE + 0.07) * 0.5 * u, lip, true, -1, true)
	for d in Dir.LIST:
		if mask & d:
			draw_line(Vector2.ZERO, _dir_vec(d) * len, GROOVE_FLOOR, GROOVE * u, true)
	draw_circle(Vector2.ZERO, GROOVE * 0.5 * u, GROOVE_FLOOR, true, -1, true)
	for d in Dir.LIST:
		if mask & d:
			draw_line(_dir_vec(d) * u * 0.06, _dir_vec(d) * len, GROOVE_DEEP, GROOVE * 0.35 * u, true)
	if not wet:
		return
	# water: per-arm fill from the entry side, hub, flowing glints
	var hub_full := water >= 0.5 or tile.is_source()
	for d in Dir.LIST:
		if not (mask & d):
			continue
		var f := _arm_fill(d)
		if f <= 0.01:
			continue
		var dir := _dir_vec(d)
		var a: Vector2
		var b: Vector2
		if (entry_mask & d) and not tile.is_source():
			a = dir * len
			b = dir * len * (1.0 - f)
		else:
			a = Vector2.ZERO
			b = dir * len * f
		draw_line(a, b, WATER_DEEP_COL, WATER * u, true)
		draw_line(a, b, WATER_COL, WATER * u * 0.72, true)
		draw_line(a + Vector2(-dir.y, dir.x) * u * 0.02, b + Vector2(-dir.y, dir.x) * u * 0.02, Color(WATER_SHINE, 0.55), WATER * u * 0.18, true)
		if f >= 0.99 and not Game.reduced_motion():
			# glints travel away from where the water came in
			var outward := not (entry_mask & d) or tile.is_source()
			for k in 2:
				var ph := fmod(_t * 0.9 + k * 0.5 + float(_seed % 7) * 0.13, 1.0)
				var s := ph if outward else 1.0 - ph
				var p := dir * len * s
				draw_circle(p, u * 0.03 * (1.0 - absf(ph - 0.5)), Color(1, 1, 1, 0.75 * sin(ph * PI)), true, -1, true)
	if hub_full:
		draw_circle(Vector2.ZERO, WATER * 0.5 * u, WATER_DEEP_COL, true, -1, true)
		draw_circle(Vector2.ZERO, WATER * 0.36 * u, WATER_COL, true, -1, true)


func _draw_spring() -> void:
	var u := unit
	for i in 9:
		var a := TAU * i / 9.0
		var p := Vector2(cos(a), sin(a)) * u * 0.25
		draw_circle(p + Vector2(0, u * 0.012), u * 0.055, Color(0.55, 0.57, 0.6), true, -1, true)
		draw_circle(p, u * 0.052, Color(0.86, 0.87, 0.88), true, -1, true)
	draw_circle(Vector2.ZERO, u * 0.2, WATER_DEEP_COL, true, -1, true)
	draw_circle(Vector2.ZERO, u * 0.17, WATER_COL, true, -1, true)
	var t := 0.0 if Game.reduced_motion() else _t
	for k in 3:
		var ph := fmod(t * 0.6 + k / 3.0, 1.0)
		draw_arc(Vector2.ZERO, u * (0.05 + 0.13 * ph), 0, TAU, 28, Color(1, 1, 1, 0.5 * (1.0 - ph)), u * 0.015, true)
	for i in 3:
		draw_circle(Vector2.ZERO, u * (0.11 - i * 0.025), Color(0.75, 0.97, 1.0, 0.25 + i * 0.25), true, -1, true)


func _draw_moss() -> void:
	if Painter.hash01(_seed) > 0.4:
		return
	var u := unit
	for i in 3:
		var p := Vector2(Painter.hash01(_seed + i * 7) - 0.5, Painter.hash01(_seed * 3 + i) - 0.5) * u * 0.55
		draw_circle(p, u * (0.03 + 0.02 * Painter.hash01(_seed + i)), Color(0.45, 0.68, 0.42, 0.35), true, -1, true)


func _draw_rock() -> void:
	var u := unit
	var pts := PackedVector2Array()
	var n := 11
	for i in n:
		var a := TAU * i / n
		var r := u * 0.34 * (0.85 + 0.25 * Painter.hash01(_seed * 5 + i))
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.86))
	var shadow := PackedVector2Array()
	for p in pts:
		shadow.append(p + Vector2(0, u * 0.07))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.22))
	var side := PackedVector2Array()
	for p in pts:
		side.append(p + Vector2(0, u * 0.04))
	draw_colored_polygon(side, Color("767b84"))
	draw_colored_polygon(pts, Color("a3a8b0"))
	var top := PackedVector2Array()
	for p in pts:
		top.append(p * 0.72 + Vector2(-u * 0.03, -u * 0.05))
	draw_colored_polygon(top, Color("bdc2c9"))
	draw_circle(Vector2(u * 0.08, -u * 0.1), u * 0.09, Color(0.47, 0.68, 0.38, 0.95), true, -1, true)
	draw_circle(Vector2(u * 0.13, -u * 0.06), u * 0.06, Color(0.55, 0.76, 0.43, 0.95), true, -1, true)


func _draw_target() -> void:
	var u := unit
	draw_circle(Vector2(0, u * 0.04), u * 0.33, Color(0, 0, 0, 0.16), true, -1, true)
	draw_circle(Vector2.ZERO, u * 0.33, SOIL_DARK, true, -1, true)
	draw_circle(Vector2(0, -u * 0.015), u * 0.3, SOIL, true, -1, true)
	if wet and water > 0.3:
		draw_arc(Vector2.ZERO, u * 0.27, 0, TAU, 40, Color(WATER_COL, 0.85), u * 0.05, true)
	_draw_sapling(Vector2(0, u * 0.08), u, bloom)


func _draw_sapling(base: Vector2, u: float, b: float) -> void:
	var trunk_h := u * (0.26 + 0.08 * b)
	var top := base + Vector2(0, -trunk_h)
	draw_line(base, top, BARK, u * (0.045 + 0.02 * b), true)
	if b < 0.6:
		# a thirsty sapling: bare twigs with a few curled, dry leaves
		var a := 1.0 - b / 0.6
		var tips := [top + Vector2(-u * 0.12, -u * 0.06), top + Vector2(u * 0.12, -u * 0.03), top + Vector2(0, -u * 0.12)]
		for k in 3:
			draw_line(top + Vector2(0, u * 0.06 * float(k != 2)), tips[k], Color(BARK, a), u * 0.024, true)
			draw_circle(tips[k], u * 0.035, Color(0.8, 0.64, 0.38, a), true, -1, true)
			draw_circle(tips[k] + Vector2(-u * 0.008, -u * 0.01), u * 0.018, Color(0.9, 0.78, 0.52, a), true, -1, true)
	if b > 0.02:
		var s := u * (0.1 + 0.16 * b)
		var c := top + Vector2(0, -s * 0.35)
		draw_circle(c + Vector2(0, s * 0.18), s * 1.02, Color(0, 0, 0, 0.12), true, -1, true)
		draw_circle(c + Vector2(-s * 0.45, s * 0.1), s * 0.62, Color("3f8f4a"), true, -1, true)
		draw_circle(c + Vector2(s * 0.45, s * 0.12), s * 0.6, Color("3f8f4a"), true, -1, true)
		draw_circle(c, s * 0.75, Color("5fb355"), true, -1, true)
		draw_circle(c + Vector2(-s * 0.2, -s * 0.25), s * 0.4, Color("86cf6a"), true, -1, true)
		if b > 0.7:
			for i in 5:
				var a := TAU * i / 5.0 + 0.4
				draw_circle(c + Vector2(cos(a), sin(a)) * s * 0.55, s * 0.11, Color("ffd2dc"), true, -1, true)


func _draw_bonus() -> void:
	var u := unit
	draw_circle(Vector2(0, u * 0.03), u * 0.3, Color(0, 0, 0, 0.14), true, -1, true)
	draw_circle(Vector2.ZERO, u * 0.3, SOIL_DARK, true, -1, true)
	draw_circle(Vector2(0, -u * 0.012), u * 0.27, SOIL, true, -1, true)
	for i in 10:
		var a := TAU * i / 10.0
		draw_circle(Vector2(cos(a), sin(a)) * u * 0.4, u * 0.022, Color(1.0, 0.82, 0.35, 0.9), true, -1, true)
	var cols := [Color("f58ea1"), Color("ffffff"), Color("b89be8"), Color("ffd15a")]
	var g := 0.3 + 0.7 * bloom
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var p := Vector2(cos(a), sin(a)) * u * (0.15 if i % 2 == 0 else 0.08)
		draw_line(p + Vector2(0, u * 0.06), p, Color("4f8f3e"), u * 0.018, true)
		if bloom > 0.2:
			Painter.flower(self, p, u * 0.07 * g, cols[i % 4], bloom)
		else:
			draw_circle(p, u * 0.025, Color("6faa55"), true, -1, true)


func link_index() -> int:
	if tile.link == "":
		return 0
	return (tile.link.unicode_at(0) - 97) % Palette.LINK_COLORS.size()


## Link tag: colour AND shape (circle, triangle, square, diamond).
func _badge(c: Vector2, r: float) -> void:
	var col: Color = Palette.LINK_COLORS[link_index()]
	var pts := PackedVector2Array()
	match link_index():
		0:
			draw_circle(c, r * 1.12, Color.WHITE, true, -1, true)
			draw_circle(c, r * 0.85, col, true, -1, true)
			return
		1:
			for i in 3:
				var a := -PI * 0.5 + TAU * i / 3.0
				pts.append(c + Vector2(cos(a), sin(a)) * r * 1.15)
		2:
			for v in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				pts.append(c + v * r * 0.82)
		_:
			for v in [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]:
				pts.append(c + v * r * 1.1)
	var outline := PackedVector2Array()
	for p in pts:
		outline.append(c + (p - c) * 1.3)
	draw_colored_polygon(outline, Color.WHITE)
	draw_colored_polygon(pts, col)


func _draw_gate() -> void:
	var u := unit
	var axis := _dir_vec(Dir.rotate_mask(Dir.N, tile.rotation))
	var across := Vector2(-axis.y, axis.x)
	var ang := across.angle()
	# a wooden sluice board across the groove; it slides aside when open
	var slide := across * u * 0.27 * _gate_open
	var alpha := 1.0 - 0.5 * _gate_open
	var len := u * 0.5
	var thick := u * 0.17
	draw_set_transform(slide + Vector2(0, -sin(celebrate * PI) * 0.08 * u), ang, Vector2(press, press))
	var body := Rect2(Vector2(-len * 0.5, -thick * 0.5), Vector2(len, thick))
	_round_rect(Rect2(body.position + Vector2(0, u * 0.035), body.size), u * 0.04, Color(0, 0, 0, 0.3 * alpha))
	_round_rect(body, u * 0.04, Color(0.47, 0.31, 0.18, alpha))
	_round_rect(body.grow(-u * 0.018), u * 0.03, Color(0.69, 0.48, 0.28, alpha))
	for k in [-0.28, 0.28]:
		draw_line(Vector2(len * k, -thick * 0.5), Vector2(len * k, thick * 0.5), Color(0.35, 0.36, 0.38, alpha), u * 0.03, true)
	draw_line(Vector2(-len * 0.42, -thick * 0.12), Vector2(len * 0.42, -thick * 0.12), Color(1, 0.9, 0.7, 0.35 * alpha), u * 0.012, true)
	draw_set_transform(Vector2(0, -sin(celebrate * PI) * 0.08 * u), 0.0, Vector2(press, press))
	_badge(slide + across * u * 0.33, u * 0.09)


func _draw_switch() -> void:
	var u := unit
	var w := u * 0.7
	var h := u * 0.36
	var rect := Rect2(Vector2(-w * 0.5, -h * 0.5), Vector2(w, h))
	var col: Color = Palette.LINK_COLORS[link_index()]
	_round_rect(Rect2(rect.position + Vector2(0, u * 0.06), rect.size), h * 0.5, Color(0, 0, 0, 0.22))
	_round_rect(Rect2(rect.position + Vector2(0, u * 0.035), rect.size), h * 0.5, Color("8f897d").lerp(col.darkened(0.35), _switch_on))
	_round_rect(rect, h * 0.5, Color("d9d3c6").lerp(col, _switch_on))
	var kx := lerpf(-w * 0.5 + h * 0.5, w * 0.5 - h * 0.5, _switch_on)
	draw_circle(Vector2(kx, u * 0.025), h * 0.42, Color(0, 0, 0, 0.2), true, -1, true)
	draw_circle(Vector2(kx, 0), h * 0.42, Color.WHITE, true, -1, true)
	_badge(Vector2(kx, 0), h * 0.2)


func _draw_leaks() -> void:
	var u := unit
	var t := 0.0 if Game.reduced_motion() else _t
	for d in Dir.LIST:
		if leak_mask & d and tile.shape_mask() & d:
			var dir := _dir_vec(d)
			for k in 3:
				var ph := fmod(t * 1.4 + k * 0.33, 1.0)
				var p := dir * u * (0.46 + 0.12 * ph) + Vector2(0, u * 0.18 * ph * ph)
				draw_circle(p, u * 0.035 * (1.0 - ph * 0.5), Color(0.55, 0.9, 1.0, 0.9 * (1.0 - ph)), true, -1, true)


# ------------------------------------------------------------------ helpers

func _dir_vec(d: int) -> Vector2:
	var o := Dir.offset(d)
	return Vector2(o.x, o.y)


func _arm_fill(d: int) -> float:
	if not wet:
		return 0.0
	if tile.is_source():
		return clampf(water, 0.0, 1.0)
	if entry_mask & d:
		return clampf(water * 2.0, 0.0, 1.0)
	return clampf(water * 2.0 - 1.0, 0.0, 1.0)


func _round_rect(r: Rect2, radius: float, col: Color) -> void:
	radius = minf(radius, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var corners := [r.position + Vector2(r.size.x - radius, radius), r.position + Vector2(r.size.x - radius, r.size.y - radius),
		r.position + Vector2(radius, r.size.y - radius), r.position + Vector2(radius, radius)]
	for ci in 4:
		var start := -PI * 0.5 + ci * PI * 0.5
		for k in 7:
			var a := start + PI * 0.5 * k / 6.0
			pts.append(corners[ci] + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, col)
