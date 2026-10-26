extends Control
## Boot: continues the native SCYDE splash (same logo, same place), then the
## LUMA loading screen (LoadingScreen) while the first scene loads on a thread,
## then straight into play for first-time players (no menu before the first
## puzzle) or the menu for returning players.

const LOGO_BG := Color(0.047, 0.059, 0.078)
const SPLASH_PX := 1080.0       ## boot splash image size (assets/branding/scyde_splash.png)
const WORDMARK_PX := 380.0      ## wordmark width inside that image

var _target: Dictionary
var _scene_path := ""
var _logo: TextureRect
var _loading: LoadingScreen
var _routed := false
var _bg: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_target = first_scene()
	_scene_path = Router.SCENES.get(_target["scene"], "")
	if _scene_path != "" and not Router.dry_run:
		ResourceLoader.load_threaded_request(_scene_path)
	_bg = ColorRect.new()
	_bg.color = LOGO_BG
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)
	_build_logo()
	_build_loading()
	_run()


## The wordmark at exactly the size the native splash showed it, so the
## hand-over from the engine splash is invisible.
func _build_logo() -> void:
	var tex: Texture2D = load("res://assets/branding/scyde_wordmark.png")
	_logo = TextureRect.new()
	_logo.texture = tex
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var win := Vector2(get_window().size) if get_window() else size
	var vp := get_viewport_rect().size
	var fit := minf(1.0, minf(win.x, win.y) / SPLASH_PX)
	var w := WORDMARK_PX * fit * (vp.x / maxf(win.x, 1.0))
	var h := w * tex.get_height() / float(tex.get_width())
	_logo.custom_minimum_size = Vector2(w, h)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.add_child(_logo)


func _build_loading() -> void:
	_loading = LoadingScreen.new()
	_loading.modulate.a = 0.0
	add_child(_loading)
	_loading.finished.connect(route)


func _run() -> void:
	var fast := Game.reduced_motion()
	var tw := create_tween()
	tw.tween_interval(0.05 if fast else 0.7)               # hold the brand
	tw.tween_property(_logo, "modulate:a", 0.0, 0.05 if fast else 0.35)
	tw.tween_property(_loading, "modulate:a", 1.0, 0.05 if fast else 0.45)
	await tw.finished
	while is_inside_tree():
		_loading.progress = _progress()
		await get_tree().process_frame


func _progress() -> float:
	if _scene_path == "" or Router.dry_run:
		return 1.0
	var arr := []
	var st := ResourceLoader.load_threaded_get_status(_scene_path, arr)
	if st == ResourceLoader.THREAD_LOAD_LOADED or st == ResourceLoader.THREAD_LOAD_FAILED \
			or st == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		return 1.0
	return float(arr[0]) if not arr.is_empty() else 0.0


static func first_scene() -> Dictionary:
	var first: String = Game.content.level_order[0] if not Game.content.level_order.is_empty() else ""
	if first != "" and not Game.progression.is_completed(first):
		return {"scene": "gameplay", "params": {"level_id": first}}
	return {"scene": "menu", "params": {}}


func route() -> void:
	if _routed:
		return
	_routed = true
	if _scene_path != "" and not Router.dry_run:
		ResourceLoader.load_threaded_get(_scene_path)  # keep it cached for the change
	var r := first_scene()
	Router.go(r["scene"], r["params"])
