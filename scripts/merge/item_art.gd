class_name ItemArt
extends RefCounted
## Procedural cartoon icons for every merge item ("chain:level"): bold dark
## outlines, flat fills with a soft highlight, saturated casual palette.
## draw(ci, id, rect) paints the item centred in rect on any CanvasItem.

const OUT := Color("4a2f24")          ## outline ink
const OUT_W := 0.035                  ## outline width (fraction of icon size)


## The glossy baked version (IconBaker) when it is ready, the flat drawing until then.
static func draw_3d(ci: CanvasItem, id: String, r: Rect2) -> void:
	var t := IconBaker.texture(id)
	if t:
		ci.draw_texture_rect(t, r.grow(r.size.x * 0.125), false)   # the bake keeps a 10 % margin
	else:
		draw(ci, id, r)


## A character portrait, baked like the items.
static func draw_portrait(ci: CanvasItem, who: String, r: Rect2) -> void:
	var t := IconBaker.texture("portrait:" + who)
	if t:
		ci.draw_texture_rect(t, r.grow(r.size.x * 0.0435), false)
	else:
		PortraitArt.draw(ci, who, r)


## A customer bust (no frame), baked like the items.
static func draw_bust(ci: CanvasItem, who: String, r: Rect2) -> void:
	var t := IconBaker.texture("bust:" + who)
	if t:
		ci.draw_texture_rect(t, r.grow(r.size.x * 0.0435), false)
	else:
		PortraitArt.draw_bust(ci, who, r)


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
		"glass":
			_glass(ci, c, s, l)
		"candle":
			_candle(ci, c, s, l)
		"lamp":
			_lamp(ci, c, s, l)
		"chart":
			_chart(ci, c, s, l)
		"gen_glass", "gen_candle", "gen_lamp", "gen_chart":
			_workshop_generator(ci, c, s, chain, l)
		"tea":
			_tea(ci, c, s, l)
		"pottery":
			_pottery(ci, c, s, l)
		"dumpling":
			_dumpling(ci, c, s, l)
		"stone":
			_stone(ci, c, s, l)
		"gen_tea", "gen_pottery", "gen_dumpling", "gen_stone":
			_teahouse_generator(ci, c, s, chain, l)
		"fruit":
			_fruit(ci, c, s, l)
		"rope":
			_rope(ci, c, s, l)
		"woven":
			_woven(ci, c, s, l)
		"sail":
			_sail(ci, c, s, l)
		"gen_fruit", "gen_rope", "gen_woven", "gen_sail":
			_market_generator(ci, c, s, chain, l)
		"sweet":
			_sweet(ci, c, s, l)
		"moonflower":
			_moonflower(ci, c, s, l)
		"honey":
			_honey(ci, c, s, l)
		"paperlantern":
			_paperlantern(ci, c, s, l)
		"gen_sweet", "gen_moonflower", "gen_honey", "gen_paperlantern":
			_bakery_generator(ci, c, s, chain, l)
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
		"crate":
			_crate_box(ci, c, s)
		"star":
			_xp_star(ci, c, s)
		"coin":
			_gold_coin(ci, c, s)
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
	if outline == OUT:
		# soft edge in the fill's own darker shade: reads as a rendered object, not ink
		ci.draw_polyline(closed, Color(fill.darkened(0.42), 0.85 * fill.a), maxf(1.2, s * OUT_W * 0.6), true)
	else:
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


# ------------------------------------------------------------------ Lighthouse Workshop

const GLASS_BLUE := Color("8fd0e0")
const WAX := Color("fbf1d6")
const FLAME := Color("ffb52e")
const BRASS := Color("d9a441")
const PAPER_TAN := Color("ecd9ad")


static func _flame(ci: CanvasItem, base: Vector2, h: float, s: float) -> void:
	ci.draw_circle(base + Vector2(0, -h * 0.5), h * 0.9, Color(1.0, 0.8, 0.3, 0.18), true, -1, true)
	_shape(ci, PackedVector2Array([base, base + Vector2(h * 0.32, -h * 0.4), base + Vector2(0, -h), base + Vector2(-h * 0.32, -h * 0.4)]), FLAME, s * 0.5)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -h * 0.1), base + Vector2(h * 0.14, -h * 0.4), base + Vector2(0, -h * 0.7), base + Vector2(-h * 0.14, -h * 0.4)]), Color("fff3c4"))


static func _taper(ci: CanvasItem, base: Vector2, w: float, h: float, s: float, col := WAX) -> void:
	_shape(ci, _rect_pts(Rect2(base + Vector2(-w * 0.5, -h), Vector2(w, h)), w * 0.25), col, s)
	_line(ci, base + Vector2(0, -h), base + Vector2(0, -h - s * 0.04), OUT, s * 0.02)
	_flame(ci, base + Vector2(0, -h - s * 0.03), s * 0.14, s)


static func _pane(ci: CanvasItem, r: Rect2, s: float, cols: Array) -> void:
	_shape(ci, _rect_pts(r, s * 0.03), Color("3a4a5a"), s)
	var inner := r.grow(-s * 0.03)
	var hw := inner.size.x / 2.0
	var hh := inner.size.y / 2.0
	for k in 4:
		var q := Rect2(inner.position + Vector2((k % 2) * hw, (k / 2) * hh), Vector2(hw, hh)).grow(-s * 0.012)
		ci.draw_rect(q, cols[k % cols.size()])
	_hl(ci, inner.position + Vector2(hw * 0.5, hh * 0.5), s * 0.05, 0.6)


static func _glass(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1, 2:
			var cols := [GLASS_BLUE, Color("9fe0b8"), Color("f2b8c6")]
			for k in l:
				var o := c + Vector2((k - (l - 1) * 0.5) * s * 0.22, k * s * 0.06)
				_shape(ci, PackedVector2Array([o + Vector2(-s * 0.16, -s * 0.06), o + Vector2(-s * 0.02, -s * 0.2), o + Vector2(s * 0.16, -s * 0.08), o + Vector2(s * 0.12, s * 0.14), o + Vector2(-s * 0.12, s * 0.16)]), cols[k], s)
				_hl(ci, o + Vector2(-s * 0.04, -s * 0.06), s * 0.04)
		3:
			for k in 3:
				var a := TAU * k / 3.0 - PI / 2.0
				_shape(ci, _circle_pts(c + Vector2(cos(a), sin(a)) * s * 0.14, s * 0.12, 18), [GLASS_BLUE, Color("9fe0b8"), Color("f2b8c6")][k], s * 0.7)
				_hl(ci, c + Vector2(cos(a), sin(a)) * s * 0.14 + Vector2(-s * 0.04, -s * 0.04), s * 0.03, 0.8)
		4:
			var b := PackedVector2Array([c + Vector2(-s * 0.06, -s * 0.38), c + Vector2(s * 0.06, -s * 0.38), c + Vector2(s * 0.06, -s * 0.18), c + Vector2(s * 0.2, -s * 0.06),
				c + Vector2(s * 0.2, s * 0.34), c + Vector2(-s * 0.2, s * 0.34), c + Vector2(-s * 0.2, -s * 0.06), c + Vector2(-s * 0.06, -s * 0.18)])
			_shape(ci, b, Color(0.55, 0.85, 0.75, 0.9), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.08, -s * 0.44), Vector2(s * 0.16, s * 0.08)), s * 0.02), Color("a77b4f"), s * 0.6)
			_hl(ci, c + Vector2(-s * 0.1, s * 0.04), s * 0.05)
		5:
			_pane(ci, Rect2(c - Vector2(s * 0.3, s * 0.34), Vector2(s * 0.6, s * 0.68)), s, [GLASS_BLUE, GLASS_BLUE.lightened(0.2)])
		6:
			_shape(ci, _circle_pts(c, s * 0.3, 28), Color(0.45, 0.8, 0.6, 0.9), s)
			for k in 4:
				var a := TAU * k / 4.0 + PI / 4.0
				_line(ci, c + Vector2(cos(a), sin(a)) * s * 0.3, c + Vector2(cos(a), sin(a)) * s * 0.42, Color("c9a265"), s * 0.03)
			ci.draw_arc(c, s * 0.36, 0, TAU, 32, Color("c9a265"), s * 0.03, true)
			_hl(ci, c + Vector2(-s * 0.1, -s * 0.1), s * 0.08)
		7:
			_pane(ci, Rect2(c - Vector2(s * 0.3, s * 0.36), Vector2(s * 0.6, s * 0.72)), s, [Color("e2554f"), Color("f5cf3c"), Color("3d6fb0"), Color("6cc24a")])
		8:
			_shape(ci, _circle_pts(c, s * 0.4, 32), Color("3a4a5a"), s)
			var cols := [Color("e2554f"), Color("f5cf3c"), Color("3d6fb0"), Color("6cc24a"), Color("b89be8"), Color("f29a76")]
			for k in 6:
				var a0 := TAU * k / 6.0
				ci.draw_colored_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * s * 0.35, c + Vector2(cos(a0 + TAU / 6.0), sin(a0 + TAU / 6.0)) * s * 0.35]), cols[k])
			_shape(ci, _circle_pts(c, s * 0.1, 16), Color("fff3c4"), s * 0.6)
		_:
			# Crystal Dome (9) / the Lens of Dawn (10)
			if l == 10:
				ci.draw_circle(c, s * 0.46, Color(1.0, 0.85, 0.4, 0.25), true, -1, true)
				for k in 8:
					var a := TAU * k / 8.0
					_line(ci, c + Vector2(cos(a), sin(a)) * s * 0.34, c + Vector2(cos(a), sin(a)) * s * 0.46, Color(1.0, 0.85, 0.4, 0.8), s * 0.03)
				_shape(ci, _circle_pts(c, s * 0.3, 32), GLASS_BLUE, s)
				for k in 3:
					ci.draw_arc(c, s * (0.08 + k * 0.08), 0, TAU, 28, Color(1, 1, 1, 0.55), s * 0.02, true)
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)
			else:
				_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.34, s * 0.22), Vector2(s * 0.68, s * 0.12)), s * 0.04), Color("8a5a3a"), s)
				var dome := PackedVector2Array()
				for i in 17:
					var a := PI + PI * i / 16.0
					dome.append(c + Vector2(cos(a) * s * 0.28, s * 0.22 + sin(a) * s * 0.5))
				_shape(ci, dome, Color(0.75, 0.92, 1.0, 0.75), s)
				for k in 3:
					var a := TAU * k / 3.0 - PI / 2.0
					_shape(ci, _circle_pts(c + Vector2(0, s * 0.04) + Vector2(cos(a), sin(a)) * s * 0.09, s * 0.07, 14), [Color("e2554f"), Color("f5cf3c"), Color("3d6fb0")][k], s * 0.5)
				_hl(ci, c + Vector2(-s * 0.14, -s * 0.12), s * 0.06, 0.8)


