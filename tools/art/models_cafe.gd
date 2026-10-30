extends RefCounted
## Lantern Café (resources/merge/items.json): coffee, bakery, catch, garden and their
## generators.

const Kit := preload("res://tools/art/kit.gd")


static func v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


static func keys() -> Array:
	var out := []
	for c in ["coffee", "bakery", "catch", "garden"]:
		for i in 10:
			out.append("%s:%d" % [c, i + 1])
	for c in ["gen_coffee", "gen_bakery", "gen_catch", "gen_garden"]:
		for i in 5:
			out.append("%s:%d" % [c, i + 1])
	for i in 3:
		out.append("gen_planter:%d" % (i + 1))
	return out


static func build(key: String) -> ArtModel:
	var m := ArtModel.new()
	seed(key.hash())
	var chain := key.get_slice(":", 0)
	var l := int(key.get_slice(":", 1))
	match chain:
		"coffee":
			_coffee(m, l)
		"bakery":
			_bakery(m, l)
		"catch":
			_catch(m, l)
		"garden":
			_garden(m, l)
		"gen_coffee":
			_grinder(m, l)
		"gen_bakery":
			_flour_sack(m, l)
		"gen_catch":
			_net_barrel(m, l)
		"gen_garden":
			_seed_tin(m, l)
		"gen_planter":
			_planter(m, l)
	return m


# ------------------------------------------------------------------ coffee

static func bean(m: ArtModel, p: Vector3, s: float, rot: Vector3) -> void:
	m.ell(p, v(0.3, 0.4, 0.23) * s, "7a4424").rot_deg(rot).gloss(0.6)
	var b := Basis.from_euler(rot * PI / 180.0)
	m.ell(p + b * v(0, 0, 0.22 * s), v(0.03, 0.32, 0.07) * s, "3c1d0c").rot_deg(rot).sub(0.025 * s)


