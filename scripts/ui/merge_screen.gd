extends Control
## LUMA Harbour (merge-2 mode): top bar (level, energy, coins, gems), the
## customers' order row, the 7 x 9 board, an info bar for the selected item and
## the bottom navigation (home, inventory, tasks). Rules live in MergeGame.

var game: MergeGame
var loc := ""                   ## "" = Lantern Café, else an island's merge location
var board_view: MergeBoardView
var _level_badge: LevelBadge
var _energy_label: Label
var _energy_timer: Label
var _coins_label: Label
var _gems_label: Label
var _orders_row: HBoxContainer
var _info_icon: ItemIcon
var _info_name: Label
var _info_sub: Label
var _info_actions: HBoxContainer
var _tasks_btn: Button
var _tasks_dot: Panel
var _inv_btn: Button
var _toast: Label
var _overlay: Control
var _dirty := false
var _save_t := 0.0
var _tick_t := 0.0
var _level_queue: Array[int] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loc = str(Router.params.get("location", ""))
	game = Game.merge_game(loc)
	var now := _now()
	game.tick(now)
	game.deliver_gifts()
	game.changed.connect(_on_changed)
	game.leveled_up.connect(func(l): _level_queue.append(l))
	_build()
	_refresh()
	Audio.play_music()
	if Router.params.get("intro", false) or not game.s.get("intro_seen", false):
		game.s["intro_seen"] = true
		_show_dialogue(game.db.intro, func(): pass)


func _now() -> int:
	return int(Time.get_unix_time_from_system())


# ------------------------------------------------------------------ layout

func _build() -> void:
	var bg := HarborBackdrop.new()
	bg.loc = loc
	add_child(bg)
	IconBaker.instance()   # starts baking the glossy icons as soon as the screen exists
	var margin := UI.safe_margin(self, 12)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)
	col.add_child(_build_top())
	col.add_child(UI.spacer(8))
	col.add_child(_build_orders())
	var counter := CounterBand.new()
	col.add_child(counter)
	counter.item_rect_changed.connect(func(): bg.split_y = counter.global_position.y + counter.size.y * 0.5)
	col.add_child(UI.spacer(14))
	board_view = MergeBoardView.new()
	board_view.name = "MergeBoard"
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(board_view)
	board_view.setup(game)
	board_view.cell_tapped.connect(_on_tap)
	board_view.cell_dropped.connect(_on_drop)
	col.add_child(UI.spacer(12))
	col.add_child(_build_bottom())
	_toast = UI.label("", "", 26, HORIZONTAL_ALIGNMENT_CENTER)
	_toast.add_theme_color_override("font_color", Color.WHITE)
	_toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.set_anchors_preset(Control.PRESET_CENTER)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast)


func _pill(icon_id: String, plus: bool, on_plus: Callable) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _face(Color("fff8ea"), 22, Color("c7b28c"), 4, 4, 2, 5))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 66)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	p.add_child(row)
	var ic := ItemIcon.new()
	ic.id = icon_id
	ic.custom_minimum_size = Vector2(56, 56)
	row.add_child(ic)
	var l := UI.label("0", "", 32)
	l.add_theme_font_override("font", ThemeBuilder.font_display())
	l.add_theme_color_override("font_color", Color("3a3f6e"))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	if plus:
		var b := Button.new()
		b.flat = true
		b.custom_minimum_size = Vector2(44, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var plus_icon := PlusMark.new()
		plus_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(plus_icon)
		b.pressed.connect(on_plus)
		row.add_child(b)
	return [p, l]


## A rounded face with an optional darker bottom lip (`lip` px) and soft shadow.
static func _face(bg: Color, radius: int, edge: Color, shadow := 0, pad_l := 12, pad_v := 8, lip := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	if lip > 0:
		sb.border_color = edge
		sb.border_width_bottom = lip
	if shadow > 0:
		sb.shadow_color = Color(edge, 0.25)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.5)
	sb.content_margin_left = pad_l
	sb.content_margin_right = 10
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	return sb


func _build_top() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_level_badge = LevelBadge.new()
	_level_badge.custom_minimum_size = Vector2(92, 92)
	row.add_child(_level_badge)
	var e := _pill("energy:2", true, _show_energy)
	e[0].name = "EnergyPill"
	_energy_label = e[1]
	row.add_child(e[0])
	_energy_timer = UI.label("", "", 17, HORIZONTAL_ALIGNMENT_CENTER)
	_energy_timer.add_theme_font_override("font", ThemeBuilder.font_display())
	_energy_timer.add_theme_color_override("font_color", Color("e08a12"))
	_energy_timer.autowrap_mode = TextServer.AUTOWRAP_OFF
	_energy_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_label.add_child(_energy_timer)
	_energy_timer.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_energy_timer.offset_top = -6
	_energy_timer.offset_bottom = 14
	var c := _pill("coin:1", false, Callable())
	_coins_label = c[1]
	row.add_child(c[0])
	var g := _pill("gems:1", false, Callable())
	_gems_label = g[1]
	row.add_child(g[0])
	var home := Button.new()
	home.name = "HomeButton"
	home.flat = true
	home.tooltip_text = UI.t("BACK")
	home.custom_minimum_size = Vector2(74, 74)
	var hi := HomeMark.new()
	hi.set_anchors_preset(Control.PRESET_FULL_RECT)
	home.add_child(hi)
	home.pressed.connect(func():
		_save_now()
		if loc != "":
			Router.go("islands", {"island": str(Game.merge_locations()[loc]["island"])})
		else:
			Router.go("menu"))
	row.add_child(home)
	return row


func _update_energy_timer(now: int) -> void:
	if _energy_timer == null:
		return
	if game.energy(now) >= game.energy_cap():
		_energy_timer.text = ""
	else:
		var eta := game.energy_eta(now)
		_energy_timer.text = "%02d:%02d" % [eta / 60, eta % 60]


func _build_orders() -> Control:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 292)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_orders_row = HBoxContainer.new()
	_orders_row.add_theme_constant_override("separation", 0)
	sc.add_child(_orders_row)
	return sc


