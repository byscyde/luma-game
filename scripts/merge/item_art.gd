class_name ItemArt
extends RefCounted
## Procedural cartoon icons for every merge item ("chain:level"): bold dark
## outlines, flat fills with a soft highlight, saturated casual palette.
## draw(ci, id, rect) paints the item centred in rect on any CanvasItem.

const OUT := Color("4a2f24")          ## outline ink
const OUT_W := 0.035                  ## outline width (fraction of icon size)


static func draw(ci: CanvasItem, id: String, r: Rect2) -> void:
	var s := minf(r.size.x, r.size.y)
	if s < 6.0:
		return   # not laid out yet: degenerate polygons cannot be triangulated
	var c := r.get_center()
	var chain := MergeDB.chain_of(id)
	var l := MergeDB.level_of(id)
	match chain:
		"coffee":
			_coffee(ci, c, s, l)
		"bakery":
			_bakery(ci, c, s, l)
		"catch":
			_catch(ci, c, s, l)
		"garden":
			_garden(ci, c, s, l)
		"gen_coffee", "gen_bakery", "gen_catch", "gen_garden", "gen_planter":
			_generator(ci, c, s, chain, l)
		"grill":
			_grill(ci, c, s, l)
		"seaweed":
			_seaweed(ci, c, s, l)
		"smoothie":
			_smoothie(ci, c, s, l)
		"pearl":
			_pearl(ci, c, s, l)
		"gen_grill", "gen_seaweed", "gen_smoothie", "gen_pearl":
			_reef_generator(ci, c, s, chain, l)
		"coins":
			_coins(ci, c, s, l)
		"gems":
			_gems(ci, c, s, l)
		"energy":
			_energy(ci, c, s, l)
		"chest":
			_chest(ci, c, s, l)
		"scissors":
			_scissors(ci, c, s)
		_:
			_shape(ci, _circle_pts(c, s * 0.3), Color("cccccc"), s)


# ------------------------------------------------------------------ primitives

static func _circle_pts(c: Vector2, r: float, n := 28, sy := 1.0) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a) * r, sin(a) * r * sy))
	return p


static func _rect_pts(r: Rect2, rad: float) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var p := PackedVector2Array()
	var cs := [r.position + Vector2(r.size.x - rad, rad), r.position + Vector2(r.size.x - rad, r.size.y - rad),
		r.position + Vector2(rad, r.size.y - rad), r.position + Vector2(rad, rad)]
	for k in 4:
		for j in 6:
			var a := -PI * 0.5 + k * PI * 0.5 + PI * 0.5 * j / 5.0
			p.append(cs[k] + Vector2(cos(a), sin(a)) * rad)
	return p


## Filled polygon with a bold outline.
static func _shape(ci: CanvasItem, pts: PackedVector2Array, fill: Color, s: float, outline := OUT) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, outline, maxf(1.5, s * OUT_W), true)


static func _hl(ci: CanvasItem, c: Vector2, r: float, a := 0.45) -> void:
	ci.draw_circle(c, r, Color(1, 1, 1, a), true, -1, true)


static func _line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	ci.draw_line(a, b, col, w, true)


static func _stars(ci: CanvasItem, c: Vector2, s: float, n: int) -> void:
	for i in n:
		var x := c.x + (i - (n - 1) * 0.5) * s * 0.13
		var p := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + TAU * k / 10.0
			var rr := s * (0.06 if k % 2 == 0 else 0.026)
			p.append(Vector2(x, c.y) + Vector2(cos(a), sin(a)) * rr)
		_shape(ci, p, Color("ffd34d"), s * 0.6)


# ------------------------------------------------------------------ coffee

static func _cup(ci: CanvasItem, c: Vector2, s: float, w: float, h: float, body: Color, liquid: Color) -> void:
	# saucer, handle, cup, liquid top
	_shape(ci, _circle_pts(c + Vector2(0, h * 0.5), w * 0.8, 24, 0.22), Color("f2efe9"), s)
	var hc := c + Vector2(w * 0.5, 0)
	ci.draw_arc(hc, h * 0.24, -PI * 0.5, PI * 0.5, 16, OUT, s * 0.07, true)
	ci.draw_arc(hc, h * 0.24, -PI * 0.5, PI * 0.5, 16, body, s * 0.035, true)
	var p := PackedVector2Array([c + Vector2(-w * 0.5, -h * 0.4), c + Vector2(w * 0.5, -h * 0.4),
		c + Vector2(w * 0.38, h * 0.45), c + Vector2(-w * 0.38, h * 0.45)])
	_shape(ci, p, body, s)
	_shape(ci, _circle_pts(c + Vector2(0, -h * 0.4), w * 0.5, 24, 0.24), liquid, s)
	_hl(ci, c + Vector2(-w * 0.28, 0), w * 0.06, 0.6)


