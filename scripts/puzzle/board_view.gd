class_name BoardView
extends Control
## Renders a PuzzleBoard as a 3D diorama (orthographic camera, so channel
## connections are never distorted), turns touches into tile taps and
## animates water. Holds no rules: it emits `tile_tapped` and is told what the
## water did.

signal tile_tapped(cell: Vector2i)

const FILL_STEP := 0.075       ## seconds between consecutive BFS rings filling
const FILL_TIME := 0.16        ## seconds for one tile to fill
const PITCH := 56.0            ## camera tilt in degrees from horizontal

var board: PuzzleBoard
var input_enabled := true
var views: Dictionary = {}     ## Vector2i -> TileView
var cell_size := 100.0         ## approx on-screen width of a cell (for overlays)
var _wet_since: Dictionary = {}
var _pointer: Node2D
var _pointer_cell := Vector2i(-1, -1)
var _svc: SubViewportContainer
var _vp: SubViewport
var _root: Node3D
var _tiles_root: Node3D
var _camera: Camera3D
var _plinth: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_svc.add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	_build_environment()
	_tiles_root = Node3D.new()
	_root.add_child(_tiles_root)
	_pointer = PointerHand.new()
	_pointer.visible = false
	_pointer.z_index = 10
	add_child(_pointer)
	resized.connect(_layout)


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.light_energy = 0.66
	sun.rotation_degrees = Vector3(-58, -32, 0)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_max_distance = 25.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_root.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.85, 0.95)
	env.ambient_light_energy = 0.26
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.near = 0.1
	_camera.far = 100.0
	_root.add_child(_camera)


func setup(p_board: PuzzleBoard) -> void:
	board = p_board
	for v in views.values():
		v.queue_free()
	views.clear()
	_wet_since.clear()
	for y in board.height:
		for x in board.width:
			var p := Vector2i(x, y)
			var v := TileView.new()
			_tiles_root.add_child(v)
			v.position = cell_world(p)
			v.setup(board.get_tile(p), board, p)
			views[p] = v
	_build_plinth()
	_layout()


func _build_plinth() -> void:
	if _plinth:
		_plinth.queue_free()
	_plinth = Node3D.new()
	_root.add_child(_plinth)
	var w := float(board.width)
	var h := float(board.height)
	# earthy block with a grass rim the tiles sit on
	LowPoly.instance(LowPoly.slab(Vector3(w + 0.5, 0.9, h + 0.5), 0.18), LowPoly.mat(Color(0.62, 0.48, 0.36)), Vector3(0, -0.9, 0), _plinth)
	LowPoly.instance(LowPoly.slab(Vector3(w + 0.42, 0.06, h + 0.42), 0.12), LowPoly.mat(Color(0.38, 0.58, 0.3)), Vector3(0, -0.04, 0), _plinth)
	# a few rocks and tufts around the rim for a hand-made diorama feel
	var rng := RandomNumberGenerator.new()
	rng.seed = int(w * 13 + h * 7)
	for i in 10:
		var side := i % 4
		var t := rng.randf_range(-0.45, 0.45)
		var p := Vector3()
		match side:
			0: p = Vector3(t * w, 0, -h * 0.5 - 0.2)
			1: p = Vector3(w * 0.5 + 0.2, 0, t * h)
			2: p = Vector3(t * w, 0, h * 0.5 + 0.2)
			_: p = Vector3(-w * 0.5 - 0.2, 0, t * h)
		if i % 3 == 0:
			LowPoly.instance(LowPoly.blob(0.12, 0, 0.25, i, Vector3(1.2, 0.7, 1)), LowPoly.mat(Color(0.66, 0.66, 0.68)), p, _plinth)
		else:
			LowPoly.instance(LowPoly.cyl(0.05, 0.0, 0.16, 4), LowPoly.mat(Color(0.38, 0.6, 0.3)), p, _plinth, false)


func cell_world(p: Vector2i) -> Vector3:
	return Vector3(p.x - (board.width - 1) * 0.5, 0.0, p.y - (board.height - 1) * 0.5)


