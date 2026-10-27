extends RefCounted
## Reusable parts for the merge-art models (ArtModel): crockery, containers, plants,
## food and decorations. Positions are the part's base centre unless noted; `s`
## scales the part.

const WOOD := "b9783f"
const WOOD_DARK := "8a5228"
const GOLD := "ffc634"
const SILVER := "dfe6ee"
const CREAM := "fffaf2"


static func cup(m: ArtModel, p: Vector3, s: float, col, drink, handle := true, saucer := true) -> void:
	if saucer:
		m.cyl(p + Vector3(0, 0.04, 0) * s, 0.62 * s, 0.045 * s, 0.035 * s, col).gloss(0.7)
		m.cyl(p + Vector3(0, 0.1, 0) * s, 0.36 * s, 0.03 * s, 0.02 * s, col).sub(0.03 * s, true)
	var b := p + Vector3(0, 0.38, 0) * s
	m.cone(b, 0.26 * s, 0.42 * s, 0.3 * s, 0.07 * s, col).gloss(0.75)
	if handle:
		m.torus(b + Vector3(0.42, 0.02, 0) * s, 0.14 * s, 0.045 * s, col).rot_deg(Vector3(90, 0, 0)).k(0.03 * s).gloss(0.75)
	m.cyl(b + Vector3(0, 0.33, 0) * s, 0.36 * s, 0.1 * s, 0.0, drink).sub(0.015 * s)


static func plate(m: ArtModel, p: Vector3, r: float, col = CREAM) -> void:
	m.cone(p + Vector3(0, 0.05 * r, 0), r * 0.62, r, 0.06 * r, 0.04 * r, col).gloss(0.75)
	m.cyl(p + Vector3(0, 0.13 * r, 0), r * 0.68, 0.05 * r, 0.04 * r, col).sub(0.06 * r, true)


static func bowl(m: ArtModel, p: Vector3, r: float, col, fill = null) -> void:
	m.begin()
	m.sphere(p + Vector3(0, r * 0.62, 0), r, col).gloss(0.7)
	m.plane(p + Vector3(0, r * 0.62, 0)).inter(0.02 * r)
	m.plane(p + Vector3(0, r * 0.02, 0)).rot_deg(Vector3(180, 0, 0)).inter(0.04 * r)
	m.sphere(p + Vector3(0, r * 0.66, 0), r * 0.88, col.darkened(0.15) if col is Color else Color(str(col)).darkened(0.15)).sub(0.02 * r)
	m.end(0.0)
	if fill != null:
		m.ell(p + Vector3(0, r * 0.56, 0), Vector3(r * 0.86, r * 0.22, r * 0.86), fill).k(0.03 * r).gloss(0.4)


static func jar(m: ArtModel, p: Vector3, s: float, col, lid, label = null) -> void:
	m.cyl(p + Vector3(0, 0.42, 0) * s, 0.36 * s, 0.42 * s, 0.12 * s, col).gloss(0.85)
	m.cyl(p + Vector3(0, 0.9, 0) * s, 0.3 * s, 0.09 * s, 0.04 * s, lid).k(0.02 * s).gloss(0.6)
	if label != null:
		m.cyl(p + Vector3(0, 0.42, 0) * s, 0.37 * s, 0.17 * s, 0.02 * s, label).paint(0.01 * s)


static func bottle(m: ArtModel, p: Vector3, s: float, col, cap) -> void:
	m.cyl(p + Vector3(0, 0.36, 0) * s, 0.3 * s, 0.36 * s, 0.14 * s, col).gloss(0.9)
	m.cone(p + Vector3(0, 0.8, 0) * s, 0.28 * s, 0.12 * s, 0.14 * s, 0.05 * s, col).k(0.06 * s).gloss(0.9)
	m.cyl(p + Vector3(0, 1.0, 0) * s, 0.13 * s, 0.07 * s, 0.03 * s, cap).k(0.01 * s).gloss(0.5)


static func sack(m: ArtModel, p: Vector3, s: float, col, tie = "b9783f") -> void:
	# a burlap sack: wide soft bottom, gathered neck, frilled opening, a rope tie
	var c := ArtModel.c(col)
	m.ell(p + Vector3(0, 0.36, 0) * s, Vector3(0.54, 0.42, 0.46) * s, c).gloss(0.08)
	m.cone(p + Vector3(0, 0.62, 0) * s, 0.42 * s, 0.17 * s, 0.2 * s, 0.1 * s, c).k(0.12 * s).gloss(0.08)
	for i in 7:
		var a := TAU * i / 7.0
		m.ell(p + Vector3(cos(a) * 0.17, 0.92, sin(a) * 0.17) * s, Vector3(0.11, 0.12, 0.07) * s, c.lightened(0.05)).rot_deg(Vector3(0, -rad_to_deg(a), 30 * cos(a))).k(0.05 * s).gloss(0.08)
	m.torus(p + Vector3(0, 0.8, 0) * s, 0.17 * s, 0.04 * s, tie).k(0.015 * s).gloss(0.3)
	m.ell(p + Vector3(0.12, 0.72, 0.16) * s, Vector3(0.03, 0.09, 0.03) * s, tie).rot_deg(Vector3(0, 0, 25)).k(0.01 * s)


static func crate(m: ArtModel, p: Vector3, half: Vector3, wood = WOOD) -> void:
	var c := ArtModel.c(wood)
	m.box(p + Vector3(0, half.y, 0), half, 0.05, c).gloss(0.25)
	for y in [0.3, 1.0, 1.7]:
		m.box(p + Vector3(0, half.y * y, half.z), Vector3(half.x * 0.98, 0.012, 0.02), 0.01, c.darkened(0.3)).sub(0.01, true)
	m.box(p + Vector3(half.x * 0.86, half.y, half.z + 0.01), Vector3(0.05, half.y, 0.03), 0.02, c.darkened(0.12)).mirror().k(0.01)


