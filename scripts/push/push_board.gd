class_name PushBoard
extends RefCounted
## Stone Steps rules (Sokoban): Luma walks the terraces and pushes boulders
## into the spillway sockets. A level is solved when every socket holds a
## boulder — then the dammed water turns onto the dry terraces.
##
## Grid tokens (one character per cell):
##   #  rock wall      .  path      o  socket (empty)
##   B  boulder        *  boulder on a socket
##   @  Luma           +  Luma on a socket
## A move is a direction "N", "E", "S" or "W"; one step, pushing at most one
## boulder that has an open cell behind it.

const DIRS := {"N": Vector2i(0, -1), "E": Vector2i(1, 0), "S": Vector2i(0, 1), "W": Vector2i(-1, 0)}

var w := 0
var h := 0
var walls := {}          ## Vector2i -> true
var sockets := {}        ## Vector2i -> true
var boulders := {}       ## Vector2i -> true
var player := Vector2i.ZERO


static func from_dict(d: Dictionary) -> PushBoard:
	var b := PushBoard.new()
	var rows: Array = d.get("grid", [])
	b.h = rows.size()
	for y in rows.size():
		var row := str(rows[y])
		b.w = maxi(b.w, row.length())
		for x in row.length():
			var c := Vector2i(x, y)
			match row[x]:
				"#":
					b.walls[c] = true
				"o":
					b.sockets[c] = true
				"B":
					b.boulders[c] = true
				"*":
					b.boulders[c] = true
					b.sockets[c] = true
				"@":
					b.player = c
				"+":
					b.player = c
					b.sockets[c] = true
	return b


func to_grid() -> Array:
	var out: Array = []
	for y in h:
		var row := ""
		for x in w:
			var c := Vector2i(x, y)
			if walls.has(c):
				row += "#"
			elif boulders.has(c):
				row += "*" if sockets.has(c) else "B"
			elif c == player:
				row += "+" if sockets.has(c) else "@"
			else:
				row += "o" if sockets.has(c) else "."
		out.append(row)
	return out


func duplicate_board() -> PushBoard:
	var b := PushBoard.new()
	b.w = w
	b.h = h
	b.walls = walls
	b.sockets = sockets
	b.boulders = boulders.duplicate()
	b.player = player
	return b


func open(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h and not walls.has(c)


## Applies one step. Returns "" when blocked, "walk" or "push".
func step(dir: String) -> String:
	var d: Vector2i = DIRS[dir]
	var n := player + d
	if not open(n):
		return ""
	if boulders.has(n):
		var beyond := n + d
		if not open(beyond) or boulders.has(beyond):
			return ""
		boulders.erase(n)
		boulders[beyond] = true
		player = n
		return "push"
	player = n
	return "walk"


## Takes back a step made in `dir`; `pushed` says whether it moved a boulder.
func unstep(dir: String, pushed: bool) -> void:
	var d: Vector2i = DIRS[dir]
	if pushed:
		boulders.erase(player + d)
		boulders[player] = true
	player -= d


static func opposite(dir: String) -> String:
	return {"N": "S", "S": "N", "E": "W", "W": "E"}[dir]


func solved() -> bool:
	for s in sockets:
		if not boulders.has(s):
			return false
	return true


func filled() -> int:
	var n := 0
	for s in sockets:
		if boulders.has(s):
			n += 1
	return n


## Cells Luma can walk to without pushing (BFS), with the first step of a
## shortest path to each: cell -> path Array of directions.
func walk_paths() -> Dictionary:
	var paths := {player: []}
	var queue: Array = [player]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for dir in DIRS:
			var n: Vector2i = c + DIRS[dir]
			if paths.has(n) or not open(n) or boulders.has(n):
				continue
			var p: Array = (paths[c] as Array).duplicate()
			p.append(dir)
			paths[n] = p
			queue.append(n)
	return paths


func key() -> String:
	var bs: Array = boulders.keys()
	bs.sort()
	return "%d,%d|%s" % [player.x, player.y, str(bs)]