static func _coffee(m: ArtModel, l: int) -> void:
	var cup := Kit.CREAM
	match l:
		1:
			bean(m, v(-0.3, -0.1, 0.05), 1.35, v(0, 0, 25))
			bean(m, v(0.32, 0.02, -0.1), 1.3, v(0, 30, -35))
		2:
			m.begin()
			m.sphere(v(-0.12, -0.15, 0), 0.62, Kit.SILVER).gloss(0.95)
			m.plane(v(0, -0.08, 0)).inter(0.0)
			m.sphere(v(-0.12, -0.15, 0), 0.56, "a8b0ba").sub(0.0)
			m.end(0.0)
			m.segment(v(0.4, -0.18, 0), v(0.95, 0.15, 0), 0.07, "a0603a").k(0.04).gloss(0.5)
			for p in [v(-0.35, -0.02, 0.15), v(0.0, 0.02, 0.2), v(-0.15, 0.08, -0.15), v(0.15, -0.02, -0.05), v(-0.45, -0.05, -0.15)]:
				bean(m, p, 0.55, v(randf_range(-60, 60), randf_range(0, 360), randf_range(-60, 60)))
		3:
			m.box(v(0, -0.25, 0), v(0.46, 0.62, 0.32), 0.06, "b07a4a").gloss(0.15)
			m.box(v(0, 0.42, 0), v(0.44, 0.08, 0.3), 0.03, "8a5a32").k(0.03)
			m.box(v(0, -0.25, 0.33), v(0.32, 0.3, 0.02), 0.04, "fff3dc").k(0.01)
			bean(m, v(0, -0.25, 0.36), 0.5, v(0, 0, 20))
			m.ell(v(0, 0.48, 0), v(0.38, 0.12, 0.26), "4a2a16").k(0.04).gloss(0.05)
		4:
			Kit.cup(m, v(0, -0.62, 0), 1.15, cup, "5a2e14")
			m.ell(v(0, 0.03, 0), v(0.34, 0.03, 0.34), "c88a4a").k(0.02).gloss(0.4)
		5:
			Kit.cup(m, v(0, -0.62, 0), 1.25, cup, "e9cfa7")
			m.ell(v(0, 0.13, 0.04), v(0.18, 0.03, 0.14), "fffaf0").paint(0.02)
			m.ell(v(0, 0.13, -0.18), v(0.32, 0.03, 0.12), "b8875a").paint(0.04)
		6, 7:
			var glass := Color("eaf6fb")
			m.cyl(v(0, -0.15, 0), 0.38, 0.72, 0.08, glass).gloss(1.0)
			m.cyl(v(0, -0.5, 0.0), 0.385, 0.32, 0.04, "fff3e0").paint(0.04)
			m.cyl(v(0, 0.05, 0.0), 0.385, 0.25, 0.04, "a0603a").paint(0.04)
			m.cyl(v(0, 0.5, 0), 0.33, 0.1, 0.0, "f5e6cc").sub(0.01)
			if l == 7:
				for p in [v(-0.12, 0.48, 0.05), v(0.14, 0.5, -0.06), v(0.02, 0.56, 0.12)]:
					m.box(p, v(0.1, 0.1, 0.1), 0.03, "dff4ff").rot_deg(v(randf_range(0, 40), randf_range(0, 90), 20)).k(0.01).gloss(1.0)
				m.segment(v(0.1, 0.3, -0.05), v(0.3, 0.95, -0.1), 0.045, "e8553f").gloss(0.7)
			else:
				m.ell(v(0, 0.56, 0), v(0.3, 0.12, 0.3), "fffaf0").k(0.04)
				m.sphere(v(0.05, 0.67, 0.05), 0.05, "a0603a").k(0.01)
		8:
			m.cyl(v(0, -0.4, 0), 0.42, 0.42, 0.1, "d9574a").gloss(0.75)
			m.torus(v(0.48, -0.36, 0), 0.18, 0.06, "d9574a").rot_deg(v(90, 0, 0)).k(0.03).gloss(0.75)
			m.cyl(v(0, 0.02, 0), 0.36, 0.06, 0.0, "6b3a20").sub(0.01)
			for i in 3:
				m.ell(v(0, 0.08 + i * 0.13, 0), v(0.34 - i * 0.09, 0.1, 0.34 - i * 0.09), "fffaf2").k(0.04).gloss(0.3)
			m.cone(v(0, 0.48, 0), 0.08, 0.0, 0.08, 0.01, "fffaf2").k(0.04)
			m.torus(v(0, 0.2, 0), 0.24, 0.025, "6b3a20").rot_deg(v(10, 0, 10)).paint(0.01)
			m.sphere(v(0.08, 0.6, 0.0), 0.06, "c0392b").k(0.01).gloss(0.9)
		9:
			Kit.plate(m, v(0, -0.62, 0), 0.95)
			m.cyl(v(0, -0.32, 0), 0.62, 0.24, 0.06, "c98a4a").gloss(0.2)
			m.cyl(v(0, -0.32, 0), 0.63, 0.04, 0.02, "7a4424").paint(0.02)
			for i in 14:
				var a := randf() * TAU
				var r := randf() * 0.5
				m.sphere(v(cos(a) * r, -0.06, sin(a) * r), 0.07, "e8b46a").k(0.03)
			m.ell(v(0, -0.03, 0), v(0.5, 0.04, 0.5), "fff6e8").paint(0.04)
		10:
			Kit.plate(m, v(0, -0.82, 0), 1.0, "e3f1ff")
			Kit.cake(m, v(0, -0.76, 0), 0.68, 0.36, "a0603a", "fff3e0", 3)
			m.cyl(v(0, 0.48, 0), 0.08, 0.14, 0.03, Kit.GOLD).gloss(0.9)
			m.sphere(v(0, 0.72, 0), 0.13, "ffcf5a").gloss(1.0)
			m.cone(v(0, 0.88, 0), 0.1, 0.02, 0.06, 0.02, Kit.GOLD).k(0.02).gloss(0.9)
			for i in 5:
				var a := TAU * i / 5.0
				m.sphere(v(cos(a) * 0.5, -0.04, sin(a) * 0.5), 0.07, "e84a7a").k(0.02).gloss(0.9)


# ------------------------------------------------------------------ bakery

static func _bread_col(top := false) -> Color:
	return Color("d88a3a") if top else Color("e8b46a")


