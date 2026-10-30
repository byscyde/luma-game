class_name Painter
extends RefCounted
## Procedural, resolution-independent drawing of LUMA's diorama elements.
## Everything is drawn with CanvasItem primitives so the art scales to any
## device and ships without external asset dependencies.
## `g` is a continuous growth/restoration value so transitions can animate.

const AA := true


static func hash01(n: int) -> float:
	var x := (n * 374761393 + 668265263) & 0x7fffffff
	x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
	return float(x % 10000) / 10000.0


static func ellipse_points(c: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	ci.draw_colored_polygon(ellipse_points(c, rx, ry), col)


static func shadow(ci: CanvasItem, c: Vector2, rx: float, alpha: float = 0.22) -> void:
	ellipse(ci, c, rx, rx * 0.38, Color(0.08, 0.12, 0.06, alpha))


static func circle(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r > 0.2:
		ci.draw_circle(c, r, col, true, -1.0, AA)


static func smooth(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


# ---------------------------------------------------------------- vegetation

## Trees: kind in tree, willow, pine, fruit_tree, heart_tree.
## g: 0 dry, 1 young, 2 mature. h: full mature height in pixels.
static func tree(ci: CanvasItem, base: Vector2, h: float, g: float, kind: String, t: float, seed_n: int = 0) -> void:
	var life := clampf(g, 0.0, 1.0)
	var mature := clampf(g - 1.0, 0.0, 1.0)
	var sway := sin(t * 1.3 + seed_n) * h * 0.012 * life
	shadow(ci, base + Vector2(h * 0.04, 0), h * (0.18 + 0.16 * life + 0.08 * mature))
	var trunk_h := h * (0.34 + 0.12 * life + 0.08 * mature)
	var tw := h * (0.045 + 0.03 * life + 0.025 * mature)
	if kind == "pine":
		trunk_h *= 0.6
	var top := base + Vector2(sway * 0.5, -trunk_h)
	var bark := Palette.DRY_DARK.lerp(Palette.BARK, life)
	var bark_dark := Palette.DRY_DARK.darkened(0.25).lerp(Palette.BARK_DARK, life)
	ci.draw_colored_polygon(PackedVector2Array([
		base + Vector2(-tw, 0), base + Vector2(tw, 0), top + Vector2(tw * 0.45, 0), top + Vector2(-tw * 0.45, 0)]), bark)
	ci.draw_colored_polygon(PackedVector2Array([
		base + Vector2(tw * 0.15, 0), base + Vector2(tw, 0), top + Vector2(tw * 0.45, 0), top + Vector2(tw * 0.05, 0)]), bark_dark)
	# bare branches fade out as leaves arrive
	var bare := 1.0 - smooth(0.35, 1.0, g)
	if bare > 0.01:
		var bc := Color(bark, bare)
		var bw := maxf(1.5, tw * 0.5)
		ci.draw_line(top, top + Vector2(-h * 0.16, -h * 0.14), bc, bw, AA)
		ci.draw_line(top, top + Vector2(h * 0.14, -h * 0.17), bc, bw, AA)
		ci.draw_line(top + Vector2(0, h * 0.08), top + Vector2(h * 0.13, -h * 0.02), bc, bw * 0.8, AA)
		ci.draw_line(top + Vector2(-h * 0.08, -h * 0.07), top + Vector2(-h * 0.12, -h * 0.2), bc, bw * 0.6, AA)
	var ls := smooth(0.12, 1.0, g) * (0.62 + 0.38 * mature)
	if ls <= 0.01:
		return
	var u := h * ls
	var c := top + Vector2(sway, -u * 0.12)
	var dark := Palette.LEAF_DEEP
	var mid := Palette.LEAF_DARK
	var lite := Palette.LEAF
	var hi := Palette.LEAF_LIGHT
	match kind:
		"pine":
			dark = Color("2d5f45"); mid = Color("3c7a52"); lite = Color("559a63"); hi = Color("7fbf7a")
			for i in 3:
				var w := u * (0.36 - i * 0.08)
				var y := c.y + u * 0.1 - i * u * 0.22
				var tip := Vector2(c.x + sway * (i + 1) * 0.4, y - u * 0.36)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - w, y), Vector2(c.x + w, y), tip]), dark if i == 0 else mid)
				ci.draw_colored_polygon(PackedVector2Array([Vector2(c.x - w * 0.15, y), Vector2(c.x + w, y), tip]), lite if i < 2 else hi)
			return
		"willow":
			dark = Color("4f8f4f"); mid = Color("6aa85a"); lite = Color("8dc46e"); hi = Color("b8e08e")
			circle(ci, c + Vector2(0, -u * 0.05), u * 0.34, mid)
			circle(ci, c + Vector2(-u * 0.12, -u * 0.14), u * 0.22, lite)
			circle(ci, c + Vector2(u * 0.12, -u * 0.16), u * 0.18, hi)
			for i in 9:
				var x := -u * 0.32 + i * u * 0.08
				var len := u * (0.32 + 0.12 * hash01(seed_n * 31 + i))
				var sw := sin(t * 1.6 + i * 0.7 + seed_n) * u * 0.03
				var start := c + Vector2(x, -u * 0.02)
				ci.draw_line(start, start + Vector2(sw, len), dark if i % 2 == 0 else mid, maxf(2.0, u * 0.035), AA)
			return
		"heart_tree":
			dark = Color("3d7f5a"); mid = Color("4f9a68"); lite = Color("72b97a"); hi = Color("a6dda0")
			if mature > 0.0:
				circle(ci, c + Vector2(0, -u * 0.12), u * (0.62 + 0.04 * sin(t * 2.0)), Color(Palette.GOLD, 0.12 * mature))
	# rounded canopy built from overlapping blobs, lit from upper-left
	var blobs := [
		[0.0, 0.02, 0.34, dark], [-0.24, 0.06, 0.24, dark], [0.25, 0.04, 0.25, mid],
		[-0.1, -0.16, 0.3, mid], [0.13, -0.2, 0.25, lite], [-0.18, -0.09, 0.18, lite],
		[-0.05, -0.3, 0.17, hi], [0.08, -0.06, 0.16, lite],
	]
	for b in blobs:
		circle(ci, c + Vector2(b[0] * u, b[1] * u), b[2] * u, b[3])
	if mature > 0.25:
		var accent := Color.WHITE
		match kind:
			"fruit_tree": accent = Color("e85b4a") if seed_n % 2 == 0 else Color("f3c74a")
			"heart_tree": accent = Palette.GOLD
			_: accent = Color("fff3f0")
		for i in 7:
			var a := hash01(seed_n * 17 + i) * TAU
			var r := (0.12 + 0.2 * hash01(seed_n * 7 + i * 3)) * u
			var p := c + Vector2(cos(a) * r, sin(a) * r * 0.8 - u * 0.1)
			circle(ci, p, u * (0.035 if kind != "heart_tree" else 0.045) * mature, accent)


