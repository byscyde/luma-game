extends RefCounted
## 3D busts of the merge characters (customers, hosts) from PortraitArt.LOOKS:
## a stylised head with big glossy eyes, a hair style, clothes and an accessory,
## or an animal for the pets. Rendered by tools/bake_merge_art.gd.

const IRIS := ["6b4423", "3f7fb8", "4f8a4a", "6b4423", "3a2a1e", "2e2018"]


static func build(who: String) -> ArtModel:
	var look := PortraitArt.look_of(who)
	var m := ArtModel.new()
	m.cam_pos = Vector3(0, 0.35, 4.4)
	m.cam_target = Vector3(0, -0.02, 0)
	m.fov = 0.31
	m.bound = 1.75
	if look.has("animal"):
		_animal(m, str(look["animal"]))
		return m
	var skin := PortraitArt.SKIN[int(look.get("skin", 0))] as Color
	var hair := Color(str(look.get("hair_col", "3a2418")))
	var outfit := Color(str(look.get("outfit", "5b86b5")))
	var iris := Color(IRIS[absi(who.hash()) % IRIS.size()])
	var acc := str(look.get("acc", ""))
	var style := str(look.get("hair", "short"))
	_body(m, skin, outfit, acc)
	_head(m, skin, iris, hair, look)
	_hair(m, style, hair, skin)
	_accessory(m, acc, outfit, hair)
	return m


static func _body(m: ArtModel, skin: Color, outfit: Color, acc: String) -> void:
	# shoulders and chest; the bottom runs out of the frame
	m.cone(Vector3(0, -0.94, -0.05), 0.78, 0.5, 0.42, 0.22, outfit).gloss(0.12)
	m.ell(Vector3(0.5, -0.7, -0.06), Vector3(0.26, 0.2, 0.26), outfit).mirror().k(0.2).gloss(0.12)
	m.capsule(Vector3(0.72, -1.11, -0.04), 0.2, 0.16, outfit.darkened(0.04)).rot_deg(Vector3(0, 0, 10)).mirror().k(0.06).gloss(0.12)
	m.cyl(Vector3(0, -0.34, -0.04), 0.15, 0.2, 0.06, skin).k(0.08).gloss(0.2)
	# v-neck opening and collar
	m.cone(Vector3(0, -0.6, 0.3), 0.02, 0.17, 0.14, 0.01, skin).rot_deg(Vector3(-28, 0, 0)).k(0.03)
	m.ell(Vector3(0.13, -0.55, 0.22), Vector3(0.12, 0.05, 0.12), outfit.lightened(0.25)).rot_deg(Vector3(0, 0, -38)).mirror().k(0.02).gloss(0.15)
	if acc == "apron":
		m.box(Vector3(0, -1.05, 0.4), Vector3(0.28, 0.38, 0.3), 0.12, "fffaf0").paint(0.01)
		m.capsule(Vector3(0.26, -0.58, 0.18), 0.1, 0.035, "fffaf0").rot_deg(Vector3(0, 0, 20)).mirror().k(0.02)


