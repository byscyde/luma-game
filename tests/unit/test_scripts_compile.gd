extends TestCase
## Every script must compile. GDScript only reports parse errors when a file is
## loaded, so a screen that is rarely opened could otherwise hide a broken build.


func _scripts(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		_scripts(dir_path.path_join(sub), out)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))


func test_all_game_and_tool_scripts_compile() -> void:
	var files: Array[String] = []
	_scripts("res://scripts", files)
	_scripts("res://tools", files)
	assert_true(files.size() > 20, "found scripts")
	for f in files:
		var s: GDScript = load(f)
		assert_not_null(s, "load " + f)
		if s:
			assert_true(s.can_instantiate(), "compile " + f)


func test_all_scenes_load() -> void:
	for f in ["res://scenes/boot/boot.tscn", "res://scenes/menus/main_menu.tscn", "res://scenes/gameplay/gameplay.tscn",
			"res://scenes/island/island.tscn", "res://scenes/menus/collection.tscn", "res://scenes/menus/settings.tscn",
			"res://scenes/merge/merge.tscn"]:
		var ps: PackedScene = load(f)
		assert_not_null(ps, f)
		if ps:
			assert_true(ps.can_instantiate(), "instantiable " + f)