static func _candle(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.28), c + Vector2(s * 0.18, s * 0.06), c + Vector2(s * 0.12, s * 0.24), c + Vector2(-s * 0.12, s * 0.24), c + Vector2(-s * 0.18, s * 0.06)]), WAX, s)
			_hl(ci, c + Vector2(-s * 0.05, 0), s * 0.05)
		2:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.14), s * 0.26, 24, 0.45), Color("c0c6cc"), s)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.08), s * 0.2, 24, 0.4), WAX, s * 0.6)
			_flame(ci, c + Vector2(0, s * 0.06), s * 0.24, s)
		3:
			_taper(ci, c + Vector2(0, s * 0.36), s * 0.12, s * 0.5, s)
		4:
			_taper(ci, c + Vector2(-s * 0.1, s * 0.36), s * 0.11, s * 0.5, s)
			_taper(ci, c + Vector2(s * 0.12, s * 0.36), s * 0.11, s * 0.4, s, Color("f2c6c0"))
		5:
			_taper(ci, c + Vector2(0, s * 0.38), s * 0.3, s * 0.46, s, Color("f6e2b0"))
		6:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.24, -s * 0.12), Vector2(s * 0.48, s * 0.5)), s * 0.08), Color(0.75, 0.9, 0.95, 0.8), s)
			_taper(ci, c + Vector2(0, s * 0.34), s * 0.3, s * 0.2, s)
		7, 8:
			var n := 3 if l == 7 else 5
			var base_y := s * 0.1 if l == 7 else -s * 0.02
			_line(ci, c + Vector2(0, base_y), c + Vector2(0, s * 0.36), BRASS, s * 0.05)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.38), s * 0.16, 18, 0.35), BRASS, s * 0.7)
			ci.draw_arc(c + Vector2(0, base_y - s * 0.06), s * 0.3, 0.1, PI - 0.1, 20, OUT, s * 0.06, true)
			ci.draw_arc(c + Vector2(0, base_y - s * 0.06), s * 0.3, 0.1, PI - 0.1, 20, BRASS, s * 0.035, true)
			for k in n:
				var x := (k - (n - 1) * 0.5) * (s * 0.6 / (n - 1))
				var y := base_y - s * 0.06 + sqrt(maxf(0.0, s * s * 0.09 - x * x))
				_taper(ci, c + Vector2(x, y), s * 0.07, s * 0.16, s * 0.7)
			if l == 8:
				for k in 4:
					ci.draw_circle(c + Vector2(-s * 0.24 + k * s * 0.16, s * 0.18), s * 0.03, GLASS_BLUE, true, -1, true)
		_:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.38, s * 0.12), Vector2(s * 0.76, s * 0.24)), s * 0.04), Color("8a5a3a"), s)
			for k in 5:
				var hgt := s * (0.2 + 0.08 * (2 - absi(k - 2)))
				_taper(ci, c + Vector2(-s * 0.28 + k * s * 0.14, s * 0.12), s * 0.09, hgt, s * 0.7)
			if l == 10:
				ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.34, Color(1.0, 0.8, 0.3, 0.16), true, -1, true)
				_stars(ci, c + Vector2(0, s * 0.44), s, 3)


static func _lantern_body(ci: CanvasItem, c: Vector2, w: float, h: float, s: float, frame: Color, glow := true) -> void:
	_shape(ci, _rect_pts(Rect2(c + Vector2(-w * 0.5, -h * 0.5), Vector2(w, h)), w * 0.12), frame, s)
	ci.draw_rect(Rect2(c + Vector2(-w * 0.36, -h * 0.36), Vector2(w * 0.72, h * 0.72)), Color("fff1b8") if glow else Color("bfd6e0"))
	if glow:
		_flame(ci, c + Vector2(0, h * 0.25), h * 0.42, s * 0.8)
	_line(ci, c + Vector2(0, -h * 0.5), c + Vector2(0, -h * 0.5 - s * 0.06), frame, s * 0.04)
	ci.draw_arc(c + Vector2(0, -h * 0.5 - s * 0.1), s * 0.06, PI, TAU, 12, OUT, s * 0.03, true)


static func _lamp(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.3), c + Vector2(s * 0.2, s * 0.06), c + Vector2(0, s * 0.28), c + Vector2(-s * 0.2, s * 0.06)]), Color("c98a2b"), s)
			_hl(ci, c + Vector2(-s * 0.06, 0), s * 0.05)
		2:
			var p := PackedVector2Array()
			for i in 10:
				p.append(c + Vector2(sin(i * 0.8) * s * 0.06, s * 0.3 - i * s * 0.06))
			ci.draw_polyline(p, OUT, s * 0.08, true)
			ci.draw_polyline(p, Color("f3ead6"), s * 0.05, true)
		3:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.22, -s * 0.16), Vector2(s * 0.44, s * 0.48)), s * 0.06), Color("8c9aa6"), s)
			_line(ci, c + Vector2(s * 0.1, -s * 0.16), c + Vector2(s * 0.3, -s * 0.36), OUT, s * 0.06)
			_line(ci, c + Vector2(s * 0.1, -s * 0.16), c + Vector2(s * 0.3, -s * 0.36), Color("8c9aa6"), s * 0.035)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.14, 0), Vector2(s * 0.28, s * 0.1)), Color("c98a2b"))
		4:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.18), s * 0.26, 24, 0.5), BRASS, s)
			ci.draw_arc(c + Vector2(s * 0.28, s * 0.16), s * 0.08, -PI / 2, PI / 2, 12, OUT, s * 0.04, true)
			_flame(ci, c + Vector2(-s * 0.06, s * 0.06), s * 0.3, s)
		5, 6, 7, 8:
			var frame: Color = {5: Color("4a5866"), 6: BRASS, 7: Color("c0473e"), 8: Color("2f6f8f")}[l]
			_lantern_body(ci, c + Vector2(0, s * 0.06), s * (0.36 + (l - 5) * 0.04), s * 0.5, s, frame)
			if l >= 7:
				_shape(ci, PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.2), c + Vector2(0, -s * 0.36), c + Vector2(s * 0.26, -s * 0.2)]), frame, s * 0.7)
			if l == 8:
				for k in 2:
					_line(ci, c + Vector2(-s * 0.3 + k * s * 0.6, s * 0.06), c + Vector2(-s * 0.44 + k * s * 0.88, s * 0.06), Color(1.0, 0.85, 0.4, 0.8), s * 0.04)
		_:
			# beacon tower (9) / great lighthouse lamp (10)
			for k in 6:
				var a := -PI / 2.0 + (k - 2.5) * 0.3
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.12), c + Vector2(cos(a - 0.08), sin(a - 0.08)) * s * 0.5 + Vector2(0, -s * 0.12), c + Vector2(cos(a + 0.08), sin(a + 0.08)) * s * 0.5 + Vector2(0, -s * 0.12)]), Color(1.0, 0.85, 0.4, 0.25))
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.18, s * 0.38), c + Vector2(s * 0.18, s * 0.38), c + Vector2(s * 0.12, -s * 0.02), c + Vector2(-s * 0.12, -s * 0.02)]), Color("f4efe6"), s)
			for k in 2:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.15 + k * 0.01 * s, s * 0.08 + k * s * 0.14), Vector2(s * 0.3 - k * 0.02 * s, s * 0.06)), Color("e2554f"))
			_lantern_body(ci, c + Vector2(0, -s * 0.12), s * 0.26, s * 0.22, s, Color("3a4a5a"))
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.22), c + Vector2(0, -s * 0.36), c + Vector2(s * 0.18, -s * 0.22)]), Color("c0473e"), s * 0.7)
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.44), s, 3)


static func _chart(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.2), c + Vector2(s * 0.2, -s * 0.24), c + Vector2(s * 0.24, s * 0.18), c + Vector2(-s * 0.04, s * 0.26), c + Vector2(-s * 0.2, s * 0.14)]), PAPER_TAN, s)
		2:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.26, s * 0.3), Vector2(s * 0.52, s * 0.6)), s * 0.02), PAPER_TAN, s)
			var p := PackedVector2Array([c + Vector2(-s * 0.16, s * 0.1), c + Vector2(-s * 0.04, -s * 0.12), c + Vector2(s * 0.08, s * 0.04), c + Vector2(s * 0.16, -s * 0.14)])
			ci.draw_polyline(p, Color("6b4a2b"), s * 0.025, true)
		3:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.26, s * 0.3), Vector2(s * 0.52, s * 0.6)), s * 0.02), Color("f6efe0"), s)
			for k in 4:
				_line(ci, c + Vector2(-s * 0.18, -s * 0.18 + k * s * 0.12), c + Vector2(s * 0.18, -s * 0.18 + k * s * 0.12), Color("3d6fb0"), s * 0.02)
				ci.draw_circle(c + Vector2(-s * 0.18 + (k % 2) * s * 0.3, -s * 0.18 + k * s * 0.12), s * 0.03, Color("3d6fb0"), true, -1, true)
		4, 5:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.34, s * 0.26), Vector2(s * 0.68, s * 0.52)), s * 0.03), PAPER_TAN if l == 4 else Color("cfe6f2"), s)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.2), c + Vector2(-s * 0.02, -s * 0.18), c + Vector2(s * 0.04, s * 0.04), c + Vector2(-s * 0.12, s * 0.2), c + Vector2(-s * 0.3, s * 0.2)]), Color("9fcf7a"), s * 0.6)
			if l == 5:
				for k in 3:
					ci.draw_arc(c + Vector2(s * 0.14, s * 0.02), s * (0.06 + k * 0.05), -PI / 2, PI / 2, 12, Color("3d6fb0"), s * 0.015, true)
				_line(ci, c + Vector2(s * 0.2, -s * 0.12), c + Vector2(s * 0.2, -s * 0.2), Color("e2554f"), s * 0.03)
			ci.draw_circle(c + Vector2(s * 0.18, -s * 0.06), s * 0.03, Color("e2554f"), true, -1, true)
		6:
			_shape(ci, _circle_pts(c, s * 0.32, 28), BRASS, s)
			_shape(ci, _circle_pts(c, s * 0.25, 28), Color("f6efe0"), s * 0.5)
			_shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.22), c + Vector2(s * 0.05, 0), c + Vector2(0, s * 0.22), c + Vector2(-s * 0.05, 0)]), Color("e2554f"), s * 0.4)
			ci.draw_circle(c, s * 0.03, OUT, true, -1, true)
		7:
			var a := c + Vector2(-s * 0.32, s * 0.16)
			var b := c + Vector2(s * 0.3, -s * 0.18)
			_line(ci, a, b, OUT, s * 0.2)
			_line(ci, a, a.lerp(b, 0.45), BRASS, s * 0.15)
			_line(ci, a.lerp(b, 0.45), b, Color("6b4a2b"), s * 0.12)
			_shape(ci, _circle_pts(b, s * 0.08, 14), Color("cfe6f2"), s * 0.6)
		8:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.28, s * 0.34), Vector2(s * 0.56, s * 0.68)), s * 0.05), Color("6b3a2a"), s)
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.22, s * 0.28), Vector2(s * 0.44, s * 0.56)), s * 0.03), Color("8a4a32"), s * 0.5)
			_shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.12), c + Vector2(s * 0.1, s * 0.04), c + Vector2(-s * 0.1, s * 0.04)]), BRASS, s * 0.5)
			ci.draw_rect(Rect2(c + Vector2(s * 0.12, -s * 0.36), Vector2(s * 0.06, s * 0.2)), Color("e2554f"))
		_:
			_shape(ci, _circle_pts(c, s * 0.38, 32), Color("1f2a4b"), s)
			for k in 9:
				var a := TAU * k / 9.0 + 0.3
				var rr := s * (0.12 + 0.18 * float((k * 7) % 5) / 4.0)
				ci.draw_circle(c + Vector2(cos(a), sin(a)) * rr, s * 0.02 + (k % 3) * s * 0.008, Color("fff3c4"), true, -1, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.1), c + Vector2(-s * 0.05, -s * 0.18), c + Vector2(s * 0.1, -s * 0.05), c + Vector2(s * 0.22, -s * 0.14)]), Color(1, 1, 1, 0.5), s * 0.012, true)
			ci.draw_arc(c, s * 0.38, 0, TAU, 32, BRASS, s * 0.04, true)
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)


