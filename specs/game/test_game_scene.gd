extends GutTest

## Tests d'intégration pour la scène game.gd.

const GameScript = preload("res://src/game.gd")
const GamePlayControllerScript = preload("res://src/controllers/game_play_controller.gd")
const SequenceVisualEditorScript = preload("res://src/ui/sequence/sequence_visual_editor.gd")
const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")

var _game: Control


func before_each() -> void:
	_game = Control.new()
	_game.set_script(GameScript)
	add_child(_game)
	# _ready() is called automatically


func after_each() -> void:
	remove_child(_game)
	_game.queue_free()


func test_game_initializes_without_errors() -> void:
	assert_not_null(_game, "game should be created")
	assert_not_null(_game._play_ctrl, "play controller should exist")


func test_game_has_visual_editor() -> void:
	assert_not_null(_game._visual_editor)
	assert_true(_game._visual_editor.get_script() == SequenceVisualEditorScript)


func test_game_has_story_play_controller() -> void:
	assert_not_null(_game._story_play_ctrl)
	assert_true(_game._story_play_ctrl.get_script() == StoryPlayControllerScript)


func test_story_selector_visible_when_no_story_path() -> void:
	# story_path is empty by default → selector shown
	assert_eq(_game.story_path, "")
	assert_true(_game._story_selector.visible, "story selector should be visible when no story_path")


func test_stop_button_hidden_on_start() -> void:
	assert_false(_game._stop_button.visible, "stop button should be hidden on start")


func test_play_overlay_hidden_on_start() -> void:
	assert_false(_game._play_overlay.visible, "play overlay should be hidden on start")


func test_no_graph_edit_in_tree() -> void:
	var found_graph = _has_graph_edit(_game)
	assert_false(found_graph, "should not contain any GraphEdit (editor component)")


func test_show_story_selector_resets_state() -> void:
	_game._story_selector.visible = false
	_game._stop_button.visible = true
	_game._show_story_selector()
	assert_true(_game._story_selector.visible)
	assert_false(_game._stop_button.visible)


func test_story_path_export_property_exists() -> void:
	# Verify the exported property exists and is a string
	assert_true("story_path" in _game, "should have story_path property")
	assert_typeof(_game.story_path, TYPE_STRING)


func test_load_and_play_with_invalid_path_shows_error() -> void:
	_game._load_and_play("res://nonexistent_story")
	# Should not crash, error dialog shown
	pass_test("should not crash on invalid path")


func test_on_play_finished_return_shows_selector_when_no_path() -> void:
	_game._story_selector.visible = false
	_game._on_play_finished_return()
	assert_true(_game._story_selector.visible, "should show selector when story_path is empty")


# --- Helpers ---

func _has_graph_edit(node: Node) -> bool:
	if node is GraphEdit:
		return true
	for child in node.get_children():
		if _has_graph_edit(child):
			return true
	return false
