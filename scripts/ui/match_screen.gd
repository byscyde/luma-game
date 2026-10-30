extends Control
## Moon Grove level (match-3): swap neighbouring moonflowers to make rows of
## three or more, clear the dark moss and gather the flowers the grove asks
## for before the moves run out. Rules live in MatchBoard; progress is saved
## the moment the goals are met (Game.complete_island_level).

const ISLAND := "moon_grove"

var level: Dictionary
var mb: MatchBoard
var board_view: MatchBoardView
var moves := 0
var solved := false
var failed := false
var _moves_label: Label
var _goal_row: HBoxContainer
var _restart_btn: Button
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
	mb = MatchBoard.from_dict(level)
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
	_goal_row = HBoxContainer.new()
	_goal_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_goal_row.add_theme_constant_override("separation", 12)
	col.add_child(_goal_row)
	_caption_panel = PanelContainer.new()
	_caption_panel.theme_type_variation = "DarkCard"
	_caption_panel.add_child(UI.label(UI.t("MATCH_TUTORIAL") if index == 0 else UI.t("MATCH_TUTORIAL_MOSS"), "", 26))
	_caption_panel.visible = index == 0 or index == 3
	col.add_child(_caption_panel)
	board_view = MatchBoardView.new()
	board_view.name = "Board"
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(board_view)
	board_view.setup(mb)
	board_view.swap_requested.connect(try_swap)
	var dock := PanelContainer.new()
	dock.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.PAPER, 40, 18, Color.TRANSPARENT, 0, 14, 10))
	col.add_child(dock)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	dock.add_child(row)
	_restart_btn = UI.button(UI.t("RESET"), "reset", "SecondaryButton", Vector2(0, 96))
	_hint_btn = UI.button(UI.t("HINT"), "hint", "PrimaryButton", Vector2(0, 96))
	_restart_btn.name = "ResetButton"
	_hint_btn.name = "HintButton"
	for b in [_restart_btn, _hint_btn]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	_restart_btn.pressed.connect(func(): Router.go("match", {"level_id": level["id"]}))
	_hint_btn.pressed.connect(hint)


func _chip(text: String, kind: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = "ChipPanel"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	chip.add_child(h)
	if kind != -1:
		var icon := GoalIcon.new()
		icon.kind = kind
		icon.custom_minimum_size = Vector2(34, 34)
		h.add_child(icon)
	var l := UI.label(text, "", 24)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	h.add_child(l)
	return chip


func _refresh() -> void:
	for c in _goal_row.get_children():
		c.queue_free()
	var left := _chip(UI.t("MOVES_LEFT") % mb.moves_left, -1)
	_moves_label = left.get_child(0).get_child(0)
	_goal_row.add_child(left)
	if mb.goal_moss:
		_goal_row.add_child(_chip(UI.t("MOSS_LEFT") % mb.moss_left(), -2))
	for k in mb.goal_collect:
		_goal_row.add_child(_chip(str(maxi(0, int(mb.goal_collect[k]) - mb.collected[k])), int(k)))
	_hint_btn.disabled = solved or failed
	_restart_btn.disabled = solved
	if mb.goals_met() and not solved:
		_on_solved()
	elif mb.lost() and not failed:
		_on_failed()


# ------------------------------------------------------------------ actions

## One swap from the player; returns whether it was played.
func try_swap(a: Vector2i, b: Vector2i) -> bool:
	if solved or failed:
		return false
	var before := mb.cells.duplicate()
	if not mb.swap(a, b):
		Audio.play("tap", 0.7, -8.0)
		board_view.selected = Vector2i(-1, -1)
		return false
	moves += 1
	board_view.play_result(a, b, mb.last_events, before)
	_caption_panel.visible = false
	Audio.play("rotate", randf_range(0.95, 1.1))
	Game.haptic(10 if mb.last_events.size() < 3 else 20)
	_refresh()
	return true


func hint() -> void:
	if solved or failed:
		return
	board_view.hint_pair = MatchBot.best_swap(mb)
	Audio.play("hint")


func _on_solved() -> void:
	solved = true
	board_view.input_enabled = false
	var receipt := Game.complete_island_level(ISLAND, level, moves)
	_hint_btn.disabled = true
	_restart_btn.disabled = true
	if not Game.reduced_motion():
		await get_tree().create_timer(0.6).timeout
	Audio.play("complete")
	Game.haptic(30)
	_show_result(receipt)


func _on_failed() -> void:
	failed = true
	board_view.input_enabled = false
	var overlay := _overlay()
	var v: VBoxContainer = overlay.get_meta("box")
	v.add_child(UI.label(UI.t("OUT_OF_MOVES"), "HeadingLabel", 46, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(UI.t("OUT_OF_MOVES_BODY"), "CaptionLabel", 26, HORIZONTAL_ALIGNMENT_CENTER))
	var retry := UI.button(UI.t("TRY_AGAIN"), "reset", "PrimaryButton", Vector2(0, 104))
	retry.name = "RetryButton"
	retry.pressed.connect(func(): Router.go("match", {"level_id": level["id"]}))
	v.add_child(retry)
	var leave := UI.button(UI.t("BACK"), "back", "SecondaryButton", Vector2(0, 88))
	leave.pressed.connect(_leave)
	v.add_child(leave)


func _overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "ResultOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.14, 0.6)
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
	overlay.set_meta("box", v)
	return overlay


func _show_result(r: Dictionary) -> void:
	var overlay := _overlay()
	var v: VBoxContainer = overlay.get_meta("box")
	var head := UI.label(UI.t("MATCH_RESULT"), "HeadingLabel", 50, HORIZONTAL_ALIGNMENT_CENTER)
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
			Router.go("match", {"level_id": levels[idx + 1]["id"]})
		else:
			_leave())
	v.add_child(cont)


## A small goal icon: a moonflower of one kind, or a moss tuft (kind -2).
class GoalIcon:
	extends Control
	var kind := 0

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.4
		if kind == -2:
			draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), MatchBoardView.MOSS_2)
			for k in 3:
				draw_circle(c + Vector2(-r * 0.6 + k * r * 0.6, r * 0.4), r * 0.3, MatchBoardView.MOSS_1.lightened(0.2))
			return
		var pts := MatchBoardView.shape_pts(c, kind, r)
		draw_colored_polygon(pts, MatchBoardView.KIND_COLORS[kind % 6])