static func flower(ci: CanvasItem, p: Vector2, s: float, col: Color, bloom: float) -> void:
	ci.draw_line(p, p + Vector2(0, -s * 1.4), Palette.LEAF_DARK, maxf(1.5, s * 0.22), AA)
	var head := p + Vector2(0, -s * 1.4)
	if bloom < 0.05:
		circle(ci, head, s * 0.28, Palette.LEAF_DARK)
		return
	var r := s * 0.55 * bloom
	for i in 5:
		var a := TAU * i / 5.0
		circle(ci, head + Vector2(cos(a), sin(a)) * r * 0.75, r * 0.6, col)
	circle(ci, head, r * 0.45, Palette.GOLD)


## A patch of flowers and grass tufts. g 0 = dry, 1 = green, 2 = in bloom.
static func meadow(ci: CanvasItem, c: Vector2, radius: float, g: float, t: float, seed_n: int, palette_cols: Array = []) -> void:
	var cols := palette_cols if not palette_cols.is_empty() else [Palette.CORAL, Color.WHITE, Palette.LILAC, Palette.GOLD]
	var green := clampf(g, 0.0, 1.0)
	var bloom := clampf(g - 1.0, 0.0, 1.0)
	var n := 12
	for i in n:
		var a := hash01(seed_n * 13 + i) * TAU
		var rr := sqrt(hash01(seed_n * 29 + i * 5)) * radius
		var p := c + Vector2(cos(a) * rr, sin(a) * rr * 0.5)
		var tuft := Palette.DRY.lerp(Palette.LEAF, green)
		var sw := sin(t * 2.0 + i) * radius * 0.02
		ci.draw_line(p, p + Vector2(-radius * 0.05 + sw, -radius * 0.12), tuft, 2.0, AA)
		ci.draw_line(p, p + Vector2(radius * 0.04 + sw, -radius * 0.14), tuft.darkened(0.15), 2.0, AA)
		if i % 2 == 0 and green > 0.3:
			flower(ci, p, radius * 0.09, cols[i % cols.size()], bloom)