static func _bakery(m: ArtModel, l: int) -> void:
	match l:
		1:
			Kit.sack(m, v(0, -0.85, 0), 1.3, "f2e6cc", "b9783f")
			m.ell(v(0, 0.28, 0), v(0.3, 0.12, 0.28), "ffffff").k(0.06).gloss(0.05)
			m.ell(v(0, -0.35, 0.5), v(0.18, 0.22, 0.05), "8fb6e8").paint(0.02)
		2:
			m.box(v(0, -0.6, 0), v(0.85, 0.06, 0.55), 0.04, Kit.WOOD).gloss(0.3)
			m.ell(v(0, -0.22, 0), v(0.58, 0.36, 0.5), "f6e3c8").k(0.08).gloss(0.25)
			m.ell(v(0.6, -0.5, 0.3), v(0.14, 0.03, 0.1), "ffffff").k(0.02)
		3:
			m.ell(v(0, -0.2, 0), v(0.72, 0.5, 0.62), _bread_col(true)).gloss(0.55)
			m.ell(v(0, -0.6, 0), v(0.72, 0.15, 0.62), _bread_col()).k(0.1)
			for x in [-0.22, 0.22]:
				m.ell(v(x, 0.26, 0.15), v(0.04, 0.06, 0.4), "f2cf8a").rot_deg(v(0, 0, 20)).sub(0.04, true)
		4:
			var col := "e3a24a"
			m.ell(v(0, 0, 0), v(0.42, 0.36, 0.38), col).gloss(0.5)
			for sd in [-1, 1]:
				m.ell(v(0.38 * sd, -0.06, 0.02), v(0.28, 0.28, 0.3), "d99440").rot_deg(v(0, 0, 25 * sd)).k(0.06)
				m.ell(v(0.66 * sd, -0.16, 0.06), v(0.19, 0.2, 0.21), col).rot_deg(v(0, 0, 40 * sd)).k(0.06)
				m.taper(v(0.86 * sd, -0.32, 0.1), 0.12, 0.05, 0.12, "c9863a").rot_deg(v(0, 0, 35 * sd)).k(0.05)
			for x in [-0.19, 0.19]:
				m.ell(v(x, 0.0, 0.36), v(0.025, 0.36, 0.07), "a8652a").sub(0.04, true)
			m.ell(v(0, 0.32, 0.06), v(0.24, 0.06, 0.2), "f2c26e").paint(0.08)
		5:
			m.capsule(v(0, 0, 0), 0.75, 0.26, _bread_col(true)).rot_deg(v(0, 25, 62)).gloss(0.55)
			for i in 4:
				var t := -0.5 + i * 0.33
				var p := Basis.from_euler(v(0, 25, 62) * PI / 180.0) * v(0, t, 0.24)
				m.ell(p, v(0.05, 0.12, 0.08), "f2cf8a").rot_deg(v(0, 25, 62 - 50)).sub(0.03, true)
		6:
			m.box(v(0, -0.55, 0), v(0.72, 0.1, 0.6), 0.08, "f2d39a").gloss(0.3)
			m.box(v(0, -0.38, 0), v(0.78, 0.04, 0.66), 0.03, "6fc35a").k(0.02).gloss(0.5)
			for p in [v(-0.3, -0.3, 0.2), v(0.3, -0.3, -0.15), v(0.35, -0.3, 0.3)]:
				m.cyl(p, 0.2, 0.03, 0.02, "e8553f").k(0.01).gloss(0.6)
			m.box(v(0, -0.24, 0), v(0.66, 0.035, 0.56), 0.02, "ffd34a").rot_deg(v(0, 12, 0)).k(0.01).gloss(0.5)
			m.box(v(0, -0.08, 0), v(0.72, 0.1, 0.6), 0.08, "f2d39a").gloss(0.3)
			m.box(v(0, 0.02, 0), v(0.68, 0.02, 0.56), 0.02, "d89a4a").paint(0.03)
		7:
			# a club sandwich wedge: toast, lettuce, tomato, cheese, toast, ...
			m.begin()
			for i in 3:
				var y := -0.62 + i * 0.36
				m.box(v(0, y, 0), v(0.6, 0.07, 0.6), 0.05, "f2d39a").gloss(0.3)
				m.box(v(0, y + 0.1, 0), v(0.64, 0.03, 0.64), 0.02, "6fc35a").k(0.01).gloss(0.5)
				m.box(v(0, y + 0.16, 0), v(0.6, 0.03, 0.6), 0.02, ["e8553f", "ffd34a", "f2a0a8"][i]).k(0.01).gloss(0.5)
			m.box(v(0, 0.48, 0), v(0.6, 0.07, 0.6), 0.05, "f2d39a").gloss(0.3)
			m.plane(v(0, 0, 0)).rot_deg(v(0, 45, 90)).inter(0.02)
			m.end(0.0)
			m.cyl(v(-0.1, 0.55, -0.05), 0.025, 0.42, 0.01, Kit.WOOD).gloss(0.4)
			m.sphere(v(-0.1, 0.98, -0.05), 0.1, "4f8a3a").gloss(0.9)
			m.cam_pos = v(1.2, 1.2, 3.3)
		8:
			m.cone(v(0, -0.5, 0), 0.72, 0.85, 0.16, 0.08, "e3a24a").gloss(0.4)
			m.cyl(v(0, -0.34, 0), 0.74, 0.06, 0.0, "fff3e0").sub(0.02, false)
			m.cyl(v(0, -0.4, 0), 0.74, 0.04, 0.02, "fff3e0").k(0.02).gloss(0.3)
			for i in 8:
				var a := TAU * i / 8.0
				m.sphere(v(cos(a) * 0.55, -0.28, sin(a) * 0.55), 0.14, "e8553f").k(0.02).gloss(0.8)
			for i in 5:
				var a := TAU * i / 5.0 + 0.3
				m.cyl(v(cos(a) * 0.28, -0.3, sin(a) * 0.28), 0.14, 0.03, 0.02, "7cc04a").k(0.01).gloss(0.6)
			m.sphere(v(0, -0.24, 0), 0.12, "3f5fd0").k(0.01).gloss(0.8)
		9:
			m.cone(v(0, -0.45, 0), 0.7, 0.85, 0.18, 0.08, "e3a24a").gloss(0.4)
			m.ell(v(0, -0.25, 0), v(0.75, 0.16, 0.75), "8a2a5a").k(0.03).gloss(0.8)
			for i in 5:
				var x := -0.5 + i * 0.25
				m.capsule(v(x, -0.12, 0), 0.62, 0.05, "f2c26e").rot_deg(v(90, 0, 0)).k(0.02).gloss(0.4)
				m.capsule(v(0, -0.12, x), 0.62, 0.05, "e8b46a").rot_deg(v(0, 0, 90)).k(0.02).gloss(0.4)
			m.torus(v(0, -0.28, 0), 0.8, 0.08, "e3a24a").k(0.02)
			m.plane(v(0, -0.6, 0)).rot_deg(v(180, 0, 0)).inter(0.0)
		10:
			m.cone(v(0, -0.55, 0), 0.7, 0.85, 0.2, 0.08, "e3a24a").gloss(0.4)
			m.ell(v(0, -0.3, 0), v(0.78, 0.18, 0.78), "fff3e0").k(0.05).gloss(0.5)
			m.torus(v(0, -0.32, 0), 0.8, 0.08, "e3a24a").k(0.02)
			for i in 8:
				var a := TAU * i / 8.0
				m.sphere(v(cos(a) * 0.6, -0.15, sin(a) * 0.6), 0.1, "e8553f").k(0.02).gloss(0.9)
			for i in 3:
				var x := -0.25 + i * 0.25
				m.cyl(v(x, 0.05, 0.05 * i), 0.04, 0.2, 0.01, ["8fd0ff", "ff9fbf", "ffd34a"][i]).gloss(0.6)
				m.ell(v(x, 0.34, 0.05 * i), v(0.04, 0.08, 0.04), "ffb02a").gloss(1.0)
			Kit.star(m, v(0, 0.55, -0.25), 0.25, Kit.GOLD, 0.2)


