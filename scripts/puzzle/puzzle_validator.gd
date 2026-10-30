class_name PuzzleValidator
extends RefCounted
## Decides completion and optional objectives purely from logical state.


## Returns {solved, objectives: [{type, label, met, value?}], optional_met: int}
static func evaluate(level: LevelData, board: PuzzleBoard, sim: WaterResult, moves: int) -> Dictionary:
	var solved := sim.all_required_reached
	var objectives: Array = []
	var met_count := 0
	for o in level.optional:
		var type: String = o.get("type", "")
		var met := false
		var entry := {"type": type}
		match type:
			LevelData.OBJ_MOVES_AT_MOST:
				var v := int(o.get("value", level.par_moves))
				entry["value"] = v
				met = solved and moves <= v
			LevelData.OBJ_NO_LEAKS:
				met = solved and sim.leak_count() == 0
			LevelData.OBJ_REACH_BONUS:
				var tid: String = o.get("target", "")
				entry["target"] = tid
				met = solved and sim.reached_bonus.has(tid)
		entry["met"] = met
		if met:
			met_count += 1
		objectives.append(entry)
	return {"solved": solved, "objectives": objectives, "optional_met": met_count}


static func objective_label(o: Dictionary) -> String:
	match o.get("type", ""):
		LevelData.OBJ_MOVES_AT_MOST:
			return tr_fmt("OBJ_MOVES", [int(o.get("value", 0))])
		LevelData.OBJ_NO_LEAKS:
			return TranslationServer.translate("OBJ_NO_LEAKS")
		LevelData.OBJ_REACH_BONUS:
			return TranslationServer.translate("OBJ_BONUS")
	return str(o.get("type", ""))


static func tr_fmt(key: String, args: Array) -> String:
	return TranslationServer.translate(key) % args
