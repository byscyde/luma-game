class_name ThemeBuilder
extends RefCounted
## Builds the global UI theme in code (fonts, buttons, panels, sliders).
## Variations: PrimaryButton, SecondaryButton, GhostButton, Card, TitleLabel,
## HeadingLabel, CaptionLabel, ChipPanel.

const FONT_BOLD := "res://assets/fonts/nunito-latin-700-normal.woff2"
const FONT_BLACK := "res://assets/fonts/nunito-latin-800-normal.woff2"

static var _cache: Theme


static func font_bold() -> Font:
	return load(FONT_BOLD)


static func font_black() -> Font:
	return load(FONT_BLACK)


static func box(bg: Color, radius: int = 24, shadow: int = 0, border: Color = Color.TRANSPARENT,
		border_w: int = 0, pad_h: int = 24, pad_v: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.corner_detail = 10
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_color = Palette.SHADOW
		s.shadow_size = shadow
		s.shadow_offset = Vector2(0, shadow * 0.6)
	if border_w > 0:
		s.border_color = border
		s.set_border_width_all(border_w)
	s.content_margin_left = pad_h
	s.content_margin_right = pad_h
	s.content_margin_top = pad_v
	s.content_margin_bottom = pad_v
	return s


static func build() -> Theme:
	if _cache:
		return _cache
	var t := Theme.new()
	t.default_font = font_bold()
	t.default_font_size = 30

	# Base button = secondary (cream)
	_button(t, "Button", Palette.CREAM, Palette.TEXT, 30)
	_button(t, "PrimaryButton", Palette.GOLD, Palette.TEXT, 34)
	_button(t, "SecondaryButton", Palette.CREAM, Palette.TEXT, 30)
	_button(t, "GhostButton", Color(1, 1, 1, 0.14), Palette.TEXT_LIGHT, 28)
	for v in ["PrimaryButton", "SecondaryButton", "GhostButton"]:
		t.set_type_variation(v, "Button")
	t.set_font("font", "PrimaryButton", font_black())

	t.set_stylebox("panel", "PanelContainer", box(Color(Palette.CREAM, 0.97), 32, 10, Color.TRANSPARENT, 0, 28, 24))
	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", box(Color(Palette.CREAM, 0.97), 32, 12, Color.TRANSPARENT, 0, 32, 28))
	t.set_type_variation("ChipPanel", "PanelContainer")
	t.set_stylebox("panel", "ChipPanel", box(Color(1, 1, 1, 0.16), 22, 0, Color.TRANSPARENT, 0, 18, 8))
	t.set_type_variation("DarkCard", "PanelContainer")
	t.set_stylebox("panel", "DarkCard", box(Color(Palette.NIGHT, 0.82), 28, 8, Color.TRANSPARENT, 0, 26, 18))

	t.set_color("font_color", "Label", Palette.TEXT)
	for v in ["TitleLabel", "HeadingLabel", "CaptionLabel", "LightLabel", "LightCaption"]:
		t.set_type_variation(v, "Label")
	t.set_font("font", "TitleLabel", font_black())
	t.set_font_size("font_size", "TitleLabel", 92)
	t.set_color("font_color", "TitleLabel", Palette.TEXT_LIGHT)
	t.set_color("font_shadow_color", "TitleLabel", Color(0, 0, 0, 0.25))
	t.set_constant("shadow_offset_y", "TitleLabel", 5)
	t.set_font("font", "HeadingLabel", font_black())
	t.set_font_size("font_size", "HeadingLabel", 40)
	t.set_font_size("font_size", "CaptionLabel", 24)
	t.set_color("font_color", "CaptionLabel", Palette.TEXT_SOFT)
	t.set_color("font_color", "LightLabel", Palette.TEXT_LIGHT)
	t.set_font_size("font_size", "LightCaption", 24)
	t.set_color("font_color", "LightCaption", Color(Palette.TEXT_LIGHT, 0.8))

	# Sliders / checkboxes
	var track := box(Palette.SAND_SHADE, 8, 0, Color.TRANSPARENT, 0, 0, 6)
	t.set_stylebox("slider", "HSlider", track)
	var fill := box(Palette.WATER, 8, 0, Color.TRANSPARENT, 0, 0, 6)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_icon("grabber", "HSlider", _dot_texture(36, Palette.WATER_DEEP))
	t.set_icon("grabber_highlight", "HSlider", _dot_texture(40, Palette.WATER_DEEP))
	t.set_icon("checked", "CheckButton", _switch_texture(true))
	t.set_icon("unchecked", "CheckButton", _switch_texture(false))
	t.set_color("font_color", "CheckButton", Palette.TEXT)
	t.set_color("font_hover_color", "CheckButton", Palette.TEXT)
	t.set_color("font_pressed_color", "CheckButton", Palette.TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Palette.TEXT)
	t.set_color("font_focus_color", "CheckButton", Palette.TEXT)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover_pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	_cache = t
	return t


static func _button(t: Theme, type: String, bg: Color, fg: Color, size: int) -> void:
	t.set_stylebox("normal", type, box(bg, 30, 6, Color.TRANSPARENT, 0, 30, 18))
	t.set_stylebox("hover", type, box(bg.lightened(0.06), 30, 7, Color.TRANSPARENT, 0, 30, 18))
	var pressed := box(bg.darkened(0.1), 30, 2, Color.TRANSPARENT, 0, 30, 18)
	pressed.content_margin_top = 20
	pressed.content_margin_bottom = 16
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("disabled", type, box(Color(bg.darkened(0.15), 0.55), 30, 0, Color.TRANSPARENT, 0, 30, 18))
	t.set_stylebox("focus", type, box(Color.TRANSPARENT, 30, 0, Palette.WATER_DEEP, 4, 30, 18))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(k, type, fg)
	t.set_color("font_disabled_color", type, Color(fg, 0.5))
	t.set_font_size("font_size", type, size)


static func _dot_texture(d: int, c: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dist := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - dist, 0.0, 1.0)
			var col := c if dist < r - 4 else Color.WHITE
			img.set_pixel(x, y, Color(col, a))
	return ImageTexture.create_from_image(img)


static func _switch_texture(on: bool) -> ImageTexture:
	var w := 84
	var h := 48
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var bg := Palette.LEAF if on else Palette.SAND_SHADE
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
