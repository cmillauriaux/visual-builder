extends GutTest

# Tests pour StoryPathRewriter (réécriture des chemins images pour l'export)

const StoryPathRewriter = preload("res://src/export/story_path_rewriter.gd")
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
	_test_dir = "user://test_rewriter_%d" % randi()
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
			DirAccess.remove_absolute(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


# --- Tests de réécriture des backgrounds ---

func test_rewrite_background_user_path():
	var story = _create_story_with_background("user://stories/test/assets/backgrounds/forest.png")
	StorySaver.save_story(story, _test_dir)

	var result = StoryPathRewriter.rewrite_story_paths(_test_dir, "res://story")

	assert_true(result)
	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.chapters[0].scenes[0].sequences[0].background, "res://story/assets/backgrounds/forest.png")


# --- Tests de réécriture des foregrounds ---

func test_rewrite_foreground_user_path():
	var story = _create_story_with_foreground("user://stories/test/assets/foregrounds/hero.png")
	StorySaver.save_story(story, _test_dir)

	var result = StoryPathRewriter.rewrite_story_paths(_test_dir, "res://story")

	assert_true(result)
	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.chapters[0].scenes[0].sequences[0].foregrounds[0].image, "res://story/assets/foregrounds/hero.png")


# --- Tests de réécriture des foregrounds dans les dialogues ---

func test_rewrite_dialogue_foreground():
	var story = _create_story_with_dialogue_foreground("user://stories/test/assets/foregrounds/npc.png")
	StorySaver.save_story(story, _test_dir)

	var result = StoryPathRewriter.rewrite_story_paths(_test_dir, "res://story")

	assert_true(result)
	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.chapters[0].scenes[0].sequences[0].dialogues[0].foregrounds[0].image, "res://story/assets/foregrounds/npc.png")


# --- Tests de chemins vides ---

func test_rewrite_empty_path():
	var story = _create_story_with_background("")
	StorySaver.save_story(story, _test_dir)

	StoryPathRewriter.rewrite_story_paths(_test_dir, "res://story")

	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.chapters[0].scenes[0].sequences[0].background, "")


# --- Tests de chemins res:// déjà corrects ---

func test_rewrite_already_res_path():
	var story = _create_story_with_background("res://story/assets/backgrounds/already.png")
	StorySaver.save_story(story, _test_dir)

	StoryPathRewriter.rewrite_story_paths(_test_dir, "res://story")

	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.chapters[0].scenes[0].sequences[0].background, "res://story/assets/backgrounds/already.png")


# --- Tests que menu_background n'est pas touché ---

func test_rewrite_preserves_menu_background():
	var story = _create_story_with_background("user://stories/test/assets/backgrounds/bg.png")
	story.menu_background = "backgrounds/menu_bg.png"
	StorySaver.save_story(story, _test_dir)

	StoryPathRewriter.rewrite_story_paths(_test_dir, "res://story")

	var loaded = StorySaver.load_story(_test_dir)
	assert_eq(loaded.menu_background, "backgrounds/menu_bg.png")


# --- Test roundtrip complet ---

func test_rewrite_full_story_roundtrip():
	var story = _create_full_story()
	StorySaver.save_story(story, _test_dir)

	var result = StoryPathRewriter.rewrite_story_paths(_test_dir, "res://story")
	assert_true(result)

	var loaded = StorySaver.load_story(_test_dir)

	# Story metadata intacte
	assert_eq(loaded.title, "Mon Aventure")
	assert_eq(loaded.menu_background, "backgrounds/menu.png")

	var seq = loaded.chapters[0].scenes[0].sequences[0]
	# Background réécrit
	assert_eq(seq.background, "res://story/assets/backgrounds/forest.png")
	# Foreground séquence réécrit
	assert_eq(seq.foregrounds[0].image, "res://story/assets/foregrounds/hero.png")
	# Foreground dialogue réécrit
	assert_eq(seq.dialogues[0].foregrounds[0].image, "res://story/assets/foregrounds/npc.png")
	# Dialogue sans foreground inchangé
	assert_eq(seq.dialogues[1].foregrounds.size(), 0)


# --- Test story introuvable ---

