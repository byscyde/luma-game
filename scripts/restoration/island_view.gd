class_name IslandView
extends Control
## Isometric diorama of a world. Reads restoration stages from progression and
## animates them (display stages are floats that tween toward saved stages).
## Purely visual + area picking; it never changes progression itself.

signal area_selected(area_id: String)

var world: Dictionary
var interactive := true
var selected_area := ""
var display_stage: Dictionary = {}     ## object id -> float
var display_area_unlocked: Dictionary = {}  ## area id -> float (mist fade)
var focus_object := ""
var zoom := 1.0
var fit_margin := Vector2(12, 12)

var _tw := 64.0                        ## tile width in px
var _th := 32.0
var _hstep := 26.0
var _origin := Vector2.ZERO
var _cells: Array = []                 ## {gx, gy, area, h}
var _cell_map: Dictionary = {}         ## Vector2i -> cell dict
var _t := 0.0
var _sparks: Array = []
var _sb := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	if world.is_empty() and not Game.content.worlds.is_empty():
		setup(Game.content.worlds[0])


func setup(p_world: Dictionary) -> void:
	world = p_world
	_cells.clear()
	_cell_map.clear()
	for a in world.get("areas", []):
		var r: Array = a["rect"]
		for gy in range(int(r[1]), int(r[3]) + 1):
			for gx in range(int(r[0]), int(r[2]) + 1):
				var c := {"gx": gx, "gy": gy, "area": a["id"], "h": int(a.get("height", 0))}
				_cells.append(c)
				_cell_map[Vector2i(gx, gy)] = c
	_cells.sort_custom(func(a, b): return a.gx + a.gy < b.gx + b.gy or (a.gx + a.gy == b.gx + b.gy and a.gx < b.gx))
	sync_from_progress()
	_layout()


## Snap every display value to the saved state (no animation).
func sync_from_progress() -> void:
	for o in world.get("objects", []):
		display_stage[o["id"]] = float(Game.progression.object_stage(o["id"]))
	for a in world.get("areas", []):
		display_area_unlocked[a["id"]] = 1.0 if Game.progression.is_area_unlocked(a["id"]) else 0.0


func _layout() -> void:
	if world.is_empty():
		return
	var isl: Dictionary = world.get("island", {})
	var cols := int(isl.get("cols", 8))
	var rows := int(isl.get("rows", 10))
	var span := float(cols + rows)
	var avail := size - fit_margin * 2.0
	# width: span * tw/2 ; height: span * th/2 + heights + cliff
	var tw_w := avail.x / (span * 0.5)
	var tw_h := avail.y / (span * 0.25 + 1.6)
	_tw = maxf(0.0, minf(tw_w, tw_h) * zoom)
	_th = _tw * 0.5
	_hstep = _tw * 0.42
	var island_w := span * _tw * 0.5
	var island_h := span * _th * 0.5
	_origin = Vector2(
		fit_margin.x + (avail.x - island_w) * 0.5 + rows * _tw * 0.5,
		fit_margin.y + (avail.y - island_h) * 0.5 + _hstep * 1.6)
	queue_redraw()


func iso(gx: float, gy: float, h: float) -> Vector2:
	return _origin + Vector2((gx - gy) * _tw * 0.5, (gx + gy) * _th * 0.5 - h * _hstep)


func height_at(gx: float, gy: float) -> int:
	var c = _cell_map.get(Vector2i(floori(gx), floori(gy)))
	return -1 if c == null else int(c["h"])


func area_at(gx: float, gy: float) -> String:
	var c = _cell_map.get(Vector2i(floori(gx), floori(gy)))
	return "" if c == null else c["area"]


func area_center(area_id: String) -> Vector2:
	for a in world.get("areas", []):
		if a["id"] == area_id:
			var r: Array = a["rect"]
			return iso((r[0] + r[2] + 1) * 0.5, (r[1] + r[3] + 1) * 0.5, a.get("height", 0))
	return size * 0.5


func object_screen_pos(object_id: String) -> Vector2:
	for o in world.get("objects", []):
		if o["id"] == object_id:
			return iso(o["pos"][0], o["pos"][1], height_at(o["pos"][0], o["pos"][1]))
	return size * 0.5


## Animated area progress (0..1) computed from display stages.
func area_display_progress(area_id: String) -> float:
	var total := 0.0
	var have := 0.0
	for o in world.get("objects", []):
		if o["area"] == area_id:
			total += float(o.get("stages", 1))
			have += minf(float(display_stage.get(o["id"], 0.0)), float(o.get("stages", 1)))
	return 0.0 if total == 0.0 else have / total


