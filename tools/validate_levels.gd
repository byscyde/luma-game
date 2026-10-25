extends SceneTree
## Content validation for every shipped level, using the game's own model.
##   godot --headless --path . --script res://tools/validate_levels.gd -- [--report=path]
## Exits 1 if any level has an error. Writes a JSON report for
## tools/generate_level_report.py.

const BUDGET := 400000


func _init() -> void:
	var report_path := "res://build/reports/levels.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--report="):
			report_path = a.substr(9)
	var db := ContentDB.load_default()
	var errors: Array[String] = []
	var warnings: Array[String] = []
	for e in db.errors:
		errors.append("content: " + e)
	var levels_out: Array = []
	var level_ids := {}
	var essence_running := 0
	var unlock_running := 0
	for area_id in db.area_order:
		var area: Dictionary = db.areas[area_id]
		unlock_running += int(area.get("cost", 0))
		if essence_running < unlock_running:
			errors.append("economy: area %s costs %d cumulative, only %d base essence earned before it" % [area_id, unlock_running, essence_running])
		for lid in area["levels"]:
			var level := db.get_level(lid)
			if level == null:
				continue
			essence_running += int(level.rewards.get("essence", ProgressionModel.BASE_ESSENCE))
			levels_out.append(_check_level(db, level, errors, warnings))
			level_ids[lid] = true
	# restoration coverage: every object stage must be granted by some level
	var granted := {}
	for lid in db.level_order:
		for r in db.get_level(lid).restores:
			var oid: String = r.get("object", "")
			if not db.objects.has(oid):
				errors.append("%s restores unknown object %s" % [lid, oid])
				continue
			granted[oid] = maxi(int(granted.get(oid, 0)), int(r.get("stage", 1)))
	for oid in db.objects:
		var need := int(db.objects[oid].get("stages", 1))
		if int(granted.get(oid, 0)) < need:
			errors.append("object %s reaches stage %d of %d: never fully restorable" % [oid, int(granted.get(oid, 0)), need])
	var discovered := {}
	for lid in db.level_order:
		var d: String = db.get_level(lid).rewards.get("discovery", "")
		if d != "":
			if not db.decorations.has(d):
				errors.append("%s grants unknown decoration %s" % [lid, d])
			if discovered.has(d):
				errors.append("decoration %s granted twice" % d)
			discovered[d] = true
	for did in db.decorations:
		if not discovered.has(did):
			errors.append("decoration %s can never be discovered" % did)
	var out := {
		"generated_at": Time.get_datetime_string_from_system(true),
		"engine": Engine.get_version_info()["string"],
		"level_count": levels_out.size(),
		"errors": errors,
		"warnings": warnings,
		"levels": levels_out,
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(report_path).get_base_dir())
	var f := FileAccess.open(report_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(out, "  "))
	for l in levels_out:
		print("%-8s %-24s %dx%d  min=%-3s par=%-3s bonus=%-5s sealed=%-5s exp=%s %s" % [
			l.id, l.name, l.width, l.height, str(l.min_moves), str(l.par), str(l.bonus_min), str(l.no_leaks_min), str(l.expansions), l.status])
	for w in warnings:
		print("WARNING ", w)
	for e in errors:
		print("ERROR ", e)
	print("%d levels, %d errors, %d warnings" % [levels_out.size(), errors.size(), warnings.size()])
	quit(1 if not errors.is_empty() or levels_out.is_empty() else 0)


func _check_level(db: ContentDB, level: LevelData, errors: Array[String], warnings: Array[String]) -> Dictionary:
	var info := {"id": level.id, "name": level.name, "width": level.width, "height": level.height,
		"mechanic": level.mechanic, "difficulty": level.difficulty, "status": "", "min_moves": null,
		"par": level.optional_value(LevelData.OBJ_MOVES_AT_MOST, 0), "bonus_min": null,
		"no_leaks_min": null, "expansions": 0, "tiles": {}}
	for e in level.errors:
		errors.append("%s: %s" % [level.id, e])
	if not level.errors.is_empty():
		info.status = "invalid"
		return info
	var board := level.build_board()
	for t in board.tiles:
		info.tiles[t.type] = int(info.tiles.get(t.type, 0)) + 1
	if board.sources().is_empty():
		errors.append("%s: no water source" % level.id)
	if board.target_ids(false).is_empty():
		errors.append("%s: no required target" % level.id)
	var ids := {}
	for tid in board.target_ids(true):
		if ids.has(tid):
			errors.append("%s: duplicate target id %s" % [level.id, tid])
		ids[tid] = true
	for k in level.targets:
		if not ids.has(k):
			errors.append("%s: target metadata for missing target %s" % [level.id, k])
	for link in board.switches:
		var has_gate := false
		for t in board.tiles:
			if t.is_gate() and t.link == link:
				has_gate = true
		if not has_gate:
			errors.append("%s: switch %s controls no gate" % [level.id, link])
	for t in board.tiles:
		if t.is_gate() and not board.switches.has(t.link):
			errors.append("%s: gate link %s has no switch" % [level.id, t.link])
	if WaterSimulation.simulate(board).all_required_reached:
		errors.append("%s: already solved before the first move" % level.id)
	var r := PuzzleSolver.solve(board, BUDGET)
	info.expansions = r.get("expansions", 0)
	info.status = r["status"]
	if r["status"] == PuzzleSolver.STATUS_SOLVED:
		info.min_moves = r["moves"]
		# replay the solver's taps through the real board rules
		var replay := level.build_board()
		for p in r["taps"]:
			replay.tap(p)
		if not WaterSimulation.simulate(replay).all_required_reached:
			errors.append("%s: solver solution does not replay" % level.id)
	elif r["status"] == PuzzleSolver.STATUS_UNVERIFIED and level.validation.get("status", "") == "approved_unverified" and str(level.validation.get("reason", "")) != "":
		warnings.append("%s: unverified within budget, approved: %s" % [level.id, level.validation["reason"]])
	else:
		errors.append("%s: solver status %s" % [level.id, r["status"]])
	if info.min_moves != null:
		if level.has_optional(LevelData.OBJ_MOVES_AT_MOST) and info.par < int(info.min_moves):
			errors.append("%s: move target %d is below the minimum %d" % [level.id, info.par, info.min_moves])
		if int(info.min_moves) <= 1 and db.level_number(level.id) > 2:
			warnings.append("%s: trivial (min %d moves)" % [level.id, info.min_moves])
	if level.has_optional(LevelData.OBJ_REACH_BONUS):
		var rb := PuzzleSolver.solve(board, BUDGET, PuzzleSolver.GOAL_WITH_BONUS)
		if rb["status"] == PuzzleSolver.STATUS_SOLVED:
			info.bonus_min = rb["moves"]
		else:
			errors.append("%s: bonus objective not achievable (%s)" % [level.id, rb["status"]])
	if level.has_optional(LevelData.OBJ_NO_LEAKS):
		var rn := PuzzleSolver.solve(board, BUDGET, PuzzleSolver.GOAL_NO_LEAKS)
		if rn["status"] == PuzzleSolver.STATUS_SOLVED:
			info.no_leaks_min = rn["moves"]
		else:
			errors.append("%s: no-spill objective not achievable (%s)" % [level.id, rn["status"]])
	for o in level.optional:
		if o.get("type", "") == LevelData.OBJ_REACH_BONUS and not ids.has(o.get("target", "")):
			errors.append("%s: bonus objective references missing target %s" % [level.id, o.get("target", "")])
	if level.restores.is_empty():
		warnings.append("%s: restores nothing on the island" % level.id)
	return info
