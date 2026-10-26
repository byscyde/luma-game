extends CanvasLayer
## Scene navigation with a soft fade. Parameters for the next scene are passed
## through `params` and read by the scene in _ready().

const SCENES := {
	"menu": "res://scenes/menus/main_menu.tscn",
	"gameplay": "res://scenes/gameplay/gameplay.tscn",
	"island": "res://scenes/island/island.tscn",
	"collection": "res://scenes/menus/collection.tscn",
	"settings": "res://scenes/menus/settings.tscn",
}

var params: Dictionary = {}
var current := ""
## Tests set this so navigation is recorded instead of replacing the scene.
var dry_run := false
var last_request: Dictionary = {}
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.12, 0.15, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func go(scene_key: String, p_params: Dictionary = {}) -> void:
	if not SCENES.has(scene_key):
		push_error("Router: unknown scene " + scene_key)
		return
	if dry_run:
		last_request = {"scene": scene_key, "params": p_params}
		params = p_params
		return
	if _busy:
		return
	_busy = true
	params = p_params
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var dur := 0.08 if Game.reduced_motion() else 0.22
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, dur)
	await tw.finished
	current = scene_key
	get_tree().change_scene_to_file(SCENES[scene_key])
	await get_tree().process_frame
	await get_tree().process_frame
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, dur * 1.3)
	await tw2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


## Immediate change without fade (tests, boot).
func go_now(scene_key: String, p_params: Dictionary = {}) -> void:
	if dry_run:
		last_request = {"scene": scene_key, "params": p_params}
		params = p_params
		return
	params = p_params
	current = scene_key
	get_tree().change_scene_to_file(SCENES[scene_key])


## Rebuilds the current screen with the same parameters (theme change).
func reload() -> void:
	if dry_run or current == "" or _busy:
		return
	go(current, params)


func is_busy() -> bool:
	return _busy
