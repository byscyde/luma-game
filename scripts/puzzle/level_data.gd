class_name LevelData
extends RefCounted
## Parsed, versioned level definition. Levels are authored as JSON in
## resources/levels/<world>/<id>.json using a compact token grid
## (see docs/LEVEL_AUTHORING.md).

const FORMAT_VERSION := 1
const MIN_SIZE := 3
const MAX_SIZE := 7

const OBJ_REACH_ALL := "reach_all_targets"
const OBJ_MOVES_AT_MOST := "moves_at_most"
const OBJ_NO_LEAKS := "no_leaks"
const OBJ_REACH_BONUS := "reach_bonus"
const REQUIRED_TYPES := [OBJ_REACH_ALL]
const OPTIONAL_TYPES := [OBJ_MOVES_AT_MOST, OBJ_NO_LEAKS, OBJ_REACH_BONUS]

var id: String = ""
var name: String = ""
var world: String = ""
var area: String = ""
var mechanic: String = ""
var difficulty: int = 1
var width: int = 0
var height: int = 0
var grid: Array = []                 ## Array of rows, each an Array of token strings
var targets: Dictionary = {}         ## target id -> {label, kind}
var required: Array = []             ## objective dicts
var optional: Array = []             ## objective dicts
var par_moves: int = 0
var restores: Array = []             ## [{object, stage}]
var rewards: Dictionary = {}
var tutorial: String = ""
var hint_text: String = ""
var validation: Dictionary = {}      ## e.g. {"status": "approved_unverified", "reason": "..."}
var errors: Array[String] = []


static func from_dict(src: Dictionary) -> LevelData:
	var d := migrate(src)
	var l := LevelData.new()
	l.id = str(d.get("id", ""))
	l.name = str(d.get("name", l.id))
	l.world = str(d.get("world", ""))
	l.area = str(d.get("area", ""))
	l.mechanic = str(d.get("mechanic", ""))
	l.difficulty = int(d.get("difficulty", 1))
	l.targets = d.get("targets", {})
	var obj: Dictionary = d.get("objectives", {})
	l.required = obj.get("required", [{"type": OBJ_REACH_ALL}])
	l.optional = obj.get("optional", [])
	l.par_moves = int(d.get("par_moves", 0))
	l.restores = d.get("restores", [])
	l.rewards = d.get("rewards", {})
	l.tutorial = str(d.get("tutorial", ""))
	l.hint_text = str(d.get("hint_text", ""))
	l.validation = d.get("validation", {})
	if l.id == "":
		l.errors.append("missing id")
	var rows: Array = d.get("grid", [])
	for row in rows:
		var tokens: Array = []
		for tok in str(row).split(" ", false):
			tokens.append(tok)
		l.grid.append(tokens)
	l.height = l.grid.size()
	l.width = l.grid[0].size() if l.height > 0 else 0
	if l.height < MIN_SIZE or l.height > MAX_SIZE or l.width < MIN_SIZE or l.width > MAX_SIZE:
		l.errors.append("board %dx%d outside supported %d..%d" % [l.width, l.height, MIN_SIZE, MAX_SIZE])
	for y in l.height:
		if l.grid[y].size() != l.width:
			l.errors.append("row %d has %d tokens, expected %d" % [y, l.grid[y].size(), l.width])
	for o in l.required:
		if not REQUIRED_TYPES.has(o.get("type", "")):
			l.errors.append("unknown required objective '%s'" % o.get("type", ""))
	for o in l.optional:
		if not OPTIONAL_TYPES.has(o.get("type", "")):
			l.errors.append("unknown optional objective '%s'" % o.get("type", ""))
	if l.errors.is_empty():
		l.build_board()  # surfaces token errors early
	return l


## Upgrades older level formats in place. Add a step per version bump.
static func migrate(src: Dictionary) -> Dictionary:
	var d := src.duplicate(true)
	var v := int(d.get("format_version", 1))
	# v1 is the first released format; future steps go here, e.g.
	# if v == 1: ...convert...; v = 2
	d["format_version"] = v
	return d


static func parse_token(tok: String) -> Dictionary:
	if tok.is_empty():
		return {"error": "empty token"}
	var head := tok.substr(0, 1)
	if not TileTypes.TOKENS.has(head):
		return {"error": "unknown tile token '%s'" % tok}
	var type: String = TileTypes.TOKENS[head]
	var rest := tok.substr(1)
	var pinned := false
	if rest.ends_with("!"):
		pinned = true
		rest = rest.substr(0, rest.length() - 1)
	var t := PuzzleTile.new(type)
	t.pinned = pinned
	match type:
		TileTypes.EMPTY, TileTypes.ROCK, TileTypes.CROSS:
			if rest != "":
				return {"error": "token '%s' takes no parameters" % tok}
		TileTypes.SOURCE, TileTypes.STRAIGHT, TileTypes.ELBOW, TileTypes.TEE:
			if rest.length() != 1 or not rest.is_valid_int() or int(rest) > 3:
				return {"error": "token '%s' needs a rotation digit 0-3" % tok}
			t.rotation = int(rest)
		TileTypes.TARGET, TileTypes.BONUS:
			if rest == "" or not rest.is_valid_int():
				return {"error": "token '%s' needs a numeric id" % tok}
			t.target_id = head + rest
		TileTypes.GATE:
			if rest.length() < 2 or not rest.substr(0, 1).is_valid_int() or int(rest.substr(0, 1)) > 3:
				return {"error": "gate token '%s' needs rotation digit then link id" % tok}
			t.rotation = int(rest.substr(0, 1))
			t.link = rest.substr(1)
			t.inverted = head == "g"
		TileTypes.SWITCH:
			if rest == "":
				return {"error": "switch token '%s' needs a link id" % tok}
			t.link = rest
	return {"tile": t, "switch_on": head == "k"}


func build_board() -> PuzzleBoard:
	var b := PuzzleBoard.new(width, height)
	for y in height:
		for x in width:
			var r := parse_token(str(grid[y][x]))
			if r.has("error"):
				if not errors.has(r["error"]):
					errors.append(r["error"])
				continue
			var t: PuzzleTile = r["tile"]
			b.set_tile(Vector2i(x, y), t)
			if t.is_toggle():
				b.switches[t.link] = bool(r["switch_on"])
	return b


func has_optional(type_id: String) -> bool:
	for o in optional:
		if o.get("type", "") == type_id:
			return true
	return false


func optional_value(type_id: String, default_value: int = 0) -> int:
	for o in optional:
		if o.get("type", "") == type_id:
			return int(o.get("value", default_value))
	return default_value