static func _coffee(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	var brown := Color("7a4a2b")
	match l:
		1:
			for o in [Vector2(-0.1, 0.05), Vector2(0.11, -0.04)]:
				var bc: Vector2 = c + o * s
				_shape(ci, _circle_pts(bc, s * 0.13, 20, 1.35), Color("8b5a33"), s)
				_line(ci, bc + Vector2(0, -s * 0.15), bc + Vector2(0, s * 0.15), Color("5a361d"), s * 0.03)
				_hl(ci, bc + Vector2(-s * 0.05, -s * 0.07), s * 0.03)
		2:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.32, -s * 0.05), c + Vector2(s * 0.2, -s * 0.05), c + Vector2(s * 0.12, s * 0.22), c + Vector2(-s * 0.26, s * 0.22)]), Color("c9ccd2"), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(s * 0.18, -s * 0.02), Vector2(s * 0.2, s * 0.07)), s * 0.03), Color("9aa0aa"), s)
			for k in 5:
				var bc := c + Vector2(-s * 0.2 + k * s * 0.08, -s * 0.07 - (k % 2) * s * 0.04)
				_shape(ci, _circle_pts(bc, s * 0.05, 14, 1.3), Color("8b5a33"), s * 0.7)
		3:
			var bag := PackedVector2Array([c + Vector2(-s * 0.24, -s * 0.28), c + Vector2(s * 0.24, -s * 0.28), c + Vector2(s * 0.28, s * 0.32), c + Vector2(-s * 0.28, s * 0.32)])
			_shape(ci, bag, Color("c98a4b"), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.15, -s * 0.05), Vector2(s * 0.3, s * 0.2)), s * 0.04), Color("f4e3c4"), s * 0.7)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.05), s * 0.05, 14, 1.3), brown, s * 0.6)
			_line(ci, c + Vector2(-s * 0.24, -s * 0.2), c + Vector2(s * 0.24, -s * 0.2), Color("8a5a2f"), s * 0.03)
		4:
			_cup(ci, c + Vector2(0, s * 0.05), s, s * 0.36, s * 0.32, Color("ffffff"), Color("4e2b16"))
		5:
			_cup(ci, c + Vector2(0, s * 0.04), s, s * 0.46, s * 0.4, Color("e9f1f5"), Color("e9cfa8"))
			_heart(ci, c + Vector2(0, -s * 0.12), s * 0.07, Color("b07a4a"))
		6, 7:
			var g := PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.36), c + Vector2(s * 0.18, -s * 0.36), c + Vector2(s * 0.14, s * 0.36), c + Vector2(-s * 0.14, s * 0.36)])
			ci.draw_colored_polygon(g, Color(0.85, 0.95, 1.0, 0.5))
			var lq := PackedVector2Array([c + Vector2(-s * 0.165, -s * 0.2), c + Vector2(s * 0.165, -s * 0.2), c + Vector2(s * 0.14, s * 0.34), c + Vector2(-s * 0.14, s * 0.34)])
			ci.draw_colored_polygon(lq, Color("b07848"))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.165, -s * 0.2), c + Vector2(s * 0.165, -s * 0.2), c + Vector2(s * 0.157, -s * 0.02), c + Vector2(-s * 0.157, -s * 0.02)]), Color("f1dfc2"))
			if l == 7:
				for k in 3:
					_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.12 + k * s * 0.08, -s * 0.12 + (k % 2) * s * 0.1), Vector2(s * 0.08, s * 0.08)), s * 0.015), Color(0.9, 0.97, 1, 0.9), s * 0.5)
				_line(ci, c + Vector2(s * 0.05, -s * 0.2), c + Vector2(s * 0.16, -s * 0.46), Color("e2554f"), s * 0.05)
			var gl := g.duplicate()
			gl.append(g[0])
			ci.draw_polyline(gl, OUT, maxf(1.5, s * OUT_W), true)
			_hl(ci, c + Vector2(-s * 0.1, -s * 0.05), s * 0.03, 0.7)
		8:
			_cup(ci, c + Vector2(0, s * 0.08), s, s * 0.46, s * 0.4, Color("d65a4a"), Color("5a2e16"))
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.16), s * 0.2, 20, 0.7), Color("fff7ec"), s)
			_line(ci, c + Vector2(-s * 0.12, -s * 0.18), c + Vector2(s * 0.12, -s * 0.14), Color("6b3a1f"), s * 0.03)
		9:
			_cake_slice(ci, c, s, Color("8a5432"), Color("f6e6cc"), Color("ffffff"))
		10:
			_layer_cake(ci, c, s, [Color("7a4a2b"), Color("f3dcc0"), Color("7a4a2b")], Color("fff6ea"))
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.05, -s * 0.44), Vector2(s * 0.1, s * 0.14)), s * 0.02), Color("ffcf5a"), s * 0.6)


static func _heart(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var p := PackedVector2Array()
	for i in 32:
		var t := TAU * i / 32.0
		p.append(c + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * r / 16.0)
	ci.draw_colored_polygon(p, col)


static func _cake_slice(ci: CanvasItem, c: Vector2, s: float, sponge: Color, cream: Color, top: Color) -> void:
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.26), s * 0.36, 24, 0.25), Color("f2efe9"), s)
	var p := PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.02), c + Vector2(s * 0.26, -s * 0.2), c + Vector2(s * 0.26, s * 0.2), c + Vector2(-s * 0.3, s * 0.24)])
	_shape(ci, p, sponge, s)
	_line(ci, c + Vector2(-s * 0.3, s * 0.11), c + Vector2(s * 0.26, s * 0.0), cream, s * 0.05)
	_shape(ci, PackedVector2Array([c + Vector2(-s * 0.32, -s * 0.06), c + Vector2(s * 0.28, -s * 0.26), c + Vector2(s * 0.28, -s * 0.18), c + Vector2(-s * 0.32, 0)]), top, s * 0.8)
	ci.draw_circle(c + Vector2(s * 0.12, -s * 0.28), s * 0.05, Color("d83b4b"), true, -1, true)


static func _layer_cake(ci: CanvasItem, c: Vector2, s: float, layers: Array, frosting: Color) -> void:
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.3), s * 0.42, 28, 0.22), Color("f2efe9"), s)
	var w := s * 0.34
	var y := c.y + s * 0.28
	for i in layers.size():
		var h := s * 0.14
		var r := Rect2(Vector2(c.x - w + i * s * 0.05, y - h), Vector2((w - i * s * 0.05) * 2.0, h))
		_shape(ci, _rect_pts(r, s * 0.04), layers[i], s)
		_line(ci, Vector2(r.position.x + s * 0.02, r.position.y + s * 0.01), Vector2(r.end.x - s * 0.02, r.position.y + s * 0.01), frosting, s * 0.04)
		y -= h
	for k in 5:
		ci.draw_circle(Vector2(c.x - s * 0.18 + k * s * 0.09, y + s * 0.02), s * 0.03, Color("e34b5c"), true, -1, true)


# ------------------------------------------------------------------ bakery

static func _bread(ci: CanvasItem, c: Vector2, w: float, h: float, s: float, col: Color, scores: int) -> void:
	_shape(ci, _circle_pts(c, w, 28, h / w), col, s)
	for k in scores:
		var x := c.x + (k - (scores - 1) * 0.5) * w * 0.5
		_line(ci, Vector2(x - w * 0.12, c.y - h * 0.4), Vector2(x + w * 0.12, c.y + h * 0.1), col.darkened(0.3), s * 0.025)
	_hl(ci, c + Vector2(-w * 0.4, -h * 0.4), s * 0.04)


