class_name CloudSnapshot
extends RefCounted
## The cloud copy of the save: "gz:" + base64(gzip(JSON)) of
## {"format": 1, "savedAt", "uploadId", "device", "data": <the whole save>},
## the same layout the server's admin page reads (server/luma-cloud/admin.js).

const FORMAT := 1


static func pack(data: Dictionary, upload_id: String, device: String) -> String:
	var snap := {"format": FORMAT, "savedAt": int(Time.get_unix_time_from_system()), "uploadId": upload_id,
		"device": device, "data": data}
	var raw := JSON.stringify(snap).to_utf8_buffer()
	return "gz:" + Marshalls.raw_to_base64(raw.compress(FileAccess.COMPRESSION_GZIP))


## The snapshot dictionary, or {} when the value cannot be read.
static func unpack(value: String) -> Dictionary:
	var text := value
	if value.begins_with("gz:"):
		var bytes := Marshalls.base64_to_raw(value.substr(3))
		if bytes.is_empty():
			return {}
		text = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	var d = JSON.parse_string(text)
	if not (d is Dictionary) or not (d.get("data") is Dictionary):
		return {}
	return d


static func new_upload_id() -> String:
	var c := Crypto.new()
	return c.generate_random_bytes(16).hex_encode()


## A rough measure of how far a save has got, to tell the player which copy is further along.
static func progress_of(data: Dictionary) -> Dictionary:
	var islands := 0
	for id in data.get("islands", {}):
		islands += (data["islands"][id].get("completed", {}) as Dictionary).size()
	var merge: Dictionary = data.get("merge", {})
	return {
		"levels": (data.get("progress", {}).get("completed", {}) as Dictionary).size(),
		"islands": islands,
		"tasks": (merge.get("tasks_done", []) as Array).size(),
		"cafe_level": int(merge.get("level", 0)),
		"saved_at": int(data.get("updated_at", 0)),
	}


static func is_fresh(data: Dictionary) -> bool:
	var p := progress_of(data)
	return p["levels"] == 0 and p["islands"] == 0 and p["tasks"] == 0