static func basket(m: ArtModel, p: Vector3, r: float, col = "c98a46", handle := true) -> void:
	var c := ArtModel.c(col)
	m.begin()
	m.cone(p + Vector3(0, r * 0.4, 0), r * 0.75, r, r * 0.4, r * 0.1, c).gloss(0.2)
	m.cyl(p + Vector3(0, r * 0.82, 0), r * 0.88, r * 0.12, 0.0, c.darkened(0.2)).sub(0.02)
	m.end(0.0)
	for i in 3:
		m.torus(p + Vector3(0, r * (0.18 + 0.22 * i), 0), r * (0.8 + 0.07 * i), r * 0.035, c.darkened(0.16)).k(0.01)
	m.torus(p + Vector3(0, r * 0.8, 0), r * 0.95, r * 0.07, c.lightened(0.08)).k(0.02)
	if handle:
		m.begin()
		m.torus(p + Vector3(0, r * 0.8, 0), r * 0.82, r * 0.06, c.lightened(0.05)).rot_deg(Vector3(90, 0, 0))
		m.plane(p + Vector3(0, r * 0.8, 0)).rot_deg(Vector3(180, 0, 0)).inter(0.0)
		m.end(0.03)


static func leaf(m: ArtModel, p: Vector3, len: float, col, rot: Vector3) -> void:
	m.ell(p, Vector3(len * 0.42, len, len * 0.08), col).rot_deg(rot).gloss(0.5)


static func flower(m: ArtModel, p: Vector3, r: float, petal, center, n := 6, tilt := Vector3(-35, 0, 0)) -> void:
	var b := Basis.from_euler(Vector3(deg_to_rad(tilt.x), deg_to_rad(tilt.y), deg_to_rad(tilt.z)))
	for i in n:
		var a := TAU * i / n
		var off := b * Vector3(cos(a), 0, sin(a)) * r * 0.62
		m.ell(p + off, Vector3(r * 0.42, r * 0.12, r * 0.28), petal).rot_deg(Vector3(tilt.x, -rad_to_deg(a), tilt.z)).k(0.02 * r).gloss(0.4)
	m.sphere(p + b * Vector3(0, r * 0.1, 0), r * 0.3, center).k(0.03 * r).gloss(0.3)


static func pot(m: ArtModel, p: Vector3, s: float, col = "d0743f") -> void:
	var c := ArtModel.c(col)
	m.cone(p + Vector3(0, 0.3, 0) * s, 0.3 * s, 0.42 * s, 0.3 * s, 0.06 * s, c).gloss(0.35)
	m.cyl(p + Vector3(0, 0.62, 0) * s, 0.47 * s, 0.08 * s, 0.04 * s, c.lightened(0.06)).k(0.02 * s).gloss(0.35)
	m.cyl(p + Vector3(0, 0.68, 0) * s, 0.38 * s, 0.06 * s, 0.0, "6b4423").sub(0.02 * s)


static func cake(m: ArtModel, p: Vector3, r: float, h: float, sponge, frost, layers := 1) -> void:
	var y := 0.0
	for i in layers:
		var rr := r * (1.0 - 0.2 * i)
		m.cyl(p + Vector3(0, y + h * 0.5, 0), rr, h * 0.5, rr * 0.12, sponge).k(0.01).gloss(0.2)
		m.cyl(p + Vector3(0, y + h * 0.88, 0), rr * 1.02, h * 0.16, rr * 0.1, frost).k(0.02).gloss(0.55)
		for j in 8:
			var a := TAU * j / 8.0
			m.sphere(p + Vector3(cos(a) * rr * 0.98, y + h * 0.82, sin(a) * rr * 0.98), rr * 0.11, frost).k(0.03).gloss(0.55)
		y += h
	return


static func star(m: ArtModel, p: Vector3, r: float, col, depth := 0.12, rot := Vector3.ZERO) -> void:
	# five rounded points around a centre
	for i in 5:
		var a := -PI * 0.5 + TAU * i / 5.0
		var tip := p + Basis.from_euler(rot * PI / 180.0) * (Vector3(cos(a), -sin(a), 0) * r * 0.62)
		m.taper(tip, r * 0.1, r * 0.34, r * 0.32, col).along(p - tip).k(r * 0.08).gloss(0.85)
	m.ell(p, Vector3(r * 0.42, r * 0.42, depth * r * 1.6), col).rot_deg(rot).k(r * 0.08).gloss(0.85)


static func sparkle(m: ArtModel, p: Vector3, r: float) -> void:
	m.ell(p, Vector3(r * 0.18, r, r * 0.18), "fff6c8").gloss(0.9)
	m.ell(p, Vector3(r, r * 0.18, r * 0.18), "fff6c8").k(r * 0.1).gloss(0.9)


## Generator upgrade tiers: wood, painted, brass, silver, gold.
static func tier_col(level: int) -> Color:
	return Color(["a8703c", "4f86c9", "d9a441", "c9d3dd", "ffc634"][clampi(level - 1, 0, 4)])


static func tier_trim(m: ArtModel, level: int, p: Vector3, r: float) -> void:
	# a ring of studs, more of them on higher tiers, and a gem on the top tier
	if level >= 3:
		var n := 4 + 2 * (level - 3)
		for i in n:
			var a := TAU * i / n
			m.sphere(p + Vector3(cos(a), 0, sin(a)) * r, r * 0.07, GOLD if level != 4 else SILVER).k(0.01).gloss(0.9)
	if level >= 5:
		m.sphere(p + Vector3(0, 0, r), r * 0.14, "e84a7a").k(0.01).gloss(1.0)
