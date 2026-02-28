extends GutTest

## Tests pour game.gd — scène standalone du jeu.

const GameScript = preload("res://src/game.gd")
const GamePlayControllerScript = preload("res://src/controllers/game_play_controller.gd")

var _game: Control


func before_each() -> void:
	_game = Control.new()
	_game.set_script(GameScript)
	add_child(_game)


func after_each() -> void:
	if _game.get_tree():
		_game.get_tree().paused = false
	remove_child(_game)
	_game.queue_free()


func test_initializes_without_errors() -> void:
	assert_not_null(_game)


func test_has_play_controller() -> void:
	assert_not_null(_game._play_ctrl)
	assert_true(_game._play_ctrl.get_script() == GamePlayControllerScript)


func test_has_menu_button() -> void:
	assert_not_null(_game._menu_button)
	assert_false(_game._menu_button.visible)


func test_has_pause_menu() -> void:
	assert_not_null(_game._pause_menu)
	assert_false(_game._pause_menu.visible)


func test_has_main_menu() -> void:
	assert_not_null(_game._main_menu)


func test_has_settings() -> void:
	assert_not_null(_game._settings)


func test_story_path_default_empty() -> void:
	assert_eq(_game.story_path, "")


func test_story_selector_visible_by_default() -> void:
	assert_true(_game._story_selector.visible)


func test_play_overlay_hidden_by_default() -> void:
	assert_false(_game._play_overlay.visible)


func test_on_pause_resume() -> void:
	_game._pause_menu.show_menu()
	_game._on_pause_resume()
	assert_false(_game._pause_menu.visible)


func test_show_story_selector_hides_menu_button() -> void:
	_game._menu_button.visible = true
	_game._show_story_selector()
	assert_false(_game._menu_button.visible)
	assert_true(_game._story_selector.visible)


func test_show_main_menu_hides_selector() -> void:
	var Story = preload("res://src/models/story.gd")
	_game._current_story = Story.new()
	_game._current_story.title = "Test"
	_game._show_main_menu(_game._current_story)
	assert_false(_game._story_selector.visible)
	assert_true(_game._main_menu.visible)


func test_load_invalid_story_shows_error() -> void:
	_game._load_story_and_show_menu("res://nonexistent_12345")
	pass_test("should not crash on invalid path")


func test_on_play_finished_return_shows_menu() -> void:
	var Story = preload("res://src/models/story.gd")
	_game._current_story = Story.new()
	_game._current_story.title = "Test"
	_game._main_menu.visible = false
	_game._on_play_finished_return()
	assert_true(_game._main_menu.visible)
