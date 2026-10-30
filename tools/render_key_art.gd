extends Node
## Renders the loading-screen key art: Verdant Isle from the real 3D island, fully
## restored, then one painting per archipelago island made from that island's real
## game board, solved, on its own sky. Output: build/key_art/<shot>.png (1080x1920),
## which tools/paint_key_art.py grades into assets/branding/loading_<n>.jpg.
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/render_key_art.tscn

const SIZE := Vector2i(1080, 1920)
const OUT := "res://build/key_art"

## shot: area to frame (or "" for the whole island) pulled toward the island
## centre by `pull`, distance factor, yaw/pitch
## in degrees, sun colour/energy/angles, sky colour, ambient colour/energy.
const SHOTS := [
	{"name": "dawn", "area": "", "dist": 0.66, "yaw": -12.0, "pitch": 36.0, "pull": 0.0,
		"sun": Color(1.0, 0.82, 0.6), "energy": 0.8, "sun_rot": Vector3(-26, -70, 0),
		"sky": Color(0.98, 0.78, 0.6), "amb": Color(0.95, 0.82, 0.76), "amb_e": 0.26},
	{"name": "glade", "area": "spring_glade", "dist": 0.42, "yaw": -24.0, "pitch": 32.0, "pull": 0.0,
		"sun": Color(1.0, 0.95, 0.85), "energy": 0.7, "sun_rot": Vector3(-48, -40, 0),
		"sky": Color(0.5, 0.8, 0.88), "amb": Color(0.74, 0.84, 0.95), "amb_e": 0.26},
	{"name": "falls", "area": "heart_falls", "dist": 0.4, "yaw": -12.0, "pitch": 28.0, "pull": 0.45,
		"sun": Color(1.0, 0.9, 0.74), "energy": 0.74, "sun_rot": Vector3(-36, 10, 0),
		"sky": Color(0.62, 0.82, 0.88), "amb": Color(0.78, 0.86, 0.95), "amb_e": 0.25},
	{"name": "ponds", "area": "lily_ponds", "dist": 0.4, "yaw": -40.0, "pitch": 34.0, "pull": 0.25,
		"sun": Color(1.0, 0.86, 0.68), "energy": 0.76, "sun_rot": Vector3(-30, -100, 0),
		"sky": Color(0.6, 0.8, 0.86), "amb": Color(0.8, 0.84, 0.92), "amb_e": 0.26},
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.msaa_3d = Viewport.MSAA_8X
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var w := IslandWorld.new()
	vp.add_child(w)
	w.build(Game.content.worlds[0])
	w.sun.directional_shadow_max_distance = 60.0
	for a in w.area_ids:
		w.set_area_awake(a, 1.0)
		w.set_area_progress(a, 1.0)
	for id in w.props:
		var pr: IslandProp = w.props[id]
		pr.set_growth(float(pr.data.get("stages", 1)))
	for id in w.decos:
		w.decos[id].visible = true
	var env: Environment = null
	for c in w.get_children():
		if c is WorldEnvironment:
			env = c.environment
	var aspect := float(SIZE.x) / float(SIZE.y)
	var full := w.fit_distance(aspect)
	var home := w.cam_target
	for s in SHOTS:
		w.cam_yaw = deg_to_rad(s["yaw"])
		w.cam_pitch = deg_to_rad(s["pitch"])
		var target: Vector3 = home if s["area"] == "" else w.area_center3d(s["area"]).lerp(home, float(s["pull"]))
		w.set_view(target, full * float(s["dist"]))
		w.sun.light_color = s["sun"]
		w.sun.light_energy = s["energy"]
		w.sun.rotation_degrees = s["sun_rot"]
		if env:
			env.background_color = s["sky"]
			env.ambient_light_color = s["amb"]
			env.ambient_light_energy = s["amb_e"]
		await get_tree().create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path(OUT.path_join(String(s["name"]) + ".png"))
		vp.get_texture().get_image().save_png(path)
		print("saved ", path)
	vp.queue_free()
	for shot in ISLAND_SHOTS:
		await _render_island(shot)
	get_tree().quit()


## Archipelago islands: sky gradient (top, bottom), glow colour, board tilt (degrees), level.
const ISLAND_SHOTS := [
	{"name": "ember", "top": Color("3b1d2e"), "bottom": Color("e0703f"), "glow": Color(1.0, 0.6, 0.3), "tilt": -7.0, "level": 26},
	{"name": "lantern", "top": Color("0c1430"), "bottom": Color("2a3f72"), "glow": Color(1.0, 0.85, 0.45), "tilt": 6.0, "level": 29},
	{"name": "steps", "top": Color("a9c7b0"), "bottom": Color("6f8a5a"), "glow": Color(1.0, 0.95, 0.8), "tilt": -5.0, "level": 20},
	{"name": "rope", "top": Color("9fd8ec"), "bottom": Color("2c7fa8"), "glow": Color(1.0, 1.0, 0.9), "tilt": 5.0, "level": 21},
	{"name": "grove", "top": Color("120f2e"), "bottom": Color("3b2f6e"), "glow": Color(0.8, 0.75, 1.0), "tilt": -6.0, "level": 25},
]


func _render_island(shot: Dictionary) -> void:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = false
	vp.msaa_2d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var sky := KeyArtSky.new()
	sky.top = shot["top"]
	sky.bottom = shot["bottom"]
	sky.glow = shot["glow"]
	sky.size = Vector2(SIZE)
	vp.add_child(sky)
	var board := _island_board(str(shot["name"]), int(shot["level"]))
	board.size = Vector2(SIZE.x * 1.08, SIZE.y * 0.72)
	board.position = Vector2(SIZE.x * -0.04, SIZE.y * 0.17)
	board.pivot_offset = board.size * 0.5
	board.rotation_degrees = float(shot["tilt"])
	vp.add_child(board)
	await get_tree().create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path(OUT.path_join(String(shot["name"]) + ".png"))
	vp.get_texture().get_image().save_png(path)
	print("saved ", path)
	vp.queue_free()


## A late level of the island's game, solved, in its real board view.
func _island_board(name: String, index: int) -> Control:
	match name:
		"ember":
			var lv: Dictionary = Game.island_levels("ember_reef")[index]
			var sb := SlideBoard.from_dict(lv)
			for m in lv["solution"]:
				sb.apply(m)
			var v := SlideBoardView.new()
			v.frame_ring = true
			v.inner_w = sb.w
			v.inner_h = sb.h
			v.input_enabled = false
			v.ready.connect(func():
				v.setup(sb.puzzle_board())
				for p in v.views:
					var inner: bool = p.x >= 1 and p.y >= 1 and p.x <= sb.w and p.y <= sb.h
					v.views[p].block = inner
					v.views[p].quiet = not inner
				v.apply_water(sb.simulate(), false))
			return v
		"lantern":
			var lv: Dictionary = Game.island_levels("lantern_bay")[index]
			var lb := LightBoard.from_dict(lv)
			for c in lv["solution"]:
				lb.toggle(Vector2i(int(c[0]), int(c[1])))
			var v := LightBoardView.new()
			v.input_enabled = false
			v.ready.connect(func():
				v.setup(lb)
				v.show_trace(lb.trace(), false))
			return v
		"steps":
			var lv: Dictionary = Game.island_levels("stone_steps")[index]
			var pb := PushBoard.from_dict(lv)
			var sol: Array = lv["solution"]
			for i in sol.size() - 3:
				pb.step(sol[i])
			var v := PushBoardView.new()
			v.input_enabled = false
			v.ready.connect(func(): v.setup(pb))
			return v
		"rope":
			var lv: Dictionary = Game.island_levels("rope_isles")[index]
			var bb := BridgeBoard.from_dict(lv)
			for e in lv["solution"]:
				var k := bb.link_between(bb.island_at(Vector2i(int(e[0]), int(e[1]))), bb.island_at(Vector2i(int(e[2]), int(e[3]))))
				for n in int(e[4]):
					bb.tap(k)
			var v := BridgeBoardView.new()
			v.input_enabled = false
			v.ready.connect(func(): v.setup(bb))
			return v
		_:
			var lv: Dictionary = Game.island_levels("moon_grove")[index]
			var mb := MatchBoard.from_dict(lv)
			var sol: Array = lv["solution"]
			for i in mini(6, sol.size()):
				var m: Array = sol[i]
				mb.swap(Vector2i(int(m[0]), int(m[1])), Vector2i(int(m[2]), int(m[3])))
			var v := MatchBoardView.new()
			v.input_enabled = false
			v.ready.connect(func(): v.setup(mb))
			return v


## Sky behind an island board: a vertical gradient, a soft glow and a few stars.
class KeyArtSky:
	extends Control
	var top := Color.BLACK
	var bottom := Color.BLACK
	var glow := Color.WHITE

	func _draw() -> void:
		var n := 48
		for k in n:
			var r := Rect2(0, size.y * k / n, size.x, size.y / n + 1)
			draw_rect(r, top.lerp(bottom, float(k) / (n - 1)))
		for k in 10:
			draw_circle(Vector2(size.x * 0.72, size.y * 0.12), size.x * (0.05 + k * 0.05), Color(glow, 0.05))
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for k in 60:
			var p := Vector2(rng.randf() * size.x, rng.randf() * size.y * 0.2)
			draw_circle(p, rng.randf_range(1.0, 3.0), Color(1, 1, 1, rng.randf_range(0.15, 0.6)))
