extends Control
## Island screen: shows the restored world, plays pending restoration after a
## level, lets the player pick an area, replay levels and awaken new areas.

var view: IslandView
var _panel_title: Label
var _panel_progress: ProgressBar
var _panel_percent: Label
var _levels_row: HBoxContainer
var _primary: Button
var _status: Label
var _toast: PanelContainer
var _toast_label: Label
var _area := ""
var _animating := false
var _toast_tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Backdrop.new())
	_build_ui()
	Audio.play_music()
	_area = _default_area()
	view.selected_area = _area
	var receipt: Dictionary = Game.pending_receipt
	Game.pending_receipt = {}
	if not receipt.is_empty() and not receipt.get("restoration", []).is_empty():
		_play_restoration(receipt)
	else:
		_refresh_panel()


func _default_area() -> String:
	var next := Game.progression.next_level_id()
	if next != "":
		var a: String = Game.content.get_level(next).area
		if Game.progression.is_area_unlocked(a):
			return a
		# next level is behind a locked area: focus that area so the unlock is offered
		return a
	return Game.content.area_order[-1]


func _build_ui() -> void:
	var margin := UI.safe_margin(self, 22)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	var home := UI.button("", "back", "GhostButton", Vector2(84, 84))
	home.name = "MenuButton"
	if "accessibility_name" in home:
		home.set("accessibility_name", UI.t("MENU"))
	home.pressed.connect(func(): Router.go("menu"))
	top.add_child(home)
	var title := UI.label(tr(Game.content.worlds[0].get("name", "")), "LightLabel", 40)
	title.add_theme_font_override("font", ThemeBuilder.font_black())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top.add_child(title)
	top.add_child(UI.essence_chip())

	view = IslandView.new()
	view.name = "IslandView"
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(view)
	view.area_selected.connect(_on_area_selected)

	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	col.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_panel_title = UI.label("", "HeadingLabel", 38)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_panel_title)
	_panel_percent = UI.label("", "CaptionLabel", 26)
	_panel_percent.autowrap_mode = TextServer.AUTOWRAP_OFF
	head.add_child(_panel_percent)
	_panel_progress = ProgressBar.new()
	_panel_progress.show_percentage = false
	_panel_progress.custom_minimum_size = Vector2(0, 16)
	_panel_progress.max_value = 1.0
	_panel_progress.add_theme_stylebox_override("background", ThemeBuilder.box(Palette.SAND_SHADE, 8, 0, Color.TRANSPARENT, 0, 0, 0))
	_panel_progress.add_theme_stylebox_override("fill", ThemeBuilder.box(Palette.LEAF, 8, 0, Color.TRANSPARENT, 0, 0, 0))
	v.add_child(_panel_progress)
	_levels_row = HBoxContainer.new()
	_levels_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_levels_row.add_theme_constant_override("separation", 12)
	v.add_child(_levels_row)
	_status = UI.label("", "CaptionLabel", 24, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_status)
	_primary = UI.button("", "play", "PrimaryButton", Vector2(0, 104))
	_primary.name = "PrimaryButton"
	_primary.pressed.connect(_on_primary)
	v.add_child(_primary)
	# toast floats over the island, below the top bar
	var toast_holder := CenterContainer.new()
	toast_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_holder.offset_top = 140
	toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_holder)
	_toast = PanelContainer.new()
	_toast.theme_type_variation = "DarkCard"
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.custom_minimum_size = Vector2(420, 0)
	_toast_label = UI.label("", "LightLabel", 28, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_child(_toast_label)
	toast_holder.add_child(_toast)


func _on_area_selected(area_id: String) -> void:
	if _animating:
		return
	Audio.play("ui_click")
	_area = area_id
	_refresh_panel()


func _refresh_panel() -> void:
	var prog := Game.progression
	var area: Dictionary = Game.content.areas[_area]
	view.selected_area = _area
	_panel_title.text = tr(area["name"])
	var pct := prog.area_progress(_area)
	_panel_progress.value = pct
	_panel_percent.text = UI.t("PERCENT_RESTORED") % int(round(pct * 100))
	for c in _levels_row.get_children():
		c.queue_free()
	var unlocked := prog.is_area_unlocked(_area)
	for lid in area["levels"]:
		_levels_row.add_child(_level_button(lid, unlocked))
	_primary.disabled = false
	_status.text = ""
	if not unlocked:
		var chk := prog.can_unlock_area(_area)
		var cost := int(area.get("cost", 0))
		_primary.text = UI.t("AWAKEN_AREA") % cost
		_primary.set_meta("action", "unlock")
		if not chk["ok"]:
			_primary.disabled = true
			match chk["reason"]:
				"previous_area":
					_status.text = UI.t("LOCK_PREVIOUS")
				"essence":
					_status.text = UI.t("LOCK_ESSENCE") % int(chk.get("missing", 0))
		else:
			_status.text = UI.t("AWAKEN_HINT")
		return
	var next := ""
	for lid in area["levels"]:
		if not prog.is_completed(lid):
			next = lid
			break
	if next != "":
		_primary.text = UI.t("PLAY_LEVEL") % Game.content.level_number(next)
		_primary.set_meta("action", "play")
		_primary.set_meta("level", next)
		_primary.disabled = not prog.is_level_unlocked(next)
		if _primary.disabled:
			_status.text = UI.t("LOCK_PREVIOUS")
		return
	# area finished: point at whatever comes next
	var global_next := prog.next_level_id()
	if global_next == "":
		_primary.text = UI.t("ALL_RESTORED")
		_primary.set_meta("action", "none")
		_primary.disabled = true
		_status.text = UI.t("ALL_RESTORED_HINT")
	else:
		var next_area: String = Game.content.get_level(global_next).area
		_primary.text = UI.t("GO_TO_AREA") % tr(Game.content.areas[next_area]["name"])
		_primary.set_meta("action", "select")
		_primary.set_meta("area", next_area)
		_status.text = UI.t("AREA_RESTORED")


func _level_button(lid: String, area_unlocked: bool) -> Button:
	var prog := Game.progression
	var n := Game.content.level_number(lid)
	var done := prog.is_completed(lid)
	var open := area_unlocked and prog.is_level_unlocked(lid)
	var b := Button.new()
	b.custom_minimum_size = Vector2(92, 92)
	b.theme_type_variation = "PrimaryButton" if (open and not done) else "SecondaryButton"
	b.text = str(n)
	b.disabled = not open
	b.name = "Level%d" % n
	if "accessibility_name" in b:
		var state := UI.t("STATE_DONE") if done else (UI.t("STATE_OPEN") if open else UI.t("STATE_LOCKED"))
		b.set("accessibility_name", "%s %d, %s" % [UI.t("LEVEL"), n, state])
	if done:
		var stars := prog.optional_met_count(lid)
		var lvl := Game.content.get_level(lid)
		var badge := UI.icon("check" if stars < lvl.optional.size() else "star", Palette.LEAF_DARK if stars < lvl.optional.size() else Palette.GOLD_DEEP, 24)
		badge.position = Vector2(62, 6)
		b.add_child(badge)
	b.pressed.connect(func():
		Audio.play("ui_click")
		Router.go("gameplay", {"level_id": lid}))
	return b


func _on_primary() -> void:
	match _primary.get_meta("action", ""):
		"play":
			Router.go("gameplay", {"level_id": _primary.get_meta("level")})
		"unlock":
			if Game.unlock_area(_area):
				Audio.play("unlock")
				Game.haptic(25)
				_animating = true
				_primary.disabled = true
				await view.animate_area_unlock(_area, 0.3 if Game.reduced_motion() else 1.4)
				_animating = false
				_show_toast(UI.t("AREA_AWAKENED") % tr(Game.content.areas[_area]["name"]))
				_refresh_panel()
		"select":
			_area = _primary.get_meta("area")
			_refresh_panel()


func _play_restoration(receipt: Dictionary) -> void:
	_animating = true
	var lvl := Game.content.get_level(receipt["level"])
	_area = lvl.area
	view.selected_area = _area
	# start from the pre-level state, then grow into the saved state
	for ch in receipt["restoration"]:
		view.display_stage[ch["object"]] = float(ch["from"])
	_refresh_panel()
	_primary.disabled = true
	var reduced := Game.reduced_motion()
	await get_tree().create_timer(0.1 if reduced else 0.45).timeout
	for ch in receipt["restoration"]:
		var o: Dictionary = Game.content.objects[ch["object"]]
		_show_toast(UI.t("RESTORING") % tr(o.get("name", "")))
		Audio.play("bloom")
		Game.haptic(15)
		await view.animate_object(ch["object"], float(ch["to"]), 0.3 if reduced else 1.5)
	var msgs: Array[String] = []
	for d in receipt.get("discoveries", []):
		msgs.append(UI.t("NEW_DISCOVERY") % tr(Game.content.decorations[d]["name"]))
	if Game.progression.area_restored(_area):
		msgs.append(UI.t("AREA_FULLY_RESTORED") % tr(Game.content.areas[_area]["name"]))
		Audio.play("unlock")
	if lvl.tutorial == "milestone":
		msgs.append(UI.t("TUT_MILESTONE"))
	if not msgs.is_empty():
		_show_toast("\n".join(msgs), 4.0)
	_animating = false
	view.sync_from_progress()
	# After the area is complete, steer the panel towards the next area.
	var next := Game.progression.next_level_id()
	if next != "" and Game.progression.area_complete(_area):
		_area = Game.content.get_level(next).area
	_refresh_panel()


func _show_toast(text: String, hold: float = 1.6) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 0.0
	if _toast_tween:
		_toast_tween.kill()
	var tw := create_tween()
	_toast_tween = tw
	tw.tween_property(_toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(hold)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func(): _toast.visible = false)