static func _workshop_generator(ci: CanvasItem, c: Vector2, s: float, chain: String, l: int) -> void:
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.36), s * 0.36, 24, 0.18), Color(0, 0, 0, 0.18), s, Color(0, 0, 0, 0))
	match chain:
		"gen_glass":
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.32, s * 0.32), c + Vector2(s * 0.32, s * 0.32), c + Vector2(s * 0.28, -s * 0.06), c + Vector2(0, -s * 0.3), c + Vector2(-s * 0.28, -s * 0.06)]), Color("b4643c"), s)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.12), s * 0.14, 18, 0.9), Color("ffb52e"), s * 0.6)
			ci.draw_circle(c + Vector2(0, s * 0.14), s * 0.07, Color("fff3c4"), true, -1, true)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.3, -s * 0.0 + k * s * 0.1), c + Vector2(-s * 0.18, -s * 0.0 + k * s * 0.1), Color("7a3a22"), s * 0.02)
		"gen_candle":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.34, -s * 0.04), Vector2(s * 0.68, s * 0.34)), s * 0.05), Color("8a5a3a"), s)
			for k in 4:
				_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.28 + k * s * 0.15, -s * 0.0), Vector2(s * 0.1, s * 0.22)), s * 0.03), Color("5a3a24"), s * 0.4)
			_taper(ci, c + Vector2(0, -s * 0.04), s * 0.1, s * 0.2, s * 0.8)
		"gen_lamp":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.24, -s * 0.3), Vector2(s * 0.48, s * 0.62)), s * 0.12), Color("8a5a3a"), s)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.24, -s * 0.18 + k * s * 0.2), c + Vector2(s * 0.24, -s * 0.18 + k * s * 0.2), Color("4a3a2a"), s * 0.04)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.32), s * 0.08, 14, 0.6), Color("c98a2b"), s * 0.5)
		"gen_chart":
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.38, -s * 0.04), c + Vector2(s * 0.38, -s * 0.04), c + Vector2(s * 0.3, s * 0.1), c + Vector2(-s * 0.3, s * 0.1)]), Color("8a5a3a"), s)
			_line(ci, c + Vector2(-s * 0.26, s * 0.1), c + Vector2(-s * 0.3, s * 0.36), OUT, s * 0.05)
			_line(ci, c + Vector2(s * 0.26, s * 0.1), c + Vector2(s * 0.3, s * 0.36), OUT, s * 0.05)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.26, -s * 0.24), Vector2(s * 0.44, s * 0.2)), s * 0.02), PAPER_TAN, s * 0.6)
			_shape(ci, _circle_pts(c + Vector2(s * 0.24, -s * 0.16), s * 0.08, 14), BRASS, s * 0.5)
	_stars(ci, c + Vector2(0, s * 0.4), s, l)


# ------------------------------------------------------------------ Terrace Tea House

const TEA_GREEN := Color("6f9a4a")
const CLAY := Color("c97a4a")
const CELADON := Color("a8cfb4")
const DOUGH := Color("f6efe0")
const STONE_GREY := Color("a7a39a")


static func _tea_leaf(ci: CanvasItem, base: Vector2, dir: Vector2, len: float, s: float) -> void:
	_leaf(ci, base, dir, len, TEA_GREEN, s)


static func _teacup(ci: CanvasItem, c: Vector2, w: float, s: float, col: Color, tea := true) -> void:
	_shape(ci, PackedVector2Array([c + Vector2(-w * 0.5, -w * 0.3), c + Vector2(w * 0.5, -w * 0.3), c + Vector2(w * 0.35, w * 0.3), c + Vector2(-w * 0.35, w * 0.3)]), col, s)
	if tea:
		_shape(ci, _circle_pts(c + Vector2(0, -w * 0.3), w * 0.46, 18, 0.25), Color("a7c464"), s * 0.4)


static func _teapot(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	_line(ci, c + Vector2(s * 0.2, 0), c + Vector2(s * 0.38, -s * 0.16), OUT, s * 0.08)
	_line(ci, c + Vector2(s * 0.2, 0), c + Vector2(s * 0.38, -s * 0.16), col, s * 0.05)
	ci.draw_arc(c + Vector2(-s * 0.24, 0), s * 0.1, PI * 0.5, PI * 1.5, 12, OUT, s * 0.05, true)
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.04), s * 0.24, 24, 0.8), col, s)
	_shape(ci, _circle_pts(c + Vector2(0, -s * 0.15), s * 0.12, 16, 0.35), col.darkened(0.15), s * 0.6)
	ci.draw_circle(c + Vector2(0, -s * 0.2), s * 0.035, OUT, true, -1, true)
	_hl(ci, c + Vector2(-s * 0.08, -s * 0.02), s * 0.05)


static func _tea(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_tea_leaf(ci, c + Vector2(-s * 0.14, s * 0.2), Vector2(0.6, -0.8), s * 0.5, s)
		2:
			for k in 3:
				_tea_leaf(ci, c + Vector2(0, s * 0.22), Vector2(-0.5 + k * 0.5, -1).normalized(), s * 0.44, s)
			_line(ci, c + Vector2(-s * 0.08, s * 0.2), c + Vector2(s * 0.08, s * 0.2), Color("c9a265"), s * 0.05)
		3:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.2, -s * 0.26), Vector2(s * 0.4, s * 0.56)), s * 0.05), Color("c0473e"), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.22, -s * 0.32), Vector2(s * 0.44, s * 0.1)), s * 0.03), BRASS, s * 0.6)
			_tea_leaf(ci, c + Vector2(-s * 0.06, s * 0.14), Vector2(0.6, -0.8), s * 0.24, s * 0.6)
		4:
			_teacup(ci, c + Vector2(0, s * 0.06), s * 0.46, s, Color("f4efe6"))
		5:
			_teapot(ci, c, s, Color("4a7a8c"))
		6:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.4, s * 0.12), Vector2(s * 0.8, s * 0.14)), s * 0.04), Color("8a5a3a"), s)
			_teapot(ci, c + Vector2(-s * 0.1, -s * 0.06), s * 0.7, Color("4a7a8c"))
			_teacup(ci, c + Vector2(s * 0.24, s * 0.04), s * 0.18, s * 0.7, Color("f4efe6"))
		7:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.08), s * 0.34, 24, 0.55), Color("3a3a40"), s)
			_shape(ci, _circle_pts(c, s * 0.28, 24, 0.35), Color("8fc24a"), s * 0.5)
			for k in 5:
				_line(ci, c + Vector2(s * 0.2, -s * 0.3 + k * s * 0.03), c + Vector2(s * 0.34, -s * 0.36 + k * s * 0.03), Color("e6d4a8"), s * 0.015)
		8:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.34, -s * 0.22), Vector2(s * 0.68, s * 0.52)), s * 0.04), Color("8a5a3a"), s)
			_line(ci, c + Vector2(-s * 0.34, -s * 0.06), c + Vector2(s * 0.34, -s * 0.06), Color("5a3a24"), s * 0.03)
			_tea_leaf(ci, c + Vector2(-s * 0.06, s * 0.18), Vector2(0.6, -0.8), s * 0.22, s * 0.6)
			ci.draw_circle(c + Vector2(0, -s * 0.14), s * 0.04, BRASS, true, -1, true)
		_:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.42, s * 0.14), Vector2(s * 0.84, s * 0.14)), s * 0.04), Color("5a3a24"), s)
			_teapot(ci, c + Vector2(0, -s * 0.08), s * 0.75, BRASS if l == 10 else Color("4a7a8c"))
			_teacup(ci, c + Vector2(-s * 0.32, s * 0.06), s * 0.14, s * 0.6, Color("f4efe6"))
			_teacup(ci, c + Vector2(s * 0.32, s * 0.06), s * 0.14, s * 0.6, Color("f4efe6"))
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)


static func _vase(ci: CanvasItem, c: Vector2, s: float, col: Color, tall := 1.0) -> void:
	var p := PackedVector2Array()
	var prof := [0.08, 0.1, 0.2, 0.28, 0.26, 0.18, 0.12]
	for k in prof.size():
		p.append(c + Vector2(prof[k] * s, (-0.36 + k * 0.12) * s * tall))
	for k in range(prof.size() - 1, -1, -1):
		p.append(c + Vector2(-prof[k] * s, (-0.36 + k * 0.12) * s * tall))
	_shape(ci, p, col, s)
	_hl(ci, c + Vector2(-s * 0.1, 0), s * 0.05)


