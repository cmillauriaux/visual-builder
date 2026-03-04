extends GutTest

const StorySaver = preload("res://src/persistence/story_saver.gd")
const Story = preload("res://src/models/story.gd")
const Chapter = preload("res://src/models/chapter.gd")
const SceneData = preload("res://src/models/scene_data.gd")
const Sequence = preload("res://src/models/sequence.gd")
const VariableDefinition = preload("res://src/models/variable_definition.gd")

var _test_dir: String = ""


func before_each():
	_test_dir = "user://test_var_display_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_test_dir)


func after_each():
	_remove_dir_recursive(_test_dir)


func _remove_dir_recursive(path: String):
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
		var full_path = path + "/" + file_name
		if dir.current_is_dir():
			_remove_dir_recursive(full_path)
		else:
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _make_minimal_story() -> RefCounted:
	var story = Story.new()
	story.title = "Test"
	var ch = Chapter.new()
	ch.chapter_name = "Ch1"
	var sc = SceneData.new()
	sc.scene_name = "Sc1"
	var seq = Sequence.new()
	seq.seq_name = "Seq1"
	sc.sequences.append(seq)
	ch.scenes.append(sc)
	story.chapters.append(ch)
	return story


func test_save_load_variable_with_display_fields():
	var story = _make_minimal_story()
	var v = VariableDefinition.new()
	v.var_name = "score"
	v.initial_value = "0"
	v.show_on_main = true
	v.show_on_details = true
	v.visibility_mode = "variable"
	v.visibility_variable = "unlocked"
	v.image = "assets/foregrounds/coin.png"
	v.description = "Votre score"
	story.variables.append(v)

	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)

	assert_not_null(loaded)
	assert_eq(loaded.variables.size(), 1)
	var lv = loaded.variables[0]
	assert_eq(lv.var_name, "score")
	assert_eq(lv.initial_value, "0")
	assert_eq(lv.show_on_main, true)
	assert_eq(lv.show_on_details, true)
	assert_eq(lv.visibility_mode, "variable")
	assert_eq(lv.visibility_variable, "unlocked")
	assert_eq(lv.description, "Votre score")


func test_save_load_retrocompat_no_display_fields():
	var story = _make_minimal_story()
	var v = VariableDefinition.new()
	v.var_name = "health"
	v.initial_value = "100"
	story.variables.append(v)

	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)

	assert_not_null(loaded)
	assert_eq(loaded.variables.size(), 1)
	var lv = loaded.variables[0]
	assert_eq(lv.var_name, "health")
	assert_eq(lv.show_on_main, false)
	assert_eq(lv.show_on_details, false)
	assert_eq(lv.visibility_mode, "always")
	assert_eq(lv.visibility_variable, "")
	assert_eq(lv.image, "")
	assert_eq(lv.description, "")


func test_save_load_multiple_variables_mixed():
	var story = _make_minimal_story()

	var v1 = VariableDefinition.new()
	v1.var_name = "score"
	v1.initial_value = "0"
	v1.show_on_main = true
	v1.description = "Score du joueur"
	story.variables.append(v1)

	var v2 = VariableDefinition.new()
	v2.var_name = "hidden"
	v2.initial_value = "x"
	story.variables.append(v2)

	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)

	assert_eq(loaded.variables.size(), 2)
	assert_eq(loaded.variables[0].show_on_main, true)
	assert_eq(loaded.variables[0].description, "Score du joueur")
	assert_eq(loaded.variables[1].show_on_main, false)
	assert_eq(loaded.variables[1].description, "")
