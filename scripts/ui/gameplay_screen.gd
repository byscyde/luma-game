extends Control
## Gameplay screen: one puzzle level from start to result card.
## Rules live in PuzzleBoard / WaterSimulation / PuzzleValidator; this screen
## wires input, feedback, persistence and the result flow together.

const RESULT_TITLES := ["RESULT_TITLE_1", "RESULT_TITLE_2", "RESULT_TITLE_3"]

var level: LevelData
var board: PuzzleBoard
var board_view: BoardView
var moves := 0
var history: Array = []
var initial_snapshot: Dictionary
var solved := false
var hints_used := 0
var undo_count := 0
var last_sim: WaterResult
var last_receipt: Dictionary = {}
var _start_ms := 0
var _reached_before: Dictionary = {}

var _title: Label
var _subtitle: Label
var _chips: HFlowContainer
var _moves_label: Label
var _leak_chip: PanelContainer
var _bonus_chip: PanelContainer
var _caption_panel: PanelContainer
var _caption: Label
var _undo_btn: Button
var _reset_btn: Button
var _hint_btn: Button
var _overlay: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var id: String = Router.params.get("level_id", "")
	if id == "":
		id = Game.progression.next_level_id()
	if id == "" or not Game.progression.is_level_unlocked(id):
		# Nothing playable here (locked or all done): the island explains why.
		call_deferred("_leave_to_island")
		return
	level = Game.content.get_level(id)
	board = level.build_board()
	initial_snapshot = board.snapshot()
	var ip := Game.in_progress_for(id)
	if not ip.is_empty() and (ip.get("rotations", []) as Array).size() == board.tiles.size():
		board.restore({"rotations": PackedByteArray(ip["rotations"]), "switches": ip.get("switches", {})})
		moves = int(ip.get("moves", 0))
	_build()
	Game.level_started(id)
	_start_ms = Time.get_ticks_msec()
	Audio.play_music()
	# let layout settle, then let water run from the source
	await get_tree().process_frame
	_refresh(true)
	_update_tutorial()


func _leave_to_island() -> void:
	Router.go("island")


# ------------------------------------------------------------------ UI

func _build() -> void:
	add_child(Backdrop.new())
	var margin := UI.safe_margin(self, 22)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	var back := UI.round_button("back", UI.t("BACK"))
	back.name = "BackButton"
	back.pressed.connect(_on_back)
	top.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", -6)
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(titles)
	var area_name: String = tr(Game.content.areas.get(level.area, {}).get("name", ""))
	_title = UI.label((UI.t("LEVEL_KICKER") % [Game.content.level_number(level.id), area_name]).to_upper(), "KickerLabel")
	titles.add_child(_title)
	_subtitle = UI.label(tr(level.name), "HeadingLabel", 40)
	titles.add_child(_subtitle)
	top.add_child(UI.essence_chip())

	_chips = HFlowContainer.new()
	_chips.alignment = FlowContainer.ALIGNMENT_CENTER
	_chips.add_theme_constant_override("h_separation", 10)
	_chips.add_theme_constant_override("v_separation", 8)
	col.add_child(_chips)
	var mv := _chip("tap", "")
	_moves_label = mv.get_meta("label")
	_chips.add_child(mv)
	if level.has_optional(LevelData.OBJ_NO_LEAKS):
		_leak_chip = _chip("no_leaks", UI.t("CHIP_NO_LEAKS"))
		_chips.add_child(_leak_chip)
	if level.has_optional(LevelData.OBJ_REACH_BONUS):
		_bonus_chip = _chip("flower", UI.t("CHIP_BONUS"))
		_chips.add_child(_bonus_chip)

	_caption_panel = PanelContainer.new()
	_caption_panel.theme_type_variation = "DarkCard"
	_caption_panel.visible = false
	var cap_row := HBoxContainer.new()
	cap_row.add_theme_constant_override("separation", 14)
	_caption_panel.add_child(cap_row)
	cap_row.add_child(UI.icon("hint", Palette.SUN_EDGE, 38))
	_caption = UI.label("", "", 28)
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_row.add_child(_caption)
	col.add_child(_caption_panel)

	board_view = BoardView.new()
	board_view.name = "Board"
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(board_view)
	board_view.setup(board)
	board_view.tile_tapped.connect(_on_tile_tapped)

	# bottom dock: three icon-over-label tools on one card; Hint is the accent
	var dock := PanelContainer.new()
	dock.name = "Dock"
	dock.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.PAPER, 40, 18, Color.TRANSPARENT, 0, 14, 10))
	col.add_child(dock)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	dock.add_child(bottom)
	_undo_btn = _tool_button(UI.t("UNDO"), "undo", false)
	_reset_btn = _tool_button(UI.t("RESET"), "reset", false)
	_hint_btn = _tool_button(UI.t("HINT"), "hint", true)
	for b in [_undo_btn, _reset_btn, _hint_btn]:
		bottom.add_child(b)
	_undo_btn.name = "UndoButton"
	_reset_btn.name = "ResetButton"
	_hint_btn.name = "HintButton"
	_undo_btn.pressed.connect(undo)
	_reset_btn.pressed.connect(reset)
	_hint_btn.pressed.connect(hint)
	_update_buttons()