static func _pottery(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.24, s * 0.2), c + Vector2(-s * 0.18, -s * 0.12), c + Vector2(s * 0.04, -s * 0.22), c + Vector2(s * 0.24, -s * 0.04), c + Vector2(s * 0.2, s * 0.22)]), CLAY, s)
		2:
			_shape(ci, _circle_pts(c, s * 0.24, 24), CLAY, s)
			_hl(ci, c + Vector2(-s * 0.08, -s * 0.08), s * 0.06)
		3:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.32, -s * 0.06), c + Vector2(s * 0.32, -s * 0.06), c + Vector2(s * 0.18, s * 0.22), c + Vector2(-s * 0.18, s * 0.22)]), CLAY, s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.06), s * 0.3, 20, 0.2), CLAY.darkened(0.25), s * 0.5)
		4:
			_teacup(ci, c + Vector2(-s * 0.14, s * 0.06), s * 0.28, s, CLAY, false)
			_teacup(ci, c + Vector2(s * 0.16, s * 0.1), s * 0.28, s, CELADON, false)
		5:
			_vase(ci, c, s, CLAY)
		6:
			_vase(ci, c, s, Color("3d6fb0"))
			ci.draw_arc(c + Vector2(0, s * 0.02), s * 0.22, 0.2, PI - 0.2, 16, Color("f4efe6"), s * 0.03, true)
		7:
			for k in 3:
				_shape(ci, _circle_pts(c + Vector2(0, s * 0.2 - k * s * 0.08), s * 0.36, 28, 0.25), [Color("f4efe6"), CELADON, Color("3d6fb0")][k], s)
		8:
			_vase(ci, c, s * 1.1, CELADON)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.18, -s * 0.06 + k * s * 0.08), c + Vector2(s * 0.18, -s * 0.06 + k * s * 0.08), CELADON.darkened(0.2), s * 0.015)
		_:
			_vase(ci, c + Vector2(0, s * 0.02), s * 1.15, Color("2f3f6a") if l == 10 else Color("c0473e"))
			if l == 10:
				_shape(ci, _circle_pts(c + Vector2(s * 0.02, -s * 0.06), s * 0.12, 18), Color("f5e6b0"), s * 0.4)
				_stars(ci, c + Vector2(0, s * 0.44), s, 3)
			else:
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.18, s * 0.06), c + Vector2(-s * 0.06, -s * 0.06), c + Vector2(s * 0.06, s * 0.06), c + Vector2(s * 0.18, -s * 0.06)]), BRASS, s * 0.035, true)


static func _bun(ci: CanvasItem, c: Vector2, r: float, s: float) -> void:
	_shape(ci, _circle_pts(c, r, 20, 0.8), DOUGH, s * 0.7)
	for k in 3:
		_line(ci, c + Vector2(0, -r * 0.6), c + Vector2((k - 1) * r * 0.5, -r * 0.1), Color(0.6, 0.5, 0.4, 0.5), s * 0.015)


static func _steamer(ci: CanvasItem, c: Vector2, w: float, s: float) -> void:
	_shape(ci, _rect_pts(Rect2(c + Vector2(-w * 0.5, -w * 0.12), Vector2(w, w * 0.32)), w * 0.06), Color("d9b46a"), s)
	for k in 4:
		_line(ci, c + Vector2(-w * 0.5, -w * 0.06 + k * w * 0.07), c + Vector2(w * 0.5, -w * 0.06 + k * w * 0.07), Color("a8823f"), s * 0.012)


static func _dumpling(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.26, s * 0.24), c + Vector2(s * 0.26, s * 0.24), c + Vector2(s * 0.2, -s * 0.12), c + Vector2(0, -s * 0.26), c + Vector2(-s * 0.2, -s * 0.12)]), Color("e8d9b8"), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.12, -s * 0.02), Vector2(s * 0.24, s * 0.14)), s * 0.02), Color("c0473e"), s * 0.5)
		2:
			_shape(ci, _circle_pts(c, s * 0.24, 24, 0.85), DOUGH, s)
		3:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.3, s * 0.12), c + Vector2(-s * 0.16, -s * 0.16), c + Vector2(0, -s * 0.22), c + Vector2(s * 0.16, -s * 0.16), c + Vector2(s * 0.3, s * 0.12), c + Vector2(0, s * 0.2)]), DOUGH, s)
			for k in 4:
				_line(ci, c + Vector2(-s * 0.15 + k * s * 0.1, -s * 0.16), c + Vector2(-s * 0.12 + k * s * 0.08, -s * 0.06), Color(0.6, 0.5, 0.4, 0.6), s * 0.015)
		4:
			for k in 2:
				_bun(ci, c + Vector2(-s * 0.15 + k * s * 0.3, k * s * 0.06), s * 0.17, s)
		5:
			_steamer(ci, c + Vector2(0, s * 0.12), s * 0.7, s)
			for k in 3:
				_bun(ci, c + Vector2(-s * 0.2 + k * s * 0.2, -s * 0.06), s * 0.11, s)
		6:
			_plate(ci, c, s, 0.42)
			for k in 4:
				_bun(ci, c + Vector2(-s * 0.21 + k * s * 0.14, s * 0.02 - (k % 2) * s * 0.06), s * 0.09, s)
		7:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.08), s * 0.34, 24, 0.6), Color("f4efe6"), s)
			_shape(ci, _circle_pts(c, s * 0.28, 24, 0.38), Color("e6a93a"), s * 0.5)
			for k in 4:
				ci.draw_arc(c + Vector2(-s * 0.1 + k * s * 0.06, 0), s * 0.06, 0, PI, 8, Color("fff3c4"), s * 0.02, true)
			_line(ci, c + Vector2(s * 0.1, -s * 0.1), c + Vector2(s * 0.34, -s * 0.36), Color("a77b4f"), s * 0.03)
		8:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.1), s * 0.38, 24, 0.55), Color("3a3a40"), s)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.02), s * 0.32, 24, 0.38), Color("e2554f"), s * 0.5)
			for k in 4:
				ci.draw_circle(c + Vector2(-s * 0.15 + k * s * 0.1, (k % 2) * s * 0.05), s * 0.045, [DOUGH, Color("6cc24a"), Color("f5cf3c"), DOUGH][k], true, -1, true)
		_:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.42, s * 0.04), Vector2(s * 0.84, s * 0.28)), s * 0.05), Color("c0473e"), s)
			_steamer(ci, c + Vector2(-s * 0.16, -s * 0.06), s * 0.36, s * 0.7)
			_steamer(ci, c + Vector2(s * 0.18, -s * 0.06), s * 0.36, s * 0.7)
			_bun(ci, c + Vector2(0, -s * 0.24), s * 0.1, s)
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)


static func _pebble(ci: CanvasItem, c: Vector2, rx: float, ry: float, s: float, col := STONE_GREY) -> void:
	_shape(ci, _circle_pts(c, rx, 20, ry / rx), col, s * 0.7)
	_hl(ci, c + Vector2(-rx * 0.35, -ry * 0.35), rx * 0.25, 0.6)


static func _stone(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_pebble(ci, c, s * 0.2, s * 0.14, s)
		2:
			_pebble(ci, c, s * 0.28, s * 0.18, s, Color("8f9aa0"))
		3:
			_pebble(ci, c + Vector2(-s * 0.12, s * 0.06), s * 0.18, s * 0.12, s)
			_pebble(ci, c + Vector2(s * 0.14, -s * 0.02), s * 0.16, s * 0.11, s, Color("8f9aa0"))
		4:
			for k in 3:
				_pebble(ci, c + Vector2(0, s * 0.2 - k * s * 0.16), s * (0.26 - k * 0.06), s * 0.09, s, [STONE_GREY, Color("8f9aa0"), Color("b8b3a8")][k])
		5:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.08, s * 0.0), Vector2(s * 0.16, s * 0.34)), s * 0.02), STONE_GREY, s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.16, -s * 0.16), Vector2(s * 0.32, s * 0.18)), s * 0.03), Color("8f9aa0"), s)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.08, -s * 0.12), Vector2(s * 0.16, s * 0.1)), Color("ffe08a"))
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.16), c + Vector2(0, -s * 0.36), c + Vector2(s * 0.26, -s * 0.16)]), STONE_GREY, s)
		6:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.36, s * 0.24), c + Vector2(-s * 0.24, -s * 0.14), c + Vector2(0, -s * 0.3), c + Vector2(s * 0.3, -s * 0.06), c + Vector2(s * 0.36, s * 0.24)]), Color("8f9aa0"), s)
			ci.draw_circle(c + Vector2(-s * 0.1, -s * 0.12), s * 0.08, MOSS_GREEN, true, -1, true)
		7:
			ci.draw_arc(c + Vector2(0, s * 0.24), s * 0.34, PI, TAU, 24, OUT, s * 0.16, true)
			ci.draw_arc(c + Vector2(0, s * 0.24), s * 0.34, PI, TAU, 24, STONE_GREY, s * 0.12, true)
			_line(ci, c + Vector2(-s * 0.42, s * 0.3), c + Vector2(s * 0.42, s * 0.3), Color("57b8d6"), s * 0.06)
		8:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.38, s * 0.26), Vector2(s * 0.76, s * 0.52)), s * 0.04), Color("e6dcc6"), s)
			for k in 4:
				ci.draw_arc(c + Vector2(-s * 0.1, 0), s * (0.06 + k * 0.06), 0, TAU, 24, Color("b8ad94"), s * 0.012, true)
			_pebble(ci, c + Vector2(-s * 0.1, 0), s * 0.06, s * 0.05, s)
			_pebble(ci, c + Vector2(s * 0.22, s * 0.1), s * 0.08, s * 0.06, s)
		_:
			for k in 4:
				var w := s * (0.36 - k * 0.07)
				var y := s * 0.28 - k * s * 0.17
				_shape(ci, _rect_pts(Rect2(c + Vector2(-w * 0.6, y - s * 0.08), Vector2(w * 1.2, s * 0.1)), s * 0.02), STONE_GREY, s * 0.7)
				_shape(ci, PackedVector2Array([c + Vector2(-w, y - s * 0.08), c + Vector2(w, y - s * 0.08), c + Vector2(w * 0.7, y - s * 0.14), c + Vector2(-w * 0.7, y - s * 0.14)]), Color("6f6a61"), s * 0.6)
			if l == 10:
				ci.draw_circle(c + Vector2(0, -s * 0.42), s * 0.06, Color("ffe08a"), true, -1, true)
				_stars(ci, c + Vector2(0, s * 0.44), s, 3)


const MOSS_GREEN := Color("7fa35a")


static func _teahouse_generator(ci: CanvasItem, c: Vector2, s: float, chain: String, l: int) -> void:
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.36), s * 0.36, 24, 0.18), Color(0, 0, 0, 0.18), s, Color(0, 0, 0, 0))
	match chain:
		"gen_tea":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.18, s * 0.12), Vector2(s * 0.36, s * 0.22)), s * 0.04), CLAY, s)
			for k in 7:
				var a := -PI * 0.5 + (k - 3) * 0.4
				_tea_leaf(ci, c + Vector2(0, s * 0.12), Vector2(cos(a), sin(a)), s * 0.36, s)
		"gen_pottery":
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.18), s * 0.36, 24, 0.35), Color("8a5a3a"), s)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.1), s * 0.3, 24, 0.3), Color("5a3a24"), s * 0.6)
			_vase(ci, c + Vector2(0, -s * 0.04), s * 0.6, CLAY)
		"gen_dumpling":
			for k in 2:
				_steamer(ci, c + Vector2(0, s * 0.16 - k * s * 0.2), s * 0.66, s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.18), s * 0.34, 24, 0.25), Color("e6c47a"), s)
			for k in 3:
				ci.draw_arc(c + Vector2(-s * 0.12 + k * s * 0.12, -s * 0.34), s * 0.05, PI, TAU, 8, Color(1, 1, 1, 0.7), s * 0.02, true)
		"gen_stone":
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.4, s * 0.3), c + Vector2(-s * 0.28, -s * 0.12), c + Vector2(-s * 0.04, -s * 0.28), c + Vector2(s * 0.3, -s * 0.16), c + Vector2(s * 0.4, s * 0.3)]), Color("8f9aa0"), s)
			_line(ci, c + Vector2(-s * 0.06, -s * 0.24), c + Vector2(s * 0.06, s * 0.1), Color("5e5b4f"), s * 0.03)
			_line(ci, c + Vector2(s * 0.12, -s * 0.04), c + Vector2(s * 0.3, -s * 0.36), Color("a77b4f"), s * 0.04)
			_shape(ci, PackedVector2Array([c + Vector2(s * 0.26, -s * 0.42), c + Vector2(s * 0.4, -s * 0.34), c + Vector2(s * 0.34, -s * 0.28)]), Color("8c9aa6"), s * 0.5)
	_stars(ci, c + Vector2(0, s * 0.4), s, l)