static func reeds(ci: CanvasItem, c: Vector2, s: float, g: float, t: float) -> void:
	var life := clampf(g, 0.0, 1.0)
	for i in 7:
		var x := (i - 3) * s * 0.12 + hash01(i * 5) * s * 0.05
		var hgt := s * (0.5 + 0.35 * hash01(i * 9)) * (0.4 + 0.6 * life)
		var sw := sin(t * 1.8 + i) * s * 0.03 * life
		var col := Palette.DRY.lerp(Color("5e9a4a"), life)
		ci.draw_line(c + Vector2(x, 0), c + Vector2(x + sw, -hgt), col, maxf(2.0, s * 0.03), AA)
		if g > 1.2 and i % 2 == 0:
			var top := c + Vector2(x + sw, -hgt)
			ci.draw_line(top + Vector2(0, s * 0.04), top + Vector2(0, s * 0.14), Color("7a4e2c"), maxf(3.0, s * 0.06), AA)


static func rock(ci: CanvasItem, c: Vector2, s: float, seed_n: int, moss: bool = true) -> void:
	shadow(ci, c + Vector2(0, s * 0.05), s * 0.55, 0.25)
	var pts := PackedVector2Array()
	for i in 9:
		var a := PI + PI * i / 8.0
		var r := s * (0.42 + 0.12 * hash01(seed_n * 11 + i))
		pts.append(c + Vector2(cos(a) * r * 1.15, sin(a) * r * 0.95))
	pts.append(c + Vector2(s * 0.45, s * 0.1))
	pts.append(c + Vector2(-s * 0.48, s * 0.1))
	ci.draw_colored_polygon(pts, Palette.ROCK)
	# lit facet
	var hi := PackedVector2Array([c + Vector2(-s * 0.36, -s * 0.05), c + Vector2(-s * 0.12, -s * 0.38),
		c + Vector2(s * 0.12, -s * 0.34), c + Vector2(-s * 0.02, -s * 0.04)])
	ci.draw_colored_polygon(hi, Palette.ROCK.lightened(0.22))
	var sh := PackedVector2Array([c + Vector2(s * 0.1, -s * 0.02), c + Vector2(s * 0.42, -s * 0.18),
		c + Vector2(s * 0.45, s * 0.1), c + Vector2(s * 0.0, s * 0.1)])
	ci.draw_colored_polygon(sh, Palette.ROCK_DARK)
	if moss:
		circle(ci, c + Vector2(-s * 0.18, -s * 0.33), s * 0.12, Palette.MOSS)
		circle(ci, c + Vector2(-s * 0.04, -s * 0.38), s * 0.09, Palette.MOSS.lightened(0.15))


# ---------------------------------------------------------------- water

static func pond(ci: CanvasItem, c: Vector2, rx: float, g: float, t: float, seed_n: int) -> void:
	var ry := rx * 0.5
	ellipse(ci, c, rx * 1.08, ry * 1.12, Palette.SAND_SHADE.darkened(0.1))
	ellipse(ci, c, rx, ry, Palette.DRY_DARK.darkened(0.1))
	var fill := clampf(g, 0.0, 1.0)
	if fill > 0.01:
		ellipse(ci, c + Vector2(0, ry * 0.05), rx * (0.4 + 0.6 * fill), ry * (0.4 + 0.6 * fill), Palette.WATER_DEEP)
		ellipse(ci, c + Vector2(-rx * 0.08, -ry * 0.05), rx * (0.3 + 0.55 * fill), ry * (0.3 + 0.5 * fill), Palette.WATER)
		for i in 2:
			var ph := fmod(t * 0.35 + i * 0.5, 1.0)
			var rr := rx * (0.2 + 0.6 * ph) * fill
			var a := (1.0 - ph) * 0.45
			ci.draw_arc(c + Vector2(rx * 0.15 * (i * 2 - 1), 0), rr, PI * 1.1, PI * 1.9, 16, Color(Palette.WATER_LIGHT, a), 2.0, AA)
	if g > 1.05:
		var lil := clampf(g - 1.0, 0.0, 1.0)
		for i in 4:
			var a := hash01(seed_n * 3 + i) * TAU
			var p := c + Vector2(cos(a) * rx * 0.55, sin(a) * ry * 0.55)
			ellipse(ci, p, rx * 0.12 * lil, ry * 0.14 * lil, Color("4f9a58"))
			if i % 2 == 0:
				circle(ci, p + Vector2(0, -ry * 0.06), rx * 0.04 * lil, Palette.CORAL.lightened(0.3))


