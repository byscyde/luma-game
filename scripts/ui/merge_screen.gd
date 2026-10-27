extends Control
## LUMA Harbour (merge-2 mode): top bar (level, energy, coins, gems), the
## customers' order row, the 7 x 9 board, an info bar for the selected item and
## the bottom navigation (home, inventory, tasks). Rules live in MergeGame.

var game: MergeGame
var loc := ""                   ## "" = Lantern Café, else an island's merge location
var board_view: MergeBoardView
var _level_badge: LevelBadge
var _energy_label: Label
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
	var margin := UI.safe_margin(self, 14)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	col.add_child(_build_top())
	col.add_child(_build_orders())
	board_view = MergeBoardView.new()
	board_view.name = "MergeBoard"
	board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(board_view)
	board_view.setup(game)
	board_view.cell_tapped.connect(_on_tap)
	board_view.cell_dropped.connect(_on_drop)
	col.add_child(_build_info())
	col.add_child(_build_nav())
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
	p.add_theme_stylebox_override("panel", _face(Color.WHITE, 30, Color(0.1, 0.25, 0.35, 0.22), 6, 2, 4))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 62)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	p.add_child(row)
	var ic := ItemIcon.new()
	ic.id = icon_id
	ic.custom_minimum_size = Vector2(58, 58)
	row.add_child(ic)
	var l := UI.label("0", "", 30)
	l.add_theme_font_override("font", ThemeBuilder.font_display())
	l.add_theme_color_override("font_color", Color("2b3a45"))
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	if plus:
		var b := Button.new()
		b.text = "+"
		b.custom_minimum_size = Vector2(46, 46)
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_font_override("font", ThemeBuilder.font_display())
		for st in ["normal", "hover", "pressed", "hover_pressed"]:
			b.add_theme_stylebox_override(st, _face(Color("4fc35f") if st != "pressed" else Color("3fa94f"), 23, Color("2f8a3c"), 0, 0, 0, 4))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
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
	row.add_theme_constant_override("separation", 12)
	_level_badge = LevelBadge.new()
	_level_badge.custom_minimum_size = Vector2(80, 80)
	row.add_child(_level_badge)
	var e := _pill("energy:2", true, _show_energy)
	e[0].name = "EnergyPill"
	_energy_label = e[1]
	row.add_child(e[0])
	var c := _pill("coins:2", false, Callable())
	_coins_label = c[1]
	row.add_child(c[0])
	var g := _pill("gems:1", false, Callable())
	_gems_label = g[1]
	row.add_child(g[0])
	return row


func _build_orders() -> Control:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 262)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_orders_row = HBoxContainer.new()
	_orders_row.add_theme_constant_override("separation", 12)
	sc.add_child(_orders_row)
	return sc


func _build_info() -> Control:
	var p := PanelContainer.new()
	p.name = "InfoBar"
	p.add_theme_stylebox_override("panel", _face(Color(1, 1, 1, 0.96), 28, Color(0.1, 0.25, 0.35, 0.5), 8, 16, 8))
	p.custom_minimum_size = Vector2(0, 108)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var well := PanelContainer.new()
	well.add_theme_stylebox_override("panel", _face(Color("fff3dc"), 22, Color.TRANSPARENT, 0, 4, 4))
	row.add_child(well)
	_info_icon = ItemIcon.new()
	_info_icon.custom_minimum_size = Vector2(84, 84)
	well.add_child(_info_icon)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	row.add_child(v)
	_info_name = UI.label("", "HeadingLabel", 28)
	_info_name.add_theme_color_override("font_color", Color("2b3a45"))
	_info_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	_info_name.clip_text = true
	v.add_child(_info_name)
	_info_sub = UI.label("", "CaptionLabel", 20)
	_info_sub.add_theme_color_override("font_color", Color("6b7c86"))
	v.add_child(_info_sub)
	_info_actions = HBoxContainer.new()
	_info_actions.add_theme_constant_override("separation", 8)
	row.add_child(_info_actions)
	return p


