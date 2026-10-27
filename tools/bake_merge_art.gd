extends Node
## Renders the merge art (items, currencies, characters) with the SDF renderer into
## PNGs under assets/merge/art. Needs a display (Xvfb works):
##   xvfb-run -a godot --path . --rendering-driver opengl3 res://tools/bake_merge_art.tscn -- [--set=all|cafe|people|...] [--only=key,key] [--size=px] [--out=dir]
## then: python3 tools/finish_merge_art.py   (round portraits, asset manifest)
## Deterministic: the same models give the same PNGs.

const SHADER := preload("res://tools/art/sdf_render.gdshader")
const SETS := ["shared", "people", "cafe"]
const SIZES := {"people": 384}   ## px; everything else 256

var out_dir := "res://assets/merge/art"
var size := 0
var only: PackedStringArray = []
var set_name := "all"
var debug := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7).split(",")
		elif a.begins_with("--size="):
			size = int(a.substr(7))
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--debug="):
			debug = int(a.substr(8))
		elif a.begins_with("--set="):
			set_name = a.substr(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var sets: Array = SETS if set_name == "all" else [set_name]
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var rect := ColorRect.new()
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	rect.material = mat
	vp.add_child(rect)
	add_child(vp)
	for sname in sets:
		var lib = load("res://tools/art".path_join("models_%s.gd" % sname))
		var keys: Array = lib.keys()
		if not only.is_empty():
			keys = keys.filter(func(k): return only.has(k))
		var px := int(SIZES.get(sname, 256)) if size == 0 else size
		vp.size = Vector2i(px, px)
		rect.size = Vector2(px, px)
		await _bake_set(lib, keys, vp, mat)
	get_tree().quit()


func _bake_set(lib, keys: Array, vp: SubViewport, mat: ShaderMaterial) -> void:
	for key in keys:
		var t := Time.get_ticks_msec()
		var m: ArtModel = lib.build(key)
		m.apply(mat)
		mat.set_shader_parameter("debug", debug)
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var path := ProjectSettings.globalize_path(out_dir.path_join(str(key).replace(":", "_") + ("" if debug == 0 else "_d%d" % debug) + ".png"))
		img.save_png(path)
		print("baked %s (%d prims) in %d ms" % [key, m.prims.size(), Time.get_ticks_msec() - t])