static func stream(ci: CanvasItem, pts: PackedVector2Array, width: float, g: float, t: float) -> void:
	if pts.size() < 2 or width < 1.0:
		return
	ci.draw_polyline(pts, Palette.DRY_DARK, width * 1.25, AA)
	ci.draw_polyline(pts, Palette.DRY_DARK.darkened(0.15), width * 0.9, AA)
	var f := clampf(g, 0.0, 1.0)
	if f <= 0.01:
		return
	# water advances along the bed as f grows
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var reach := total * f
	var wet := PackedVector2Array([pts[0]])
	var acc := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg >= reach:
			wet.append(pts[i].lerp(pts[i + 1], (reach - acc) / maxf(seg, 0.001)))
			break
		wet.append(pts[i + 1])
		acc += seg
	ci.draw_polyline(wet, Palette.WATER_DEEP, width, AA)
	ci.draw_polyline(wet, Palette.WATER, width * 0.66, AA)
	# moving highlights
	var dash := width * 1.6
	var off := fmod(t * width * 2.2, dash * 2.0)
	acc = 0.0
	for i in wet.size() - 1:
		var a := wet[i]
		var b := wet[i + 1]
		var seg := a.distance_to(b)
		var d := -off
		while d < seg:
			var s0 := maxf(d, 0.0)
			var s1 := minf(d + dash * 0.5, seg)
			if s1 > s0:
				ci.draw_line(a.lerp(b, s0 / seg), a.lerp(b, s1 / seg), Color(Palette.WATER_LIGHT, 0.7), maxf(1.5, width * 0.18), AA)
			d += dash
		acc += seg


static func waterfall(ci: CanvasItem, top: Vector2, bottom: Vector2, width: float, g: float, t: float) -> void:
	var f := clampf(g, 0.0, 1.0)
	if f <= 0.01:
		# dry stain on the cliff
		ci.draw_rect(Rect2(top.x - width * 0.4, top.y, width * 0.8, bottom.y - top.y), Color(Palette.STONE_DEEP, 0.35))
		return
	var len := (bottom.y - top.y) * f
	ci.draw_rect(Rect2(top.x - width * 0.5, top.y, width, len), Palette.WATER_DEEP)
	ci.draw_rect(Rect2(top.x - width * 0.32, top.y, width * 0.64, len), Palette.WATER)
	for i in 4:
		var x := top.x - width * 0.35 + i * width * 0.23
		var ph := fmod(t * 1.4 + i * 0.27, 1.0)
		var y0 := top.y + ph * len
		ci.draw_line(Vector2(x, y0), Vector2(x, minf(y0 + len * 0.25, top.y + len)), Color(Palette.WATER_LIGHT, 0.8), maxf(1.5, width * 0.08), AA)
	if f > 0.95:
		for i in 6:
			var a := hash01(i * 7) * PI
			var r := width * (0.3 + 0.25 * sin(t * 4.0 + i))
			circle(ci, bottom + Vector2(cos(a) * width * 0.6, -absf(sin(a)) * width * 0.15), r * 0.4, Color(Palette.FOAM, 0.85))


static func spring(ci: CanvasItem, c: Vector2, s: float, g: float, t: float) -> void:
	ellipse(ci, c, s * 0.52, s * 0.28, Palette.STONE_DARK)
	ellipse(ci, c + Vector2(0, -s * 0.04), s * 0.46, s * 0.23, Palette.STONE)
	var f := clampf(g, 0.0, 1.0)
	ellipse(ci, c + Vector2(0, -s * 0.03), s * 0.36, s * 0.17, Palette.DRY_DARK.lerp(Palette.WATER_DEEP, f))
	if f > 0.01:
		ellipse(ci, c + Vector2(-s * 0.03, -s * 0.05), s * 0.28 * f, s * 0.12 * f, Palette.WATER)
		for i in 3:
			var ph := fmod(t * 0.8 + i / 3.0, 1.0)
			circle(ci, c + Vector2((i - 1) * s * 0.1, -s * 0.05 - ph * s * 0.25), s * 0.03 * (1.0 - ph), Color(Palette.WATER_LIGHT, 1.0 - ph))
		circle(ci, c + Vector2(0, -s * 0.06), s * 0.08 * (1.0 + 0.15 * sin(t * 3.0)), Color(Palette.WATER_LIGHT, 0.6))


# ---------------------------------------------------------------- creatures

static func rabbit(ci: CanvasItem, p: Vector2, s: float, t: float, seed_n: int) -> void:
	var hop := absf(sin(t * 2.2 + seed_n)) * s * 0.18
	var q := p + Vector2(0, -hop)
	shadow(ci, p, s * 0.35, 0.18)
	var fur := Color("e9e1d3") if seed_n % 2 == 0 else Color("b59a7a")
	ellipse(ci, q + Vector2(0, -s * 0.2), s * 0.32, s * 0.22, fur)
	circle(ci, q + Vector2(s * 0.25, -s * 0.38), s * 0.15, fur)
	ellipse(ci, q + Vector2(s * 0.2, -s * 0.62), s * 0.05, s * 0.16, fur)
	ellipse(ci, q + Vector2(s * 0.3, -s * 0.6), s * 0.05, s * 0.15, fur.darkened(0.08))
	circle(ci, q + Vector2(-s * 0.3, -s * 0.24), s * 0.08, Color.WHITE)
	circle(ci, q + Vector2(s * 0.3, -s * 0.4), s * 0.03, Palette.TEXT)


