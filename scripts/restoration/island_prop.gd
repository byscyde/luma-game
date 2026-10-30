class_name IslandProp
extends Node3D
## One restorable object (or decoration) on the 3D island. `set_growth(g)`
## takes a normalised value: 0 dormant, 1 young/activated, 2 fully restored;
## it is continuous so restoration can animate smoothly.

var data: Dictionary
var kind := ""
var is_deco := false
var g := 0.0
var _w: IslandWorld
var _parts: Dictionary = {}
var _t := 0.0
var _seed := 0


func setup(p_data: Dictionary, w: IslandWorld, deco := false) -> void:
	data = p_data
	kind = data.get("kind", "")
	is_deco = deco
	_w = w
	_seed = absi(hash(data["id"])) % 1000
	name = data["id"]
	var px: float = data["pos"][0]
	var pz: float = data["pos"][1]
	position = w.surface(px, pz)
	rotation.y = Painter.hash01(_seed) * TAU if kind in ["tree", "fruit_tree", "pine", "willow", "palm", "meadow", "reeds", "rabbits", "deer"] else 0.0
	_build()
	set_growth(0.0)
	# only animated kinds need a per-frame update (keeps the island cheap at 120 Hz)
	set_process(kind == "koi" if is_deco else kind in ["mill", "rabbits", "ducks", "birds", "spring",
		"tree", "fruit_tree", "heart_tree", "willow", "pine", "palm"])


# ------------------------------------------------------------------ building

func _m(col: Color, em := 0.0) -> StandardMaterial3D:
	return LowPoly.mat(col, em)


func _add(mesh: Mesh, col: Color, pos := Vector3.ZERO, parent: Node3D = null, em := 0.0) -> MeshInstance3D:
	return LowPoly.instance(mesh, _m(col, em), pos, parent if parent else self)


func _node(n: String, parent: Node3D = null) -> Node3D:
	var nd := Node3D.new()
	nd.name = n
	(parent if parent else self).add_child(nd)
	_parts[n] = nd
	return nd


func _build() -> void:
	match kind:
		"tree", "fruit_tree", "heart_tree":
			_build_tree()
		"pine":
			_build_pine()
		"palm":
			_build_palm()
		"willow":
			_build_willow()
		"meadow":
			_build_meadow()
		"reeds":
			_build_reeds()
		"spring":
			_build_spring()
		"pond":
			_build_pond()
		"stream":
			_build_stream()
		"waterfall":
			_build_waterfall()
		"terrace":
			_build_terrace()
		"mill":
			_build_mill()
		"rabbits":
			_build_rabbits()
		"deer":
			_build_deer()
		"ducks":
			_build_ducks()
		"birds":
			_build_birds()
		_:
			_build_deco()


func _build_tree() -> void:
	var big := 1.55 if kind == "heart_tree" else 1.0
	var trunk := _node("trunk")
	_add(LowPoly.cyl(0.075 * big, 0.04 * big, 0.5 * big, 6, 0.1, _seed), Color(0.5, 0.35, 0.22), Vector3.ZERO, trunk)
	var bare := _node("bare", trunk)
	for i in 3:
		var br := LowPoly.instance(LowPoly.cyl(0.022, 0.008, 0.28 * big, 4), _m(Color(0.52, 0.4, 0.28)), Vector3(0, 0.36 * big, 0), bare)
		br.rotation = Vector3(deg_to_rad(40), TAU * i / 3.0 + _seed, 0)
	var canopy := _node("canopy")
	canopy.position = Vector3(0, 0.52 * big, 0)
	var greens := [Color(0.24, 0.52, 0.18), Color(0.34, 0.64, 0.22), Color(0.46, 0.74, 0.26), Color(0.3, 0.6, 0.2)]
	if kind == "heart_tree":
		greens = [Color(0.3, 0.6, 0.42), Color(0.38, 0.7, 0.48), Color(0.5, 0.78, 0.52), Color(0.34, 0.64, 0.45)]
	var blobs := [[Vector3(0, 0.12, 0), 0.3], [Vector3(-0.19, 0.0, 0.08), 0.22], [Vector3(0.2, 0.02, -0.06), 0.23], [Vector3(0.02, 0.32, -0.04), 0.21],
		[Vector3(-0.1, 0.22, 0.14), 0.17], [Vector3(0.14, 0.2, 0.13), 0.16]]
	for i in blobs.size():
		var b: Array = blobs[i]
		var mi := LowPoly.instance(LowPoly.blob(float(b[1]) * big, 1, 0.14, _seed + i), _m(greens[i % greens.size()]), b[0] * big, canopy)
		mi.set_meta("green", greens[i % greens.size()])
	var bloom := _node("bloom", canopy)
	var accent := Color(1, 0.96, 0.94)
	if kind == "fruit_tree":
		accent = Color(0.9, 0.3, 0.22) if _seed % 2 == 0 else Color(0.98, 0.78, 0.25)
	elif kind == "heart_tree":
		accent = Color(1.0, 0.82, 0.35)
	for i in 9:
		var a := TAU * i / 9.0 + _seed
		var p := Vector3(cos(a) * 0.26, 0.08 + 0.22 * Painter.hash01(_seed + i), sin(a) * 0.26) * big
		LowPoly.instance(LowPoly.blob(0.04 * big, 0, 0.0, 1), _m(accent, 1.4 if kind == "heart_tree" else 0.0), p, bloom, false)
	if kind == "heart_tree":
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.85, 0.5)
		light.omni_range = 1.4
		light.light_energy = 0.0
		light.position = Vector3(0, 0.7, 0)
		add_child(light)
		_parts["light"] = light


