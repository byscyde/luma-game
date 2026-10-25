class_name Dir
extends RefCounted
## Canonical direction model shared by the game, solver, validator and tests.
## Directions are bit flags so a tile's openings fit in a 4-bit mask.

const N := 1
const E := 2
const S := 4
const W := 8
const ALL := 15
const LIST: Array[int] = [N, E, S, W]


## Rotates a connection mask clockwise by `turns` quarter turns (N -> E -> S -> W).
static func rotate_mask(mask: int, turns: int) -> int:
	var t := posmod(turns, 4)
	var m := mask & ALL
	for i in t:
		m = ((m << 1) | (m >> 3)) & ALL
	return m


static func opposite(d: int) -> int:
	match d:
		N: return S
		E: return W
		S: return N
		W: return E
	return 0


static func offset(d: int) -> Vector2i:
	match d:
		N: return Vector2i(0, -1)
		E: return Vector2i(1, 0)
		S: return Vector2i(0, 1)
		W: return Vector2i(-1, 0)
	return Vector2i.ZERO


## Angle in radians for drawing (0 = pointing up / north, clockwise positive).
static func angle(d: int) -> float:
	match d:
		N: return 0.0
		E: return PI * 0.5
		S: return PI
		W: return PI * 1.5
	return 0.0


static func name_of(d: int) -> String:
	match d:
		N: return "N"
		E: return "E"
		S: return "S"
		W: return "W"
	return "?"


static func mask_to_string(mask: int) -> String:
	var s := ""
	for d in LIST:
		if mask & d:
			s += name_of(d)
	return s if s != "" else "-"


static func count(mask: int) -> int:
	var c := 0
	for d in LIST:
		if mask & d:
			c += 1
	return c