static func deer(ci: CanvasItem, p: Vector2, s: float, t: float) -> void:
	var body := Color("b0784a")
	shadow(ci, p, s * 0.5, 0.2)
	for x in [-0.28, -0.16, 0.18, 0.3]:
		ci.draw_line(p + Vector2(s * x, -s * 0.42), p + Vector2(s * x, 0), body.darkened(0.25), maxf(2.0, s * 0.06), AA)
	ellipse(ci, p + Vector2(0, -s * 0.5), s * 0.42, s * 0.17, body)
	var nod := sin(t * 0.9) * s * 0.06
	var head := p + Vector2(s * 0.45, -s * 0.82 + nod)
	ci.draw_line(p + Vector2(s * 0.3, -s * 0.55), head, body, maxf(3.0, s * 0.12), AA)
	ellipse(ci, head + Vector2(s * 0.06, 0), s * 0.12, s * 0.08, body)
	ci.draw_line(head, head + Vector2(-s * 0.06, -s * 0.22), Color("6a4a2e"), 2.0, AA)
	ci.draw_line(head + Vector2(-s * 0.04, -s * 0.14), head + Vector2(-s * 0.14, -s * 0.22), Color("6a4a2e"), 2.0, AA)
	for i in 3:
		circle(ci, p + Vector2(-s * 0.1 + i * s * 0.12, -s * 0.55), s * 0.025, Color(1, 1, 1, 0.8))


static func duck(ci: CanvasItem, p: Vector2, s: float, t: float, seed_n: int) -> void:
	var q := p + Vector2(sin(t * 0.5 + seed_n) * s * 0.6, sin(t * 2.0 + seed_n) * s * 0.03)
	ellipse(ci, q, s * 0.3, s * 0.15, Color.WHITE)
	circle(ci, q + Vector2(s * 0.22, -s * 0.2), s * 0.11, Color("2f7a4f") if seed_n % 2 == 0 else Color.WHITE)
	ci.draw_colored_polygon(PackedVector2Array([q + Vector2(s * 0.3, -s * 0.22), q + Vector2(s * 0.44, -s * 0.18), q + Vector2(s * 0.3, -s * 0.15)]), Color("f0a23b"))


static func birds(ci: CanvasItem, c: Vector2, s: float, t: float, count: int = 3) -> void:
	for i in count:
		var a := t * 0.6 + i * TAU / count
		var p := c + Vector2(cos(a) * s * 1.2, sin(a) * s * 0.4 - s * 0.6)
		var flap := sin(t * 8.0 + i) * s * 0.08
		var w := s * 0.16
		ci.draw_polyline(PackedVector2Array([p + Vector2(-w, -flap), p, p + Vector2(w, -flap)]), Color("3a4a4a"), 2.0, AA)


static func koi(ci: CanvasItem, c: Vector2, rx: float, t: float) -> void:
	var a := t * 0.7
	var p := c + Vector2(cos(a) * rx * 0.5, sin(a) * rx * 0.22)
	var dir := Vector2(-sin(a), cos(a) * 0.45).normalized()
	var side := Vector2(-dir.y, dir.x)
	var s := rx * 0.14
	var body := PackedVector2Array([p + dir * s, p + side * s * 0.35, p - dir * s * 0.8, p - side * s * 0.35])
	ci.draw_colored_polygon(body, Color("f5a524"))
	ci.draw_colored_polygon(PackedVector2Array([p - dir * s * 0.7, p - dir * s * 1.2 + side * s * 0.3, p - dir * s * 1.2 - side * s * 0.3]), Color("f7c35c"))


# ---------------------------------------------------------------- structures

static func iso_box(ci: CanvasItem, base: Vector2, w: float, d: float, h: float, top_col: Color, left_col: Color, right_col: Color) -> void:
	# base = bottom-centre of the front corner
	var l := Vector2(-w, -w * 0.5)
	var r := Vector2(d, -d * 0.5)
	var up := Vector2(0, -h)
	ci.draw_colored_polygon(PackedVector2Array([base, base + l, base + l + up, base + up]), left_col)
	ci.draw_colored_polygon(PackedVector2Array([base, base + r, base + r + up, base + up]), right_col)
	ci.draw_colored_polygon(PackedVector2Array([base + up, base + l + up, base + l + r + up, base + r + up]), top_col)