func _layout() -> void:
	if board == null or size.x < 2 or size.y < 2:
		return
	var w := float(board.width) + 0.9
	var h := float(board.height) + 0.9
	var pitch := deg_to_rad(PITCH)
	# vertical screen extent of the board in world units (ortho, tilted)
	var vert := h * sin(pitch) + 1.0 * cos(pitch)
	var aspect := size.x / size.y
	_camera.size = maxf(vert, w / aspect) * 1.04
	var target := Vector3(0, 0.1, 0.05)
	var dir := Vector3(0, sin(pitch), cos(pitch))
	_camera.position = target + dir * 20.0
	_camera.look_at(target, Vector3.UP)
	cell_size = size.y / _camera.size
	if _pointer_cell != Vector2i(-1, -1):
		show_pointer(_pointer_cell)


func cell_center(p: Vector2i) -> Vector2:
	if _vp == null or _vp.size.x == 0:
		return size * 0.5
	var sp := _camera.unproject_position(cell_world(p) + Vector3(0, TileView.TOP, 0))
	return sp * (size / Vector2(_vp.size))


func cell_at(local: Vector2) -> Vector2i:
	if board == null or _vp.size.x == 0:
		return Vector2i(-1, -1)
	var vp_pos := local * (Vector2(_vp.size) / size)
	var o := _camera.project_ray_origin(vp_pos)
	var n := _camera.project_ray_normal(vp_pos)
	if absf(n.y) < 0.0001:
		return Vector2i(-1, -1)
	var t := (TileView.TOP - o.y) / n.y
	var hit := o + n * t
	var c := Vector2i(floori(hit.x + board.width * 0.5), floori(hit.z + board.height * 0.5))
	return c if board.in_bounds(c) else Vector2i(-1, -1)


func _gui_input(event: InputEvent) -> void:
	if not input_enabled or board == null:
		return
	# On touch screens Godot also emits an emulated mouse click for every touch
	# (emulate_mouse_from_touch); handling both rotated each tile twice per tap.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	if pressed:
		var c := cell_at(pos)
		if c != Vector2i(-1, -1):
			accept_event()
			tile_tapped.emit(c)


# ------------------------------------------------------------------ animation hooks

func _refresh_shape(v: TileView) -> void:
	# Rebuild a tile whose logical shape changed (rotation, undo, reset).
	var keep := {"wet": v.wet, "water": v.water, "entry": v.entry_mask, "leak": v.leak_mask, "bloom": v.bloom}
	v.setup(v.tile, board, v.cell)
	v.wet = keep["wet"]
	v.entry_mask = keep["entry"]
	v.water = keep["water"]
	v.leak_mask = keep["leak"]
	v.bloom = keep["bloom"]