# ------------------------------------------------------------------ catch

static func fish(m: ArtModel, p: Vector3, s: float, body, belly, rot := Vector3.ZERO) -> void:
	var b := Basis.from_euler(rot * PI / 180.0)
	m.ell(p, v(0.62, 0.32, 0.2) * s, body).rot_deg(rot).gloss(0.8)
	m.ell(p + b * v(0, -0.1, 0) * s, v(0.52, 0.18, 0.21) * s, belly).rot_deg(rot).paint(0.05 * s)
	m.ell(p + b * v(-0.68, 0, 0) * s, v(0.16, 0.26, 0.05) * s, body).rot_deg(rot).k(0.08 * s).gloss(0.6)
	m.ell(p + b * v(0.05, 0.3, 0) * s, v(0.2, 0.1, 0.04) * s, body).rot_deg(rot + v(0, 0, -10)).k(0.04 * s)
	m.sphere(p + b * v(0.38, 0.06, 0.13) * s, 0.075 * s, "ffffff").gloss(0.9)
	m.sphere(p + b * v(0.4, 0.06, 0.18) * s, 0.042 * s, "1a1418").gloss(1.0)
	m.ell(p + b * v(0.22, -0.02, 0.17) * s, v(0.02, 0.14, 0.04) * s, Color(body).darkened(0.2) if body is Color else Color(str(body)).darkened(0.2)).rot_deg(rot).paint(0.01 * s)