static func _head(m: ArtModel, skin: Color, iris: Color, hair: Color, look: Dictionary) -> void:
	var lip := skin.darkened(0.12)
	m.sphere(Vector3(0, 0.26, 0), 0.5, skin).gloss(0.22)
	m.ell(Vector3(0, 0.06, 0.08), Vector3(0.38, 0.34, 0.37), skin).k(0.16)
	m.ell(Vector3(0.48, 0.2, -0.02), Vector3(0.07, 0.11, 0.06), skin).mirror().k(0.04)
	m.ell(Vector3(0.5, 0.2, 0.01), Vector3(0.03, 0.06, 0.03), lip).mirror().sub(0.02)
	# cheeks
	m.ell(Vector3(0.25, 0.06, 0.36), Vector3(0.1, 0.07, 0.08), Color("ff8f88").lerp(skin, 0.35)).mirror().paint(0.06)
	# nose
	m.ell(Vector3(0, 0.15, 0.47), Vector3(0.055, 0.06, 0.05), skin.darkened(0.04)).k(0.04)
	# mouth: open smile with teeth
	m.ell(Vector3(0, 0.0, 0.43), Vector3(0.15, 0.085, 0.1), "5e1f1c").sub(0.012)
	m.box(Vector3(0, 0.045, 0.38), Vector3(0.11, 0.025, 0.06), 0.018, "ffffff").k(0.0).gloss(0.6)
	m.ell(Vector3(0, -0.06, 0.39), Vector3(0.08, 0.035, 0.06), "e0706a").k(0.0)
	m.ell(Vector3(0, 0.1, 0.43), Vector3(0.19, 0.05, 0.1), skin).k(0.025)
	# eyes: big glossy balls with an iris, a pupil, two catch lights and a dark upper lash line
	var e := Vector3(0.175, 0.27, 0.39)
	m.ell(e, Vector3(0.105, 0.13, 0.08), "ffffff").mirror().gloss(0.85)
	m.ell(e + Vector3(-0.004, -0.012, 0.064), Vector3(0.078, 0.096, 0.03), iris).mirror().gloss(0.95)
	m.ell(e + Vector3(-0.004, -0.012, 0.088), Vector3(0.042, 0.052, 0.014), "141016").mirror().gloss(1.0)
	m.sphere(e + Vector3(-0.03, 0.03, 0.098), 0.022, "ffffff").mirror()
	m.sphere(e + Vector3(0.025, -0.04, 0.094), 0.01, "ffffff").mirror()
	m.begin()
	m.ell(e + Vector3(0, 0.004, 0.004), Vector3(0.115, 0.14, 0.085), "231614").mirror().gloss(0.3)
	m.plane(e + Vector3(0, 0.102, 0)).rot_deg(Vector3(190, 0, 0)).inter(0.006)
	m.end(0.006)
	# brows
	m.begin()
	m.torus(Vector3(0.18, 0.33, 0.455), 0.12, 0.022, hair.darkened(0.2)).rot_deg(Vector3(80, 0, 0)).mirror().gloss(0.2)
	m.plane(Vector3(0, 0.42, 0)).rot_deg(Vector3(180, 0, 0)).inter(0.0)
	m.end(0.01)
	if look.has("beard"):
		var b := Color(str(look["beard"]))
		m.begin()
		m.ell(Vector3(0, -0.06, 0.18), Vector3(0.44, 0.38, 0.36), b).gloss(0.15)
		m.ell(Vector3(0, 0.1, 0.4), Vector3(0.3, 0.2, 0.3), "000000").sub(0.06, true)
		m.ell(Vector3(0, -0.02, 0.48), Vector3(0.13, 0.08, 0.08), "6e2622").sub(0.01)
		m.plane(Vector3(0, 0.06, 0)).inter(0.05)
		m.end(0.03)
	if look.has("moustache"):
		var mc := Color(str(look["moustache"]))
		m.ell(Vector3(0.07, 0.06, 0.47), Vector3(0.08, 0.035, 0.04), mc).rot_deg(Vector3(0, 0, -12)).mirror().k(0.02).gloss(0.2)


static func _cap(m: ArtModel, hair: Color, low := 0.2, back := 0.0) -> void:
	# the hair cap: a shell over the skull, cut away over the face
	m.sphere(Vector3(0, 0.3, -0.04 - back), 0.545, hair).gloss(0.45)
	m.plane(Vector3(0, low, 0.0)).rot_deg(Vector3(180 - 38, 0, 0)).inter(0.05)


