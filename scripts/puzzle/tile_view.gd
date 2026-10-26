class_name TileView
extends Node3D
## One puzzle tile as a small 3D diorama piece. Purely visual: reads logical
## state from its PuzzleTile/PuzzleBoard and animates toward it.
##
## Visual language (never colour-only):
##  * every cell sits on a checkered lawn, so empty cells read as background
##  * rotatable tiles are round cream stone discs with four notches; the whole
##    disc turns
##  * pinned / fixed tiles are square grey slabs with bronze corner rivets
##  * channels are dark slate grooves that fill with bright flowing water;
##    spills show droplets
##  * targets are dry saplings that grow when water reaches them

const LAWN := 0.08         ## lawn top height (empty cells, plants, rocks)
const TOP := 0.26          ## top surface of discs and slabs (tap plane)
const DISC_R := 0.465      ## disc radius: neighbouring discs almost touch
const GROOVE_W := 0.24     ## carved channel width
const WATER_W := 0.17      ## water ribbon width inside the groove

const DISC_SIDE := Color("cfb78b")
const DISC_FACE := Color("efe3c6")
const DISC_NOTCH := Color("bba578")
const SLAB_SIDE := Color("a9a397")
const SLAB_FACE := Color("cfc9bc")
const RIVET := Color("b07f45")
const GROOVE_FLOOR := Color("4c5d6a")
const GROOVE_LIP_DISC := Color("e2d3b2")
const GROOVE_LIP_SLAB := Color("b7b0a2")
const LAWN_A := Color("74b553")
const LAWN_B := Color("6aab4b")

var tile: PuzzleTile
var board: PuzzleBoard
var cell := Vector2i.ZERO

var rot_offset := 0.0:     ## radians, animates to 0 after a rotation
	set(v):
		rot_offset = v
		if _disc:
			_disc.rotation.y = v
var press := 1.0:
	set(v):
		press = v
		if _disc:
			_disc.scale = Vector3(v, 1.0, v)
var water := 0.0:
	set(v):
		water = v
		_update_water()
var wet := false
var entry_mask := 0
var leak_mask := 0:
	set(v):
		leak_mask = v
		_update_water()
var bloom := 0.0:
	set(v):
		bloom = v
		_update_bloom()
var highlight := false
var celebrate := 0.0

var _disc: Node3D            ## moving part: turns on rotation, squashes on press
var _arms: Dictionary = {}   ## dir -> {"node": Node3D, "mesh": MeshInstance3D}
var _hub_water: Node3D
var _drops: Node3D
var _ring: MeshInstance3D
var _sapling: Dictionary = {}
var _flowers: Node3D
var _gate_plank: Node3D
var _lever: Node3D
var _t := 0.0
var _seed := 0


func setup(p_tile: PuzzleTile, p_board: PuzzleBoard, p_cell: Vector2i) -> void:
	tile = p_tile
	board = p_board
	cell = p_cell
	_seed = p_cell.x * 31 + p_cell.y * 17
	set_meta("mask", tile.shape_mask())
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_disc = null
	_hub_water = null
	_sapling.clear()
	_flowers = null
	_gate_plank = null
	_lever = null
	_arms.clear()
	_build()


# ------------------------------------------------------------------ materials

func _water() -> StandardMaterial3D:
	# bright, slightly luminous turquoise that reads well on slate
	return LowPoly.mat(Color(0.3, 0.84, 0.94), 0.35, 0.2)


func _m(c: Color, em := 0.0) -> StandardMaterial3D:
	return LowPoly.mat(c, em)


func _box(sz: Vector3, c: Color, pos: Vector3, parent: Node3D, chamfer := 0.02) -> MeshInstance3D:
	return LowPoly.instance(LowPoly.slab(sz, chamfer), _m(c), pos, parent)


# ------------------------------------------------------------------ building

