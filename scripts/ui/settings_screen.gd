extends Control
## Settings: audio, haptics, reduced motion, theme, FPS counter, analytics
## opt-out, cloud save and sign-in, reset progress.

const PROVIDER_NAMES := {"apple": "Apple", "google": "Google", "facebook": "Facebook"}

var _confirm: Control
var _cloud_box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Backdrop.new())
	var margin := UI.safe_margin(self, 22)
	var page := ScrollContainer.new()
	page.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(page)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 16)
	page.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	col.add_child(top)
	var back := UI.round_button("back", UI.t("BACK"))
	back.name = "BackButton"
	back.pressed.connect(func(): Router.go("menu"))
	top.add_child(back)
	var title := UI.label(UI.t("SETTINGS"), "HeadingLabel", 44)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	col.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	card.add_child(v)
	v.add_child(_slider(UI.t("MUSIC"), "music_volume"))
	v.add_child(_slider(UI.t("SOUNDS"), "sfx_volume"))
	v.add_child(_toggle(UI.t("HAPTICS"), "haptics"))
	v.add_child(_toggle(UI.t("REDUCED_MOTION"), "reduced_motion"))
	v.add_child(_theme_picker())
	v.add_child(_toggle(UI.t("SHOW_FPS"), "show_fps"))
	v.add_child(_toggle(UI.t("ANALYTICS"), "analytics"))
	v.add_child(UI.label(UI.t("ANALYTICS_NOTE"), "CaptionLabel", 22))

	var cloud_card := PanelContainer.new()
	cloud_card.name = "CloudCard"
	cloud_card.theme_type_variation = "Card"
	col.add_child(cloud_card)
	_cloud_box = VBoxContainer.new()
	_cloud_box.add_theme_constant_override("separation", 12)
	cloud_card.add_child(_cloud_box)
	_build_cloud()
	Cloud.status_changed.connect(_build_cloud)
	Cloud.providers_changed.connect(_build_cloud)

	col.add_child(UI.spacer(0, true))
	var reset := UI.button(UI.t("RESET_PROGRESS"), "reset", "GhostButton", Vector2(0, 88))
	reset.name = "ResetProgressButton"
	reset.pressed.connect(_ask_reset)
	col.add_child(reset)
	var lic := UI.button(UI.t("LICENCES"), "", "GhostButton", Vector2(0, 76))
	lic.name = "LicencesButton"
	lic.pressed.connect(_show_licences)
	col.add_child(lic)
	col.add_child(UI.label(UI.t("CREDITS"), "LightCaption", 20, HORIZONTAL_ALIGNMENT_CENTER))


func _build_cloud() -> void:
	if not is_instance_valid(_cloud_box):
		return
	for c in _cloud_box.get_children():
		c.queue_free()
	_cloud_box.add_child(UI.label(UI.t("CLOUD_SAVE"), "", 30))
	var status_key := "CLOUD_STATUS_" + (Cloud.status if Cloud.enabled else Cloud.OFF).to_upper()
	var status := UI.label(Cloud.last_error if Cloud.last_error != "" else UI.t(status_key), "CaptionLabel", 22)
	status.name = "CloudStatus"
	_cloud_box.add_child(status)
	if not Cloud.enabled:
		return
	var linked: Array = Cloud.state["providers"]
	if linked.is_empty():
		_cloud_box.add_child(UI.label(UI.t("CLOUD_GUEST_NOTE"), "CaptionLabel", 22))
	for prov in linked:
		var row := HBoxContainer.new()
		row.add_child(UI.label(UI.t("CLOUD_SIGNED_IN_AS") % PROVIDER_NAMES.get(prov, prov), "", 24))
		row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var un := UI.button(UI.t("CLOUD_UNLINK") % PROVIDER_NAMES.get(prov, prov), "", "GhostButton", Vector2(0, 64))
		un.pressed.connect(func(): Cloud.unlink(prov))
		row.add_child(un)
		_cloud_box.add_child(row)
	for prov in NativeAuth.providers():
		if linked.has(prov):
			continue
		var b := UI.button(UI.t("CLOUD_SIGN_IN_" + str(prov).to_upper()), "", "PrimaryButton" if prov == "apple" else "SecondaryButton", Vector2(0, 88))
		b.name = "SignIn_" + prov
		b.pressed.connect(func(): Cloud.sign_in(prov))
		_cloud_box.add_child(b)
	var sync := UI.button(UI.t("CLOUD_SYNC_NOW"), "", "GhostButton", Vector2(0, 72))
	sync.name = "CloudSyncNow"
	sync.disabled = Cloud.status == Cloud.SYNCING or Cloud.status == Cloud.WAITING
	sync.pressed.connect(func(): Cloud.check_cloud())
	_cloud_box.add_child(sync)
	if str(Cloud.state["token"]) != "":
		var del := UI.button(UI.t("CLOUD_DELETE_ACCOUNT"), "", "GhostButton", Vector2(0, 72))
		del.name = "CloudDeleteAccount"
		del.pressed.connect(_ask_delete_account)
		_cloud_box.add_child(del)