func test_rewrite_returns_false_on_missing_story():
	var result = StoryPathRewriter.rewrite_story_paths("user://nonexistent_dir_99999", "res://story")
	assert_false(result)


# --- Test foreground réécrit mais les autres propriétés préservées ---

func test_rewrite_preserves_foreground_properties():
	var story = _create_story_with_foreground("user://stories/test/assets/foregrounds/hero.png")
	var fg = story.chapters[0].scenes[0].sequences[0].foregrounds[0]
	fg.fg_name = "Hero"
	fg.z_order = 5
	fg.opacity = 0.8
	fg.flip_h = true
	fg.scale = 2.0
	fg.anchor_bg = Vector2(0.3, 0.7)
	fg.transition_type = "fade"
	fg.transition_duration = 1.5
	StorySaver.save_story(story, _test_dir)

	StoryPathRewriter.rewrite_story_paths(_test_dir, "res://story")

	var loaded = StorySaver.load_story(_test_dir)
	var loaded_fg = loaded.chapters[0].scenes[0].sequences[0].foregrounds[0]
	assert_eq(loaded_fg.image, "res://story/assets/foregrounds/hero.png")
	assert_eq(loaded_fg.fg_name, "Hero")
	assert_eq(loaded_fg.z_order, 5)
	assert_almost_eq(loaded_fg.opacity, 0.8, 0.01)
	assert_true(loaded_fg.flip_h)
	assert_almost_eq(loaded_fg.scale, 2.0, 0.01)
	assert_eq(loaded_fg.transition_type, "fade")
	assert_almost_eq(loaded_fg.transition_duration, 1.5, 0.01)


# --- Helpers ---

func _create_story_with_background(bg_path: String) -> RefCounted:
	var story = Story.new()
	story.title = "Test"
	var chapter = Chapter.new()
	chapter.chapter_name = "Ch1"
	var scene = SceneData.new()
	scene.scene_name = "Sc1"
	var seq = Sequence.new()
	seq.seq_name = "Seq1"
	seq.background = bg_path
	var dlg = Dialogue.new()
	dlg.character = "Test"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	scene.sequences.append(seq)
	chapter.scenes.append(scene)
	story.chapters.append(chapter)
	return story


func _create_story_with_foreground(fg_path: String) -> RefCounted:
	var story = _create_story_with_background("")
	var fg = Foreground.new()
	fg.fg_name = "Hero"
	fg.image = fg_path
	story.chapters[0].scenes[0].sequences[0].foregrounds.append(fg)
	return story


func _create_story_with_dialogue_foreground(fg_path: String) -> RefCounted:
	var story = _create_story_with_background("")
	var fg = Foreground.new()
	fg.fg_name = "NPC"
	fg.image = fg_path
	story.chapters[0].scenes[0].sequences[0].dialogues[0].foregrounds.append(fg)
	return story


func _create_full_story() -> RefCounted:
	var story = Story.new()
	story.title = "Mon Aventure"
	story.menu_background = "backgrounds/menu.png"

	var chapter = Chapter.new()
	chapter.chapter_name = "Chapitre 1"

	var scene = SceneData.new()
	scene.scene_name = "Scène 1"

	var seq = Sequence.new()
	seq.seq_name = "Exploration"
	seq.background = "user://stories/aventure/assets/backgrounds/forest.png"

	# Foreground sur la séquence
	var fg = Foreground.new()
	fg.fg_name = "Héros"
	fg.image = "user://stories/aventure/assets/foregrounds/hero.png"
	seq.foregrounds.append(fg)

	# Dialogue 1 avec foreground
	var dlg1 = Dialogue.new()
	dlg1.character = "Héros"
	dlg1.text = "Bonjour !"
	var dlg_fg = Foreground.new()
	dlg_fg.fg_name = "PNJ"
	dlg_fg.image = "user://stories/aventure/assets/foregrounds/npc.png"
	dlg1.foregrounds.append(dlg_fg)
	seq.dialogues.append(dlg1)

	# Dialogue 2 sans foreground
	var dlg2 = Dialogue.new()
	dlg2.character = "Narrateur"
	dlg2.text = "Un silence..."
	seq.dialogues.append(dlg2)

	scene.sequences.append(seq)
	chapter.scenes.append(scene)
	story.chapters.append(chapter)
	return story
