extends Node
## Headless test runner. Run with:
##   godot --headless --path . res://tests/run_tests.tscn -- [--filter=substr] [--junit=path]
## Exit code is 0 only if every test passed and at least one test ran.

class ErrorCounter extends Logger:
	var count := 0
	var messages: Array[String] = []
	var mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtrace: Array[ScriptBacktrace]) -> void:
		# Warnings are informative only; errors fail the running test.
		if error_type == Logger.ERROR_TYPE_WARNING:
			return
		mutex.lock()
		count += 1
		messages.append("%s:%d %s %s %s" % [file, line, function, code, rationale])
		mutex.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass

	func take() -> Array[String]:
		mutex.lock()
		var m := messages.duplicate()
		messages.clear()
		count = 0
		mutex.unlock()
		return m


var _errors := ErrorCounter.new()


func _ready() -> void:
	# Let the root finish adding autoloads/scenes before tests add nodes to it.
	await get_tree().process_frame
	OS.add_logger(_errors)
	var args := _parse_args()
	var files := _collect("res://tests")
	files.sort()
	var total := 0
	var failed := 0
	var cases: Array = []
	var t0 := Time.get_ticks_msec()
	for path in files:
		var script: GDScript = load(path)
		if script == null:
			print("LOAD FAIL ", path)
			failed += 1
			total += 1
			cases.append({"suite": path, "name": "<load>", "ok": false, "msgs": ["could not load"], "ms": 0})
			continue
		var methods: Array[String] = []
		for m in script.get_script_method_list():
			var n: String = m["name"]
			if n.begins_with("test_") and not methods.has(n):
				methods.append(n)
		for m in methods:
			if args.filter != "" and not (path + "::" + m).contains(args.filter):
				continue
			total += 1
			_errors.take()
			var inst: TestCase = script.new()
			inst.tree = get_tree()
			var start := Time.get_ticks_msec()
			await inst.before_each()
			await inst.call(m)
			await inst.after_each()
			var msgs: Array[String] = inst.failures.duplicate()
			for e in _errors.take():
				msgs.append("engine error: " + e)
			var ok := msgs.is_empty()
			if not ok:
				failed += 1
			var ms := Time.get_ticks_msec() - start
			cases.append({"suite": path.get_file().get_basename(), "name": m, "ok": ok, "msgs": msgs, "ms": ms})
			print("%s %s::%s (%d ms)" % ["PASS" if ok else "FAIL", path.get_file(), m, ms])
			for msg in msgs:
				print("    - ", msg)
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("\n%d tests, %d passed, %d failed in %.2fs" % [total, total - failed, failed, secs])
	if args.junit != "":
		_write_junit(args.junit, cases, secs)
	OS.remove_logger(_errors)
	get_tree().quit(0 if failed == 0 and total > 0 else 1)


func _parse_args() -> Dictionary:
	var out := {"filter": "", "junit": ""}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--filter="):
			out.filter = a.substr(9)
		elif a.begins_with("--junit="):
			out.junit = a.substr(8)
	return out


func _collect(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_collect(dir_path.path_join(sub)))
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and dir_path != "res://tests":
			out.append(dir_path.path_join(f))
	return out


func _write_junit(path: String, cases: Array, secs: float) -> void:
	var fails := 0
	for c in cases:
		if not c.ok:
			fails += 1
	var xml := '<?xml version="1.0" encoding="UTF-8"?>\n'
	xml += '<testsuite name="luma" tests="%d" failures="%d" time="%.3f">\n' % [cases.size(), fails, secs]
	for c in cases:
		xml += '  <testcase classname="%s" name="%s" time="%.3f">' % [c.suite, c.name, c.ms / 1000.0]
		if not c.ok:
			xml += '<failure message="%s"/>' % "\n".join(c.msgs).xml_escape(true)
		xml += '</testcase>\n'
	xml += '</testsuite>\n'
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(xml)
