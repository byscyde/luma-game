class_name NativeAuth
extends RefCounted
## Bridge to the native sign-in plugin ("LumaAuth": plugins/ios and plugins/android).
## The plugin shows the system's Apple / Google / Facebook sign-in and answers with
## the provider's token, which the server checks. Without the plugin (editor,
## desktop, tests) nothing is available and the buttons are hidden.
##
## Plugin contract:
##   configure(config_json: String)     client ids from resources/cloud/cloud_config.json
##   is_available(provider: String) -> bool
##   sign_in(provider: String, nonce: String) -> void
##   sign_out(provider: String) -> void
##   signal sign_in_completed(provider: String, token: String, error: String)

const SINGLETON := "LumaAuth"
const CONFIG_PATH := "res://resources/cloud/cloud_config.json"

static var _configured := false


static func plugin() -> Object:
	if not Engine.has_singleton(SINGLETON):
		return null
	var p := Engine.get_singleton(SINGLETON)
	if not _configured:
		_configured = true
		p.call("configure", FileAccess.get_file_as_string(CONFIG_PATH))
	return p


static func available(provider: String) -> bool:
	var p := plugin()
	return p != null and bool(p.call("is_available", provider))


## Providers to offer on this device, in display order (Apple only on Apple devices).
static func providers() -> Array:
	var out: Array = []
	for prov in ["apple", "google", "facebook"]:
		if available(prov):
			out.append(prov)
	return out
