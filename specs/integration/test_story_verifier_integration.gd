extends GutTest

# Tests d'integration pour le verificateur d'histoire

const MainScript = preload("res://src/main.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")

var _main: Control


func before_each():
	_main = Control.new()
	_main.set_script(MainScript)
	add_child_autofree(_main)


func _make_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Test"
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Ch1"
	var scene = SceneDataScript.new()
	scene.scene_name = "Sc1"
	var seq = SequenceScript.new()
	seq.seq_name = "Seq1"
	scene.sequences.append(seq)
	scene.entry_point_uuid = seq.uuid
	chapter.scenes.append(scene)
	chapter.entry_point_uuid = scene.uuid
	story.chapters.append(chapter)
	story.entry_point_uuid = chapter.uuid
	return story


# === Menu Histoire ===

func test_histoire_menu_contains_verify_item():
	var popup = _main._histoire_menu.get_popup()
	assert_eq(popup.get_item_text(popup.get_item_index(5)), "Vérifier l'histoire")


# === Panel rapport ===

func test_verifier_report_panel_exists():
	assert_not_null(_main._verifier_report_panel)

func test_verifier_report_panel_initially_hidden():
	assert_false(_main._verifier_report_panel.visible)

func test_verify_shows_report_panel():
	var story = _make_story()
	_main._editor_main.open_story(story)
	_main._nav_ctrl.on_verify_pressed()
	assert_true(_main._verifier_report_panel.visible, "Panel rapport visible apres verification")
	assert_false(_main._chapter_graph_view.visible, "Graphs masques pendant verification")

func test_close_report_restores_view():
	var story = _make_story()
	_main._editor_main.open_story(story)
	_main._nav_ctrl.on_verify_pressed()
	_main._nav_ctrl.on_verifier_close()
	assert_false(_main._verifier_report_panel.visible, "Panel rapport masque apres fermeture")
	assert_true(_main._chapter_graph_view.visible, "Graphs restaures apres fermeture")
