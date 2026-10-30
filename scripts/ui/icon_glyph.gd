class_name IconGlyph
extends Control
## Draws a UI icon tinted with `color`. Uses the SVG set in
## assets/icons/ui when available, else falls back to Painter shapes.

const ICON_DIR := "res://assets/icons/ui/"

@export var kind := "leaf":
	set(v):
		kind = v
		_tex = null
		queue_redraw()
@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()

var _tex: Texture2D


static func texture_for(k: String) -> Texture2D:
	var path := ICON_DIR + k + ".svg"
	return load(path) if ResourceLoader.exists(path) else null


func _draw() -> void:
	if _tex == null:
		_tex = texture_for(kind)
	if _tex:
		draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false, color)
	else:
		Painter.icon(self, kind, Rect2(Vector2.ZERO, size), color)
