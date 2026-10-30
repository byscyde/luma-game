class_name IslandWorld
extends Node3D
## 3D diorama of a world, composed from per-area land "blobs": a sandy cove,
## raised plateaus walled by chunky boulders, a ledge and an islet, dressed
## with dense tropical foliage, stairs, huts, stepping stones, a clear
## turquoise sea with shore foam, and clouds. Restoration state is pushed in
## by IslandView; this node only renders.

const RES := 0.16
const PAD := 3.0
const SEA_Y := 0.0

var world: Dictionary
var cols := 11
var rows := 11
var area_ids: Array[String] = []
var area_index: Dictionary = {}       ## area id -> index
var area_defs: Dictionary = {}        ## area id -> area dict
var x0 := 0.0
var z0 := 0.0
var nx := 0
var nz := 0
var heights := PackedFloat32Array()
var props: Dictionary = {}
var decos: Dictionary = {}
var clouds: Dictionary = {}           ## area id -> Node3D (covers locked areas)
var camera: Camera3D
var sun: DirectionalLight3D
var terrain_mat: ShaderMaterial
var _veg: Dictionary = {}
var _progress := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _awake := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _warp := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _patch := FastNoiseLite.new()
var _ponds: Array = []
var _extra_height: Dictionary = {}    ## sea foam stamps for rocks: Vector2i -> h
var cam_target := Vector3.ZERO
var cam_dist := 16.0
var cam_yaw := 0.0
var cam_pitch := deg_to_rad(50.0)
var _t := 0.0


func build(p_world: Dictionary) -> void:
	world = p_world
	var isl: Dictionary = world.get("island", {})
	cols = int(isl.get("cols", 11))
	rows = int(isl.get("rows", 11))
	_warp.seed = 7
	_warp.frequency = 0.45
	_detail.seed = 11
	_detail.frequency = 1.6
	_patch.seed = 23
	_patch.frequency = 0.9
	var i := 0
	for a in world.get("areas", []):
		area_ids.append(a["id"])
		area_index[a["id"]] = i
		area_defs[a["id"]] = a
		i += 1
	for o in world.get("objects", []):
		if o["kind"] == "pond":
			_ponds.append([Vector2(o["pos"][0], o["pos"][1]), 0.62])
	_build_heights()
	_build_terrain()
	_build_lighting()
	_build_boulders()
	_build_scenery()
	for o in world.get("objects", []):
		var p := IslandProp.new()
		p.setup(o, self)
		add_child(p)
		props[o["id"]] = p
	for d in world.get("decorations", []):
		var p := IslandProp.new()
		p.setup(d, self, true)
		add_child(p)
		decos[d["id"]] = p
	_build_vegetation()
	_build_clouds()
	_build_sea()


# ------------------------------------------------------------------ height field

func _blob_weight(a: Dictionary, b: Array, x: float, z: float) -> float:
	var wx := x + _warp.get_noise_2d(x, z) * 0.45
	var wz := z + _warp.get_noise_2d(x + 57.0, z - 13.0) * 0.45
	var d := Vector2(wx, wz).distance_to(Vector2(b[0], b[1]))
	var r: float = b[2]
	if a.get("kind", "") == "beach":
		return smoothstep(r + 0.9, r - 0.5, d)      # long gentle beach slope
	if a.get("kind", "") == "shore":
		return smoothstep(r + 0.45, r - 0.25, d)
	return smoothstep(r + 0.12, r - 0.12, d)        # steep plateau walls


func _blob_h(a: Dictionary, b: Array) -> float:
	return float(b[3]) if b.size() > 3 else float(a.get("height_y", 0.3))


func _land(x: float, z: float) -> Dictionary:
	# Highest weighted plateau wins; returns {h, area, w}
	var best_h := -10.0
	var best_area := ""
	var best_w := 0.0
	for a in world.get("areas", []):
		for b in a.get("blobs", []):
			var w := _blob_weight(a, b, x, z)
			if w <= 0.0:
				continue
			var h := _blob_h(a, b) * w + (-0.35) * (1.0 - w)
			if h > best_h:
				best_h = h
				best_area = a["id"]
				best_w = w
	return {"h": best_h, "area": best_area, "w": best_w}