# ------------------------------------------------------------------ Rope Market

const ROPE_TAN := Color("c9a265")
const ROPE_DARK := Color("8a6a3a")
const REED := Color("d8b86a")
const CLOTH_RED := Color("e2554f")
const CLOTH_BLUE := Color("3d6fb0")


static func _berry(ci: CanvasItem, c: Vector2, r: float, s: float, col := Color("c0396b")) -> void:
	_shape(ci, _circle_pts(c, r, 16), col, s * 0.6)
	_hl(ci, c + Vector2(-r * 0.35, -r * 0.35), r * 0.3, 0.7)


static func _banana(ci: CanvasItem, c: Vector2, s: float) -> void:
	var p := PackedVector2Array()
	for i in 12:
		var a := PI * 0.15 + PI * 0.7 * i / 11.0
		p.append(c + Vector2(cos(a) * s * 0.3, sin(a) * s * 0.3 - s * 0.16))
	for i in range(11, -1, -1):
		var a := PI * 0.15 + PI * 0.7 * i / 11.0
		p.append(c + Vector2(cos(a) * s * 0.2, sin(a) * s * 0.18 - s * 0.1))
	_shape(ci, p, Color("f5cf3c"), s)


static func _fruit(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_berry(ci, c, s * 0.16, s)
			_leaf(ci, c + Vector2(0, -s * 0.14), Vector2(0.7, -0.7), s * 0.14, Color("6cc24a"), s * 0.6)
		2:
			_berry(ci, c + Vector2(-s * 0.1, s * 0.04), s * 0.14, s)
			_berry(ci, c + Vector2(s * 0.12, -s * 0.02), s * 0.14, s, Color("5a3d8a"))
		3:
			_banana(ci, c, s)
		4:
			_shape(ci, _circle_pts(c, s * 0.28, 24, 1.25), Color("f5a524"), s)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.04), s * 0.14, 18, 1.4), Color("f28a5c"), s * 0.5)
			for k in 3:
				ci.draw_circle(c + Vector2(0, -s * 0.04 + k * s * 0.07), s * 0.025, OUT, true, -1, true)
		5:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.12), s * 0.34, 24, 0.55), Color("c9935a"), s)
			_berry(ci, c + Vector2(-s * 0.14, -s * 0.02), s * 0.1, s)
			_shape(ci, _circle_pts(c + Vector2(s * 0.12, -s * 0.04), s * 0.12, 16), Color("f5a524"), s * 0.6)
			_berry(ci, c + Vector2(0, -s * 0.12), s * 0.09, s, Color("6cc24a"))
		6:
			_line(ci, c + Vector2(-s * 0.36, s * 0.3), c + Vector2(s * 0.36, -s * 0.3), Color("a77b4f"), s * 0.03)
			for k in 4:
				var p := c + Vector2(-s * 0.36, s * 0.3).lerp(Vector2(s * 0.36, -s * 0.3), (k + 1) / 5.0)
				_berry(ci, p, s * 0.08, s, [Color("c0396b"), Color("f5a524"), Color("6cc24a"), Color("f5cf3c")][k])
		7, 8:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.36, -s * 0.06), Vector2(s * 0.72, s * 0.34)), s * 0.03), Color("b07a45"), s)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.36, s * 0.04 + k * s * 0.08), c + Vector2(s * 0.36, s * 0.04 + k * s * 0.08), Color("7a5230"), s * 0.015)
			for k in 4:
				_berry(ci, c + Vector2(-s * 0.24 + k * s * 0.16, -s * 0.1), s * 0.08, s, [Color("f5a524"), Color("c0396b"), Color("6cc24a"), Color("f5cf3c")][k])
			if l == 8:
				for k in 2:
					_shape(ci, _circle_pts(c + Vector2(-s * 0.24 + k * s * 0.48, s * 0.3), s * 0.09, 16), Color("3a3a40"), s * 0.6)
		_:
			if l == 10:
				_shape(ci, PackedVector2Array([c + Vector2(-s * 0.42, s * 0.04), c + Vector2(s * 0.42, s * 0.04), c + Vector2(s * 0.3, s * 0.3), c + Vector2(-s * 0.3, s * 0.3)]), Color("8a5a3a"), s)
			for row in 3:
				for k in 3 - row:
					var p := c + Vector2((k - (2 - row) * 0.5) * s * 0.18, s * (0.08 if l == 9 else -0.04) - row * s * 0.15 + (s * 0.12 if l == 9 else 0.0))
					_berry(ci, p, s * 0.09, s, [Color("f5a524"), Color("c0396b"), Color("6cc24a")][(row + k) % 3])
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)


static func _coil(ci: CanvasItem, c: Vector2, r: float, s: float, col := ROPE_TAN) -> void:
	_shape(ci, _circle_pts(c, r, 24, 0.8), col, s)
	for k in 3:
		ci.draw_arc(c, r * (0.3 + k * 0.22), 0, TAU, 20, ROPE_DARK, s * 0.018, true)


static func _rope(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			var p := PackedVector2Array()
			for i in 12:
				p.append(c + Vector2(-s * 0.3 + i * s * 0.055, sin(i * 0.9) * s * 0.08))
			ci.draw_polyline(p, OUT, s * 0.07, true)
			ci.draw_polyline(p, ROPE_TAN, s * 0.045, true)
		2:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.18, -s * 0.24), Vector2(s * 0.36, s * 0.48)), s * 0.06), Color("a77b4f"), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.14, -s * 0.16), Vector2(s * 0.28, s * 0.32)), s * 0.03), ROPE_TAN, s * 0.6)
		3:
			_coil(ci, c, s * 0.3, s)
		4:
			_coil(ci, c + Vector2(0, s * 0.08), s * 0.24, s)
			ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.1, 0, TAU, 16, OUT, s * 0.07, true)
			ci.draw_arc(c + Vector2(0, -s * 0.2), s * 0.1, 0, TAU, 16, ROPE_TAN, s * 0.045, true)
		5:
			for k in 2:
				_line(ci, c + Vector2(-s * 0.18 + k * s * 0.36, -s * 0.4), c + Vector2(-s * 0.18 + k * s * 0.36, s * 0.4), ROPE_TAN, s * 0.05)
			for k in 5:
				_line(ci, c + Vector2(-s * 0.18, -s * 0.3 + k * s * 0.15), c + Vector2(s * 0.18, -s * 0.3 + k * s * 0.15), Color("a77b4f"), s * 0.05)
		6:
			_shape(ci, _circle_pts(c, s * 0.36, 24, 0.85), Color(0, 0, 0, 0), s, Color(0, 0, 0, 0))
			for k in 5:
				_line(ci, c + Vector2(-s * 0.36 + k * s * 0.18, -s * 0.3), c + Vector2(-s * 0.3 + k * s * 0.15, s * 0.3), ROPE_TAN, s * 0.025)
				_line(ci, c + Vector2(-s * 0.36, -s * 0.3 + k * s * 0.15), c + Vector2(s * 0.36, -s * 0.3 + k * s * 0.15), ROPE_TAN, s * 0.025)
			_shape(ci, _circle_pts(c + Vector2(s * 0.24, s * 0.24), s * 0.08, 14), Color("f2efe9"), s * 0.5)
		7:
			for k in 2:
				_line(ci, c + Vector2(-s * 0.42 + k * s * 0.84, -s * 0.36), c + Vector2(-s * 0.42 + k * s * 0.84, s * 0.3), Color("8a5a3a"), s * 0.06)
			var p := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				p.append(c + Vector2(-s * 0.4 + t * s * 0.8, -s * 0.2 + sin(t * PI) * s * 0.3))
			ci.draw_polyline(p, OUT, s * 0.16, true)
			ci.draw_polyline(p, CLOTH_RED, s * 0.12, true)
		8:
			_line(ci, c + Vector2(-s * 0.4, -s * 0.06), c + Vector2(s * 0.4, -s * 0.06), ROPE_TAN, s * 0.04)
			_line(ci, c + Vector2(-s * 0.4, s * 0.14), c + Vector2(s * 0.4, s * 0.14), ROPE_TAN, s * 0.04)
			for k in 6:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.36 + k * s * 0.125, -s * 0.04), Vector2(s * 0.08, s * 0.16)), Color("a77b4f"))
			for k in 2:
				_line(ci, c + Vector2(-s * 0.4 + k * s * 0.8, -s * 0.3), c + Vector2(-s * 0.4 + k * s * 0.8, s * 0.3), Color("8a5a3a"), s * 0.05)
		_:
			_line(ci, c + Vector2(0, -s * 0.42), c + Vector2(0, s * 0.36), Color("8a5a3a"), s * 0.06)
			for k in 4:
				_line(ci, c + Vector2(0, -s * 0.38), c + Vector2(-s * 0.36 + k * s * 0.24, s * 0.32), Color(0.5, 0.4, 0.25), s * 0.02)
			_line(ci, c + Vector2(-s * 0.2, -s * 0.12), c + Vector2(s * 0.2, -s * 0.12), Color("8a5a3a"), s * 0.04)
			if l == 10:
				_coil(ci, c + Vector2(0, s * 0.16), s * 0.16, s * 0.7, Color("ffcf3a"))
				_stars(ci, c + Vector2(0, s * 0.44), s, 3)


static func _basket(ci: CanvasItem, c: Vector2, w: float, h: float, s: float) -> void:
	_shape(ci, PackedVector2Array([c + Vector2(-w * 0.5, -h * 0.5), c + Vector2(w * 0.5, -h * 0.5), c + Vector2(w * 0.4, h * 0.5), c + Vector2(-w * 0.4, h * 0.5)]), REED, s)
	for k in 3:
		_line(ci, c + Vector2(-w * 0.46, -h * 0.25 + k * h * 0.25), c + Vector2(w * 0.46, -h * 0.25 + k * h * 0.25), REED.darkened(0.25), s * 0.015)
	for k in 5:
		_line(ci, c + Vector2(-w * 0.4 + k * w * 0.2, -h * 0.5), c + Vector2(-w * 0.32 + k * w * 0.16, h * 0.5), REED.darkened(0.25), s * 0.012)