static func _bakery(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	var crust := Color("d9963e")
	match l:
		1:
			var bag := PackedVector2Array([c + Vector2(-s * 0.24, -s * 0.24), c + Vector2(s * 0.24, -s * 0.24), c + Vector2(s * 0.3, s * 0.32), c + Vector2(-s * 0.3, s * 0.32)])
			_shape(ci, bag, Color("f4ead6"), s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.26), s * 0.22, 20, 0.35), Color("ffffff"), s * 0.8)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.06), s * 0.08, 16), Color("e0b65a"), s * 0.6)
		2:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.05), s * 0.3, 28, 0.62), Color("f6e3c0"), s)
			_hl(ci, c + Vector2(-s * 0.1, -s * 0.05), s * 0.05)
		3:
			_bread(ci, c + Vector2(0, s * 0.04), s * 0.26, s * 0.2, s, crust, 1)
		4:
			var p := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				p.append(c + Vector2(cos(a) * s * 0.34, sin(a) * s * 0.26 + s * 0.12))
			for i in 13:
				var a := TAU - PI * i / 12.0
				p.append(c + Vector2(cos(a) * s * 0.18, sin(a) * s * 0.1 + s * 0.12))
			_shape(ci, p, Color("e7a64a"), s)
			for k in 4:
				var a := PI + PI * (k + 0.8) / 5.0
				_line(ci, c + Vector2(cos(a) * s * 0.2, sin(a) * s * 0.12 + s * 0.12), c + Vector2(cos(a) * s * 0.32, sin(a) * s * 0.24 + s * 0.12), Color("b8742c"), s * 0.025)
		5:
			_bread(ci, c, s * 0.42, s * 0.12, s, crust, 4)
		6, 7:
			var n := 1 if l == 6 else 2
			for k in n:
				var o := Vector2(k * s * 0.08, -k * s * 0.08)
				var tri := PackedVector2Array([c + o + Vector2(-s * 0.3, s * 0.22), c + o + Vector2(s * 0.3, s * 0.22), c + o + Vector2(-s * 0.3, -s * 0.24)])
				_shape(ci, tri, Color("f4e2bf"), s)
				_line(ci, c + o + Vector2(-s * 0.3, s * 0.12), c + o + Vector2(s * 0.12, s * 0.12), Color("6fbf4a"), s * 0.045)
				_line(ci, c + o + Vector2(-s * 0.3, s * 0.04), c + o + Vector2(s * 0.0, s * 0.04), Color("e2554f"), s * 0.04)
			if l == 7:
				_line(ci, c + Vector2(0, -s * 0.38), c + Vector2(0, s * 0.0), Color("c9a46a"), s * 0.03)
		8:
			_shape(ci, _circle_pts(c, s * 0.34, 28, 0.42), Color("e7b25c"), s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.03), s * 0.28, 28, 0.3), Color("fff2d6"), s * 0.7)
			for k in 6:
				var a := TAU * k / 6.0
				ci.draw_circle(c + Vector2(cos(a) * s * 0.17, sin(a) * s * 0.06 - s * 0.03), s * 0.04, [Color("e2384d"), Color("6e3fae"), Color("f7b733")][k % 3], true, -1, true)
		9, 10:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.06), s * 0.38, 28, 0.45), Color("c97d3a"), s)
			_shape(ci, _circle_pts(c, s * 0.32, 28, 0.38), Color("8e2a52") if l == 9 else Color("d94f3d"), s * 0.8)
			for k in 4:
				_line(ci, c + Vector2(-s * 0.26 + k * s * 0.17, -s * 0.1), c + Vector2(-s * 0.2 + k * s * 0.17, s * 0.1), Color("e7b25c"), s * 0.04)
			if l == 10:
				_stars(ci, c + Vector2(0, -s * 0.28), s, 3)


# ------------------------------------------------------------------ catch

static func _fish(ci: CanvasItem, c: Vector2, s: float, body: Color, len: float) -> void:
	var tail := PackedVector2Array([c + Vector2(len * 0.45, 0), c + Vector2(len * 0.75, -len * 0.25), c + Vector2(len * 0.75, len * 0.25)])
	_shape(ci, tail, body.darkened(0.15), s)
	_shape(ci, _circle_pts(c, len * 0.52, 24, 0.5), body, s)
	ci.draw_circle(c + Vector2(-len * 0.28, -len * 0.05), len * 0.06, OUT, true, -1, true)
	_hl(ci, c + Vector2(-len * 0.1, -len * 0.14), len * 0.07)


static func _catch(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			var p := PackedVector2Array([c + Vector2(0, s * 0.24)])
			for i in 9:
				var a := PI + PI * i / 8.0
				p.append(c + Vector2(cos(a) * s * 0.3, sin(a) * s * 0.3 + s * 0.05))
			_shape(ci, p, Color("f6b9a8"), s)
			for k in 5:
				var a := PI + PI * (k + 1) / 6.0
				_line(ci, c + Vector2(0, s * 0.22), c + Vector2(cos(a) * s * 0.26, sin(a) * s * 0.26 + s * 0.05), Color("d98a77"), s * 0.025)
		2:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.06), s * 0.3, 24, 0.55), Color("b9a58f"), s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.04), s * 0.28, 24, 0.35), Color("dccab4"), s)
			ci.draw_circle(c + Vector2(0, s * 0.02), s * 0.06, Color("fffaf0"), true, -1, true)
		3:
			_fish(ci, c, s, Color("8fc3e8"), s * 0.5)
		4:
			_fish(ci, c, s, Color("4f8fd1"), s * 0.66)
		5:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.12), s * 0.42, 28, 0.32), Color("f2efe9"), s)
			_fish(ci, c, s, Color("d9934d"), s * 0.62)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.15 + k * s * 0.1, -s * 0.12), c + Vector2(-s * 0.2 + k * s * 0.1, s * 0.1), Color("6b3a1f"), s * 0.03)
		6:
			var cone := PackedVector2Array([c + Vector2(-s * 0.28, -s * 0.1), c + Vector2(s * 0.28, -s * 0.1), c + Vector2(0, s * 0.4)])
			for k in 5:
				_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.22 + k * s * 0.09, -s * 0.36 + (k % 2) * s * 0.06), Vector2(s * 0.06, s * 0.3)), s * 0.02), Color("f6cd5a"), s * 0.6)
			_shape(ci, cone, Color("e8f0f6"), s)
			_line(ci, c + Vector2(-s * 0.2, -s * 0.02), c + Vector2(s * 0.2, -s * 0.02), Color("3e7cc4"), s * 0.04)
		7:
			for k in 2:
				var o := c + Vector2((k - 0.5) * s * 0.32, 0)
				var p := PackedVector2Array()
				for i in 13:
					var a := PI * i / 12.0 + PI
					p.append(o + Vector2(cos(a) * s * 0.18, -sin(a) * s * 0.26 - s * 0.05))
				_shape(ci, p, Color("f2c86b"), s)
				ci.draw_circle(o + Vector2(0, s * 0.1), s * 0.07, Color("6fbf4a"), true, -1, true)
				ci.draw_circle(o + Vector2(s * 0.04, s * 0.05), s * 0.04, Color("e2554f"), true, -1, true)
		8:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.08), s * 0.36, 28, 0.55), Color("f4f1ea"), s)
			_shape(ci, _circle_pts(c, s * 0.3, 28, 0.38), Color("e8994a"), s * 0.8)
			for k in 4:
				ci.draw_circle(c + Vector2(-s * 0.15 + k * s * 0.1, (k % 2) * s * 0.05 - s * 0.02), s * 0.04, Color("fff0d8"), true, -1, true)
		9:
			_lobster(ci, c, s)
		10:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.1), s * 0.44, 28, 0.42), Color("c9d7e0"), s)
			_lobster(ci, c + Vector2(s * 0.05, -s * 0.04), s * 0.75)
			_fish(ci, c + Vector2(-s * 0.18, s * 0.12), s, Color("4f8fd1"), s * 0.32)
			ci.draw_circle(c + Vector2(s * 0.24, s * 0.16), s * 0.06, Color("f6e27a"), true, -1, true)