func _height_fn(x: float, z: float) -> float:
	var land := _land(x, z)
	var h: float = land["h"]
	if land["area"] != "" and float(land["w"]) > 0.95:
		h += _detail.get_noise_2d(x, z) * 0.03
	# sea floor deepens away from land
	# wide sandy shelf: water stays shallow (turquoise) for a while off the coast
	var shore := _coast_distance(x, z)
	var seabed := -0.08 - 0.25 * smoothstep(0.0, 1.6, shore) - 0.7 * smoothstep(1.2, 3.6, shore)
	h = maxf(h, seabed)
	for pd in _ponds:
		var dist: float = Vector2(x, z).distance_to(pd[0])
		h -= 0.22 * smoothstep(float(pd[1]), float(pd[1]) * 0.45, dist)
	return h


## Approximate distance from (x, z) to the nearest land blob edge (0 on land).
func _coast_distance(x: float, z: float) -> float:
	var best := 99.0
	for a in world.get("areas", []):
		for b in a.get("blobs", []):
			best = minf(best, Vector2(x, z).distance_to(Vector2(b[0], b[1])) - float(b[2]))
	return maxf(best, 0.0)


func _build_heights() -> void:
	x0 = -PAD
	z0 = -PAD
	nx = int(ceil((cols + PAD * 2) / RES)) + 1
	nz = int(ceil((rows + PAD * 2) / RES)) + 1
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = _height_fn(x0 + ix * RES, z0 + iz * RES)


func height_at(x: float, z: float) -> float:
	var fx := clampf((x - x0) / RES, 0.0, nx - 1.001)
	var fz := clampf((z - z0) / RES, 0.0, nz - 1.001)
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var a := heights[iz * nx + ix]
	var b := heights[iz * nx + ix + 1]
	var c := heights[(iz + 1) * nx + ix]
	var d := heights[(iz + 1) * nx + ix + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)


func _slope_at(x: float, z: float) -> float:
	var e := RES
	return Vector2(height_at(x + e, z) - height_at(x - e, z), height_at(x, z + e) - height_at(x, z - e)).length() / (2.0 * e)


func area_at(x: float, z: float) -> String:
	var land := _land(x, z)
	return land["area"] if float(land["w"]) > 0.35 else ""


func plateau_y(area_id: String) -> float:
	return float(area_defs.get(area_id, {}).get("height_y", 0.3))


func area_center3d(area_id: String) -> Vector3:
	var a: Dictionary = area_defs.get(area_id, {})
	var sum := Vector2.ZERO
	var wsum := 0.0
	for b in a.get("blobs", []):
		var r: float = b[2]
		sum += Vector2(b[0], b[1]) * r * r
		wsum += r * r
	var c := sum / maxf(wsum, 0.001)
	return Vector3(c.x, plateau_y(area_id), c.y)


