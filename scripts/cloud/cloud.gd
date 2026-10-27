extends Node
## Cloud autoload: keeps the save on the LUMA server (server/luma-cloud), like FOUNDERS.
## Every device gets a guest player on first start; after each local save the game
## uploads a copy a few seconds later. Signing in with Apple, Google or Facebook binds
## that player so the save can be restored on another phone. When the cloud copy was
## changed elsewhere (another phone, the admin page) and this device has progress of
## its own, the player chooses which one to keep — nothing is overwritten silently.
##
## Off in headless runs (tests, CI smoke test) and when no server is configured.

signal status_changed
signal providers_changed

const CONFIG_PATH := "res://resources/cloud/cloud_config.json"
const STATE_PATH := "user://cloud_state.json"

const OFF := "off"
const IDLE := "idle"
const SYNCING := "syncing"
const SYNCED := "synced"
const OFFLINE := "offline"
const WAITING := "waiting"     ## a conflict is waiting for the player's choice

var enabled := false
var client: CloudClient
var state := {"player_id": "", "token": "", "device_id": "", "last_upload_id": "", "providers": []}
var status := OFF
var last_error := ""
var last_synced_at := 0
var save_key := "luma_save"
var pending: Dictionary = {}   ## cloud snapshot awaiting the player's choice
var state_path := STATE_PATH
var _push_delay := 4.0
var _push_timer: Timer
var _busy := false
var _dialog: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg = ContentDB.read_json(CONFIG_PATH)
	cfg = cfg if cfg is Dictionary else {}
	save_key = str(cfg.get("save_key", save_key))
	_push_delay = float(cfg.get("push_delay_s", _push_delay))
	var url := str(cfg.get("server_url", ""))
	_push_timer = Timer.new()
	_push_timer.one_shot = true
	_push_timer.timeout.connect(push_now)
	add_child(_push_timer)
	client = CloudClient.new(url, _http)
	_load_state()
	client.token = str(state["token"])
	Game.saved.connect(_on_game_saved)
	enabled = url != "" and DisplayServer.get_name() != "headless" and not ("--no-cloud" in OS.get_cmdline_user_args())
	if enabled:
		_set_status(IDLE)
		start.call_deferred()


## Tests: an in-memory server instead of HTTP, a separate state file, no dialogs.
func use_for_tests(transport: Callable, path: String) -> void:
	client = CloudClient.new("https://test.invalid", transport)
	state_path = path
	state = {"player_id": "", "token": "", "device_id": "test-device", "last_upload_id": "", "providers": []}
	pending = {}
	_busy = false
	enabled = true
	_set_status(IDLE)


func _load_state() -> void:
	var d = ContentDB.read_json(state_path) if FileAccess.file_exists(state_path) else null
	if d is Dictionary:
		for k in state:
			if d.has(k):
				state[k] = d[k]
	if str(state["device_id"]) == "":
		state["device_id"] = CloudSnapshot.new_upload_id()
		_save_state()


func _save_state() -> void:
	var f := FileAccess.open(state_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(state))


func _set_status(s: String, error := "") -> void:
	status = s
	last_error = error
	status_changed.emit()


func signed_in() -> bool:
	return not (state["providers"] as Array).is_empty()


# ------------------------------------------------------------------ sync

## First contact: make sure this device has a player, then compare with the cloud copy.
func start() -> void:
	if not enabled:
		return
	if await ensure_player():
		await check_cloud()


func ensure_player() -> bool:
	if str(state["token"]) != "":
		client.token = str(state["token"])
		return true
	var r: Dictionary = await client.guest(str(state["device_id"]))
	if int(r["status"]) != 200:
		_set_status(OFFLINE)
		return false
	state["player_id"] = str(r["json"].get("playerId", ""))
	state["token"] = str(r["json"].get("token", ""))
	state["providers"] = []
	client.token = str(state["token"])
	_save_state()
	return true


## Reads the cloud copy: uploads ours when the cloud has nothing newer, adopts the cloud
## copy when this device has no progress yet, otherwise asks the player.
func check_cloud() -> void:
	if not enabled or _busy:
		return
	_busy = true
	_set_status(SYNCING)
	var r: Dictionary = await client.get_save(save_key)
	_busy = false
	var code := int(r["status"])
	if code == 401:
		state["token"] = ""
		if await ensure_player():
			await push_now()
		return
	if code == 404:
		await push_now()
		return
	if code != 200:
		_set_status(OFFLINE)
		return
	var snap := CloudSnapshot.unpack(str(r["json"].get("value", "")))
	if snap.is_empty() or str(snap.get("uploadId", "")) == str(state["last_upload_id"]):
		await push_now()   # the cloud has nothing newer than this device
		return
	if CloudSnapshot.is_fresh(Game.data):
		adopt(snap)
		return
	pending = snap
	_set_status(WAITING)
	_show_conflict()


func _on_game_saved() -> void:
	if enabled and status != WAITING:
		_push_timer.start(_push_delay)


## Uploads the current save now (skipped while a conflict waits for the player).
func push_now() -> void:
	if not enabled or _busy or not pending.is_empty():
		return
	if str(state["token"]) == "" and not await ensure_player():
		return
	_busy = true
	_set_status(SYNCING)
	var upload_id := CloudSnapshot.new_upload_id()
	var value := CloudSnapshot.pack(Game.data, upload_id, OS.get_model_name())
	var r: Dictionary = await client.put_save(save_key, value)
	_busy = false
	match int(r["status"]):
		200:
			state["last_upload_id"] = upload_id
			_save_state()
			last_synced_at = int(Time.get_unix_time_from_system())
			_set_status(SYNCED)
		401:
			state["token"] = ""
			_save_state()
			if await ensure_player():
				await push_now()
		_:
			_set_status(OFFLINE)


