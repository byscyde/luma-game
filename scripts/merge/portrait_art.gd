class_name PortraitArt
extends RefCounted
## Procedural character portraits for the merge locations (order cards, dialogue,
## tasks): a bust in a round frame — skin, hair style, eyes, smile, clothes and an
## accessory per character, or an animal for the pets. IconBaker gives them the same
## lit "3D" finish as the items. Unknown ids get a look derived from the id.

const SKIN := [Color("f6d3b3"), Color("eabf98"), Color("d49a6a"), Color("b07447"), Color("8a5634"), Color("5e3a22")]
const OUT := Color("4a2f24")

## who -> look. hair: bob, bun, long, short, curly, bald, ponytail, braids, spiky, wavy, grey
const LOOKS := {
	"nell": {"skin": 0, "hair": "bob", "hair_col": "c0602e", "outfit": "e8875f", "acc": "apron"},
	"tobias": {"skin": 1, "hair": "bald", "hair_col": "d8d4cc", "outfit": "3d6fb0", "acc": "cap", "beard": "d8d4cc"},
	"ada": {"skin": 3, "hair": "bun", "hair_col": "3a2418", "outfit": "d7a33f", "acc": "chef"},
	"rafe": {"skin": 0, "hair": "short", "hair_col": "6b5a4a", "outfit": "7d5ba6", "acc": "tie", "moustache": "6b5a4a"},
	"juno": {"skin": 4, "hair": "curly", "hair_col": "2a1a12", "outfit": "4fa37a", "acc": "glasses"},
	"pip": {"animal": "otter"},
	"marisol": {"skin": 2, "hair": "ponytail", "hair_col": "2a1a12", "outfit": "e8744f", "acc": "bandana"},
	"kai": {"skin": 3, "hair": "spiky", "hair_col": "1d1d22", "outfit": "3f9fbf", "acc": "goggles"},
	"ula": {"skin": 4, "hair": "grey", "hair_col": "e6e2da", "outfit": "8a6fb0", "acc": "flower"},
	"sparky": {"animal": "crab"},
	"isolde": {"skin": 0, "hair": "braids", "hair_col": "e8c25a", "outfit": "f2c14e", "acc": "scarf"},
	"bram": {"skin": 1, "hair": "wavy", "hair_col": "8a4a22", "outfit": "5b86b5", "acc": "goggles", "beard": "8a4a22"},
	"wick": {"animal": "owl"},
	"hana": {"skin": 1, "hair": "bun", "hair_col": "1d1d22", "outfit": "6f9a4a", "acc": "flower"},
	"toma": {"skin": 2, "hair": "short", "hair_col": "2a1a12", "outfit": "b4643c", "acc": "headband"},
	"pebble": {"animal": "tortoise"},
	"vesna": {"skin": 0, "hair": "long", "hair_col": "6b3a26", "outfit": "7d5ba6", "acc": "earrings"},
	"ines": {"skin": 2, "hair": "wavy", "hair_col": "3a2418", "outfit": "5b86b5", "acc": "earrings"},
	"marek": {"skin": 1, "hair": "short", "hair_col": "c9a265", "outfit": "c0473e", "acc": "", "beard": "c9a265"},
	"kiki": {"animal": "parrot"},
	"luna": {"skin": 5, "hair": "curly", "hair_col": "1d1d22", "outfit": "7d5ba6", "acc": "chef"},
	"silas": {"skin": 0, "hair": "grey", "hair_col": "9a9a9a", "outfit": "5a5f7a", "acc": "glasses", "moustache": "9a9a9a"},
	"dusk": {"animal": "moth"},
}


static func look_of(who: String) -> Dictionary:
	if LOOKS.has(who):
		return LOOKS[who]
	var h := who.hash()
	var hairs := ["bob", "short", "long", "curly", "ponytail", "wavy", "bun"]
	var cols := ["2a1a12", "6b3a26", "c0602e", "e8c25a", "1d1d22", "8a4a22"]
	var outfits := ["e8875f", "3d6fb0", "4fa37a", "d7a33f", "7d5ba6", "c0473e"]
	return {"skin": absi(h) % SKIN.size(), "hair": hairs[absi(h >> 3) % hairs.size()], "hair_col": cols[absi(h >> 6) % cols.size()],
		"outfit": outfits[absi(h >> 9) % outfits.size()], "acc": ""}


