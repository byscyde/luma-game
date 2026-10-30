extends Node
## Privacy-conscious analytics abstraction.
##
## There is NO network backend: events are kept in a local, bounded queue
## (user://analytics_queue.jsonl) so a future, disclosed provider can be plugged
## in behind `_dispatch`. Only whitelisted, non-identifying game parameters are
## recorded. Disabled entirely when the player turns analytics off.

const QUEUE_PATH := "user://analytics_queue.jsonl"
const MAX_QUEUE := 500
const EVENTS := [
	"app_started", "tutorial_started", "tutorial_completed", "level_started",
	"level_completed", "level_failed", "level_restarted", "hint_used",
	"island_restoration_completed", "area_unlocked", "decoration_unlocked",
	"session_ended", "save_recovered", "achievement_unlocked",
	"merge_order_served", "merge_task_done",
]
const ALLOWED_PARAMS := [
	"level_id", "area_id", "moves", "par", "optional_met", "duration_s",
	"hint_count", "undo_count", "decoration_id", "achievement_id", "status",
	"session_s", "levels_completed", "build", "items", "task_id",
]

var enabled := true
var recent: Array = []  ## in-memory copy for debugging / tests
var _session_start := 0


func _ready() -> void:
	_session_start = Time.get_ticks_msec()


func log_event(event_name: String, params: Dictionary = {}) -> void:
	if not enabled:
		return
	if not EVENTS.has(event_name):
		push_warning("Analytics: unknown event %s" % event_name)
		return
	var clean := {}
	for k in params:
		if ALLOWED_PARAMS.has(k):
			var v = params[k]
			if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME]:
				clean[k] = v
	var ev := {"e": event_name, "t": int(Time.get_unix_time_from_system()), "p": clean}
	recent.append(ev)
	if recent.size() > 100:
		recent.pop_front()
	_dispatch(ev)


func session_seconds() -> int:
	return int((Time.get_ticks_msec() - _session_start) / 1000)


func clear_queue() -> void:
	recent.clear()
	if FileAccess.file_exists(QUEUE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(QUEUE_PATH))


func _dispatch(ev: Dictionary) -> void:
	var f: FileAccess
	if FileAccess.file_exists(QUEUE_PATH):
		f = FileAccess.open(QUEUE_PATH, FileAccess.READ_WRITE)
		if f and f.get_length() > MAX_QUEUE * 256:
			f.close()
			f = FileAccess.open(QUEUE_PATH, FileAccess.WRITE)  # simple bound: rotate
		elif f:
			f.seek_end()
	else:
		f = FileAccess.open(QUEUE_PATH, FileAccess.WRITE)
	if f:
		f.store_line(JSON.stringify(ev))