func _build_info() -> Control:
	var wrap := VBoxContainer.new()
	wrap.name = "InfoBar"
	wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	wrap.add_theme_constant_override("separation", -10)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 6)
	tab_row.z_index = 1
	wrap.add_child(tab_row)
	var tab := PanelContainer.new()
	tab.add_theme_stylebox_override("panel", _face(Color("3d8fe6"), 14, Color("2a6cb8"), 0, 14, 4, 4))
	tab_row.add_child(tab)
	_info_name = UI.label("", "", 23)
	_info_name.add_theme_font_override("font", ThemeBuilder.font_display())
	_info_name.add_theme_color_override("font_color", Color.WHITE)
	_info_name.add_theme_color_override("font_outline_color", Color("1f4f8f"))
	_info_name.add_theme_constant_override("outline_size", 5)
	_info_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	tab.add_child(_info_name)
	var info_i := InfoMark.new()
	info_i.custom_minimum_size = Vector2(34, 34)
	info_i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tab_row.add_child(info_i)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _face(Color("fbfdff"), 20, Color("9fb7d6"), 0, 14, 12, 5))
	card.custom_minimum_size = Vector2(0, 100)
	wrap.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	_info_icon = ItemIcon.new()
	_info_icon.custom_minimum_size = Vector2(60, 60)
	_info_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_info_icon)
	_info_sub = UI.label("", "", 20)
	_info_sub.add_theme_color_override("font_color", Color("3a4f8f"))
	_info_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_info_sub)
	_info_actions = HBoxContainer.new()
	_info_actions.add_theme_constant_override("separation", 6)
	row.add_child(_info_actions)
	return wrap


func _build_bottom() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_inv_btn = Button.new()
	_inv_btn.name = "InventoryButton"
	_inv_btn.flat = true
	_inv_btn.custom_minimum_size = Vector2(104, 120)
	_inv_btn.tooltip_text = UI.t("INVENTORY")
	var case := ShowcaseMark.new()
	case.set_anchors_preset(Control.PRESET_FULL_RECT)
	_inv_btn.add_child(case)
	_inv_btn.pressed.connect(_show_inventory)
	row.add_child(_inv_btn)
	row.add_child(_build_info())
	_tasks_btn = Button.new()
	_tasks_btn.name = "TasksButton"
	_tasks_btn.flat = true
	_tasks_btn.tooltip_text = UI.t("TASKS")
	_tasks_btn.custom_minimum_size = Vector2(104, 120)
	var tm := TasksMark.new()
	tm.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tasks_btn.add_child(tm)
	_tasks_btn.pressed.connect(_show_tasks)
	row.add_child(_tasks_btn)
	_tasks_dot = Panel.new()
	_tasks_dot.add_theme_stylebox_override("panel", ThemeBuilder.box(Color("e2453f"), 14, 0, Color.WHITE, 4, 0, 0))
	_tasks_dot.size = Vector2(28, 28)
	_tasks_dot.position = Vector2(74, 4)
	_tasks_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks_btn.add_child(_tasks_dot)
	return row


# ------------------------------------------------------------------ refresh

func _on_changed() -> void:
	_dirty = true
	_refresh()


func _refresh() -> void:
	var now := _now()
	var s := game.s
	_level_badge.level = int(s["level"])
	_level_badge.progress = float(s["xp"]) / float(MergeGame.xp_to_next(int(s["level"])))
	_level_badge.queue_redraw()
	_energy_label.text = "%d" % game.energy(now)
	_coins_label.text = _short(int(s["coins"]))
	_gems_label.text = str(int(s["gems"]))
	_inv_btn.tooltip_text = "%s %d/%d" % [UI.t("INVENTORY"), game.inventory().size(), int(s["inv_slots"])]
	(_inv_btn.get_child(0) as ShowcaseMark).count = game.inventory().size()
	var can_task := false
	for t in game.open_tasks():
		if game.can_do_task(t["id"]):
			can_task = true
	_tasks_dot.visible = can_task
	_rebuild_orders()
	var need := {}
	for o in game.orders():
		for id in o["items"]:
			need[id] = true
	board_view.needed = need
	_refresh_info()
	while not _level_queue.is_empty():
		var l: int = _level_queue.pop_front()
		_show_level_up(l)


static func _short(n: int) -> String:
	if n >= 10000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


func _rebuild_orders() -> void:
	for c in _orders_row.get_children():
		c.queue_free()
	var i := 0
	for o in game.orders():
		_orders_row.add_child(_order_card(o, i))
		i += 1