static func draw(ci: CanvasItem, who: String, r: Rect2, ring := Color(0, 0, 0, 0)) -> void:
	var s := minf(r.size.x, r.size.y)
	if s < 8.0:
		return
	var c := r.get_center()
	var rad := s * 0.5
	var look := look_of(who)
	var bg := Color(str(look.get("outfit", "88aacc"))).lightened(0.55) if not look.has("animal") else _animal_bg(str(look["animal"]))
	ci.draw_circle(c, rad, bg.darkened(0.08), true, -1, true)
	ci.draw_circle(c + Vector2(-rad * 0.12, -rad * 0.14), rad * 0.82, bg, true, -1, true)
	if look.has("animal"):
		_animal(ci, str(look["animal"]), c, rad)
	else:
		_person(ci, look, c, rad)
	if ring.a > 0.0:
		ci.draw_arc(c, rad * 0.97, 0, TAU, 48, ring, rad * 0.07, true)


# ------------------------------------------------------------------ helpers

static func _ellipse(c: Vector2, rx: float, ry: float, n := 28) -> PackedVector2Array:
	var p := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, line := 0.0) -> void:
	if pts.size() < 3:
		return
	ci.draw_colored_polygon(pts, col)
	if line > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, col.darkened(0.45), line, true)


## The part of the frame circle below a curve: shoulders and clothes.
static func _bust(c: Vector2, rad: float, top: float) -> PackedVector2Array:
	var r := rad * 0.98
	var curve := func(x: float) -> float: return top * rad + x * x / rad * 0.45
	var p := PackedVector2Array()
	for i in 41:   # lower half of the circle, right to left, below the shoulder line
		var a := PI * i / 40.0
		var q := Vector2(cos(a), sin(a)) * r
		if q.y >= curve.call(q.x):
			p.append(c + q)
	for i in 41:   # shoulder line, left to right, inside the circle
		var x := lerpf(-r, r, i / 40.0)
		var y: float = curve.call(x)
		if x * x + y * y <= r * r:
			p.append(c + Vector2(x, y))
	return p


# ------------------------------------------------------------------ people