static func _hair(m: ArtModel, style: String, hair: Color, skin: Color) -> void:
	if style == "bald":
		m.ell(Vector3(0.45, 0.3, -0.12), Vector3(0.1, 0.13, 0.16), hair).mirror().k(0.05).gloss(0.3)
		return
	m.begin()
	match style:
		"short", "grey":
			_cap(m, hair, 0.28)
			m.ell(Vector3(-0.12, 0.62, 0.3), Vector3(0.26, 0.11, 0.16), hair).rot_deg(Vector3(0, 0, -14)).k(0.06)
		"spiky":
			_cap(m, hair, 0.3)
			for i in 6:
				var a := deg_to_rad(-70 + i * 28)
				m.taper(Vector3(sin(a) * 0.32, 0.78 + cos(a) * 0.05, 0.06), 0.14, 0.02, 0.14, hair).rot_deg(Vector3(-20, 0, -rad_to_deg(a) * 0.8)).k(0.05)
		"bob":
			_cap(m, hair, 0.18)
			m.ell(Vector3(0.4, 0.12, -0.02), Vector3(0.2, 0.36, 0.34), hair).mirror().k(0.12)
			m.ell(Vector3(0, 0.6, 0.34), Vector3(0.36, 0.13, 0.14), hair).k(0.08)
			m.ell(Vector3(0, 0.15, 0.6), Vector3(0.5, 0.6, 0.2), "000000").sub(0.08, true)
		"bun":
			_cap(m, hair, 0.26)
			m.sphere(Vector3(0, 0.86, -0.12), 0.21, hair).k(0.06)
			m.torus(Vector3(0, 0.78, -0.08), 0.12, 0.04, hair.darkened(0.2)).rot_deg(Vector3(-20, 0, 0)).k(0.02)
		"long", "wavy":
			_cap(m, hair, 0.2)
			m.ell(Vector3(0, -0.2, -0.25), Vector3(0.55, 0.75, 0.3), hair).k(0.12)
			m.ell(Vector3(0.43, -0.12, 0.05), Vector3(0.14, 0.55, 0.2), hair).mirror().k(0.1)
			if style == "wavy":
				for i in 4:
					m.sphere(Vector3(0.47, 0.25 - i * 0.2, 0.08), 0.1, hair).mirror().k(0.08)
			m.ell(Vector3(-0.1, 0.6, 0.33), Vector3(0.32, 0.13, 0.15), hair).rot_deg(Vector3(0, 0, -18)).k(0.07)
		"curly":
			_cap(m, hair, 0.24)
			for i in 11:
				var a := deg_to_rad(-100 + i * 20)
				m.sphere(Vector3(sin(a) * 0.5, 0.36 + cos(a) * 0.4, -0.02 + 0.08 * cos(a)), 0.16, hair).k(0.05)
		"ponytail":
			_cap(m, hair, 0.24)
			m.sphere(Vector3(0, 0.6, -0.42), 0.15, hair).k(0.06)
			m.taper(Vector3(0, 0.2, -0.6), 0.16, 0.06, 0.32, hair).rot_deg(Vector3(-25, 0, 0)).k(0.06)
			m.ell(Vector3(-0.1, 0.6, 0.33), Vector3(0.3, 0.12, 0.15), hair).rot_deg(Vector3(0, 0, -16)).k(0.07)
		"braids":
			_cap(m, hair, 0.22)
			for i in 5:
				m.sphere(Vector3(0.42, 0.05 - i * 0.14, -0.02 + i * 0.02), 0.095 - i * 0.007, hair).mirror().k(0.03)
			m.ell(Vector3(0, 0.6, 0.33), Vector3(0.34, 0.12, 0.15), hair).k(0.07)
		_:
			_cap(m, hair, 0.28)
	m.end(0.02)


static func _accessory(m: ArtModel, acc: String, outfit: Color, hair: Color) -> void:
	match acc:
		"chef":
			m.cyl(Vector3(0, 0.78, -0.06), 0.42, 0.13, 0.06, "fbfbf8").rot_deg(Vector3(-12, 0, 0)).gloss(0.2)
			for p in [Vector3(-0.24, 1.0, -0.1), Vector3(0.24, 1.0, -0.1), Vector3(0, 1.08, -0.08), Vector3(0, 0.98, 0.12)]:
				m.sphere(p, 0.26, "ffffff").k(0.1).gloss(0.15)
		"cap":
			m.begin()
			m.sphere(Vector3(0, 0.36, -0.03), 0.53, outfit).gloss(0.3)
			m.plane(Vector3(0, 0.44, 0)).rot_deg(Vector3(168, 0, 0)).inter(0.02)
			m.end(0.01)
			m.cyl(Vector3(0, 0.48, 0.42), 0.3, 0.025, 0.02, outfit.darkened(0.15)).rot_deg(Vector3(14, 0, 0)).k(0.02)
			m.sphere(Vector3(0, 0.9, -0.02), 0.05, outfit.lightened(0.2)).k(0.01)
		"tie":
			m.box(Vector3(0, -0.85, 0.36), Vector3(0.07, 0.2, 0.03), 0.03, "c0473e").rot_deg(Vector3(-15, 0, 0)).k(0.01).gloss(0.4)
		"scarf":
			m.torus(Vector3(0, -0.52, 0.0), 0.22, 0.1, "e0533f").rot_deg(Vector3(10, 0, 0)).k(0.03).gloss(0.1)
			m.ell(Vector3(0.12, -0.78, 0.3), Vector3(0.09, 0.2, 0.06), "e0533f").rot_deg(Vector3(0, 0, 12)).k(0.04)
		"glasses":
			m.torus(Vector3(0.165, 0.28, 0.5), 0.12, 0.018, "2a2a35").rot_deg(Vector3(90, 0, 0)).mirror().gloss(0.7)
			m.capsule(Vector3(0, 0.3, 0.52), 0.05, 0.015, "2a2a35").rot_deg(Vector3(0, 0, 90)).gloss(0.7)
		"goggles":
			m.torus(Vector3(0, 0.6, -0.02), 0.5, 0.035, "4a3a2a").rot_deg(Vector3(-14, 0, 0)).k(0.01)
			m.cyl(Vector3(0.15, 0.66, 0.42), 0.11, 0.05, 0.03, "c98a3a").rot_deg(Vector3(70, 0, 0)).mirror().gloss(0.8)
			m.cyl(Vector3(0.15, 0.67, 0.47), 0.08, 0.02, 0.01, "9fe0f0").rot_deg(Vector3(70, 0, 0)).mirror().gloss(1.0)
		"bandana":
			m.begin()
			m.sphere(Vector3(0, 0.34, -0.03), 0.535, "d9473a").gloss(0.15)
			m.plane(Vector3(0, 0.5, 0)).rot_deg(Vector3(162, 0, 0)).inter(0.02)
			m.end(0.01)
			m.sphere(Vector3(0.36, 0.42, -0.3), 0.09, "d9473a").k(0.03)
			for p in [Vector3(0.1, 0.72, 0.36), Vector3(-0.2, 0.68, 0.34), Vector3(0.3, 0.6, 0.3)]:
				m.sphere(p, 0.025, "ffffff").paint(0.004)
		"headband":
			m.torus(Vector3(0, 0.54, -0.02), 0.5, 0.045, "e0a43a").rot_deg(Vector3(-16, 0, 0)).k(0.01).gloss(0.3)
		"flower":
			var fc := Vector3(-0.42, 0.52, 0.18)
			for i in 5:
				var a := TAU * i / 5.0
				m.sphere(fc + Vector3(cos(a), sin(a), 0) * 0.08, 0.065, "ff8fb1").k(0.01).gloss(0.4)
			m.sphere(fc + Vector3(0, 0, 0.04), 0.045, "ffd34a").k(0.01)
		"earrings":
			m.sphere(Vector3(0.5, 0.05, 0.0), 0.04, "ffd75a").mirror().gloss(0.9)


