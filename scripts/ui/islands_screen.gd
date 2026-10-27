extends Control
## The archipelago: one card per island (its game, progress, lock state) and,
## for an island with its own puzzle game, the grid of its 30 levels.

var _list: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Backdrop.new())
	var margin := UI.safe_margin(self, 22)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	var back := UI.round_button("back", UI.t("BACK"))
	back.name = "BackButton"
	back.pressed.connect(func(): Router.go("menu"))
	top.add_child(back)
	var title := UI.label(UI.t("ARCHIPELAGO"), "HeadingLabel", 44)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 14)
	sc.add_child(_list)
	var open: String = Router.params.get("island", "")
	if open != "" and Game.island_unlocked(open):
		_show_levels(open)
	else:
		_show_islands()


func _clear() -> void:
	for c in _list.get_children():
		c.queue_free()


func _show_islands() -> void:
	_clear()
	var n := 0
	for isl in Game.islands():
		n += 1
		_list.add_child(_island_card(isl, n))


func _island_card(isl: Dictionary, n: int) -> Control:
	var id: String = isl["id"]
	var unlocked := Game.island_unlocked(id)
	var p := PanelContainer.new()
	p.name = "Island_" + id
	p.theme_type_variation = "Card"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(96, 96)
	badge.add_theme_stylebox_override("panel", ThemeBuilder.box(Color(str(isl.get("color", "888888"))) if unlocked else Palette.DISABLED, 48, 0, Color.TRANSPARENT, 0, 0, 0))
	var num := UI.label(str(n), "HeadingLabel", 44, HORIZONTAL_ALIGNMENT_CENTER)
	num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	num.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(num)
	row.add_child(badge)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	row.add_child(v)
	v.add_child(UI.label(tr(isl["name"]), "HeadingLabel", 34))
	v.add_child(UI.label(tr(isl.get("game_name", "")), "CaptionLabel", 22))
	var status := ""
	if isl.get("coming_soon", false):
		status = UI.t("COMING_SOON")
	elif not unlocked:
		status = UI.t("ISLAND_LOCKED_CAFE")
	elif id == "verdant":
		status = UI.t("LEVELS_DONE") % [Game.progression.completed_count(), Game.content.level_order.size()]
	else:
		status = UI.t("LEVELS_DONE") % [(Game.island_progress(id)["completed"] as Dictionary).size(), Game.island_levels(id).size()]
	v.add_child(UI.label(status, "KickerLabel", 22))
	if unlocked:
		var go := UI.button(UI.t("PLAY"), "play", "PrimaryButton", Vector2(150, 84))
		go.name = "Go_" + id
		go.pressed.connect(func():
			if id == "verdant":
				Router.go("island")
			else:
				_show_levels(id))
		row.add_child(go)
	else:
		row.add_child(UI.icon("lock", Palette.INK_SOFT, 44))
	return p


func _show_levels(id: String) -> void:
	_clear()
	var isl := Game.island(id)
	var head := HBoxContainer.new()
	_list.add_child(head)
	var back := UI.button(UI.t("ARCHIPELAGO"), "back", "SecondaryButton", Vector2(0, 76))
	back.pressed.connect(_show_islands)
	head.add_child(back)
	_list.add_child(UI.label(tr(isl["name"]), "HeadingLabel", 40, HORIZONTAL_ALIGNMENT_CENTER))
	_list.add_child(UI.label(tr(isl.get("game_name", "")), "CaptionLabel", 24, HORIZONTAL_ALIGNMENT_CENTER))
	if isl.has("merge_location"):
		var mloc: Dictionary = isl["merge_location"]
		var lid := str(mloc["id"])
		var open := Game.merge_location_unlocked(lid)
		var mb := UI.button(tr(str(mloc["name"])) if open else UI.t("LOCATION_LOCKED") % tr(str(mloc["name"])), "home" if open else "lock",
			"PrimaryButton" if open else "SecondaryButton", Vector2(0, 90))
		mb.name = "Location_" + lid
		mb.disabled = not open
		mb.pressed.connect(func(): Router.go("merge", {"location": lid}))
		_list.add_child(mb)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list.add_child(grid)
	var levels := Game.island_levels(id)
	var done: Dictionary = Game.island_progress(id)["completed"]
	for i in levels.size():
		var lv: Dictionary = levels[i]
		var b := Button.new()
		b.name = "Level_%d" % (i + 1)
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(112, 112)
		var unlocked := Game.island_level_unlocked(id, i)
		b.theme_type_variation = "PrimaryButton" if unlocked and not done.has(lv["id"]) else "SecondaryButton"
		b.disabled = not unlocked
		if done.has(lv["id"]):
			b.add_theme_constant_override("content_margin_bottom", 30)
			var stars := HBoxContainer.new()
			stars.alignment = BoxContainer.ALIGNMENT_CENTER
			stars.add_theme_constant_override("separation", 0)
			stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stars.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			stars.position = Vector2(14, 70)
			stars.size = Vector2(84, 28)
			for k in 3:
				stars.add_child(UI.icon("star", Palette.SUN if k < int(done[lv["id"]].get("stars", 1)) else Palette.MUTED, 26))
			b.add_child(stars)
			var sb: StyleBox = ThemeBuilder.build().get_stylebox("normal", "SecondaryButton").duplicate()
			sb.content_margin_bottom = 40
			b.add_theme_stylebox_override("normal", sb)
		b.pressed.connect(func(): Router.go("slide", {"level_id": lv["id"]}))
		grid.add_child(b)
