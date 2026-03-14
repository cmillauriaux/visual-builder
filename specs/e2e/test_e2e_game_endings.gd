extends "res://specs/e2e/e2e_game_base.gd"

## Tests e2e — Écrans de fin du jeu (game_over, to_be_continued).
##
## Utilise make_branching_story() : chemin A → to_be_continued,
## chemin B (Game Over) → game_over.


func test_game_over_screen_displayed():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")

	# Intro → fin séquence → choix
	_game._story_play_ctrl.on_sequence_finished()
	await _ui.wait_frames(3)

	# Choisir "Game Over" (index 1)
	await _ui.click_choice(_game._choice_panel, 1)
	await _ui.wait_frames(3)

	# L'écran game_over doit être affiché
	assert_true(_game._game_over_screen.visible,
		"Game over screen should be visible")


func test_game_over_back_to_menu():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")

	_game._story_play_ctrl.on_sequence_finished()
	await _ui.wait_frames(3)
	await _ui.click_choice(_game._choice_panel, 1)
	await _ui.wait_frames(3)

	assert_true(_game._game_over_screen.visible)

	# Cliquer sur le bouton retour au menu
	await _ui.click_button(_game._game_over_screen._back_button, "Retour au menu")
	await _ui.wait_frames(3)

	assert_false(_game._game_over_screen.visible,
		"Game over screen should be hidden after back")
	assert_true(_game._main_menu.visible,
		"Main menu should be visible after back")


func test_to_be_continued_screen():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")

	# Parcours complet : Intro → Chemin A → Séquence A → Finale → to_be_continued
	_game._story_play_ctrl.on_sequence_finished()
	await _ui.wait_frames(3)
	await _ui.click_choice(_game._choice_panel, 0)  # Chemin A

	_game._story_play_ctrl.on_sequence_finished()  # Séquence A → Finale
	_game._story_play_ctrl.on_sequence_finished()  # Finale → to_be_continued
	await _ui.wait_frames(3)

	assert_true(_game._to_be_continued_screen.visible,
		"To be continued screen should be visible")


func test_to_be_continued_back_to_menu():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")

	_game._story_play_ctrl.on_sequence_finished()
	await _ui.wait_frames(3)
	await _ui.click_choice(_game._choice_panel, 0)

	_game._story_play_ctrl.on_sequence_finished()
	_game._story_play_ctrl.on_sequence_finished()
	await _ui.wait_frames(3)

	assert_true(_game._to_be_continued_screen.visible)

	await _ui.click_button(_game._to_be_continued_screen._back_button, "Retour au menu")
	await _ui.wait_frames(3)

	assert_false(_game._to_be_continued_screen.visible,
		"To be continued screen should be hidden after back")
	assert_true(_game._main_menu.visible,
		"Main menu should be visible after back")


func test_ending_screen_title():
	var story = await show_main_menu_with_story()

	# Vérifier que les écrans de fin ont des contrôles de titre
	assert_not_null(_game._game_over_screen,
		"Game over screen should exist")
	assert_not_null(_game._to_be_continued_screen,
		"To be continued screen should exist")
	# Les deux écrans doivent avoir un bouton retour
	assert_not_null(_game._game_over_screen._back_button,
		"Game over screen should have back button")
	assert_not_null(_game._to_be_continued_screen._back_button,
		"To be continued screen should have back button")