## A customer at the counter: a big portrait, the rewards beside it and a plate with the
## dishes wanted (green tick = on the board); "Serve" replaces the rewards when ready.
func _order_card(o: Dictionary, i: int) -> Control:
	var ready := game.can_serve(i)
	var stand := Control.new()
	stand.name = "Order%d" % i
	stand.custom_minimum_size = Vector2(232, 292)
	var bust := CustomerBust.new()
	bust.who = str(o["who"])
	bust.position = Vector2(-6, 0)
	bust.size = Vector2(196, 206)
	stand.add_child(bust)
	var badges := VBoxContainer.new()
	badges.add_theme_constant_override("separation", 6)
	badges.position = Vector2(128, 84)
	stand.add_child(badges)
	badges.add_child(_reward_badge("star:1", "+%d" % int(o.get("xp", 1))))
	badges.add_child(_reward_badge("coin:1", "+%d" % int(o["coins"])))
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _face(Color("fbfdff"), 18, Color("a9c3dc"), 0, 6, 4, 6))
	plate.position = Vector2(8, 196)
	plate.size = Vector2(216, 92)
	stand.add_child(plate)
	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 0)
	plate.add_child(items)
	var have := {}
	for id in o["items"]:
		var ic := ItemIcon.new()
		ic.id = id
		ic.custom_minimum_size = Vector2(70, 80)
		ic.zoom = 1.35
		var n := int(have.get(id, 0)) + 1
		have[id] = n
		ic.check = game.count_on_board(id) >= n
		items.add_child(ic)
	if ready:
		badges.visible = false
		var serve := Button.new()
		serve.name = "Serve%d" % i
		serve.text = UI.t("SERVE")
		serve.position = Vector2(122, 104)
		serve.size = Vector2(106, 60)
		serve.add_theme_font_override("font", ThemeBuilder.font_display())
		serve.add_theme_font_size_override("font_size", 26)
		for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			serve.add_theme_color_override(st, Color.WHITE)
		serve.add_theme_color_override("font_outline_color", Color("2f7a2c"))
		serve.add_theme_constant_override("outline_size", 6)
		for st in ["normal", "hover", "focus", "hover_pressed"]:
			serve.add_theme_stylebox_override(st, _face(Color("62cf3c"), 18, Color("368f22"), 0, 6, 4, 6))
		serve.add_theme_stylebox_override("pressed", _face(Color("55bd31"), 18, Color("368f22"), 0, 6, 6, 2))
		serve.pressed.connect(func(): _serve(i))
		stand.add_child(serve)
	return stand


## A dark translucent pill with an icon and "+N" (order rewards).
func _reward_badge(icon_id: String, text: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _face(Color(0.18, 0.13, 0.42, 0.78), 18, Color.TRANSPARENT, 0, 2, 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	p.add_child(row)
	var ic := ItemIcon.new()
	ic.id = icon_id
	ic.custom_minimum_size = Vector2(38, 38)
	ic.zoom = 1.4
	row.add_child(ic)
	var l := UI.label(text, "", 26)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", ThemeBuilder.font_display())
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color("1d1640"))
	l.add_theme_constant_override("outline_size", 6)
	row.add_child(l)
	return p


func _refresh_info() -> void:
	for c in _info_actions.get_children():
		c.queue_free()
	var c := board_view.selected
	var v = game.at(c) if c != Vector2i(-1, -1) else null
	if v == null:
		_info_icon.id = ""
		_info_name.text = UI.t("MERGE_HINT_TITLE")
		_info_sub.text = UI.t("MERGE_HINT_BODY")
		return
	var id: String = v["id"]
	var db := game.db
	_info_icon.id = id
	_info_name.text = tr(db.item_name(id))
	var lvl := UI.t("ITEM_LEVEL") % [db.level_of(id), db.max_level(MergeDB.chain_of(id))]
	var now := _now()
	var sub := lvl
	if v.get("boxed", false):
		sub = UI.t("CRATE_HINT")
	elif float(v.get("bubble_until", 0)) > 0.0:
		sub = UI.t("BUBBLE_HINT")
		_action(UI.t("POP") + " %d" % game.bubble_price(c), "gems:1", func():
			if not game.pop_bubble(c, _now()):
				_say(UI.t("NOT_ENOUGH_GEMS")))
	else:
		match db.kind(id):
			"generator":
				var cost := int(db.gen_def(id, "energy", 1))
				sub = lvl + " · " + (UI.t("GEN_HINT_ENERGY") if cost > 0 else UI.t("GEN_HINT_FREE"))
			"chest":
				var until := int(v.get("timer_until", 0))
				sub = lvl + " · " + (UI.t("CHEST_HINT") if until == 0 else (UI.t("CHEST_READY") if until <= now else UI.t("CHEST_OPENING")))
				if until == 0 or until > now:
					_action(UI.t("RUSH") + " %d" % game.chest_rush_price(c, now), "gems:1", func():
						if not game.rush_chest(c, _now()):
							_say(UI.t("NOT_ENOUGH_GEMS")))
			"resource":
				sub = UI.t("RESOURCE_HINT")
			"tool":
				sub = UI.t("SCISSORS_HINT")
			_:
				sub = lvl + " · " + (UI.t("MAX_LEVEL") if db.is_max(id) else UI.t("MERGE_NEXT") % tr(db.item_name(db.next_id(id))))
		if game.can_sell(c):
			_action(UI.t("SELL") + " +%d" % db.sell_value(id), "coin:1", func():
				game.sell(c, _now())
				board_view.selected = Vector2i(-1, -1)
				_offer_undo())
		if true:
			_action("", "chest:1", func():
				if game.store(c):
					board_view.selected = Vector2i(-1, -1)
					_refresh()
				else:
					_say(UI.t("INVENTORY_FULL")), UI.t("STORE"))
	_info_sub.text = sub


func _action(text: String, icon_id: String, cb: Callable, tooltip := "") -> void:
	var b := Button.new()
	b.theme_type_variation = "SecondaryButton"
	b.custom_minimum_size = Vector2(0, 70)
	b.add_theme_font_size_override("font_size", 22)
	b.text = text
	b.tooltip_text = tooltip if tooltip != "" else text
	if "accessibility_name" in b:
		b.set("accessibility_name", tooltip if tooltip != "" else text)
	var pad := 16 if text != "" else 0
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sb: StyleBox = ThemeBuilder.build().get_stylebox(st, "SecondaryButton").duplicate()
		sb.content_margin_left = 60 + pad
		sb.content_margin_right = 14 + pad * 0.5
		b.add_theme_stylebox_override(st, sb)
	var ic := ItemIcon.new()
	ic.id = icon_id
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.position = Vector2(10, 10)
	ic.size = Vector2(46, 46)
	b.add_child(ic)
	b.pressed.connect(func():
		Audio.play("ui_click")
		cb.call())
	_info_actions.add_child(b)


# ------------------------------------------------------------------ board actions

func _on_tap(c: Vector2i) -> void:
	var v = game.at(c)
	if v == null:
		board_view.selected = Vector2i(-1, -1)
		_refresh_info()
		return
	var was_selected := board_view.selected == c
	board_view.selected = c
	var kind := game.db.kind(v["id"])
	if kind in ["generator", "chest", "resource"] and (was_selected or kind != "chest"):
		var r := game.tap(c, _now())
		if r.get("ok", false):
			if r.has("cell"):
				board_view.pop(r["cell"])
			Audio.play("tap" if kind == "generator" else "bloom")
			Game.haptic(8)
			if kind == "resource":
				board_view.selected = Vector2i(-1, -1)
		else:
			_explain(r)
	else:
		Audio.play("tap", 1.1, -6.0)
	_refresh_info()


func _on_drop(from: Vector2i, to: Vector2i) -> void:
	var r := game.drop(from, to, _now())
	match str(r.get("action", "none")):
		"merge", "unbox":
			board_view.pop(to, true)
			if r.get("bubble", Vector2i(-1, -1)) != Vector2i(-1, -1):
				board_view.pop(r["bubble"])
			board_view.selected = to
			Audio.play("rotate", 1.15)
			Game.haptic(14)
		"split":
			board_view.pop(to)
			board_view.pop(r["cell"])
			board_view.selected = to
		"move", "swap", "stack":
			board_view.selected = to
			Audio.play("tap", 0.9, -6.0)
		_:
			if r.get("reason", "") == "board_full":
				_say(UI.t("BOARD_FULL"))
	_refresh_info()


func _explain(r: Dictionary) -> void:
	match str(r.get("reason", "")):
		"no_energy":
			_show_energy()
		"board_full":
			_say(UI.t("BOARD_FULL"))
		"cooldown":
			_say(UI.t("COOLDOWN"))
		"chest_timer":
			_say(UI.t("CHEST_OPENING"))
		"opening":
			_say(UI.t("CHEST_STARTED"))


func _serve(i: int) -> void:
	var o: Dictionary = game.orders()[i]
	var r := game.serve(i)
	if r.get("ok", false):
		_save_now()
		Audio.play("complete")
		Game.haptic(20)
		_say("+%d  ·  +%d XP" % [int(r["coins"]), int(r["xp"])])
		Analytics.log_event("merge_order_served", {"items": (o["items"] as Array).size()})


func _offer_undo() -> void:
	_say(UI.t("SOLD"))
	_action(UI.t("UNDO"), "coin:1", func():
		if game.undo_sale(_now()):
			_refresh())


func _say(text: String) -> void:
	_toast.text = text
	_toast.size = Vector2(get_viewport_rect().size.x - 60, 0)
	_toast.position = Vector2(30, get_viewport_rect().size.y * 0.42)
	var tw := create_tween()
	_toast.modulate.a = 1.0
	tw.tween_interval(1.2)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _process(delta: float) -> void:
	_tick_t += delta
	if _tick_t >= 0.5:
		_tick_t = 0.0
		var now := _now()
		game.tick(now)
		_energy_label.text = "%d" % game.energy(now)
		_update_energy_timer(now)
		if not game.last_sale.is_empty() and now > int(game.last_sale["until"]):
			game.last_sale = {}
			_refresh_info()
	_save_t += delta
	if _dirty and _save_t > 1.5:
		_save_now()


func _save_now() -> void:
	_dirty = false
	_save_t = 0.0
	Game.save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE and _dirty:
		Game.save()


# ------------------------------------------------------------------ overlays

func _open_overlay(min_w := 640.0) -> VBoxContainer:
	_close_overlay()
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.08, 0.1, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_close_overlay())
	_overlay.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(cc)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(minf(min_w, get_viewport_rect().size.x - 40), 0)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	return v


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null


