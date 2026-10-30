class_name PuzzleTile
extends RefCounted
## One cell of a puzzle board. Pure data + rules; no rendering.

var type: String = TileTypes.EMPTY
var rotation: int = 0          ## quarter turns clockwise from the base orientation, 0..3
var pinned: bool = false       ## level pinned this tile so it cannot be rotated
var link: String = ""          ## gate/switch link id
var inverted: bool = false     ## gate is open while its switch is OFF
var target_id: String = ""     ## for targets / bonus targets


func _init(p_type: String = TileTypes.EMPTY, p_rotation: int = 0) -> void:
	type = p_type
	rotation = posmod(p_rotation, 4)


func is_rotatable() -> bool:
	return TileTypes.flag(type, "rotatable") and not pinned


func is_toggle() -> bool:
	return TileTypes.flag(type, "toggle")


func is_interactive() -> bool:
	return is_rotatable() or is_toggle()


func accepts_water() -> bool:
	return TileTypes.flag(type, "accepts")


func transmits_water() -> bool:
	return TileTypes.flag(type, "transmits")


func is_source() -> bool:
	return TileTypes.flag(type, "emits")


func is_sink() -> bool:
	return TileTypes.flag(type, "sink")


func is_gate() -> bool:
	return TileTypes.flag(type, "gated")


## Openings with the current rotation, ignoring gate state.
func shape_mask() -> int:
	return Dir.rotate_mask(TileTypes.base_mask(type), rotation)


## Openings for a hypothetical rotation (used by the solver).
func shape_mask_at(rot: int) -> int:
	return Dir.rotate_mask(TileTypes.base_mask(type), rot)


## Number of visually distinct orientations reachable by rotating.
func distinct_rotations() -> Array[int]:
	var seen := {}
	var out: Array[int] = []
	for r in 4:
		var m := shape_mask_at(r)
		if not seen.has(m):
			seen[m] = true
			out.append(r)
	return out


func duplicate_tile() -> PuzzleTile:
	var t := PuzzleTile.new(type, rotation)
	t.pinned = pinned
	t.link = link
	t.inverted = inverted
	t.target_id = target_id
	return t
