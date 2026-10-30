class_name MergeDB
extends RefCounted
## Merge-mode content: item chains, generators, balance and story, loaded from
## resources/merge/*.json. Items are addressed as "<chain>:<level>" (1-based).

const ITEMS_PATH := "res://resources/merge/items.json"
const BALANCE_PATH := "res://resources/merge/balance.json"
const STORY_PATH := "res://resources/merge/story.json"

var cols := 7
var rows := 9
var chains: Dictionary = {}
var balance: Dictionary = {}
var cast: Dictionary = {}
var chapters: Array = []
var intro: Array = []             ## dialogue shown on the first visit
var hosts: Array = []             ## cast members who never place orders (owner, pet)
var errors: Array[String] = []


static func load_default() -> MergeDB:
	var db := MergeDB.new()
	db.load_from(_read(ITEMS_PATH), _read(BALANCE_PATH), _read(STORY_PATH))
	return db


## Another merge location (Reef Grill, ...): items/balance/story.json in `dir`.
static func load_location(dir: String) -> MergeDB:
	var db := MergeDB.new()
	db.load_from(_read(dir.path_join("items.json")), _read(dir.path_join("balance.json")), _read(dir.path_join("story.json")))
	return db


static func _read(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func load_from(items: Dictionary, p_balance: Dictionary, story: Dictionary) -> void:
	cols = int(items.get("board", {}).get("cols", 7))
	rows = int(items.get("board", {}).get("rows", 9))
	chains = items.get("chains", {})
	balance = p_balance
	cast = story.get("cast", {})
	chapters = story.get("chapters", [])
	intro = story.get("intro", [])
	hosts = story.get("hosts", [])
	_validate()


# ------------------------------------------------------------------ items

static func make_id(chain: String, level: int) -> String:
	return "%s:%d" % [chain, level]


static func chain_of(id: String) -> String:
	return id.get_slice(":", 0)


static func level_of(id: String) -> int:
	return int(id.get_slice(":", 1))


func exists(id: String) -> bool:
	var c: Dictionary = chains.get(chain_of(id), {})
	var l := level_of(id)
	return not c.is_empty() and l >= 1 and l <= max_level(chain_of(id))


func kind(id: String) -> String:
	return str(chains.get(chain_of(id), {}).get("kind", ""))


func max_level(chain: String) -> int:
	return (chains.get(chain, {}).get("names", []) as Array).size()


func item_name(id: String) -> String:
	var names: Array = chains.get(chain_of(id), {}).get("names", [])
	var l := level_of(id)
	return str(names[l - 1]) if l >= 1 and l <= names.size() else id


func is_max(id: String) -> bool:
	return level_of(id) >= max_level(chain_of(id))


func next_id(id: String) -> String:
	return "" if is_max(id) else make_id(chain_of(id), level_of(id) + 1)


func resource_value(id: String) -> int:
	var c: Dictionary = chains.get(chain_of(id), {})
	var vals: Array = c.get("values", [])
	var l := level_of(id)
	return int(vals[l - 1]) if l >= 1 and l <= vals.size() else 0


func gen_def(id: String, key: String, default = null):
	var c: Dictionary = chains.get(chain_of(id), {})
	var v = c.get(key, default)
	if v is Array:
		var l := clampi(level_of(id) - 1, 0, (v as Array).size() - 1)
		return v[l] if not (v as Array).is_empty() else default
	return v


func unlock_level(chain: String) -> int:
	return int(chains.get(chain, {}).get("unlock_level", 1))


## Food chains the player can be asked for at this level.
func food_chains(player_level: int) -> Array[String]:
	var out: Array[String] = []
	for k in chains:
		if chains[k].get("kind", "") == "food" and unlock_level(k) <= player_level:
			out.append(k)
	out.sort()
	return out


func sell_value(id: String) -> int:
	var table: Array = balance.get("sell_coins", [0, 1])
	return int(table[clampi(level_of(id), 0, table.size() - 1)])


func task(task_id: String) -> Dictionary:
	for ch in chapters:
		for t in ch["tasks"]:
			if t["id"] == task_id:
				return t
	return {}


# ------------------------------------------------------------------ validation

func _validate() -> void:
	errors.clear()
	if chains.is_empty():
		errors.append("no chains")
	for k in chains:
		var c: Dictionary = chains[k]
		if (c.get("names", []) as Array).is_empty():
			errors.append("%s: no names" % k)
		if c.get("kind", "") == "generator":
			if not chains.has(str(c.get("produces", ""))):
				errors.append("%s: produces unknown chain" % k)
			for table in c.get("drops", []):
				for d in table:
					if not exists(make_id(str(d[0]), int(d[1]))):
						errors.append("%s: drops unknown item %s:%s" % [k, d[0], d[1]])
		if c.get("kind", "") == "chest":
			for table in c.get("contents", []):
				for d in table:
					if not exists(make_id(str(d[0]), int(d[1]))):
						errors.append("%s: contains unknown item %s:%s" % [k, d[0], d[1]])
	for s in balance.get("start_board", []):
		if not exists(str(s["id"])):
			errors.append("start board: unknown item %s" % s["id"])
	var ids := {}
	for ch in chapters:
		for t in ch.get("tasks", []):
			if ids.has(t["id"]):
				errors.append("duplicate task %s" % t["id"])
			ids[t["id"]] = true
			if int(t.get("cost", 0)) <= 0:
				errors.append("task %s: cost must be positive" % t["id"])
			for line in t.get("dialogue", []):
				if not cast.has(str(line[0])):
					errors.append("task %s: unknown speaker %s" % [t["id"], line[0]])