func _show_energy() -> void:
	var v := _open_overlay()
	v.add_child(UI.label(UI.t("ENERGY"), "HeadingLabel", 40, HORIZONTAL_ALIGNMENT_CENTER))
	var now := _now()
	var e := game.energy(now)
	var txt := UI.t("ENERGY_FULL") if e >= game.energy_cap() else UI.t("ENERGY_NEXT") % MergeBoardView._clock(game.energy_eta(now))
	v.add_child(UI.label("%d / %d" % [e, game.energy_cap()], "HeadingLabel", 34, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(txt, "CaptionLabel", 24, HORIZONTAL_ALIGNMENT_CENTER))
	var price := game.refill_price(now)
	var b := UI.button(UI.t("BUY_REFILL") % [game.energy_cap(), price], "", "PrimaryButton", Vector2(0, 96))
	b.name = "BuyRefill"
	b.pressed.connect(func():
		if game.buy_energy_refill(_now()):
			_close_overlay()
		else:
			_say(UI.t("NOT_ENOUGH_GEMS")))
	v.add_child(b)
	var close := UI.button(UI.t("CLOSE"), "", "SecondaryButton", Vector2(0, 80))
	close.pressed.connect(_close_overlay)
	v.add_child(close)


func _show_inventory() -> void:
	var v := _open_overlay()
	v.add_child(UI.label(UI.t("INVENTORY"), "HeadingLabel", 40, HORIZONTAL_ALIGNMENT_CENTER))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	var inv := game.inventory()
	for i in int(game.s["inv_slots"]):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(120, 120)
		slot.theme_type_variation = "SecondaryButton"
		var ic := ItemIcon.new()
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.position = Vector2(14, 10)
		ic.size = Vector2(92, 92)
		slot.add_child(ic)
		if i < inv.size():
			ic.id = inv[i]["id"]
			var idx := i
			slot.pressed.connect(func():
				if game.take_out(idx):
					_show_inventory()
				else:
					_say(UI.t("BOARD_FULL")))
		else:
			slot.disabled = true
		grid.add_child(slot)
	if int(game.s["inv_slots"]) < int(game.db.balance.get("inventory_max", 16)):
		var buy := UI.button(UI.t("BUY_SLOT") % game.slot_price(), "", "PrimaryButton", Vector2(0, 90))
		buy.pressed.connect(func():
			if game.buy_slot():
				_show_inventory()
			else:
				_say(UI.t("NOT_ENOUGH_GEMS")))
		v.add_child(buy)
	v.add_child(UI.label(UI.t("INVENTORY_HINT"), "CaptionLabel", 22, HORIZONTAL_ALIGNMENT_CENTER))
	var close := UI.button(UI.t("CLOSE"), "", "SecondaryButton", Vector2(0, 80))
	close.pressed.connect(_close_overlay)
	v.add_child(close)


func _show_tasks() -> void:
	var v := _open_overlay()
	v.name = "TasksSheet"
	var ci := game.chapter_index()
	if ci >= game.db.chapters.size():
		v.add_child(UI.label(UI.t("STORY_TBC"), "HeadingLabel", 34, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		var ch: Dictionary = game.db.chapters[ci]
		v.add_child(UI.label((UI.t("CHAPTER_N") % (ci + 1)).to_upper(), "KickerLabel", 22, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UI.label(tr(ch["title"]), "HeadingLabel", 40, HORIZONTAL_ALIGNMENT_CENTER))
		var done := 0
		for t in ch["tasks"]:
			if (game.s["tasks_done"] as Array).has(t["id"]):
				done += 1
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 18)
		bar.max_value = (ch["tasks"] as Array).size()
		bar.value = done
		v.add_child(bar)
		v.add_child(UI.label(UI.t("TASKS_DONE") % [done, (ch["tasks"] as Array).size()], "CaptionLabel", 22, HORIZONTAL_ALIGNMENT_CENTER))
		var blocked := game.chapter_blocked_by()
		if blocked != "":
			var isl := Game.island(blocked)
			v.add_child(UI.label(UI.t("CHAPTER_NEEDS_ISLAND") % tr(str(isl.get("name", blocked))), "", 26, HORIZONTAL_ALIGNMENT_CENTER))
			var go := UI.button(UI.t("GO_THERE"), "play", "PrimaryButton", Vector2(0, 90))
			go.name = "GoIsland"
			go.pressed.connect(func():
				_save_now()
				Router.go("islands", {"island": blocked}))
			v.add_child(go)
		for t in game.open_tasks():
			v.add_child(_task_row(t))
	var close := UI.button(UI.t("CLOSE"), "", "SecondaryButton", Vector2(0, 80))
	close.pressed.connect(_close_overlay)
	v.add_child(close)


func _task_row(t: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", ThemeBuilder.box(Palette.SHEET, 22, 0, Palette.MINT_EDGE, 2, 16, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var name := UI.label(tr(t["title"]), "", 26)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name)
	var b := UI.button("%d" % int(t["cost"]), "", "PrimaryButton", Vector2(150, 72))
	b.name = "Task_" + str(t["id"])
	var ic := ItemIcon.new()
	ic.id = "coin:1"
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.position = Vector2(12, 12)
	ic.size = Vector2(44, 44)
	b.add_child(ic)
	b.disabled = not game.can_do_task(t["id"])
	b.pressed.connect(func(): _start_task(t))
	row.add_child(b)
	return p


func _start_task(t: Dictionary) -> void:
	if t.has("designs"):
		var v := _open_overlay()
		v.add_child(UI.label(tr(t["title"]), "HeadingLabel", 36, HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(UI.label(UI.t("CHOOSE_DESIGN"), "CaptionLabel", 24, HORIZONTAL_ALIGNMENT_CENTER))
		for i in (t["designs"] as Array).size():
			var idx := i
			var b := UI.button(tr(t["designs"][i]), "", "SecondaryButton", Vector2(0, 84))
			b.name = "Design%d" % i
			b.pressed.connect(func(): _do_task(t, idx))
			v.add_child(b)
	else:
		_do_task(t, 0)


func _do_task(t: Dictionary, design: int) -> void:
	var r := game.do_task(t["id"], design)
	_close_overlay()
	if not r.get("ok", false):
		_say(UI.t("NOT_ENOUGH_COINS"))
		return
	_save_now()   # story progress is saved the moment it is paid for
	Audio.play("complete")
	Analytics.log_event("merge_task_done", {"task_id": str(t["id"])})
	_show_dialogue(r["dialogue"], func():
		if str(r.get("unlocks_island", "")) != "":
			_show_island_unlocked(str(r["unlocks_island"]))
		elif r.get("chapter_done", false):
			_show_chapter_done(r.get("reward", {})))


func _show_dialogue(lines: Array, done: Callable) -> void:
	if lines.is_empty():
		done.call()
		return
	_close_overlay()
	_overlay = DialogueOverlay.new()
	_overlay.name = "Dialogue"
	(_overlay as DialogueOverlay).cast = game.db.cast
	(_overlay as DialogueOverlay).lines = lines
	(_overlay as DialogueOverlay).finished.connect(func():
		_close_overlay()
		done.call())
	add_child(_overlay)


func _show_island_unlocked(id: String) -> void:
	var isl := Game.island(id)
	var v := _open_overlay()
	v.name = "IslandUnlocked"
	v.add_child(UI.label(UI.t("ISLAND_UNLOCKED") % tr(str(isl.get("name", id))), "HeadingLabel", 38, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(tr(str(isl.get("game_name", ""))), "CaptionLabel", 26, HORIZONTAL_ALIGNMENT_CENTER))
	var go := UI.button(UI.t("GO_THERE"), "play", "PrimaryButton", Vector2(0, 96))
	go.pressed.connect(func():
		_save_now()
		Router.go("islands", {"island": id}))
	v.add_child(go)
	var later := UI.button(UI.t("CLOSE"), "", "SecondaryButton", Vector2(0, 80))
	later.pressed.connect(_close_overlay)
	v.add_child(later)


func _show_chapter_done(reward: Dictionary) -> void:
	var v := _open_overlay()
	v.add_child(UI.label(UI.t("CHAPTER_DONE"), "HeadingLabel", 42, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label("+%d  %s   ·   +%d  %s" % [int(reward.get("gems", 0)), UI.t("GEMS"), int(reward.get("energy", 0)), UI.t("ENERGY")], "", 28, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UI.button(UI.t("CONTINUE"), "play", "PrimaryButton", Vector2(0, 96))
	ok.pressed.connect(_close_overlay)
	v.add_child(ok)


func _show_level_up(l: int) -> void:
	Audio.play("complete")
	var v := _open_overlay()
	v.name = "LevelUp"
	v.add_child(UI.label(UI.t("LEVEL_UP"), "HeadingLabel", 46, HORIZONTAL_ALIGNMENT_CENTER))
	var badge := LevelBadge.new()
	badge.level = l
	badge.progress = 0.0
	badge.custom_minimum_size = Vector2(140, 140)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(badge)
	v.add_child(UI.label(UI.t("LEVEL_UP_BODY"), "CaptionLabel", 24, HORIZONTAL_ALIGNMENT_CENTER))
	var ok := UI.button(UI.t("CONTINUE"), "play", "PrimaryButton", Vector2(0, 96))
	ok.pressed.connect(_close_overlay)
	v.add_child(ok)


# ------------------------------------------------------------------ small widgets

## An item icon as a Control (orders, inventory, info bar, buttons).
class ItemIcon extends Control:
	var id := "":
		set(v):
			id = v
			queue_redraw()
	var check := false
	var framed := false
	var zoom := 1.0   ## >1 lets the icon fill more of its box (plates, small badges)

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if id != "" and DisplayServer.get_name() != "headless":
			IconBaker.instance().baked.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if framed:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color("fff3dc")
			sb.set_corner_radius_all(int(size.x * 0.22))
			draw_style_box(sb, r)
		if id != "":
			ItemArt.draw_3d(self, id, r.grow(size.x * (zoom - 1.0) * 0.5 - size.x * 0.06))
		if check:
			var p := Vector2(size.x * 0.8, size.y * 0.2)
			draw_circle(p, size.x * 0.16, Color.WHITE, true, -1, true)
			draw_circle(p, size.x * 0.13, Color("4fb36a"), true, -1, true)
			draw_polyline(PackedVector2Array([p + Vector2(-size.x * 0.06, 0), p + Vector2(-size.x * 0.01, size.x * 0.05), p + Vector2(size.x * 0.07, -size.x * 0.05)]), Color.WHITE, maxf(2.0, size.x * 0.04), true)


## Player badge: the café owner's portrait in a rounded square, a green level star and a
## thin XP bar.
class LevelBadge extends Control:
	var level := 1
	var progress := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if DisplayServer.get_name() != "headless":
			IconBaker.instance().baked.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2(4, 0), size - Vector2(8, 8))
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(r.size.x * 0.26))
		sb.anti_aliasing = true
		sb.bg_color = Color("3a5fa8")
		draw_style_box(sb, Rect2(r.position + Vector2(0, 5), r.size))
		sb.bg_color = Color("bfe6fb")
		sb.border_color = Color.WHITE
		sb.set_border_width_all(4)
		draw_style_box(sb, r)
		var face := MergeArt.texture("face:nell")
		if face:
			draw_texture_rect(face, r.grow(-5), false)
		else:
			ItemArt.draw_bust(self, "nell", r.grow(-6))
		var bar := Rect2(r.position + Vector2(10, r.size.y - 12), Vector2(r.size.x - 20, 8))
		draw_rect(bar, Color(0, 0, 0, 0.35))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(progress, 0, 1), bar.size.y)), Color("ffcf2e"))
		var c := Vector2(size.x * 0.2, size.y * 0.82)
		var rr := size.x * 0.24
		var p := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + TAU * k / 10.0
			p.append(c + Vector2(cos(a), sin(a)) * rr * (1.0 if k % 2 == 0 else 0.5))
		var outline := p.duplicate()
		outline.append(p[0])
		draw_polyline(outline, Color.WHITE, 6, true)
		draw_colored_polygon(p, Color("3fbf4a"))
		var f := ThemeBuilder.font_display()
		var fs := int(rr * 0.85)
		var t := str(level)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, c + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color("1f6a24"))
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## A customer standing behind the counter (PortraitArt bust, baked).
class CustomerBust extends Control:
	var who := ""

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if DisplayServer.get_name() != "headless":
			IconBaker.instance().baked.connect(queue_redraw)

	func _draw() -> void:
		var s := minf(size.x, size.y)
		ItemArt.draw_bust(self, who, Rect2(Vector2((size.x - s) * 0.5, size.y - s), Vector2(s, s)))


## The counter the plates stand on: a blue band with a bright top edge.
class CounterBand extends Control:
	func _ready() -> void:
		custom_minimum_size = Vector2(0, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2(-12, -8), Vector2(size.x + 24, size.y + 8))
		draw_rect(r, Color("4d6fd0"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 7)), Color("8fb0ff"))
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - 6), Vector2(r.size.x, 6)), Color("33489a"))
		for k in 12:
			var x := size.x * (k + 0.5) / 12.0
			var sp := 4.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 4 - sp * 2), Vector2(x + sp * 0.5, 4 - sp * 0.5), Vector2(x + sp * 2, 4),
				Vector2(x + sp * 0.5, 4 + sp * 0.5), Vector2(x, 4 + sp * 2), Vector2(x - sp * 0.5, 4 + sp * 0.5), Vector2(x - sp * 2, 4),
				Vector2(x - sp * 0.5, 4 - sp * 0.5)]), Color(1, 1, 1, 0.6))


