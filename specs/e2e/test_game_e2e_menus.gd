extends GutTest

## Tests e2e — Menus du jeu (menu principal, pause, résumé).

const GameScript = preload("res://src/game.gd")
const StoryScript = preload("res://src/models/story.gd")
const E2eStoryBuilder = preload("res://specs/e2e/e2e_story_builder.gd")

var _game: Control


func before_each():
	_game = Control.new()
	_game.set_script(GameScript)
	add_child(_game)


func after_each():
	if _game and _game.get_tree():
		_game.get_tree().paused = false
	if _game:
		remove_child(_game)
		_game.queue_free()
		_game = null


func test_story_selector_visible_on_start():
	assert_true(_game._story_selector.visible, "Story selector should be visible on start")
	assert_false(_game._main_menu.visible, "Main menu should be hidden on start")
	assert_false(_game._play_overlay.visible, "Play overlay should be hidden on start")


func test_main_menu_to_play_to_pause_to_resume():
	# Afficher le menu principal
	var story = E2eStoryBuilder.make_branching_story()
	_game._current_story = story
	_game._show_main_menu(story)
	assert_true(_game._main_menu.visible, "Main menu should be visible")
	assert_false(_game._story_selector.visible, "Story selector should be hidden")

	# Lancer la partie
	_game._play_ctrl.start_story(story)
	assert_true(_game._menu_button.visible, "Menu button should appear during play")

	# Ouvrir le menu pause
	_game._pause_menu.show_menu()
	assert_true(_game._pause_menu.visible, "Pause menu should be visible")

	# Reprendre
	_game._on_pause_resume()
	assert_false(_game._pause_menu.visible, "Pause menu should be hidden after resume")


func test_pause_quit_returns_to_menu():
	var story = E2eStoryBuilder.make_branching_story()
	_game._current_story = story
	_game._show_main_menu(story)

	# Lancer et ouvrir pause
	_game._play_ctrl.start_story(story)
	_game._pause_menu.show_menu()
	assert_true(_game._pause_menu.visible)

	# Quitter vers le menu
	_game._on_play_finished_return()
	assert_true(_game._main_menu.visible, "Main menu should be visible after quit")
