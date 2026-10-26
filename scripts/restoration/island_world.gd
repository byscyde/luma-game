class_name IslandWorld
extends Node3D
## 3D low-poly diorama of a world: terrain from a height field (three terraces,
## organic coastline, beaches, cliffs), a depth-shaded sea, restorable props,
## vegetation that greens with each area's progress, and clouds over locked
## areas. Purely presentational; IslandView feeds it display values.

const RES := 0.2
const PLATEAU := [0.28, 0.86, 1.44]
const SEABED := -0.8
const PAD := 4.0

var world: Dictionary
var cols := 8
var rows := 10
var area_ids: Array[String] = []
var area_index: Dictionary = {}       ## area id -> index
var area_level: Dictionary = {}       ## area id -> plateau level
var cell_area: Dictionary = {}        ## Vector2i -> area index
var x0 := 0.0
var z0 := 0.0
var nx := 0
var nz := 0
var heights := PackedFloat32Array()
var props: Dictionary = {}            ## object id -> IslandProp
var decos: Dictionary = {}            ## decoration id -> IslandProp
var clouds: Dictionary = {}           ## area id -> Node3D
var camera: Camera3D
var sun: DirectionalLight3D
var terrain_mat: ShaderMaterial
var _veg: Dictionary = {}             ## area id -> {tufts, bushes, flowers: MultiMeshInstance3D, base: Array}
var _progress := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _awake := PackedFloat32Array([0, 0, 0, 0, 0, 0])
var _warp := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _ponds: Array = []                ## [Vector2 centre, radius]
var cam_target := Vector3.ZERO
var cam_dist := 14.0
var cam_yaw := 0.0
var cam_pitch := deg_to_rad(44.0)
var _t := 0.0


func build(p_world: Dictionary) -> void:
	world = p_world
	var isl: Dictionary = world.get("island", {})
	cols = int(isl.get("cols", 8))
	rows = int(isl.get("rows", 10))
	_warp.seed = 7
	_warp.frequency = 0.35
	_detail.seed = 11
	_detail.frequency = 1.3
	var i := 0
	for a in world.get("areas", []):
		area_ids.append(a["id"])
		area_index[a["id"]] = i
		area_level[a["id"]] = int(a.get("height", 0))
		var r: Array = a["rect"]
		for gy in range(int(r[1]), int(r[3]) + 1):
			for gx in range(int(r[0]), int(r[2]) + 1):
				cell_area[Vector2i(gx, gy)] = i
		i += 1
	for o in world.get("objects", []):
		if o["kind"] == "pond":
			_ponds.append([Vector2(o["pos"][0], o["pos"][1]), 0.62])
	_build_heights()
	_build_terrain()
	_build_sea()
	_build_lighting()
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


# ------------------------------------------------------------------ height field

func _cell_level(x: float, z: float) -> int:
	var gx := clampi(floori(x), 0, cols - 1)
	var gy := clampi(floori(z), 0, rows - 1)
	var idx: int = cell_area.get(Vector2i(gx, gy), -1)
	if idx < 0:
		return 0
	return int(area_level[area_ids[idx]])


func area_at(x: float, z: float) -> String:
	if x < -0.6 or z < -0.6 or x > cols + 0.6 or z > rows + 0.6:
		return ""
	var gx := clampi(floori(x), 0, cols - 1)
	var gy := clampi(floori(z), 0, rows - 1)
	var idx: int = cell_area.get(Vector2i(gx, gy), -1)
	return "" if idx < 0 else area_ids[idx]


func _coast_sdf(x: float, z: float) -> float:
	var c := Vector2(cols * 0.5, rows * 0.5)
	var half := Vector2(cols * 0.5 + 0.55, rows * 0.5 + 0.55)
	var r := 1.9
	var q := (Vector2(x, z) - c).abs() - (half - Vector2(r, r))
	var d := Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
	return d + _warp.get_noise_2d(x * 1.3 + 40.0, z * 1.3) * 0.55


