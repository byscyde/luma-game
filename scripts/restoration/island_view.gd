class_name IslandView
extends Control
## Hosts the 3D IslandWorld in a SubViewport and keeps it in sync with
## display values (floats that tween toward saved progress). Handles area
## picking (tap), orbiting (horizontal drag) and restoration camera moves.
## Never changes progression itself.

signal area_selected(area_id: String)

var world: Dictionary
var interactive := true
var selected_area := ""
var display_stage: Dictionary = {}          ## object id -> float (0..stages)
var display_area_unlocked: Dictionary = {}  ## area id -> float (0 locked .. 1 awake)
var focus_object := ""
var idle_orbit := true
## Screen space covered by UI (px): the island is framed in what remains.
var top_inset := 0.0
var bottom_inset := 0.0

var island: IslandWorld
var _svc: SubViewportContainer
var _vp: SubViewport
var _labels: Control
var _dirty := true
var _home_target := Vector3.ZERO
var _home_dist := 14.0
var _yaw_offset := 0.0
var _press_pos := Vector2.ZERO
var _pressed := false
var _dragging := false
var _t := 0.0
var _cam_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	_svc = SubViewportContainer.new()
	_svc.stretch = true
	_svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_svc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_svc.add_child(_vp)
	_labels = Control.new()
	_labels.set_anchors_preset(Control.PRESET_FULL_RECT)
	_labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_labels)
	resized.connect(_layout)
	if world.is_empty() and not Game.content.worlds.is_empty():
		setup(Game.content.worlds[0])


func setup(p_world: Dictionary) -> void:
	world = p_world
	if island:
		island.queue_free()
	island = IslandWorld.new()
	_vp.add_child(island)
	island.build(world)
	sync_from_progress()
	_layout()


## Snap every display value to the saved state (no animation).
func sync_from_progress() -> void:
	for o in world.get("objects", []):
		display_stage[o["id"]] = float(Game.progression.object_stage(o["id"]))
	for a in world.get("areas", []):
		display_area_unlocked[a["id"]] = 1.0 if Game.progression.is_area_unlocked(a["id"]) else 0.0
	_dirty = true


func _layout() -> void:
	if island == null or size.x < 2 or size.y < 2:
		return
	var visible_h := maxf(size.y - top_inset - bottom_inset, size.y * 0.35)
	_home_dist = island.fit_distance(size.x / size.y, visible_h / size.y)
	_home_target = Vector3(island.cols * 0.5, 0.6, island.rows * 0.5 + 0.4)
	# shift the image so the island centres in the uncovered region
	var px_per_unit := size.y / (2.0 * _home_dist * tan(deg_to_rad(island.camera.fov) * 0.5))
	island.camera.v_offset = -((bottom_inset - top_inset) * 0.5) / px_per_unit
	island.cam_target = _home_target
	island.cam_dist = _home_dist
	island._apply_camera()


# ------------------------------------------------------------------ sync

func area_display_progress(area_id: String) -> float:
	var total := 0.0
	var have := 0.0
	for o in world.get("objects", []):
		if o["area"] == area_id:
			total += float(o.get("stages", 1))
			have += minf(float(display_stage.get(o["id"], 0.0)), float(o.get("stages", 1)))
	return 0.0 if total == 0.0 else have / total


func _push() -> void:
	for o in world.get("objects", []):
		var p: IslandProp = island.props.get(o["id"])
		if p:
			var stages := float(o.get("stages", 1))
			p.set_growth(float(display_stage.get(o["id"], 0.0)) * 2.0 / stages)
	for a in world.get("areas", []):
		island.set_area_progress(a["id"], area_display_progress(a["id"]))
		island.set_area_awake(a["id"], float(display_area_unlocked.get(a["id"], 0.0)))
	for d in world.get("decorations", []):
		var dp: IslandProp = island.decos.get(d["id"])
		if dp:
			var area_awake := float(display_area_unlocked.get(island.area_at(d["pos"][0], d["pos"][1]), 1.0)) > 0.5
			dp.visible = Game.progression.is_decoration_visible(d["id"]) and area_awake


func _process(delta: float) -> void:
	if island == null:
		return
	if not Game.reduced_motion():
		_t += delta
	if _dirty:
		_dirty = false
		_push()
	if idle_orbit and not _dragging and (_cam_tween == null or not _cam_tween.is_running()):
		island.cam_yaw = deg_to_rad(-12.0) + _yaw_offset + sin(_t * 0.15) * deg_to_rad(2.5)
		island._apply_camera()
	_update_labels()


# ------------------------------------------------------------------ animation API