func surface(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


# ------------------------------------------------------------------ terrain

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock_a := Color(0.74, 0.62, 0.5)
	var rock_b := Color(0.6, 0.5, 0.42)
	var sand := Color(0.97, 0.91, 0.76)
	var wet := Color(0.88, 0.82, 0.66)
	for iz in nz:
		for ix in nx:
			var x := x0 + ix * RES
			var z := z0 + iz * RES
			var h := heights[iz * nx + ix]
			var hx := heights[iz * nx + mini(ix + 1, nx - 1)] - heights[iz * nx + maxi(ix - 1, 0)]
			var hz := heights[mini(iz + 1, nz - 1) * nx + ix] - heights[maxi(iz - 1, 0) * nx + ix]
			var slope := Vector2(hx, hz).length() / (2.0 * RES)
			var var_n := 0.5 + 0.5 * _detail.get_noise_2d(x * 2.0 + 9.0, z * 2.0)
			var land := _land(x, z)
			var area: String = land["area"]
			var a: Dictionary = area_defs.get(area, {})
			var base := rock_a.lerp(rock_b, var_n)
			var grassy := 0.0
			if h < 0.05:
				base = wet.darkened(clampf(-h * 0.25, 0.0, 0.25))
			elif slope < 1.1:
				base = sand.lerp(Color(0.93, 0.86, 0.7), var_n * 0.5)
				if a.get("kind", "") == "beach":
					# grassy patches scattered over the sand
					var pn := _patch.get_noise_2d(x, z)
					grassy = smoothstep(0.08, 0.22, pn) * smoothstep(0.12, 0.2, h)
				elif h > 0.3:
					grassy = 1.0
			var ai := float(area_index.get(area, -1)) if grassy > 0.0 else -1.0
			st.set_color(base)
			st.set_uv(Vector2(var_n, 0))
			st.set_uv2(Vector2(ai, grassy))
			st.add_vertex(Vector3(x, h, z))
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			var b := a + 1
			var c := a + nx
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(d)
			st.add_index(a); st.add_index(d); st.add_index(c)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://resources/shaders/terrain.gdshader")
	terrain_mat.set_shader_parameter("progress", _progress)
	terrain_mat.set_shader_parameter("awake", _awake)
	mi.material_override = terrain_mat
	add_child(mi)


# ------------------------------------------------------------------ boulders (cliff walls)

const ROCK_COLS := [Color(0.7, 0.58, 0.47), Color(0.6, 0.49, 0.4), Color(0.76, 0.65, 0.54), Color(0.55, 0.47, 0.41), Color(0.66, 0.6, 0.55)]


func _build_boulders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# few, large facets read as chiselled boulders rather than soft lumps
	var meshes := [LowPoly.blob(1.0, 0, 0.22, 1, Vector3(1.0, 0.85, 1.0)), LowPoly.blob(1.0, 1, 0.26, 2, Vector3(1.1, 0.75, 0.9)),
		LowPoly.blob(1.0, 0, 0.25, 3, Vector3(0.9, 1.0, 1.0))]
	var buckets: Array = [[], [], []]
	var step := 0.34
	var gz := z0
	while gz < z0 + nz * RES:
		var gx := x0
		while gx < x0 + nx * RES:
			var x := gx + rng.randf_range(-0.12, 0.12)
			var z := gz + rng.randf_range(-0.12, 0.12)
			gx += step
			var slope := _slope_at(x, z)
			var h := height_at(x, z)
			if slope < 1.4 or h < -0.3:
				continue
			# find the drop: sample around for the low and high side
			var hi := h
			var lo := h
			for k in 8:
				var a := TAU * k / 8.0
				var hh := height_at(x + cos(a) * 0.35, z + sin(a) * 0.35)
				hi = maxf(hi, hh)
				lo = minf(lo, hh)
			var drop := hi - maxf(lo, -0.3)
			if drop < 0.25:
				continue
			var s := clampf(drop * 0.36, 0.16, 0.5) * rng.randf_range(0.8, 1.2)
			var y := lerpf(maxf(lo, -0.25), hi, rng.randf_range(0.25, 0.6))
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
			var col: Color = ROCK_COLS[rng.randi() % ROCK_COLS.size()]
			col = col.darkened(rng.randf_range(0.0, 0.12))
			buckets[rng.randi() % 3].append([Transform3D(basis, Vector3(x, y, z)), col])
			if lo < 0.1:
				_stamp(x, z, s)
		gz += step
	for i in 3:
		_rock_multimesh(meshes[i], buckets[i])


func _stamp(x: float, z: float, r: float) -> void:
	# record rock footprint so the sea draws foam around it
	var c := Vector2i(roundi((x - x0) / RES), roundi((z - z0) / RES))
	var n := int(ceil(r / RES))
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			if Vector2(dx, dz).length() * RES <= r:
				var k := c + Vector2i(dx, dz)
				_extra_height[k] = maxf(float(_extra_height.get(k, -9.0)), 0.05)


func _rock_multimesh(mesh: Mesh, items: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = LowPoly.mat(Color.WHITE, 0.0, 0.92, true)
	add_child(mmi)
	return mmi


# ------------------------------------------------------------------ scenery

func _build_scenery() -> void:
	for s in world.get("scenery", []):
		match s.get("kind", ""):
			"stairs_stone", "stairs_wood":
				_stairs(s)
			"stone_hut":
				_stone_hut(s)
			"shed":
				_shed(s)
			"crate":
				_crate(Vector3(s["pos"][0], 0, s["pos"][1]), 0.22)
			"stepping_stones":
				_stepping(s["path"])
			"boulder":
				var p := surface(s["pos"][0], s["pos"][1])
				var sc: float = s.get("s", 1.0)
				LowPoly.instance(LowPoly.blob(0.32 * sc, 1, 0.2, int(p.x * 10)), LowPoly.mat(ROCK_COLS[int(p.z) % 4]), p + Vector3(0, 0.06, 0), self)
				_stamp(p.x, p.z, 0.32 * sc)
			"rowboat":
				_rowboat(s)


func _stairs(s: Dictionary) -> void:
	var a := surface(s["from"][0], s["from"][1])
	var b := surface(s["to"][0], s["to"][1])
	var wood: bool = s["kind"] == "stairs_wood"
	var steps := maxi(4, int(ceil((b.y - a.y) / 0.11)))
	var dir := Vector3(b.x - a.x, 0, b.z - a.z)
	var yaw := atan2(dir.x, dir.z)
	var holder := Node3D.new()
	add_child(holder)
	for i in steps:
		var u := (i + 0.5) / steps
		var p := Vector3(lerpf(a.x, b.x, u), lerpf(a.y, b.y, (i + 1.0) / steps), lerpf(a.z, b.z, u))
		var col := Color(0.62, 0.43, 0.28).lerp(Color(0.55, 0.37, 0.24), float(i % 2)) if wood else Color(0.86, 0.84, 0.8).lerp(Color(0.76, 0.74, 0.7), Painter.hash01(i))
		var step := LowPoly.instance(LowPoly.slab(Vector3(0.5 if wood else 0.56, 0.08, dir.length() / steps + 0.06), 0.02), LowPoly.mat(col), p - Vector3(0, 0.08, 0), holder)
		step.rotation.y = yaw
		# risers / support so steps read as solid
		var riser := LowPoly.instance(LowPoly.slab(Vector3(0.48 if wood else 0.54, maxf(0.05, p.y - a.y), dir.length() / steps), 0.0),
			LowPoly.mat(col.darkened(0.25)), Vector3(p.x, a.y - 0.02, p.z), holder)
		riser.rotation.y = yaw
	if wood:
		for side in [-1.0, 1.0]:
			var off: Vector3 = Vector3(cos(yaw), 0, -sin(yaw)) * 0.28 * side
			for k in 3:
				var u := k / 2.0
				var p: Vector3 = a.lerp(b, u) + off
				LowPoly.instance(LowPoly.cyl(0.03, 0.03, 0.32, 5), LowPoly.mat(Color(0.48, 0.33, 0.21)), p - Vector3(0, 0.02, 0), holder)


func _stone_hut(s: Dictionary) -> void:
	var p := surface(s["pos"][0], s["pos"][1])
	var n := Node3D.new()
	n.position = p
	n.rotation.y = s.get("rot", 0.0)
	add_child(n)
	var wall := Color(0.93, 0.92, 0.88)
	LowPoly.instance(LowPoly.slab(Vector3(0.62, 0.42, 0.52), 0.05), LowPoly.mat(wall), Vector3.ZERO, n)
	LowPoly.instance(LowPoly.roof(0.72, 0.62, 0.3), LowPoly.mat(Color(0.88, 0.87, 0.84)), Vector3(0, 0.42, 0), n)
	LowPoly.instance(LowPoly.slab(Vector3(0.12, 0.2, 0.12), 0.02), LowPoly.mat(Color(0.78, 0.76, 0.72)), Vector3(0.18, 0.5, -0.1), n)
	LowPoly.instance(LowPoly.slab(Vector3(0.16, 0.26, 0.03), 0.02), LowPoly.mat(Color(0.35, 0.3, 0.28)), Vector3(0, 0, 0.26), n)
	LowPoly.instance(LowPoly.slab(Vector3(0.12, 0.12, 0.03), 0.01), LowPoly.mat(Color(0.32, 0.36, 0.38)), Vector3(-0.2, 0.18, 0.26), n)


func _shed(s: Dictionary) -> void:
	var p := surface(s["pos"][0], s["pos"][1])
	var n := Node3D.new()
	n.position = p
	n.rotation.y = s.get("rot", 0.0)
	add_child(n)
	var plank := Color(0.66, 0.46, 0.3)
	for i in 5:
		LowPoly.instance(LowPoly.slab(Vector3(0.5, 0.075, 0.42), 0.01), LowPoly.mat(plank.darkened(0.06 * (i % 2))), Vector3(0, i * 0.075, 0), n)
	LowPoly.instance(LowPoly.slab(Vector3(0.18, 0.28, 0.03), 0.01), LowPoly.mat(Color(0.42, 0.28, 0.18)), Vector3(0, 0, 0.215), n)
	var roof := LowPoly.instance(LowPoly.slab(Vector3(0.62, 0.05, 0.56), 0.01), LowPoly.mat(Color(0.52, 0.35, 0.22)), Vector3(0, 0.4, 0), n)
	roof.rotation.x = -0.18
	_crate(p + Vector3(0.38, 0, 0.28), 0.16)


func _crate(at: Vector3, s: float) -> void:
	var p := surface(at.x, at.z)
	var n := Node3D.new()
	n.position = p
	n.rotation.y = Painter.hash01(int(at.x * 100 + at.z)) * TAU
	add_child(n)
	LowPoly.instance(LowPoly.slab(Vector3(s, s, s), 0.01), LowPoly.mat(Color(0.72, 0.52, 0.32)), Vector3.ZERO, n)
	for side in [-1.0, 1.0]:
		LowPoly.instance(LowPoly.slab(Vector3(s * 1.04, s * 0.16, s * 1.04), 0.0), LowPoly.mat(Color(0.52, 0.36, 0.22)), Vector3(0, s * (0.5 + 0.38 * side) - s * 0.08, 0), n)


func _stepping(path: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in path.size() - 1:
		var a := Vector2(path[i][0], path[i][1])
		var b := Vector2(path[i + 1][0], path[i + 1][1])
		var n := int(a.distance_to(b) / 0.32)
		for k in n:
			var p := a.lerp(b, (k + rng.randf()) / n) + Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
			var s := rng.randf_range(0.14, 0.22)
			var mi := LowPoly.instance(LowPoly.blob(s, 1, 0.15, k + i * 13, Vector3(1.2, 0.18, 1.0)), LowPoly.mat(Color(0.8, 0.79, 0.76).lerp(Color(0.7, 0.69, 0.67), rng.randf())), surface(p.x, p.y) + Vector3(0, 0.01, 0), self, false)
			mi.rotation.y = rng.randf() * TAU
	# scattered loose slabs across the beach as in a well-trodden cove
	for k in 18:
		var x := rng.randf_range(4.0, 7.4)
		var z := rng.randf_range(6.0, 9.6)
		if area_at(x, z) != "spring_glade" or height_at(x, z) < 0.08:
			continue
		var s := rng.randf_range(0.08, 0.16)
		LowPoly.instance(LowPoly.blob(s, 1, 0.2, 200 + k, Vector3(1.3, 0.25, 1.0)), LowPoly.mat(Color(0.78, 0.77, 0.74)), surface(x, z), self, false)


func _rowboat(s: Dictionary) -> void:
	var n := Node3D.new()
	n.position = Vector3(s["pos"][0], 0.02, s["pos"][1])
	n.rotation.y = s.get("rot", 0.0)
	add_child(n)
	LowPoly.instance(LowPoly.blob(0.26, 1, 0.0, 1, Vector3(0.55, 0.32, 1.0)), LowPoly.mat(Color(0.96, 0.96, 0.94)), Vector3.ZERO, n)
	LowPoly.instance(LowPoly.blob(0.22, 1, 0.0, 1, Vector3(0.5, 0.2, 0.92)), LowPoly.mat(Color(0.6, 0.45, 0.32)), Vector3(0, 0.04, 0), n)
	_stamp(n.position.x, n.position.z, 0.22)
	n.set_meta("bob", true)
	n.name = "Rowboat"


# ------------------------------------------------------------------ sea

func _build_sea() -> void:
	var img := Image.create(nx, nz, false, Image.FORMAT_RF)
	for iz in nz:
		for ix in nx:
			var h := heights[iz * nx + ix]
			var k := Vector2i(ix, iz)
			if _extra_height.has(k):
				h = maxf(h, float(_extra_height[k]))
			img.set_pixel(ix, iz, Color(h, 0, 0))
	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://resources/shaders/sea.gdshader")
	mat.set_shader_parameter("heightmap", tex)
	mat.set_shader_parameter("bounds", Vector4(x0, z0, (nx - 1) * RES, (nz - 1) * RES))
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	plane.subdivide_width = 0
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(cols * 0.5, SEA_Y, rows * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_lighting() -> void:
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 0.66
	sun.rotation_degrees = Vector3(-46, -40, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.45, 0.78, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.84, 0.95)
	env.ambient_light_energy = 0.24
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.near = 0.5
	camera.far = 140.0
	add_child(camera)
	cam_target = Vector3(cols * 0.5, 0.6, rows * 0.5 + 0.3)
	cam_yaw = deg_to_rad(-12.0)
	_apply_camera()


func _apply_camera() -> void:
	var dir := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	camera.position = cam_target + dir * cam_dist
	camera.look_at(cam_target, Vector3.UP)


## Camera distance that frames the whole island. [param aspect] is the full
## viewport's width/height; [param visible_frac] the share of its height not
## covered by UI (the image is shifted into that band with v_offset).
func fit_distance(aspect: float, visible_frac := 1.0) -> float:
	var radius := Vector2(cols, rows).length() * 0.5
	var half_t := tan(deg_to_rad(camera.fov) * 0.5)
	var vfov := 2.0 * atan(half_t * visible_frac)
	var hfov := 2.0 * atan(half_t * aspect)
	# the diamond-shaped island needs less than its bounding circle when wide,
	# but narrow (portrait) views are limited by its full diagonal
	var view_aspect := aspect / maxf(visible_frac, 0.01)
	var snug := lerpf(0.9, 0.74, clampf((view_aspect - 0.5) / 0.6, 0.0, 1.0))
	return radius / sin(minf(vfov, hfov) * 0.5) * snug


func set_view(target: Vector3, dist: float) -> void:
	cam_target = target
	cam_dist = dist
	_apply_camera()


# ------------------------------------------------------------------ vegetation

const GROVE := {
	"spring_glade": ["palm", "palm", "tree"],
	"willow_brook": ["palm", "willow", "tree"],
	"old_mill": ["tree", "tree", "palm"],
	"stone_terraces": ["pine", "tree", "palm"],
	"lily_ponds": ["palm", "palm", "tree"],
	"heart_falls": ["tree", "pine", "tree"],
}


func _build_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var avoid: Array[Vector2] = []
	for o in world.get("objects", []):
		avoid.append(Vector2(o["pos"][0], o["pos"][1]))
	for d in world.get("decorations", []):
		avoid.append(Vector2(d["pos"][0], d["pos"][1]))
	for s in world.get("scenery", []):
		if s.has("pos"):
			avoid.append(Vector2(s["pos"][0], s["pos"][1]))
	var plant_meshes := [LowPoly.plant("fern", 1), LowPoly.plant("broad", 2), LowPoly.plant("fern", 3)]
	for a in world.get("areas", []):
		var aid: String = a["id"]
		var c := area_center3d(aid)
		var radius := 0.0
		for b in a.get("blobs", []):
			radius = maxf(radius, Vector2(b[0], b[1]).distance_to(Vector2(c.x, c.z)) + float(b[2]))
		var pts_plant: Array = [[], [], []]
		var pts_bush: Array[Vector3] = []
		var pts_flower: Array[Vector3] = []
		var tries := 0
		var beach: bool = a.get("kind", "") == "beach"
		var want_plants := 26 if beach else 46
		var placed_plants := 0
		while (placed_plants < want_plants or pts_flower.size() < 50 or pts_bush.size() < 10) and tries < 5000:
			tries += 1
			var x := c.x + rng.randf_range(-radius, radius)
			var z := c.z + rng.randf_range(-radius, radius)
			if area_at(x, z) != aid:
				continue
			var y := height_at(x, z)
			if y < 0.12 or _slope_at(x, z) > 1.0:
				continue
			if beach and _patch.get_noise_2d(x, z) < 0.12:
				continue  # foliage clusters on the grassy patches of the cove
			var ok := true
			for p in avoid:
				if p.distance_to(Vector2(x, z)) < 0.3:
					ok = false
					break
			if not ok:
				continue
			# dense along plateau rims, like hand-placed edge planting
			var p3 := Vector3(x, y, z)
			if placed_plants < want_plants:
				pts_plant[rng.randi() % 3].append(p3)
				placed_plants += 1
			elif pts_bush.size() < 10:
				pts_bush.append(p3)
			elif pts_flower.size() < 50:
				pts_flower.append(p3)
		var trees := Node3D.new()
		trees.name = "Grove_" + aid
		add_child(trees)
		var placed := 0
		var t2 := 0
		while placed < (5 if beach else 7) and t2 < 600:
			t2 += 1
			var x := c.x + rng.randf_range(-radius, radius)
			var z := c.z + rng.randf_range(-radius, radius)
			if area_at(x, z) != aid or height_at(x, z) < 0.15 or _slope_at(x, z) > 0.6:
				continue
			if beach and _patch.get_noise_2d(x, z) < 0.1:
				continue
			var near := false
			for p in avoid:
				if p.distance_to(Vector2(x, z)) < 0.55:
					near = true
					break
			if near:
				continue
			avoid.append(Vector2(x, z))
			var kinds: Array = GROVE.get(aid, ["tree"])
			var tp := IslandProp.new()
			tp.setup({"id": "%s_grove_%d" % [aid, placed], "kind": kinds[placed % kinds.size()],
				"pos": [x, z], "area": aid, "stages": 2}, self)
			tp.scale = Vector3.ONE * rng.randf_range(0.7, 1.0)
			trees.add_child(tp)
			placed += 1
		var entry := {
			"grove": trees,
			"plants": [],
			"bushes": _multimesh(LowPoly.blob(0.15, 1, 0.18, 3, Vector3(1, 0.75, 1)), pts_bush, rng, 0.8, 1.4),
			"flowers": _multimesh(LowPoly.blob(0.05, 0, 0.1, 4), pts_flower, rng, 0.8, 1.3),
			"pts_flower": pts_flower,
		}
		for k in 3:
			var arr: Array[Vector3] = []
			arr.assign(pts_plant[k])
			entry["plants"].append(_multimesh(plant_meshes[k], arr, rng, 0.75, 1.35, true))
		_veg[aid] = entry
		set_area_progress(aid, 0.0)


func _multimesh(mesh: Mesh, pts: Array[Vector3], rng: RandomNumberGenerator, smin: float, smax: float, double_sided := false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		var s := rng.randf_range(smin, smax)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, pts[i]))
		mm.set_instance_color(i, Color.WHITE)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = LowPoly.mat(Color.WHITE, 0.0, 0.9, true, double_sided)
	add_child(mmi)
	mmi.set_meta("pts", pts)
	return mmi


const FLOWER_COLS := [Color(0.72, 0.42, 0.92), Color(1.0, 0.86, 0.3), Color(0.62, 0.36, 0.86), Color(1, 1, 1), Color(1.0, 0.78, 0.25)]


func set_area_progress(area_id: String, p: float) -> void:
	var i: int = area_index.get(area_id, -1)
	if i < 0:
		return
	_progress[i] = p
	terrain_mat.set_shader_parameter("progress", _progress)
	var v: Dictionary = _veg.get(area_id, {})
	if v.is_empty():
		return
	var dry := Color(0.66, 0.56, 0.36)
	for k in (v["plants"] as Array).size():
		var mmi: MultiMeshInstance3D = v["plants"][k]
		var mm := mmi.multimesh
		var pts: Array = mmi.get_meta("pts")
		for j in mm.instance_count:
			var lush := Color(0.28, 0.6, 0.18).lerp(Color(0.46, 0.74, 0.24), Painter.hash01(j * 3 + k * 17 + i))
			mm.set_instance_color(j, dry.lerp(lush, p))
			var s := (0.55 + 0.45 * p) * (0.8 + 0.5 * Painter.hash01(j + k * 31 + i))
			mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, Painter.hash01(j * 7 + k) * TAU).scaled(Vector3(s, s, s)), pts[j]))
	var bushes: MultiMesh = v["bushes"].multimesh
	for k in bushes.instance_count:
		var lush := Color(0.24, 0.52, 0.2).lerp(Color(0.38, 0.66, 0.24), Painter.hash01(k * 7 + i))
		bushes.set_instance_color(k, Color(0.58, 0.48, 0.32).lerp(lush, p))
	for tp in (v["grove"] as Node3D).get_children():
		(tp as IslandProp).set_growth(p * 2.0)
	var bloom := smoothstep(0.45, 1.0, p)
	var flowers: MultiMesh = v["flowers"].multimesh
	var pts: Array[Vector3] = v["pts_flower"]
	for k in flowers.instance_count:
		var s := maxf(0.001, bloom * (0.8 + 0.5 * Painter.hash01(k + i * 13)))
		flowers.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(s, s, s)), pts[k] + Vector3(0, 0.08 * bloom, 0)))
		flowers.set_instance_color(k, FLOWER_COLS[(k + i) % FLOWER_COLS.size()])