static func _woven(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_line(ci, c + Vector2(-s * 0.04, s * 0.36), c + Vector2(s * 0.04, -s * 0.36), REED, s * 0.05)
			_shape(ci, _circle_pts(c + Vector2(s * 0.03, -s * 0.24), s * 0.05, 10, 2.0), Color("8a5a3a"), s * 0.5)
		2:
			for k in 5:
				_line(ci, c + Vector2(-s * 0.12 + k * s * 0.06, s * 0.36), c + Vector2(-s * 0.08 + k * s * 0.04, -s * 0.36), REED, s * 0.04)
			_line(ci, c + Vector2(-s * 0.16, 0), c + Vector2(s * 0.16, 0), CLOTH_RED, s * 0.05)
		3:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.34, s * 0.24), Vector2(s * 0.68, s * 0.48)), s * 0.03), REED, s)
			for k in 4:
				_line(ci, c + Vector2(-s * 0.34, -s * 0.18 + k * s * 0.12), c + Vector2(s * 0.34, -s * 0.18 + k * s * 0.12), REED.darkened(0.2), s * 0.02)
		4:
			_basket(ci, c + Vector2(0, s * 0.06), s * 0.5, s * 0.36, s)
		5:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.1), s * 0.42, 28, 0.3), REED, s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.02), s * 0.2, 20, 0.8), REED.darkened(0.08), s)
			_line(ci, c + Vector2(-s * 0.2, s * 0.02), c + Vector2(s * 0.2, s * 0.02), CLOTH_RED, s * 0.05)
		6:
			ci.draw_arc(c + Vector2(0, -s * 0.06), s * 0.24, PI, TAU, 16, OUT, s * 0.07, true)
			ci.draw_arc(c + Vector2(0, -s * 0.06), s * 0.24, PI, TAU, 16, REED.darkened(0.15), s * 0.045, true)
			_basket(ci, c + Vector2(0, s * 0.12), s * 0.62, s * 0.36, s)
		7:
			_basket(ci, c, s * 0.42, s * 0.56, s)
			ci.draw_circle(c, s * 0.12, Color(1.0, 0.85, 0.4, 0.6), true, -1, true)
			_line(ci, c + Vector2(0, -s * 0.28), c + Vector2(0, -s * 0.4), ROPE_DARK, s * 0.03)
		8:
			_basket(ci, c + Vector2(0, s * 0.02), s * 0.56, s * 0.3, s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.26, -s * 0.38), Vector2(s * 0.52, s * 0.26)), s * 0.06), REED, s * 0.8)
			for k in 2:
				_line(ci, c + Vector2(-s * 0.2 + k * s * 0.4, s * 0.16), c + Vector2(-s * 0.22 + k * s * 0.44, s * 0.36), REED.darkened(0.25), s * 0.04)
		_:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.44, -s * 0.02), c + Vector2(s * 0.44, -s * 0.02), c + Vector2(s * 0.3, s * 0.22), c + Vector2(-s * 0.3, s * 0.22)]), REED, s)
			for k in 4:
				_line(ci, c + Vector2(-s * 0.3 + k * s * 0.2, -s * 0.02), c + Vector2(-s * 0.26 + k * s * 0.17, s * 0.22), REED.darkened(0.25), s * 0.015)
			if l == 10:
				_shape(ci, PackedVector2Array([c + Vector2(-s * 0.26, -s * 0.06), c + Vector2(-s * 0.26, -s * 0.3), c + Vector2(-s * 0.13, -s * 0.18), c + Vector2(0, -s * 0.36), c + Vector2(s * 0.13, -s * 0.18), c + Vector2(s * 0.26, -s * 0.3), c + Vector2(s * 0.26, -s * 0.06)]), Color("ffcf3a"), s * 0.7)
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)
			else:
				_line(ci, c + Vector2(0, -s * 0.02), c + Vector2(0, -s * 0.4), ROPE_DARK, s * 0.03)
				_shape(ci, PackedVector2Array([c + Vector2(s * 0.02, -s * 0.38), c + Vector2(s * 0.28, -s * 0.08), c + Vector2(s * 0.02, -s * 0.08)]), Color("f4efe6"), s * 0.6)


static func _sail(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.24, -s * 0.16), c + Vector2(s * 0.2, -s * 0.22), c + Vector2(s * 0.26, s * 0.18), c + Vector2(-s * 0.2, s * 0.22)]), CLOTH_RED, s)
		2:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.32, -s * 0.14), Vector2(s * 0.64, s * 0.28)), s * 0.12), CLOTH_BLUE, s)
			ci.draw_arc(c + Vector2(-s * 0.32, 0), s * 0.12, PI * 0.5, PI * 1.5, 12, CLOTH_BLUE.darkened(0.3), s * 0.03, true)
		3:
			for k in 4:
				ci.draw_rect(Rect2(c + Vector2(-s * 0.3 + (k % 2) * s * 0.3, -s * 0.3 + (k / 2) * s * 0.3), Vector2(s * 0.3, s * 0.3)), [CLOTH_RED, Color("f5cf3c"), CLOTH_BLUE, Color("6cc24a")][k])
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.3, s * 0.3), Vector2(s * 0.6, s * 0.6)), s * 0.02), Color(0, 0, 0, 0), s)
		4:
			_line(ci, c + Vector2(-s * 0.24, -s * 0.38), c + Vector2(-s * 0.24, s * 0.38), Color("8a5a3a"), s * 0.05)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.34), c + Vector2(s * 0.32, -s * 0.2), c + Vector2(-s * 0.22, -s * 0.04)]), CLOTH_RED, s)
		5:
			var p := PackedVector2Array()
			for i in 9:
				p.append(c + Vector2(-s * 0.42 + i * s * 0.105, -s * 0.2 + sin(i * PI / 8.0) * s * 0.12))
			ci.draw_polyline(p, ROPE_DARK, s * 0.025, true)
			for i in 4:
				var q: Vector2 = p[i * 2 + 1]
				_shape(ci, PackedVector2Array([q + Vector2(-s * 0.07, 0), q + Vector2(s * 0.07, 0), q + Vector2(0, s * 0.18)]), [CLOTH_RED, Color("f5cf3c"), CLOTH_BLUE, Color("6cc24a")][i], s * 0.5)
		6, 7:
			_line(ci, c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.3), Color("8a5a3a"), s * 0.05)
			var sp := PackedVector2Array([c + Vector2(s * 0.03, -s * 0.36), c + Vector2(s * 0.34, s * 0.16), c + Vector2(s * 0.03, s * 0.16)])
			_shape(ci, sp, Color("f4efe6") if l == 6 else CLOTH_RED, s)
			if l == 7:
				for k in 2:
					_line(ci, c + Vector2(s * 0.05, -s * 0.16 + k * s * 0.16), c + Vector2(s * 0.12 + k * s * 0.1, -s * 0.16 + k * s * 0.16), Color("f4efe6"), s * 0.04)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.3, s * 0.2), c + Vector2(s * 0.3, s * 0.2), c + Vector2(s * 0.22, s * 0.36), c + Vector2(-s * 0.22, s * 0.36)]), Color("8a5a3a"), s)
		8:
			_shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.4), c + Vector2(s * 0.3, 0), c + Vector2(0, s * 0.3), c + Vector2(-s * 0.3, 0)]), CLOTH_BLUE, s)
			_line(ci, c + Vector2(0, -s * 0.4), c + Vector2(0, s * 0.3), Color(1, 1, 1, 0.6), s * 0.02)
			_line(ci, c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), Color(1, 1, 1, 0.6), s * 0.02)
			var tail := PackedVector2Array()
			for i in 6:
				tail.append(c + Vector2(sin(i * 1.2) * s * 0.06, s * 0.3 + i * s * 0.03))
			ci.draw_polyline(tail, ROPE_DARK, s * 0.02, true)
		_:
			_line(ci, c + Vector2(-s * 0.06, -s * 0.44), c + Vector2(-s * 0.06, s * 0.3), Color("8a5a3a"), s * 0.05)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.04, -s * 0.4), c + Vector2(s * 0.38, s * 0.14), c + Vector2(-s * 0.04, s * 0.14)]), Color("f4efe6") if l == 9 else Color("ffcf3a"), s)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.08, -s * 0.3), c + Vector2(-s * 0.34, s * 0.14), c + Vector2(-s * 0.08, s * 0.14)]), CLOTH_RED, s)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.4, s * 0.18), c + Vector2(s * 0.4, s * 0.18), c + Vector2(s * 0.28, s * 0.36), c + Vector2(-s * 0.28, s * 0.36)]), Color("8a5a3a"), s)
			if l == 10:
				_stars(ci, c + Vector2(0, s * 0.44), s, 3)


static func _market_generator(ci: CanvasItem, c: Vector2, s: float, chain: String, l: int) -> void:
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.36), s * 0.36, 24, 0.18), Color(0, 0, 0, 0.18), s, Color(0, 0, 0, 0))
	match chain:
		"gen_fruit":
			_line(ci, c + Vector2(0, s * 0.36), c + Vector2(0, -s * 0.04), Color("8a5a3a"), s * 0.09)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.14), s * 0.3, 24, 0.75), Color("4f9a3a"), s)
			for k in 4:
				_berry(ci, c + Vector2(-s * 0.16 + k * s * 0.11, -s * 0.16 + (k % 2) * s * 0.1), s * 0.06, s * 0.7, [Color("c0396b"), Color("f5a524")][k % 2])
		"gen_rope":
			_coil(ci, c + Vector2(0, s * 0.06), s * 0.34, s)
			_coil(ci, c + Vector2(0, -s * 0.06), s * 0.24, s * 0.8, ROPE_TAN.lightened(0.1))
		"gen_woven":
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.24), s * 0.36, 24, 0.3), Color("57b8d6"), s)
			for k in 7:
				var x := -s * 0.27 + k * s * 0.09
				_line(ci, c + Vector2(x, s * 0.24), c + Vector2(x + sin(k) * s * 0.04, -s * 0.3 + (k % 3) * s * 0.06), REED.darkened(0.1), s * 0.035)
				_shape(ci, _circle_pts(c + Vector2(x + sin(k) * s * 0.04, -s * 0.3 + (k % 3) * s * 0.06), s * 0.03, 8, 2.0), Color("8a5a3a"), s * 0.3)
		"gen_sail":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.34, -s * 0.1), Vector2(s * 0.68, s * 0.42)), s * 0.04), Color("a77b4f"), s)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.08), c + Vector2(0, -s * 0.38), c + Vector2(s * 0.4, -s * 0.08)]), CLOTH_RED, s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.1, s * 0.08), Vector2(s * 0.2, s * 0.24)), s * 0.03), Color("f4efe6"), s * 0.5)
	_stars(ci, c + Vector2(0, s * 0.4), s, l)


