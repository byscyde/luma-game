class_name WaterResult
extends RefCounted
## Structured, deterministic output of a water simulation pass.

var distance: Dictionary = {}               ## Vector2i -> int (BFS steps from nearest source)
var order: Array[Vector2i] = []              ## reached cells in deterministic BFS order
var edges: Array = []                        ## [Vector2i from, Vector2i to] connections water crossed
var reached_targets: Array[String] = []      ## required target ids reached
var reached_bonus: Array[String] = []        ## optional bonus target ids reached
var leaks: Array = []                        ## {pos, dir, reason} openings where water escapes
var frontier: Array[Vector2i] = []           ## undetermined cells water tried to enter (solver only)
var required_targets: Array[String] = []
var all_required_reached: bool = false


func is_wet(p: Vector2i) -> bool:
	return distance.has(p)


func leak_count() -> int:
	return leaks.size()


func describe() -> String:
	var lines: Array[String] = []
	lines.append("reached=%d targets=%s/%s bonus=%s leaks=%d complete=%s" % [
		order.size(), str(reached_targets), str(required_targets), str(reached_bonus),
		leaks.size(), str(all_required_reached)])
	for l in leaks:
		lines.append("  leak at %s dir %s (%s)" % [str(l["pos"]), Dir.name_of(l["dir"]), l["reason"]])
	return "\n".join(lines)
