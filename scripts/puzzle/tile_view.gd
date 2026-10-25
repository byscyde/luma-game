class_name TileView
extends Node2D
## Draws one puzzle tile. Purely visual: reads logical state from its
## PuzzleTile/PuzzleBoard and animates towards it.
##
## Visual language (never colour-only):
##  * rotatable tiles sit on a round stone disc with rim notches; the disc turns
##  * pinned / fixed tiles are square slabs with corner rivets
##  * wet channels are filled with moving turquoise water; spills show droplets
##  * targets are dry saplings that grow when water reaches them

var tile: PuzzleTile
var board: PuzzleBoard
var cell := Vector2i.ZERO
var s := 100.0                ## cell size in pixels

var rot_offset := 0.0         ## radians, animates to 0 after a rotation
var press := 1.0              ## scale while pressed
var water := 0.0              ## 0..1 fill progress
var wet := false
var entry_mask := 0           ## directions water arrives from
var leak_mask := 0            ## openings where water spills
var bloom := 0.0              ## target growth 0..1
var gate_open_v := 0.0        ## 0 closed .. 1 open (animated)
var switch_v := 0.0           ## 0 off .. 1 on (animated)
var highlight := false
var celebrate := 0.0
var _time := 0.0
var _seed := 0
var _sb := StyleBoxFlat.new()


func setup(p_tile: PuzzleTile, p_board: PuzzleBoard, p_cell: Vector2i, size_px: float) -> void:
	tile = p_tile
	board = p_board
	cell = p_cell
	s = size_px
	_seed = p_cell.x * 31 + p_cell.y * 17
	if tile.is_gate():
		gate_open_v = 1.0 if board.is_gate_open(tile) else 0.0
	if tile.is_toggle():
		switch_v = 1.0 if bool(board.switches.get(tile.link, false)) else 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var target_gate := 1.0 if tile and tile.is_gate() and board.is_gate_open(tile) else 0.0
	gate_open_v = move_toward(gate_open_v, target_gate, delta * 5.0)
	if tile and tile.is_toggle():
		var target_sw := 1.0 if bool(board.switches.get(tile.link, false)) else 0.0
		switch_v = move_toward(switch_v, target_sw, delta * 6.0)
	queue_redraw()


func link_index() -> int:
	if tile.link == "":
		return 0
	return (tile.link.unicode_at(0) - 97) % Palette.LINK_COLORS.size()


func _draw() -> void:
	if tile == null:
		return
	var half := s * 0.5
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * press)
	var t := tile.type
	var on_grass := t in [TileTypes.EMPTY, TileTypes.TARGET, TileTypes.BONUS, TileTypes.ROCK, TileTypes.SWITCH]
	var slab := Rect2(-half * 0.94, -half * 0.94, s * 0.94, s * 0.94)
	# soft drop shadow for depth
	_round_rect(Rect2(slab.position + Vector2(0, s * 0.045), slab.size), s * 0.16, Color(0.03, 0.08, 0.07, 0.35))
	if on_grass:
		var g := Palette.GRASS.darkened(0.04 + 0.05 * Painter.hash01(_seed))
		_round_rect(slab, s * 0.16, g.darkened(0.18))
		_round_rect(Rect2(slab.position, slab.size - Vector2(0, s * 0.04)), s * 0.16, g)
	else:
		var base := Palette.SAND if tile.is_rotatable() else Palette.STONE
		_round_rect(slab, s * 0.16, base.darkened(0.2))
		_round_rect(Rect2(slab.position, slab.size - Vector2(0, s * 0.04)), s * 0.16, base)
	if highlight:
		var a := 0.55 + 0.45 * sin(_time * 6.0)
		_round_rect_outline(slab.grow(s * 0.02), s * 0.18, Color(Palette.GOLD, a), maxf(3.0, s * 0.05))
	if celebrate > 0.0:
		_round_rect(slab, s * 0.16, Color(Palette.WATER_LIGHT, 0.25 * celebrate))
	match t:
		TileTypes.EMPTY:
			_tufts()
		TileTypes.ROCK:
			_tufts()
			Painter.rock(self, Vector2(0, s * 0.12), s * 0.62, _seed)
		TileTypes.TARGET:
			_draw_target()
		TileTypes.BONUS:
			_draw_bonus()
		TileTypes.SWITCH:
			_draw_switch()
		TileTypes.SOURCE:
			_draw_channels(tile.shape_mask(), 0.0)
			_draw_source()
		_:
			if tile.is_rotatable():
				_draw_disc()
			else:
				_rivets()
			_draw_channels(tile.shape_mask(), rot_offset)
			if tile.is_gate():
				_draw_gate()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------ parts

