class_name LoadingScreen
extends Control
## The loading screen: paintings of the restored island (assets/branding/
## loading_1..4, rendered from the real 3D island by tools/render_key_art.gd and
## graded by tools/paint_key_art.py) drift slowly in a Ken Burns move and
## dissolve into one another, each with its own chapter caption, while
## fireflies rise from the bottom. The title sits at the top; the progress bar,
## a tip and the version along the bottom. Paintings fill any screen shape.
##
## The owner sets `progress` (0..1); `finished` is emitted once loading is done
## and at least the first chapter has been on screen long enough to read.

signal finished

const SCENE_SECONDS := 6.5
const FADE_SECONDS := 1.4
const MIN_SECONDS := 2.6
const FIREFLIES := 22
const GOLD := Color("ffd27a")
const PALE := Color(0.93, 0.95, 0.92, 0.9)

const SCENES := [
	{"img": "res://assets/branding/loading_1.jpg", "title": "LOAD_CH1_TITLE", "line": "LOAD_CH1_LINE",
		"s0": 1.05, "s1": 1.14, "from": Vector2(0.0, 0.01), "to": Vector2(-0.02, -0.01)},
	{"img": "res://assets/branding/loading_2.jpg", "title": "LOAD_CH2_TITLE", "line": "LOAD_CH2_LINE",
		"s0": 1.14, "s1": 1.06, "from": Vector2(0.02, 0.0), "to": Vector2(-0.015, 0.005)},
	{"img": "res://assets/branding/loading_3.jpg", "title": "LOAD_CH3_TITLE", "line": "LOAD_CH3_LINE",
		"s0": 1.06, "s1": 1.15, "from": Vector2(-0.02, 0.0), "to": Vector2(0.01, -0.01)},
	{"img": "res://assets/branding/loading_4.jpg", "title": "LOAD_CH4_TITLE", "line": "LOAD_CH4_LINE",
		"s0": 1.13, "s1": 1.05, "from": Vector2(-0.015, -0.01), "to": Vector2(0.015, 0.005)},
]
const NUMERALS := ["I", "II", "III", "IV"]
const TIPS := ["LOAD_TIP_1", "LOAD_TIP_2", "LOAD_TIP_3", "LOAD_TIP_4", "LOAD_TIP_5", "LOAD_TIP_6"]
const STATUS := ["LOAD_STATUS_1", "LOAD_STATUS_2", "LOAD_STATUS_3", "LOAD_STATUS_4"]

var progress := 0.0            ## set by the owner, 0..1

var _slides: Array[TextureRect] = []
var _slide_scene := [-1, -1]
var _front := 0
var _scene := -1
var _scene_t := 0.0
var _t := 0.0
var _shown := 0.0
var _done := false
var _chapter: Label
var _cap_title: Label
var _cap_line: Label
var _caption: Control
var _pips: Array[Panel] = []
var _status: Label
var _percent: Label
var _tip: Label
var _track: Control
var _fill: TextureRect
var _head: Control
var _flies: Fireflies
var _tip_index := 0
var _reduced := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reduced = Game.reduced_motion()
	var bg := ColorRect.new()
	bg.color = Color("0b0f12")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for i in 2:
		var s := TextureRect.new()
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		s.set_anchors_preset(Control.PRESET_FULL_RECT)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.modulate.a = 0.0
		add_child(s)
		_slides.append(s)
	add_child(_shade(true, 0.40, [Color(0.02, 0.04, 0.05, 0.7), Color(0.02, 0.04, 0.05, 0.22), Color(0.02, 0.04, 0.05, 0.0)]))
	add_child(_shade(false, 0.52, [Color(0.02, 0.03, 0.04, 0.0), Color(0.02, 0.03, 0.04, 0.5), Color(0.01, 0.02, 0.03, 0.9)]))
	_flies = Fireflies.new()
	_flies.count = 0 if _reduced else FIREFLIES
	_flies.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_flies)
	_build_brand()
	_build_bottom()
	_tip_index = randi() % TIPS.size()
	_tip.text = UI.t(TIPS[_tip_index])
	_show_scene(0)


func _shade(top: bool, frac: float, cols: Array) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	g.colors = PackedColorArray(cols)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(0, 1)
	tex.width = 4
	tex.height = 128
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if top:
		r.anchor_right = 1.0
		r.anchor_bottom = frac
	else:
		r.anchor_top = 1.0 - frac
		r.anchor_right = 1.0
		r.anchor_bottom = 1.0
	return r


func _spaced(size: int, spacing: int, display := true) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = ThemeBuilder.font_display() if display else ThemeBuilder.font_bold()
	f.spacing_glyph = spacing
	return f


