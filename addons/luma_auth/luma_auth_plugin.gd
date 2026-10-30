@tool
extends EditorPlugin
## Adds the LUMA sign-in plugin to Android exports (Godot v2 Android plugin). The AAR is
## built by tools/ci/build_auth_plugin_android.sh into addons/luma_auth/bin/; without it
## (local exports) the game simply offers no sign-in buttons. iOS uses a GDExtension
## that the iOS workflow builds and adds (tools/ci/build_auth_plugin_ios.sh).

var _export: AndroidExport


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport:
	extends EditorExportPlugin

	const AAR := "luma_auth/bin/luma-auth.aar"   ## relative to res://addons/

	func _get_name() -> String:
		return "LumaAuth"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _has_aar() -> bool:
		return FileAccess.file_exists("res://addons/" + AAR)

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([AAR]) if _has_aar() else PackedStringArray()

	# Keep in step with plugins/luma_auth/android/build.gradle.kts.
	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not _has_aar():
			return PackedStringArray()
		return PackedStringArray([
			"androidx.credentials:credentials:1.5.0",
			"androidx.credentials:credentials-play-services-auth:1.5.0",
			"com.google.android.libraries.identity.googleid:googleid:1.1.1",
			"androidx.browser:browser:1.8.0",
			"org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0",
		])

	## androidx.credentials brings biometric permissions for passkeys, which LUMA does not
	## use; CI allows only VIBRATE and INTERNET.
	func _get_android_manifest_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		if not _has_aar():
			return ""
		return """
	<uses-permission android:name="android.permission.USE_BIOMETRIC" tools:node="remove" />
	<uses-permission android:name="android.permission.USE_FINGERPRINT" tools:node="remove" />
"""

	## Facebook sends the player back to fb<app id>://authorize/: this activity catches it.
	func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
		var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://resources/cloud/cloud_config.json"))
		var fb := str(cfg.get("facebook_app_id", "")) if cfg is Dictionary else ""
		if not _has_aar() or fb == "" or not fb.is_valid_int():
			return ""
		return """
		<activity android:name="com.scyde.lumaauth.RedirectActivity" android:exported="true"
			android:launchMode="singleTask" android:theme="@android:style/Theme.Translucent.NoTitleBar">
			<intent-filter>
				<action android:name="android.intent.action.VIEW" />
				<category android:name="android.intent.category.DEFAULT" />
				<category android:name="android.intent.category.BROWSABLE" />
				<data android:scheme="fb%s" android:host="authorize" />
			</intent-filter>
		</activity>
""" % fb
