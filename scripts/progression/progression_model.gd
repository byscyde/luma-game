class_name ProgressionModel
extends RefCounted
## Progression rules over the "progress" section of the save. Every reward is
## applied idempotently: replaying a level can improve a record but never
## grants a one-time reward twice, and essence can never go negative.

const BASE_ESSENCE := 10
const OPTIONAL_ESSENCE := 5

var content: ContentDB
var p: Dictionary  ## the save's "progress" dictionary (mutated in place)


func _init(p_content: ContentDB, progress: Dictionary) -> void:
	content = p_content
	p = progress


# ---------------------------------------------------------------- queries

func is_completed(level_id: String) -> bool:
	return p["completed"].has(level_id)


func completed_count() -> int:
	return p["completed"].size()


func is_area_unlocked(area_id: String) -> bool:
	return p["areas_unlocked"].has(area_id)


func essence() -> int:
	return int(p["essence"])


func is_level_unlocked(level_id: String) -> bool:
	var level := content.get_level(level_id)
	if level == null or not is_area_unlocked(level.area):
		return false
	var idx := content.level_order.find(level_id)
	if idx <= 0:
		return true
	return is_completed(content.level_order[idx - 1])


## First level that is unlocked and not yet completed. "" when everything is done.
## If the next level sits in a still-locked area, returns that level anyway;
## callers check is_level_unlocked() to offer the area unlock instead.
func next_level_id() -> String:
	for id in content.level_order:
		if not is_completed(id):
			return id
	return ""


func area_complete(area_id: String) -> bool:
	for lid in content.areas[area_id].get("levels", []):
		if not is_completed(lid):
			return false
	return true


## {ok, reason} where reason in "", "already", "previous_area", "essence"
func can_unlock_area(area_id: String) -> Dictionary:
	if is_area_unlocked(area_id):
		return {"ok": false, "reason": "already"}
	var idx := content.area_order.find(area_id)
	if idx > 0 and not area_complete(content.area_order[idx - 1]):
		return {"ok": false, "reason": "previous_area"}
	var cost := int(content.areas[area_id].get("cost", 0))
	if essence() < cost:
		return {"ok": false, "reason": "essence", "missing": cost - essence()}
	return {"ok": true, "reason": ""}


func unlock_area(area_id: String) -> bool:
	if not can_unlock_area(area_id)["ok"]:
		return false
	p["essence"] = essence() - int(content.areas[area_id].get("cost", 0))
	p["areas_unlocked"].append(area_id)
	return true


func object_stage(object_id: String) -> int:
	return int(p["restoration"].get(object_id, 0))


func area_progress(area_id: String) -> float:
	var total := 0
	var have := 0
	for o in content.objects_in_area(area_id):
		total += int(o.get("stages", 1))
		have += mini(object_stage(o["id"]), int(o.get("stages", 1)))
	return 0.0 if total == 0 else float(have) / float(total)


func area_restored(area_id: String) -> bool:
	return area_progress(area_id) >= 1.0


func has_discovery(id: String) -> bool:
	return p["discoveries"].has(id)


func objective_count(type_id: String) -> int:
	return int(p["objective_counts"].get(type_id, 0))


func level_record(level_id: String) -> Dictionary:
	return p["completed"].get(level_id, {})


## Count of optional objectives ever met for a level.
func optional_met_count(level_id: String) -> int:
	return (level_record(level_id).get("optional", {}) as Dictionary).size()


# ---------------------------------------------------------------- mutation

