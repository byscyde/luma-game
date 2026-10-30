class_name TileTypes
extends RefCounted
## Static definitions for every puzzle tile type. Data-driven so new mechanics
## (frozen channels, energy channels, ...) can be added without touching the
## simulation core: each type only declares how it connects and behaves.

const EMPTY := "empty"
const STRAIGHT := "straight"
const ELBOW := "elbow"
const TEE := "tee"
const CROSS := "cross"
const SOURCE := "source"
const TARGET := "target"
const BONUS := "bonus"
const ROCK := "rock"
const GATE := "gate"
const SWITCH := "switch"

## base_mask: openings at rotation 0.
## rotatable: the player may rotate it (unless the level pins it with "!").
## accepts: water may enter it.  transmits: water continues out of its other openings.
## emits: it is a water source.  sink: it is a goal that absorbs water.
## toggle: tapping toggles a link instead of rotating.
const DEFS := {
	EMPTY: {"base_mask": 0, "rotatable": false, "accepts": false, "transmits": false},
	STRAIGHT: {"base_mask": Dir.N | Dir.S, "rotatable": true, "accepts": true, "transmits": true},
	ELBOW: {"base_mask": Dir.N | Dir.E, "rotatable": true, "accepts": true, "transmits": true},
	TEE: {"base_mask": Dir.N | Dir.E | Dir.S, "rotatable": true, "accepts": true, "transmits": true},
	CROSS: {"base_mask": Dir.ALL, "rotatable": false, "accepts": true, "transmits": true},
	SOURCE: {"base_mask": Dir.N, "rotatable": false, "accepts": false, "transmits": true, "emits": true},
	TARGET: {"base_mask": Dir.ALL, "rotatable": false, "accepts": true, "transmits": false, "sink": true},
	BONUS: {"base_mask": Dir.ALL, "rotatable": false, "accepts": true, "transmits": false, "sink": true},
	ROCK: {"base_mask": 0, "rotatable": false, "accepts": false, "transmits": false},
	GATE: {"base_mask": Dir.N | Dir.S, "rotatable": false, "accepts": true, "transmits": true, "gated": true},
	SWITCH: {"base_mask": 0, "rotatable": false, "accepts": false, "transmits": false, "toggle": true},
}

## Token letter -> type, used by the compact level grid format.
const TOKENS := {
	".": EMPTY,
	"#": ROCK,
	"+": CROSS,
	"S": SOURCE,
	"T": TARGET,
	"B": BONUS,
	"I": STRAIGHT,
	"L": ELBOW,
	"Y": TEE,
	"G": GATE,
	"g": GATE,
	"K": SWITCH,
	"k": SWITCH,
}


static func has_type(type_id: String) -> bool:
	return DEFS.has(type_id)


static func def(type_id: String) -> Dictionary:
	return DEFS.get(type_id, DEFS[EMPTY])


static func flag(type_id: String, key: String) -> bool:
	return bool(def(type_id).get(key, false))


static func base_mask(type_id: String) -> int:
	return int(def(type_id).get("base_mask", 0))
