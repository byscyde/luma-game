class_name PlatformServices
extends RefCounted
## Thin seam for platform-specific features. Store/achievement SDKs (Game
## Center, Google Play Games) plug in here later without touching gameplay.


static func vibrate(ms: int) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(ms, 0.4)


static func report_achievement(achievement_id: String) -> void:
	# No platform achievement service is integrated yet (documented in
	# docs/RELEASE_RUNBOOK.md). Achievements are tracked locally in the save.
	if OS.is_debug_build():
		print_verbose("achievement unlocked locally: ", achievement_id)


static func is_mobile() -> bool:
	return OS.has_feature("mobile")


## Safe area in viewport (canvas) coordinates.
static func safe_area_rect(viewport: Viewport) -> Rect2:
	var full := viewport.get_visible_rect()
	var safe := DisplayServer.get_display_safe_area()
	var screen := DisplayServer.screen_get_size()
	if safe.size.x <= 0 or screen.x <= 0 or not is_mobile():
		return full
	var sx := full.size.x / float(screen.x)
	var sy := full.size.y / float(screen.y)
	return Rect2(safe.position.x * sx, safe.position.y * sy, safe.size.x * sx, safe.size.y * sy)
