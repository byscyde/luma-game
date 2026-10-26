extends Node
## Renders the loading-screen key art from the real 3D island, fully restored,
## in several moods. Output: build/key_art/<shot>.png (1080x1920), which
## tools/paint_key_art.py grades into assets/branding/loading_<n>.jpg.
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
	get_tree().quit()