func _build_palm() -> void:
	var trunk := _node("trunk")
	var lean := Vector3(0.12 + 0.1 * Painter.hash01(_seed), 0, 0.05)
	var p := Vector3.ZERO
	for i in 6:
		var seg := LowPoly.instance(LowPoly.cyl(0.06 - i * 0.005, 0.055 - i * 0.005, 0.2, 7), _m(Color(0.62, 0.48, 0.34).darkened(0.08 * (i % 2))), p, trunk)
		seg.rotation.z = -0.08 * i * 0.6
		p += Vector3(lean.x * (0.25 + i * 0.12), 0.19, lean.z * 0.3)
	_node("bare", trunk)
	var canopy := _node("canopy")
	canopy.position = p + Vector3(0, 0.02, 0)
	var crown := LowPoly.instance(LowPoly.palm_crown(_seed % 5), _m(Color(0.34, 0.66, 0.24)), Vector3.ZERO, canopy, true)
	crown.material_override = LowPoly.mat(Color(0.34, 0.66, 0.24), 0.0, 0.85, false, true)
	crown.set_meta("green", Color(0.34, 0.66, 0.24))
	crown.set_meta("double", true)
	for i in 3:
		var a := TAU * i / 3.0
		LowPoly.instance(LowPoly.blob(0.04, 0, 0.0, 1), _m(Color(0.45, 0.32, 0.18)), Vector3(cos(a) * 0.05, -0.04, sin(a) * 0.05), canopy, false)
	_node("bloom", canopy)


func _build_pine() -> void:
	var trunk := _node("trunk")
	_add(LowPoly.cyl(0.06, 0.04, 0.28, 5), Color(0.45, 0.32, 0.22), Vector3.ZERO, trunk)
	var canopy := _node("canopy")
	canopy.position.y = 0.18
	var cols := [Color(0.2, 0.45, 0.32), Color(0.25, 0.53, 0.36), Color(0.32, 0.6, 0.4)]
	for i in 3:
		var mi := LowPoly.instance(LowPoly.cyl(0.3 - i * 0.07, 0.0, 0.42, 7, 0.08, _seed + i), _m(cols[i]), Vector3(0, i * 0.2, 0), canopy)
		mi.set_meta("green", cols[i])
	_node("bare", trunk)
	_node("bloom", canopy)


func _build_willow() -> void:
	var trunk := _node("trunk")
	_add(LowPoly.cyl(0.07, 0.045, 0.5, 6, 0.1, _seed), Color(0.48, 0.36, 0.25), Vector3.ZERO, trunk)
	_node("bare", trunk)
	var canopy := _node("canopy")
	canopy.position.y = 0.55
	var c1 := Color(0.45, 0.66, 0.35)
	var c2 := Color(0.56, 0.76, 0.4)
	LowPoly.instance(LowPoly.blob(0.32, 1, 0.1, _seed, Vector3(1, 0.7, 1)), _m(c1), Vector3.ZERO, canopy).set_meta("green", c1)
	for i in 10:
		var a := TAU * i / 10.0
		var mi := LowPoly.instance(LowPoly.cyl(0.05, 0.02, 0.42, 4), _m(c2), Vector3(cos(a) * 0.26, 0.05, sin(a) * 0.26), canopy)
		mi.rotation.x = PI
		mi.set_meta("green", c2)
	_node("bloom", canopy)


