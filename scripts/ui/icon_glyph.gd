class_name IconGlyph
extends Control
## Draws a Painter vector icon scaled to its rect.

@export var kind := "leaf":
	set(v):
		kind = v
		queue_redraw()
@export var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()


func _draw() -> void:
	Painter.icon(self, kind, Rect2(Vector2.ZERO, size), color)
