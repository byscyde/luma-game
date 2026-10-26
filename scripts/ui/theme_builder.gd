class_name ThemeBuilder
extends RefCounted
## Global UI theme built in code. Light lagoon palette, tactile buttons (a
## darker bottom edge that compresses when pressed), white cards with soft
## shadows, Fredoka headings + Nunito body.
## Variations: PrimaryButton, SecondaryButton, GhostButton (round/white icon
## buttons), Card, Sheet, ChipPanel, DarkCard (callouts), TitleLabel,
## HeadingLabel, CaptionLabel, LightLabel, LightCaption, KickerLabel.

const FONT_BOLD := "res://assets/fonts/nunito-latin-700-normal.woff2"
const FONT_BLACK := "res://assets/fonts/nunito-latin-800-normal.woff2"
const FONT_DISPLAY := "res://assets/fonts/fredoka-latin-600-normal.woff2"

static var _cache: Theme


static func font_bold() -> Font:
	return load(FONT_BOLD)


static func font_black() -> Font:
	return load(FONT_DISPLAY)


static func font_display() -> Font:
	return load(FONT_DISPLAY)


static func box(bg: Color, radius: int = 24, shadow: int = 0, border: Color = Color.TRANSPARENT,
		border_w: int = 0, pad_h: int = 24, pad_v: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 12
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_color = Color(0.08, 0.2, 0.2, 0.16)
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.45)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


## Tactile button face: coloured top with a darker bottom edge.
static func button_box(face: Color, edge: Color, radius: int, pressed := false, pad_h := 30, pad_v := 16) -> StyleBoxFlat:
	var s := box(face, radius, 0 if pressed else 8, Color.TRANSPARENT, 0, pad_h, pad_v)
	s.border_color = edge
	s.border_width_bottom = 2 if pressed else 7
	if pressed:
		s.content_margin_top = pad_v + 5
		s.expand_margin_top = -5
	return s


