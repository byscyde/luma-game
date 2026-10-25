class_name TestCase
extends RefCounted
## Minimal test base class. Methods named test_* are run by tests/run_tests.gd.
## A test fails if any assertion fails OR any engine/script error is logged
## while it runs.

var failures: Array[String] = []
var tree: SceneTree  ## set by the runner; integration tests may add nodes to it


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func fail(msg: String) -> void:
	failures.append(msg)


func assert_true(cond: bool, msg: String = "expected true") -> void:
	if not cond:
		fail(msg)


func assert_false(cond: bool, msg: String = "expected false") -> void:
	if cond:
		fail(msg)


func assert_eq(actual, expected, msg: String = "") -> void:
	if typeof(actual) != typeof(expected) and not (_is_num(actual) and _is_num(expected)):
		fail("%s expected %s (%s) got %s (%s)" % [msg, str(expected), type_string(typeof(expected)), str(actual), type_string(typeof(actual))])
	elif actual != expected:
		fail("%s expected %s got %s" % [msg, str(expected), str(actual)])


func assert_ne(actual, unexpected, msg: String = "") -> void:
	if actual == unexpected:
		fail("%s did not expect %s" % [msg, str(unexpected)])


func assert_has(container, item, msg: String = "") -> void:
	if not container.has(item):
		fail("%s expected %s to contain %s" % [msg, str(container), str(item)])


func assert_not_null(v, msg: String = "expected non-null") -> void:
	if v == null:
		fail(msg)


func _is_num(v) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT


## Waits a number of frames (integration tests).
func frames(n: int = 1) -> void:
	for i in n:
		await tree.process_frame


## Helper used by many tests: board from rows of tokens.
static func board_from(rows: Array) -> PuzzleBoard:
	var l := LevelData.from_dict({"id": "t", "grid": rows})
	return l.build_board()