## The player's choice in the conflict dialog.
func resolve(keep_this_device: bool) -> void:
	if pending.is_empty():
		return
	var snap := pending
	pending = {}
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	if keep_this_device:
		await push_now()
	else:
		adopt(snap)


## Replaces the local save with a cloud copy.
func adopt(snap: Dictionary) -> void:
	Game.replace_data(snap["data"])
	state["last_upload_id"] = str(snap.get("uploadId", ""))
	_save_state()
	last_synced_at = int(Time.get_unix_time_from_system())
	_set_status(SYNCED)
	if not Router.dry_run:
		Router.go("menu")


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if enabled and not _push_timer.is_stopped():
			_push_timer.stop()
			push_now()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		if enabled and status != WAITING:
			check_cloud()


# ------------------------------------------------------------------ sign-in

## Shows the system sign-in of a provider, then binds the account on the server.
func sign_in(provider: String) -> void:
	var p := NativeAuth.plugin()
	if p == null or not enabled:
		_set_status(status, UI.t("CLOUD_SIGNIN_UNAVAILABLE"))
		return
	var nonce := CloudSnapshot.new_upload_id()
	p.call("sign_in", provider, nonce)
	while true:
		var res: Array = await p.sign_in_completed
		if str(res[0]) != provider:
			continue
		if str(res[2]) != "":
			_set_status(status, UI.t("CLOUD_SIGNIN_FAILED"))
			return
		await finish_sign_in(provider, str(res[1]), nonce)
		return


## Second half of sign-in (also used by tests): the server checks the provider's token.
func finish_sign_in(provider: String, provider_token: String, nonce: String) -> void:
	if not await ensure_player():
		return
	var r: Dictionary = await client.sign_in(provider, provider_token, nonce)
	if int(r["status"]) != 200:
		_set_status(OFFLINE if int(r["status"]) == 0 else status, UI.t("CLOUD_SIGNIN_FAILED"))
		return
	var j: Dictionary = r["json"]
	state["providers"] = j.get("providers", [])
	if bool(j.get("switched", false)):
		# this account already had a player (another phone): continue as that player
		state["player_id"] = str(j.get("playerId", ""))
		state["token"] = str(j.get("token", ""))
		state["last_upload_id"] = ""
		client.token = str(state["token"])
		_save_state()
		providers_changed.emit()
		await check_cloud()
	else:
		_save_state()
		providers_changed.emit()
		_set_status(status)


func unlink(provider: String) -> void:
	var r: Dictionary = await client.unlink(provider)
	if int(r["status"]) == 200:
		state["providers"] = r["json"].get("providers", [])
		_save_state()
		var p := NativeAuth.plugin()
		if p:
			p.call("sign_out", provider)
		providers_changed.emit()


## Deletes the player and every cloud copy (App Store rule 5.1.1(v)); the game on this
## device keeps its local save and starts again as a new guest.
func delete_account() -> bool:
	var r: Dictionary = await client.delete_account()
	if int(r["status"]) != 200:
		_set_status(OFFLINE if int(r["status"]) == 0 else status, UI.t("CLOUD_DELETE_FAILED"))
		return false
	state["player_id"] = ""
	state["token"] = ""
	state["last_upload_id"] = ""
	state["providers"] = []
	client.token = ""
	_save_state()
	providers_changed.emit()
	_set_status(IDLE)
	return true


# ------------------------------------------------------------------ HTTP

func _http(method: int, url: String, headers: PackedStringArray, body: String) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	if req.request(url, headers, method, body) != OK:
		req.queue_free()
		return {"status": 0, "json": {}}
	var res: Array = await req.request_completed
	req.queue_free()
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
		return {"status": 0, "json": {}}
	var j = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	return {"status": int(res[1]), "json": j if j is Dictionary else {}}


# ------------------------------------------------------------------ conflict dialog

static func describe(p: Dictionary) -> String:
	return UI.t("CLOUD_PROGRESS") % [p["levels"], p["islands"], p["tasks"]]


func _show_conflict() -> void:
	if Router.dry_run or DisplayServer.get_name() == "headless":
		return
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = CanvasLayer.new()
	_dialog.layer = 60
	add_child(_dialog)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog.add_child(cc)
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(620, 0)
	cc.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	v.add_child(UI.label(UI.t("CLOUD_CONFLICT_TITLE"), "HeadingLabel", 38, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UI.label(UI.t("CLOUD_CONFLICT_BODY"), "CaptionLabel", 24, HORIZONTAL_ALIGNMENT_CENTER))
	var here := UI.button(UI.t("CLOUD_KEEP_DEVICE") + "\n" + describe(CloudSnapshot.progress_of(Game.data)), "", "SecondaryButton", Vector2(0, 120))
	here.name = "KeepDevice"
	here.pressed.connect(resolve.bind(true))
	v.add_child(here)
	var cloud := UI.button(UI.t("CLOUD_USE_CLOUD") + "\n" + describe(CloudSnapshot.progress_of(pending["data"])), "", "PrimaryButton", Vector2(0, 120))
	cloud.name = "UseCloud"
	cloud.pressed.connect(resolve.bind(false))
	v.add_child(cloud)
