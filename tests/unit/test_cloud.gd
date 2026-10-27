extends TestCase
## Cloud save: the save format, and the sync rules against an in-memory server
## (guest on first start, upload after saving, adopt on a fresh phone, ask on a
## conflict, sign-in that switches to an existing player).

const STATE := "user://test_cloud_state.json"

var server: Dictionary   ## players -> {"save": String}, tokens -> player


func before_each() -> void:
	Router.dry_run = true
	Game.reset_progress()
	server = {"players": {}, "tokens": {}, "identities": {}, "calls": []}
	Cloud.use_for_tests(_fake, STATE)


func after_each() -> void:
	Cloud.enabled = false
	Cloud.pending = {}
	Router.dry_run = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STATE))


func _fake(method: int, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	await tree.process_frame
	var path := url.replace("https://test.invalid", "")
	var token := ""
	for h in headers:
		if h.begins_with("Authorization: Bearer "):
			token = h.substr(22)
	var me: String = server["tokens"].get(token, "")
	var b = JSON.parse_string(body) if body != "" else {}
	server["calls"].append(path)
	if path == "/v1/guest":
		var id := "p%d" % server["players"].size()
		server["players"][id] = {"save": ""}
		server["tokens"]["t-" + id] = id
		return {"status": 200, "json": {"playerId": id, "token": "t-" + id}}
	if path.begins_with("/v1/auth/"):
		var key: String = path.substr(9) + ":" + str(b["token"])
		if server["identities"].has(key):
			var owner: String = server["identities"][key]
			server["tokens"]["t2-" + owner] = owner
			return {"status": 200, "json": {"playerId": owner, "token": "t2-" + owner, "switched": owner != me, "linked": false, "providers": [path.substr(9)]}}
		server["identities"][key] = me
		return {"status": 200, "json": {"playerId": me, "token": token, "switched": false, "linked": true, "providers": [path.substr(9)]}}
	if me == "":
		return {"status": 401, "json": {}}
	if path == "/v1/save/luma_save":
		if method == HTTPClient.METHOD_PUT:
			server["players"][me]["save"] = b["value"]
			return {"status": 200, "json": {"ok": true}}
		var v: String = server["players"][me]["save"]
		return {"status": 404, "json": {}} if v == "" else {"status": 200, "json": {"value": v}}
	return {"status": 404, "json": {}}


func _progressed() -> Dictionary:
	var d := SaveStore.default_data()
	d["progress"]["completed"] = {"w1_l01": {"best_moves": 3}, "w1_l02": {"best_moves": 4}}
	d["progress"]["essence"] = 25
	return d


func test_snapshot_round_trip_and_server_format() -> void:
	var packed := CloudSnapshot.pack({"save_version": 3, "progress": {"essence": 7}}, "abc", "Phone")
	assert_true(packed.begins_with("gz:"))
	var back := CloudSnapshot.unpack(packed)
	assert_eq(back["uploadId"], "abc")
	assert_eq(int(back["data"]["progress"]["essence"]), 7)
	# made by the server's admin.js (Node zlib): the game must read it
	var node := CloudSnapshot.unpack("gz:H4sIAAAAAAAAAx3LMQrDMAxG4bv8s5cSQkFbxyy5QlAipRhay1iul+C7B3d8PL4Lp5UvV9AjwLmpvCpoDvjlj7EsAgLvBwJEWzwUhNVER3Nl0PVHW9Pi0RJoCsjF3kXdx1R3TUM9e+83hconpWwAAAA=")
	assert_eq(node["device"], "Node")
	assert_eq(int(node["data"]["progress"]["essence"]), 7)
	assert_true(CloudSnapshot.unpack("{\"format\": 1}").is_empty(), "a snapshot without data is ignored")


func test_first_start_creates_a_guest_and_uploads() -> void:
	await Cloud.start()
	assert_eq(Cloud.state["player_id"], "p0")
	assert_eq(Cloud.status, Cloud.SYNCED)
	var snap := CloudSnapshot.unpack(server["players"]["p0"]["save"])
	assert_eq(snap["uploadId"], Cloud.state["last_upload_id"])


func test_a_fresh_phone_takes_the_cloud_save() -> void:
	await Cloud.start()
	server["players"]["p0"]["save"] = CloudSnapshot.pack(_progressed(), "other-phone", "Old phone")
	await Cloud.check_cloud()
	assert_eq(Game.progression.completed_count(), 2, "the cloud progress is now on this phone")
	assert_eq(Cloud.state["last_upload_id"], "other-phone")
	assert_eq(Cloud.status, Cloud.SYNCED)


func test_two_different_saves_wait_for_the_player() -> void:
	await Cloud.start()
	Game.data["progress"]["completed"]["w1_l01"] = {"best_moves": 2}
	server["players"]["p0"]["save"] = CloudSnapshot.pack(_progressed(), "admin-edit", "Admin")
	await Cloud.check_cloud()
	assert_eq(Cloud.status, Cloud.WAITING)
	var cloud_value: String = server["players"]["p0"]["save"]
	await Cloud.push_now()
	assert_eq(server["players"]["p0"]["save"], cloud_value, "nothing is uploaded while the player decides")
	await Cloud.resolve(true)
	assert_eq(Cloud.status, Cloud.SYNCED)
	assert_ne(server["players"]["p0"]["save"], cloud_value, "this phone's progress went up")
	assert_eq(Game.progression.completed_count(), 1)


func test_choosing_the_cloud_save_replaces_local_progress_but_not_settings() -> void:
	await Cloud.start()
	Game.data["progress"]["completed"]["w1_l01"] = {"best_moves": 2}
	Game.data["settings"]["haptics"] = false
	server["players"]["p0"]["save"] = CloudSnapshot.pack(_progressed(), "x", "Other")
	await Cloud.check_cloud()
	await Cloud.resolve(false)
	assert_eq(Game.progression.completed_count(), 2)
	assert_eq(Game.data["settings"]["haptics"], false, "settings belong to the device")


func test_sign_in_on_a_new_phone_finds_the_old_player() -> void:
	await Cloud.start()                                  # phone A, guest p0
	Game.replace_data(_progressed())
	await Cloud.push_now()
	await Cloud.finish_sign_in("google", "g-token", "n")
	assert_eq(Cloud.state["providers"], ["google"])
	# phone B: a new guest, no progress yet
	Game.reset_progress()
	Cloud.use_for_tests(_fake, STATE)
	await Cloud.start()
	assert_eq(Cloud.state["player_id"], "p1")
	await Cloud.finish_sign_in("google", "g-token", "n")
	assert_eq(Cloud.state["player_id"], "p0", "continues as the player of phone A")
	assert_eq(Game.progression.completed_count(), 2, "and gets phone A's progress")


func test_game_save_schedules_an_upload() -> void:
	await Cloud.start()
	var before: int = server["calls"].size()
	Game.save()
	await tree.create_timer(Cloud._push_delay + 0.3).timeout
	assert_true(server["calls"].size() > before, "uploaded a few seconds after saving")
