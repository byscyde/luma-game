class_name Backdrop
extends Control
## Soft vertical gradient with drifting light motes. Used behind every screen.

var top_color := Palette.DEEP
var bottom_color := Palette.NIGHT
var motes := 18
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not Game.reduced_motion():
		_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	# warm glow from above
	for i in 6:
		draw_circle(Vector2(w * 0.5, -h * 0.1), h * (0.25 + i * 0.08), Color(1.0, 0.9, 0.7, 0.025), true, -1, true)
	for i in motes:
		var sx := Painter.hash01(i * 13)
		var sy := Painter.hash01(i * 29 + 3)
		var sp := 0.01 + 0.02 * Painter.hash01(i * 7)
		var y := fmod(sy - _t * sp + 1.0, 1.0) * h
		var x := sx * w + sin(_t * 0.5 + i) * 12.0
		var a := 0.12 + 0.18 * (0.5 + 0.5 * sin(_t * 1.3 + i))
		draw_circle(Vector2(x, y), 2.0 + 3.0 * Painter.hash01(i * 3), Color(1.0, 0.95, 0.75, a), true, -1, true)