static func _catch(m: ArtModel, l: int) -> void:
	match l:
		1:
			_scallop(m, v(0, -0.1, 0), 1.0, "f7b9a0")
		2:
			m.begin()
			m.ell(v(0, -0.35, 0), v(0.7, 0.3, 0.55), "a7b5c8").gloss(0.5)
			m.plane(v(0, -0.32, 0)).inter(0.0)
			m.end(0.0)
			m.begin()
			m.ell(v(0, -0.28, -0.05), v(0.7, 0.3, 0.55), "b9c7da").rot_deg(v(-38, 0, 0)).gloss(0.5)
			m.plane(v(0, -0.3, -0.05)).rot_deg(v(142, 0, 0)).inter(0.0)
			m.end(0.0)
			m.sphere(v(0, -0.25, 0.12), 0.18, "fff8f0").gloss(1.0)
			m.ell(v(0, -0.33, 0), v(0.6, 0.06, 0.45), "f2a0a8").k(0.02)
		3:
			fish(m, v(0, 0, 0), 1.2, "4f9fe0", "e8f4ff", v(0, -15, 8))
		4:
			fish(m, v(0, 0, 0), 1.45, "f08a6a", "ffe2d0", v(0, -15, 8))
		5:
			Kit.plate(m, v(0, -0.6, 0), 1.0)
			fish(m, v(0, -0.32, 0.05), 1.2, "d9873a", "f2c27a", v(80, 0, 0))
			for x in [-0.3, -0.05, 0.2]:
				m.capsule(v(x, -0.2, 0.05), 0.2, 0.02, "6b3a1e").rot_deg(v(90, 0, 25)).paint(0.01)
			m.ell(v(0.5, -0.3, 0.35), v(0.16, 0.08, 0.12), "ffe14a").k(0.02).gloss(0.8)
			m.ell(v(-0.5, -0.38, 0.3), v(0.12, 0.04, 0.08), "4f9a3a").k(0.01)
		6:
			m.cone(v(0, -0.3, 0), 0.25, 0.62, 0.52, 0.05, "fffaf0").gloss(0.2)
			m.cone(v(0, -0.3, 0), 0.26, 0.63, 0.53, 0.02, "3f7fd0").paint(0.01)
			m.cyl(v(0, 0.24, 0), 0.52, 0.2, 0.0, "fffaf0").sub(0.02, false)
			for i in 7:
				var a := randf() * TAU
				m.box(v(cos(a) * 0.3, 0.2 + randf() * 0.15, sin(a) * 0.25), v(0.05, 0.3, 0.05), 0.02, "f2c94a").rot_deg(v(randf_range(-25, 25), 0, randf_range(-25, 25))).k(0.01).gloss(0.5)
			m.ell(v(-0.1, 0.32, 0.2), v(0.22, 0.42, 0.14), "d9873a").rot_deg(v(0, 0, 15)).k(0.02).gloss(0.4)
		7:
			for t in [[v(-0.33, -0.25, 0), -12.0], [v(0.33, -0.25, 0.1), 12.0]]:
				var p: Vector3 = t[0]
				var r := Vector3(0, t[1], 0)
				m.begin()
				m.ell(p, v(0.36, 0.42, 0.3), "f2d39a").rot_deg(r).gloss(0.3)
				m.ell(p + v(0, 0.06, 0), v(0.33, 0.4, 0.22), "e8c27a").rot_deg(r).sub(0.01)
				m.plane(p + v(0, 0.02, 0)).inter(0.0)
				m.end(0.0)
				m.ell(p + v(0, 0.02, 0), v(0.3, 0.1, 0.2), "6fc35a").rot_deg(r).k(0.05).gloss(0.5)
				m.ell(p + v(0, 0.1, 0), v(0.24, 0.08, 0.14), "f08a6a").rot_deg(r).k(0.03).gloss(0.6)
				m.sphere(p + v(-0.08, 0.17, 0.06), 0.05, "e8553f").k(0.01)
				m.sphere(p + v(0.08, 0.17, -0.02), 0.04, "fff8ee").k(0.01)
		8:
			Kit.bowl(m, v(0, -0.75, 0), 0.82, "fffaf0", "f08a4a")
			for p in [v(-0.25, -0.15, 0.1), v(0.25, -0.15, -0.1)]:
				m.torus(p, 0.12, 0.05, "f2a07a").rot_deg(v(70, 0, 30)).k(0.02).gloss(0.6)
			m.ell(v(0.1, -0.12, 0.3), v(0.16, 0.06, 0.1), "2a2a40").k(0.02).gloss(0.9)
			m.sphere(v(-0.05, -0.12, -0.25), 0.06, "4f9a3a").k(0.01)
		9:
			var r := "e8553f"
			m.ell(v(0, -0.2, 0), v(0.3, 0.22, 0.55), r).gloss(0.6)
			for i in 4:
				m.ell(v(0, -0.22, -0.55 - i * 0.14), v(0.24 - i * 0.03, 0.15, 0.1), r).k(0.04).gloss(0.6)
			m.ell(v(0, -0.25, -1.05), v(0.26, 0.05, 0.12), r).k(0.04)
			for sd in [-1.0, 1.0]:
				m.segment(v(0.22 * sd, -0.2, 0.4), v(0.45 * sd, -0.1, 0.75), 0.07, r).k(0.03)
				m.ell(v(0.55 * sd, 0.0, 0.85), v(0.18, 0.12, 0.28), r).rot_deg(v(0, 25 * sd, 0)).k(0.04).gloss(0.7)
				m.segment(v(0.12 * sd, 0.0, 0.5), v(0.25 * sd, 0.55, 0.8), 0.015, r).k(0.01)
			m.sphere(v(0.1, 0.05, 0.48), 0.05, "1a1418").mirror().k(0.01).gloss(1.0)
			m.cam_pos = v(0, 2.2, 3.0)
		10:
			Kit.plate(m, v(0, -0.6, 0), 1.15, "dff1ff")
			m.ell(v(0, -0.45, 0), v(0.9, 0.05, 0.7), "6fc35a").k(0.02)
			m.ell(v(-0.15, -0.3, 0.0), v(0.22, 0.15, 0.42), "e8553f").rot_deg(v(0, 50, 0)).k(0.02).gloss(0.6)
			m.ell(v(0.2, -0.3, -0.3), v(0.2, 0.14, 0.18), "e8553f").k(0.03).gloss(0.6)
			for p in [v(0.4, -0.32, 0.25), v(-0.5, -0.32, 0.3), v(0.0, -0.32, 0.45)]:
				m.torus(p, 0.12, 0.05, "f2a07a").rot_deg(v(70, randf_range(0, 90), 0)).k(0.02).gloss(0.6)
			m.ell(v(0.6, -0.3, -0.1), v(0.16, 0.08, 0.12), "ffe14a").k(0.02).gloss(0.8)