func _height_fn(x: float, z: float) -> float:
	var wx := x + _warp.get_noise_2d(x, z) * 0.32
	var wz := z + _warp.get_noise_2d(x + 57.0, z - 13.0) * 0.32
	var lvl := _cell_level(wx, wz)
	var land_h: float = PLATEAU[lvl] + _detail.get_noise_2d(x, z) * 0.035
	var d := _coast_sdf(x, z)
	var land: float
	if lvl == 0:
		land = smoothstep(0.75, -0.55, d)   # gentle beach
	else:
		land = smoothstep(0.32, -0.12, d)   # cliffs into the sea
	# continental shelf: shallow turquoise near shore, deepening outward
	var seabed := -0.18 - 0.75 * smoothstep(0.0, 3.2, d)
	var h := lerpf(seabed, land_h, land)
	for pd in _ponds:
		var dist: float = Vector2(x, z).distance_to(pd[0])
		h -= 0.24 * smoothstep(float(pd[1]), float(pd[1]) * 0.45, dist) * land
	return h


func _build_heights() -> void:
	x0 = -PAD
	z0 = -PAD
	nx = int(ceil((cols + PAD * 2) / RES)) + 1
	nz = int(ceil((rows + PAD * 2) / RES)) + 1
	heights.resize(nx * nz)
	for iz in nz:
		for ix in nx:
			heights[iz * nx + ix] = _height_fn(x0 + ix * RES, z0 + iz * RES)


## Bilinear terrain height at world x/z.
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


func plateau_y(area_id: String) -> float:
	return PLATEAU[int(area_level.get(area_id, 0))]


