extends Control
## Collection: discovered decorations (toggle on the island) and achievements.

var _list: VBoxContainer
var _tab := "decor"
var _tab_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Backdrop.new())
	var margin := UI.safe_margin(self, 22)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	var back := UI.round_button("back", UI.t("BACK"))
	back.name = "BackButton"
	back.pressed.connect(func(): Router.go("menu"))
	top.add_child(back)
	var title := UI.label(UI.t("COLLECTION"), "HeadingLabel", 44)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	col.add_child(tabs)
	for key in ["decor", "achievements"]:
		var b := UI.button(UI.t("TAB_DECOR") if key == "decor" else UI.t("TAB_ACHIEVEMENTS"), "", "SecondaryButton", Vector2(0, 80))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.toggle_mode = true
		b.name = "Tab_" + key
		b.pressed.connect(func(): _select(key))
		tabs.add_child(b)
		_tab_buttons[key] = b
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 12)
	scroll.add_child(_list)
	_select("decor")


func _select(key: String) -> void:
	_tab = key
	for k in _tab_buttons:
		_tab_buttons[k].button_pressed = k == key
		_tab_buttons[k].theme_type_variation = "PrimaryButton" if k == key else "SecondaryButton"
	for c in _list.get_children():
		c.queue_free()
	if key == "decor":
		_fill_decor()
	else:
		_fill_achievements()


func _fill_decor() -> void:
	var prog := Game.progression
	var unlock_level := {}
	for lid in Game.content.level_order:
		var d: String = Game.content.get_level(lid).rewards.get("discovery", "")
		if d != "":
			unlock_level[d] = lid
	for id in Game.content.decoration_order:
		var d: Dictionary = Game.content.decorations[id]
		var have := prog.has_discovery(id)
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		var preview := DecorPreview.new()
		preview.kind = d["kind"]
		preview.locked = not have
		preview.custom_minimum_size = Vector2(110, 110)
		row.add_child(preview)
		var txt := VBoxContainer.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		txt.add_child(UI.label(tr(d["name"]) if have else UI.t("UNDISCOVERED"), "HeadingLabel", 30))
		if have:
			txt.add_child(UI.label(tr(d.get("description", "")), "CaptionLabel", 24))
			var toggle := CheckButton.new()
			toggle.text = UI.t("SHOW_ON_ISLAND")
			toggle.button_pressed = prog.is_decoration_visible(id)
			toggle.name = "Show_" + id
			toggle.toggled.connect(func(on): Game.set_decoration_visible(id, on))
			txt.add_child(toggle)
		elif unlock_level.has(id):
			txt.add_child(UI.label(UI.t("UNLOCK_BY_LEVEL") % Game.content.level_number(unlock_level[id]), "CaptionLabel", 24))
		_list.add_child(card)


func _fill_achievements() -> void:
	var prog := Game.progression
	for a in Game.content.achievements:
		var have: bool = prog.p["achievements"].has(a["id"])
		var card := PanelContainer.new()
		card.theme_type_variation = "Card"
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		card.add_child(row)
		row.add_child(UI.icon("trophy", Palette.SUN_EDGE if have else Color("d7e0dc"), 56))
		var txt := VBoxContainer.new()
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(txt)
		txt.add_child(UI.label(tr(a["name"]), "HeadingLabel", 30))
		txt.add_child(UI.label(tr(a["description"]), "CaptionLabel", 24))
		if not have:
			var pr := prog.achievement_progress(a)
			var bar := ProgressBar.new()
			bar.max_value = pr.y
			bar.value = pr.x
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(0, 12)
			bar.add_theme_stylebox_override("background", ThemeBuilder.box(Palette.SAND_SHADE, 6, 0, Color.TRANSPARENT, 0, 0, 0))
			bar.add_theme_stylebox_override("fill", ThemeBuilder.box(Palette.WATER, 6, 0, Color.TRANSPARENT, 0, 0, 0))
			txt.add_child(bar)
		_list.add_child(card)


class DecorPreview extends Control:
	var kind := ""
	var locked := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		draw_circle(c, size.x * 0.48, Color("eaf5f1") if not locked else Color("eef1f0"), true, -1, true)
		Painter.ellipse(self, c + Vector2(0, size.y * 0.28), size.x * 0.36, size.y * 0.1, Color("8cc56a") if not locked else Color("dfe5e2"))
		if locked:
			var tex := IconGlyph.texture_for("lock")
			draw_texture_rect(tex, Rect2(c - Vector2(24, 26), Vector2(48, 48)), false, Color("b8c5c0"))
			return
		Painter.decoration(self, kind, c + Vector2(0, size.y * 0.3), size.x * 0.7, _t)