func _build() -> void:
	_build_lawn()
	_disc = Node3D.new()
	add_child(_disc)
	match tile.type:
		TileTypes.EMPTY:
			_build_tufts()
		TileTypes.ROCK:
			LowPoly.instance(LowPoly.blob(0.27, 1, 0.22, _seed, Vector3(1.1, 0.75, 1.0)), _m(Color(0.64, 0.66, 0.7)), Vector3(0, LAWN + 0.1, 0), _disc)
			LowPoly.instance(LowPoly.blob(0.12, 1, 0.2, _seed + 1, Vector3(1.2, 0.5, 1)), _m(Color(0.5, 0.7, 0.36)), Vector3(-0.08, LAWN + 0.25, 0.04), _disc)
		TileTypes.TARGET:
			_build_target()
		TileTypes.BONUS:
			_build_bonus()
		TileTypes.SWITCH:
			_build_switch()
		TileTypes.SOURCE:
			_build_slab()
			_build_channels(GROOVE_LIP_SLAB, 0.5)
			_build_source()
		_:
			if tile.is_rotatable():
				_build_disc()
				_build_channels(GROOVE_LIP_DISC, DISC_R)
			else:
				_build_slab()
				_build_channels(GROOVE_LIP_SLAB, 0.5)
			if tile.is_gate():
				_build_gate()
	_drops = Node3D.new()
	add_child(_drops)
	_ring = LowPoly.instance(_ring_mesh(), _m(Color(1.0, 0.8, 0.3), 1.6), Vector3(0, LAWN + 0.01, 0), self, false)
	_ring.visible = false
	_update_water()
	_update_bloom()


## Checkered lawn square under every cell; flush with its neighbours.
func _build_lawn() -> void:
	var g := LAWN_A if (cell.x + cell.y) % 2 == 0 else LAWN_B
	_box(Vector3(1.0, LAWN, 1.0), g, Vector3.ZERO, self, 0.0)


func _build_tufts() -> void:
	if Painter.hash01(_seed) > 0.45:
		return
	var g := (LAWN_A if (cell.x + cell.y) % 2 == 0 else LAWN_B).darkened(0.16)
	for i in 3:
		var p := Vector3((Painter.hash01(_seed + i * 7) - 0.5) * 0.6, LAWN, (Painter.hash01(_seed * 3 + i) - 0.5) * 0.6)
		LowPoly.instance(LowPoly.cyl(0.03, 0.0, 0.09, 4), _m(g), p, _disc, false)


## Round stone disc with four notches between the channel directions.
func _build_disc() -> void:
	LowPoly.instance(LowPoly.cyl(DISC_R, DISC_R - 0.015, TOP - LAWN - 0.02, 40), _m(DISC_SIDE), Vector3(0, LAWN, 0), _disc)
	LowPoly.instance(LowPoly.cyl(DISC_R - 0.025, DISC_R - 0.045, 0.02, 32), _m(DISC_FACE), Vector3(0, TOP - 0.02, 0), _disc)
	for i in 4:
		var a := TAU * (i + 0.5) / 4.0
		LowPoly.instance(LowPoly.cyl(0.035, 0.035, 0.006, 10), _m(DISC_NOTCH), Vector3(cos(a) * 0.34, TOP, sin(a) * 0.34), _disc, false)


## Square grey slab with corner rivets for tiles that cannot turn.
func _build_slab() -> void:
	_box(Vector3(0.94, TOP - LAWN - 0.02, 0.94), SLAB_SIDE, Vector3(0, LAWN, 0), _disc, 0.05)
	_box(Vector3(0.88, 0.02, 0.88), SLAB_FACE, Vector3(0, TOP - 0.02, 0), _disc, 0.02)
	for v in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		LowPoly.instance(LowPoly.cyl(0.045, 0.035, 0.03, 8), _m(RIVET), Vector3(v.x * 0.35, TOP, v.y * 0.35), _disc)


func _ring_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 32
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p := func(a: float, r: float, y: float) -> Vector3: return Vector3(cos(a) * r, y, sin(a) * r)
		for q in [[p.call(a0, 0.47, 0), p.call(a1, 0.47, 0), p.call(a1, 0.53, 0)], [p.call(a0, 0.47, 0), p.call(a1, 0.53, 0), p.call(a0, 0.53, 0)]]:
			st.add_vertex(q[0]); st.add_vertex(q[2]); st.add_vertex(q[1])
	st.generate_normals()
	return st.commit()