# ------------------------------------------------------------------ clouds

func _cloud(at: Vector3, scale_f: float, seed_n: int, parent: Node3D) -> Node3D:
	var node := Node3D.new()
	node.position = at
	parent.add_child(node)
	var white := LowPoly.mat(Color(0.98, 0.99, 1.0), 0.18, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	for k in 7:
		var b := LowPoly.blob(rng.randf_range(0.45, 0.75) * scale_f, 2, 0.04, k + seed_n, Vector3(1.25, 0.8, 1.0))
		var off := Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.1, 0.3), rng.randf_range(-0.6, 0.6)) * scale_f
		var mi := LowPoly.instance(b, white, off, node, false)
		mi.set_meta("base", off)
	return node


func _build_clouds() -> void:
	for a in world.get("areas", []):
		var c := area_center3d(a["id"])
		var node := _cloud(c + Vector3(0, 0.9, 0), 1.0, hash(a["id"]) % 1000, self)
		node.name = "Cloud_" + a["id"]
		clouds[a["id"]] = node
	var k := 0
	for s in world.get("scenery", []):
		if s.get("kind", "") == "cloud":
			var p: Array = s["pos"]
			var n := _cloud(Vector3(p[0], p[1], p[2]), float(s.get("s", 1.0)), 500 + k, self)
			n.name = "SkyCloud%d" % k
			k += 1


