extends Control
## Boot: a brand moment, then straight into play for first-time players
## (no menu before the first puzzle) or the menu for returning players.

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(Backdrop.new())
	var title := UI.label("LUMA", "TitleLabel", 150, HORIZONTAL_ALIGNMENT_CENTER)
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(title)
	title.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(title, "modulate:a", 1.0, 0.1 if Game.reduced_motion() else 0.5)
	tw.tween_interval(0.1 if Game.reduced_motion() else 0.5)
	await tw.finished
	route()


static func first_scene() -> Dictionary:
	var first: String = Game.content.level_order[0] if not Game.content.level_order.is_empty() else ""
	if first != "" and not Game.progression.is_completed(first):
		return {"scene": "gameplay", "params": {"level_id": first}}
	return {"scene": "menu", "params": {}}


func route() -> void:
	var r := first_scene()
	Router.go(r["scene"], r["params"])
