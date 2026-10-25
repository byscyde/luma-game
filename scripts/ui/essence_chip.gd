class_name EssenceChip
extends PanelContainer
## Live essence counter. A method connection (not a lambda) so the signal is
## released automatically when the chip is freed with its screen.

var _label: Label


func _init() -> void:
	theme_type_variation = "ChipPanel"
	tooltip_text = UI.t("ESSENCE")
	if "accessibility_name" in self:
		set("accessibility_name", UI.t("ESSENCE"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	row.add_child(UI.icon("leaf", Palette.LEAF_LIGHT, 30))
	_label = UI.label(str(Game.progression.essence()), "LightLabel", 30)
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(_label)


func _ready() -> void:
	Game.essence_changed.connect(_on_essence_changed)


func _on_essence_changed(v: int) -> void:
	_label.text = str(v)
