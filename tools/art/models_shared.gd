extends RefCounted
## Items every merge location shares (coins, gems, energy, chests, scissors) and the
## UI icons (XP star, currency coin, mystery crate).

const Kit := preload("res://tools/art/kit.gd")


static func v(x: float, y: float, z: float) -> Vector3:
	return Vector3(x, y, z)


static func keys() -> Array:
	var out := ["star:1", "coin:1", "crate:1", "scissors:1"]
	for i in 5:
		out.append("coins:%d" % (i + 1))
		out.append("energy:%d" % (i + 1))
	for i in 4:
		out.append("gems:%d" % (i + 1))
	for i in 3:
		out.append("chest:%d" % (i + 1))
	return out


static func build(key: String) -> ArtModel:
	var m := ArtModel.new()
	seed(key.hash())
	var chain := key.get_slice(":", 0)
	var lvl := int(key.get_slice(":", 1))
	match chain:
		"star":
			Kit.star(m, v(0, 0.02, 0), 0.95, "ffcf2e", 0.22)
			m.cam_pos = v(0, 0.4, 3.6)
		"coin":
			_coin(m, v(0, 0, 0), 0.82, v(0, 0, 0))
			m.cam_pos = v(0, 0.5, 3.6)
		"coins":
			match lvl:
				1:
					_coin(m, v(0, 0, 0), 0.7, v(10, -15, 0))
				2:
					for i in 4:
						_coin_flat(m, v(-0.12, -0.45 + i * 0.17, 0.0), 0.55)
					_coin(m, v(0.38, -0.05, 0.3), 0.42, v(15, -20, 8))
				3:
					_pouch(m, v(0, -0.85, 0), 1.25)
				4:
					_chest(m, 1, true)
				5:
					for p in [v(0, -0.55, 0), v(-0.45, -0.6, 0.2), v(0.45, -0.6, 0.15)]:
						m.ell(p, v(0.55, 0.32, 0.45), "f2b52a").k(0.15).gloss(0.6)
					for p in [v(-0.3, -0.25, 0.42), v(0.2, -0.18, 0.45), v(0.5, -0.38, 0.4), v(-0.6, -0.42, 0.38), v(0, 0.05, 0.25)]:
						_coin(m, p, 0.24, v(randf_range(-30, 30), randf_range(-40, 40), randf_range(-30, 30)))
					m.ell(v(-0.05, 0.25, 0.1), v(0.2, 0.22, 0.2), "3fd0e0").gloss(1.0)
					_gem(m, v(0.35, -0.02, 0.38), 0.18, "e84a7a")
					m.cyl(v(-0.4, 0.05, -0.15), 0.18, 0.2, 0.05, "e0a43a").rot_deg(v(0, 0, 25)).gloss(0.8)
		"gems":
			match lvl:
				1:
					_gem(m, v(0, -0.05, 0), 0.92, "2fd0c8")
				2:
					_gem(m, v(-0.36, 0.05, -0.15), 0.62, "2fd0c8")
					_gem(m, v(0.4, -0.2, 0.2), 0.56, "8f6bff")
				3:
					for g in [[v(0, 0.1, -0.15), 0.6, "2fd0c8"], [v(-0.55, -0.25, 0.15), 0.44, "8f6bff"], [v(0.55, -0.22, 0.12), 0.46, "e84a7a"], [v(0.05, -0.38, 0.45), 0.36, "4fc35f"]]:
						_gem(m, g[0], g[1], g[2])
					m.ell(v(0, -0.7, 0), v(0.8, 0.14, 0.5), "a0a8b8").k(0.1).gloss(0.3)
				4:
					# a gold crown with points, pearls and gems
					m.begin()
					m.cyl(v(0, -0.35, 0), 0.7, 0.28, 0.06, Kit.GOLD).gloss(0.95)
					m.cyl(v(0, -0.2, 0), 0.6, 0.5, 0.0, "c98a12").sub(0.02)
					m.end(0.0)
					for i in 8:
						var a := TAU * i / 8.0
						m.cone(v(cos(a) * 0.64, 0.12, sin(a) * 0.64), 0.2, 0.04, 0.26, 0.04, Kit.GOLD).k(0.05).gloss(0.95)
						m.sphere(v(cos(a) * 0.64, 0.42, sin(a) * 0.64), 0.07, "fff8f0").k(0.01).gloss(1.0)
					_gem(m, v(0, -0.32, 0.7), 0.2, "e84a7a")
					_gem(m, v(0.5, -0.32, 0.5), 0.14, "2fd0c8")
					_gem(m, v(-0.5, -0.32, 0.5), 0.14, "4fc35f")
					m.cam_pos = v(0, 1.4, 3.4)
		"energy":
			match lvl:
				1:
					m.sphere(v(0, -0.25, 0), 0.5, "4fd35f").gloss(0.95)
					m.cone(v(0, 0.32, 0), 0.4, 0.02, 0.32, 0.02, "4fd35f").k(0.15).gloss(0.95)
					_bolt(m, v(0, -0.22, 0.5), 0.5)
				2:
					Kit.bottle(m, v(0, -0.9, 0), 1.6, "4fd35f", "e0a43a")
					_bolt(m, v(0, -0.32, 0.5), 0.6)
				3:
					m.ell(v(0, -0.3, 0), v(0.62, 0.6, 0.55), "4fd35f").gloss(0.95)
					m.cyl(v(0, 0.38, 0), 0.24, 0.16, 0.06, "4fd35f").k(0.1).gloss(0.95)
					m.torus(v(0.55, -0.2, 0), 0.24, 0.07, "3fae4f").rot_deg(v(90, 0, 0)).k(0.04).gloss(0.9)
					m.cyl(v(0, 0.58, 0), 0.22, 0.06, 0.03, "e0a43a").k(0.01)
					_bolt(m, v(0, -0.28, 0.58), 0.6)
				4:
					m.cyl(v(0, -0.25, 0), 0.62, 0.6, 0.2, "4fd35f").gloss(0.8)
					m.ell(v(0, -0.25, 0), v(0.7, 0.3, 0.7), "4fd35f").k(0.25)
					for y in [-0.7, 0.2]:
						m.torus(v(0, y, 0), 0.63, 0.05, "8a5a32").k(0.02).gloss(0.4)
					_bolt(m, v(0, -0.25, 0.7), 0.6)
				5:
					m.cyl(v(0, -0.65, 0), 0.85, 0.15, 0.08, "c9d3dd").gloss(0.6)
					m.cyl(v(0, -0.55, 0), 0.72, 0.08, 0.0, "4fd35f").sub(0.02, false)
					m.cyl(v(0, -0.6, 0), 0.72, 0.03, 0.0, "6fe87a").k(0.01).gloss(1.0)
					m.cyl(v(0, -0.2, 0), 0.12, 0.35, 0.04, "c9d3dd").k(0.05)
					m.cyl(v(0, 0.18, 0), 0.4, 0.06, 0.04, "c9d3dd").k(0.05)
					for i in 6:
						var a := TAU * i / 6.0
						m.sphere(v(cos(a) * 0.5, 0.0 - 0.3 * 0.0, sin(a) * 0.5) + v(0, -0.15, 0), 0.08, "6fe87a").gloss(1.0)
					m.sphere(v(0, 0.48, 0), 0.24, "6fe87a").gloss(1.0)
					_bolt(m, v(0, 0.48, 0.24), 0.2)
		"chest":
			_chest(m, lvl, false)
		"scissors":
			for sd in [-1.0, 1.0]:
				m.torus(v(0.28 * sd, -0.5, 0), 0.2, 0.07, "e8553f").rot_deg(v(90, 0, 0)).gloss(0.6)
				m.taper(v(0.12 * sd, 0.2, 0.03 * sd), 0.09, 0.03, 0.42, Kit.SILVER).rot_deg(v(0, 0, -16 * sd)).gloss(0.95)
			m.cyl(v(0, -0.18, 0.07), 0.06, 0.06, 0.02, "8a8a95").rot_deg(v(90, 0, 0)).gloss(0.9)
			m.cam_pos = v(0, 0.3, 3.6)
		"crate":
			Kit.crate(m, v(0, -0.7, 0), v(0.66, 0.62, 0.6))
			m.box(v(0, 0.0, 0.62), v(0.24, 0.24, 0.02), 0.05, "fff3dc").k(0.01)
			m.ell(v(0, 0.0, 0.63), v(0.08, 0.13, 0.03), "e0a43a").k(0.01)
	return m


