class_name BridgeBoard
extends RefCounted
## Rope Isles rules (Hashi): islets carry a number; join neighbouring islets
## with rope bridges running straight across open water. Each pair takes zero,
## one or two bridges, bridges never cross, every islet ends with exactly its
## number of bridges, and all islets form one connected group.
##
## Level data: {"w", "h", "islands": [[x, y, n], ...]}. The candidate links
## (nearest islet in each direction) are derived; a link's state is 0, 1 or 2.
## A player move is one tap on a link: 0 -> 1 -> 2 -> 0.

var w := 0
var h := 0
var islands: Array = []      ## [Vector2i cell, int n]
var links: Array = []        ## [a, b] island indices, a < b; a is left of / above b
var state: PackedInt32Array = []
var _at := {}                ## Vector2i -> island index
var _crosses: Array = []     ## link index -> Array of link indices it crosses


static func from_dict(d: Dictionary) -> BridgeBoard:
	var b := BridgeBoard.new()
	b.w = int(d.get("w", 0))
	b.h = int(d.get("h", 0))
	for e in d.get("islands", []):
		b._at[Vector2i(int(e[0]), int(e[1]))] = b.islands.size()
		b.islands.append([Vector2i(int(e[0]), int(e[1])), int(e[2])])
	b._find_links()
	b.state.resize(b.links.size())
	b.state.fill(0)
	return b


func duplicate_board() -> BridgeBoard:
	var b := BridgeBoard.new()
	b.w = w
	b.h = h
	b.islands = islands
	b.links = links
	b._at = _at
	b._crosses = _crosses
	b.state = state.duplicate()
	return b


func cell(i: int) -> Vector2i:
	return islands[i][0]


func need(i: int) -> int:
	return islands[i][1]


func island_at(c: Vector2i) -> int:
	return _at.get(c, -1)


func _find_links() -> void:
	for i in islands.size():
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var c: Vector2i = cell(i) + d
			while c.x < w and c.y < h:
				if _at.has(c):
					links.append([i, _at[c]])
					break
				c += d
	for k in links.size():
		var out: Array = []
		for j in links.size():
			if j != k and _cross(links[k], links[j]):
				out.append(j)
		_crosses.append(out)


func _cross(l1: Array, l2: Array) -> bool:
	var a1 := cell(l1[0])
	var b1 := cell(l1[1])
	var a2 := cell(l2[0])
	var b2 := cell(l2[1])
	var h1 := a1.y == b1.y
	var h2 := a2.y == b2.y
	if h1 == h2:
		return false
	if not h1:
		return _cross(l2, l1)
	# l1 horizontal (row a1.y, x in (a1.x, b1.x)); l2 vertical (column a2.x, y in (a2.y, b2.y))
	return a2.x > a1.x and a2.x < b1.x and a1.y > a2.y and a1.y < b2.y


func crossings(k: int) -> Array:
	return _crosses[k]


## The link between two islets, or -1.
func link_between(i: int, j: int) -> int:
	for k in links.size():
		if (links[k][0] == i and links[k][1] == j) or (links[k][0] == j and links[k][1] == i):
			return k
	return -1


## Whether link k may hold a bridge now (no crossing bridge is built).
func link_free(k: int) -> bool:
	for j in _crosses[k]:
		if state[j] > 0:
			return false
	return true


## One tap: 0 -> 1 -> 2 -> 0. A link blocked by a crossing bridge stays at 0
## (returns false).
func tap(k: int) -> bool:
	if k < 0 or k >= links.size():
		return false
	if state[k] == 0 and not link_free(k):
		return false
	state[k] = (state[k] + 1) % 3
	return true


func degree(i: int) -> int:
	var n := 0
	for k in links.size():
		if links[k][0] == i or links[k][1] == i:
			n += state[k]
	return n


func connected() -> bool:
	if islands.is_empty():
		return false
	var seen := {0: true}
	var stack: Array = [0]
	while not stack.is_empty():
		var i: int = stack.pop_back()
		for k in links.size():
			if state[k] == 0:
				continue
			var o: int = links[k][1] if links[k][0] == i else (links[k][0] if links[k][1] == i else -1)
			if o >= 0 and not seen.has(o):
				seen[o] = true
				stack.append(o)
	return seen.size() == islands.size()


func complete_count() -> int:
	var n := 0
	for i in islands.size():
		if degree(i) == need(i):
			n += 1
	return n


func solved() -> bool:
	return complete_count() == islands.size() and connected()


func total_bridges() -> int:
	var n := 0
	for v in state:
		n += v
	return n