static func _scallop(m: ArtModel, p: Vector3, s: float, col) -> void:
	m.begin()
	m.ell(p, v(0.72, 0.6, 0.22) * s, col).gloss(0.55)
	m.plane(p + v(0, -0.35, 0) * s).rot_deg(v(180, 0, 0)).inter(0.0)
	m.end(0.0)
	for i in 7:
		var a := deg_to_rad(-60 + i * 20)
		m.capsule(p + v(sin(a) * 0.32, cos(a) * 0.2 - 0.05, 0.16) * s, 0.28 * s, 0.035 * s, Color(col).lightened(0.15) if col is Color else Color(str(col)).lightened(0.15)).rot_deg(v(0, 0, -rad_to_deg(a))).k(0.03 * s)
	m.box(p + v(0, -0.45, 0) * s, v(0.2, 0.08, 0.12) * s, 0.04 * s, col).k(0.06 * s)


# ------------------------------------------------------------------ garden

static func _sprout(m: ArtModel, p: Vector3, s: float) -> void:
	m.segment(p, p + v(0, 0.45, 0) * s, 0.05 * s, "5aa83a").gloss(0.5)
	Kit.leaf(m, p + v(-0.2, 0.52, 0) * s, 0.22 * s, "6fc35a", v(0, 0, 60))
	Kit.leaf(m, p + v(0.2, 0.55, 0) * s, 0.24 * s, "7cd04a", v(0, 0, -60))