## Green rounded "+" (energy pill).
class PlusMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var s := minf(size.x, size.y) * 0.42
		for pass_i in 2:
			var w := s * (0.62 if pass_i == 0 else 0.4)
			var col := Color("2f8a2c") if pass_i == 0 else Color("6fdc3c")
			var off := Vector2(0, 3) if pass_i == 0 else Vector2.ZERO
			draw_rect(Rect2(c + off - Vector2(w * 0.5, s), Vector2(w, s * 2)), col)
			draw_rect(Rect2(c + off - Vector2(s, w * 0.5), Vector2(s * 2, w)), col)


## Home: a little house on a round button (top right).
class HomeMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.46
		draw_circle(c + Vector2(0, 4), r, Color("2b3f7a"), true, -1, true)
		draw_circle(c, r, Color("ffffff"), true, -1, true)
		draw_circle(c, r * 0.86, Color("ffb938"), true, -1, true)
		var s := r * 0.5
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.15, -s * 0.05), c + Vector2(0, -s * 1.1), c + Vector2(s * 1.15, -s * 0.05)]), Color("e2453f"))
		draw_rect(Rect2(c + Vector2(-s * 0.8, -s * 0.1), Vector2(s * 1.6, s * 1.05)), Color("fff3dc"))
		draw_rect(Rect2(c + Vector2(-s * 0.22, s * 0.3), Vector2(s * 0.44, s * 0.65)), Color("8a5a3a"))