# ------------------------------------------------------------------ animation API

func animate_object(object_id: String, to_stage: float, duration: float = 1.6) -> void:
	focus_object = object_id
	var from := float(display_stage.get(object_id, 0.0))
	var tw := create_tween()
	tw.tween_method(func(v): display_stage[object_id] = v, from, to_stage, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not Game.reduced_motion():
		burst(object_screen_pos(object_id), 26)
	await tw.finished
	focus_object = ""


func animate_area_unlock(area_id: String, duration: float = 1.4) -> void:
	var tw := create_tween()
	tw.tween_method(func(v): display_area_unlocked[area_id] = v, 0.0, 1.0, duration)
	if not Game.reduced_motion():
		burst(area_center(area_id), 40, Palette.GOLD)
	await tw.finished


func burst(at: Vector2, n: int, col: Color = Palette.LEAF_LIGHT) -> void:
	for i in n:
		var a := randf() * TAU
		var sp := randf_range(40.0, 160.0)
		_sparks.append({"p": at, "v": Vector2(cos(a), sin(a) * 0.6 - 0.8) * sp, "life": randf_range(0.6, 1.3), "max": 1.3,
			"c": col if i % 3 else Palette.GOLD, "r": randf_range(2.0, 5.0)})


# ------------------------------------------------------------------ input

func _gui_input(event: InputEvent) -> void:
	if not interactive:
		return
	var pos := Vector2.ZERO
	var hit := false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		hit = true
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
		hit = true
	if hit:
		var a := pick_area(pos)
		if a != "":
			accept_event()
			selected_area = a
			area_selected.emit(a)
			queue_redraw()


func pick_area(pos: Vector2) -> String:
	for i in range(_cells.size() - 1, -1, -1):
		var c: Dictionary = _cells[i]
		var poly := _top_poly(c)
		if Geometry2D.is_point_in_polygon(pos, poly):
			return c["area"]
	return ""


func _top_poly(c: Dictionary) -> PackedVector2Array:
	var gx: float = c.gx
	var gy: float = c.gy
	var h: float = c.h
	return PackedVector2Array([iso(gx, gy, h), iso(gx + 1, gy, h), iso(gx + 1, gy + 1, h), iso(gx, gy + 1, h)])


# ------------------------------------------------------------------ drawing

func _process(delta: float) -> void:
	if not Game.reduced_motion():
		_t += delta
	for s in _sparks:
		s["life"] -= delta
		s["p"] += s["v"] * delta
		s["v"].y += 120.0 * delta
	_sparks = _sparks.filter(func(s): return s["life"] > 0.0)
	queue_redraw()


func _draw() -> void:
	if world.is_empty() or _tw < 4.0:
		return
	_draw_sea()
	for c in _cells:
		_draw_cell(c)
	_draw_objects()
	_draw_mist()
	for s in _sparks:
		var a: float = clampf(s["life"] / s["max"], 0.0, 1.0)
		draw_circle(s["p"], s["r"] * (0.5 + a * 0.5), Color(s["c"], a), true, -1, true)


func _draw_sea() -> void:
	var isl: Dictionary = world.get("island", {})
	var cols := float(isl.get("cols", 8))
	var rows := float(isl.get("rows", 10))
	var c := iso(cols * 0.5, rows * 0.5, -1.0)
	var rx := (cols + rows) * _tw * 0.36
	var ry := rx * 0.56
	for i in 5:
		var k := 1.25 - i * 0.07
		Painter.ellipse(self, c + Vector2(0, _th * 0.5), rx * k, ry * k, Color(Palette.SEA_LIGHT, 0.06 + i * 0.03))
	# lapping foam rings
	for i in 3:
		var ph := fmod(_t * 0.12 + i / 3.0, 1.0)
		var k := 0.92 + ph * 0.25
		draw_arc(c + Vector2(0, _th * 0.5), rx * k, 0, TAU, 64, Color(Palette.FOAM, 0.22 * (1.0 - ph)), 2.0, true)


func _area_colors(area_id: String) -> Array:
	var prog := area_display_progress(area_id)
	var unlocked := float(display_area_unlocked.get(area_id, 0.0))
	var top := Palette.GRASS_DRY.lerp(Palette.GRASS, prog)
	var locked_top := Color("8d8f86")
	top = locked_top.lerp(top, unlocked)
	return [top, prog, unlocked]


func _draw_cell(c: Dictionary) -> void:
	var gx: int = c.gx
	var gy: int = c.gy
	var h: int = c.h
	var cols: Array = _area_colors(c.area)
	var top: Color = cols[0]
	var n := Painter.hash01(gx * 92 + gy * 13)
	top = top.darkened(0.04 * n).lightened(0.03 * (1.0 - n))
	# side faces where the neighbour is lower (or open sea)
	var front_l := Vector2i(gx, gy + 1)
	var front_r := Vector2i(gx + 1, gy)
	var hl := height_at(front_l.x, front_l.y)
	var hr := height_at(front_r.x, front_r.y)
	var cliff := Color("8a7357").lerp(Color("7a6a55"), n)
	if hl < h:
		var bottom := float(hl) if hl >= 0 else -1.2
		draw_colored_polygon(PackedVector2Array([iso(gx, gy + 1, h), iso(gx + 1, gy + 1, h), iso(gx + 1, gy + 1, bottom), iso(gx, gy + 1, bottom)]), cliff.darkened(0.08))
		if hl < 0:
			draw_colored_polygon(PackedVector2Array([iso(gx, gy + 1, -0.85), iso(gx + 1, gy + 1, -0.85), iso(gx + 1, gy + 1, -1.2), iso(gx, gy + 1, -1.2)]), Color(Palette.SAND, 0.9))
	if hr < h:
		var bottom := float(hr) if hr >= 0 else -1.2
		draw_colored_polygon(PackedVector2Array([iso(gx + 1, gy, h), iso(gx + 1, gy + 1, h), iso(gx + 1, gy + 1, bottom), iso(gx + 1, gy, bottom)]), cliff.darkened(0.22))
		if hr < 0:
			draw_colored_polygon(PackedVector2Array([iso(gx + 1, gy, -0.85), iso(gx + 1, gy + 1, -0.85), iso(gx + 1, gy + 1, -1.2), iso(gx + 1, gy, -1.2)]), Color(Palette.SAND_SHADE, 0.9))
	var poly := _top_poly(c)
	draw_colored_polygon(poly, top)
	# grass edge highlight
	draw_line(poly[0], poly[1], Color(1, 1, 1, 0.08), 1.5, true)
	draw_line(poly[0], poly[3], Color(1, 1, 1, 0.05), 1.5, true)
	if selected_area == c.area and interactive:
		var a := 0.12 + 0.08 * sin(_t * 3.0)
		draw_colored_polygon(poly, Color(1, 1, 0.85, a))
	# tiny tufts for texture
	if cols[1] > 0.3 and n > 0.4:
		var p := iso(gx + 0.5, gy + 0.5, h)
		draw_line(p, p + Vector2(-2, -_tw * 0.07), Color(Palette.LEAF_DARK, cols[1]), 2.0, true)
		draw_line(p, p + Vector2(3, -_tw * 0.08), Color(Palette.LEAF_DARK, cols[1]), 2.0, true)


func _draw_objects() -> void:
	var items: Array = []
	for o in world.get("objects", []):
		items.append({"kind": "obj", "o": o, "depth": o["pos"][0] + o["pos"][1]})
	for d in world.get("decorations", []):
		if Game.progression.is_decoration_visible(d["id"]):
			items.append({"kind": "deco", "o": d, "depth": d["pos"][0] + d["pos"][1] + 0.01})
	items.sort_custom(func(a, b): return a.depth < b.depth)
	for it in items:
		var o: Dictionary = it.o
		var gx: float = o["pos"][0]
		var gy: float = o["pos"][1]
		var h := maxi(0, height_at(gx, gy))
		var p := iso(gx, gy, h)
		if it.kind == "deco":
			if float(display_area_unlocked.get(area_at(gx, gy), 1.0)) > 0.5:
				Painter.decoration(self, o["kind"], p, _tw * 0.9, _t)
			continue
		var g := float(display_stage.get(o["id"], 0.0))
		var stages := float(o.get("stages", 1))
		if focus_object == o["id"]:
			var pulse := 0.5 + 0.5 * sin(_t * 6.0)
			Painter.ellipse(self, p, _tw * (0.55 + 0.08 * pulse), _tw * 0.27, Color(Palette.GOLD, 0.25 + 0.2 * pulse))
		# normalise so every kind reads g in 0..2 (single-stage objects map 1 -> 2)
		var g2 := g * (2.0 / stages) if stages > 0 else g
		_draw_object(o, p, g, g2, h)


func _draw_object(o: Dictionary, p: Vector2, g: float, g2: float, h: int) -> void:
	var u := _tw
	var seed_n := int(abs(o["id"].hash())) % 997
	match o["kind"]:
		"tree", "fruit_tree", "heart_tree", "willow", "pine":
			var scale := 1.5 if o["kind"] == "heart_tree" else 1.0
			Painter.tree(self, p, u * 1.1 * scale, g2, o["kind"], _t, seed_n)
		"meadow":
			Painter.meadow(self, p, u * 0.7, g2, _t, seed_n)
		"reeds":
			Painter.reeds(self, p, u * 0.8, g2, _t)
		"spring":
			Painter.spring(self, p, u * 0.95, g2 * 0.5, _t)
		"pond":
			Painter.pond(self, p, u * 0.85, g2, _t, seed_n)
		"stream":
			var to: Array = o.get("to", o["pos"])
			var a := p
			var b := iso(to[0], to[1], maxi(0, height_at(to[0], to[1])))
			var mid := a.lerp(b, 0.5) + Vector2(0, -u * 0.08)
			var pts := PackedVector2Array()
			for i in 13:
				var k := i / 12.0
				pts.append(a.lerp(mid, k).lerp(mid.lerp(b, k), k) + Vector2(sin(k * 7.0 + seed_n) * u * 0.06, 0))
			Painter.stream(self, pts, u * 0.2, g2 * 0.5, _t)
		"waterfall":
			var area: Dictionary = Game.content.areas.get(o["area"], {})
			var r: Array = area.get("rect", [0, 0, 0, 0])
			var edge := float(r[3]) + 1.0
			var top := iso(o["pos"][0], edge, h)
			var bottom := iso(o["pos"][0], edge, h - 1)
			Painter.waterfall(self, top, bottom, u * 0.28, g2 * 0.5, _t)
			if g2 > 1.0:
				Painter.ellipse(self, bottom + Vector2(0, u * 0.06), u * 0.34 * (g2 - 1.0), u * 0.12 * (g2 - 1.0), Color(Palette.WATER, 0.85))
		"rabbits":
			if g2 > 0.05:
				grow_draw(p, func():
					Painter.rabbit(self, p, u * 0.32, _t, 0)
					Painter.rabbit(self, p + Vector2(u * 0.3, u * 0.12), u * 0.26, _t, 1), g2)
		"deer":
			if g2 > 0.05:
				grow_draw(p, func(): Painter.deer(self, p, u * 0.55, _t), g2)
		"ducks":
			if g2 > 0.05:
				var pond_pos := object_screen_pos("pond_main")
				grow_draw(pond_pos, func():
					Painter.duck(self, pond_pos + Vector2(-u * 0.2, 0), u * 0.3, _t, 0)
					Painter.duck(self, pond_pos + Vector2(u * 0.25, u * 0.08), u * 0.25, _t, 1), g2)
		"birds":
			if g2 > 0.05:
				grow_draw(p, func(): Painter.birds(self, p + Vector2(0, -u * 0.8), u * 0.6, _t, 3), g2)
		"terrace":
			Painter.terrace(self, p, u * 0.8, g2, _t)
		"mill":
			Painter.mill(self, p, u * 1.1, g2, _t)


## Draws `f` scaled by k about `anchor` so creatures grow into view.
func grow_draw(anchor: Vector2, f: Callable, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	if k <= 0.02:
		return
	draw_set_transform(anchor * (1.0 - k), 0.0, Vector2(k, k))
	f.call()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_mist() -> void:
	for a in world.get("areas", []):
		var u := 1.0 - float(display_area_unlocked.get(a["id"], 0.0))
		if u <= 0.01:
			continue
		var r: Array = a["rect"]
		var h := float(a.get("height", 0))
		# a few broad, soft mist banks drifting over the area
		var cols := float(r[2]) - float(r[0]) + 1.0
		var rows := float(r[3]) - float(r[1]) + 1.0
		for i in 4:
			var fx: float = float(r[0]) + (0.2 + 0.6 * Painter.hash01(i * 11 + int(r[0]))) * cols
			var fy: float = float(r[1]) + (0.2 + 0.6 * Painter.hash01(i * 23 + int(r[1]))) * rows
			var p := iso(fx, fy, h + 0.25) + Vector2(sin(_t * 0.25 + i) * _tw * 0.15, 0)
			var rad := _tw * (1.0 + 0.4 * Painter.hash01(i * 5))
			for k in 3:
				Painter.ellipse(self, p, rad * (1.0 - k * 0.25), rad * 0.42 * (1.0 - k * 0.25), Color(0.9, 0.95, 0.95, 0.1 * u))
		# lock badge
		var c := area_center(a["id"]) + Vector2(0, -_tw * 0.4)
		draw_circle(c, _tw * 0.3, Color(Palette.NIGHT, 0.55 * u), true, -1, true)
		Painter.icon(self, "lock", Rect2(c - Vector2.ONE * _tw * 0.17, Vector2.ONE * _tw * 0.34), Color(Palette.CREAM, u))