static func _lobster(ci: CanvasItem, c: Vector2, s: float) -> void:
	var red := Color("e0443a")
	for sd in [-1.0, 1.0]:
		_shape(ci, _circle_pts(c + Vector2(sd * s * 0.26, -s * 0.2), s * 0.1, 16, 1.3), red, s)
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.05), s * 0.16, 20, 1.6), red, s)
	for k in 3:
		_line(ci, c + Vector2(-s * 0.12, s * (0.08 + k * 0.08)), c + Vector2(s * 0.12, s * (0.08 + k * 0.08)), red.darkened(0.35), s * 0.025)
	for sd in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sd * s * 0.05, -s * 0.15), s * 0.025, OUT, true, -1, true)


# ------------------------------------------------------------------ garden

static func _pot(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var p := PackedVector2Array([c + Vector2(-s * 0.2, 0), c + Vector2(s * 0.2, 0), c + Vector2(s * 0.15, s * 0.3), c + Vector2(-s * 0.15, s * 0.3)])
	_shape(ci, p, col, s)
	_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.23, -s * 0.05), Vector2(s * 0.46, s * 0.08)), s * 0.02), col.lightened(0.1), s)


static func _leaf(ci: CanvasItem, base: Vector2, dir: Vector2, len: float, col: Color, s: float) -> void:
	var n := Vector2(-dir.y, dir.x)
	var tip := base + dir * len
	var p := PackedVector2Array([base, base + dir * len * 0.5 + n * len * 0.28, tip, base + dir * len * 0.5 - n * len * 0.28])
	_shape(ci, p, col, s * 0.8)


static func _flower(ci: CanvasItem, c: Vector2, r: float, petal: Color, center: Color, s: float) -> void:
	for k in 6:
		var a := TAU * k / 6.0
		_shape(ci, _circle_pts(c + Vector2(cos(a), sin(a)) * r * 0.7, r * 0.45, 14), petal, s * 0.6)
	_shape(ci, _circle_pts(c, r * 0.4, 14), center, s * 0.6)


static func _garden(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	var green := Color("5fb648")
	match l:
		1:
			for o in [Vector2(-0.08, 0.04), Vector2(0.08, -0.03), Vector2(0.0, 0.1)]:
				_shape(ci, _circle_pts(c + o * s, s * 0.07, 14, 1.4), Color("c9a265"), s * 0.7)
		2:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.2), s * 0.26, 20, 0.35), Color("8a5a3a"), s)
			_line(ci, c + Vector2(0, s * 0.18), c + Vector2(0, -s * 0.06), Color("4f9a3a"), s * 0.04)
			_leaf(ci, c + Vector2(0, -s * 0.04), Vector2(-0.8, -0.6), s * 0.2, green, s)
			_leaf(ci, c + Vector2(0, -s * 0.04), Vector2(0.8, -0.6), s * 0.2, green, s)
		3, 4:
			if l == 3:
				_pot(ci, c + Vector2(0, s * 0.02), s, Color("d0703f"))
			for k in (5 if l == 3 else 7):
				var a := -PI * 0.5 + (k - 3) * 0.32
				_leaf(ci, c + Vector2(0, s * (0.02 if l == 3 else 0.22)), Vector2(cos(a), sin(a)), s * (0.28 if l == 3 else 0.36), Color("6cc24a") if k % 2 == 0 else Color("4f9a3a"), s)
		5:
			_cup(ci, c + Vector2(0, s * 0.06), s, s * 0.44, s * 0.36, Color("ffffff"), Color("b9cf6a"))
			_leaf(ci, c + Vector2(s * 0.05, -s * 0.14), Vector2(0.3, -1), s * 0.18, green, s)
		6:
			_pot(ci, c + Vector2(0, s * 0.04), s, Color("4c8fc9"))
			_line(ci, c + Vector2(0, s * 0.02), c + Vector2(0, -s * 0.2), Color("4f9a3a"), s * 0.035)
			_flower(ci, c + Vector2(0, -s * 0.22), s * 0.12, Color("f48fb1"), Color("ffd34d"), s)
		7:
			_line(ci, c + Vector2(0, s * 0.4), c + Vector2(0, -s * 0.05), Color("4f9a3a"), s * 0.05)
			_leaf(ci, c + Vector2(0, s * 0.18), Vector2(-1, -0.3), s * 0.18, green, s)
			for k in 12:
				var a := TAU * k / 12.0
				_shape(ci, _circle_pts(c + Vector2(0, -s * 0.12) + Vector2(cos(a), sin(a)) * s * 0.16, s * 0.07, 10, 1.0), Color("ffc928"), s * 0.5)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.12), s * 0.12, 18), Color("7a4a2b"), s * 0.6)
		8:
			_line(ci, c + Vector2(0, s * 0.4), c + Vector2(0, -s * 0.02), Color("3f8a3a"), s * 0.045)
			_leaf(ci, c + Vector2(0, s * 0.15), Vector2(1, -0.4), s * 0.18, green, s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.14), s * 0.19, 20), Color("e0304a"), s)
			ci.draw_arc(c + Vector2(0, -s * 0.14), s * 0.1, 0.5, 5.5, 16, Color("a01c32"), s * 0.03, true)
			ci.draw_arc(c + Vector2(0, -s * 0.14), s * 0.04, 0.5, 5.5, 12, Color("a01c32"), s * 0.025, true)
		9, 10:
			if l == 9:
				_shape(ci, PackedVector2Array([c + Vector2(-s * 0.34, 0), c + Vector2(s * 0.34, 0), c + Vector2(s * 0.26, s * 0.34), c + Vector2(-s * 0.26, s * 0.34)]), Color("c98f4f"), s)
				ci.draw_arc(c + Vector2(0, 0), s * 0.3, PI, TAU, 20, Color("a46d36"), s * 0.05, true)
			else:
				_shape(ci, PackedVector2Array([c + Vector2(-s * 0.08, s * 0.05), c + Vector2(s * 0.08, s * 0.05), c + Vector2(s * 0.04, s * 0.44), c + Vector2(-s * 0.04, s * 0.44)]), Color("f4f1ea"), s)
				_shape(ci, _circle_pts(c + Vector2(0, s * 0.12), s * 0.08, 12), Color("f7b6c8"), s * 0.6)
			var cols := [Color("f48fb1"), Color("ffffff"), Color("ffd34d"), Color("e0304a"), Color("b89be8")]
			for k in (5 if l == 9 else 7):
				var a := PI + PI * (k + 0.5) / (5.0 if l == 9 else 7.0)
				_flower(ci, c + Vector2(cos(a) * s * 0.24, sin(a) * s * 0.22 - (0.0 if l == 9 else s * 0.08)), s * 0.09, cols[k % cols.size()], Color("ffe48a"), s)


# ------------------------------------------------------------------ generators