## Carved grooves along each opening, out to `reach` from the centre. Arms
## live under _disc so they turn with it.
func _build_channels(lip: Color, reach: float) -> void:
	var mask := tile.shape_mask()
	var holder := _disc
	for d in Dir.LIST:
		if not (mask & d):
			continue
		var arm := Node3D.new()
		holder.add_child(arm)
		arm.rotation.y = -Dir.angle(d)       # local -Z points along the arm
		_box(Vector3(GROOVE_W + 0.07, 0.008, reach), lip.darkened(0.12), Vector3(0, TOP, -reach * 0.5), arm, 0.0)
		_box(Vector3(GROOVE_W, 0.014, reach), GROOVE_FLOOR, Vector3(0, TOP, -reach * 0.5), arm, 0.0)
		var w := Node3D.new()
		w.name = "water"
		arm.add_child(w)
		var wm := LowPoly.instance(LowPoly.slab(Vector3(WATER_W, 0.022, reach), 0.0), _water(), Vector3(0, TOP + 0.004, -reach * 0.5), w, false)
		wm.set_meta("top", TOP)
		wm.set_meta("reach", reach)
		_arms[d] = {"node": w, "mesh": wm}
	LowPoly.instance(LowPoly.cyl((GROOVE_W + 0.07) * 0.5, (GROOVE_W + 0.07) * 0.5, 0.008, 16), _m(lip.darkened(0.12)), Vector3(0, TOP, 0), holder)
	LowPoly.instance(LowPoly.cyl(GROOVE_W * 0.5, GROOVE_W * 0.5, 0.014, 16), _m(GROOVE_FLOOR), Vector3(0, TOP, 0), holder)
	_hub_water = LowPoly.instance(LowPoly.cyl(WATER_W * 0.5, WATER_W * 0.5, 0.026, 16), _water(), Vector3(0, TOP, 0), holder, false)


func _build_source() -> void:
	for i in 9:
		var a := TAU * i / 9.0
		LowPoly.instance(LowPoly.blob(0.06, 0, 0.25, i, Vector3(1.1, 0.8, 1)), _m(Color(0.93, 0.93, 0.9)), Vector3(cos(a) * 0.24, TOP + 0.02, sin(a) * 0.24), _disc)
	LowPoly.instance(LowPoly.cyl(0.21, 0.21, 0.04, 18), _water(), Vector3(0, TOP, 0), _disc, false)
	var orb := LowPoly.instance(LowPoly.blob(0.11, 1, 0.0, 1), _m(Color(0.6, 0.93, 1.0), 0.7), Vector3(0, TOP + 0.12, 0), self, false)
	orb.name = "orb"
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 0.95, 1.0)
	l.light_energy = 0.45
	l.omni_range = 0.9
	l.position = Vector3(0, TOP + 0.3, 0)
	add_child(l)


func _build_target() -> void:
	LowPoly.instance(LowPoly.cyl(0.32, 0.27, 0.05, 14), _m(Color(0.55, 0.4, 0.27)), Vector3(0, LAWN - 0.01, 0), _disc)
	var puddle := LowPoly.instance(LowPoly.cyl(0.28, 0.28, 0.05, 14), _water(), Vector3(0, LAWN, 0), _disc, false)
	_sapling["puddle"] = puddle
	var root := Node3D.new()
	root.position = Vector3(0, LAWN + 0.04, 0)
	_disc.add_child(root)
	_sapling["root"] = root
	var trunk := LowPoly.instance(LowPoly.cyl(0.05, 0.025, 0.42, 6, 0.1, _seed), _m(Color(0.5, 0.36, 0.24)), Vector3.ZERO, root)
	_sapling["trunk"] = trunk
	var bare := Node3D.new()
	root.add_child(bare)
	for i in 3:
		var b := LowPoly.instance(LowPoly.cyl(0.016, 0.006, 0.2, 4), _m(Color(0.55, 0.42, 0.3)), Vector3(0, 0.28, 0), bare)
		b.rotation = Vector3(deg_to_rad(45), TAU * i / 3.0, 0)
	_sapling["bare"] = bare
	var canopy := Node3D.new()
	canopy.position = Vector3(0, 0.46, 0)
	root.add_child(canopy)
	var greens := [Color(0.3, 0.6, 0.3), Color(0.4, 0.7, 0.33), Color(0.5, 0.78, 0.38)]
	for i in 3:
		var p: Vector3 = [Vector3(0, 0.05, 0), Vector3(-0.12, -0.02, 0.06), Vector3(0.11, 0.04, -0.05)][i]
		LowPoly.instance(LowPoly.blob([0.22, 0.16, 0.17][i], 1, 0.14, _seed + i), _m(greens[i]), p, canopy)
	for i in 6:
		var a := TAU * i / 6.0
		LowPoly.instance(LowPoly.blob(0.035, 0, 0.0, 1), _m(Color(1, 0.88, 0.9)), Vector3(cos(a) * 0.17, 0.1 + 0.08 * Painter.hash01(i), sin(a) * 0.17), canopy, false)
	_sapling["canopy"] = canopy