## Called after the tile's logical rotation changed; animates the turn.
func animate_rotation(p: Vector2i) -> void:
	var v: TileView = views.get(p)
	if v == null:
		return
	_refresh_shape(v)
	var reduced := Game.reduced_motion()
	v.rot_offset = PI * 0.5
	var tw := v.create_tween().set_parallel(true)
	tw.tween_property(v, "rot_offset", 0.0, 0.06 if reduced else 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	v.press = 0.94
	tw.tween_property(v, "press", 1.0, 0.18).set_trans(Tween.TRANS_SINE)


func animate_press(p: Vector2i) -> void:
	var v: TileView = views.get(p)
	if v == null:
		return
	v.press = 0.94
	v.create_tween().tween_property(v, "press", 1.0, 0.14)


## Applies a simulation result. Newly wet tiles fill ring by ring from the
## source; tiles that lost water drain immediately. Returns the time in seconds
## until the last tile finishes filling.
func apply_water(sim: WaterResult, animate: bool = true) -> float:
	var entry: Dictionary = {}
	for e in sim.edges:
		var a: Vector2i = e[0]
		var b: Vector2i = e[1]
		entry[b] = int(entry.get(b, 0)) | _dir_between(b, a)
	var leaks: Dictionary = {}
	for l in sim.leaks:
		leaks[l["pos"]] = int(leaks.get(l["pos"], 0)) | int(l["dir"])
	var reduced := Game.reduced_motion() or not animate
	var longest := 0.0
	var base_dist := 999
	for p in sim.order:
		if not _wet_since.has(p):
			base_dist = mini(base_dist, int(sim.distance[p]))
	for p in views:
		var v: TileView = views[p]
		if v.tile.shape_mask() != _built_mask(v):
			_refresh_shape(v)
		var now_wet := sim.is_wet(p)
		v.entry_mask = int(entry.get(p, 0))
		v.leak_mask = int(leaks.get(p, 0))
		if now_wet and not v.wet:
			v.wet = true
			_wet_since[p] = true
			var delay := 0.0 if reduced else maxf(0.0, (int(sim.distance[p]) - base_dist) * FILL_STEP)
			v.water = 0.0
			var tw := v.create_tween()
			tw.tween_interval(delay)
			tw.tween_property(v, "water", 1.0, 0.01 if reduced else FILL_TIME)
			if v.tile.is_sink():
				tw.tween_property(v, "bloom", 1.0, 0.05 if reduced else 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			longest = maxf(longest, delay + FILL_TIME + (0.6 if v.tile.is_sink() else 0.0))
		elif not now_wet and v.wet:
			v.wet = false
			_wet_since.erase(p)
			v.water = 0.0
			if v.tile.is_sink():
				v.create_tween().tween_property(v, "bloom", 0.0, 0.2)
		elif now_wet:
			v.water = v.water  # refresh entry/leak visuals
	return longest


func _built_mask(v: TileView) -> int:
	return int(v.get_meta("mask", -1))


func _dir_between(from: Vector2i, to: Vector2i) -> int:
	var d := to - from
	for dir in Dir.LIST:
		if Dir.offset(dir) == d:
			return dir
	return 0


## A ripple of hops across all wet tiles when the puzzle is solved.
func celebrate(sim: WaterResult) -> void:
	if Game.reduced_motion():
		return
	for p in sim.order:
		var v: TileView = views[p]
		var tw := v.create_tween()
		tw.tween_interval(int(sim.distance[p]) * 0.05)
		tw.tween_property(v, "celebrate", 1.0, 0.35)
		tw.tween_property(v, "celebrate", 0.0, 0.01)


func set_highlight(p: Vector2i) -> void:
	for c in views:
		views[c].highlight = c == p


func show_pointer(p: Vector2i) -> void:
	_pointer_cell = p
	if p == Vector2i(-1, -1):
		_pointer.visible = false
		return
	_pointer.visible = true
	(_pointer as PointerHand).unit = cell_size
	_pointer.position = cell_center(p) + Vector2(cell_size * 0.16, cell_size * 0.12)


func hide_pointer() -> void:
	show_pointer(Vector2i(-1, -1))


## Tutorial pointer: a soft hand that taps.
class PointerHand extends Node2D:
	var unit := 100.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var tap := absf(sin(_t * 3.0))
		var off := Vector2(0, -unit * 0.08 * tap)
		var s := unit * 0.3
		var ph := fmod(_t * 1.5, 1.0)
		draw_arc(Vector2(-s * 0.55, -s * 0.9), unit * 0.12 + ph * unit * 0.25, 0, TAU, 24, Color(1, 1, 1, 0.8 * (1.0 - ph)), 4.0, true)
		var col := Color("fffaf0")
		var outline := Color(0.18, 0.24, 0.24, 0.85)
		var finger_a := off + Vector2(-s * 0.55, -s * 0.9)
		var finger_b := off + Vector2(-s * 0.1, s * 0.1)
		draw_line(finger_a, finger_b, outline, s * 0.44, true)
		draw_line(finger_a, finger_b, col, s * 0.32, true)
		draw_circle(off + Vector2(s * 0.15, s * 0.45), s * 0.48, outline, true, -1, true)
		draw_circle(off + Vector2(s * 0.15, s * 0.45), s * 0.42, col, true, -1, true)
		draw_circle(finger_a, s * 0.22, outline, true, -1, true)
		draw_circle(finger_a, s * 0.16, col, true, -1, true)