func _draw_disc() -> void:
	var r := s * 0.44
	draw_circle(Vector2(0, s * 0.02), r, Palette.SAND_SHADE.darkened(0.12), true, -1, true)
	draw_circle(Vector2.ZERO, r, Palette.SAND_SHADE, true, -1, true)
	draw_circle(Vector2.ZERO, r * 0.9, Palette.CREAM.lerp(Palette.SAND, 0.5), true, -1, true)
	# rim notches rotate with the disc: a clear "this turns" affordance
	for i in 4:
		var a := rot_offset + PI * 0.25 + i * PI * 0.5
		var dir := Vector2(sin(a), -cos(a))
		draw_line(dir * r * 0.78, dir * r * 0.96, Palette.STONE_DARK, maxf(2.0, s * 0.03), true)


func _rivets() -> void:
	var k := s * 0.33
	for v in [Vector2(-k, -k), Vector2(k, -k), Vector2(-k, k), Vector2(k, k)]:
		draw_circle(v, s * 0.035, Palette.STONE_DEEP, true, -1, true)
		draw_circle(v + Vector2(-s * 0.008, -s * 0.008), s * 0.018, Palette.STONE.lightened(0.2), true, -1, true)


func _tufts() -> void:
	for i in 4:
		var p := Vector2((Painter.hash01(_seed + i * 7) - 0.5) * s * 0.7, (Painter.hash01(_seed * 3 + i) - 0.5) * s * 0.7)
		var c := Palette.LEAF_DARK.lerp(Palette.GRASS, 0.3)
		draw_line(p, p + Vector2(-s * 0.03, -s * 0.07), c, maxf(1.5, s * 0.02), true)
		draw_line(p, p + Vector2(s * 0.025, -s * 0.08), c, maxf(1.5, s * 0.02), true)


## Water fill of an arm in [0,1], given whether water flows in or out of it.
func _arm_fill(d: int) -> float:
	if not wet:
		return 0.0
	if tile.is_source():
		return clampf(water, 0.0, 1.0)
	if entry_mask & d:
		return clampf(water * 2.0, 0.0, 1.0)
	return clampf(water * 2.0 - 1.0, 0.0, 1.0)


func _draw_channels(mask: int, angle_off: float) -> void:
	var gw := s * 0.3
	var half := s * 0.5
	var xf := Transform2D(angle_off, Vector2.ZERO)
	# groove
	for d in Dir.LIST:
		if mask & d:
			var e := xf * (Vector2(Dir.offset(d)) * half)
			draw_line(Vector2.ZERO, e, Palette.GROOVE_DARK, gw, true)
	draw_circle(Vector2.ZERO, gw * 0.5, Palette.GROOVE_DARK, true, -1, true)
	for d in Dir.LIST:
		if mask & d:
			var e := xf * (Vector2(Dir.offset(d)) * half)
			draw_line(Vector2.ZERO, e, Palette.GROOVE, gw * 0.74, true)
	draw_circle(Vector2.ZERO, gw * 0.37, Palette.GROOVE, true, -1, true)
	if not wet:
		return
	# water: entry arms fill edge->centre, then exits fill centre->edge
	var ww := gw * 0.56
	var centre_wet := water >= 0.5 or tile.is_source()
	for d in Dir.LIST:
		if not (mask & d):
			continue
		var f := _arm_fill(d)
		if f <= 0.0:
			continue
		var edge := xf * (Vector2(Dir.offset(d)) * half)
		var a: Vector2
		var b: Vector2
		if entry_mask & d and not tile.is_source():
			a = edge
			b = edge.lerp(Vector2.ZERO, f)
		else:
			a = Vector2.ZERO
			b = edge * f
		draw_line(a, b, Palette.WATER_DEEP, ww, true)
		draw_line(a, b, Palette.WATER, ww * 0.7, true)
		# flowing highlight dashes
		var dir := (b - a)
		var len := dir.length()
		if len > 1.0 and s > 8.0:
			var n := dir / len
			var dash := s * 0.12
			var off := fmod(_time * s * 0.5, dash * 2.0)
			var p := -off
			while p < len:
				var p0 := maxf(p, 0.0)
				var p1 := minf(p + dash * 0.6, len)
				if p1 > p0:
					draw_line(a + n * p0, a + n * p1, Color(Palette.WATER_LIGHT, 0.75), maxf(1.5, ww * 0.18), true)
				p += dash * 2.0
	if centre_wet:
		draw_circle(Vector2.ZERO, ww * 0.5, Palette.WATER, true, -1, true)
	# spills
	if water >= 0.99 and leak_mask != 0:
		for d in Dir.LIST:
			if leak_mask & d and mask & d:
				var edge := Vector2(Dir.offset(d)) * half * 0.92
				for k in 3:
					var ph := fmod(_time * 1.6 + k * 0.33, 1.0)
					var side := Vector2(-Dir.offset(d).y, Dir.offset(d).x) * ((k - 1) * s * 0.06)
					var p := edge + Vector2(Dir.offset(d)) * ph * s * 0.08 + side
					draw_circle(p, s * 0.028 * (1.0 - ph * 0.6), Color(Palette.WATER_LIGHT, 1.0 - ph), true, -1, true)