func _build_bonus() -> void:
	LowPoly.instance(LowPoly.cyl(0.34, 0.3, 0.05, 14), _m(Color(0.53, 0.39, 0.27)), Vector3(0, LAWN - 0.01, 0), _disc)
	for i in 10:
		var a := TAU * i / 10.0
		LowPoly.instance(LowPoly.blob(0.025, 0, 0.0, 1), _m(Color(1.0, 0.8, 0.3), 0.6), Vector3(cos(a) * 0.42, LAWN, sin(a) * 0.42), _disc, false).name = "marker"
	_flowers = Node3D.new()
	_disc.add_child(_flowers)
	var cols := [Color(0.98, 0.5, 0.6), Color(1, 1, 1), Color(0.72, 0.58, 0.95), Color(1.0, 0.8, 0.28)]
	for i in 7:
		var a := TAU * i / 7.0 + 0.3
		var r := 0.18 if i % 2 == 0 else 0.1
		var f := Node3D.new()
		f.position = Vector3(cos(a) * r, LAWN + 0.04, sin(a) * r)
		_flowers.add_child(f)
		LowPoly.instance(LowPoly.cyl(0.012, 0.01, 0.16, 3), _m(Color(0.35, 0.6, 0.3)), Vector3.ZERO, f, false)
		LowPoly.instance(LowPoly.blob(0.055, 0, 0.1, i), _m(cols[i % 4]), Vector3(0, 0.17, 0), f, false)


func link_index() -> int:
	if tile.link == "":
		return 0
	return (tile.link.unicode_at(0) - 97) % Palette.LINK_COLORS.size()


func _badge(parent: Node3D, pos: Vector3) -> void:
	var col: Color = Palette.LINK_COLORS[link_index()]
	var mesh: Mesh
	match link_index():
		0: mesh = LowPoly.blob(0.07, 1, 0.0, 1)                 # circle -> ball
		1: mesh = LowPoly.cyl(0.08, 0.0, 0.13, 3)               # triangle -> pyramid
		2: mesh = LowPoly.slab(Vector3(0.12, 0.12, 0.12), 0.01) # square -> cube
		_: mesh = LowPoly.cyl(0.08, 0.0, 0.12, 4)               # diamond
	LowPoly.instance(mesh, _m(col, 0.25), pos, parent)


func _build_gate() -> void:
	var holder := Node3D.new()
	holder.rotation.y = -Dir.angle(Dir.rotate_mask(Dir.N, tile.rotation))
	_disc.add_child(holder)
	for s in [-1.0, 1.0]:
		LowPoly.instance(LowPoly.cyl(0.05, 0.045, 0.42, 6), _m(Color(0.45, 0.31, 0.2)), Vector3(s * 0.24, TOP, 0), holder)
	_badge(holder, Vector3(0.24, TOP + 0.44, 0))
	LowPoly.instance(LowPoly.slab(Vector3(0.56, 0.06, 0.08), 0.01), _m(Color(0.5, 0.35, 0.22)), Vector3(0, TOP + 0.4, 0), holder)
	_gate_plank = Node3D.new()
	holder.add_child(_gate_plank)
	LowPoly.instance(LowPoly.slab(Vector3(0.4, 0.2, 0.06), 0.015), _m(Color(0.66, 0.47, 0.29)), Vector3(0, 0, 0), _gate_plank)
	_gate_plank.position.y = TOP + 0.01


func _build_switch() -> void:
	LowPoly.instance(LowPoly.cyl(0.24, 0.28, 0.1, 12), _m(SLAB_FACE), Vector3(0, LAWN, 0), _disc)
	_lever = Node3D.new()
	_lever.position = Vector3(0, LAWN + 0.12, 0)
	_disc.add_child(_lever)
	LowPoly.instance(LowPoly.cyl(0.03, 0.025, 0.42, 6), _m(Color(0.5, 0.35, 0.22)), Vector3.ZERO, _lever)
	_badge(_lever, Vector3(0, 0.44, 0))
	LowPoly.instance(LowPoly.slab(Vector3(0.14, 0.06, 0.12), 0.01), _m(Color(0.42, 0.42, 0.42)), Vector3(0, LAWN + 0.08, 0), _disc)