static func _generator(ci: CanvasItem, c: Vector2, s: float, chain: String, l: int) -> void:
	# a sturdy machine/box body in the chain's colour, with a level band of stars
	var body: Color = {"gen_coffee": Color("c0473e"), "gen_bakery": Color("e4c58f"), "gen_catch": Color("3f7fbf"),
		"gen_garden": Color("6aa84f"), "gen_planter": Color("a8743f")}[chain]
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.36), s * 0.36, 24, 0.18), Color(0, 0, 0, 0.18), s, Color(0, 0, 0, 0))
	match chain:
		"gen_coffee":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.28, -s * 0.18), Vector2(s * 0.56, s * 0.54)), s * 0.07), body, s)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.18), c + Vector2(s * 0.2, -s * 0.18), c + Vector2(s * 0.28, -s * 0.42), c + Vector2(-s * 0.28, -s * 0.42)]), Color("b9bec6"), s)
			for k in 3:
				ci.draw_circle(c + Vector2(-s * 0.12 + k * s * 0.12, -s * 0.34), s * 0.04, Color("8b5a33"), true, -1, true)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.12, s * 0.06), Vector2(s * 0.24, s * 0.16)), s * 0.03), Color("3a2a22"), s * 0.7)
		"gen_bakery":
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.24), c + Vector2(s * 0.3, -s * 0.24), c + Vector2(s * 0.34, s * 0.36), c + Vector2(-s * 0.34, s * 0.36)]), body, s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.28), s * 0.26, 20, 0.35), Color("fffaf0"), s)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.08), s * 0.12, 18), Color("d9963e"), s * 0.7)
		"gen_catch":
			_shape(ci, _circle_pts(c, s * 0.36, 28), Color("e8d9b8"), s)
			for k in 5:
				_line(ci, c + Vector2(-s * 0.32 + k * s * 0.16, -s * 0.28), c + Vector2(-s * 0.32 + k * s * 0.16, s * 0.28), Color("a88b5c"), s * 0.02)
				_line(ci, c + Vector2(-s * 0.3, -s * 0.28 + k * s * 0.14), c + Vector2(s * 0.3, -s * 0.28 + k * s * 0.14), Color("a88b5c"), s * 0.02)
			_fish(ci, c + Vector2(-s * 0.02, s * 0.02), s * 0.8, Color("8fc3e8"), s * 0.32)
			ci.draw_arc(c, s * 0.36, 0, TAU, 32, body, s * 0.06, true)
		"gen_garden":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.26, -s * 0.28), Vector2(s * 0.52, s * 0.62)), s * 0.06), Color("c9ccd2"), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.26, -s * 0.1), Vector2(s * 0.52, s * 0.28)), s * 0.02), body, s * 0.8)
			_flower(ci, c + Vector2(0, s * 0.04), s * 0.08, Color("ffffff"), Color("ffd34d"), s)
		"gen_planter":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.34, s * 0.0), Vector2(s * 0.68, s * 0.32)), s * 0.04), body, s)
			for k in 7:
				var a := -PI * 0.5 + (k - 3) * 0.3
				_leaf(ci, c + Vector2((k - 3) * s * 0.07, s * 0.02), Vector2(cos(a), sin(a)), s * 0.26, Color("6cc24a") if k % 2 == 0 else Color("4f9a3a"), s)
	_stars(ci, c + Vector2(0, s * 0.4), s, l)


# ------------------------------------------------------------------ resources

static func _coins(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	var n: int = [1, 3, 5, 7, 9][clampi(l - 1, 0, 4)]
	for k in n:
		var col: int = k % 3
		var row: int = k / 3
		var p := c + Vector2((col - 1) * s * 0.18 * float(n > 1), s * 0.14 - row * s * 0.12 + (col % 2) * s * 0.04)
		_shape(ci, _circle_pts(p + Vector2(0, s * 0.03), s * 0.15, 22, 0.55), Color("d79a1e"), s * 0.8)
		_shape(ci, _circle_pts(p, s * 0.15, 22, 0.55), Color("ffcf3a"), s * 0.8)
		_shape(ci, _circle_pts(p, s * 0.08, 16, 0.55), Color("ffe48a"), s * 0.5, Color("d79a1e"))
	if l >= 5:
		_stars(ci, c + Vector2(0, -s * 0.34), s, 3)


static func _gem(ci: CanvasItem, c: Vector2, r: float, s: float) -> void:
	var p := PackedVector2Array([c + Vector2(-r, -r * 0.3), c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(r * 0.5, -r * 0.8), c + Vector2(r, -r * 0.3), c + Vector2(0, r)])
	_shape(ci, p, Color("2fd0c8"), s, Color("176c74"))
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.5, -r * 0.8), c + Vector2(0, -r * 0.3), c + Vector2(-r, -r * 0.3)]), Color(1, 1, 1, 0.45))
	_line(ci, c + Vector2(-r, -r * 0.3), c + Vector2(r, -r * 0.3), Color("176c74"), s * 0.02)


static func _gems(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_gem(ci, c, s * 0.24, s)
		2:
			_gem(ci, c + Vector2(-s * 0.13, s * 0.04), s * 0.18, s)
			_gem(ci, c + Vector2(s * 0.13, -s * 0.02), s * 0.2, s)
		3:
			for o in [Vector2(-0.18, 0.08), Vector2(0.18, 0.08), Vector2(0, -0.08)]:
				_gem(ci, c + o * s, s * 0.17, s)
		_:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.3, s * 0.2), c + Vector2(s * 0.3, s * 0.2), c + Vector2(s * 0.34, -s * 0.12), c + Vector2(s * 0.15, s * 0.0), c + Vector2(0, -s * 0.24), c + Vector2(-s * 0.15, 0), c + Vector2(-s * 0.34, -s * 0.12)]), Color("ffcf3a"), s)
			_gem(ci, c + Vector2(0, s * 0.06), s * 0.12, s)


