extends GutTest

# Tests pour StorySaver (sauvegarde/chargement d'histoires)

const StorySaver = preload("res://src/persistence/story_saver.gd")
const Story = preload("res://src/models/story.gd")
const Chapter = preload("res://src/models/chapter.gd")
const SceneData = preload("res://src/models/scene_data.gd")
const Sequence = preload("res://src/models/sequence.gd")
const Foreground = preload("res://src/models/foreground.gd")
const Dialogue = preload("res://src/models/dialogue.gd")
const Ending = preload("res://src/models/ending.gd")
const Choice = preload("res://src/models/choice.gd")
const Consequence = preload("res://src/models/consequence.gd")

var _test_dir: String = ""

func before_each():
	# Utilise un dossier temporaire unique pour chaque test
	_test_dir = "user://test_story_%d" % randi()
	DirAccess.make_dir_recursive_absolute(_test_dir)

func after_each():
	# Nettoie le dossier temporaire
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
			DirAccess.remove_absolute(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)

# --- Tests de sauvegarde ---

func test_save_creates_story_yaml():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	assert_true(FileAccess.file_exists(_test_dir + "/story.yaml"))

func test_save_creates_chapter_directories():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var ch_uuid = story.chapters[0].uuid
	assert_true(DirAccess.dir_exists_absolute(_test_dir + "/chapters/" + ch_uuid))

func test_save_creates_chapter_yaml():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var ch_uuid = story.chapters[0].uuid
	assert_true(FileAccess.file_exists(_test_dir + "/chapters/" + ch_uuid + "/chapter.yaml"))

func test_save_creates_scene_yaml():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var ch_uuid = story.chapters[0].uuid
	var scene_uuid = story.chapters[0].scenes[0].uuid
	assert_true(FileAccess.file_exists(_test_dir + "/chapters/" + ch_uuid + "/scenes/" + scene_uuid + ".yaml"))

func test_save_creates_assets_dirs():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	assert_true(DirAccess.dir_exists_absolute(_test_dir + "/assets/backgrounds"))
	assert_true(DirAccess.dir_exists_absolute(_test_dir + "/assets/foregrounds"))

# --- Tests de chargement ---

func test_load_story():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	assert_not_null(loaded)
	assert_eq(loaded.title, "Mon Histoire")
	assert_eq(loaded.author, "Auteur")
	assert_eq(loaded.version, "1.0.0")

func test_load_story_chapters():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.chapters.size(), 1)
	assert_eq(loaded.chapters[0].chapter_name, "Chapitre 1")

func test_load_story_scenes():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.chapters[0].scenes.size(), 1)
	assert_eq(loaded.chapters[0].scenes[0].scene_name, "Scène 1")

func test_load_story_sequences():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	var seq = loaded.chapters[0].scenes[0].sequences[0]
	assert_eq(seq.seq_name, "Exploration")
	assert_eq(seq.background, "foret.png")

func test_load_story_dialogues():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	var seq = loaded.chapters[0].scenes[0].sequences[0]
	assert_eq(seq.dialogues.size(), 1)
	assert_eq(seq.dialogues[0].character, "Héros")
	assert_eq(seq.dialogues[0].text, "Où suis-je ?")

func test_load_story_connections():
	var story = _create_test_story()
	story.connections.append({"from": story.chapters[0].uuid, "to": "other-uuid"})
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.connections.size(), 1)

func test_load_story_foregrounds():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	var seq = loaded.chapters[0].scenes[0].sequences[0]
	assert_eq(seq.foregrounds.size(), 1)
	assert_eq(seq.foregrounds[0].fg_name, "Héros")
	assert_eq(seq.foregrounds[0].image, "personnage-a.png")

func test_load_story_ending():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	var seq = loaded.chapters[0].scenes[0].sequences[0]
	assert_not_null(seq.ending)
	assert_eq(seq.ending.type, "choices")
	assert_eq(seq.ending.choices.size(), 1)
	assert_eq(seq.ending.choices[0].text, "Abandonner")

# --- Test cycle complet ---