func _build_nav() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var home := _nav_button("", "home", Color.WHITE, Color("c9d6dc"), Color("2b3a45"))
	home.name = "HomeButton"
	home.custom_minimum_size = Vector2(96, 96)
	home.tooltip_text = UI.t("BACK")
	home.pressed.connect(func():
		_save_now()
		if loc != "":
			Router.go("islands", {"island": str(Game.merge_locations()[loc]["island"])})
		else:
			Router.go("menu"))
	row.add_child(home)
	_inv_btn = _nav_button(UI.t("INVENTORY"), "collection", Color.WHITE, Color("c9d6dc"), Color("2b3a45"))
	_inv_btn.name = "InventoryButton"
	_inv_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_btn.pressed.connect(_show_inventory)
	row.add_child(_inv_btn)
	_tasks_btn = _nav_button(UI.t("TASKS"), "check", Color("ffb938"), Color("d9861a"), Color("5a3200"))
	_tasks_btn.name = "TasksButton"
	_tasks_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tasks_btn.pressed.connect(_show_tasks)
	row.add_child(_tasks_btn)
	_tasks_dot = Panel.new()
	_tasks_dot.add_theme_stylebox_override("panel", ThemeBuilder.box(Color("e2453f"), 14, 0, Color.WHITE, 4, 0, 0))
	_tasks_dot.size = Vector2(28, 28)
	_tasks_dot.position = Vector2(-4, -6)
	_tasks_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tasks_btn.add_child(_tasks_dot)
	return row