func _draw_source() -> void:
	var r := s * 0.28
	draw_circle(Vector2(0, s * 0.02), r * 1.15, Palette.STONE_DEEP, true, -1, true)
	draw_circle(Vector2.ZERO, r * 1.1, Palette.STONE_DARK, true, -1, true)
	draw_circle(Vector2.ZERO, r * 0.92, Palette.WATER_DEEP, true, -1, true)
	draw_circle(Vector2(-r * 0.08, -r * 0.08), r * 0.72, Palette.WATER, true, -1, true)
	for i in 2:
		var ph := fmod(_time * 0.7 + i * 0.5, 1.0)
		draw_arc(Vector2.ZERO, r * (0.25 + 0.6 * ph), 0, TAU, 24, Color(Palette.WATER_LIGHT, 0.8 * (1.0 - ph)), maxf(1.5, s * 0.02), true)
	draw_circle(Vector2(-r * 0.25, -r * 0.3), r * 0.16, Color(1, 1, 1, 0.65), true, -1, true)


func _draw_target() -> void:
	# inlet water from the side(s) it was reached
	if wet:
		for d in Dir.LIST:
			if entry_mask & d:
				var edge := Vector2(Dir.offset(d)) * s * 0.5
				draw_line(edge, edge * 0.3, Palette.WATER_DEEP, s * 0.17, true)
				draw_line(edge, edge * 0.3, Palette.WATER, s * 0.12, true)
	Painter.ellipse(self, Vector2(0, s * 0.18), s * 0.3, s * 0.14, Palette.DRY_DARK.lerp(Color("5c4630"), bloom))
	if bloom > 0.0:
		Painter.ellipse(self, Vector2(0, s * 0.18), s * 0.3 * bloom, s * 0.13 * bloom, Color(Palette.WATER, 0.55))
	Painter.tree(self, Vector2(0, s * 0.2), s * 0.78, 0.15 + bloom * 1.55, "tree", _time, _seed)


func _draw_bonus() -> void:
	if wet:
		for d in Dir.LIST:
			if entry_mask & d:
				var edge := Vector2(Dir.offset(d)) * s * 0.5
				draw_line(edge, edge * 0.35, Palette.WATER, s * 0.12, true)
	Painter.ellipse(self, Vector2(0, s * 0.12), s * 0.34, s * 0.2, Palette.DRY_DARK.lerp(Color("5c4630"), bloom))
	var cols := [Palette.CORAL, Color.WHITE, Palette.LILAC, Palette.GOLD]
	for i in 5:
		var a := TAU * i / 5.0 + 0.3
		var p := Vector2(cos(a) * s * 0.2, s * 0.14 + sin(a) * s * 0.1)
		Painter.flower(self, p, s * 0.09, cols[i % 4], bloom)
	if bloom <= 0.0:
		# dashed ring marks it as an optional goal
		for i in 12:
			var a0 := TAU * i / 12.0
			draw_arc(Vector2(0, s * 0.05), s * 0.36, a0, a0 + TAU / 24.0, 4, Color(Palette.GOLD, 0.8), maxf(2.0, s * 0.025), true)