func _label(text: String, font: Font, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _safe_insets() -> Vector2:
	var vp := get_viewport()
	if vp == null:
		return Vector2.ZERO
	var full := vp.get_visible_rect()
	var safe := PlatformServices.safe_area_rect(vp)
	return Vector2(maxf(0.0, safe.position.y - full.position.y), maxf(0.0, full.end.y - safe.end.y))


func _build_brand() -> void:
	var inset := _safe_insets()
	var brand := VBoxContainer.new()
	brand.anchor_right = 1.0
	brand.offset_top = inset.x + 70
	brand.add_theme_constant_override("separation", 0)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brand)
	brand.add_child(_label("LUMA", _spaced(96, 10), 96, Color.WHITE))
	brand.add_child(_label(UI.t("SUBTITLE").to_upper(), _spaced(22, 6, false), 22, GOLD))


func _build_bottom() -> void:
	var inset := _safe_insets()
	var col := VBoxContainer.new()
	col.anchor_top = 1.0
	col.anchor_right = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = 36
	col.offset_right = -36
	col.offset_bottom = -(inset.y + 26)
	col.grow_vertical = Control.GROW_DIRECTION_BEGIN
	col.add_theme_constant_override("separation", 10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	# chapter caption: numeral between two gold rules, name, one line, pips
	var cap := VBoxContainer.new()
	cap.add_theme_constant_override("separation", 4)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption = cap
	col.add_child(cap)
	var rule_row := HBoxContainer.new()
	rule_row.alignment = BoxContainer.ALIGNMENT_CENTER
	rule_row.add_theme_constant_override("separation", 14)
	rule_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(rule_row)
	rule_row.add_child(_rule(false))
	_chapter = _label("I", _spaced(22, 5, false), 22, GOLD)
	rule_row.add_child(_chapter)
	rule_row.add_child(_rule(true))
	_cap_title = _label("", _spaced(44, 2), 44, Color("fff4dc"))
	cap.add_child(_cap_title)
	_cap_line = _label("", ThemeBuilder.font_bold(), 25, PALE)
	_cap_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.add_child(_cap_line)
	var pip_row := HBoxContainer.new()
	pip_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pip_row.add_theme_constant_override("separation", 8)
	pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(pip_row)
	for i in SCENES.size():
		var p := Panel.new()
		p.custom_minimum_size = Vector2(10, 8)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(1, 1, 1, 0.3), 4, 0, Color.TRANSPARENT, 0, 0, 0))
		pip_row.add_child(p)
		_pips.append(p)
	col.add_child(UI.spacer(26))
	# progress: what is happening and how far, over a slim bar with a glowing head
	var labels := HBoxContainer.new()
	labels.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(labels)
	_status = _label(UI.t(STATUS[0]), ThemeBuilder.font_bold(), 22, PALE, HORIZONTAL_ALIGNMENT_LEFT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(_status)
	_percent = _label("0%", ThemeBuilder.font_bold(), 22, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	labels.add_child(_percent)
	_track = Panel.new()
	_track.custom_minimum_size = Vector2(0, 10)
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(0.01, 0.02, 0.03, 0.6), 5, 0, Color(1, 0.88, 0.48, 0.3), 1, 0, 0))
	col.add_child(_track)
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([Color("1f8fa6"), Color("4fd3e0"), GOLD])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 128
	gt.height = 4
	_fill = TextureRect.new()
	_fill.texture = gt
	_fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fill.stretch_mode = TextureRect.STRETCH_SCALE
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.position = Vector2(1, 1)
	_track.add_child(_fill)
	_head = Glow.new()
	_head.size = Vector2(30, 30)
	_track.add_child(_head)
	col.add_child(UI.spacer(10))
	_tip = _label("", ThemeBuilder.font_bold(), 21, Color(0.85, 0.9, 0.88, 0.75))
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_tip)
	var ver := _label("v%s · SCYDE" % ProjectSettings.get_setting("application/config/version", ""), ThemeBuilder.font_bold(), 16, Color(1, 1, 1, 0.45))
	col.add_child(ver)