static func _coin(m: ArtModel, p: Vector3, r: float, rot: Vector3) -> void:
	var b := Basis.from_euler(rot * PI / 180.0)
	var face := b * Vector3(0, 0, 1)
	m.cyl(p, r, r * 0.13, r * 0.06, "ffc634").rot_deg(rot + v(90, 0, 0)).gloss(0.95)
	m.cyl(p + face * r * 0.15, r * 0.76, r * 0.05, r * 0.02, "f0a818").rot_deg(rot + v(90, 0, 0)).sub(r * 0.03)
	Kit.star(m, p + face * r * 0.09, r * 0.6, "ffd75a", 0.12, rot)


static func _coin_flat(m: ArtModel, p: Vector3, r: float) -> void:
	m.cyl(p, r, r * 0.13, r * 0.06, "ffc634").gloss(0.9)
	m.torus(p, r * 0.98, r * 0.04, "f0a818").k(0.01)


static func _gem(m: ArtModel, p: Vector3, r: float, col) -> void:
	# a brilliant cut: crown and pavilion with flat facets
	m.begin()
	m.cone(p + v(0, r * 0.22, 0), r, r * 0.62, r * 0.22, r * 0.03, col).gloss(1.0)
	m.cone(p + v(0, -r * 0.4, 0), r * 0.04, r, r * 0.42, r * 0.02, col).k(r * 0.02).gloss(1.0)
	for i in 8:
		var a := TAU * (i + 0.5) / 8.0
		var up := Vector3(cos(a) * 0.62, 0.78, sin(a) * 0.62).normalized()
		m.plane(p + v(0, r * 0.3, 0) + up * r * 0.3).along(up).inter(0.0)
		var dn := Vector3(cos(a + PI / 8) * 0.8, -0.6, sin(a + PI / 8) * 0.8).normalized()
		m.plane(p + v(0, r * 0.0, 0) + dn * r * 0.62).along(dn).inter(0.0)
	m.end(0.0)
	m.sphere(p + v(-r * 0.25, r * 0.36, r * 0.3), r * 0.12, "ffffff").paint(r * 0.04)