## Applies a finished level. `evaluation` is PuzzleValidator.evaluate output.
## Returns a receipt describing exactly what changed (for UI + analytics).
func apply_level_result(level: LevelData, evaluation: Dictionary, moves: int) -> Dictionary:
	var receipt := {
		"level": level.id,
		"first_completion": false,
		"essence": 0,
		"new_optional": [],
		"restoration": [],
		"discoveries": [],
		"achievements": [],
		"best_moves": moves,
	}
	if not evaluation.get("solved", false):
		return receipt
	if not is_level_unlocked(level.id):
		push_warning("apply_level_result on locked level %s ignored" % level.id)
		return receipt
	var first := not is_completed(level.id)
	var rec: Dictionary = p["completed"].get(level.id, {"best_moves": moves, "optional": {}, "times": 0})
	rec["times"] = int(rec.get("times", 0)) + 1
	rec["best_moves"] = mini(int(rec.get("best_moves", moves)), moves)
	receipt["best_moves"] = rec["best_moves"]
	var gained := 0
	if first:
		receipt["first_completion"] = true
		gained += int(level.rewards.get("essence", BASE_ESSENCE))
	var objectives: Array = evaluation.get("objectives", [])
	for i in objectives.size():
		var o: Dictionary = objectives[i]
		# Keyed by objective identity (not index) so content edits stay safe.
		var key: String = o.get("type", "") + ":" + str(o.get("target", ""))
		if o.get("met", false) and not rec["optional"].has(key):
			rec["optional"][key] = true
			gained += int(level.rewards.get("optional_essence", OPTIONAL_ESSENCE))
			receipt["new_optional"].append(i)
			var counts: Dictionary = p["objective_counts"]
			counts[o["type"]] = int(counts.get(o["type"], 0)) + 1
	p["completed"][level.id] = rec
	if gained > 0:
		p["essence"] = essence() + gained
		p["essence_earned_total"] = int(p["essence_earned_total"]) + gained
	receipt["essence"] = gained
	# Restoration only ever moves forward.
	for r in level.restores:
		var oid: String = r.get("object", "")
		if not content.objects.has(oid):
			continue
		var max_stage := int(content.objects[oid].get("stages", 1))
		var target := mini(int(r.get("stage", 1)), max_stage)
		var current := object_stage(oid)
		if target > current:
			p["restoration"][oid] = target
			receipt["restoration"].append({"object": oid, "from": current, "to": target})
	var disc: String = level.rewards.get("discovery", "")
	if disc != "" and content.decorations.has(disc) and not has_discovery(disc):
		p["discoveries"].append(disc)
		receipt["discoveries"].append(disc)
	receipt["achievements"] = check_achievements()
	return receipt


func check_achievements() -> Array:
	var unlocked: Array = []
	for a in content.achievements:
		var aid: String = a["id"]
		if p["achievements"].has(aid):
			continue
		if _condition_met(a.get("condition", {})):
			p["achievements"].append(aid)
			unlocked.append(aid)
	return unlocked


func achievement_progress(a: Dictionary) -> Vector2i:
	var c: Dictionary = a.get("condition", {})
	var goal := int(c.get("value", 1))
	match c.get("type", ""):
		"levels_completed":
			return Vector2i(mini(completed_count(), goal), goal)
		"object_stage":
			return Vector2i(mini(object_stage(c.get("object", "")), goal), goal)
		"area_restored":
			return Vector2i(int(area_restored(c.get("area", ""))), 1)
		"objective_met":
			return Vector2i(mini(objective_count(c.get("objective", "")), goal), goal)
		"areas_unlocked":
			return Vector2i(mini(p["areas_unlocked"].size(), goal), goal)
		"discoveries":
			return Vector2i(mini(p["discoveries"].size(), goal), goal)
	return Vector2i(0, 1)


func _condition_met(c: Dictionary) -> bool:
	var prog := achievement_progress({"condition": c})
	return prog.x >= prog.y and prog.y > 0


func set_decoration_visible(id: String, visible: bool) -> void:
	if not has_discovery(id):
		return
	var hidden: Array = p["decor_hidden"]
	if visible:
		hidden.erase(id)
	elif not hidden.has(id):
		hidden.append(id)


func is_decoration_visible(id: String) -> bool:
	return has_discovery(id) and not p["decor_hidden"].has(id)