# ------------------------------------------------------------------ Moonlight Bakery

const MOON_PURPLE := Color("7d5ba6")
const MOON_PALE := Color("e9ecff")
const PETAL := Color("c9cff5")
const HONEY := Color("f2b632")
const ICING := Color("f6d6e6")
const PAPER_RED := Color("e2554f")


static func _bloom(ci: CanvasItem, c: Vector2, r: float, s: float, col := PETAL) -> void:
	for k in 5:
		var a := -PI / 2.0 + TAU * k / 5.0
		_shape(ci, _circle_pts(c + Vector2(cos(a), sin(a)) * r * 0.55, r * 0.45, 14), col, s * 0.5)
	_shape(ci, _circle_pts(c, r * 0.32, 14), Color("f5e6b0"), s * 0.4)


static func _sweet(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.18, s * 0.18), Vector2(s * 0.36, s * 0.36)), s * 0.04), Color("fbfaf4"), s)
			_hl(ci, c + Vector2(-s * 0.06, -s * 0.06), s * 0.05)
		2:
			_shape(ci, _circle_pts(c, s * 0.16, 18), Color("e86a8c"), s)
			for k in 2:
				var sgn := -1 if k == 0 else 1
				_shape(ci, PackedVector2Array([c + Vector2(sgn * s * 0.14, 0), c + Vector2(sgn * s * 0.32, -s * 0.12), c + Vector2(sgn * s * 0.32, s * 0.12)]), Color("e86a8c").lightened(0.2), s * 0.6)
		3:
			_shape(ci, _circle_pts(c, s * 0.28, 24), Color("d9a45a"), s)
			for k in 5:
				ci.draw_circle(c + Vector2(cos(k * 1.3) * s * 0.14, sin(k * 1.9) * s * 0.14), s * 0.035, Color("5a3a24"), true, -1, true)
		4:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.22, 0), c + Vector2(s * 0.22, 0), c + Vector2(s * 0.16, s * 0.3), c + Vector2(-s * 0.16, s * 0.3)]), Color("c9935a"), s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.04), s * 0.24, 20, 0.7), ICING, s)
			ci.draw_circle(c + Vector2(0, -s * 0.24), s * 0.06, Color("e2554f"), true, -1, true)
		5:
			_shape(ci, _circle_pts(c, s * 0.3, 24, 0.9), Color("d9a45a"), s)
			_shape(ci, _circle_pts(c, s * 0.2, 20, 0.9), Color("c9935a"), s * 0.5)
			ci.draw_arc(c + Vector2(s * 0.04, 0), s * 0.12, PI * 0.6, PI * 1.6, 12, Color("8a5a3a"), s * 0.03, true)
		6:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.32, s * 0.24), c + Vector2(s * 0.32, s * 0.24), c + Vector2(0, -s * 0.3)]), Color("f6efe0"), s)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.2, s * 0.06), c + Vector2(s * 0.2, s * 0.06), c + Vector2(0, -s * 0.3)]), ICING, s * 0.5)
			_line(ci, c + Vector2(-s * 0.26, s * 0.14), c + Vector2(s * 0.26, s * 0.14), MOON_PURPLE, s * 0.04)
		7, 9, 10:
			var tiers := 2 if l == 7 else 3
			for k in tiers:
				var w := s * (0.4 - k * 0.1)
				var y := s * 0.3 - k * s * 0.2
				_shape(ci, _rect_pts(Rect2(c + Vector2(-w, y - s * 0.18), Vector2(w * 2.0, s * 0.18)), s * 0.04), ICING if k % 2 == 0 else Color("f6efe0"), s)
				_line(ci, c + Vector2(-w, y - s * 0.14), c + Vector2(w, y - s * 0.14), MOON_PURPLE, s * 0.025)
			if l >= 9:
				_shape(ci, _circle_pts(c + Vector2(0, -s * 0.36), s * 0.08, 14), MOON_PALE, s * 0.5)
			if l == 10:
				ci.draw_circle(c, s * 0.46, Color(0.8, 0.8, 1.0, 0.15), true, -1, true)
				_stars(ci, c + Vector2(0, s * 0.44), s, 3)
		_:
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.06), s * 0.3, 24, 0.5), Color("d9a45a"), s)
			for k in 5:
				var a := -PI / 2.0 + TAU * k / 5.0
				ci.draw_circle(c + Vector2(cos(a), sin(a) * 0.5) * s * 0.18 + Vector2(0, s * 0.02), s * 0.05, Color("e2554f") if k % 2 == 0 else MOON_PURPLE, true, -1, true)


static func _moonflower(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, _circle_pts(c, s * 0.12, 14, 1.4), Color("8a6a3a"), s)
		2:
			_line(ci, c + Vector2(0, s * 0.3), c + Vector2(0, -s * 0.04), Color("4f9a3a"), s * 0.05)
			_leaf(ci, c + Vector2(0, 0), Vector2(-0.8, -0.6), s * 0.22, Color("6cc24a"), s)
			_leaf(ci, c + Vector2(0, -s * 0.02), Vector2(0.8, -0.6), s * 0.22, Color("6cc24a"), s)
		3:
			_line(ci, c + Vector2(0, s * 0.34), c + Vector2(0, -s * 0.06), Color("4f9a3a"), s * 0.05)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.16), s * 0.12, 14, 1.5), PETAL, s)
		4:
			_line(ci, c + Vector2(0, s * 0.36), c + Vector2(0, 0), Color("4f9a3a"), s * 0.05)
			_bloom(ci, c + Vector2(0, -s * 0.08), s * 0.26, s)
		5:
			for k in 2:
				_line(ci, c + Vector2(-s * 0.12 + k * s * 0.24, s * 0.36), c + Vector2(-s * 0.14 + k * s * 0.28, -s * 0.02), Color("4f9a3a"), s * 0.04)
				_bloom(ci, c + Vector2(-s * 0.15 + k * s * 0.3, -s * 0.1 + k * s * 0.04), s * 0.18, s)
		6:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.06, s * 0.36), c + Vector2(s * 0.06, s * 0.36), c + Vector2(s * 0.14, s * 0.06), c + Vector2(-s * 0.14, s * 0.06)]), Color("f4efe6"), s)
			for k in 3:
				_bloom(ci, c + Vector2(-s * 0.18 + k * s * 0.18, -s * 0.12 + (k % 2) * s * 0.08), s * 0.15, s, [PETAL, Color("f6d6e6"), PETAL][k])
		7:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.2, s * 0.06), c + Vector2(s * 0.2, s * 0.06), c + Vector2(s * 0.16, s * 0.36), c + Vector2(-s * 0.16, s * 0.36)]), Color("c97a4a"), s)
			_bloom(ci, c + Vector2(0, -s * 0.12), s * 0.24, s)
		8:
			ci.draw_arc(c + Vector2(0, s * 0.3), s * 0.36, PI, TAU, 24, OUT, s * 0.1, true)
			ci.draw_arc(c + Vector2(0, s * 0.3), s * 0.36, PI, TAU, 24, Color("4f9a3a"), s * 0.07, true)
			for k in 5:
				var a := PI + PI * (k + 0.5) / 5.0
				_bloom(ci, c + Vector2(0, s * 0.3) + Vector2(cos(a), sin(a)) * s * 0.36, s * 0.1, s * 0.7)
		_:
			if l == 10:
				ci.draw_arc(c + Vector2(0, s * 0.04), s * 0.3, PI, TAU, 20, OUT, s * 0.1, true)
				ci.draw_arc(c + Vector2(0, s * 0.04), s * 0.3, PI, TAU, 20, Color("ffcf3a"), s * 0.07, true)
				for k in 5:
					var a := PI + PI * (k + 0.5) / 5.0
					_bloom(ci, c + Vector2(0, s * 0.04) + Vector2(cos(a), sin(a)) * s * 0.3, s * 0.11, s * 0.7)
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)
			else:
				_shape(ci, _circle_pts(c + Vector2(0, s * 0.18), s * 0.4, 24, 0.4), Color("4f9a3a"), s)
				for k in 4:
					_bloom(ci, c + Vector2(-s * 0.24 + k * s * 0.16, s * 0.04 - (k % 2) * s * 0.12), s * 0.12, s * 0.7)
				_shape(ci, _circle_pts(c + Vector2(s * 0.22, -s * 0.3), s * 0.1, 16), MOON_PALE, s * 0.5)


static func _honey(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, PackedVector2Array([c + Vector2(0, -s * 0.26), c + Vector2(s * 0.16, s * 0.06), c + Vector2(0, s * 0.22), c + Vector2(-s * 0.16, s * 0.06)]), HONEY, s)
			_hl(ci, c + Vector2(-s * 0.04, 0), s * 0.04)
		2, 6:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.22, -s * 0.18), Vector2(s * 0.44, s * 0.5)), s * 0.12), HONEY, s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.24, -s * 0.3), Vector2(s * 0.48, s * 0.12)), s * 0.03), Color("e2554f") if l == 2 else Color("8a5a3a"), s * 0.7)
			if l == 6:
				_line(ci, c + Vector2(s * 0.08, -s * 0.3), c + Vector2(s * 0.26, -s * 0.46), Color("a77b4f"), s * 0.04)
		3:
			_line(ci, c + Vector2(-s * 0.3, s * 0.3), c + Vector2(s * 0.1, -s * 0.1), Color("a77b4f"), s * 0.05)
			for k in 3:
				_shape(ci, _circle_pts(c + Vector2(s * 0.14, -s * 0.14) + Vector2(k - 1, 1 - k) * s * 0.06, s * 0.08, 14), HONEY, s * 0.5)
		4:
			for k in 7:
				var o := Vector2.ZERO if k == 0 else Vector2(cos(TAU * k / 6.0), sin(TAU * k / 6.0)) * s * 0.21
				var hx := PackedVector2Array()
				for j in 6:
					hx.append(c + o + Vector2(cos(TAU * j / 6.0 + PI / 6.0), sin(TAU * j / 6.0 + PI / 6.0)) * s * 0.11)
				_shape(ci, hx, HONEY, s * 0.4)
		5:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.3, -s * 0.06), Vector2(s * 0.6, s * 0.3)), s * 0.06), Color("d9a45a"), s)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.06), s * 0.3, 20, 0.3), HONEY, s * 0.7)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.16 + k * s * 0.16, -s * 0.02), c + Vector2(-s * 0.16 + k * s * 0.16, s * 0.08 + (k % 2) * s * 0.06), HONEY, s * 0.04)
		7, 9:
			var tiers := 4
			for k in tiers:
				var w := s * (0.22 + 0.06 * (2 - absi(k - 1)))
				_shape(ci, _circle_pts(c + Vector2(0, s * 0.24 - k * s * 0.15), w, 20, 0.4), Color("e6b85a") if l == 7 else Color("ffcf3a"), s * 0.8)
			ci.draw_circle(c + Vector2(0, s * 0.16), s * 0.05, OUT, true, -1, true)
		8:
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.26, -s * 0.32), Vector2(s * 0.52, s * 0.66)), s * 0.12), Color("a77b4f"), s)
			for k in 3:
				_line(ci, c + Vector2(-s * 0.26, -s * 0.16 + k * s * 0.16), c + Vector2(s * 0.26, -s * 0.16 + k * s * 0.16), Color("6b4a2b"), s * 0.03)
			_shape(ci, _circle_pts(c, s * 0.1, 14), HONEY, s * 0.5)
		_:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.36, s * 0.3), c + Vector2(s * 0.36, s * 0.3), c + Vector2(s * 0.3, -s * 0.06), c + Vector2(0, -s * 0.36), c + Vector2(-s * 0.3, -s * 0.06)]), Color("ffcf3a"), s)
			for k in 3:
				_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.24 + k * s * 0.18, s * 0.04), Vector2(s * 0.1, s * 0.2)), s * 0.04), Color("8a5a3a"), s * 0.4)
			_stars(ci, c + Vector2(0, s * 0.44), s, 3)


