extends GutTest

# Tests pour le fil d'Ariane (Breadcrumb)

var Breadcrumb = load("res://src/ui/navigation/breadcrumb.gd")

var _breadcrumb: HBoxContainer = null

func before_each():
	_breadcrumb = HBoxContainer.new()
	_breadcrumb.set_script(Breadcrumb)
	add_child_autofree(_breadcrumb)

func test_set_story_level():
	_breadcrumb.set_path(["Mon Histoire"])
	assert_eq(_breadcrumb.get_path_labels(), ["Mon Histoire"])

func test_set_chapter_level():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1"])
	assert_eq(_breadcrumb.get_path_labels(), ["Mon Histoire", "Chapitre 1"])

func test_set_scene_level():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1", "Scène 1"])
	assert_eq(_breadcrumb.get_path_labels(), ["Mon Histoire", "Chapitre 1", "Scène 1"])

func test_set_sequence_level():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1", "Scène 1", "Séquence 1"])
	assert_eq(_breadcrumb.get_path_labels(), ["Mon Histoire", "Chapitre 1", "Scène 1", "Séquence 1"])

func test_click_emits_signal():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1", "Scène 1"])
	watch_signals(_breadcrumb)
	_breadcrumb.navigate_to(0)
	assert_signal_emitted(_breadcrumb, "level_clicked")

func test_separator_present():
	_breadcrumb.set_path(["A", "B", "C"])
	# Il doit y avoir des séparateurs entre les éléments
	assert_true(_breadcrumb.get_child_count() > 3, "Il doit y avoir des séparateurs")