static func _garden(m: ArtModel, l: int) -> void:
	match l:
		1:
			m.ell(v(0, -0.1, 0), v(0.34, 0.5, 0.28), "c98a46").rot_deg(v(0, 0, -25)).gloss(0.5)
			m.ell(v(0.06, 0.05, 0.2), v(0.12, 0.28, 0.08), "e8b46a").rot_deg(v(0, 0, -25)).paint(0.05)
		2:
			m.ell(v(0, -0.65, 0), v(0.7, 0.28, 0.55), "8a5a32").gloss(0.1)
			_sprout(m, v(0, -0.45, 0.05), 1.4)
		3:
			Kit.pot(m, v(0, -0.95, 0), 1.35)
			for i in 9:
				var a := TAU * i / 9.0
				Kit.leaf(m, v(cos(a) * 0.28, 0.15 + randf() * 0.25, sin(a) * 0.22), 0.3, "4fa83a", v(randf_range(-30, 30), rad_to_deg(a), 40 * cos(a)))
		4:
			for i in 5:
				var a := deg_to_rad(-50 + i * 25)
				Kit.leaf(m, v(sin(a) * 0.35, 0.05 + cos(a) * 0.2, 0.05 * i), 0.5, ["5aa83a", "6fc35a", "4f9a3a"][i % 3], v(10, 0, -rad_to_deg(a)))
			m.segment(v(0, -0.65, 0), v(0, -0.1, 0), 0.05, "4f8a2a").k(0.04)
			m.torus(v(0, -0.45, 0), 0.08, 0.04, "c0473e").k(0.01)
		5:
			Kit.cup(m, v(0, -0.62, 0), 1.25, "e8f4ea", "a8c84a")
			Kit.leaf(m, v(0.05, 0.16, 0.0), 0.22, "4fa83a", v(80, 30, 0))
		6:
			Kit.pot(m, v(0, -0.98, 0), 1.25, "4f86c9")
			for i in 3:
				var x := -0.28 + i * 0.28
				m.segment(v(x * 0.5, -0.2, 0), v(x, 0.35 + 0.08 * (i % 2), 0.0), 0.04, "4f8a2a").k(0.03)
				m.ell(v(x, 0.5 + 0.08 * (i % 2), 0), v(0.15, 0.2, 0.15), ["e84a7a", "ffd34a", "f08a4a"][i]).k(0.02).gloss(0.6)
				m.ell(v(x, 0.66 + 0.08 * (i % 2), 0.0), v(0.1, 0.06, 0.1), "000000").sub(0.03, true)
			Kit.leaf(m, v(-0.25, -0.05, 0.15), 0.25, "5aa83a", v(0, 0, 40))
			Kit.leaf(m, v(0.25, -0.05, 0.15), 0.25, "5aa83a", v(0, 0, -40))
		7:
			m.segment(v(0, -0.95, 0), v(0, -0.1, 0), 0.06, "4f8a2a")
			Kit.leaf(m, v(-0.25, -0.5, 0.05), 0.25, "5aa83a", v(0, 0, 60))
			Kit.leaf(m, v(0.25, -0.65, 0.05), 0.25, "5aa83a", v(0, 0, -60))
			Kit.flower(m, v(0, 0.18, 0.1), 0.85, "ffc21a", "7a4424", 14, v(70, 0, 0))
		8:
			m.segment(v(0, -0.95, 0), v(0.05, -0.15, 0), 0.04, "4f8a2a")
			Kit.leaf(m, v(-0.2, -0.45, 0.05), 0.2, "4f9a3a", v(0, 0, 60))
			for i in 6:
				var a := TAU * i / 6.0
				m.ell(v(0.05 + cos(a) * 0.12, 0.08 + 0.05 * sin(a), sin(a) * 0.12), v(0.18, 0.24, 0.12), "d92a4a").rot_deg(v(0, -rad_to_deg(a), 18)).k(0.02).gloss(0.6)
			m.ell(v(0.05, 0.12, 0), v(0.13, 0.2, 0.13), "b81d3a").k(0.02).gloss(0.6)
			m.ell(v(0.05, 0.3, 0), v(0.08, 0.06, 0.08), "000000").sub(0.02, true)
		9:
			Kit.basket(m, v(0, -0.95, 0), 0.75)
			for i in 6:
				var a := TAU * i / 6.0
				Kit.flower(m, v(cos(a) * 0.35, -0.25 + randf() * 0.15, sin(a) * 0.3), 0.3, ["e84a7a", "ffd34a", "8f6bff", "ff9f5a", "ffffff", "e84a7a"][i], "ffe08a", 5, v(-55, 0, 0))
		10:
			m.cam_pos = v(0, 1.0, 3.0)
			m.cone(v(0, -0.55, 0), 0.08, 0.2, 0.35, 0.04, "6fae4a").gloss(0.3)
			m.torus(v(0, -0.45, 0), 0.16, 0.06, "ff9fbf").k(0.01).gloss(0.5)
			m.ell(v(0.2, -0.6, 0.12), v(0.08, 0.2, 0.04), "ff9fbf").rot_deg(v(0, 0, 25)).k(0.01)
			for i in 9:
				var a := TAU * i / 9.0
				var r := 0.3 if i > 0 else 0.0
				Kit.flower(m, v(cos(a) * r, 0.2 + 0.1 * (1.0 if i == 0 else 0.0), sin(a) * r), 0.3, ["ffffff", "ffe0ec"][i % 2], "ffd34a", 6, v(-45, 0, 0))
			for i in 5:
				var a := TAU * i / 5.0 + 0.4
				Kit.leaf(m, v(cos(a) * 0.55, 0.05, sin(a) * 0.45), 0.2, "5aa83a", v(-50, rad_to_deg(a), 0))


# ------------------------------------------------------------------ generators

static func _grinder(m: ArtModel, l: int) -> void:
	var c := Kit.tier_col(l)
	m.box(v(0, -0.62, 0), v(0.5, 0.3, 0.46), 0.08, c).gloss(0.45)
	m.box(v(0, -0.62, 0.47), v(0.18, 0.12, 0.02), 0.04, Color(c).darkened(0.3)).sub(0.01, true)
	m.cyl(v(0, -0.25, 0), 0.32, 0.08, 0.04, Kit.SILVER if l < 5 else Kit.GOLD).k(0.02).gloss(0.9)
	m.cone(v(0, 0.12, 0), 0.24, 0.46, 0.3, 0.05, Kit.SILVER if l < 5 else Kit.GOLD).k(0.03).gloss(0.95)
	m.cyl(v(0, 0.42, 0), 0.4, 0.05, 0.0, "4a2a16").sub(0.01)
	for i in 4:
		bean(m, v(randf_range(-0.2, 0.2), 0.42, randf_range(-0.2, 0.2)), 0.35, v(randf_range(0, 90), randf_range(0, 360), 0))
	m.segment(v(0.0, 0.48, 0), v(0.38, 0.62, 0.1), 0.04, Kit.WOOD_DARK).k(0.02)
	m.sphere(v(0.42, 0.66, 0.1), 0.09, "e8553f").k(0.01).gloss(0.8)
	Kit.tier_trim(m, l, v(0, -0.32, 0), 0.46)