func surface(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


# ------------------------------------------------------------------ terrain

func _build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock_a := Color(0.80, 0.73, 0.64)
	var rock_b := Color(0.66, 0.6, 0.55)
	var sand := Color(0.94, 0.88, 0.74)
	var wet := Color(0.84, 0.78, 0.64)
	for iz in nz:
		for ix in nx:
			var x := x0 + ix * RES
			var z := z0 + iz * RES
			var h := heights[iz * nx + ix]
			var hx := heights[iz * nx + mini(ix + 1, nx - 1)] - heights[iz * nx + maxi(ix - 1, 0)]
			var hz := heights[mini(iz + 1, nz - 1) * nx + ix] - heights[maxi(iz - 1, 0) * nx + ix]
			var slope := Vector2(hx, hz).length() / (2.0 * RES)
			var var_n := 0.5 + 0.5 * _detail.get_noise_2d(x * 2.0 + 9.0, z * 2.0)
			var base := rock_a.lerp(rock_b, 0.5 + 0.5 * sin(h * 22.0 + _detail.get_noise_2d(x, z) * 3.0))
			var grassy := 0.0
			if h < 0.02:
				base = wet.darkened(clampf(-h * 0.35, 0.0, 0.3))
			elif slope < 0.9:
				var beachness := smoothstep(0.34, 0.12, h) if _cell_level(x, z) == 0 else 0.0
				base = sand.lerp(Color(0.9, 0.84, 0.68), var_n * 0.4)
				grassy = 1.0 - beachness
				if _coast_sdf(x, z) > -0.25:
					grassy *= 0.0
			var area := area_at(x, z)
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


func _build_sea() -> void:
	var img := Image.create(nx, nz, false, Image.FORMAT_RF)
	for iz in nz:
		for ix in nx:
			img.set_pixel(ix, iz, Color(heights[iz * nx + ix], 0, 0))
	var tex := ImageTexture.create_from_image(img)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://resources/shaders/sea.gdshader")
	mat.set_shader_parameter("heightmap", tex)
	mat.set_shader_parameter("bounds", Vector4(x0, z0, (nx - 1) * RES, (nz - 1) * RES))
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = plane
	mi.material_override = mat
	mi.position = Vector3(cols * 0.5, 0.0, rows * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_lighting() -> void:
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 0.62
	sun.rotation_degrees = Vector3(-38, -55, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.67, 0.86, 0.9)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.74, 0.82, 0.95)
	env.ambient_light_energy = 0.2
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	env.fog_enabled = false
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	camera = Camera3D.new()
	camera.fov = 30.0
	camera.near = 0.5
	camera.far = 120.0
	add_child(camera)
	cam_target = Vector3(cols * 0.5, 0.5, rows * 0.5 + 0.2)
	cam_yaw = deg_to_rad(-28.0)
	_apply_camera()


func _apply_camera() -> void:
	var dir := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	camera.position = cam_target + dir * cam_dist
	camera.look_at(cam_target, Vector3.UP)


## Distance so the whole island fits a viewport of this aspect (w/h).
func fit_distance(aspect: float) -> float:
	var radius := Vector2(cols + 1.5, rows + 1.5).length() * 0.5
	var vfov := deg_to_rad(camera.fov)
	var hfov := 2.0 * atan(tan(vfov * 0.5) * aspect)
	return radius / sin(minf(vfov, hfov) * 0.5) * 0.78


func set_view(target: Vector3, dist: float) -> void:
	cam_target = target
	cam_dist = dist
	_apply_camera()


# ------------------------------------------------------------------ vegetation

func _build_vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var avoid: Array[Vector2] = []
	for o in world.get("objects", []):
		avoid.append(Vector2(o["pos"][0], o["pos"][1]))
	for d in world.get("decorations", []):
		avoid.append(Vector2(d["pos"][0], d["pos"][1]))
	for a in world.get("areas", []):
		var r: Array = a["rect"]
		var pts_tuft: Array[Vector3] = []
		var pts_bush: Array[Vector3] = []
		var pts_flower: Array[Vector3] = []
		var tries := 0
		while (pts_tuft.size() < 70 or pts_bush.size() < 14 or pts_flower.size() < 40) and tries < 3000:
			tries += 1
			var x := rng.randf_range(float(r[0]), float(r[2]) + 1.0)
			var z := rng.randf_range(float(r[1]), float(r[3]) + 1.0)
			if _coast_sdf(x, z) > -0.45:
				continue
			var ok := true
			for p in avoid:
				if p.distance_to(Vector2(x, z)) < 0.42:
					ok = false
					break
			if not ok:
				continue
			var y := height_at(x, z)
			if absf(y - plateau_y(a["id"])) > 0.08:
				continue  # keep off cliffs and pond bowls
			var p3 := Vector3(x, y, z)
			if pts_tuft.size() < 70:
				pts_tuft.append(p3)
			elif pts_bush.size() < 14:
				pts_bush.append(p3)
			else:
				pts_flower.append(p3)
		var trees := Node3D.new()
		trees.name = "Grove_" + a["id"]
		add_child(trees)
		var placed := 0
		var t2 := 0
		while placed < 7 and t2 < 400:
			t2 += 1
			var x := rng.randf_range(float(r[0]) + 0.2, float(r[2]) + 0.8)
			var z := rng.randf_range(float(r[1]) + 0.2, float(r[3]) + 0.8)
			if _coast_sdf(x, z) > -0.6 or absf(height_at(x, z) - plateau_y(a["id"])) > 0.06:
				continue
			var near := false
			for p in avoid:
				if p.distance_to(Vector2(x, z)) < 0.55:
					near = true
					break
			if near:
				continue
			avoid.append(Vector2(x, z))
			var kinds := ["tree", "pine", "tree", "bush"]
			var tp := IslandProp.new()
			tp.setup({"id": "%s_grove_%d" % [a["id"], placed], "kind": kinds[placed % 4] if kinds[placed % 4] != "bush" else "tree",
				"pos": [x, z], "area": a["id"], "stages": 2}, self)
			tp.scale = Vector3.ONE * rng.randf_range(0.55, 0.8)
			trees.add_child(tp)
			placed += 1
		var entry := {
			"grove": trees,
			"tufts": _multimesh(LowPoly.cyl(0.045, 0.0, 0.16, 4), pts_tuft, rng, 0.7, 1.3),
			"bushes": _multimesh(LowPoly.blob(0.14, 0, 0.18, 3, Vector3(1, 0.8, 1)), pts_bush, rng, 0.7, 1.4),
			"flowers": _multimesh(LowPoly.blob(0.045, 0, 0.1, 4), pts_flower, rng, 0.8, 1.2),
			"pts_flower": pts_flower,
			"seed": rng.randi(),
		}
		_veg[a["id"]] = entry
		set_area_progress(a["id"], 0.0)


func _multimesh(mesh: Mesh, pts: Array[Vector3], rng: RandomNumberGenerator, smin: float, smax: float) -> MultiMeshInstance3D:
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
	mmi.material_override = LowPoly.mat(Color.WHITE, 0.0, 0.9, true)
	add_child(mmi)
	return mmi


const FLOWER_COLS := [Color(0.98, 0.55, 0.62), Color(1, 1, 1), Color(0.75, 0.62, 0.95), Color(1.0, 0.82, 0.3)]


## p in 0..1: ground and scatter vegetation colour; flowers bloom past 0.55.
func set_area_progress(area_id: String, p: float) -> void:
	var i: int = area_index.get(area_id, -1)
	if i < 0:
		return
	_progress[i] = p
	terrain_mat.set_shader_parameter("progress", _progress)
	var v: Dictionary = _veg.get(area_id, {})
	if v.is_empty():
		return
	var dry := Color(0.74, 0.62, 0.4)
	var tufts: MultiMesh = v["tufts"].multimesh
	var bushes: MultiMesh = v["bushes"].multimesh
	var flowers: MultiMesh = v["flowers"].multimesh
	for k in tufts.instance_count:
		var lush := Color(0.36, 0.66, 0.27).lerp(Color(0.55, 0.78, 0.3), Painter.hash01(k * 3 + i))
		tufts.set_instance_color(k, dry.lerp(lush, p))
	for k in bushes.instance_count:
		var lush := Color(0.27, 0.55, 0.28).lerp(Color(0.4, 0.68, 0.3), Painter.hash01(k * 7 + i))
		bushes.set_instance_color(k, Color(0.62, 0.52, 0.36).lerp(lush, p))
	for tp in (v["grove"] as Node3D).get_children():
		(tp as IslandProp).set_growth(p * 2.0)
	var bloom := smoothstep(0.5, 1.0, p)
	var pts: Array[Vector3] = v["pts_flower"]
	for k in flowers.instance_count:
		var s := maxf(0.001, bloom * (0.8 + 0.4 * Painter.hash01(k + i * 13)))
		flowers.set_instance_transform(k, Transform3D(Basis().scaled(Vector3(s, s, s)), pts[k] + Vector3(0, 0.05 * bloom, 0)))
		flowers.set_instance_color(k, FLOWER_COLS[k % FLOWER_COLS.size()])


# ------------------------------------------------------------------ clouds (locked areas)

func _build_clouds() -> void:
	var white := LowPoly.mat(Color(0.97, 0.98, 1.0), 0.12, 1.0)
	for a in world.get("areas", []):
		var r: Array = a["rect"]
		var node := Node3D.new()
		node.name = "Cloud_" + a["id"]
		var cx := (float(r[0]) + float(r[2]) + 1.0) * 0.5
		var cz := (float(r[1]) + float(r[3]) + 1.0) * 0.5
		node.position = Vector3(cx, plateau_y(a["id"]) + 0.75, cz)
		var w := float(r[2]) - float(r[0]) + 1.0
		var d := float(r[3]) - float(r[1]) + 1.0
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(a["id"])
		for k in 9:
			var b := LowPoly.blob(rng.randf_range(0.45, 0.8), 1, 0.08, k, Vector3(1.3, 0.62, 1.0))
			var off := Vector3(rng.randf_range(-w * 0.38, w * 0.38), rng.randf_range(-0.1, 0.25), rng.randf_range(-d * 0.38, d * 0.38))
			var mi := LowPoly.instance(b, white, off, node, true)
			mi.set_meta("base", off)
		add_child(node)
		clouds[a["id"]] = node


## 1 = awake (clear), 0 = locked (cloud-covered).
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
		c.position.y = plateau_y(area_id) + 0.75 + v * 1.6


# ------------------------------------------------------------------ picking

func pick(screen_pos: Vector2) -> Vector3:
	var o := camera.project_ray_origin(screen_pos)
	var n := camera.project_ray_normal(screen_pos)
	var t := 0.0
	while t < 80.0:
		var p := o + n * t
		if p.y <= maxf(height_at(p.x, p.z), 0.0):
			return p
		t += 0.04
	return Vector3(INF, INF, INF)


func _process(delta: float) -> void:
	_t += delta
	for id in clouds:
		var c: Node3D = clouds[id]
		if not c.visible:
			continue
		for k in c.get_child_count():
			var mi: Node3D = c.get_child(k)
			var b: Vector3 = mi.get_meta("base")
			mi.position = b + Vector3(sin(_t * 0.3 + k) * 0.12, sin(_t * 0.5 + k * 1.7) * 0.05, 0)