static func build() -> Theme:
	if _cache:
		return _cache
	var t := Theme.new()
	t.default_font = font_bold()
	t.default_font_size = 30

	_button(t, "Button", Palette.PAPER, Palette.MINT_EDGE, Palette.INK, 30, 30)
	_button(t, "PrimaryButton", Palette.SUN, Palette.SUN_EDGE, Palette.SUN_INK, 36, 34)
	_button(t, "SecondaryButton", Palette.PAPER, Palette.MINT_EDGE, Palette.INK, 30, 30)
	_button(t, "GhostButton", Palette.PAPER, Palette.MINT_EDGE, Palette.INK, 44, 28)
	for v in ["PrimaryButton", "SecondaryButton", "GhostButton"]:
		t.set_type_variation(v, "Button")
	for v in ["PrimaryButton", "SecondaryButton", "GhostButton", "Button"]:
		t.set_font("font", v, font_display())

	t.set_stylebox("panel", "PanelContainer", box(Palette.PAPER, 36, 18, Color.TRANSPARENT, 0, 30, 26))
	for v in ["Card", "Sheet", "ChipPanel", "DarkCard"]:
		t.set_type_variation(v, "PanelContainer")
	t.set_stylebox("panel", "Card", box(Palette.PAPER, 40, 22, Color.TRANSPARENT, 0, 34, 30))
	var sheet := box(Palette.SHEET, 44, 24, Color.TRANSPARENT, 0, 34, 30)
	t.set_stylebox("panel", "Sheet", sheet)
	t.set_stylebox("panel", "ChipPanel", box(Color(1, 1, 1, 0.9), 26, 6, Color.TRANSPARENT, 0, 18, 9))
	t.set_stylebox("panel", "DarkCard", box(Color(1, 1, 1, 0.95), 30, 12, Color.TRANSPARENT, 0, 28, 18))

	t.set_color("font_color", "Label", Palette.INK)
	for v in ["TitleLabel", "HeadingLabel", "CaptionLabel", "LightLabel", "LightCaption", "KickerLabel"]:
		t.set_type_variation(v, "Label")
	t.set_font("font", "TitleLabel", font_display())
	t.set_font_size("font_size", "TitleLabel", 120)
	t.set_color("font_color", "TitleLabel", Color.WHITE)
	t.set_color("font_shadow_color", "TitleLabel", Color(0.05, 0.3, 0.33, 0.45))
	t.set_constant("shadow_offset_y", "TitleLabel", 6)
	t.set_constant("shadow_outline_size", "TitleLabel", 10)
	t.set_font("font", "HeadingLabel", font_display())
	t.set_font_size("font_size", "HeadingLabel", 42)
	t.set_color("font_color", "HeadingLabel", Palette.INK)
	t.set_font_size("font_size", "CaptionLabel", 24)
	t.set_color("font_color", "CaptionLabel", Palette.INK_SOFT)
	t.set_color("font_color", "LightLabel", Palette.INK)
	t.set_font_size("font_size", "LightCaption", 24)
	t.set_color("font_color", "LightCaption", Palette.INK_SOFT)
	t.set_font("font", "KickerLabel", font_bold())
	t.set_font_size("font_size", "KickerLabel", 22)
	t.set_color("font_color", "KickerLabel", Palette.TEAL)

	# Progress bars
	t.set_stylebox("background", "ProgressBar", box(Color("e4efeb"), 10, 0, Color.TRANSPARENT, 0, 0, 0))
	t.set_stylebox("fill", "ProgressBar", box(Palette.TEAL, 10, 0, Color.TRANSPARENT, 0, 0, 0))

	# Sliders / toggles
	t.set_stylebox("slider", "HSlider", box(Color("e4efeb"), 10, 0, Color.TRANSPARENT, 0, 0, 7))
	var fill := box(Palette.TEAL, 10, 0, Color.TRANSPARENT, 0, 0, 7)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot_texture(44, Palette.PAPER, Palette.TEAL))
	t.set_icon("grabber_highlight", "HSlider", _dot_texture(48, Palette.PAPER, Palette.TEAL))
	t.set_icon("checked", "CheckButton", _switch_texture(true))
	t.set_icon("unchecked", "CheckButton", _switch_texture(false))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(k, "CheckButton", Palette.INK)
	for st in ["normal", "pressed", "hover", "hover_pressed", "focus"]:
		t.set_stylebox(st, "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_cache = t
	return t


static func _button(t: Theme, type: String, face: Color, edge: Color, fg: Color, radius: int, size: int) -> void:
	t.set_stylebox("normal", type, button_box(face, edge, radius))
	t.set_stylebox("hover", type, button_box(face.lightened(0.04), edge, radius))
	t.set_stylebox("pressed", type, button_box(face.darkened(0.05), edge, radius, true))
	t.set_stylebox("hover_pressed", type, button_box(face.darkened(0.05), edge, radius, true))
	var dis := button_box(Palette.DISABLED, Palette.DISABLED.darkened(0.06), radius)
	dis.shadow_size = 0
	t.set_stylebox("disabled", type, dis)
	var focus := box(Color.TRANSPARENT, radius + 4, 0, Palette.TEAL, 4, 30, 16)
	focus.expand_margin_left = 4
	focus.expand_margin_right = 4
	focus.expand_margin_top = 4
	focus.expand_margin_bottom = 4
	t.set_stylebox("focus", type, focus)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, type, fg)
	t.set_color("font_disabled_color", type, Color(Palette.INK_SOFT, 0.55))
	t.set_font_size("font_size", type, size)


static func _dot_texture(d: int, c: Color, ring: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			var col := ring if dist > r - 5 else c
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


static func _switch_texture(on: bool) -> ImageTexture:
	var w := 92
	var h := 52
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Palette.TEAL if on else Color("d9e4e0")
	var r := h / 2.0
	for y in h:
		for x in w:
			var cx := clampf(x + 0.5, r, w - r)
			var dist := Vector2(x + 0.5 - cx, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			var col := bg
			var knob_x := w - r if on else r
			var kd := Vector2(x + 0.5 - knob_x, y + 0.5 - r).length()
			if kd < r - 5:
				col = Color.WHITE
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)
