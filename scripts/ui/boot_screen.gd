extends Control
## Boot: continues the native SCYDE splash (same logo, same place), then a
## LUMA loading screen while the first scene loads on a background thread,
## then straight into play for first-time players (no menu before the first
## puzzle) or the menu for returning players.

const LOGO_BG := Color(0.047, 0.059, 0.078)
const NIGHT_TOP := Color("1b2350")
const NIGHT_BOTTOM := Color("090c1f")
const SPLASH_PX := 1080.0       ## boot splash image size (assets/branding/scyde_splash.png)
const WORDMARK_PX := 380.0      ## wordmark width inside that image

var _target: Dictionary
var _scene_path := ""
var _bar: ProgressBar
var _logo: TextureRect
var _loading: Control
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
	_loading = Control.new()
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.modulate.a = 0.0
	add_child(_loading)
	var grad := NightGradient.new()
	grad.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(grad)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 34)
	_loading.add_child(col)
	col.add_child(UI.spacer(0, true))
	var art := TextureRect.new()
	art.texture = load("res://assets/branding/luma_key_art.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size = Vector2(0, minf(460.0, get_viewport_rect().size.x * 0.66))
	col.add_child(art)
	var bar_row := CenterContainer.new()
	col.add_child(bar_row)
	_bar = ProgressBar.new()
	_bar.name = "LoadingBar"
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(minf(420.0, get_viewport_rect().size.x * 0.6), 14)
	_bar.add_theme_stylebox_override("background", ThemeBuilder.box(Color(1, 1, 1, 0.12), 7, 0, Color.TRANSPARENT, 0, 0, 0))
	_bar.add_theme_stylebox_override("fill", ThemeBuilder.box(Color("ffd76a"), 7, 0, Color.TRANSPARENT, 0, 0, 0))
	bar_row.add_child(_bar)
	var cap := UI.label(UI.t("LOADING"), "", 24, HORIZONTAL_ALIGNMENT_CENTER)
	cap.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0, 0.75))
	col.add_child(cap)
	col.add_child(UI.spacer(0, true))
	# developer mark at the bottom
	var by := TextureRect.new()
	by.texture = load("res://assets/branding/scyde_wordmark.png")
	by.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	by.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	by.modulate = Color(1, 1, 1, 0.55)
	by.custom_minimum_size = Vector2(0, 38)
	col.add_child(by)
	var full := get_viewport().get_visible_rect()
	var safe := PlatformServices.safe_area_rect(get_viewport())
	col.add_child(UI.spacer(48 + maxf(0.0, full.end.y - safe.end.y)))


func _run() -> void:
	var fast := Game.reduced_motion()
	var tw := create_tween()
	tw.tween_interval(0.05 if fast else 0.7)               # hold the brand
	tw.tween_property(_logo, "modulate:a", 0.0, 0.05 if fast else 0.35)
	tw.parallel().tween_property(_bg, "color", NIGHT_TOP, 0.05 if fast else 0.35)
	tw.tween_property(_loading, "modulate:a", 1.0, 0.05 if fast else 0.3)
	await tw.finished
	var min_end := Time.get_ticks_msec() + (0 if fast else 700)
	while true:
		var p := _progress()
		_bar.value = lerpf(_bar.value, p * 100.0, 0.35)
		if p >= 1.0 and Time.get_ticks_msec() >= min_end:
			break
		await get_tree().process_frame
	_bar.value = 100.0
	if _scene_path != "" and not Router.dry_run:
		ResourceLoader.load_threaded_get(_scene_path)  # keep it cached for the change
	route()


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
	var r := first_scene()
	Router.go(r["scene"], r["params"])


## Deep night-blue gradient matching the app icon.
class NightGradient extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var top := Color("1b2350")
		var bottom := Color("090c1f")
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([top, top, bottom, bottom]))
		for i in 6:
			draw_circle(Vector2(w * 0.5, h * 0.42), h * (0.12 + i * 0.06), Color(1.0, 0.75, 0.35, 0.03), true, -1, true)
