class_name UI
extends RefCounted
## Small factory helpers so every screen builds consistent widgets.


static func label(text: String, variation: String = "", size: int = 0, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Button with a vector icon and optional text. `variation` is a theme type.
static func button(text: String, icon_kind: String = "", variation: String = "SecondaryButton",
		min_size := Vector2(0, 92)) -> Button:
	var b := Button.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.text = text
	if "accessibility_name" in b:
		b.set("accessibility_name", text if text != "" else icon_kind)
	if icon_kind != "":
		# Read from the LUMA theme directly: the button is not in the tree yet,
		# so get_theme_*() would resolve against the engine default theme.
		var theme := ThemeBuilder.build()
		var fg: Color = theme.get_color("font_color", variation)
		var glyph := IconGlyph.new()
		glyph.kind = icon_kind
		glyph.color = fg
		glyph.custom_minimum_size = Vector2(34, 34)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(glyph)
		if text == "":
			glyph.set_anchors_preset(Control.PRESET_CENTER)
			glyph.position = -glyph.custom_minimum_size * 0.5
			glyph.size = glyph.custom_minimum_size
		else:
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("h_separation", 0)
			# icon sits left of the centred text; leave room for it
			var pad := theme.get_stylebox("normal", variation).content_margin_left
			for st in ["normal", "hover", "pressed", "disabled", "focus"]:
				var sb: StyleBox = theme.get_stylebox(st, variation).duplicate()
				sb.content_margin_left = pad + 46
				b.add_theme_stylebox_override(st, sb)
			glyph.set_anchors_preset(Control.PRESET_CENTER_LEFT)
			glyph.position = Vector2(pad, -17)
			glyph.size = Vector2(34, 34)
	b.pressed.connect(func(): Audio.play("ui_click"))
	return b


static func icon(kind: String, color: Color, size := 34.0) -> IconGlyph:
	var g := IconGlyph.new()
	g.kind = kind
	g.color = color
	g.custom_minimum_size = Vector2(size, size)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func essence_chip() -> PanelContainer:
	return EssenceChip.new()


## Root margin container that respects device safe areas plus a base gutter.
static func safe_margin(root: Control, base := 24) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(m)
	var apply := func():
		var vp := root.get_viewport()
		if vp == null:
			return
		var full := vp.get_visible_rect()
		var safe := PlatformServices.safe_area_rect(vp)
		m.add_theme_constant_override("margin_left", int(base + safe.position.x - full.position.x))
		m.add_theme_constant_override("margin_top", int(base + safe.position.y - full.position.y))
		m.add_theme_constant_override("margin_right", int(base + full.end.x - safe.end.x))
		m.add_theme_constant_override("margin_bottom", int(base + full.end.y - safe.end.y))
	apply.call()
	root.get_viewport().size_changed.connect(apply)
	return m


static func spacer(h: float = 0.0, expand := false) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func t(key: String) -> String:
	return TranslationServer.translate(key)