func _build_meadow() -> void:
	var tufts := _node("tufts")
	var flowers := _node("flowers")
	var cols := [Color(0.98, 0.55, 0.62), Color(1, 1, 1), Color(0.75, 0.62, 0.95), Color(1.0, 0.82, 0.3)]
	for i in 16:
		var a := Painter.hash01(_seed + i * 3) * TAU
		var r := sqrt(Painter.hash01(_seed * 7 + i)) * 0.55
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var t := LowPoly.instance(LowPoly.cyl(0.05, 0.0, 0.18, 4), _m(Color(0.5, 0.72, 0.32)), p, tufts, false)
		t.set_meta("green", Color(0.5, 0.72, 0.32))
		if i % 2 == 0:
			var f := Node3D.new()
			f.position = p + Vector3(0.04, 0, 0)
			flowers.add_child(f)
			LowPoly.instance(LowPoly.cyl(0.012, 0.012, 0.16, 3), _m(Color(0.35, 0.6, 0.3)), Vector3.ZERO, f, false)
			LowPoly.instance(LowPoly.blob(0.055, 0, 0.0, 2), _m(cols[i % 4]), Vector3(0, 0.17, 0), f, false)


func _build_reeds() -> void:
	var n := _node("reeds")
	for i in 11:
		var x := (i - 5) * 0.07 + Painter.hash01(i) * 0.03
		var h := 0.32 + 0.22 * Painter.hash01(i * 9)
		var r := LowPoly.instance(LowPoly.cyl(0.014, 0.008, h, 3), _m(Color(0.38, 0.6, 0.3)), Vector3(x, 0, Painter.hash01(i * 5) * 0.2 - 0.1), n, false)
		r.set_meta("green", Color(0.38, 0.6, 0.3))
		if i % 2 == 0:
			LowPoly.instance(LowPoly.cyl(0.025, 0.025, 0.08, 4), _m(Color(0.45, 0.28, 0.16)), Vector3(0, h - 0.06, 0), r, false)


func _build_spring() -> void:
	for i in 9:
		var a := TAU * i / 9.0
		_add(LowPoly.blob(0.1, 0, 0.25, i, Vector3(1.2, 0.7, 1)), Color(0.72, 0.7, 0.66), Vector3(cos(a) * 0.32, 0.03, sin(a) * 0.32))
	var water := _node("water")
	_add(LowPoly.cyl(0.3, 0.3, 0.02, 12), Color(0.3, 0.78, 0.85), Vector3(0, 0.03, 0), water, 0.25)
	var bub := _node("bubbles", water)
	for i in 4:
		LowPoly.instance(LowPoly.blob(0.035, 0, 0.0, 3), _m(Color(0.85, 0.98, 1.0), 0.4), Vector3(0, 0.05, 0), bub, false)


func _build_pond() -> void:
	position.y = _w.plateau_y(data["area"]) - 0.24
	for i in 10:
		var a := TAU * i / 10.0 + 0.2
		var p := Vector3(cos(a) * 0.62, 0.2, sin(a) * 0.62)
		_add(LowPoly.blob(0.1, 0, 0.3, i, Vector3(1.2, 0.6, 1)), Color(0.74, 0.72, 0.66), p)
	var water := _node("water")
	_add(LowPoly.cyl(0.6, 0.6, 0.03, 14), Color(0.27, 0.72, 0.82), Vector3.ZERO, water, 0.2)
	var lilies := _node("lilies")
	for i in 5:
		var a := Painter.hash01(_seed + i) * TAU
		var p := Vector3(cos(a) * 0.36, 0.22, sin(a) * 0.36)
		_add(LowPoly.cyl(0.08, 0.08, 0.01, 6), Color(0.33, 0.62, 0.3), p, lilies)
		if i % 2 == 0:
			_add(LowPoly.blob(0.035, 0, 0.0, 2), Color(1.0, 0.75, 0.82), p + Vector3(0, 0.02, 0), lilies)


