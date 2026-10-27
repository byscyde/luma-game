class_name IconBaker
extends Node
## Bakes the procedural merge icons (ItemArt) and character portraits (PortraitArt)
## into glossy "3D" textures, once per id and session: the flat drawing is rendered
## into an atlas, then a shader turns its silhouette and colour edges into a height
## field and lights it (soft bevel, diffuse + specular, contact shadow). Views ask
## for `texture(id)`; until it is ready they draw the flat icon and get `baked`.
##
## Lives as a child of the scene tree root (created on first use).

signal baked

const CELL := 256            ## px per icon in the atlas
const GRID := 8              ## icons per atlas side
const SHADER := preload("res://scripts/merge/icon_3d.gdshader")

static var _inst: IconBaker

var _cache: Dictionary = {}  ## key -> ImageTexture
var _queue: Array = []       ## keys waiting
var _busy := false


static func instance() -> IconBaker:
	if _inst == null or not is_instance_valid(_inst):
		_inst = IconBaker.new()
		_inst.name = "IconBaker"
		var tree := Engine.get_main_loop() as SceneTree
		tree.root.add_child.call_deferred(_inst)
	return _inst


## Baked texture for an item id ("chain:level") or a portrait ("portrait:<who>"),
## or null while it is being made.
static func texture(key: String) -> Texture2D:
	if key == "" or DisplayServer.get_name() == "headless":
		return null
	var b := instance()
	if b._cache.has(key):
		return b._cache[key]
	if not b._queue.has(key):
		b._queue.append(key)
		b._kick.call_deferred()
	return null


func _kick() -> void:
	if _busy or _queue.is_empty() or not is_inside_tree():
		return
	_busy = true
	while not _queue.is_empty():
		# people get a softer, rounder relief than items (no lumps on faces)
		var soft := _is_person(str(_queue[0]))
		var batch: Array = []
		for k in _queue.duplicate():
			if batch.size() < GRID * GRID and _is_person(k) == soft:
				batch.append(k)
				_queue.erase(k)
		await _bake(batch, soft)
	_busy = false
	baked.emit()


static func _is_person(key: String) -> bool:
	return key.begins_with("portrait:") or key.begins_with("bust:")


func _bake(keys: Array, soft := false) -> void:
	var size := Vector2i(CELL * GRID, CELL * GRID)
	var flat := SubViewport.new()
	flat.size = size
	flat.transparent_bg = true
	flat.msaa_2d = Viewport.MSAA_4X
	flat.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := _Painter.new()
	painter.keys = keys
	painter.size = Vector2(size)
	flat.add_child(painter)
	add_child(flat)
	var lit := SubViewport.new()
	lit.size = size
	lit.transparent_bg = true
	lit.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := TextureRect.new()
	rect.texture = flat.get_texture()
	rect.size = Vector2(size)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("px", Vector2(1.0 / size.x, 1.0 / size.y))
	mat.set_shader_parameter("src", flat.get_texture())
	mat.set_shader_parameter("radius", (12.0 if soft else 10.0) * CELL / 160.0)
	mat.set_shader_parameter("relief", 1.6 if soft else 9.0)
	mat.set_shader_parameter("lum_weight", 0.03 if soft else 0.22)
	rect.material = mat
	lit.add_child(rect)
	add_child(lit)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := lit.get_texture().get_image()
	for i in keys.size():
		var cell := Rect2i((i % GRID) * CELL, (i / GRID) * CELL, CELL, CELL)
		var sub := img.get_region(cell)
		sub.generate_mipmaps()
		_cache[keys[i]] = ImageTexture.create_from_image(sub)
	flat.queue_free()
	lit.queue_free()


## Draws the flat versions of a batch into the atlas (with a margin for the bevel and shadow).
class _Painter:
	extends Control
	var keys: Array = []

	func _draw() -> void:
		for i in keys.size():
			var cell := Rect2(Vector2((i % GRID) * CELL, (i / GRID) * CELL), Vector2(CELL, CELL))
			var key: String = keys[i]
			var r := cell.grow(-CELL * 0.1)
			r.position.y -= CELL * 0.03
			if key.begins_with("portrait:"):
				PortraitArt.draw(self, key.substr(9), cell.grow(-CELL * 0.04))
			elif key.begins_with("bust:"):
				PortraitArt.draw_bust(self, key.substr(5), cell.grow(-CELL * 0.04))
			else:
				ItemArt.draw(self, key, r)