# ------------------------------------------------------------------ state

func _arm_fill(d: int) -> float:
	if not wet:
		return 0.0
	if tile.is_source():
		return clampf(water, 0.0, 1.0)
	if entry_mask & d:
		return clampf(water * 2.0, 0.0, 1.0)
	return clampf(water * 2.0 - 1.0, 0.0, 1.0)


func _update_water() -> void:
	if tile == null:
		return
	for d in _arms:
		var arm: Dictionary = _arms[d]
		var f := _arm_fill(d)
		var node: Node3D = arm["node"]
		var mesh: MeshInstance3D = arm["mesh"]
		node.visible = f > 0.01
		var top: float = mesh.get_meta("top")
		var reach: float = mesh.get_meta("reach")
		mesh.scale = Vector3(1, 1, maxf(f, 0.01))
		if (entry_mask & d) and not tile.is_source():
			# fill from the edge inward
			mesh.position = Vector3(0, top + 0.004, -reach + reach * 0.5 * f)
		else:
			mesh.position = Vector3(0, top + 0.004, -reach * 0.5 * f)
	if _hub_water:
		_hub_water.visible = wet and (water >= 0.5 or tile.is_source())
	if _sapling.has("puddle"):
		_sapling["puddle"].visible = wet and water > 0.3
	_update_drops()


func _update_drops() -> void:
	if _drops == null:
		return
	for c in _drops.get_children():
		c.queue_free()
	if not wet or water < 0.99 or leak_mask == 0:
		return
	for d in Dir.LIST:
		if leak_mask & d and tile.shape_mask() & d:
			var off := Vector3(Dir.offset(d).x, 0, Dir.offset(d).y) * 0.47
			for k in 3:
				var drop := LowPoly.instance(LowPoly.blob(0.035, 0, 0.0, k), _m(Color(0.7, 0.95, 1.0), 0.6), off + Vector3(0, TOP + 0.1, 0), _drops, false)
				drop.set_meta("k", k)
				drop.set_meta("base", off)


func _update_bloom() -> void:
	if _sapling.has("canopy"):
		var b := bloom
		var canopy: Node3D = _sapling["canopy"]
		canopy.scale = Vector3.ONE * maxf(0.001, 0.15 + 0.85 * b)
		canopy.visible = b > 0.02
		(_sapling["bare"] as Node3D).visible = b < 0.6
		(_sapling["trunk"] as Node3D).scale = Vector3.ONE * (0.75 + 0.25 * b)
	if _flowers:
		for f in _flowers.get_children():
			f.scale = Vector3.ONE * maxf(0.001, 0.25 + 0.75 * bloom)
			(f.get_child(1) as Node3D).visible = bloom > 0.3


func _process(delta: float) -> void:
	_t += delta
	if tile == null:
		return
	if _gate_plank:
		var open := board.is_gate_open(tile)
		_gate_plank.position.y = move_toward(_gate_plank.position.y, TOP + (0.3 if open else 0.01), delta * 1.6)
	if _lever:
		var on := bool(board.switches.get(tile.link, false))
		_lever.rotation.z = move_toward(_lever.rotation.z, -0.6 if on else 0.6, delta * 6.0)
	if _ring:
		_ring.visible = highlight
		if highlight:
			var s := 1.0 + 0.06 * sin(_t * 6.0)
			_ring.scale = Vector3(s, 1, s)
			_ring.position.y = LAWN + 0.01
	var orb := get_node_or_null("orb")
	if orb:
		orb.position.y = TOP + 0.12 + sin(_t * 2.0) * 0.02
	for drop in _drops.get_children():
		var k: int = drop.get_meta("k")
		var ph := fmod(_t * 1.4 + k * 0.33, 1.0)
		var base: Vector3 = drop.get_meta("base")
		drop.position = base * (1.0 + ph * 0.15) + Vector3(0, TOP + 0.12 - ph * 0.25, 0)
		drop.scale = Vector3.ONE * (1.0 - ph * 0.6)
	if celebrate > 0.0 and _disc:
		_disc.position.y = sin(celebrate * PI) * 0.08
