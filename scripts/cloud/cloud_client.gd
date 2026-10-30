class_name CloudClient
extends RefCounted
## Talks to the LUMA cloud API (server/luma-cloud). Every call returns
## {"status": int, "json": Dictionary}; status 0 means the server could not be reached.
## The transport is injectable so tests run without a network.

var base_url := ""
var token := ""
## func(method: int, url: String, headers: PackedStringArray, body: String) -> {"status", "json"} (awaitable)
var transport: Callable


func _init(p_base_url: String, p_transport: Callable) -> void:
	base_url = p_base_url.trim_suffix("/")
	transport = p_transport


func call_api(method: int, path: String, body: Variant = null, auth := true) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if auth and token != "":
		headers.append("Authorization: Bearer " + token)
	var text := "" if body == null else JSON.stringify(body)
	var r: Dictionary = await transport.call(method, base_url + path, headers, text)
	return r


func guest(device_id: String) -> Dictionary:
	return await call_api(HTTPClient.METHOD_POST, "/v1/guest", {"deviceId": device_id}, false)


func sign_in(provider: String, provider_token: String, nonce: String) -> Dictionary:
	return await call_api(HTTPClient.METHOD_POST, "/v1/auth/" + provider, {"token": provider_token, "nonce": nonce})


func me() -> Dictionary:
	return await call_api(HTTPClient.METHOD_GET, "/v1/me")


func unlink(provider: String) -> Dictionary:
	return await call_api(HTTPClient.METHOD_POST, "/v1/unlink/" + provider, {})


func delete_account() -> Dictionary:
	return await call_api(HTTPClient.METHOD_DELETE, "/v1/me")


func get_save(key: String) -> Dictionary:
	return await call_api(HTTPClient.METHOD_GET, "/v1/save/" + key)


func put_save(key: String, value: String) -> Dictionary:
	return await call_api(HTTPClient.METHOD_PUT, "/v1/save/" + key, {"value": value})