## The round blue "i" next to the info title.
class InfoMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color.WHITE, true, -1, true)
		draw_circle(c, r * 0.8, Color("3d8fe6"), true, -1, true)
		draw_circle(c + Vector2(0, -r * 0.38), r * 0.12, Color.WHITE, true, -1, true)
		draw_rect(Rect2(c + Vector2(-r * 0.1, -r * 0.15), Vector2(r * 0.2, r * 0.6)), Color.WHITE)


## Storage: a glass showcase on a wooden base, with how many items are inside.
class ShowcaseMark extends Control:
	var count := 0:
		set(v):
			count = v
			queue_redraw()

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var base := Rect2(Vector2(w * 0.08, h * 0.62), Vector2(w * 0.84, h * 0.26))
		var sb := StyleBoxFlat.new()
		sb.anti_aliasing = true
		sb.set_corner_radius_all(10)
		sb.bg_color = Color("6b3f22")
		draw_style_box(sb, Rect2(base.position + Vector2(0, 5), base.size))
		sb.bg_color = Color("a8683a")
		draw_style_box(sb, base)
		var glass := Rect2(Vector2(w * 0.14, h * 0.16), Vector2(w * 0.72, h * 0.5))
		sb.set_corner_radius_all(18)
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		sb.bg_color = Color(0.75, 0.95, 1.0, 0.85)
		sb.border_color = Color("2fa8c8")
		sb.set_border_width_all(4)
		draw_style_box(sb, glass)
		draw_line(glass.position + Vector2(10, 12), glass.position + Vector2(10, glass.size.y - 10), Color(1, 1, 1, 0.8), 5)
		for k in 3:
			draw_circle(glass.position + Vector2(glass.size.x * (0.3 + 0.2 * k), glass.size.y * 0.62), w * 0.07, [Color("f2b632"), Color("e86a8c"), Color("8fd16a")][k], true, -1, true)
		if count > 0:
			var f := ThemeBuilder.font_display()
			var t := str(count)
			var p := Vector2(w * 0.8, h * 0.2)
			draw_circle(p, 16, Color("3d8fe6"), true, -1, true)
			var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
			draw_string(f, p + Vector2(-tw * 0.5, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)


## Tasks: a big round green button with a checklist.
class TasksMark extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var r := minf(size.x, size.y) * 0.46
		draw_circle(c + Vector2(0, 6), r, Color("1f6a2c"), true, -1, true)
		draw_circle(c, r, Color("2f9a3c"), true, -1, true)
		draw_circle(c + Vector2(-r * 0.1, -r * 0.12), r * 0.82, Color("4fc35f"), true, -1, true)
		var paper := Rect2(c - Vector2(r * 0.42, r * 0.55), Vector2(r * 0.84, r * 1.08))
		var sb := StyleBoxFlat.new()
		sb.anti_aliasing = true
		sb.set_corner_radius_all(8)
		sb.bg_color = Color("fffaf0")
		draw_style_box(sb, paper)
		sb.bg_color = Color("a8683a")
		draw_style_box(sb, Rect2(paper.position + Vector2(paper.size.x * 0.25, -r * 0.08), Vector2(paper.size.x * 0.5, r * 0.18)))
		for k in 3:
			var y := paper.position.y + paper.size.y * (0.3 + 0.24 * k)
			var tick := PackedVector2Array([Vector2(paper.position.x + r * 0.1, y), Vector2(paper.position.x + r * 0.18, y + r * 0.08), Vector2(paper.position.x + r * 0.32, y - r * 0.08)])
			draw_polyline(tick, Color("3fbf4a"), 4, true)
			draw_line(Vector2(paper.position.x + r * 0.4, y), Vector2(paper.end.x - r * 0.1, y), Color("9aa8b8"), 4)


## A character's painted portrait (PortraitArt, baked to look 3D) in a coloured ring.
class Portrait extends Control:
	var who := "":
		set(v):
			who = v
			queue_redraw()
	var ring := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if DisplayServer.get_name() != "headless":
			IconBaker.instance().baked.connect(queue_redraw)

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, r * 0.07), r, Color(0.05, 0.15, 0.2, 0.22), true, -1, true)
		draw_circle(c, r, ring, true, -1, true)
		draw_circle(c, r * 0.9, Color.WHITE, true, -1, true)
		if who != "":
			ItemArt.draw_portrait(self, who, Rect2(c - Vector2(r, r) * 0.84, Vector2(r, r) * 1.68))


