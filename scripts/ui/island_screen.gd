extends Control
## Island screen: the 3D island fills the screen; a floating top bar and a
## bottom sheet show the selected area, its levels and the next action.
## Plays pending restoration after a level, offers area awakening.

const SHEET_H := 400.0

var view: IslandView
var _panel_title: Label
var _panel_kicker: Label
var _panel_progress: ProgressBar
var _panel_percent: Label
var _levels_row: HBoxContainer
var _primary: Button
var _status: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
var _area := ""
var _animating := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view = IslandView.new()
	view.name = "IslandView"
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.top_inset = 150.0
	view.bottom_inset = SHEET_H
	add_child(view)
	view.area_selected.connect(_on_area_selected)
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
		return Game.content.get_level(next).area
	return Game.content.area_order[-1]


func _build_ui() -> void:
	var margin := UI.safe_margin(self, 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	var home := UI.round_button("home", UI.t("MENU"))
	home.name = "MenuButton"
	home.pressed.connect(func(): Router.go("menu"))
	top.add_child(home)
	var title_chip := PanelContainer.new()
	title_chip.theme_type_variation = "ChipPanel"
	title_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := UI.label(tr(Game.content.worlds[0].get("name", "")), "HeadingLabel", 32)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_chip.add_child(title)
	top.add_child(title_chip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(spacer)
	top.add_child(UI.essence_chip())
	col.add_child(UI.spacer(0, true))

	var sheet := PanelContainer.new()
	sheet.theme_type_variation = "Sheet"
	sheet.custom_minimum_size = Vector2(0, SHEET_H - 40)
	col.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	sheet.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	_panel_kicker = UI.label("", "KickerLabel")
	titles.add_child(_panel_kicker)
	_panel_title = UI.label("", "HeadingLabel", 40)
	titles.add_child(_panel_title)
	_panel_percent = UI.label("", "CaptionLabel", 24)
	_panel_percent.autowrap_mode = TextServer.AUTOWRAP_OFF
	_panel_percent.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	head.add_child(_panel_percent)
	_panel_progress = ProgressBar.new()
	_panel_progress.show_percentage = false
	_panel_progress.custom_minimum_size = Vector2(0, 18)
	_panel_progress.max_value = 1.0
	v.add_child(_panel_progress)
	_levels_row = HBoxContainer.new()
	_levels_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_levels_row.add_theme_constant_override("separation", 14)
	v.add_child(_levels_row)
	_status = UI.label("", "CaptionLabel", 23, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(_status)
	_primary = UI.button("", "play", "PrimaryButton", Vector2(0, 108))
	_primary.name = "PrimaryButton"
	_primary.pressed.connect(_on_primary)
	v.add_child(_primary)

	var toast_holder := CenterContainer.new()
	toast_holder.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_holder.offset_top = 150
	toast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_holder)
	_toast = PanelContainer.new()
	_toast.theme_type_variation = "DarkCard"
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.custom_minimum_size = Vector2(420, 0)
	_toast_label = UI.label("", "", 27, HORIZONTAL_ALIGNMENT_CENTER)
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
	var idx := Game.content.area_order.find(_area) + 1
	_panel_kicker.text = (UI.t("AREA_N") % [idx, Game.content.area_order.size()]).to_upper()
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
	b.custom_minimum_size = Vector2(96, 96)
	b.theme_type_variation = "PrimaryButton" if (open and not done) else "SecondaryButton"
	b.add_theme_font_size_override("font_size", 34)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb := (ThemeBuilder.build().get_stylebox(st, b.theme_type_variation) as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.set_corner_radius_all(48)
		sb.content_margin_left = 0
		sb.content_margin_right = 0
		b.add_theme_stylebox_override(st, sb)
	b.text = str(n) if not (not open and not done) else ""
	b.disabled = not open
	b.name = "Level%d" % n
	b.pressed.connect(func(): Audio.play("ui_click"))
	if "accessibility_name" in b:
		var state := UI.t("STATE_DONE") if done else (UI.t("STATE_OPEN") if open else UI.t("STATE_LOCKED"))
		b.set("accessibility_name", "%s %d, %s" % [UI.t("LEVEL"), n, state])
	if not open and not done:
		var lock := UI.icon("lock", Color(Palette.INK_SOFT, 0.5), 34)
		lock.position = Vector2(31, 28)
		b.add_child(lock)
	if done:
		var lvl := Game.content.get_level(lid)
		var perfect := prog.optional_met_count(lid) >= lvl.optional.size()
		var badge := Badge.new()
		badge.icon = "star" if perfect else "check"
		badge.fill = Palette.SUN if perfect else Palette.TEAL
		badge.position = Vector2(60, -8)
		b.add_child(badge)
	b.pressed.connect(func(): Router.go("gameplay", {"level_id": lid}))
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
				await view.animate_area_unlock(_area, 0.3 if Game.reduced_motion() else 1.6)
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
	for ch in receipt["restoration"]:
		view.display_stage[ch["object"]] = float(ch["from"])
	view._dirty = true
	_refresh_panel()
	_primary.disabled = true
	var reduced := Game.reduced_motion()
	await get_tree().create_timer(0.1 if reduced else 0.5).timeout
	for ch in receipt["restoration"]:
		var o: Dictionary = Game.content.objects[ch["object"]]
		_show_toast(UI.t("RESTORING") % tr(o.get("name", "")))
		Audio.play("bloom")
		Game.haptic(15)
		await view.animate_object(ch["object"], float(ch["to"]), 0.3 if reduced else 1.4)
	await view.return_home()
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


## Small circular status badge (check / star) on a level bubble.
class Badge extends Control:
	var icon := "check"
	var fill := Palette.TEAL

	func _init() -> void:
		size = Vector2(40, 40)
		custom_minimum_size = Vector2(40, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_circle(Vector2(20, 22), 19, Color(0, 0, 0, 0.12), true, -1, true)
		draw_circle(Vector2(20, 20), 19, Color.WHITE, true, -1, true)
		draw_circle(Vector2(20, 20), 15, fill, true, -1, true)
		var tex := IconGlyph.texture_for(icon)
		if tex:
			draw_texture_rect(tex, Rect2(9, 9, 22, 22), false, Color.WHITE)