## Chunky bottom-bar button: coloured face with a darker lip, icon and bold label.
func _nav_button(text: String, icon: String, face: Color, lip: Color, ink: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 96)
	b.add_theme_font_override("font", ThemeBuilder.font_display())
	b.add_theme_font_size_override("font_size", 30)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, ink)
	for st in ["normal", "hover", "focus", "hover_pressed"]:
		b.add_theme_stylebox_override(st, _face(face, 32, lip, 4, 20, 10, 7))
	b.add_theme_stylebox_override("pressed", _face(face.darkened(0.06), 32, lip, 2, 20, 12, 3))
	var ic := UI.icon(icon, ink, 40)
	ic.size = Vector2(40, 40)
	ic.position = Vector2(26 if text != "" else 28, 24)
	b.add_child(ic)
	if text != "":
		for st in ["normal", "hover", "focus", "hover_pressed", "pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(st)
			sb.content_margin_left = 76
	return b


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
	_inv_btn.text = "%s %d/%d" % [UI.t("INVENTORY"), game.inventory().size(), int(s["inv_slots"])]
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


func _order_card(o: Dictionary, i: int) -> Control:
	var ready := game.can_serve(i)
	var p := PanelContainer.new()
	p.name = "Order%d" % i
	p.custom_minimum_size = Vector2(212, 0)
	p.add_theme_stylebox_override("panel", _face(Color("fffdf8") if not ready else Color("f2fff0"), 30,
		Color(0.1, 0.25, 0.35, 0.5) if not ready else Color("4fc35f"), 8, 12, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var who: Dictionary = game.db.cast.get(o["who"], {})
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var av := Portrait.new()
	av.who = str(o["who"])
	av.ring = Color(str(who.get("color", "888888")))
	av.custom_minimum_size = Vector2(84, 84)
	head.add_child(av)
	var nm := UI.label(tr(str(who.get("name", ""))), "", 22)
	nm.add_theme_font_override("font", ThemeBuilder.font_display())
	nm.add_theme_color_override("font_color", Color("2b3a45"))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(100, 0)
	nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(nm)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _face(Color("fff3dc"), 22, Color.TRANSPARENT, 0, 6, 6))
	v.add_child(bubble)
	var items := HBoxContainer.new()
	items.alignment = BoxContainer.ALIGNMENT_CENTER
	items.add_theme_constant_override("separation", 2)
	bubble.add_child(items)
	var have := {}
	for id in o["items"]:
		var ic := ItemIcon.new()
		ic.id = id
		ic.custom_minimum_size = Vector2(80, 80)
		var n := int(have.get(id, 0)) + 1
		have[id] = n
		ic.check = game.count_on_board(id) >= n
		items.add_child(ic)
	if ready:
		var serve := Button.new()
		serve.name = "Serve%d" % i
		serve.text = UI.t("SERVE")
		serve.custom_minimum_size = Vector2(0, 58)
		serve.add_theme_font_override("font", ThemeBuilder.font_display())
		serve.add_theme_font_size_override("font_size", 26)
		for st in ["font_color", "font_hover_color", "font_pressed_color"]:
			serve.add_theme_color_override(st, Color.WHITE)
		for st in ["normal", "hover", "focus", "hover_pressed"]:
			serve.add_theme_stylebox_override(st, _face(Color("4fc35f"), 26, Color("2f8a3c"), 0, 10, 4, 6))
		serve.add_theme_stylebox_override("pressed", _face(Color("45b455"), 26, Color("2f8a3c"), 0, 10, 6, 2))
		serve.pressed.connect(func(): _serve(i))
		v.add_child(serve)
	else:
		var rw := HBoxContainer.new()
		rw.alignment = BoxContainer.ALIGNMENT_CENTER
		rw.add_theme_constant_override("separation", 2)
		var ci := ItemIcon.new()
		ci.id = "coins:2"
		ci.custom_minimum_size = Vector2(44, 44)
		rw.add_child(ci)
		var amt := UI.label("+%d" % int(o["coins"]), "", 24)
		amt.autowrap_mode = TextServer.AUTOWRAP_OFF
		amt.add_theme_font_override("font", ThemeBuilder.font_display())
		amt.add_theme_color_override("font_color", Color("b07a12"))
		rw.add_child(amt)
		v.add_child(rw)
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
			_action(UI.t("SELL") + " +%d" % db.sell_value(id), "coins:1", func():
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
	_action(UI.t("UNDO"), "coins:1", func():
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
	ic.id = "coins:1"
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
			ItemArt.draw_3d(self, id, r.grow(-size.x * 0.06))
		if check:
			var p := Vector2(size.x * 0.8, size.y * 0.2)
			draw_circle(p, size.x * 0.16, Color.WHITE, true, -1, true)
			draw_circle(p, size.x * 0.13, Color("4fb36a"), true, -1, true)
			draw_polyline(PackedVector2Array([p + Vector2(-size.x * 0.06, 0), p + Vector2(-size.x * 0.01, size.x * 0.05), p + Vector2(size.x * 0.07, -size.x * 0.05)]), Color.WHITE, maxf(2.0, size.x * 0.04), true)


## Level badge: a blue gem-like disc with a gold star, the level and an XP ring.
class LevelBadge extends Control:
	var level := 1
	var progress := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0, r * 0.08), r, Color(0.05, 0.2, 0.35, 0.25), true, -1, true)
		draw_circle(c, r, Color.WHITE, true, -1, true)
		draw_arc(c, r * 0.87, -PI * 0.5, -PI * 0.5 + TAU, 48, Color("dfe8ee"), r * 0.15, true)
		if progress > 0.0:
			draw_arc(c, r * 0.87, -PI * 0.5, -PI * 0.5 + TAU * clampf(progress, 0.0, 1.0), 48, Color("ffbf2e"), r * 0.15, true)
		draw_circle(c, r * 0.72, Color("2f7fd6"), true, -1, true)
		draw_circle(c + Vector2(-r * 0.1, -r * 0.12), r * 0.56, Color("4d9bf0"), true, -1, true)
		var p := PackedVector2Array()
		for k in 10:
			var a := -PI * 0.5 + TAU * k / 10.0
			p.append(c + Vector2(cos(a), sin(a)) * r * (0.6 if k % 2 == 0 else 0.3))
		draw_colored_polygon(p, Color("ffc93a"))
		var f := ThemeBuilder.font_display()
		var fs := int(r * 0.6)
		var t := str(level)
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string_outline(f, c + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(r * 0.14), Color("9a5a00"))
		draw_string(f, c + Vector2(-w * 0.5, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


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
		var horizon := h * 0.24
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