func set_area_awake(area_id: String, v: float) -> void:
	var i: int = area_index.get(area_id, -1)
	if i < 0:
		return
	_awake[i] = v
	terrain_mat.set_shader_parameter("awake", _awake)
	var c: Node3D = clouds.get(area_id)
	if c:
		c.visible = v < 0.99
		c.scale = Vector3.ONE * maxf(0.001, 1.0 - v)
		c.position.y = plateau_y(area_id) + 0.9 + v * 1.6


# ------------------------------------------------------------------ picking

func pick(screen_pos: Vector2) -> Vector3:
	var o := camera.project_ray_origin(screen_pos)
	var n := camera.project_ray_normal(screen_pos)
	var t := 0.0
	while t < 90.0:
		var p := o + n * t
		if p.y <= maxf(height_at(p.x, p.z), 0.0):
			return p
		t += 0.04
	return Vector3(INF, INF, INF)


func _process(delta: float) -> void:
	_t += delta
	for c in get_children():
		if c.name.begins_with("Cloud_") or c.name.begins_with("SkyCloud"):
			if not c.visible:
				continue
			var k := 0
			for mi in c.get_children():
				var b: Vector3 = mi.get_meta("base")
				mi.position = b + Vector3(sin(_t * 0.3 + k) * 0.1, sin(_t * 0.5 + k * 1.7) * 0.04, 0)
				k += 1
		elif c.name == "Rowboat":
			c.position.y = 0.02 + sin(_t * 1.3) * 0.015
			c.rotation.z = sin(_t * 1.1) * 0.04
