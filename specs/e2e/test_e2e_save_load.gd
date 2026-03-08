extends GutTest

## Tests e2e — Cycle sauvegarde/chargement d'une histoire.

const MainScript = preload("res://src/main.gd")
const StorySaver = preload("res://src/persistence/story_saver.gd")

var _main: Control
var _test_dir: String = ""


func before_each():
	_test_dir = "user://test_e2e_save_load_" + str(randi())
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)
	await get_tree().process_frame


func after_each():
	if _main:
		_main.queue_free()
		_main = null
	_remove_dir_recursive(_test_dir)


func _remove_dir_recursive(path: String) -> void:
	var dir = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if dir.current_is_dir():
			_remove_dir_recursive(path + "/" + fname)
		else:
			dir.remove(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func test_save_and_load_roundtrip():
	# Créer une histoire complète
	_main._nav_ctrl.on_new_story_pressed()
	_main._nav_ctrl.on_create_pressed()  # 2ème chapitre
	assert_eq(_main._editor_main._story.chapters.size(), 2)

	var story = _main._editor_main._story
	var original_title = story.title
	var original_ch_count = story.chapters.size()
	var original_ch1_name = story.chapters[0].chapter_name
	var original_ch1_scene_count = story.chapters[0].scenes.size()

	# Sauvegarder
	StorySaver.save_story(story, _test_dir)
	assert_true(FileAccess.file_exists(_test_dir + "/story.yaml"), "story.yaml should exist")

	# Charger
	var loaded = StorySaver.load_story(_test_dir)
	assert_not_null(loaded, "Loaded story should not be null")
	assert_eq(loaded.title, original_title)
	assert_eq(loaded.chapters.size(), original_ch_count)
	assert_eq(loaded.chapters[0].chapter_name, original_ch1_name)
	assert_eq(loaded.chapters[0].scenes.size(), original_ch1_scene_count)

	# Vérifier les dialogues
	var original_seq = story.chapters[0].scenes[0].sequences[0]
	var loaded_seq = loaded.chapters[0].scenes[0].sequences[0]
	assert_eq(loaded_seq.dialogues.size(), original_seq.dialogues.size())
	assert_eq(loaded_seq.dialogues[0].character, original_seq.dialogues[0].character)
	assert_eq(loaded_seq.dialogues[0].text, original_seq.dialogues[0].text)


func test_save_modify_save_load():
	_main._nav_ctrl.on_new_story_pressed()
	var story = _main._editor_main._story

	# Première sauvegarde
	StorySaver.save_story(story, _test_dir)

	# Ajouter un chapitre
	_main._nav_ctrl.on_create_pressed()
	assert_eq(story.chapters.size(), 2)

	# Deuxième sauvegarde
	StorySaver.save_story(story, _test_dir)

	# Charger
	var loaded = StorySaver.load_story(_test_dir)
	assert_not_null(loaded)
	assert_eq(loaded.chapters.size(), 2, "Second chapter should be present after save/load")


func test_load_into_editor_replaces_state():
	# Créer et sauvegarder story A
	_main._nav_ctrl.on_new_story_pressed()
	_main._editor_main._story.title = "Story A"
	StorySaver.save_story(_main._editor_main._story, _test_dir)

	# Créer story B
	_main._nav_ctrl.on_new_story_pressed()
	assert_eq(_main._editor_main._story.title, "Mon Histoire")

	# Charger story A
	_main._nav_ctrl._on_load_dir_selected(_test_dir)
	assert_eq(_main._editor_main._story.title, "Story A", "Editor should show loaded story")
	assert_eq(_main._editor_main.get_current_level(), "chapters")