static func mill(ci: CanvasItem, base: Vector2, s: float, g: float, t: float) -> void:
	shadow(ci, base + Vector2(0, -s * 0.05), s * 0.75, 0.25)
	var repaired := clampf(g, 0.0, 1.0)
	var full := clampf(g - 1.0, 0.0, 1.0)
	var wall := Color("d9c7a3").lerp(Color("f1e4c6"), repaired)
	var wall_l := wall.darkened(0.12)
	var wall_r := wall.darkened(0.25)
	var wh := s * (0.5 + 0.2 * repaired)
	iso_box(ci, base, s * 0.42, s * 0.42, wh, wall, wall_l, wall_r)
	if repaired < 0.5:
		# broken wall gap
		ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-s * 0.3, -wh - s * 0.15), base + Vector2(-s * 0.1, -wh - s * 0.05),
			base + Vector2(-s * 0.18, -wh + s * 0.12)]), Palette.STONE_DEEP)
	# door + window
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(s * 0.12, -s * 0.06), base + Vector2(s * 0.24, -s * 0.12),
		base + Vector2(s * 0.24, -s * 0.34), base + Vector2(s * 0.12, -s * 0.28)]), Color("6b4a2f"))
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-s * 0.3, -s * 0.3), base + Vector2(-s * 0.16, -s * 0.23),
		base + Vector2(-s * 0.16, -s * 0.38), base + Vector2(-s * 0.3, -s * 0.45)]), Color("5b8fa3") if repaired > 0.5 else Color("3c3a35"))
	# roof
	var roof := smooth(0.3, 1.0, g)
	if roof > 0.01:
		var top := base + Vector2(0, -wh)
		var peak_h := s * 0.38 * roof
		var l := Vector2(-s * 0.48, -s * 0.24)
		var r := Vector2(s * 0.48, -s * 0.24)
		var ridge := Vector2(0, -peak_h)
		var roof_c := Color("b5583c").lerp(Color("c96a43"), full)
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(0, s * 0.04), top + l, top + l * 0.5 + r * 0.5 + ridge + l * 0.5, top + ridge]), roof_c.darkened(0.12))
		ci.draw_colored_polygon(PackedVector2Array([top + Vector2(0, s * 0.04), top + ridge, top + r * 0.5 + ridge + l * 0.5 + r * 0.5, top + r]), roof_c)
	# water wheel
	var wc := base + Vector2(s * 0.52, -s * 0.25)
	var wr := s * 0.28
	var ang := t * 1.2 * full
	ci.draw_arc(wc, wr, 0, TAU, 24, Color("7b5636"), maxf(3.0, s * 0.05), AA)
	for i in 8:
		var a := ang + TAU * i / 8.0
		if repaired < 0.5 and i % 3 == 0:
			continue
		ci.draw_line(wc, wc + Vector2(cos(a), sin(a)) * wr, Color("8d6640"), maxf(2.0, s * 0.03), AA)
	circle(ci, wc, s * 0.05, Color("5a3d25"))
	if full > 0.5:
		for i in 3:
			var ph := fmod(t * 1.5 + i * 0.33, 1.0)
			circle(ci, wc + Vector2(wr * 0.6, wr * (0.2 + ph)), s * 0.03 * (1.0 - ph), Color(Palette.WATER_LIGHT, 0.8 * (1.0 - ph)))


static func terrace(ci: CanvasItem, c: Vector2, s: float, g: float, t: float) -> void:
	var life := clampf(g, 0.0, 1.0)
	var lush := clampf(g - 1.0, 0.0, 1.0)
	for i in 3:
		var y := c.y + i * s * 0.18
		var w := s * (0.9 - i * 0.12)
		var col := Palette.GRASS_DRY.lerp(Color("78b45a"), life).darkened(0.06 * i)
		ellipse(ci, Vector2(c.x, y), w, s * 0.1, Palette.STONE_DARK)
		ellipse(ci, Vector2(c.x, y - s * 0.03), w * 0.96, s * 0.085, col)
		if lush > 0.0:
			for k in 6:
				var p := Vector2(c.x - w * 0.8 + k * w * 0.32, y - s * 0.04)
				circle(ci, p, s * 0.035 * lush, Color("4f8f3e"))
				circle(ci, p + Vector2(-s * 0.01, -s * 0.01), s * 0.02 * lush, Color("8fcf6a"))


# ---------------------------------------------------------------- decorations

