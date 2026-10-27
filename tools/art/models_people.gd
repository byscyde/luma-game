extends RefCounted
## Customer and host busts (bust_<who>.png).

const Character3D := preload("res://tools/art/character_3d.gd")


static func keys() -> Array:
	var out := []
	for who in PortraitArt.LOOKS:
		out.append("bust:" + who)
		out.append("face:" + who)
	return out


static func build(key: String) -> ArtModel:
	var m: ArtModel = Character3D.build(key.get_slice(":", 1))
	if key.begins_with("face:"):
		# a head-and-shoulders close-up for round portraits (masked to a circle afterwards)
		m.cam_target = Vector3(0, 0.12, 0)
		m.cam_pos = Vector3(0, 0.4, 4.4)
		m.fov = 0.23
	return m
