extends Control
## Ember Reef level: slide rows and columns of channel blocks until water from
## the spring on the frame reaches every sapling. Rules live in SlideBoard;
## progress is saved the moment the level is solved (Game.complete_island_level).

const ISLAND := "ember_reef"

var level: Dictionary
var sb: SlideBoard
var board_view: SlideBoardView
var moves := 0
var history: Array = []        ## applied moves (for undo)
var plan: Array = []           ## moves that lead to a solution from the current state
var solved := false
var _start: PackedStringArray
var _moves_label: Label
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
	sb = SlideBoard.from_dict(level)
	_start = sb.snapshot()
	plan = (level.get("solution", []) as Array).duplicate(true)
	_build(index)
	await get_tree().process_frame
	_refresh(true)


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
	var chip := PanelContainer.new()
	chip.theme_type_variation = "ChipPanel"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_moves_label = UI.label("", "", 24)
	_moves_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	chip.add_child(_moves_label)
	col.add_child(chip)
	_caption_panel = PanelContainer.new()
	_caption_panel.theme_type_variation = "DarkCard"
	var cap := UI.label(UI.t("SLIDE_TUTORIAL"), "", 26)
	_caption_panel.add_child(cap)
	_caption_panel.visible = index < 2
	col.add_child(_caption_panel)
	board_view = SlideBoardView.new()
	board_view.name = "Board"
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_view.frame_ring = true
	board_view.inner_w = sb.w
	board_view.inner_h = sb.h
	board_view.locked_rows = sb.locked_rows
	board_view.locked_cols = sb.locked_cols
	col.add_child(board_view)
	board_view.slide_requested.connect(_on_slide)
	_setup_views()
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


func _setup_views() -> void:
	board_view.setup(sb.puzzle_board())
	for p in board_view.views:
		var v: TileView = board_view.views[p]
		var inner: bool = p.x >= 1 and p.y >= 1 and p.x <= sb.w and p.y <= sb.h
		v.block = inner
		v.quiet = not inner


func _target_moves() -> int:
	for o in level.get("objectives", {}).get("optional", []):
		if o.get("type", "") == "moves_at_most":
			return int(o["value"])
	return 0


func _refresh(animate: bool) -> void:
	var sim := sb.simulate()
	var dur := board_view.apply_water(sim, animate)
	var target := _target_moves()
	_moves_label.text = UI.t("MOVES_OF") % [moves, target] if target > 0 else UI.t("MOVES_N") % moves
	_undo_btn.disabled = history.is_empty() or solved
	_reset_btn.disabled = history.is_empty() or solved
	_hint_btn.disabled = solved
	if sim.all_required_reached and not solved:
		_on_solved(dur)


# ------------------------------------------------------------------ actions

func _on_slide(m: Array) -> void:
	if solved:
		return
	if not sb.apply(m):
		Audio.play("tap", 0.7, -8.0)   # locked line
		return
	moves += 1
	history.append(m)
	# keep a valid plan: following it shortens it, any other move must be undone first
	if not plan.is_empty() and plan[0] == m:
		plan.pop_front()
	else:
		plan.push_front(SlideBoard.inverse(m))
	_setup_views()
	board_view.slide_line(str(m[0]), int(m[1]), int(m[2]), sb.w, sb.h)
	board_view.highlight_line([])
	Audio.play("rotate", randf_range(0.95, 1.05))
	Game.haptic(10)
	_caption_panel.visible = false
	_refresh(true)


func undo() -> void:
	if history.is_empty() or solved:
		return
	var m: Array = history.pop_back()
	var inv := SlideBoard.inverse(m)
	sb.apply(inv)
	moves = maxi(0, moves - 1)
	if not plan.is_empty() and plan[0] == inv:
		plan.pop_front()
	else:
		plan.push_front(m)
	_setup_views()
	board_view.slide_line(str(inv[0]), int(inv[1]), int(inv[2]), sb.w, sb.h)
	Audio.play("ui_back")
	_refresh(false)


func reset() -> void:
	if solved:
		return
	sb.restore(_start)
	moves = 0
	history.clear()
	plan = (level.get("solution", []) as Array).duplicate(true)
	_setup_views()
	_refresh(false)


func hint() -> void:
	if solved or plan.is_empty():
		return
	board_view.highlight_line(plan[0])
	Audio.play("hint")


func _on_solved(flow_time: float) -> void:
	solved = true
	board_view.input_enabled = false
	board_view.highlight_line([])
	var receipt := Game.complete_island_level(ISLAND, level, moves)
	_undo_btn.disabled = true
	_reset_btn.disabled = true
	_hint_btn.disabled = true
	if not Game.reduced_motion():
		await get_tree().create_timer(flow_time * 0.8 + 0.3).timeout
	Audio.play("complete")
	Game.haptic(30)
	_show_result(receipt)


func _show_result(r: Dictionary) -> void:
	var overlay := Control.new()
	overlay.name = "ResultOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.12, 0.14, 0.55)
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
	var head := UI.label(UI.t("RESULT_TITLE_1"), "HeadingLabel", 50, HORIZONTAL_ALIGNMENT_CENTER)
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
			Router.go("slide", {"level_id": levels[idx + 1]["id"]})
		elif r.get("island_done", false) and Game.merge_unlocked():
			Router.go("merge")
		else:
			_leave())
	v.add_child(cont)
	var replay := UI.button(UI.t("REPLAY"), "reset", "SecondaryButton", Vector2(0, 88))
	replay.pressed.connect(func(): Router.go("slide", {"level_id": level["id"]}))
	v.add_child(replay)
