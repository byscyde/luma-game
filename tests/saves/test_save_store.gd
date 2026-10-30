extends TestCase

const DIR := "user://test_saves"
var store: SaveStore
var path := ""


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	path = DIR.path_join("save_%d.json" % Time.get_ticks_usec())
	store = SaveStore.new(path)


func after_each() -> void:
	store.delete_all()


func _write_raw(p: String, text: String) -> void:
	var f := FileAccess.open(p, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_missing_save_gives_defaults() -> void:
	var d := store.load_data()
	assert_eq(store.last_status, SaveStore.STATUS_NEW)
	assert_eq(int(d["save_version"]), SaveStore.SAVE_VERSION)
	assert_has(d["progress"]["areas_unlocked"], "spring_glade")


func test_round_trip() -> void:
	var d := SaveStore.default_data()
	d["progress"]["essence"] = 42
	d["progress"]["completed"]["w1_l01"] = {"best_moves": 1, "optional": {}, "times": 1}
	d["settings"]["reduced_motion"] = true
	assert_true(store.save_data(d))
	var l := store.load_data()
	assert_eq(store.last_status, SaveStore.STATUS_OK)
	assert_eq(int(l["progress"]["essence"]), 42)
	assert_true(l["progress"]["completed"].has("w1_l01"))
	assert_true(bool(l["settings"]["reduced_motion"]))
	assert_false(FileAccess.file_exists(path + ".tmp"), "temp file cleaned up")


func test_second_save_keeps_backup_of_previous() -> void:
	var d := SaveStore.default_data()
	d["progress"]["essence"] = 1
	store.save_data(d)
	d["progress"]["essence"] = 2
	store.save_data(d)
	assert_true(FileAccess.file_exists(path + ".bak"))
	var bak = JSON.parse_string(FileAccess.get_file_as_string(path + ".bak"))
	assert_eq(int(bak["progress"]["essence"]), 1)


func test_corrupt_main_recovers_from_backup() -> void:
	var d := SaveStore.default_data()
	d["progress"]["essence"] = 7
	store.save_data(d)
	d["progress"]["essence"] = 9
	store.save_data(d)
	_write_raw(path, "{ this is not json")
	var l := store.load_data()
	assert_eq(store.last_status, SaveStore.STATUS_RECOVERED)
	assert_eq(int(l["progress"]["essence"]), 7)
	assert_true(FileAccess.file_exists(path + ".corrupt"), "corrupt file preserved for diagnostics")


func test_truncated_and_empty_files_are_corrupt() -> void:
	_write_raw(path, "")
	assert_eq(int(store.load_data()["progress"]["essence"]), 0)
	assert_eq(store.last_status, SaveStore.STATUS_RESET)
	_write_raw(path, '{"save_version": 1, "progress": {"essence": 5')
	store.load_data()
	assert_eq(store.last_status, SaveStore.STATUS_RESET)


func test_json_that_is_not_a_save_is_rejected() -> void:
	_write_raw(path, '[1, 2, 3]')
	store.load_data()
	assert_eq(store.last_status, SaveStore.STATUS_RESET)


func test_missing_fields_filled_unknown_fields_kept() -> void:
	_write_raw(path, JSON.stringify({"save_version": 1, "progress": {"essence": 12}, "future_feature": {"x": 1}}))
	var l := store.load_data()
	assert_eq(store.last_status, SaveStore.STATUS_OK)
	assert_eq(int(l["progress"]["essence"]), 12, "existing value kept")
	assert_true(l["progress"].has("restoration"), "missing field added")
	assert_true(l["settings"].has("haptics"), "missing section added")
	assert_true(l.has("future_feature"), "unknown field preserved")


func test_invalid_values_repaired() -> void:
	_write_raw(path, JSON.stringify({"save_version": 1, "progress": {
		"essence": -50, "areas_unlocked": ["willow_brook", "willow_brook", 3],
		"discoveries": ["deco_lantern", "deco_lantern"], "restoration": {"glade_tree_1": -2}},
		"settings": {"music_volume": 4.0, "sfx_volume": "loud"}}))
	var l := store.load_data()
	var p: Dictionary = l["progress"]
	assert_eq(int(p["essence"]), 0, "no negative essence")
	assert_eq(p["areas_unlocked"], ["spring_glade", "willow_brook"])
	assert_eq(p["discoveries"], ["deco_lantern"], "duplicate collectible removed")
	assert_eq(int(p["restoration"]["glade_tree_1"]), 0)
	assert_eq(float(l["settings"]["music_volume"]), 1.0)
	assert_eq(float(l["settings"]["sfx_volume"]), 0.9, "wrong type replaced by default")


func test_newer_version_is_not_downgraded_or_destroyed() -> void:
	_write_raw(path, JSON.stringify({"save_version": 99, "progress": {"essence": 3}}))
	var l := store.load_data()
	assert_eq(int(l["save_version"]), 99)
	assert_eq(int(l["progress"]["essence"]), 3)


func test_migration_from_pre_versioned_save() -> void:
	# A save with save_version 0 (pre-release format marker) is upgraded in place.
	_write_raw(path, JSON.stringify({"save_version": 0, "progress": {"essence": 4, "completed": {"w1_l01": {"best_moves": 1}}}}))
	var l := store.load_data()
	assert_eq(int(l["save_version"]), SaveStore.SAVE_VERSION)
	assert_true(l["progress"]["completed"].has("w1_l01"))
	assert_eq(int(l["progress"]["essence"]), 4)
