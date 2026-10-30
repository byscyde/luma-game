extends Control
## Stone Steps level (Sokoban): Luma pushes boulders into the spillway sockets
## so the water turns onto the dry terraces. Rules live in PushBoard; progress
## is saved the moment the level is solved (Game.complete_island_level).

const ISLAND := "stone_steps"

var level: Dictionary
var pb: PushBoard
var board_view: PushBoardView
var moves := 0
var history: Array = []        ## snapshots before each action: [player, boulders, moves, plan]
var plan: Array = []           ## steps that solve the level from the current state
var solved := false
var _live: Dictionary
var _moves_label: Label
var _status_label: Label
var _undo_btn: Button
var _reset_btn: Button
var _hint_btn: Button
var _caption_panel: PanelContainer
var _caption: Label


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
	pb = PushBoard.from_dict(level)
	_live = PushSolver.live_cells(pb)
	plan = (level.get("solution", []) as Array).duplicate()
	_build(index)
	await get_tree().process_frame
	_refresh()


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
	_caption = UI.label(UI.t("PUSH_TUTORIAL"), "", 26)
	_caption_panel.add_child(_caption)
	_caption_panel.visible = index < 2
	col.add_child(_caption_panel)
	board_view = PushBoardView.new()
	board_view.name = "Board"
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(board_view)
	board_view.setup(pb)
	board_view.step_requested.connect(func(d: String): do_steps([d]))
	board_view.walk_requested.connect(do_steps)
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


func _refresh() -> void:
	var target := _target_moves()
	_moves_label.text = UI.t("MOVES_OF") % [moves, target] if target > 0 else UI.t("MOVES_N") % moves
	_status_label.text = UI.t("SOCKETS_FILLED") % [pb.filled(), pb.sockets.size()]
	if stuck():
		_status_label.text += "  ·  " + UI.t("BOULDER_STUCK")
	_undo_btn.disabled = history.is_empty() or solved
	_reset_btn.disabled = history.is_empty() or solved
	_hint_btn.disabled = solved
	if pb.solved() and not solved:
		_on_solved()


## A boulder off its socket on a cell from which no socket can be reached.
func stuck() -> bool:
	for c in pb.boulders:
		if not _live.has(c):
			return true
	return false


# ------------------------------------------------------------------ actions

## One player action: a swipe (one step) or a tap (a walk of several steps).
## Stops at the first blocked step; returns the number of steps taken.
func do_steps(dirs: Array) -> int:
	if solved or dirs.is_empty():
		return 0
	var snap := [pb.player, pb.boulders.duplicate(), moves, plan.duplicate()]
	var taken := 0
	var path: Array = [pb.player]
	var b_from := Vector2i(-1, -1)
	var b_to := Vector2i(-1, -1)
	for d in dirs:
		var r := pb.step(d)
		if r == "":
			break
		taken += 1
		moves += 1
		path.append(pb.player)
		if r == "push":
			b_from = pb.player
			b_to = pb.player + (PushBoard.DIRS[d] as Vector2i)
		# keep the hint plan only while the player follows it
		if not plan.is_empty() and plan[0] == d:
			plan.pop_front()
		else:
			plan.clear()
		if r == "push":
			Audio.play("rotate", randf_range(0.85, 0.95))
			Game.haptic(12)
		if pb.solved():
			break
	if taken == 0:
		Audio.play("tap", 0.7, -8.0)
		return 0
	history.append(snap)
	board_view.animate_walk(path, b_from, b_to)
	board_view.highlight = Vector2i(-1, -1)
	_caption_panel.visible = false
	_refresh()
	return taken


func undo() -> void:
	if history.is_empty() or solved:
		return
	var s: Array = history.pop_back()
	pb.player = s[0]
	pb.boulders = s[1]
	moves = s[2]
	plan = s[3]
	board_view.setup(pb)
	board_view.highlight = Vector2i(-1, -1)
	Audio.play("ui_back")
	_refresh()


func reset() -> void:
	if solved or history.is_empty():
		return
	var s: Array = history[0]
	history.clear()
	pb.player = s[0]
	pb.boulders = s[1]
	moves = 0
	plan = (level.get("solution", []) as Array).duplicate()
	board_view.setup(pb)
	board_view.highlight = Vector2i(-1, -1)
	_refresh()


## The next step of a solution from here ("" when none is found: undo first).
func next_step() -> String:
	if plan.is_empty() and not stuck():
		var r := PushSolver.solve(pb, 60000)
		if r["status"] == PushSolver.SOLVED:
			plan = r["moves"]
	return plan[0] if not plan.is_empty() else ""


func hint() -> void:
	if solved:
		return
	var d := next_step()
	if d == "":
		_caption.text = UI.t("HINT_UNDO")
		_caption_panel.visible = true
		board_view.highlight = Vector2i(-1, -1)
	else:
		board_view.highlight = pb.player + (PushBoard.DIRS[d] as Vector2i)
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
		await get_tree().create_timer(0.5).timeout
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
	var head := UI.label(UI.t("PUSH_RESULT"), "HeadingLabel", 50, HORIZONTAL_ALIGNMENT_CENTER)
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
			Router.go("push", {"level_id": levels[idx + 1]["id"]})
		else:
			_leave())
	v.add_child(cont)
	var replay := UI.button(UI.t("REPLAY"), "reset", "SecondaryButton", Vector2(0, 88))
	replay.pressed.connect(func(): Router.go("push", {"level_id": level["id"]}))
	v.add_child(replay)