static func _flour_sack(m: ArtModel, l: int) -> void:
	var tie := Kit.tier_col(l)
	Kit.sack(m, v(0, -0.95, 0), 1.45, "f2e6cc", tie)
	# wheat stamp
	for i in 3:
		m.ell(v(-0.1 + i * 0.1, -0.15 + (0.08 if i == 1 else 0.0), 0.62), v(0.05, 0.12, 0.03), "e0a43a").rot_deg(v(0, 0, 20 - 20 * i)).paint(0.01)
	m.segment(v(0, -0.45, 0.66), v(0, -0.2, 0.66), 0.02, "c98a3a").paint(0.006)
	if l >= 2:
		m.box(v(0.35, -0.6, 0.55), v(0.12, 0.12, 0.05), 0.03, "c0473e" if l < 4 else Kit.GOLD).rot_deg(v(0, 40, 15)).paint(0.01)
	Kit.tier_trim(m, l, v(0, 0.22, 0), 0.32)


static func _net_barrel(m: ArtModel, l: int) -> void:
	var c := Kit.tier_col(l)
	m.cyl(v(0, -0.45, 0), 0.5, 0.45, 0.12, Kit.WOOD).gloss(0.3)
	m.ell(v(0, -0.45, 0), v(0.56, 0.3, 0.56), Kit.WOOD).k(0.2)
	for y in [-0.75, -0.15]:
		m.torus(v(0, y, 0), 0.52, 0.04, c).k(0.02).gloss(0.8)
	m.cyl(v(0, 0.0, 0), 0.42, 0.04, 0.0, "3a5a7a").sub(0.01)
	# net spilling over the rim
	for i in 9:
		var a := TAU * i / 9.0
		m.sphere(v(cos(a) * 0.38, 0.08 + randf() * 0.08, sin(a) * 0.38), 0.16, "e8dcc0").k(0.08).gloss(0.1)
	m.ell(v(0.45, -0.2, 0.3), v(0.18, 0.3, 0.1), "e8dcc0").k(0.08)
	m.sphere(v(-0.4, 0.25, 0.3), 0.16, "e8553f").gloss(0.8)
	m.torus(v(-0.4, 0.25, 0.3), 0.15, 0.03, "ffffff").rot_deg(v(70, 0, 20)).k(0.01)
	fish(m, v(0.15, 0.3, 0.1), 0.5, "4f9fe0", "e8f4ff", v(-20, -30, 40))
	Kit.tier_trim(m, l, v(0, -0.45, 0), 0.52)


static func _seed_tin(m: ArtModel, l: int) -> void:
	var c := Kit.tier_col(l)
	m.cyl(v(0, -0.4, 0), 0.5, 0.5, 0.08, c).gloss(0.8)
	m.cyl(v(0, -0.4, 0), 0.51, 0.26, 0.04, "fff3dc").paint(0.02)
	_sprout(m, v(0, -0.55, 0.5), 0.7)
	m.cyl(v(0.15, 0.2, -0.05), 0.52, 0.08, 0.05, Color(c).darkened(0.1)).rot_deg(v(0, 0, 18)).gloss(0.8)
	for i in 6:
		m.ell(v(randf_range(-0.3, 0.3), 0.12, randf_range(-0.3, 0.3)), v(0.05, 0.08, 0.04), "c98a46").rot_deg(v(90, 0, randf() * 180)).k(0.01)
	Kit.tier_trim(m, l, v(0, -0.82, 0), 0.5)


static func _planter(m: ArtModel, l: int) -> void:
	var c := Kit.tier_col(l + 1)
	Kit.crate(m, v(0, -0.95, 0), v(0.8, 0.32, 0.45), Kit.WOOD if l == 1 else c.to_html(false))
	m.box(v(0, -0.32, 0), v(0.74, 0.04, 0.4), 0.0, "5a3a22").sub(0.01, true)
	for i in 3:
		var x := -0.45 + i * 0.45
		for j in 5:
			var a := TAU * j / 5.0
			Kit.leaf(m, v(x + cos(a) * 0.12, -0.05 + randf() * 0.15, sin(a) * 0.1), 0.24, ["4fa83a", "6fc35a"][j % 2], v(randf_range(-20, 20), rad_to_deg(a), 35 * cos(a)))
	if l == 3:
		Kit.flower(m, v(0.45, 0.25, 0.1), 0.2, "ffffff", "ffd34a", 5, v(-40, 0, 0))
