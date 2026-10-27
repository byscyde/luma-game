extends Control
## Rope Isles level (Hashi): join the islets with rope bridges so each has its
## number of bridges and all islets are connected. Rules live in BridgeBoard;
## progress is saved the moment the level is solved (Game.complete_island_level).

const ISLAND := "rope_isles"

var level: Dictionary
var bb: BridgeBoard
var board_view: BridgeBoardView
var moves := 0
var history: Array = []        ## tapped links (for undo)
var solved := false
var _goal: PackedInt32Array    ## the level's unique solution, per link
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
	bb = BridgeBoard.from_dict(level)
	_goal = solution_state(bb, level)
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
	var cap := UI.label(UI.t("BRIDGE_TUTORIAL") if index == 0 else UI.t("BRIDGE_TUTORIAL_2"), "", 26)
	_caption_panel.add_child(cap)
	_caption_panel.visible = index < 2
	col.add_child(_caption_panel)
	board_view = BridgeBoardView.new()
	board_view.name = "Board"
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(board_view)
	board_view.setup(bb)
	board_view.link_tapped.connect(_on_tap)
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


## Bridge counts per link for the stored solution ([x1, y1, x2, y2, n] entries).
static func solution_state(b: BridgeBoard, lv: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(b.links.size())
	out.fill(0)
	for e in lv.get("solution", []):
		var k := b.link_between(b.island_at(Vector2i(int(e[0]), int(e[1]))), b.island_at(Vector2i(int(e[2]), int(e[3]))))
		if k >= 0:
			out[k] = int(e[4])
	return out


func _refresh() -> void:
	var target := _target_moves()
	_moves_label.text = UI.t("MOVES_OF") % [moves, target] if target > 0 else UI.t("MOVES_N") % moves
	_status_label.text = UI.t("ISLETS_DONE") % [bb.complete_count(), bb.islands.size()]
	_undo_btn.disabled = history.is_empty() or solved
	_reset_btn.disabled = history.is_empty() or solved
	_hint_btn.disabled = solved
	if bb.solved() and not solved:
		_on_solved()


# ------------------------------------------------------------------ actions

func _on_tap(k: int) -> void:
	if solved:
		return
	if not bb.tap(k):
		Audio.play("tap", 0.7, -8.0)   # a crossing bridge is in the way
		return
	moves += 1
	history.append(k)
	board_view.highlight = -1
	_caption_panel.visible = false
	Audio.play("rotate", randf_range(0.95, 1.05))
	Game.haptic(10)
	_refresh()


func undo() -> void:
	if history.is_empty() or solved:
		return
	var k: int = history.pop_back()
	bb.state[k] = (bb.state[k] + 2) % 3
	moves = maxi(0, moves - 1)
	Audio.play("ui_back")
	_refresh()


func reset() -> void:
	if solved:
		return
	bb.state.fill(0)
	moves = 0
	history.clear()
	board_view.highlight = -1
	_refresh()


## The next link to tap towards the solution: first clear a wrong bridge that
## blocks a needed one, then any link that differs from the solution.
func next_tap() -> int:
	for k in bb.links.size():
		if bb.state[k] != _goal[k] and bb.state[k] > 0 and _goal[k] == 0:
			return k
	for k in bb.links.size():
		if bb.state[k] != _goal[k] and (bb.state[k] > 0 or bb.link_free(k)):
			return k
	return -1


func hint() -> void:
	if solved:
		return
	board_view.highlight = next_tap()
	Audio.play("hint")


func _on_solved() -> void:
	solved = true
	board_view.input_enabled = false
	board_view.highlight = -1
	var receipt := Game.complete_island_level(ISLAND, level, moves)
	_undo_btn.disabled = true
	_reset_btn.disabled = true
	_hint_btn.disabled = true
	if not Game.reduced_motion():
		await get_tree().create_timer(0.4).timeout
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
	var head := UI.label(UI.t("BRIDGE_RESULT"), "HeadingLabel", 50, HORIZONTAL_ALIGNMENT_CENTER)
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
			Router.go("bridges", {"level_id": levels[idx + 1]["id"]})
		else:
			_leave())
	v.add_child(cont)
	var replay := UI.button(UI.t("REPLAY"), "reset", "SecondaryButton", Vector2(0, 88))
	replay.pressed.connect(func(): Router.go("bridges", {"level_id": level["id"]}))
	v.add_child(replay)