static func _energy(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	var h := s * (0.42 + 0.06 * l)
	var w := s * (0.26 + 0.05 * l)
	var body := Rect2(c + Vector2(-w * 0.5, -h * 0.35), Vector2(w, h * 0.75))
	_shape(ci, _rect_pts(Rect2(c + Vector2(-w * 0.18, -h * 0.5), Vector2(w * 0.36, h * 0.18)), s * 0.03), Color("9aa0aa"), s)
	_shape(ci, _rect_pts(body, w * 0.3), Color("5fd16b"), s)
	_bolt(ci, body.get_center(), h * 0.22, s)
	_hl(ci, body.position + Vector2(w * 0.25, h * 0.15), w * 0.08)


static func _bolt(ci: CanvasItem, c: Vector2, r: float, s: float) -> void:
	var p := PackedVector2Array([c + Vector2(r * 0.15, -r), c + Vector2(-r * 0.55, r * 0.15), c + Vector2(-r * 0.05, r * 0.15),
		c + Vector2(-r * 0.2, r), c + Vector2(r * 0.55, -r * 0.2), c + Vector2(r * 0.05, -r * 0.2)])
	_shape(ci, p, Color("fff36b"), s * 0.7)


static func _chest(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	var wood: Color = [Color("b9763f"), Color("b8c4cf"), Color("f0c440")][clampi(l - 1, 0, 2)]
	var trim: Color = [Color("7a4a24"), Color("6c7a88"), Color("b07d17")][clampi(l - 1, 0, 2)]
	_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.34, -s * 0.06), Vector2(s * 0.68, s * 0.38)), s * 0.04), wood, s)
	_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.34, -s * 0.3), Vector2(s * 0.68, s * 0.26)), s * 0.12), wood.lightened(0.08), s)
	for x in [-0.22, 0.22]:
		_line(ci, c + Vector2(x * s, -s * 0.3), c + Vector2(x * s, s * 0.32), trim, s * 0.05)
	_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.07, -s * 0.1), Vector2(s * 0.14, s * 0.14)), s * 0.03), Color("ffe48a"), s * 0.7)


static func _scissors(ci: CanvasItem, c: Vector2, s: float) -> void:
	_line(ci, c + Vector2(-s * 0.2, s * 0.2), c + Vector2(s * 0.24, -s * 0.3), Color("aeb6bf"), s * 0.08)
	_line(ci, c + Vector2(s * 0.2, s * 0.2), c + Vector2(-s * 0.24, -s * 0.3), Color("cdd3d9"), s * 0.08)
	for sd in [-1.0, 1.0]:
		ci.draw_arc(c + Vector2(sd * s * 0.2, s * 0.26), s * 0.1, 0, TAU, 20, Color("e2554f"), s * 0.06, true)
	ci.draw_circle(c + Vector2(0, -s * 0.02), s * 0.035, OUT, true, -1, true)


# ------------------------------------------------------------------ Reef Grill

static func _plate(ci: CanvasItem, c: Vector2, s: float, r := 0.4, col := Color("f2efe9")) -> void:
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.14), s * r, 28, 0.38), col, s)


static func _skewer(ci: CanvasItem, a: Vector2, b: Vector2, s: float, cols: Array) -> void:
	_line(ci, a, b, Color("a77b4f"), s * 0.03)
	for k in cols.size():
		var p := a.lerp(b, (k + 1.0) / (cols.size() + 1.0))
		_shape(ci, _rect_pts(Rect2(p - Vector2(s * 0.07, s * 0.07), Vector2(s * 0.14, s * 0.14)), s * 0.04), cols[k], s * 0.7)


static func _grill(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	var corn := Color("f5cf3c")
	match l:
		1, 2:
			var p := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				p.append(c + Vector2(cos(a) * s * 0.13, sin(a) * s * 0.32).rotated(0.6))
			_shape(ci, p, corn if l == 1 else Color("e6a93a"), s)
			for k in 4:
				_line(ci, c + Vector2(-s * 0.1, -s * 0.2 + k * s * 0.12).rotated(0.6), c + Vector2(s * 0.1, -s * 0.2 + k * s * 0.12).rotated(0.6), Color(0.6, 0.4, 0.1, 0.5), s * 0.02)
			_leaf(ci, c + Vector2(s * 0.12, s * 0.2), Vector2(0.7, 0.7), s * 0.2, Color("6cc24a"), s)
			if l == 2:
				for k in 3:
					_line(ci, c + Vector2(-s * 0.12 + k * s * 0.1, -s * 0.1), c + Vector2(-s * 0.04 + k * s * 0.1, s * 0.0), Color("6b3a1f"), s * 0.03)
		3, 4:
			var cols := [Color("e2554f"), Color("6cc24a"), Color("f5cf3c"), Color("e2554f")] if l == 3 else [Color("f29a76"), Color("e2554f"), Color("f29a76"), Color("6cc24a")]
			_skewer(ci, c + Vector2(-s * 0.36, s * 0.3), c + Vector2(s * 0.36, -s * 0.3), s, cols)
		5, 6:
			_plate(ci, c, s)
			_skewer(ci, c + Vector2(-s * 0.32, s * 0.14), c + Vector2(s * 0.32, -s * 0.12), s, [Color("b0603a"), Color("6cc24a"), Color("b0603a")])
			if l == 6:
				for k in 3:
					_shape(ci, _circle_pts(c + Vector2(-s * 0.16 + k * s * 0.16, s * 0.18), s * 0.08, 14, 0.7), Color("f29a76"), s * 0.6)
		7, 8:
			_plate(ci, c, s, 0.44)
			_shape(ci, _circle_pts(c + Vector2(-s * 0.1, s * 0.06), s * 0.16, 16, 0.6), Color("8b4a2b"), s)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.2 + k * s * 0.07, s * 0.0), c + Vector2(-s * 0.14 + k * s * 0.07, s * 0.12), Color("4a2414"), s * 0.02)
			_fish(ci, c + Vector2(s * 0.16, s * 0.1), s * 0.8, Color("f29a76"), s * 0.28)
			if l == 8:
				_skewer(ci, c + Vector2(-s * 0.3, -s * 0.14), c + Vector2(s * 0.3, -s * 0.24), s * 0.8, [Color("e2554f"), Color("6cc24a"), Color("f5cf3c")])
		_:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.42, -s * 0.04), Vector2(s * 0.84, s * 0.36)), s * 0.08), Color("8a5a3a"), s)
			for k in 4:
				_line(ci, c + Vector2(-s * 0.36, s * 0.02 + k * s * 0.08), c + Vector2(s * 0.36, s * 0.02 + k * s * 0.08), Color("3a2a22"), s * 0.02)
			_skewer(ci, c + Vector2(-s * 0.36, s * 0.0), c + Vector2(s * 0.36, -s * 0.28), s * 0.9, [Color("b0603a"), Color("e2554f"), Color("6cc24a"), Color("f29a76")])
			for k in 3:
				ci.draw_circle(c + Vector2(-s * 0.2 + k * s * 0.2, -s * 0.36 - (k % 2) * s * 0.04), s * 0.035, Color(1.0, 0.6, 0.2, 0.8), true, -1, true)
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.4), s, 3)