func _ask_delete_account() -> void:
	_confirm = Control.new()
	_confirm.name = "ConfirmDeleteAccount"
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(cc)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(600, 0)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	v.add_child(UI.label(UI.t("CLOUD_DELETE_TITLE"), "HeadingLabel", 38, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(UI.t("CLOUD_DELETE_BODY"), "CaptionLabel", 26, HORIZONTAL_ALIGNMENT_CENTER))
	var yes := UI.button(UI.t("CLOUD_DELETE_YES"), "", "PrimaryButton", Vector2(0, 96))
	yes.pressed.connect(func():
		await Cloud.delete_account()
		if is_instance_valid(_confirm):
			_confirm.queue_free())
	v.add_child(yes)
	var no := UI.button(UI.t("CANCEL"), "", "SecondaryButton", Vector2(0, 88))
	no.pressed.connect(func(): _confirm.queue_free())
	v.add_child(no)


func _slider(text: String, key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_child(UI.label(text, "", 30))
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = float(Game.setting(key))
	s.custom_minimum_size = Vector2(0, 52)
	s.name = "Slider_" + key
	if "accessibility_name" in s:
		s.set("accessibility_name", text)
	s.value_changed.connect(func(val): Game.set_setting(key, val))
	s.drag_ended.connect(func(_c): Audio.play("tap"))
	box.add_child(s)
	return box


## System / Light / Dark segmented choice; "System" follows the device.
func _theme_picker() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(UI.label(UI.t("THEME"), "", 30))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	var current := str(Game.setting("theme"))
	for mode in ["system", "light", "dark"]:
		var b := UI.button(UI.t("THEME_" + mode.to_upper()), "",
			"PrimaryButton" if mode == current else "SecondaryButton", Vector2(0, 76))
		b.name = "Theme_" + mode
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(func():
			if str(Game.setting("theme")) != mode:
				Game.set_setting("theme", mode)
				Router.reload())
		row.add_child(b)
	return box


func _toggle(text: String, key: String) -> CheckButton:
	var t := CheckButton.new()
	t.text = text
	t.button_pressed = bool(Game.setting(key))
	t.custom_minimum_size = Vector2(0, 64)
	t.name = "Toggle_" + key
	t.toggled.connect(func(on):
		Game.set_setting(key, on)
		Audio.play("ui_click"))
	return t


func _ask_reset() -> void:
	_confirm = Control.new()
	_confirm.name = "ConfirmReset"
	_confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(cc)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(600, 0)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	card.add_child(v)
	v.add_child(UI.label(UI.t("RESET_CONFIRM_TITLE"), "HeadingLabel", 38, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(UI.t("RESET_CONFIRM_BODY"), "CaptionLabel", 26, HORIZONTAL_ALIGNMENT_CENTER))
	var yes := UI.button(UI.t("RESET_CONFIRM_YES"), "reset", "PrimaryButton", Vector2(0, 96))
	yes.name = "ConfirmYes"
	yes.pressed.connect(func():
		Game.reset_progress()
		_confirm.queue_free()
		Router.go("menu"))
	v.add_child(yes)
	var no := UI.button(UI.t("CANCEL"), "", "SecondaryButton", Vector2(0, 88))
	no.name = "ConfirmNo"
	no.pressed.connect(func(): _confirm.queue_free())
	v.add_child(no)


func _show_licences() -> void:
	var overlay := Control.new()
	overlay.name = "LicencesOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var margin := UI.safe_margin(overlay, 32)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	margin.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(UI.label(UI.t("LICENCES"), "HeadingLabel", 36))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var text := "Nunito font\nCopyright 2014 The Nunito Project Authors (https://github.com/googlefonts/nunito)\n" \
		+ "Licensed under the SIL Open Font License, Version 1.1.\n\n" \
		+ "Fredoka font\nCopyright 2016 The Fredoka Project Authors (https://github.com/hafontia/Fredoka-One)\n" \
		+ "Licensed under the SIL Open Font License, Version 1.1.\n\n" \
		+ "Godot Engine\n" + Engine.get_license_text()
	var body := UI.label(text, "CaptionLabel", 20)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var close := UI.button(UI.t("CLOSE"), "", "PrimaryButton", Vector2(0, 92))
	close.name = "CloseLicences"
	close.pressed.connect(overlay.queue_free)
	v.add_child(close)