func _rule(right: bool) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var c := Color(1, 0.88, 0.48, 0.85)
	g.colors = PackedColorArray([c, Color(c, 0.0)] if right else [Color(c, 0.0), c])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 2
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.custom_minimum_size = Vector2(70, 2)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _show_scene(i: int) -> void:
	_scene = i
	_scene_t = 0.0
	_front = 1 - _front
	var s := _slides[_front]
	s.texture = load(SCENES[i]["img"])
	_slide_scene[_front] = i
	s.modulate.a = 0.0
	s.move_to_front()
	# keep the overlays above the paintings
	for c in get_children():
		if c != _slides[0] and c != _slides[1] and not (c is ColorRect):
			move_child(c, get_child_count() - 1)
	var tw := create_tween()
	tw.tween_property(s, "modulate:a", 1.0, 0.25 if _reduced else FADE_SECONDS)
	_chapter.text = NUMERALS[i]
	_cap_title.text = UI.t(SCENES[i]["title"])
	_cap_line.text = UI.t(SCENES[i]["line"])
	_caption.modulate.a = 0.0
	create_tween().tween_property(_caption, "modulate:a", 1.0, 0.2 if _reduced else 0.8)
	for k in _pips.size():
		_pips[k].custom_minimum_size = Vector2(28 if k == i else 10, 8)
		(_pips[k].get_theme_stylebox("panel") as StyleBoxFlat).bg_color = GOLD if k == i else Color(1, 1, 1, 0.3)


func _process(delta: float) -> void:
	_t += delta
	_scene_t += delta
	# Ken Burns on both slides (the outgoing one keeps drifting while it fades)
	for k in 2:
		var si: int = _slide_scene[k]
		if si < 0:
			continue
		var sc: Dictionary = SCENES[si]
		var u := clampf((_scene_t if si == _scene else _scene_t + SCENE_SECONDS) / (SCENE_SECONDS + FADE_SECONDS), 0.0, 1.0)
		if _reduced:
			u = 0.0
		var s := lerpf(sc["s0"], sc["s1"], u)
		var off: Vector2 = (sc["from"] as Vector2).lerp(sc["to"], u) * size
		var slide := _slides[k]
		slide.pivot_offset = size * 0.5
		slide.scale = Vector2(s, s)
		slide.position = off
	if not _reduced and _scene_t >= SCENE_SECONDS:
		_show_scene((_scene + 1) % SCENES.size())
	# progress bar eases toward the real value
	_shown = progress if _reduced else lerpf(_shown, progress, clampf(delta * 6.0, 0.0, 1.0))
	if progress >= 1.0 and _shown > 0.995:
		_shown = 1.0
	var w := maxf(0.0, (_track.size.x - 2.0) * _shown)
	_fill.size = Vector2(w, maxf(0.0, _track.size.y - 2.0))
	_head.position = Vector2(w - _head.size.x * 0.5 + 1.0, _track.size.y * 0.5 - _head.size.y * 0.5)
	_head.visible = _shown > 0.01
	_percent.text = "%d%%" % roundi(_shown * 100.0)
	_status.text = UI.t(STATUS[mini(STATUS.size() - 1, int(_shown * (STATUS.size() - 1) + 0.0001))])
	if fmod(_t, 4.0) < delta and _t > 1.0:
		_tip_index = (_tip_index + 1) % TIPS.size()
		_tip.text = UI.t(TIPS[_tip_index])
	if not _done and _shown >= 1.0 and _t >= (0.0 if _reduced else MIN_SECONDS):
		_done = true
		finished.emit()


## Soft round glow for the progress head.
class Glow extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		for i in 6:
			var k := float(i) / 5.0
			draw_circle(c, size.x * 0.5 * (1.0 - k * 0.8), Color(1.0, 0.9, 0.6, 0.08 + 0.14 * k), true, -1, true)
		draw_circle(c, size.x * 0.12, Color(1, 1, 0.92), true, -1, true)


## Fireflies drifting up from the bottom of the frame.
class Fireflies extends Control:
	var count := 22
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		if count == 0:
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in count:
			var seed := float(i) * 12.9898
			var speed := 0.05 + 0.05 * fposmod(sin(seed) * 43758.5, 1.0)
			var ph := fposmod(_t * speed + fposmod(sin(seed * 1.7) * 9631.1, 1.0), 1.0)
			var x := fposmod(sin(seed * 2.3) * 2371.7, 1.0) * size.x + sin(_t * 0.7 + i) * 18.0
			var y := size.y * (1.05 - ph * 0.75)
			var a := sin(ph * PI) * (0.55 + 0.45 * sin(_t * 3.0 + i * 1.3))
			var gold := i % 3 != 0
			var col := Color(1.0, 0.86, 0.5) if gold else Color(0.6, 0.95, 1.0)
			var r := 2.0 + 2.5 * fposmod(sin(seed * 3.1) * 513.3, 1.0)
			draw_circle(Vector2(x, y), r * 3.2, Color(col, 0.12 * a), true, -1, true)
			draw_circle(Vector2(x, y), r, Color(col, 0.9 * a), true, -1, true)
