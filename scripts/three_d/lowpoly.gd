class_name LowPoly
extends RefCounted
## Procedural low-poly mesh + material helpers shared by the island and the
## puzzle board. Meshes use flat normals (faceted, hand-crafted diorama look)
## and are cached by parameters so repeated props share GPU resources.

static var _mesh_cache: Dictionary = {}
static var _mat_cache: Dictionary = {}


## Matte material, cached by colour/emission. Vertex colours optional.
static func mat(col: Color, emission: float = 0.0, rough: float = 0.85, vertex_colors := false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [col.to_html(), emission, rough, vertex_colors]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic_specular = 0.25
	if vertex_colors:
		m.vertex_color_use_as_albedo = true
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m


static func _finish(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


## Jittered icosphere — canopies, rocks, clouds, bushes.
static func blob(radius: float, subdiv: int = 1, jitter: float = 0.12, seed_n: int = 0, squash := Vector3.ONE) -> ArrayMesh:
	var key := "blob|%.3f|%d|%.3f|%d|%s" % [radius, subdiv, jitter, seed_n, str(squash)]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var t := (1.0 + sqrt(5.0)) / 2.0
	var verts: Array[Vector3] = [
		Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2],
		[10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5],
		[2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for i in verts.size():
		verts[i] = verts[i].normalized()
	for s in subdiv:
		var mid := {}
		var nf: Array = []
		for f in faces:
			var m: Array = []
			for e in [[f[0], f[1]], [f[1], f[2]], [f[2], f[0]]]:
				var k := "%d_%d" % [mini(e[0], e[1]), maxi(e[0], e[1])]
				if not mid.has(k):
					verts.append(((verts[e[0]] + verts[e[1]]) * 0.5).normalized())
					mid[k] = verts.size() - 1
				m.append(mid[k])
			nf.append([f[0], m[0], m[2]])
			nf.append([f[1], m[1], m[0]])
			nf.append([f[2], m[2], m[1]])
			nf.append([m[0], m[1], m[2]])
		faces = nf
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n * 7919 + 17
	for i in verts.size():
		verts[i] = verts[i] * radius * (1.0 + rng.randf_range(-jitter, jitter)) * squash
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for f in faces:
		# Godot front faces are clockwise
		st.add_vertex(verts[f[0]])
		st.add_vertex(verts[f[2]])
		st.add_vertex(verts[f[1]])
	var mesh := _finish(st)
	_mesh_cache[key] = mesh
	return mesh


## Faceted frustum/cylinder/cone along +Y from y=0 to y=h.
static func cyl(r0: float, r1: float, h: float, seg: int = 7, jitter: float = 0.0, seed_n: int = 0, caps := true) -> ArrayMesh:
	var key := "cyl|%.3f|%.3f|%.3f|%d|%.3f|%d|%s" % [r0, r1, h, seg, jitter, seed_n, caps]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n * 31 + 5
	var bot: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in seg:
		var a := TAU * i / seg
		var j := 1.0 + rng.randf_range(-jitter, jitter)
		bot.append(Vector3(cos(a) * r0 * j, 0, sin(a) * r0 * j))
		top.append(Vector3(cos(a) * r1 * j, h, sin(a) * r1 * j))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in seg:
		var n := (i + 1) % seg
		st.add_vertex(bot[i]); st.add_vertex(top[n]); st.add_vertex(top[i])
		st.add_vertex(bot[i]); st.add_vertex(bot[n]); st.add_vertex(top[n])
		if caps:
			if r1 > 0.0001:
				st.add_vertex(Vector3(0, h, 0)); st.add_vertex(top[i]); st.add_vertex(top[n])
			st.add_vertex(Vector3.ZERO); st.add_vertex(bot[n]); st.add_vertex(bot[i])
	var mesh := _finish(st)
	_mesh_cache[key] = mesh
	return mesh


## Rounded-ish box (chamfered edges) centred on X/Z, from y=0 to y=size.y.
static func slab(size: Vector3, chamfer: float = 0.06) -> ArrayMesh:
	var key := "slab|%s|%.3f" % [str(size), chamfer]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var c := minf(chamfer, minf(hx, hz) * 0.5)
	var h := size.y
	# octagonal outline gives chamfered vertical edges + a bevelled top ring
	var ring := func(inset: float, y: float) -> Array[Vector3]:
		var out: Array[Vector3] = []
		var ax := hx - inset
		var az := hz - inset
		var cc := c
		out.append(Vector3(-ax + cc, y, -az)); out.append(Vector3(ax - cc, y, -az))
		out.append(Vector3(ax, y, -az + cc)); out.append(Vector3(ax, y, az - cc))
		out.append(Vector3(ax - cc, y, az)); out.append(Vector3(-ax + cc, y, az))
		out.append(Vector3(-ax, y, az - cc)); out.append(Vector3(-ax, y, -az + cc))
		return out
	var b: Array[Vector3] = ring.call(0.0, 0.0)
	var m: Array[Vector3] = ring.call(0.0, h - c)
	var t: Array[Vector3] = ring.call(c, h)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in 8:
		var n := (i + 1) % 8
		st.add_vertex(b[i]); st.add_vertex(m[n]); st.add_vertex(m[i])
		st.add_vertex(b[i]); st.add_vertex(b[n]); st.add_vertex(m[n])
		st.add_vertex(m[i]); st.add_vertex(t[n]); st.add_vertex(t[i])
		st.add_vertex(m[i]); st.add_vertex(m[n]); st.add_vertex(t[n])
	for i in range(1, 7):
		st.add_vertex(t[0]); st.add_vertex(t[i]); st.add_vertex(t[i + 1])
	for i in range(1, 7):
		st.add_vertex(b[0]); st.add_vertex(b[i + 1]); st.add_vertex(b[i])
	var mesh := _finish(st)
	_mesh_cache[key] = mesh
	return mesh


## Simple gable roof prism: width along X, depth along Z, ridge along Z.
static func roof(w: float, d: float, h: float) -> ArrayMesh:
	var key := "roof|%.3f|%.3f|%.3f" % [w, d, h]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var a := Vector3(-w / 2, 0, -d / 2); var b := Vector3(w / 2, 0, -d / 2)
	var c := Vector3(w / 2, 0, d / 2); var e := Vector3(-w / 2, 0, d / 2)
	var r0 := Vector3(0, h, -d / 2); var r1 := Vector3(0, h, d / 2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var centre := Vector3(0, h * 0.3, 0)
	for tri in [[a, r0, r1], [a, r1, e], [b, c, r1], [b, r1, r0], [a, b, r0], [e, r1, c]]:
		_add_outward(st, tri[0], tri[1], tri[2], centre)
	var mesh := _finish(st)
	_mesh_cache[key] = mesh
	return mesh


## Godot treats clockwise triangles as front faces: the winding must make
## cross(p1 - p0, p2 - p0) point away from the outside.
static func _add_outward(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, centre: Vector3) -> void:
	var n := (p1 - p0).cross(p2 - p0)
	if n.dot((p0 + p1 + p2) / 3.0 - centre) > 0.0:
		st.add_vertex(p0); st.add_vertex(p2); st.add_vertex(p1)
	else:
		st.add_vertex(p0); st.add_vertex(p1); st.add_vertex(p2)


static func instance(mesh: Mesh, material: Material, pos := Vector3.ZERO, parent: Node3D = null, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if parent:
		parent.add_child(mi)
	return mi
