class_name MergeArt
extends RefCounted
## The rendered merge art in assets/merge/art (tools/bake_merge_art.tscn): 3D items
## ("chain:level"), customer busts ("bust:<who>") and round portraits ("face:<who>").
## Views fall back to the procedural drawings for anything not rendered yet.

const DIR := "res://assets/merge/art/"

static var _cache: Dictionary = {}   ## key -> Texture2D or null


static func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var path := DIR + key.replace(":", "_") + ".png"
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_cache[key] = t
	return t