static func _seaweed(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	var green := Color("2f8f5b")
	var nori := Color("25412e")
	match l:
		1, 2:
			for k in (2 if l == 1 else 4):
				var x := c.x + (k - (1.5 if l == 2 else 0.5)) * s * 0.12
				var p := PackedVector2Array()
				for i in 9:
					p.append(Vector2(x + sin(i * 0.9 + k) * s * 0.05, c.y + s * 0.34 - i * s * 0.08))
				ci.draw_polyline(p, OUT, s * 0.11, true)
				ci.draw_polyline(p, green.lightened(0.1 * k), s * 0.07, true)
			if l == 2:
				_line(ci, c + Vector2(-s * 0.22, s * 0.12), c + Vector2(s * 0.22, s * 0.12), Color("c9a265"), s * 0.05)
		3:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.6)), s * 0.04), nori, s)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.26, -s * 0.15 + k * s * 0.15), c + Vector2(s * 0.26, -s * 0.15 + k * s * 0.15), Color(1, 1, 1, 0.12), s * 0.02)
		4:
			_shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.3), c + Vector2(s * 0.3, s * 0.22), c + Vector2(-s * 0.3, s * 0.22)]), Color("fbfaf4"), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.18, s * 0.04), Vector2(s * 0.36, s * 0.2)), s * 0.02), nori, s * 0.7)
		5, 6:
			for k in (3 if l == 5 else 2):
				var p := c + Vector2((k - (1.0 if l == 5 else 0.5)) * s * 0.24, 0)
				if l == 5:
					_shape(ci, _circle_pts(p, s * 0.11, 18), nori, s)
					_shape(ci, _circle_pts(p, s * 0.08, 18), Color("fbfaf4"), s * 0.5)
					ci.draw_circle(p, s * 0.035, Color("f29a76"), true, -1, true)
				else:
					_shape(ci, _circle_pts(p + Vector2(0, s * 0.06), s * 0.14, 18, 0.55), Color("fbfaf4"), s)
					_shape(ci, _circle_pts(p, s * 0.13, 18, 0.45), Color("f28a5c"), s)
					for j in 3:
						_line(ci, p + Vector2(-s * 0.08 + j * s * 0.07, -s * 0.05), p + Vector2(-s * 0.1 + j * s * 0.07, s * 0.05), Color(1, 1, 1, 0.6), s * 0.015)
		7:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.4, -s * 0.18), Vector2(s * 0.8, s * 0.4)), s * 0.06), Color("8a5a3a"), s)
			for k in 4:
				var p := c + Vector2(-s * 0.27 + k * s * 0.18, s * 0.02)
				_shape(ci, _circle_pts(p, s * 0.08, 16), nori if k % 2 == 0 else Color("fbfaf4"), s * 0.6)
				ci.draw_circle(p, s * 0.03, Color("f29a76") if k % 2 == 0 else Color("2f8f5b"), true, -1, true)
		8:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.08), s * 0.38, 28, 0.6), Color("3d6fb0"), s)
			_shape(ci, _circle_pts(c, s * 0.32, 28, 0.42), Color("fbfaf4"), s * 0.7)
			for k in 5:
				var a := TAU * k / 5.0
				ci.draw_circle(c + Vector2(cos(a) * s * 0.16, sin(a) * s * 0.07), s * 0.06, [Color("f28a5c"), Color("2f8f5b"), Color("f5cf3c"), Color("e2554f"), Color("8fc3e8")][k], true, -1, true)
		_:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.4, -s * 0.3), Vector2(s * 0.8, s * 0.62)), s * 0.06), Color("1f1f24"), s)
			_line(ci, c + Vector2(0, -s * 0.28), c + Vector2(0, s * 0.3), Color("c0473e"), s * 0.03)
			_line(ci, c + Vector2(-s * 0.38, 0), c + Vector2(s * 0.38, 0), Color("c0473e"), s * 0.03)
			for o in [Vector2(-0.2, -0.15), Vector2(0.2, -0.15), Vector2(-0.2, 0.15), Vector2(0.2, 0.15)]:
				ci.draw_circle(c + o * s, s * 0.08, [Color("fbfaf4"), Color("f28a5c"), Color("2f8f5b"), Color("f5cf3c")][int(o.x > 0) + 2 * int(o.y > 0)], true, -1, true)
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.4), s, 3)


static func _smoothie(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, _circle_pts(c, s * 0.3, 24), Color("7a4a2b"), s)
			for k in 3:
				ci.draw_circle(c + Vector2(-s * 0.08 + k * s * 0.08, -s * 0.12), s * 0.03, Color("3a2414"), true, -1, true)
			_hl(ci, c + Vector2(-s * 0.12, -s * 0.12), s * 0.05)
		2:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.05), s * 0.32, 24, 0.6), Color("7a4a2b"), s)
			_shape(ci, _circle_pts(c, s * 0.27, 24, 0.45), Color("fbfaf4"), s * 0.8)
		3:
			_shape(ci, _circle_pts(c, s * 0.3, 24, 0.8).duplicate(), Color("f5a524"), s)
			_shape(ci, _circle_pts(c + Vector2(s * 0.08, -s * 0.06), s * 0.16, 18, 0.8), Color("f7c948"), s * 0.4, Color(0, 0, 0, 0))
			_leaf(ci, c + Vector2(0, -s * 0.24), Vector2(0.6, -0.8), s * 0.16, Color("6cc24a"), s)
		4:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.02), c + Vector2(s * 0.3, -s * 0.02), c + Vector2(s * 0.2, s * 0.3), c + Vector2(-s * 0.2, s * 0.3)]), Color("ffffff"), s)
			for k in 5:
				ci.draw_circle(c + Vector2(-s * 0.2 + k * s * 0.1, -s * 0.06 - (k % 2) * s * 0.06), s * 0.07, [Color("f5a524"), Color("e2554f"), Color("6cc24a"), Color("f5cf3c"), Color("b89be8")][k], true, -1, true)
		5, 6, 8:
			var col: Color = {5: Color("f7a531"), 6: Color("f2789a"), 8: Color("e5533c")}[l]
			var g := PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(s * 0.2, -s * 0.3), c + Vector2(s * 0.15, s * 0.36), c + Vector2(-s * 0.15, s * 0.36)])
			ci.draw_colored_polygon(g, Color(0.85, 0.95, 1, 0.5))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.16), c + Vector2(s * 0.18, -s * 0.16), c + Vector2(s * 0.15, s * 0.34), c + Vector2(-s * 0.15, s * 0.34)]), col)
			var gl := g.duplicate()
			gl.append(g[0])
			ci.draw_polyline(gl, OUT, maxf(1.5, s * OUT_W), true)
			_line(ci, c + Vector2(s * 0.06, -s * 0.2), c + Vector2(s * 0.2, -s * 0.46), Color("4fc3dc"), s * 0.05)
			if l >= 6:
				_shape(ci, _circle_pts(c + Vector2(-s * 0.18, -s * 0.28), s * 0.1, 14, 0.5), Color("f5cf3c"), s * 0.6)
			if l == 8:
				_shape(ci, PackedVector2Array([c + Vector2(-s * 0.04, -s * 0.3), c + Vector2(-s * 0.2, -s * 0.48), c + Vector2(s * 0.12, -s * 0.36)]), Color("f2789a"), s * 0.6)
		7:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.1), s * 0.4, 28, 0.55), Color("ffffff"), s)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.02), s * 0.34, 28, 0.38), Color("b44d9c"), s * 0.7)
			for k in 6:
				ci.draw_circle(c + Vector2(-s * 0.22 + k * s * 0.09, (k % 2) * s * 0.05 - s * 0.02), s * 0.05, [Color("f5a524"), Color("f5cf3c"), Color("6cc24a")][k % 3], true, -1, true)
		_:
			for k in 3:
				_shape(ci, _circle_pts(c + Vector2(0, s * 0.26 - k * s * 0.18), s * (0.32 - k * 0.07), 24, 0.42), [Color("f5a524"), Color("e2554f"), Color("6cc24a")][k], s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.34), s * 0.07, 14), Color("f5cf3c"), s * 0.6)
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)


