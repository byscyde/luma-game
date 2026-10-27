class_name MatchBot
extends RefCounted
## Greedy player for MatchBoard: tries every possible swap on a copy of the
## board and picks the one that moves the goals forward the most. Used for the
## Hint button and by the level generator, whose stored solution is the bot's
## winning game (CI replays it with the real rules).


## Value of a position for the goals (higher is better).
static func progress(b: MatchBoard) -> float:
	var v := 0.0
	if b.goal_moss:
		v -= b.moss_left() * 3.0
	for k in b.goal_collect:
		v -= maxi(0, int(b.goal_collect[k]) - b.collected[k]) * 2.0
	return v


## The best swap from here ([a, b]) or [] when none exists.
static func best_swap(b: MatchBoard) -> Array:
	var best: Array = []
	var best_v := -INF
	var base := progress(b)
	for s in b.all_valid_swaps():
		var t := b.duplicate_board()
		t.moves_left = maxi(t.moves_left, 1)
		t.swap(s[0], s[1])
		var v := progress(t) - base
		if t.goals_met():
			v += 1000.0
		var made := 0
		for e in t.last_events:
			made += (e["made"] as Array).size()
		v += made * 1.5
		# prefer swaps low on the board (they shake up more) on ties
		v += (s[0].y + s[1].y) * 0.01
		if v > best_v:
			best_v = v
			best = s
	return best


## Plays greedily until the goals are met or `limit` swaps; returns the swaps
## made ([[ax, ay, bx, by], ...]) and whether it won.
static func play(start: MatchBoard, limit: int) -> Dictionary:
	var b := start.duplicate_board()
	b.moves_left = limit
	var moves: Array = []
	while not b.goals_met() and b.moves_left > 0:
		var s := best_swap(b)
		if s.is_empty():
			break
		b.swap(s[0], s[1])
		moves.append([s[0].x, s[0].y, s[1].x, s[1].y])
	return {"won": b.goals_met(), "moves": moves}