## Sky, sea and a distant shore behind a merge location, tinted per place.
class HarborBackdrop extends Control:
	var loc := ""
	var split_y := -1.0:   ## below this line (the counter) the deep blue play area starts
		set(v):
			split_y = v
			queue_redraw()
	var _t := 0.0
	const LOOKS := {
		"": ["9fd9f2", "ffe3bd", "47b1d4", "2a87b0", "7cc17a"],
		"reef_grill": ["ffc9a0", "ffe7c4", "3fb8c9", "1f8aa8", "e8935a"],
		"lighthouse_workshop": ["7f9fd8", "f6d7a8", "3b7fb5", "245d8f", "8fa37a"],
		"terrace_tea_house": ["bfe3d0", "f4ecd0", "62b3b4", "3b8f93", "8fb86a"],
		"rope_market": ["8fd8f5", "fff0c8", "2fb5d8", "168cb8", "f0c070"],
		"moonlight_bakery": ["3b3478", "c79bd8", "3a4f9a", "26306e", "6a5aa8"],
	}

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		if not Game.reduced_motion():
			_t += delta
			queue_redraw()

	func _draw() -> void:
		var look: Array = LOOKS.get(loc, LOOKS[""])
		var sky_top := Color(look[0])
		var sky_low := Color(look[1])
		var sea_top := Color(look[2])
		var sea_low := Color(look[3])
		if Palette.dark:
			sky_top = sky_top.darkened(0.55)
			sky_low = sky_low.darkened(0.5)
			sea_top = sea_top.darkened(0.45)
			sea_low = sea_low.darkened(0.5)
		var w := size.x
		var h := size.y
		var horizon := h * 0.17
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, horizon), Vector2(0, horizon)]),
			PackedColorArray([sky_top, sky_top, sky_low, sky_low]))
		draw_circle(Vector2(w * 0.78, horizon * 0.45), h * 0.05, Color(1, 1, 0.9, 0.55), true, -1, true)
		for k in 3:
			var cx := fmod(w * (0.15 + k * 0.35) + _t * (6 + k * 3), w * 1.3) - w * 0.15
			for b in 4:
				draw_circle(Vector2(cx + b * h * 0.03, horizon * (0.3 + 0.12 * k) - (b % 2) * h * 0.012), h * 0.025, Color(1, 1, 1, 0.55), true, -1, true)
		var hills := PackedVector2Array([Vector2(0, horizon)])
		for i in 13:
			var x := w * i / 12.0
			hills.append(Vector2(x, horizon - h * (0.02 + 0.025 * (0.5 + 0.5 * sin(i * 1.7)))))
		hills.append(Vector2(w, horizon))
		draw_colored_polygon(hills, Color(look[4]).darkened(0.1 if not Palette.dark else 0.55))
		draw_polygon(PackedVector2Array([Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([sea_top, sea_top, sea_low, sea_low]))
		for i in 14:
			var y := horizon + (h - horizon) * fmod(Painter.hash01(i * 7) + _t * 0.004 * (1 + i % 3), 1.0)
			var x := w * Painter.hash01(i * 13)
			var len := w * 0.08
			draw_line(Vector2(x, y), Vector2(x + len, y), Color(1, 1, 1, 0.16), 3.0, true)
		var sy := split_y if split_y > 0.0 else h * 0.31
		var deep_top := Color("3b4fa8") if not Palette.dark else Color("1f2858")
		var deep_low := Color("2a3478") if not Palette.dark else Color("151a3c")
		draw_polygon(PackedVector2Array([Vector2(0, sy), Vector2(w, sy), Vector2(w, h), Vector2(0, h)]),
			PackedColorArray([deep_top, deep_top, deep_low, deep_low]))


## Story scene: speaker portrait, name and line; tap to continue.
class DialogueOverlay extends Control:
	signal finished
	var cast: Dictionary = {}
	var lines: Array = []
	var _i := 0
	var _name: Label
	var _text: Label
	var _avatar: Portrait

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.03, 0.06, 0.08, 0.45)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		var panel := PanelContainer.new()
		panel.theme_type_variation = "Card"
		panel.anchor_left = 0.0
		panel.anchor_right = 1.0
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_left = 20
		panel.offset_right = -20
		panel.offset_top = -330
		panel.offset_bottom = -40
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		panel.add_child(row)
		_avatar = Portrait.new()
		_avatar.custom_minimum_size = Vector2(140, 140)
		_avatar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(_avatar)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		_name = UI.label("", "HeadingLabel", 32)
		v.add_child(_name)
		_text = UI.label("", "", 28)
		_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
		v.add_child(_text)
		v.add_child(UI.label(UI.t("TAP_TO_CONTINUE"), "CaptionLabel", 20, HORIZONTAL_ALIGNMENT_RIGHT))
		_show()

	func _show() -> void:
		var line: Array = lines[_i]
		var who: Dictionary = cast.get(line[0], {})
		_name.text = tr(str(who.get("name", line[0])))
		_name.add_theme_color_override("font_color", Color(str(who.get("color", "333333"))).darkened(0.2))
		_text.text = tr(str(line[1]))
		_avatar.ring = Color(str(who.get("color", "888888")))
		_avatar.who = str(line[0])

	func _gui_input(e: InputEvent) -> void:
		if e.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			accept_event()
			_i += 1
			if _i >= lines.size():
				finished.emit()
			else:
				Audio.play("tap", 1.2, -10.0)
				_show()
