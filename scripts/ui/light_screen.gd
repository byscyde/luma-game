extends Control
## Lantern Bay level: tap round mirrors to steer lantern beams onto every crystal
## while the night blooms stay dark. Rules live in LightBoard; progress is saved
## the moment the level is solved (Game.complete_island_level).

const ISLAND := "lantern_bay"

var level: Dictionary
var lb: LightBoard
var board_view: LightBoardView
var moves := 0
var history: Array = []        ## tapped cells (for undo)
var solved := false
var _start: PackedStringArray
var _moves_label: Label
var _status_label: Label
var _undo_btn: Button
var _reset_btn: Button
var _hint_btn: Button
var _caption_panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var id: String = Router.params.get("level_id", "")
	var levels := Game.island_levels(ISLAND)
	var index := -1
	for i in levels.size():
		if levels[i]["id"] == id:
			index = i
	if index < 0 or not Game.island_level_unlocked(ISLAND, index):
		call_deferred("_leave")
		return
	level = levels[index]
	lb = LightBoard.from_dict(level)
	_start = lb.cells.duplicate()
	_build(index)
	await get_tree().process_frame
	_refresh(false)


func _leave() -> void:
	Router.go("islands", {"island": ISLAND})


func _build(index: int) -> void:
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
	back.pressed.connect(_leave)
	top.add_child(back)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", -6)
	top.add_child(titles)
	titles.add_child(UI.label((UI.t("LEVEL_KICKER") % [index + 1, tr(Game.island(ISLAND)["name"])]).to_upper(), "KickerLabel"))
	titles.add_child(UI.label(tr(level["name"]), "HeadingLabel", 40))
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", 12)
	col.add_child(chips)
	for k in 2:
		var chip := PanelContainer.new()
		chip.theme_type_variation = "ChipPanel"
		var l := UI.label("", "", 24)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		chip.add_child(l)
		chips.add_child(chip)
		if k == 0:
			_moves_label = l
		else:
			_status_label = l
	_caption_panel = PanelContainer.new()
	_caption_panel.theme_type_variation = "DarkCard"
	var cap := UI.label(UI.t("LIGHT_TUTORIAL") if index != 10 else UI.t("LIGHT_TUTORIAL_BLOOM"), "", 26)
	if index == 15:
		cap.text = UI.t("LIGHT_TUTORIAL_PRISM")
	_caption_panel.add_child(cap)
	_caption_panel.visible = index < 2 or index == 10 or index == 15
	col.add_child(_caption_panel)
	board_view = LightBoardView.new()
	board_view.name = "Board"
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(board_view)
	board_view.setup(lb)
	board_view.mirror_tapped.connect(_on_tap)
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.PAPER, 40, 18, Color.TRANSPARENT, 0, 14, 10))
	col.add_child(dock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	dock.add_child(row)
	_undo_btn = UI.button(UI.t("UNDO"), "undo", "SecondaryButton", Vector2(0, 96))
	_reset_btn = UI.button(UI.t("RESET"), "reset", "SecondaryButton", Vector2(0, 96))
	_hint_btn = UI.button(UI.t("HINT"), "hint", "PrimaryButton", Vector2(0, 96))
	_undo_btn.name = "UndoButton"
	_reset_btn.name = "ResetButton"
	_hint_btn.name = "HintButton"
	for b in [_undo_btn, _reset_btn, _hint_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_undo_btn.pressed.connect(undo)
	_reset_btn.pressed.connect(reset)
	_hint_btn.pressed.connect(hint)


func _target_moves() -> int:
	for o in level.get("objectives", {}).get("optional", []):
		if o.get("type", "") == "moves_at_most":
			return int(o["value"])
	return 0


func _refresh(animate: bool) -> void:
	var t := lb.trace()
	board_view.show_trace(t, animate)
	var target := _target_moves()
	_moves_label.text = UI.t("MOVES_OF") % [moves, target] if target > 0 else UI.t("MOVES_N") % moves
	_status_label.text = UI.t("CRYSTALS_LIT") % [int(t["crystals_lit"]), int(t["crystals"])]
	if int(t["blooms_lit"]) > 0:
		_status_label.text += "  ·  " + UI.t("BLOOMS_BURNT") % int(t["blooms_lit"])
	_undo_btn.disabled = history.is_empty() or solved
	_reset_btn.disabled = history.is_empty() or solved
	_hint_btn.disabled = solved
	if t["solved"] and not solved:
		_on_solved()


# ------------------------------------------------------------------ actions

func _on_tap(c: Vector2i) -> void:
	if solved:
		return
	if not lb.toggle(c):
		return
	moves += 1
	history.append(c)
	board_view.highlight = Vector2i(-1, -1)
	board_view.animate_flip(c)
	_caption_panel.visible = false
	Audio.play("rotate", randf_range(0.95, 1.05))
	Game.haptic(10)
	_refresh(true)


func undo() -> void:
	if history.is_empty() or solved:
		return
	var c: Vector2i = history.pop_back()
	lb.toggle(c)
	moves = maxi(0, moves - 1)
	board_view.animate_flip(c)
	Audio.play("ui_back")
	_refresh(false)


func reset() -> void:
	if solved:
		return
	lb.cells = _start.duplicate()
	moves = 0
	history.clear()
	board_view.highlight = Vector2i(-1, -1)
	_refresh(false)


## The next mirror to tap: the cheapest solution from the current state.
func next_tap() -> Vector2i:
	var r := LightSolver.solve(lb, 20000)
	if r["status"] == LightSolver.SOLVED and not (r["flips"] as Array).is_empty():
		return r["flips"][0]
	var taps := LightSolver.taps_towards(lb, _solution_state())
	return taps[0] if not taps.is_empty() else Vector2i(-1, -1)


func _solution_state() -> String:
	var b := LightBoard.from_dict(level)
	for c in level.get("solution", []):
		b.toggle(Vector2i(int(c[0]), int(c[1])))
	return b.mirror_state()


func hint() -> void:
	if solved:
		return
	board_view.highlight = next_tap()
	Audio.play("hint")


func _on_solved() -> void:
	solved = true
	board_view.input_enabled = false
	board_view.highlight = Vector2i(-1, -1)
	var receipt := Game.complete_island_level(ISLAND, level, moves)
	_undo_btn.disabled = true
	_reset_btn.disabled = true
	_hint_btn.disabled = true
	if not Game.reduced_motion():
		await get_tree().create_timer(0.7).timeout
	Audio.play("complete")
	Game.haptic(30)
	_show_result(receipt)


func _show_result(r: Dictionary) -> void:
	var overlay := Control.new()
	overlay.name = "ResultOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.14, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(minf(620, size.x - 48), 0)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var head := UI.label(UI.t("LIGHT_RESULT"), "HeadingLabel", 50, HORIZONTAL_ALIGNMENT_CENTER)
	head.add_theme_color_override("font_color", Palette.TEAL)
	v.add_child(head)
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 10)
	for i in 3:
		stars.add_child(UI.icon("star", Palette.SUN if i < int(r["stars"]) else Palette.MUTED, 64))
	v.add_child(stars)
	v.add_child(UI.label(UI.t("MOVES_N") % moves, "CaptionLabel", 26, HORIZONTAL_ALIGNMENT_CENTER))
	if int(r.get("cafe_coins", 0)) > 0:
		v.add_child(UI.label(UI.t("CAFE_COINS_EARNED") % int(r["cafe_coins"]), "", 28, HORIZONTAL_ALIGNMENT_CENTER))
	if r.get("island_done", false):
		v.add_child(UI.label(UI.t("ISLAND_DONE"), "", 28, HORIZONTAL_ALIGNMENT_CENTER))
	var levels := Game.island_levels(ISLAND)
	var idx := levels.find(level)
	var cont := UI.button(UI.t("NEXT_LEVEL") if idx + 1 < levels.size() else UI.t("CONTINUE"), "play", "PrimaryButton", Vector2(0, 104))
	cont.name = "ContinueButton"
	cont.pressed.connect(func():
		if idx + 1 < levels.size() and not r.get("island_done", false):
			Router.go("light", {"level_id": levels[idx + 1]["id"]})
		else:
			_leave())
	v.add_child(cont)
	var replay := UI.button(UI.t("REPLAY"), "reset", "SecondaryButton", Vector2(0, 88))
	replay.pressed.connect(func(): Router.go("light", {"level_id": level["id"]}))
	v.add_child(replay)
