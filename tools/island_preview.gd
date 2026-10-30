extends Node
## Dev preview: renders the 3D island at given restoration levels and saves
## PNGs. xvfb-run godot --path . --resolution 720x1280 res://tools/island_preview.tscn
var out := "res://build/preview"

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(svc)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	svc.add_child(vp)
	var w := IslandWorld.new()
	vp.add_child(w)
	w.build(Game.content.worlds[0])
	await get_tree().process_frame
	var aspect := float(vp.size.x) / float(vp.size.y)
	w.set_view(w.cam_target, w.fit_distance(aspect))
	for stage in [["dry", 0.0, 0], ["mid", 1.0, 3], ["full", 2.0, 6]]:
		for i in w.area_ids.size():
			var a: String = w.area_ids[i]
			var awake := 1.0 if i < int(stage[2]) or stage[2] == 6 else 0.0
			if stage[0] == "dry":
				awake = 1.0 if i == 0 else 0.0
			w.set_area_awake(a, awake)
			w.set_area_progress(a, 0.0 if stage[0] == "dry" else (1.0 if i < int(stage[2]) else 0.0))
		for id in w.props:
			var pr: IslandProp = w.props[id]
			var ai: int = w.area_index[pr.data["area"]]
			pr.set_growth(float(stage[1]) * (2.0 / float(pr.data.get("stages", 1))) * 0.5 * float(pr.data.get("stages", 1)) if ai < int(stage[2]) else 0.0)
		for id in w.decos:
			w.decos[id].visible = stage[0] == "full"
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(ProjectSettings.globalize_path(out.path_join("island_%s.png" % stage[0])))
		print("saved ", stage[0])
	get_tree().quit()
