extends Control
## Title screen: the living 3D island fills the screen, the wordmark floats
## above it, and a bottom sheet holds the four real destinations.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var island := IslandView.new()
	island.interactive = false
	island.set_anchors_preset(Control.PRESET_FULL_RECT)
	island.top_inset = 300.0
	island.bottom_inset = 430.0
	add_child(island)
	var margin := UI.safe_margin(self, 26)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 0)
	margin.add_child(col)
	col.add_child(UI.spacer(36))
	var title := UI.label("LUMA", "TitleLabel", 140, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	col.add_child(title)
	var tag := PanelContainer.new()
	tag.theme_type_variation = "ChipPanel"
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var sub := UI.label(UI.t("SUBTITLE").to_upper(), "KickerLabel", 26, HORIZONTAL_ALIGNMENT_CENTER)
	sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	tag.add_child(sub)
	col.add_child(tag)
	col.add_child(UI.spacer(0, true))

	var sheet := PanelContainer.new()
	sheet.theme_type_variation = "Sheet"
	col.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	sheet.add_child(v)
	var next := Game.progression.next_level_id()
	var play_text := UI.t("PLAY")
	if next != "" and Game.progression.completed_count() > 0:
		play_text = UI.t("CONTINUE_LEVEL") % Game.content.level_number(next)
	if Game.merge_unlocked():
		play_text = UI.t("HARBOUR")
	var play := UI.button(play_text, "play", "PrimaryButton", Vector2(0, 116))
	play.name = "PlayButton"
	play.pressed.connect(_on_play)
	v.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var islands := UI.button(UI.t("ISLANDS"), "leaf", "SecondaryButton", Vector2(0, 98))
	islands.name = "IslandsButton"
	islands.pressed.connect(func(): Router.go("island"))
	var coll := UI.button(UI.t("COLLECTION"), "collection", "SecondaryButton", Vector2(0, 98))
	coll.name = "CollectionButton"
	coll.pressed.connect(func(): Router.go("collection"))
	for b in [islands, coll]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var bottom := HBoxContainer.new()
	v.add_child(bottom)
	var ver := UI.label("v%s · SCYDE" % ProjectSettings.get_setting("application/config/version", ""), "CaptionLabel", 20)
	ver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ver.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(ver)
	var settings := UI.round_button("gear", UI.t("SETTINGS"))
	settings.name = "SettingsButton"
	settings.pressed.connect(func(): Router.go("settings"))
	bottom.add_child(settings)
	Audio.play_music()
	play.grab_focus.call_deferred()


func _on_play() -> void:
	if Game.merge_unlocked():
		Router.go("merge")
		return
	var next := Game.progression.next_level_id()
	if next == "" or not Game.progression.is_level_unlocked(next):
		Router.go("island")  # all done, or the next area must be awakened first
	else:
		Router.go("gameplay", {"level_id": next})
