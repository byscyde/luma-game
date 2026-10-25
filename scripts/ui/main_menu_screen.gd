extends Control
## Title screen: living island backdrop + four real destinations.

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(Backdrop.new())
	var island := IslandView.new()
	island.interactive = false
	island.set_anchors_preset(Control.PRESET_FULL_RECT)
	island.offset_top = 330
	island.offset_bottom = -440
	add_child(island)
	var margin := UI.safe_margin(self, 28)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.add_child(UI.spacer(40))
	var title := UI.label("LUMA", "TitleLabel", 0, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_font_size_override("font_size", 120)
	col.add_child(title)
	col.add_child(UI.label(UI.t("SUBTITLE"), "LightCaption", 30, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UI.spacer(0, true))

	var next := Game.progression.next_level_id()
	var play_text := UI.t("PLAY")
	if next != "" and Game.progression.completed_count() > 0:
		play_text = UI.t("CONTINUE_LEVEL") % Game.content.level_number(next)
	var play := UI.button(play_text, "play", "PrimaryButton", Vector2(0, 112))
	play.name = "PlayButton"
	play.pressed.connect(_on_play)
	col.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	col.add_child(row)
	var islands := UI.button(UI.t("ISLANDS"), "island", "SecondaryButton", Vector2(0, 96))
	islands.name = "IslandsButton"
	islands.pressed.connect(func(): Router.go("island"))
	var coll := UI.button(UI.t("COLLECTION"), "collection", "SecondaryButton", Vector2(0, 96))
	coll.name = "CollectionButton"
	coll.pressed.connect(func(): Router.go("collection"))
	for b in [islands, coll]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	var settings := UI.button(UI.t("SETTINGS"), "gear", "GhostButton", Vector2(0, 88))
	settings.name = "SettingsButton"
	settings.pressed.connect(func(): Router.go("settings"))
	col.add_child(settings)
	col.add_child(UI.label("v%s · SCYDE" % ProjectSettings.get_setting("application/config/version", ""), "LightCaption", 20, HORIZONTAL_ALIGNMENT_CENTER))
	Audio.play_music()
	play.grab_focus.call_deferred()


func _on_play() -> void:
	var next := Game.progression.next_level_id()
	if next == "" or not Game.progression.is_level_unlocked(next):
		Router.go("island")  # all done, or the next area must be awakened first
	else:
		Router.go("gameplay", {"level_id": next})