static func _pearl_ball(ci: CanvasItem, c: Vector2, r: float, s: float) -> void:
	_shape(ci, _circle_pts(c, r, 18), Color("f4eee6"), s * 0.6, Color("9a8f86"))
	_hl(ci, c + Vector2(-r * 0.35, -r * 0.35), r * 0.3, 0.9)


static func _pearl(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, _circle_pts(c, s * 0.3, 24), Color("efdcc0"), s)
			for k in 5:
				var a := -PI * 0.5 + TAU * k / 5.0
				_line(ci, c, c + Vector2(cos(a), sin(a)) * s * 0.16, Color("c9a77a"), s * 0.03)
		2:
			_pearl_ball(ci, c, s * 0.2, s)
		3:
			_pearl_ball(ci, c + Vector2(-s * 0.12, s * 0.04), s * 0.16, s)
			_pearl_ball(ci, c + Vector2(s * 0.12, -s * 0.04), s * 0.16, s)
		4:
			ci.draw_arc(c + Vector2(0, s * 0.08), s * 0.22, 0, TAU, 32, OUT, s * 0.09, true)
			ci.draw_arc(c + Vector2(0, s * 0.08), s * 0.22, 0, TAU, 32, Color("ffcf3a"), s * 0.06, true)
			_pearl_ball(ci, c + Vector2(0, -s * 0.16), s * 0.12, s)
		5, 6:
			for k in (8 if l == 5 else 12):
				var a := PI * 0.15 + PI * 0.7 * k / (7.0 if l == 5 else 11.0)
				var p := c + Vector2(cos(a) * s * 0.3, sin(a) * s * 0.26 - s * 0.1)
				if l == 5:
					_shape(ci, _circle_pts(p, s * 0.05, 10), Color("f6b9a8"), s * 0.4)
				else:
					_pearl_ball(ci, p, s * 0.05, s * 0.6)
			if l == 6:
				_pearl_ball(ci, c + Vector2(0, s * 0.2), s * 0.1, s)
		7:
			for k in 5:
				var a := -PI * 0.5 + TAU * k / 5.0
				_shape(ci, _circle_pts(c + Vector2(cos(a), sin(a)) * s * 0.18, s * 0.12, 14), Color("f28a7a"), s * 0.6)
			_pearl_ball(ci, c, s * 0.12, s)
		8:
			_chest(ci, c, s, 3)
			for k in 3:
				_pearl_ball(ci, c + Vector2(-s * 0.16 + k * s * 0.16, -s * 0.34), s * 0.07, s * 0.6)
		_:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.32, s * 0.2), c + Vector2(s * 0.32, s * 0.2), c + Vector2(s * 0.36, -s * 0.14), c + Vector2(s * 0.16, 0), c + Vector2(0, -s * 0.28), c + Vector2(-s * 0.16, 0), c + Vector2(-s * 0.36, -s * 0.14)]), Color("ffcf3a"), s)
			for o in [-0.2, 0.0, 0.2]:
				_pearl_ball(ci, c + Vector2(o * s, s * 0.1), s * 0.06, s * 0.6)
			if l == 10:
				_shape(ci, _circle_pts(c + Vector2(0, -s * 0.12), s * 0.08, 14), Color("e8744f"), s * 0.6)
				_stars(ci, c + Vector2(0, s * 0.4), s, 3)


static func _reef_generator(ci: CanvasItem, c: Vector2, s: float, chain: String, l: int) -> void:
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.36), s * 0.36, 24, 0.18), Color(0, 0, 0, 0.18), s, Color(0, 0, 0, 0))
	match chain:
		"gen_grill":
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.02), s * 0.34, 24, 0.55), Color("3a3a40"), s)
			for k in 4:
				_line(ci, c + Vector2(-s * 0.26, -s * 0.1 + k * s * 0.07), c + Vector2(s * 0.26, -s * 0.1 + k * s * 0.07), Color("8a8a92"), s * 0.025)
			for k in 3:
				ci.draw_circle(c + Vector2(-s * 0.14 + k * s * 0.14, -s * 0.2), s * 0.05, Color(1.0, 0.55, 0.15, 0.9), true, -1, true)
			_line(ci, c + Vector2(-s * 0.2, s * 0.18), c + Vector2(-s * 0.26, s * 0.34), OUT, s * 0.05)
			_line(ci, c + Vector2(s * 0.2, s * 0.18), c + Vector2(s * 0.26, s * 0.34), OUT, s * 0.05)
		"gen_seaweed":
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.32, -s * 0.06), c + Vector2(s * 0.32, -s * 0.06), c + Vector2(s * 0.24, s * 0.32), c + Vector2(-s * 0.24, s * 0.32)]), Color("c9935a"), s)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.28, s * 0.04 + k * s * 0.09), c + Vector2(s * 0.28, s * 0.04 + k * s * 0.09), Color("9a6b3c"), s * 0.02)
			for k in 4:
				_leaf(ci, c + Vector2(-s * 0.18 + k * s * 0.12, -s * 0.06), Vector2(0.15 * (k - 1.5), -1).normalized(), s * 0.3, Color("2f8f5b"), s)
		"gen_smoothie":
			_line(ci, c + Vector2(0, s * 0.36), c + Vector2(s * 0.04, -s * 0.12), Color("8a5a3a"), s * 0.08)
			for k in 6:
				var a := -PI * 0.5 + (k - 2.5) * 0.55
				_leaf(ci, c + Vector2(s * 0.04, -s * 0.14), Vector2(cos(a), sin(a)), s * 0.32, Color("4f9a3a") if k % 2 == 0 else Color("6cc24a"), s)
			for k in 3:
				_shape(ci, _circle_pts(c + Vector2(-s * 0.04 + k * s * 0.07, -s * 0.06), s * 0.06, 12), Color("7a4a2b"), s * 0.5)
		"gen_pearl":
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.12), s * 0.34, 24, 0.5), Color("9aa0aa"), s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.06), s * 0.32, 24, 0.42), Color("c9ccd2"), s)
			_pearl_ball(ci, c + Vector2(0, s * 0.06), s * 0.1, s)
	_stars(ci, c + Vector2(0, s * 0.4), s, l)