static func _animal(m: ArtModel, kind: String) -> void:
	m.cam_target = Vector3(0, -0.05, 0)
	match kind:
		"otter":
			var f := Color("8a5a3a")
			m.ell(Vector3(0, -0.85, 0), Vector3(0.62, 0.55, 0.45), f).gloss(0.2)
			m.ell(Vector3(0, -0.8, 0.28), Vector3(0.36, 0.4, 0.2), "e8cfa8").paint(0.03)
			m.sphere(Vector3(0, 0.15, 0), 0.5, f).k(0.15).gloss(0.2)
			m.ell(Vector3(0, 0.0, 0.32), Vector3(0.3, 0.22, 0.22), "e8cfa8").k(0.06)
			m.sphere(Vector3(0.38, 0.52, 0.0), 0.11, f).mirror().k(0.04)
			m.ell(Vector3(0, 0.08, 0.53), Vector3(0.09, 0.06, 0.05), "2a1a14").k(0.02).gloss(0.9)
			_eyes(m, Vector3(0.18, 0.25, 0.4), 0.07)
			m.capsule(Vector3(0.18, -0.02, 0.5), 0.06, 0.006, "f0e8dc").rot_deg(Vector3(0, 0, 80)).mirror()
		"crab":
			var r := Color("e8553f")
			m.ell(Vector3(0, -0.35, 0), Vector3(0.8, 0.45, 0.55), r).gloss(0.45)
			for sd in [-1.0, 1.0]:
				m.segment(Vector3(0.6 * sd, -0.25, 0.2), Vector3(0.85 * sd, 0.15, 0.25), 0.1, r).k(0.05)
				m.sphere(Vector3(0.9 * sd, 0.38, 0.25), 0.24, r).k(0.06).gloss(0.5)
				m.ell(Vector3(0.98 * sd, 0.55, 0.32), Vector3(0.12, 0.2, 0.1), "000000").sub(0.02, true)
			for sd in [-1.0, 1.0]:
				m.capsule(Vector3(0.18 * sd, 0.18, 0.15), 0.12, 0.045, r).k(0.04)
			_eyes(m, Vector3(0.18, 0.38, 0.15), 0.11)
			m.ell(Vector3(0, -0.22, 0.52), Vector3(0.14, 0.05, 0.05), "6e2622").sub(0.01)
		"owl":
			var f := Color("9a7a5a")
			m.ell(Vector3(0, -0.45, 0), Vector3(0.7, 0.95, 0.55), f).gloss(0.2)
			m.ell(Vector3(0, -0.6, 0.35), Vector3(0.45, 0.6, 0.25), "e8dcc0").paint(0.04)
			m.cone(Vector3(0.42, 0.55, 0), 0.14, 0.02, 0.16, 0.02, f).rot_deg(Vector3(0, 0, -22)).mirror().k(0.06)
			m.sphere(Vector3(0.22, 0.12, 0.38), 0.22, "f2ead6").mirror().k(0.03)
			_eyes(m, Vector3(0.22, 0.12, 0.52), 0.13, "f2b632")
			m.cone(Vector3(0, -0.04, 0.6), 0.06, 0.01, 0.08, 0.01, "e8a33a").rot_deg(Vector3(200, 0, 0)).k(0.02)
		"parrot":
			var g := Color("3fb35a")
			m.ell(Vector3(0, -0.55, -0.05), Vector3(0.6, 0.8, 0.5), g).gloss(0.35)
			m.sphere(Vector3(0, 0.25, 0), 0.46, g).k(0.15).gloss(0.35)
			m.ell(Vector3(0, -0.6, 0.3), Vector3(0.38, 0.5, 0.2), "f2c94a").paint(0.06)
			m.ell(Vector3(0.24, 0.24, 0.32), Vector3(0.16, 0.14, 0.12), "ffffff").mirror().k(0.02)
			_eyes(m, Vector3(0.22, 0.28, 0.4), 0.09)
			m.taper(Vector3(0, 0.02, 0.55), 0.13, 0.03, 0.12, "f2a03a").rot_deg(Vector3(110, 0, 0)).k(0.03).gloss(0.6)
			for i in 3:
				m.ell(Vector3(-0.05 + i * 0.05, 0.75 + i * 0.03, -0.1), Vector3(0.05, 0.18, 0.05), ["e8553f", "f2c94a", "3f8fe0"][i]).rot_deg(Vector3(0, 0, 20 - i * 20)).k(0.03)
		"tortoise":
			m.ell(Vector3(0, -0.6, -0.2), Vector3(0.85, 0.55, 0.6), "6f8a3a").gloss(0.4)
			for i in 5:
				var a := TAU * i / 5.0
				m.ell(Vector3(cos(a) * 0.4, -0.25 + sin(a) * 0.15, 0.1 + sin(a) * 0.08), Vector3(0.2, 0.12, 0.14), "8fae4a").paint(0.03)
			m.sphere(Vector3(0, 0.15, 0.25), 0.38, "a8c070").k(0.08).gloss(0.25)
			_eyes(m, Vector3(0.15, 0.28, 0.55), 0.09)
			m.ell(Vector3(0, 0.05, 0.6), Vector3(0.12, 0.04, 0.04), "4a3a2a").sub(0.01)
		"moth":
			var b := Color("b9a8e8")
			for sd in [-1.0, 1.0]:
				m.ell(Vector3(0.62 * sd, -0.1, -0.25), Vector3(0.48, 0.62, 0.08), "d9cff8").rot_deg(Vector3(0, 0, 20 * sd)).gloss(0.4)
				m.sphere(Vector3(0.66 * sd, 0.05, -0.15), 0.12, "8f7ad0").paint(0.02)
			m.ell(Vector3(0, -0.6, 0), Vector3(0.38, 0.6, 0.35), b).k(0.05).gloss(0.2)
			m.sphere(Vector3(0, 0.15, 0.05), 0.38, "efe8ff").k(0.1).gloss(0.2)
			_eyes(m, Vector3(0.15, 0.2, 0.36), 0.1)
			for sd in [-1.0, 1.0]:
				m.segment(Vector3(0.1 * sd, 0.45, 0.1), Vector3(0.3 * sd, 0.85, 0.15), 0.025, "6b5a8a").k(0.02)
				m.sphere(Vector3(0.3 * sd, 0.87, 0.15), 0.06, "6b5a8a").k(0.02)


static func _eyes(m: ArtModel, p: Vector3, r: float, iris := "2a1a14") -> void:
	m.ell(p, Vector3(r, r * 1.15, r * 0.7), "ffffff").mirror().gloss(0.85)
	m.ell(p + Vector3(0, -r * 0.05, r * 0.45), Vector3(r * 0.66, r * 0.8, r * 0.35), iris).mirror().gloss(0.95)
	m.sphere(p + Vector3(-r * 0.25, r * 0.3, r * 0.75), r * 0.2, "ffffff").mirror()