func animate_object(object_id: String, to_stage: float, duration: float = 1.6) -> void:
	focus_object = object_id
	var p: IslandProp = island.props.get(object_id)
	var reduced := Game.reduced_motion()
	if p and not reduced:
		await _move_camera(p.position + Vector3(0, 0.3, 0), _home_dist * 0.78, 0.6)
	var from := float(display_stage.get(object_id, 0.0))
	var tw := create_tween()
	tw.tween_method(func(v):
		display_stage[object_id] = v
		_dirty = true, from, to_stage, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if p and not reduced:
		burst(p.position + Vector3(0, 0.4, 0))
	await tw.finished
	focus_object = ""


func return_home(duration: float = 0.7) -> void:
	if Game.reduced_motion():
		duration = 0.01
	await _move_camera(_home_target, _home_dist, duration)


func animate_area_unlock(area_id: String, duration: float = 1.4) -> void:
	var reduced := Game.reduced_motion()
	if not reduced:
		await _move_camera(area_world_center(area_id), _home_dist * 0.7, 0.5)
	var tw := create_tween()
	tw.tween_method(func(v):
		display_area_unlocked[area_id] = v
		_dirty = true, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not reduced:
		burst(area_world_center(area_id) + Vector3(0, 0.6, 0), Color(1.0, 0.85, 0.4))
	await tw.finished
	await return_home(0.8)


func _move_camera(target: Vector3, dist: float, dur: float) -> void:
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_method(func(v):
		island.cam_target = v
		island._apply_camera(), island.cam_target, target, dur)
	_cam_tween.tween_method(func(v):
		island.cam_dist = v
		island._apply_camera(), island.cam_dist, dist, dur)
	await _cam_tween.finished


func burst(at: Vector3, col := Color(0.7, 0.95, 0.45)) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 40
	p.lifetime = 1.3
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.gravity = Vector3(0, -1.6, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, col)
	grad.set_color(1, Color(1.0, 0.9, 0.5, 0.0))
	p.color_ramp = grad
	p.position = at
	island.add_child(p)
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


# ------------------------------------------------------------------ geometry helpers

func area_world_center(area_id: String) -> Vector3:
	return island.area_center3d(area_id) if island else _home_target


func _to_local(p3: Vector3) -> Vector2:
	if island == null or island.camera == null or _vp.size.x == 0:
		return size * 0.5
	var p := island.camera.unproject_position(p3)
	return p * (size / Vector2(_vp.size))


func area_center(area_id: String) -> Vector2:
	return _to_local(area_world_center(area_id))


func object_screen_pos(object_id: String) -> Vector2:
	var p: IslandProp = island.props.get(object_id)
	return _to_local(p.position) if p else size * 0.5


func pick_area(pos: Vector2) -> String:
	if island == null or size.x < 1:
		return ""
	var hit := island.pick(pos * (Vector2(_vp.size) / size))
	if hit.x == INF:
		return ""
	return island.area_at(hit.x, hit.z)


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var press := false
	var release := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
		pos = event.position
	elif event is InputEventScreenTouch:
		press = event.pressed
		release = not event.pressed
		pos = event.position
	elif (event is InputEventMouseMotion or event is InputEventScreenDrag) and _pressed:
		if absf(event.position.x - _press_pos.x) > 14.0:
			_dragging = true
		if _dragging:
			_yaw_offset = clampf(_yaw_offset - event.relative.x * 0.006, -0.9, 0.9)
			island.cam_yaw = deg_to_rad(-12.0) + _yaw_offset
			island._apply_camera()
			accept_event()
		return
	if press:
		_pressed = true
		_dragging = false
		_press_pos = pos
		accept_event()
	elif release and _pressed:
		_pressed = false
		if not _dragging:
			var a := pick_area(pos)
			if a != "":
				selected_area = a
				area_selected.emit(a)
		_dragging = false
		accept_event()


# ------------------------------------------------------------------ overlay labels

func _update_labels() -> void:
	if _labels.get_child_count() == 0:
		for a in world.get("areas", []):
			var tag := AreaTag.new()
			tag.area_id = a["id"]
			tag.text = tr(a["name"])
			_labels.add_child(tag)
	for tag in _labels.get_children():
		var t := tag as AreaTag
		var locked := float(display_area_unlocked.get(t.area_id, 0.0)) < 0.5
		t.locked = locked
		t.selected = t.area_id == selected_area and interactive
		t.visible = interactive and (locked or t.selected)
		t.position = (_to_local(area_world_center(t.area_id) + Vector3(0, 1.0 if locked else 0.55, 0)) - t.size * 0.5).round()


## Small floating pill with the area name (and a lock while asleep).
class AreaTag extends Control:
	var area_id := ""
	var text := ""
	var locked := false
	var selected := false
	var _sb := StyleBoxFlat.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = Vector2(240, 52)
		_sb.set_corner_radius_all(19)
		_sb.shadow_color = Color(0, 0, 0, 0.18)
		_sb.shadow_size = 6
		_sb.shadow_offset = Vector2(0, 3)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var font := ThemeBuilder.font_bold()
		var fs := 22
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w := tw + (64.0 if locked else 36.0)
		var r := Rect2((size.x - w) * 0.5, 8, w, 38)
		_sb.bg_color = Color(1, 1, 1, 0.94) if not locked else Color(0.16, 0.26, 0.3, 0.72)
		draw_style_box(_sb, r)
		var x := r.position.x + 18
		if locked:
			Painter.icon(self, "lock", Rect2(x - 2, r.position.y + 9, 20, 20), Color(1, 1, 1, 0.95))
			x += 26
		draw_string(font, Vector2(x, r.position.y + 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1) if locked else Color("2f4a3a"))