func _draw_gate() -> void:
	var gw := s * 0.3
	var col: Color = Palette.LINK_COLORS[link_index()]
	var xf := Transform2D(rot_offset + tile.rotation * PI * 0.5, Vector2.ZERO)
	# posts either side of the channel (local frame: channel runs N-S)
	for side in [-1.0, 1.0]:
		var p := xf * Vector2(side * gw * 0.85, 0)
		draw_circle(p, s * 0.07, Palette.BARK_DARK, true, -1, true)
		draw_circle(p, s * 0.05, Palette.BARK, true, -1, true)
	# plank slides sideways out of the channel when open
	var slide := gw * 1.05 * gate_open_v
	var half_len := gw * 0.75
	var a := xf * Vector2(-half_len + slide, 0)
	var b := xf * Vector2(half_len + slide, 0)
	draw_line(a, b, Palette.BARK_DARK, s * 0.15, true)
	draw_line(a, b, Color("a2774a") if gate_open_v < 0.5 else Color("b78b5c"), s * 0.11, true)
	# link badge (shape + colour)
	_link_shape(xf * Vector2(s * 0.33, -s * 0.33), s * 0.075, col)


func _draw_switch() -> void:
	var col: Color = Palette.LINK_COLORS[link_index()]
	Painter.ellipse(self, Vector2(0, s * 0.14), s * 0.32, s * 0.16, Palette.STONE_DEEP)
	Painter.ellipse(self, Vector2(0, s * 0.1), s * 0.3, s * 0.15, Palette.STONE_DARK)
	if switch_v > 0.0:
		draw_circle(Vector2(0, s * 0.06), s * 0.36, Color(col, 0.18 * switch_v), true, -1, true)
	var ang := lerpf(-0.75, 0.75, switch_v)
	var pivot := Vector2(0, s * 0.1)
	var tip := pivot + Vector2(sin(ang), -cos(ang)) * s * 0.34
	draw_line(pivot, tip, Palette.BARK_DARK, s * 0.08, true)
	draw_line(pivot, tip, Palette.BARK, s * 0.05, true)
	draw_circle(tip, s * 0.08, col.darkened(0.2), true, -1, true)
	draw_circle(tip, s * 0.06, col, true, -1, true)
	draw_circle(pivot, s * 0.05, Palette.STONE_DEEP, true, -1, true)
	_link_shape(Vector2(-s * 0.3, -s * 0.3), s * 0.075, col)
	# state text-free marker: filled dot = on, ring = off
	if switch_v > 0.5:
		draw_circle(Vector2(s * 0.3, -s * 0.3), s * 0.06, Palette.LEAF, true, -1, true)
	else:
		draw_arc(Vector2(s * 0.3, -s * 0.3), s * 0.055, 0, TAU, 16, Palette.STONE_DEEP, maxf(2.0, s * 0.02), true)


func _link_shape(c: Vector2, r: float, col: Color) -> void:
	var outline := col.darkened(0.45)
	match link_index():
		0:
			draw_circle(c, r * 1.2, outline, true, -1, true)
			draw_circle(c, r, col, true, -1, true)
		1:
			var tri := PackedVector2Array([c + Vector2(0, -r * 1.3), c + Vector2(r * 1.2, r * 0.9), c + Vector2(-r * 1.2, r * 0.9)])
			draw_colored_polygon(tri, outline)
			var tri2 := PackedVector2Array([c + Vector2(0, -r * 0.95), c + Vector2(r * 0.85, r * 0.65), c + Vector2(-r * 0.85, r * 0.65)])
			draw_colored_polygon(tri2, col)
		2:
			draw_rect(Rect2(c - Vector2.ONE * r * 1.15, Vector2.ONE * r * 2.3), outline)
			draw_rect(Rect2(c - Vector2.ONE * r * 0.85, Vector2.ONE * r * 1.7), col)
		_:
			var dia := PackedVector2Array([c + Vector2(0, -r * 1.4), c + Vector2(r * 1.4, 0), c + Vector2(0, r * 1.4), c + Vector2(-r * 1.4, 0)])
			draw_colored_polygon(dia, outline)
			var dia2 := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
			draw_colored_polygon(dia2, col)


## One reusable StyleBox: draw_style_box records geometry immediately, so the
## box can be reconfigured between calls without allocating every frame.
func _round_rect(r: Rect2, radius: float, col: Color) -> void:
	_sb.draw_center = true
	_sb.bg_color = col
	_sb.set_border_width_all(0)
	_sb.set_corner_radius_all(int(radius))
	_sb.anti_aliasing = true
	draw_style_box(_sb, r)


func _round_rect_outline(r: Rect2, radius: float, col: Color, w: float) -> void:
	_sb.draw_center = false
	_sb.border_color = col
	_sb.set_border_width_all(int(w))
	_sb.set_corner_radius_all(int(radius))
	_sb.anti_aliasing = true
	draw_style_box(_sb, r)