func _tool_button(text: String, icon_kind: String, accent: bool) -> Button:
	var b := Button.new()
	b.theme_type_variation = "ToolButton"
	b.custom_minimum_size = Vector2(0, 124)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = text
	if "accessibility_name" in b:
		b.set("accessibility_name", text)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var disc := PanelContainer.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	disc.custom_minimum_size = Vector2(68, 68)
	disc.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.SUN if accent else Palette.TEAL_SOFT, 34, 0, Color.TRANSPARENT, 0, 0, 0))
	v.add_child(disc)
	var cc := CenterContainer.new()
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(cc)
	cc.add_child(UI.icon(icon_kind, Palette.SUN_INK if accent else Palette.INK, 34))
	var l := UI.label(text, "", 24, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", ThemeBuilder.font_display())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	b.pressed.connect(func(): Audio.play("ui_click"))
	return b


func _chip(icon_kind: String, text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "ChipPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	chip.add_child(row)
	var ic := UI.icon(icon_kind, Palette.INK_SOFT, 28)
	row.add_child(ic)
	var l := UI.label(text, "", 24)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(l)
	chip.set_meta("label", l)
	chip.set_meta("icon", ic)
	return chip


func _set_chip_state(chip: PanelContainer, ok: bool) -> void:
	if chip == null:
		return
	var ic: IconGlyph = chip.get_meta("icon")
	ic.color = Palette.TEAL if ok else Palette.INK_SOFT
	(chip.get_meta("label") as Label).add_theme_color_override("font_color", Palette.TEAL if ok else Palette.INK)


func _update_buttons() -> void:
	_undo_btn.disabled = history.is_empty() or solved
	_reset_btn.disabled = solved or (moves == 0 and history.is_empty())
	_hint_btn.disabled = solved
	for b in [_undo_btn, _reset_btn, _hint_btn]:
		b.modulate.a = 0.38 if b.disabled else 1.0


func _update_chips() -> void:
	var target := level.optional_value(LevelData.OBJ_MOVES_AT_MOST, 0)
	if target > 0:
		_moves_label.text = UI.t("MOVES_OF") % [moves, target]
		_set_chip_state(_chips.get_child(0), moves <= target)
	else:
		_moves_label.text = UI.t("MOVES_N") % moves
	if last_sim:
		_set_chip_state(_leak_chip, last_sim.leak_count() == 0)
		_set_chip_state(_bonus_chip, not last_sim.reached_bonus.is_empty())


# ------------------------------------------------------------------ actions

func _on_tile_tapped(c: Vector2i) -> void:
	if solved:
		return
	var t := board.get_tile(c)
	var snap := board.snapshot()
	if board.tap(c):
		moves += 1
		history.append(snap)
		if t.is_rotatable():
			board_view.animate_rotation(c)
			Audio.play("rotate", randf_range(0.95, 1.05))
		else:
			board_view.animate_press(c)
			Audio.play("toggle")
		Game.haptic(10)
		board_view.set_highlight(Vector2i(-1, -1))
		_refresh(true)
		if not solved:
			Game.store_in_progress(level.id, board, moves)
		_update_tutorial()
	else:
		board_view.animate_press(c)
		Audio.play("tap", 0.8, -8.0)


func undo() -> void:
	if history.is_empty() or solved:
		return
	board.restore(history.pop_back())
	moves = maxi(0, moves - 1)
	undo_count += 1
	Audio.play("ui_back")
	_refresh(false)
	Game.store_in_progress(level.id, board, moves)
	_update_tutorial()


func reset() -> void:
	if solved:
		return
	board.restore(initial_snapshot)
	moves = 0
	history.clear()
	_refresh(false)
	Game.clear_in_progress()
	Analytics.log_event("level_restarted", {"level_id": level.id})
	_update_tutorial()


func hint() -> void:
	if solved:
		return
	var h := PuzzleSolver.hint(board)
	if h == Vector2i(-1, -1):
		_show_caption(UI.t("HINT_RESET"))
		return
	hints_used += 1
	board_view.set_highlight(h)
	Audio.play("hint")
	Analytics.log_event("hint_used", {"level_id": level.id, "hint_count": hints_used})


func _on_back() -> void:
	if not solved and moves > 0:
		Game.store_in_progress(level.id, board, moves)
		Game.save()
	Router.go("island")


# ------------------------------------------------------------------ simulation

func _refresh(animate: bool) -> void:
	last_sim = WaterSimulation.simulate(board)
	var dur := board_view.apply_water(last_sim, animate)
	var newly := false
	for id in last_sim.reached_targets + last_sim.reached_bonus:
		if not _reached_before.has(id):
			newly = true
	_reached_before.clear()
	for id in last_sim.reached_targets + last_sim.reached_bonus:
		_reached_before[id] = true
	if newly and not last_sim.all_required_reached:
		Audio.play("bloom")
	_update_chips()
	_update_buttons()
	if last_sim.all_required_reached and not solved:
		_on_solved(dur)


func _on_solved(flow_time: float) -> void:
	solved = true
	board_view.input_enabled = false
	board_view.hide_pointer()
	board_view.set_highlight(Vector2i(-1, -1))
	_update_buttons()
	var evaluation := PuzzleValidator.evaluate(level, board, last_sim, moves)
	# Persist immediately: progress must survive even if the app closes mid-animation.
	last_receipt = Game.complete_level(level, evaluation, moves, {
		"hint_count": hints_used, "undo_count": undo_count,
		"duration_s": int((Time.get_ticks_msec() - _start_ms) / 1000)})
	var reduced := Game.reduced_motion()
	if not reduced:
		await get_tree().create_timer(flow_time * 0.8).timeout
	Audio.play("complete")
	Game.haptic(30)
	board_view.celebrate(last_sim)
	_caption_panel.visible = false
	await get_tree().create_timer(0.2 if reduced else 0.9).timeout
	_show_result(evaluation)


# ------------------------------------------------------------------ tutorial

func _update_tutorial() -> void:
	if solved or level == null:
		return
	var step := level.tutorial
	if Game.tutorial.should_show(step):
		_show_caption(UI.t(Game.tutorial.caption_key(step)))
		if Game.tutorial.wants_pointer(step):
			var h := PuzzleSolver.hint(board)
			board_view.show_pointer(h)
		else:
			board_view.hide_pointer()
	else:
		_caption_panel.visible = false
		board_view.hide_pointer()


func _show_caption(text: String) -> void:
	_caption.text = text
	_caption_panel.visible = true


# ------------------------------------------------------------------ result

func _show_result(evaluation: Dictionary) -> void:
	_overlay = Control.new()
	_overlay.name = "ResultOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.22, 0.22, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(minf(620, size.x - 48), 0)
	center.add_child(card)
	var medal := Medal.new()
	medal.anchor = card
	medal.stars = 1 + int(evaluation.get("optional_met", 0))
	medal.max_stars = 1 + (evaluation.get("objectives", []) as Array).size()
	_overlay.add_child(medal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(UI.spacer(70))
	var idx := Game.content.level_number(level.id) % RESULT_TITLES.size()
	var head := UI.label(UI.t(RESULT_TITLES[idx]), "HeadingLabel", 52, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_theme_color_override("font_color", Palette.TEAL)
	v.add_child(head)
	v.add_child(UI.label(tr(level.name), "CaptionLabel", 28, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(6))
	# objectives
	v.add_child(_result_row("check", UI.t("OBJ_RESTORE"), true))
	for o in evaluation.get("objectives", []):
		v.add_child(_result_row("check" if o["met"] else "check", PuzzleValidator.objective_label(o), o["met"]))
	v.add_child(UI.spacer(4))
	var r := last_receipt
	if int(r.get("essence", 0)) > 0:
		var pill := PanelContainer.new()
		pill.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.SUN_SOFT, 30, 0, Color.TRANSPARENT, 0, 26, 10))
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var er := HBoxContainer.new()
		er.add_theme_constant_override("separation", 10)
		pill.add_child(er)
		er.add_child(UI.icon("leaf", Palette.LEAF_DARK, 40))
		var el := UI.label("+%d %s" % [r["essence"], UI.t("ESSENCE")], "HeadingLabel", 34)
		el.add_theme_color_override("font_color", Palette.SUN if Palette.dark else Palette.SUN_INK)
		el.autowrap_mode = TextServer.AUTOWRAP_OFF
		er.add_child(el)
		v.add_child(pill)
	elif not r.get("first_completion", false):
		v.add_child(UI.label(UI.t("BEST_MOVES") % int(r.get("best_moves", moves)), "CaptionLabel", 26, HORIZONTAL_ALIGNMENT_CENTER))
	for d in r.get("discoveries", []):
		var dn: String = Game.content.decorations[d]["name"]
		v.add_child(UI.label(UI.t("NEW_DISCOVERY") % tr(dn), "", 28, HORIZONTAL_ALIGNMENT_CENTER))
	for a in r.get("achievements", []):
		for ach in Game.content.achievements:
			if ach["id"] == a:
				v.add_child(UI.label(UI.t("ACHIEVEMENT_UNLOCKED") % tr(ach["name"]), "", 28, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.spacer(8))
	var cont := UI.button(UI.t("CONTINUE"), "play", "PrimaryButton", Vector2(0, 104))
	cont.name = "ContinueButton"
	var opens_harbour: bool = level.id == Game.content.level_order.back() and bool(last_receipt.get("first_completion", false))
	if opens_harbour:
		cont.text = UI.t("HARBOUR_OPEN")
	cont.pressed.connect(func():
		if opens_harbour:
			Router.go("merge", {"intro": true})
		else:
			Router.go("island", {"from_level": level.id}))
	v.add_child(cont)
	var replay := UI.button(UI.t("REPLAY"), "reset", "SecondaryButton", Vector2(0, 88))
	replay.name = "ReplayButton"
	replay.pressed.connect(func(): Router.go("gameplay", {"level_id": level.id}))
	v.add_child(replay)
	cont.grab_focus.call_deferred()
	var reduced := Game.reduced_motion()
	card.modulate.a = 0.0
	card.pivot_offset = card.size * 0.5
	var tw := create_tween().set_parallel(true)
	tw.tween_property(dim, "color:a", 0.55, 0.25)
	tw.tween_property(card, "modulate:a", 1.0, 0.1 if reduced else 0.3)
	if not reduced:
		card.scale = Vector2(0.92, 0.92)
		tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await get_tree().process_frame
		card.pivot_offset = card.size * 0.5


func _result_row(icon_kind: String, text: String, met: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UI.icon(icon_kind, Palette.TEAL if met else Palette.MUTED, 32))
	var l := UI.label(text, "" if met else "CaptionLabel", 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	return row


## Sunny medal with one star per objective met, overlapping the result card.
class Medal extends Control:
	var stars := 1
	var max_stars := 1
	var anchor: Control
	var _t := 0.0

	func _init() -> void:
		size = Vector2(260, 200)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		if is_instance_valid(anchor):
			global_position = anchor.global_position + Vector2(anchor.size.x * 0.5 - size.x * 0.5, -100)
			modulate.a = anchor.modulate.a
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, 100)
		for i in 12:
			var a := TAU * i / 12.0 + _t * 0.3
			var p1 := c + Vector2(cos(a), sin(a)) * 62
			var p2 := c + Vector2(cos(a + 0.12), sin(a + 0.12)) * 86
			var p3 := c + Vector2(cos(a - 0.12), sin(a - 0.12)) * 86
			draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(1.0, 0.86, 0.4, 0.45))
		draw_circle(c + Vector2(0, 4), 56, Color(0, 0, 0, 0.12), true, -1, true)
		draw_circle(c, 56, Color.WHITE, true, -1, true)
		draw_circle(c, 47, Palette.SUN, true, -1, true)
		var tex := IconGlyph.texture_for("leaf")
		if tex:
			draw_texture_rect(tex, Rect2(c - Vector2(30, 30), Vector2(60, 60)), false, Color.WHITE)
		var star := IconGlyph.texture_for("star")
		if star:
			var n := max_stars
			for i in n:
				var x := c.x + (i - (n - 1) * 0.5) * 40.0
				var col := Palette.SUN if i < stars else Palette.MUTED
				draw_circle(Vector2(x, c.y + 58), 21, Color.WHITE, true, -1, true)
				draw_texture_rect(star, Rect2(x - 16, c.y + 42, 32, 32), false, col)