static func _person(ci: CanvasItem, look: Dictionary, c: Vector2, rad: float) -> void:
	var skin: Color = SKIN[int(look.get("skin", 0)) % SKIN.size()]
	var hair := Color(str(look.get("hair_col", "3a2418")))
	var outfit := Color(str(look.get("outfit", "3d6fb0")))
	var style := str(look.get("hair", "short"))
	var acc := str(look.get("acc", ""))
	var head := c + Vector2(0, -rad * 0.1)
	var hw := rad * 0.42
	var hh := rad * 0.48
	# hair behind the head
	match style:
		"long", "wavy", "braids":
			_fill(ci, PackedVector2Array([head + Vector2(-hw * 1.15, -hh * 0.3), head + Vector2(hw * 1.15, -hh * 0.3),
				head + Vector2(hw * 1.25, hh * 1.5), head + Vector2(-hw * 1.25, hh * 1.5)]), hair.darkened(0.12))
		"bob":
			_fill(ci, _ellipse(head + Vector2(0, hh * 0.15), hw * 1.22, hh * 1.05), hair.darkened(0.1))
		"bun":
			ci.draw_circle(head + Vector2(0, -hh * 1.05), hw * 0.45, hair.darkened(0.05), true, -1, true)
		"ponytail":
			_fill(ci, _ellipse(head + Vector2(hw * 1.05, hh * 0.35), hw * 0.32, hh * 0.75), hair.darkened(0.1))
	# clothes and neck
	_fill(ci, _bust(c, rad, 0.5), outfit)
	_fill(ci, _ellipse(c + Vector2(0, rad * 0.52), rad * 0.2, rad * 0.1), outfit.darkened(0.15))
	ci.draw_rect(Rect2(head + Vector2(-hw * 0.32, hh * 0.6), Vector2(hw * 0.64, hh * 0.7)), skin.darkened(0.08))
	_fill(ci, _ellipse(head + Vector2(0, hh * 1.18), hw * 0.34, hh * 0.18), skin.darkened(0.08))
	match acc:
		"apron":
			_fill(ci, PackedVector2Array([c + Vector2(-rad * 0.28, rad * 0.62), c + Vector2(rad * 0.28, rad * 0.62),
				c + Vector2(rad * 0.34, rad * 0.98), c + Vector2(-rad * 0.34, rad * 0.98)]), Color("fbf3e6"))
		"tie":
			_fill(ci, PackedVector2Array([c + Vector2(0, rad * 0.56), c + Vector2(rad * 0.07, rad * 0.64), c + Vector2(0, rad * 0.95), c + Vector2(-rad * 0.07, rad * 0.64)]), Color("c0473e"))
		"scarf":
			_fill(ci, _ellipse(c + Vector2(0, rad * 0.55), rad * 0.3, rad * 0.11), Color("e2554f"))
	# ears and face
	ci.draw_circle(head + Vector2(-hw * 0.98, hh * 0.1), hw * 0.2, skin.darkened(0.05), true, -1, true)
	ci.draw_circle(head + Vector2(hw * 0.98, hh * 0.1), hw * 0.2, skin.darkened(0.05), true, -1, true)
	_fill(ci, _ellipse(head, hw, hh), skin)
	if acc == "earrings":
		for sx in [-1.0, 1.0]:
			ci.draw_circle(head + Vector2(sx * hw * 1.0, hh * 0.38), hw * 0.08, Color("ffcf3a"), true, -1, true)
	# hair on top
	match style:
		"bald":
			_fill(ci, _ellipse(head + Vector2(-hw * 0.95, hh * 0.05), hw * 0.16, hh * 0.3), hair)
			_fill(ci, _ellipse(head + Vector2(hw * 0.95, hh * 0.05), hw * 0.16, hh * 0.3), hair)
		"grey", "short", "spiky":
			var p := PackedVector2Array()
			for i in 15:
				var a := PI + PI * i / 14.0
				var bump := (hw * 0.12 if style == "spiky" and i % 2 == 0 else 0.0)
				p.append(head + Vector2(cos(a) * (hw * 1.06 + bump), sin(a) * (hh * 1.04 + bump) - hh * 0.02))
			p.append(head + Vector2(hw * 1.0, -hh * 0.15))
			p.append(head + Vector2(-hw * 1.0, -hh * 0.15))
			_fill(ci, p, hair)
		"curly":
			for i in 9:
				var a := PI * 0.95 + PI * 1.1 * i / 8.0
				ci.draw_circle(head + Vector2(cos(a) * hw * 0.98, sin(a) * hh * 0.9 - hh * 0.1), hw * 0.36, hair, true, -1, true)
		_:
			var p := PackedVector2Array()
			for i in 15:
				var a := PI + PI * i / 14.0
				p.append(head + Vector2(cos(a) * hw * 1.08, sin(a) * hh * 1.06))
			p.append(head + Vector2(hw * 0.9, -hh * 0.05))
			p.append(head + Vector2(hw * 0.2, -hh * 0.45))
			p.append(head + Vector2(-hw * 0.6, -hh * 0.2))
			p.append(head + Vector2(-hw * 1.0, hh * 0.1))
			_fill(ci, p, hair)
			if style == "braids":
				for sx in [-1.0, 1.0]:
					for k in 3:
						ci.draw_circle(head + Vector2(sx * hw * 1.05, hh * (0.5 + k * 0.32)), hw * 0.17, hair.darkened(0.06), true, -1, true)
	# face details
	var eye_y := head.y + hh * 0.05
	for sx in [-1.0, 1.0]:
		var e := Vector2(head.x + sx * hw * 0.38, eye_y)
		ci.draw_circle(e, hw * 0.17, Color.WHITE, true, -1, true)
		ci.draw_circle(e + Vector2(0, hw * 0.02), hw * 0.11, Color("3a2a22"), true, -1, true)
		ci.draw_circle(e + Vector2(-hw * 0.04, -hw * 0.03), hw * 0.04, Color.WHITE, true, -1, true)
		ci.draw_line(e + Vector2(-hw * 0.16, -hw * 0.27), e + Vector2(hw * 0.14, -hw * 0.3), hair.darkened(0.2), hw * 0.07, true)
		ci.draw_circle(Vector2(head.x + sx * hw * 0.6, head.y + hh * 0.42), hw * 0.14, Color(0.95, 0.45, 0.45, 0.28), true, -1, true)
	ci.draw_arc(head + Vector2(0, hh * 0.28), hw * 0.08, 0.2, PI - 0.2, 8, skin.darkened(0.25), hw * 0.05, true)
	ci.draw_arc(head + Vector2(0, hh * 0.44), hw * 0.28, 0.25, PI - 0.25, 14, Color("8a3a2a"), hw * 0.08, true)
	if look.has("moustache"):
		var m := Color(str(look["moustache"]))
		_fill(ci, _ellipse(head + Vector2(-hw * 0.18, hh * 0.4), hw * 0.22, hh * 0.08), m)
		_fill(ci, _ellipse(head + Vector2(hw * 0.18, hh * 0.4), hw * 0.22, hh * 0.08), m)
	if look.has("beard"):
		var b := Color(str(look["beard"]))
		var p := PackedVector2Array()
		for i in 13:
			var a := PI * 0.05 + PI * 0.9 * i / 12.0
			p.append(head + Vector2(cos(a) * hw * 0.95, hh * 0.15 + sin(a) * hh * 0.95))
		p.append(head + Vector2(-hw * 0.5, hh * 0.5))
		p.append(head + Vector2(hw * 0.5, hh * 0.5))
		_fill(ci, p, b)
		ci.draw_arc(head + Vector2(0, hh * 0.5), hw * 0.22, 0.3, PI - 0.3, 10, Color("8a3a2a"), hw * 0.07, true)
	# headwear and other accessories
	match acc:
		"glasses":
			for sx in [-1.0, 1.0]:
				ci.draw_arc(Vector2(head.x + sx * hw * 0.38, eye_y), hw * 0.24, 0, TAU, 20, Color("3a2a22"), hw * 0.06, true)
			ci.draw_line(Vector2(head.x - hw * 0.14, eye_y), Vector2(head.x + hw * 0.14, eye_y), Color("3a2a22"), hw * 0.05, true)
		"goggles":
			ci.draw_line(head + Vector2(-hw * 1.02, -hh * 0.42), head + Vector2(hw * 1.02, -hh * 0.42), Color("5a3a24"), hw * 0.12, true)
			for sx in [-1.0, 1.0]:
				ci.draw_circle(head + Vector2(sx * hw * 0.36, -hh * 0.42), hw * 0.2, Color("8fd0e0"), true, -1, true)
				ci.draw_arc(head + Vector2(sx * hw * 0.36, -hh * 0.42), hw * 0.2, 0, TAU, 16, Color("5a3a24"), hw * 0.06, true)
		"cap":
			_fill(ci, PackedVector2Array([head + Vector2(-hw * 1.05, -hh * 0.45), head + Vector2(-hw * 0.8, -hh * 1.05), head + Vector2(hw * 0.8, -hh * 1.05),
				head + Vector2(hw * 1.05, -hh * 0.45)]), Color("2c4f7a"))
			_fill(ci, _ellipse(head + Vector2(hw * 0.2, -hh * 0.45), hw * 1.15, hh * 0.13), Color("1f3a5c"))
		"chef":
			for k in 3:
				ci.draw_circle(head + Vector2((k - 1) * hw * 0.5, -hh * 1.05), hw * 0.42, Color("fbfaf4"), true, -1, true)
			ci.draw_rect(Rect2(head + Vector2(-hw * 0.9, -hh * 0.95), Vector2(hw * 1.8, hh * 0.45)), Color("fbfaf4"))
		"bandana":
			_fill(ci, PackedVector2Array([head + Vector2(-hw * 1.06, -hh * 0.35), head + Vector2(0, -hh * 1.1), head + Vector2(hw * 1.06, -hh * 0.35)]), Color("e2554f"))
		"headband":
			ci.draw_line(head + Vector2(-hw * 1.0, -hh * 0.5), head + Vector2(hw * 1.0, -hh * 0.5), Color("f2efe9"), hw * 0.16, true)
		"flower":
			var f := head + Vector2(hw * 0.75, -hh * 0.65)
			for k in 5:
				var a := TAU * k / 5.0
				ci.draw_circle(f + Vector2(cos(a), sin(a)) * hw * 0.16, hw * 0.13, Color("f28ab0"), true, -1, true)
			ci.draw_circle(f, hw * 0.09, Color("ffcf3a"), true, -1, true)