func _ribbon(points: Array[Vector3], width: float, lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var total := 0.0
	var acc: Array[float] = [0.0]
	for i in range(1, points.size()):
		total += points[i].distance_to(points[i - 1])
		acc.append(total)
	for i in points.size():
		var fwd := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var side := fwd.cross(Vector3.UP).normalized() * width * 0.5
		var v := acc[i] / maxf(total, 0.001)
		st.set_uv(Vector2(0, v)); st.add_vertex(points[i] - side + Vector3(0, lift, 0))
		st.set_uv(Vector2(1, v)); st.add_vertex(points[i] + side + Vector3(0, lift, 0))
	for i in points.size() - 1:
		var a := i * 2
		st.add_index(a); st.add_index(a + 1); st.add_index(a + 3)
		st.add_index(a); st.add_index(a + 3); st.add_index(a + 2)
	st.generate_normals()
	return st.commit()


func _flow_mat(stripes: float, speed: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://resources/shaders/water_flow.gdshader")
	m.set_shader_parameter("stripes", stripes)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("fill", 0.0)
	return m


func _build_stream() -> void:
	# Ribbons are built in world space, so the prop sits at the origin.
	position = Vector3.ZERO
	var to: Array = data.get("to", data["pos"])
	var a := Vector2(data["pos"][0], data["pos"][1])
	var b := Vector2(to[0], to[1])
	var pts: Array[Vector3] = []
	var side_dir := Vector2(-(b - a).y, (b - a).x).normalized()
	for i in 25:
		var k := i / 24.0
		var p := a.lerp(b, k) + side_dir * sin(k * PI * 2.0) * 0.25
		pts.append(_w.surface(p.x, p.y))
	var bed := MeshInstance3D.new()
	bed.mesh = _ribbon(pts, 0.36, 0.05)
	bed.material_override = _m(Color(0.6, 0.48, 0.34))
	add_child(bed)
	var water := MeshInstance3D.new()
	water.mesh = _ribbon(pts, 0.26, 0.075)
	water.material_override = _flow_mat(10.0, 0.9)
	add_child(water)
	_parts["flow"] = water


func _build_waterfall() -> void:
	var to: Array = data.get("to", data["pos"])
	var top := _w.surface(data["pos"][0], data["pos"][1])
	var bot := _w.surface(to[0], to[1])
	position = Vector3(top.x, 0, top.z)
	var low_y := bot.y
	var run := Vector3(bot.x - top.x, 0, bot.z - top.z)
	rotation.y = atan2(run.x, run.z)
	var dist := run.length()
	var pts: Array[Vector3] = []
	for i in 9:
		var k := i / 8.0
		var z := dist * (0.15 * k + 0.85 * k * k)
		pts.append(Vector3(0, lerpf(top.y + 0.03, low_y + 0.02, k), z))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size():
		var v := float(i) / (pts.size() - 1)
		st.set_uv(Vector2(0, v)); st.add_vertex(pts[i] + Vector3(-0.2, 0, 0.0))
		st.set_uv(Vector2(1, v)); st.add_vertex(pts[i] + Vector3(0.2, 0, 0.0))
	for i in pts.size() - 1:
		var a := i * 2
		st.add_index(a); st.add_index(a + 1); st.add_index(a + 3)
		st.add_index(a); st.add_index(a + 3); st.add_index(a + 2)
	st.generate_normals()
	var fall := MeshInstance3D.new()
	fall.mesh = st.commit()
	var mat := _flow_mat(5.0, 1.6)
	mat.set_shader_parameter("emissive", 0.35)
	fall.material_override = mat
	add_child(fall)
	_parts["flow"] = fall
	var pool := _node("pool")
	pool.position = Vector3(0, low_y + 0.01, dist + 0.1)
	LowPoly.instance(LowPoly.cyl(0.36, 0.36, 0.02, 10), _m(Color(0.32, 0.78, 0.86), 0.2), Vector3.ZERO, pool)
	var foam := _node("foam", pool)
	for i in 6:
		var a := TAU * i / 6.0
		LowPoly.instance(LowPoly.blob(0.07, 0, 0.2, i), _m(Color(1, 1, 1), 0.3), Vector3(cos(a) * 0.12, 0.03, sin(a) * 0.08 - 0.25), foam, false)


func _build_terrace() -> void:
	var rows_n := _node("rows")
	for row in 3:
		var z := -0.5 + row * 0.42
		_add(LowPoly.slab(Vector3(1.3, 0.05, 0.22), 0.02), Color(0.55, 0.42, 0.3), Vector3(0, 0, z), rows_n)
		for k in 7:
			var mi := LowPoly.instance(LowPoly.blob(0.085, 0, 0.15, k + row * 7, Vector3(1, 0.8, 1)), _m(Color(0.4, 0.66, 0.32)), Vector3(-0.54 + k * 0.18, 0.08, z), rows_n, false)
			mi.set_meta("green", Color(0.4, 0.66, 0.32))


func _build_mill() -> void:
	var walls := _node("walls")
	var wood := Color(0.6, 0.41, 0.26)
	for i in 6:
		_add(LowPoly.slab(Vector3(0.78, 0.1, 0.62), 0.03), wood.darkened(0.07 * (i % 2)), Vector3(0, i * 0.1, 0), walls)
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		_add(LowPoly.cyl(0.05, 0.05, 0.62, 6), Color(0.48, 0.32, 0.2), Vector3(c.x * 0.39, 0, c.y * 0.31), walls)
	var door := _add(LowPoly.slab(Vector3(0.22, 0.36, 0.03), 0.01), Color(0.4, 0.26, 0.16), Vector3(0.08, 0, 0.315), walls)
	door.set_meta("door", true)
	_add(LowPoly.slab(Vector3(0.14, 0.12, 0.03), 0.01), Color(0.95, 0.82, 0.5), Vector3(-0.22, 0.3, 0.315), walls, 0.6)
	var ruin := _node("ruin")
	for i in 3:
		_add(LowPoly.slab(Vector3(0.78, 0.1, 0.62), 0.03), Color(0.5, 0.42, 0.34), Vector3(0, i * 0.1, 0), ruin)
	for i in 4:
		_add(LowPoly.blob(0.08, 0, 0.3, i), Color(0.55, 0.46, 0.36), Vector3(-0.3 + i * 0.2, 0.3, 0.25 - (i % 2) * 0.5), ruin)
	var roof := _node("roof")
	roof.position.y = 0.6
	for side in [-1.0, 1.0]:
		for k in 4:
			var plank := _add(LowPoly.slab(Vector3(0.5, 0.04, 0.2), 0.01), Color(0.5, 0.34, 0.22).darkened(0.05 * (k % 2)), Vector3(side * 0.22, 0.12, -0.3 + k * 0.2), roof)
			plank.rotation.z = -side * 0.55
	var wheel := _node("wheel")
	wheel.position = Vector3(0.48, 0.3, 0.05)
	wheel.rotation.z = PI * 0.5
	var spokes := _node("spokes", wheel)
	LowPoly.instance(LowPoly.cyl(0.27, 0.27, 0.06, 12), _m(Color(0.5, 0.34, 0.22)), Vector3(0, -0.03, 0), spokes)
	for i in 8:
		var p := LowPoly.instance(LowPoly.slab(Vector3(0.08, 0.1, 0.16), 0.01), _m(Color(0.62, 0.45, 0.28)), Vector3.ZERO, spokes)
		var a := TAU * i / 8.0
		p.position = Vector3(cos(a) * 0.28, -0.05, sin(a) * 0.28)
		p.rotation.y = -a


func _build_rabbits() -> void:
	var n := _node("creatures")
	for i in 2:
		var r := _node("r%d" % i, n)
		r.position = Vector3(i * 0.3, 0, i * 0.15)
		var fur := Color(0.96, 0.94, 0.9) if i == 0 else Color(0.78, 0.66, 0.52)
		LowPoly.instance(LowPoly.blob(0.09, 1, 0.05, i, Vector3(1.2, 0.9, 1)), _m(fur), Vector3(0, 0.08, 0), r)
		LowPoly.instance(LowPoly.blob(0.06, 1, 0.05, i + 2), _m(fur), Vector3(0.09, 0.15, 0), r)
		for e in [-0.025, 0.025]:
			LowPoly.instance(LowPoly.cyl(0.018, 0.012, 0.1, 4), _m(fur), Vector3(0.09, 0.18, e), r)


func _build_deer() -> void:
	var n := _node("creatures")
	var brown := Color(0.7, 0.48, 0.3)
	LowPoly.instance(LowPoly.blob(0.17, 1, 0.05, 1, Vector3(1.5, 0.75, 0.8)), _m(brown), Vector3(0, 0.28, 0), n)
	for p in [Vector3(-0.15, 0, -0.06), Vector3(-0.15, 0, 0.06), Vector3(0.15, 0, -0.06), Vector3(0.15, 0, 0.06)]:
		LowPoly.instance(LowPoly.cyl(0.022, 0.018, 0.24, 4), _m(brown.darkened(0.2)), p, n)
	var neck := LowPoly.instance(LowPoly.cyl(0.04, 0.03, 0.2, 5), _m(brown), Vector3(0.2, 0.3, 0), n)
	neck.rotation.z = -0.5
	var head := _node("head", n)
	head.position = Vector3(0.3, 0.47, 0)
	LowPoly.instance(LowPoly.blob(0.06, 1, 0.05, 3, Vector3(1.4, 1, 1)), _m(brown), Vector3.ZERO, head)
	for e in [-0.04, 0.04]:
		var ant := LowPoly.instance(LowPoly.cyl(0.01, 0.006, 0.12, 3), _m(Color(0.45, 0.32, 0.2)), Vector3(-0.02, 0.04, e), head)
		ant.rotation.x = e * 6.0


func _build_ducks() -> void:
	var n := _node("creatures")
	var pond: IslandProp = _w.props.get("pond_main")
	if pond:
		position = pond.position + Vector3(0, 0.22, 0)
	for i in 3:
		var d := _node("d%d" % i, n)
		LowPoly.instance(LowPoly.blob(0.06, 1, 0.05, i, Vector3(1.4, 0.8, 1)), _m(Color(1, 1, 1)), Vector3(0, 0.03, 0), d)
		LowPoly.instance(LowPoly.blob(0.035, 0, 0.05, i), _m(Color(0.2, 0.5, 0.3) if i == 0 else Color(1, 1, 1)), Vector3(0.06, 0.08, 0), d)
		LowPoly.instance(LowPoly.cyl(0.015, 0.0, 0.04, 3), _m(Color(1, 0.62, 0.2)), Vector3(0.09, 0.08, 0), d).rotation.z = -PI / 2


func _build_birds() -> void:
	var n := _node("creatures")
	n.position.y = 1.4
	for i in 4:
		var b := _node("b%d" % i, n)
		for s in [-1.0, 1.0]:
			var wing := LowPoly.instance(LowPoly.slab(Vector3(0.14, 0.01, 0.05), 0.0), _m(Color(0.28, 0.32, 0.36)), Vector3(s * 0.06, 0, 0), b, false)
			wing.set_meta("side", s)


func _build_deco() -> void:
	var n := _node("deco")
	match kind:
		"lantern":
			_add(LowPoly.slab(Vector3(0.1, 0.32, 0.1), 0.02), Color(0.7, 0.7, 0.68), Vector3.ZERO, n)
			_add(LowPoly.slab(Vector3(0.18, 0.12, 0.18), 0.02), Color(0.75, 0.75, 0.72), Vector3(0, 0.32, 0), n)
			_add(LowPoly.slab(Vector3(0.1, 0.08, 0.1), 0.01), Color(1.0, 0.82, 0.4), Vector3(0, 0.34, 0), n, 2.5)
			_add(LowPoly.cyl(0.16, 0.0, 0.12, 4), Color(0.55, 0.55, 0.52), Vector3(0, 0.44, 0), n)
			var l := OmniLight3D.new()
			l.light_color = Color(1, 0.8, 0.45)
			l.omni_range = 0.7
			l.light_energy = 0.35
			l.position = Vector3(0, 0.4, 0)
			n.add_child(l)
		"bench":
			_add(LowPoly.slab(Vector3(0.45, 0.04, 0.14), 0.01), Color(0.6, 0.42, 0.26), Vector3(0, 0.14, 0), n)
			_add(LowPoly.slab(Vector3(0.45, 0.12, 0.03), 0.01), Color(0.6, 0.42, 0.26), Vector3(0, 0.18, -0.07), n)
			for x in [-0.18, 0.18]:
				_add(LowPoly.slab(Vector3(0.04, 0.14, 0.12), 0.0), Color(0.45, 0.3, 0.2), Vector3(x, 0, 0), n)
		"bridge":
			position.y = _w.height_at(data["pos"][0], data["pos"][1])
			rotation.y = -0.4
			for i in 7:
				var k := (i - 3) / 3.0
				var plank := _add(LowPoly.slab(Vector3(0.1, 0.03, 0.34), 0.0), Color(0.62, 0.44, 0.27), Vector3(k * 0.32, 0.12 + (1.0 - k * k) * 0.12, 0), n)
				plank.rotation.z = -k * 0.4
			for s in [-0.17, 0.17]:
				for i in 3:
					_add(LowPoly.cyl(0.015, 0.015, 0.16, 4), Color(0.45, 0.3, 0.2), Vector3((i - 1) * 0.3, 0.12 + (1.0 - pow((i - 1) * 0.95, 2)) * 0.12, s), n)
		"birdhouse":
			_add(LowPoly.cyl(0.02, 0.02, 0.5, 4), Color(0.45, 0.32, 0.22), Vector3.ZERO, n)
			_add(LowPoly.slab(Vector3(0.14, 0.14, 0.14), 0.01), Color(0.86, 0.7, 0.48), Vector3(0, 0.5, 0), n)
			_add(LowPoly.roof(0.2, 0.2, 0.1), Color(0.78, 0.36, 0.25), Vector3(0, 0.64, 0), n)
		"koi":
			var pond: IslandProp = _w.props.get("pond_main")
			if pond:
				position = pond.position + Vector3(0, 0.215, 0)
			var fish := _node("fish", n)
			_add(LowPoly.blob(0.06, 0, 0.0, 1, Vector3(1.8, 0.5, 0.8)), Color(1.0, 0.6, 0.15), Vector3(0.3, 0, 0), fish, 0.3)
		"beehive":
			for i in 4:
				_add(LowPoly.cyl(0.12 - i * 0.02, 0.11 - i * 0.02, 0.07, 8), Color(0.93, 0.72, 0.3).darkened(0.07 * (i % 2)), Vector3(0, i * 0.07, 0), n)
		"arch":
			for i in 11:
				var a := PI * i / 10.0
				var p := Vector3(cos(a) * 0.3, sin(a) * 0.36 + 0.02, 0)
				_add(LowPoly.blob(0.06, 0, 0.2, i), Color(0.35, 0.6, 0.3), p, n)
				_add(LowPoly.blob(0.035, 0, 0.0, i), [Color(1, 0.6, 0.7), Color(1, 1, 1), Color(0.8, 0.65, 1)][i % 3], p + Vector3(0, 0.03, 0.04), n)
		"spire":
			for i in 3:
				var h := 0.5 + 0.25 * (1 - absi(i - 1))
				_add(LowPoly.cyl(0.08, 0.05, h, 5, 0.1, i), Color(0.72, 0.72, 0.75), Vector3((i - 1) * 0.18, 0, (i % 2) * 0.08), n)
				_add(LowPoly.blob(0.04, 0, 0.0, i), Color(0.6, 0.95, 1.0), Vector3((i - 1) * 0.18, h * 0.65, (i % 2) * 0.08 + 0.06), n, 2.0)


# ------------------------------------------------------------------ growth

func _tint(n: Node, dry: Color, life: float) -> void:
	for c in n.get_children():
		if c is MeshInstance3D and c.has_meta("green"):
			(c as MeshInstance3D).material_override = LowPoly.mat(dry.lerp(c.get_meta("green"), life), 0.0, 0.85, false, c.has_meta("double"))
		if c.get_child_count() > 0:
			_tint(c, dry, life)


func _scale(n: String, s: float) -> void:
	var nd: Node3D = _parts.get(n)
	if nd:
		nd.scale = Vector3.ONE * maxf(s, 0.001)
		nd.visible = s > 0.002


func set_growth(value: float) -> void:
	g = value
	if is_deco:
		return
	var life := clampf(g, 0.0, 1.0)
	var mature := clampf(g - 1.0, 0.0, 1.0)
	var life_q := snappedf(life, 0.05)  # limit material churn while animating
	match kind:
		"tree", "fruit_tree", "heart_tree", "pine", "willow", "palm":
			_scale("trunk", 0.65 + 0.2 * life + 0.15 * mature)
			_scale("bare", 1.0 - smoothstep(0.3, 0.9, g))
			_scale("canopy", smoothstep(0.1, 1.0, g) * (0.68 + 0.32 * mature))
			if _parts.has("canopy"):
				if kind != "palm":
					_parts["canopy"].position.y = (0.52 if kind != "pine" else 0.18) * (1.55 if kind == "heart_tree" else 1.0) * (0.65 + 0.2 * life + 0.15 * mature)
			_tint(_parts["canopy"], Color(0.62, 0.6, 0.35), life_q)
			_scale("bloom", smoothstep(0.3, 1.0, mature))
			if _parts.has("light"):
				_parts["light"].light_energy = 0.45 * mature
		"meadow":
			_scale("tufts", 0.6 + 0.4 * life)
			_tint(_parts["tufts"], Color(0.72, 0.6, 0.36), life_q)
			_scale("flowers", smoothstep(0.2, 1.0, mature))
		"reeds":
			_scale("reeds", 0.5 + 0.5 * life + 0.15 * mature)
			_tint(_parts["reeds"], Color(0.7, 0.6, 0.38), life_q)
		"spring":
			_scale("water", life)
		"pond":
			_parts["water"].position.y = lerpf(0.0, 0.2, life)
			_parts["water"].scale = Vector3(0.6 + 0.4 * life, 1, 0.6 + 0.4 * life)
			_parts["water"].visible = life > 0.01
			_scale("lilies", mature)
		"stream", "waterfall":
			var fill := clampf(g * 0.5, 0.0, 1.0)
			(_parts["flow"].material_override as ShaderMaterial).set_shader_parameter("fill", fill)
			_parts["flow"].visible = fill > 0.001
			if _parts.has("pool"):
				_scale("pool", smoothstep(0.7, 1.0, fill))
		"terrace":
			_tint(_parts["rows"], Color(0.62, 0.5, 0.32), snappedf(clampf(g * 0.5, 0, 1), 0.05))
		"mill":
			_scale("ruin", 1.0 - smoothstep(0.0, 0.8, life))
			_scale("walls", smoothstep(0.2, 1.0, life))
			_scale("roof", smoothstep(0.3, 1.0, mature + life * 0.25))
		"rabbits", "deer", "ducks", "birds":
			_scale("creatures", smoothstep(0.0, 1.0, g * 0.5))


func _process(delta: float) -> void:
	_t += delta
	if is_deco:
		if kind == "koi" and _parts.has("fish"):
			_parts["fish"].rotation.y = -_t * 0.7
		return
	match kind:
		"mill":
			if _parts.has("spokes"):
				_parts["spokes"].rotation.y = _t * 1.2 * clampf(g - 1.0, 0.0, 1.0)
		"rabbits":
			for i in 2:
				var r: Node3D = _parts.get("r%d" % i)
				if r:
					r.position.y = absf(sin(_t * 2.4 + i * 1.3)) * 0.06
		"ducks":
			for i in 3:
				var d: Node3D = _parts.get("d%d" % i)
				if d:
					var a := _t * 0.35 + i * TAU / 3.0
					d.position = Vector3(cos(a) * 0.32, 0, sin(a) * 0.22)
					d.rotation.y = -a - PI * 0.5
		"birds":
			for i in 4:
				var b: Node3D = _parts.get("b%d" % i)
				if b:
					var a := _t * 0.5 + i * TAU / 4.0
					b.position = Vector3(cos(a) * 0.9, sin(_t + i) * 0.08, sin(a) * 0.6)
					b.rotation.y = -a
					for wing in b.get_children():
						wing.rotation.z = sin(_t * 9.0 + i) * 0.6 * float(wing.get_meta("side"))
		"spring":
			if _parts.has("bubbles"):
				var k := 0
				for bub in _parts["bubbles"].get_children():
					var ph := fmod(_t * 0.7 + k * 0.25, 1.0)
					bub.position = Vector3(sin(k * 2.0) * 0.08, 0.04 + ph * 0.25, cos(k * 2.0) * 0.08)
					bub.scale = Vector3.ONE * (1.0 - ph)
					k += 1
		"tree", "fruit_tree", "heart_tree", "willow", "pine", "palm":
			if _parts.has("canopy"):
				_parts["canopy"].rotation.z = sin(_t * 1.1 + _seed) * 0.03 * clampf(g, 0, 1)