func test_full_roundtrip():
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)

	# Vérifie que les données sont intactes
	assert_eq(loaded.title, story.title)
	assert_eq(loaded.author, story.author)
	assert_eq(loaded.description, story.description)
	assert_eq(loaded.version, story.version)
	assert_eq(loaded.chapters.size(), story.chapters.size())

	var orig_ch = story.chapters[0]
	var load_ch = loaded.chapters[0]
	assert_eq(load_ch.uuid, orig_ch.uuid)
	assert_eq(load_ch.chapter_name, orig_ch.chapter_name)

	var orig_scene = orig_ch.scenes[0]
	var load_scene = load_ch.scenes[0]
	assert_eq(load_scene.uuid, orig_scene.uuid)
	assert_eq(load_scene.scene_name, orig_scene.scene_name)

	var orig_seq = orig_scene.sequences[0]
	var load_seq = load_scene.sequences[0]
	assert_eq(load_seq.uuid, orig_seq.uuid)
	assert_eq(load_seq.seq_name, orig_seq.seq_name)
	assert_eq(load_seq.background, orig_seq.background)
	assert_eq(load_seq.dialogues.size(), orig_seq.dialogues.size())
	assert_eq(load_seq.foregrounds.size(), orig_seq.foregrounds.size())

# --- Test date de modification mise à jour ---

func test_save_updates_modified_date():
	var story = _create_test_story()
	var original_date = story.updated_at
	story.touch()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	assert_ne(loaded.updated_at, "", "updated_at ne doit pas être vide")

# --- Tests subtitle roundtrip ---

func test_subtitle_roundtrip():
	var story = _create_test_story()
	story.chapters[0].subtitle = "Le début de l'aventure"
	story.chapters[0].scenes[0].subtitle = "Arrivée en forêt"
	story.chapters[0].scenes[0].sequences[0].subtitle = "Exploration initiale"
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.chapters[0].subtitle, "Le début de l'aventure")
	assert_eq(loaded.chapters[0].scenes[0].subtitle, "Arrivée en forêt")
	assert_eq(loaded.chapters[0].scenes[0].sequences[0].subtitle, "Exploration initiale")

func test_subtitle_retrocompat_load():
	# Simuler un fichier sans subtitle (ancienne version)
	var story = _create_test_story()
	StorySaver.save_story(story, _test_dir)
	var loaded = StorySaver.load_story(_test_dir)
	# Les subtitles doivent être vides par défaut
	assert_eq(loaded.chapters[0].subtitle, "")
	assert_eq(loaded.chapters[0].scenes[0].subtitle, "")
	assert_eq(loaded.chapters[0].scenes[0].sequences[0].subtitle, "")

# --- Helper ---

func _create_test_story() -> RefCounted:
	var story = Story.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	story.description = "Une aventure"
	story.version = "1.0.0"

	var chapter = Chapter.new()
	chapter.chapter_name = "Chapitre 1"
	chapter.position = Vector2(100, 200)

	var scene = SceneData.new()
	scene.scene_name = "Scène 1"
	scene.position = Vector2(50, 100)

	var seq = Sequence.new()
	seq.seq_name = "Exploration"
	seq.position = Vector2(0, 0)
	seq.background = "foret.png"

	var fg = Foreground.new()
	fg.fg_name = "Héros"
	fg.image = "personnage-a.png"
	fg.z_order = 1
	fg.anchor_bg = Vector2(0.5, 0.8)
	fg.anchor_fg = Vector2(0.5, 1.0)
	seq.foregrounds.append(fg)

	var dlg = Dialogue.new()
	dlg.character = "Héros"
	dlg.text = "Où suis-je ?"
	seq.dialogues.append(dlg)

	var ending = Ending.new()
	ending.type = "choices"
	var choice = Choice.new()
	choice.text = "Abandonner"
	choice.consequence = Consequence.new()
	choice.consequence.type = "game_over"
	ending.choices.append(choice)
	seq.ending = ending

	scene.sequences.append(seq)
	chapter.scenes.append(scene)
	story.chapters.append(chapter)

	return story