static func _bolt(m: ArtModel, p: Vector3, s: float) -> void:
	# a chunky lightning bolt: two slanted blades offset sideways, joined by a step
	var c := "fff7b0"
	m.begin()
	m.box(p + v(0.16, 0.3, 0) * s, v(0.12, 0.32, 0.08) * s, 0.05 * s, c).rot_deg(v(0, 0, -28)).gloss(0.9)
	m.box(p + v(0.0, 0.0, 0) * s, v(0.3, 0.09, 0.08) * s, 0.05 * s, c).rot_deg(v(0, 0, 10)).gloss(0.9)
	m.box(p + v(-0.16, -0.3, 0) * s, v(0.12, 0.32, 0.08) * s, 0.05 * s, c).rot_deg(v(0, 0, -28)).gloss(0.9)
	m.end(0.015 * s)


static func _pouch(m: ArtModel, p: Vector3, s: float) -> void:
	Kit.sack(m, p, s * 1.05, "8a5a9a", "ffc634")
	for i in 3:
		_coin(m, p + v(-0.25 + 0.25 * i, 1.0 + (0.08 if i == 1 else 0.0), 0.05) * s, 0.2 * s, v(-20, 0, -15 + 15 * i))
	_coin(m, p + v(0.35, 0.3, 0.42) * s, 0.24 * s, v(0, -20, 0))


static func _chest(m: ArtModel, lvl: int, coins: bool) -> void:
	var body := Color(["a8703c", "a8703c", "a8703c"][clampi(lvl - 1, 0, 2)])
	var trim := Color([Kit.WOOD_DARK, Kit.SILVER, Kit.GOLD][clampi(lvl - 1, 0, 2)])
	if lvl == 3:
		body = Color("c0473e")
	elif lvl == 2:
		body = Color("4f6fb0")
	m.box(v(0, -0.45, 0), v(0.78, 0.32, 0.5), 0.06, body).gloss(0.3)
	m.begin()
	m.cyl(v(0, -0.1, 0), 0.5, 0.78, 0.06, body).rot_deg(v(0, 0, 90)).gloss(0.35)
	m.plane(v(0, -0.12, 0)).rot_deg(v(180, 0, 0)).inter(0.0)
	m.end(0.0)
	for x in [-0.52, 0.52]:
		m.box(v(x, -0.4, 0), v(0.07, 0.4, 0.53), 0.03, trim).k(0.01).gloss(0.85)
		m.begin()
		m.torus(v(x, -0.1, 0), 0.5, 0.06, trim).rot_deg(v(0, 0, 90)).gloss(0.85)
		m.plane(v(0, -0.12, 0)).rot_deg(v(180, 0, 0)).inter(0.0)
		m.end(0.01)
	m.box(v(0, -0.1, 0.0), v(0.8, 0.03, 0.52), 0.02, Color(trim).darkened(0.2)).k(0.01)
	m.box(v(0, -0.18, 0.53), v(0.12, 0.15, 0.04), 0.04, trim).k(0.01).gloss(0.9)
	m.ell(v(0, -0.2, 0.58), v(0.03, 0.05, 0.02), "2a1a14").sub(0.005)
	if coins:
		for p in [v(-0.3, 0.42, 0.1), v(0.05, 0.5, 0.15), v(0.35, 0.4, 0.05)]:
			_coin(m, p, 0.24, v(-30, randf_range(-20, 20), randf_range(-20, 20)))
	m.cam_pos = v(0, 1.2, 3.6)