static func _paper_lantern(ci: CanvasItem, c: Vector2, r: float, s: float, col := PAPER_RED) -> void:
	_line(ci, c + Vector2(0, -r * 1.3), c + Vector2(0, -r), OUT, s * 0.02)
	_shape(ci, _circle_pts(c, r, 20, 1.15), col, s * 0.6)
	for k in 2:
		ci.draw_arc(c, r * (0.45 + k * 0.3), PI * 0.5, PI * 1.5, 10, col.darkened(0.25), s * 0.012, true)
	ci.draw_circle(c, r * 0.35, Color(1.0, 0.9, 0.5, 0.6), true, -1, true)
	ci.draw_rect(Rect2(c + Vector2(-r * 0.3, r * 1.05), Vector2(r * 0.6, r * 0.18)), Color("ffcf3a"))


static func _paperlantern(ci: CanvasItem, c: Vector2, s: float, l: int) -> void:
	match l:
		1:
			_shape(ci, _rect_pts(Rect2(c - Vector2(s * 0.22, s * 0.28), Vector2(s * 0.44, s * 0.56)), s * 0.02), Color("fbfaf4"), s)
		2:
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.3, s * 0.2), c + Vector2(0, -s * 0.3), c + Vector2(s * 0.3, s * 0.2), c + Vector2(0, s * 0.04)]), Color("f6d6e6"), s)
		3:
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2.0 + TAU * i / 10.0
				pts.append(c + Vector2(cos(a), sin(a)) * (s * 0.3 if i % 2 == 0 else s * 0.13))
			_shape(ci, pts, Color("ffe08a"), s)
		4:
			_paper_lantern(ci, c + Vector2(0, s * 0.04), s * 0.24, s)
		5:
			_paper_lantern(ci, c + Vector2(-s * 0.17, s * 0.06), s * 0.17, s)
			_paper_lantern(ci, c + Vector2(s * 0.17, -s * 0.02), s * 0.17, s, Color("f2b632"))
		6:
			var p := PackedVector2Array()
			for i in 9:
				p.append(c + Vector2(-s * 0.42 + i * s * 0.105, -s * 0.28 + sin(i * PI / 8.0) * s * 0.12))
			ci.draw_polyline(p, ROPE_DARK, s * 0.02, true)
			for i in 3:
				_paper_lantern(ci, (p[i * 3 + 1] as Vector2) + Vector2(0, s * 0.18), s * 0.1, s * 0.7, [PAPER_RED, Color("f2b632"), MOON_PURPLE][i])
		7:
			_paper_lantern(ci, c + Vector2(0, s * 0.04), s * 0.28, s, MOON_PALE)
		8:
			_line(ci, c + Vector2(0, s * 0.4), c + Vector2(0, -s * 0.1), Color("6b4a2b"), s * 0.06)
			for k in 3:
				_paper_lantern(ci, c + Vector2(-s * 0.24 + k * s * 0.24, -s * 0.1 + (k % 2) * s * 0.14), s * 0.1, s * 0.7, [PAPER_RED, Color("f2b632"), MOON_PURPLE][k])
		_:
			if l == 10:
				ci.draw_circle(c, s * 0.42, Color(0.9, 0.9, 1.0, 0.2), true, -1, true)
				_shape(ci, _circle_pts(c, s * 0.32, 28), MOON_PALE, s)
				_shape(ci, _circle_pts(c + Vector2(s * 0.12, -s * 0.06), s * 0.26, 24), Color("c9cff5"), s * 0.4, Color(0, 0, 0, 0))
				_stars(ci, c + Vector2(0, s * 0.42), s, 3)
			else:
				ci.draw_circle(c, s * 0.38, Color(1.0, 0.8, 0.4, 0.2), true, -1, true)
				_shape(ci, PackedVector2Array([c + Vector2(-s * 0.2, -s * 0.3), c + Vector2(s * 0.2, -s * 0.3), c + Vector2(s * 0.26, s * 0.22), c + Vector2(-s * 0.26, s * 0.22)]), Color("fbe3b0"), s)
				ci.draw_circle(c + Vector2(0, s * 0.12), s * 0.07, Color("ffb52e"), true, -1, true)


static func _bakery_generator(ci: CanvasItem, c: Vector2, s: float, chain: String, l: int) -> void:
	_shape(ci, _circle_pts(c + Vector2(0, s * 0.36), s * 0.36, 24, 0.18), Color(0, 0, 0, 0.18), s, Color(0, 0, 0, 0))
	match chain:
		"gen_sweet":
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.36, s * 0.32), c + Vector2(s * 0.36, s * 0.32), c + Vector2(s * 0.36, -s * 0.06), c + Vector2(0, -s * 0.34), c + Vector2(-s * 0.36, -s * 0.06)]), Color("8a7fb0"), s)
			_shape(ci, _circle_pts(c + Vector2(0, s * 0.12), s * 0.16, 18, 0.9), Color("ffb52e"), s * 0.6)
			_shape(ci, _circle_pts(c + Vector2(0, -s * 0.12), s * 0.08, 14), MOON_PALE, s * 0.4)
		"gen_moonflower":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.38, s * 0.08), Vector2(s * 0.76, s * 0.26)), s * 0.05), Color("8a5a3a"), s)
			for k in 3:
				_bloom(ci, c + Vector2(-s * 0.22 + k * s * 0.22, -s * 0.04), s * 0.14, s * 0.7)
		"gen_honey":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.3, -s * 0.24), Vector2(s * 0.6, s * 0.56)), s * 0.04), Color("d9a45a"), s)
			_shape(ci, PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.22), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.36, -s * 0.22)]), Color("8a5a3a"), s)
			ci.draw_circle(c + Vector2(0, s * 0.06), s * 0.06, OUT, true, -1, true)
			for k in 2:
				ci.draw_circle(c + Vector2(s * 0.3 + k * s * 0.08, -s * 0.3 + k * s * 0.1), s * 0.035, HONEY, true, -1, true)
		"gen_paperlantern":
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.34, s * 0.02), Vector2(s * 0.68, s * 0.3)), s * 0.04), Color("6b6f8a"), s)
			_shape(ci, _rect_pts(Rect2(c + Vector2(-s * 0.26, -s * 0.24), Vector2(s * 0.52, s * 0.26)), s * 0.02), Color("fbfaf4"), s * 0.6)
			_line(ci, c + Vector2(-s * 0.3, -s * 0.28), c + Vector2(s * 0.3, -s * 0.28), Color("4a4f6a"), s * 0.06)
	_stars(ci, c + Vector2(0, s * 0.4), s, l)


## The wooden crate over boxed board items (drawn as "crate:1").
static func _crate_box(ci: CanvasItem, c: Vector2, s: float) -> void:
	var wood := Color("c48a52")
	var r := Rect2(c - Vector2(s * 0.44, s * 0.4), Vector2(s * 0.88, s * 0.84))
	_shape(ci, _rect_pts(r, s * 0.08), wood, s)
	for k in 3:
		var y := r.position.y + r.size.y * (0.22 + 0.29 * k)
		ci.draw_rect(Rect2(Vector2(r.position.x + s * 0.05, y), Vector2(r.size.x - s * 0.1, s * 0.035)), Color(0.45, 0.28, 0.14, 0.55))
	_shape(ci, _rect_pts(Rect2(r.position + Vector2(0, -s * 0.02), Vector2(r.size.x, s * 0.14)), s * 0.05), wood.lightened(0.12), s * 0.7)
	_line(ci, r.position + Vector2(s * 0.1, s * 0.16), r.end - Vector2(s * 0.1, s * 0.08), Color(0.45, 0.28, 0.14, 0.6), s * 0.06)
	for p in [r.position + Vector2(s * 0.09, s * 0.07), Vector2(r.end.x - s * 0.09, r.position.y + s * 0.07),
			Vector2(r.position.x + s * 0.09, r.end.y - s * 0.09), r.end - Vector2(s * 0.09, s * 0.09)]:
		ci.draw_circle(p, s * 0.03, Color("8c949c"), true, -1, true)


## The experience star on order rewards (drawn as "star:1").
static func _xp_star(ci: CanvasItem, c: Vector2, s: float) -> void:
	var p := PackedVector2Array()
	for k in 10:
		var a := -PI * 0.5 + TAU * k / 10.0
		p.append(c + Vector2(cos(a), sin(a)) * s * (0.42 if k % 2 == 0 else 0.2))
	_shape(ci, p, Color("ffc93a"), s)
	_hl(ci, c + Vector2(-s * 0.08, -s * 0.1), s * 0.07, 0.6)


## A single upright gold coin with a lantern stamp (currency pill and rewards).
static func _gold_coin(ci: CanvasItem, c: Vector2, s: float) -> void:
	var r := s * 0.36
	_shape(ci, _circle_pts(c + Vector2(r * 0.12, r * 0.08), r, 32, 1.0), Color("c98512"), s)
	_shape(ci, _circle_pts(c, r, 32, 1.0), Color("ffc93a"), s)
	_shape(ci, _circle_pts(c, r * 0.74, 28, 1.0), Color("ffb420"), s * 0.5, Color("e09a18"))
	var l := r * 0.3
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -l * 1.4), c + Vector2(l, -l * 0.3), c + Vector2(l * 0.8, l), c + Vector2(-l * 0.8, l), c + Vector2(-l, -l * 0.3)]), Color("ffe48a"))
	_hl(ci, c + Vector2(-r * 0.42, -r * 0.42), r * 0.18, 0.7)
