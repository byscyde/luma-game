class_name Backdrop
extends Control
## Soft vertical gradient with drifting light motes. Used behind every screen.

var top_color := Palette.LAGOON_TOP
var bottom_color := Palette.LAGOON_BOTTOM
var motes := 18
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if not Game.reduced_motion():
		_t += delta
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([top_color, top_color, bottom_color, bottom_color]))
	# soft sunlight from above
	for i in 5:
		draw_circle(Vector2(w * 0.3, -h * 0.05), h * (0.18 + i * 0.09), Color(1.0, 0.98, 0.9, 0.05), true, -1, true)
	# gentle wave lines drifting across the lagoon
	for i in 9:
		var y := fmod(Painter.hash01(i * 17) * h + _t * 6.0 * (0.5 + Painter.hash01(i)), h)
		var x0 := Painter.hash01(i * 5) * w * 0.7
		var len := w * (0.12 + 0.18 * Painter.hash01(i * 3))
		var pts := PackedVector2Array()
		for k in 9:
			var u := k / 8.0
			pts.append(Vector2(x0 + u * len, y + sin(u * TAU + _t * 0.8 + i) * 4.0))
		draw_polyline(pts, Color(1, 1, 1, 0.22), 3.0, true)
	for i in motes:
		var sx := Painter.hash01(i * 13)
		var sy := Painter.hash01(i * 29 + 3)
		var a := 0.25 + 0.35 * (0.5 + 0.5 * sin(_t * 1.6 + i * 2.1))
		draw_circle(Vector2(sx * w, sy * h), 2.0 + 2.5 * Painter.hash01(i * 3), Color(1, 1, 1, a), true, -1, true)