# ------------------------------------------------------------------ animals

static func _animal_bg(kind: String) -> Color:
	return {"otter": Color("bfe6e4"), "crab": Color("ffd9c2"), "owl": Color("d8cdb0"), "parrot": Color("cdeac0"),
		"tortoise": Color("e3e8c8"), "moth": Color("d9d2f2")}.get(kind, Color("dddddd"))


static func _animal(ci: CanvasItem, kind: String, c: Vector2, rad: float) -> void:
	var w := rad
	match kind:
		"otter":
			var fur := Color("9a6a44")
			_fill(ci, _bust(c, rad, 0.45), fur.darkened(0.1))
			for sx in [-1.0, 1.0]:
				ci.draw_circle(c + Vector2(sx * w * 0.36, -w * 0.38), w * 0.12, fur.darkened(0.15), true, -1, true)
			_fill(ci, _ellipse(c + Vector2(0, -w * 0.08), w * 0.46, w * 0.4), fur)
			_fill(ci, _ellipse(c + Vector2(0, w * 0.08), w * 0.3, w * 0.22), Color("e8d4b8"))
			_eyes(ci, c + Vector2(0, -w * 0.14), w * 0.2, w * 0.07)
			_fill(ci, _ellipse(c + Vector2(0, w * 0.02), w * 0.08, w * 0.055), Color("3a2a22"))
			for sx in [-1.0, 1.0]:
				for k in 2:
					ci.draw_line(c + Vector2(sx * w * 0.12, w * (0.06 + k * 0.05)), c + Vector2(sx * w * 0.36, w * (0.02 + k * 0.08)), Color(0.3, 0.2, 0.15, 0.6), w * 0.015, true)
		"crab":
			var shell := Color("e2554f")
			for sx in [-1.0, 1.0]:
				_fill(ci, _ellipse(c + Vector2(sx * w * 0.55, w * 0.05), w * 0.18, w * 0.14), shell.darkened(0.1))
				ci.draw_line(c + Vector2(sx * w * 0.12, -w * 0.15), c + Vector2(sx * w * 0.16, -w * 0.4), shell.darkened(0.2), w * 0.05, true)
				ci.draw_circle(c + Vector2(sx * w * 0.16, -w * 0.45), w * 0.09, Color.WHITE, true, -1, true)
				ci.draw_circle(c + Vector2(sx * w * 0.16, -w * 0.44), w * 0.05, Color("3a2a22"), true, -1, true)
			_fill(ci, _ellipse(c + Vector2(0, w * 0.15), w * 0.42, w * 0.3), shell)
			ci.draw_arc(c + Vector2(0, w * 0.18), w * 0.12, 0.3, PI - 0.3, 10, Color("7a2a20"), w * 0.04, true)
		"owl":
			var fur := Color("a07a50")
			_fill(ci, _bust(c, rad, 0.35), fur.darkened(0.1))
			_fill(ci, _ellipse(c + Vector2(0, -w * 0.02), w * 0.5, w * 0.48), fur)
			for sx in [-1.0, 1.0]:
				_fill(ci, PackedVector2Array([c + Vector2(sx * w * 0.3, -w * 0.4), c + Vector2(sx * w * 0.45, -w * 0.62), c + Vector2(sx * w * 0.48, -w * 0.32)]), fur.darkened(0.1))
				ci.draw_circle(c + Vector2(sx * w * 0.2, -w * 0.08), w * 0.17, Color("f3ead6"), true, -1, true)
				ci.draw_circle(c + Vector2(sx * w * 0.2, -w * 0.08), w * 0.1, Color("f2b632"), true, -1, true)
				ci.draw_circle(c + Vector2(sx * w * 0.2, -w * 0.08), w * 0.055, Color("2a1a12"), true, -1, true)
			_fill(ci, PackedVector2Array([c + Vector2(-w * 0.06, w * 0.05), c + Vector2(w * 0.06, w * 0.05), c + Vector2(0, w * 0.18)]), Color("e8a33a"))
		"parrot":
			var fea := Color("4fb04a")
			_fill(ci, _bust(c, rad, 0.4), fea.darkened(0.15))
			_fill(ci, _ellipse(c + Vector2(0, -w * 0.06), w * 0.42, w * 0.46), fea)
			_fill(ci, _ellipse(c + Vector2(0, -w * 0.42), w * 0.18, w * 0.12), Color("e2554f"))
			_eyes(ci, c + Vector2(0, -w * 0.12), w * 0.2, w * 0.07)
			_fill(ci, PackedVector2Array([c + Vector2(-w * 0.12, w * 0.02), c + Vector2(w * 0.12, w * 0.02), c + Vector2(w * 0.04, w * 0.3), c + Vector2(-w * 0.02, w * 0.22)]), Color("f2b632"))
		"tortoise":
			var skin := Color("8fae5a")
			_fill(ci, _bust(c, rad, 0.4), Color("6b5a3a"))
			for k in 3:
				ci.draw_arc(c + Vector2(0, w * 0.95), w * (0.4 + k * 0.15), PI * 1.15, PI * 1.85, 16, Color("4a3e28"), w * 0.03, true)
			_fill(ci, _ellipse(c + Vector2(0, -w * 0.1), w * 0.36, w * 0.32), skin)
			_eyes(ci, c + Vector2(0, -w * 0.14), w * 0.17, w * 0.06)
			ci.draw_arc(c + Vector2(0, w * 0.02), w * 0.12, 0.3, PI - 0.3, 10, Color("3a4a22"), w * 0.03, true)
		_:   # moth
			var fur := Color("c9bfe8")
			for sx in [-1.0, 1.0]:
				_fill(ci, _ellipse(c + Vector2(sx * w * 0.5, w * 0.1), w * 0.3, w * 0.45), Color("a99ad6"))
				ci.draw_line(c + Vector2(sx * w * 0.1, -w * 0.35), c + Vector2(sx * w * 0.3, -w * 0.65), Color("5a4a7a"), w * 0.03, true)
				ci.draw_circle(c + Vector2(sx * w * 0.3, -w * 0.66), w * 0.05, Color("5a4a7a"), true, -1, true)
			_fill(ci, _ellipse(c + Vector2(0, -w * 0.05), w * 0.32, w * 0.34), fur)
			_fill(ci, _ellipse(c + Vector2(0, w * 0.3), w * 0.22, w * 0.25), fur.darkened(0.1))
			_eyes(ci, c + Vector2(0, -w * 0.08), w * 0.15, w * 0.08)


static func _eyes(ci: CanvasItem, c: Vector2, gap: float, r: float) -> void:
	for sx in [-1.0, 1.0]:
		ci.draw_circle(c + Vector2(sx * gap, 0), r, Color("2a1a12"), true, -1, true)
		ci.draw_circle(c + Vector2(sx * gap - r * 0.3, -r * 0.3), r * 0.35, Color.WHITE, true, -1, true)