static func decoration(ci: CanvasItem, kind: String, p: Vector2, s: float, t: float) -> void:
	match kind:
		"lantern":
			shadow(ci, p, s * 0.22)
			ci.draw_rect(Rect2(p.x - s * 0.06, p.y - s * 0.5, s * 0.12, s * 0.5), Palette.ROCK)
			ci.draw_rect(Rect2(p.x - s * 0.14, p.y - s * 0.72, s * 0.28, s * 0.22), Palette.ROCK.lightened(0.1))
			circle(ci, p + Vector2(0, -s * 0.61), s * (0.18 + 0.02 * sin(t * 3.0)), Color(Palette.GOLD, 0.25))
			ci.draw_rect(Rect2(p.x - s * 0.07, p.y - s * 0.67, s * 0.14, s * 0.12), Palette.GOLD)
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.2, -s * 0.72), p + Vector2(s * 0.2, -s * 0.72), p + Vector2(0, -s * 0.88)]), Palette.ROCK_DARK)
		"bench":
			shadow(ci, p, s * 0.35)
			ci.draw_line(p + Vector2(-s * 0.3, 0), p + Vector2(-s * 0.3, -s * 0.18), Palette.BARK_DARK, 3.0, AA)
			ci.draw_line(p + Vector2(s * 0.3, -s * 0.05), p + Vector2(s * 0.3, -s * 0.22), Palette.BARK_DARK, 3.0, AA)
			ci.draw_line(p + Vector2(-s * 0.36, -s * 0.2), p + Vector2(s * 0.36, -s * 0.26), Palette.BARK, maxf(4.0, s * 0.08), AA)
			ci.draw_line(p + Vector2(-s * 0.36, -s * 0.36), p + Vector2(s * 0.36, -s * 0.42), Palette.BARK, maxf(3.0, s * 0.06), AA)
		"bridge":
			var pts := PackedVector2Array()
			for i in 9:
				var u := i / 8.0
				pts.append(p + Vector2((u - 0.5) * s * 1.1, (u - 0.5) * s * 0.55 - sin(u * PI) * s * 0.3))
			ci.draw_polyline(pts, Palette.BARK_DARK, maxf(8.0, s * 0.2), AA)
			ci.draw_polyline(pts, Palette.BARK, maxf(6.0, s * 0.15), AA)
			for i in 9:
				ci.draw_line(pts[i], pts[i] + Vector2(0, -s * 0.18), Palette.BARK_DARK, 2.0, AA)
			var rail := PackedVector2Array()
			for q in pts:
				rail.append(q + Vector2(0, -s * 0.18))
			ci.draw_polyline(rail, Palette.BARK, 2.5, AA)
		"birdhouse":
			shadow(ci, p, s * 0.15)
			ci.draw_line(p, p + Vector2(0, -s * 0.7), Palette.BARK_DARK, maxf(3.0, s * 0.05), AA)
			ci.draw_rect(Rect2(p.x - s * 0.13, p.y - s * 0.92, s * 0.26, s * 0.24), Color("d8b07a"))
			ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-s * 0.19, -s * 0.92), p + Vector2(s * 0.19, -s * 0.92), p + Vector2(0, -s * 1.08)]), Color("b5583c"))
			circle(ci, p + Vector2(0, -s * 0.8), s * 0.05, Palette.BARK_DARK)
		"koi":
			koi(ci, p, s * 1.2, t)
		"beehive":
			shadow(ci, p, s * 0.2)
			for i in 4:
				ellipse(ci, p + Vector2(0, -s * (0.08 + i * 0.1)), s * (0.18 - i * 0.03), s * 0.07, Color("e8b54a").darkened(0.08 * (i % 2)))
			for i in 3:
				var a := t * 3.0 + i * 2.1
				circle(ci, p + Vector2(cos(a) * s * 0.3, -s * 0.4 + sin(a * 1.3) * s * 0.12), s * 0.025, Palette.TEXT)
		"arch":
			ci.draw_arc(p + Vector2(0, -s * 0.2), s * 0.38, PI, TAU, 20, Palette.BARK, maxf(4.0, s * 0.06), AA)
			ci.draw_line(p + Vector2(-s * 0.38, -s * 0.2), p + Vector2(-s * 0.38, 0), Palette.BARK, maxf(4.0, s * 0.06), AA)
			ci.draw_line(p + Vector2(s * 0.38, -s * 0.2), p + Vector2(s * 0.38, 0), Palette.BARK, maxf(4.0, s * 0.06), AA)
			for i in 9:
				var a := PI + PI * i / 8.0
				var q := p + Vector2(0, -s * 0.2) + Vector2(cos(a), sin(a)) * s * 0.38
				circle(ci, q, s * 0.06, Palette.LEAF_DARK)
				circle(ci, q + Vector2(0, -s * 0.02), s * 0.04, [Palette.CORAL, Color.WHITE, Palette.LILAC][i % 3])
		"spire":
			for i in 3:
				var q := p + Vector2((i - 1) * s * 0.22, (i % 2) * s * 0.06)
				var hgt := s * (0.55 + 0.25 * (1 - absf(i - 1)))
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(-s * 0.08, 0), q + Vector2(s * 0.08, 0), q + Vector2(s * 0.05, -hgt), q + Vector2(-s * 0.05, -hgt)]), Palette.ROCK.lightened(0.05 * i))
				circle(ci, q + Vector2(0, -hgt * 0.6), s * 0.03, Color(Palette.WATER_LIGHT, 0.6 + 0.4 * sin(t * 2.0 + i)))


# ---------------------------------------------------------------- UI glyphs

## Simple vector icons for buttons. `r` is the icon rect.
static func icon(ci: CanvasItem, kind: String, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.5
	var w := maxf(2.5, s * 0.18)
	match kind:
		"back":
			ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.6), c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, s * 0.6)]), col, w, AA)
		"undo":
			ci.draw_arc(c + Vector2(s * 0.1, s * 0.1), s * 0.5, PI * 1.05, PI * 2.4, 18, col, w, AA)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.75, -s * 0.15), c + Vector2(-s * 0.1, -s * 0.1), c + Vector2(-s * 0.5, s * 0.4)]), col)
		"reset":
			ci.draw_arc(c, s * 0.55, PI * 0.2, PI * 1.85, 22, col, w, AA)
			var tip := c + Vector2(cos(PI * 0.2), sin(PI * 0.2)) * s * 0.55
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-s * 0.35, -s * 0.05), tip + Vector2(s * 0.3, -s * 0.15), tip + Vector2(s * 0.05, s * 0.4)]), col)
		"hint":
			circle(ci, c + Vector2(0, -s * 0.15), s * 0.45, col)
			ci.draw_rect(Rect2(c.x - s * 0.22, c.y + s * 0.25, s * 0.44, s * 0.3), col)
			circle(ci, c + Vector2(-s * 0.13, -s * 0.28), s * 0.12, Color(1, 1, 1, 0.7))
		"leaf":
			var pts := PackedVector2Array()
			for i in 13:
				var u := i / 12.0
				pts.append(c + Vector2(sin(u * PI) * s * 0.45, (u - 0.5) * s * 1.4).rotated(0.6))
			for i in 13:
				var u := 1.0 - i / 12.0
				pts.append(c + Vector2(-sin(u * PI) * s * 0.45, (u - 0.5) * s * 1.4).rotated(0.6))
			ci.draw_colored_polygon(pts, col)
		"drop":
			var pts := PackedVector2Array([c + Vector2(0, -s * 0.8)])
			for i in 17:
				var a := PI * i / 16.0
				pts.append(c + Vector2(cos(a) * s * 0.5, s * 0.2 + sin(a) * s * 0.5))
			ci.draw_colored_polygon(pts, col)
		"gear":
			for i in 8:
				var a := TAU * i / 8.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * s * 0.45, c + Vector2(cos(a), sin(a)) * s * 0.8, col, w * 1.3, AA)
			circle(ci, c, s * 0.55, col)
			circle(ci, c, s * 0.22, Palette.CREAM)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + TAU * i / 10.0
				var rr := s * (0.8 if i % 2 == 0 else 0.36)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			ci.draw_colored_polygon(pts, col)
		"lock":
			ci.draw_arc(c + Vector2(0, -s * 0.15), s * 0.32, PI, TAU, 14, col, w, AA)
			ci.draw_rect(Rect2(c.x - s * 0.48, c.y - s * 0.15, s * 0.96, s * 0.75), col)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.5, 0), c + Vector2(-s * 0.12, s * 0.4), c + Vector2(s * 0.55, -s * 0.45)]), col, w * 1.2, AA)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.35, -s * 0.55), c + Vector2(s * 0.55, 0), c + Vector2(-s * 0.35, s * 0.55)]), col)
		"island":
			ellipse(ci, c + Vector2(0, s * 0.3), s * 0.8, s * 0.3, col)
			circle(ci, c + Vector2(-s * 0.1, -s * 0.2), s * 0.35, col)
			ci.draw_line(c + Vector2(-s * 0.1, -s * 0.0), c + Vector2(-s * 0.1, s * 0.3), col, w, AA)
		"collection":
			for i in 2:
				for j in 2:
					ci.draw_rect(Rect2(c.x - s * 0.7 + i * s * 0.75, c.y - s * 0.7 + j * s * 0.75, s * 0.62, s * 0.62), col)
		"moves":
			ci.draw_arc(c, s * 0.55, 0, TAU, 20, col, w, AA)
			ci.draw_line(c, c + Vector2(0, -s * 0.38), col, w, AA)
			ci.draw_line(c, c + Vector2(s * 0.3, 0), col, w, AA)
		"no_leaks":
			icon(ci, "drop", r, col)
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.7, -s * 0.7), Palette.CREAM, w * 1.6, AA)
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.7, -s * 0.7), col, w * 0.8, AA)
		"flower":
			for i in 5:
				var a := TAU * i / 5.0
				circle(ci, c + Vector2(cos(a), sin(a)) * s * 0.35, s * 0.28, col)
			circle(ci, c, s * 0.22, Palette.GOLD)
