extends "res://specs/e2e/e2e_game_base.gd"

## Tests e2e — Jeu standalone avec clics UI réels.
##
## Ces tests simulent de vrais clics souris aux coordonnées des contrôles
## via GutInputSender + Input.parse_input_event(), en mode non-headless.


func test_new_game_from_main_menu():
	var story = await show_main_menu_with_story()

	# Le menu principal doit être visible
	assert_true(_game._main_menu.visible, "Main menu should be visible")
	assert_false(_game._story_selector.visible, "Story selector should be hidden")

	# Clic réel sur "Nouvelle partie" dans le menu principal
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")

	# Le jeu doit avoir démarré
	assert_true(_game._menu_button.visible, "Menu button should be visible during play")

	# Vérifier qu'on est sur la séquence Intro
	var current = _game._story_play_ctrl.get_current_sequence()
	assert_eq(current.seq_name, "Intro")


func test_choice_selection_via_button_click():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")

	# Déclencher la fin de séquence → les choix apparaissent
	_game._story_play_ctrl.on_sequence_finished()
	assert_eq(_game._story_play_ctrl.get_state(), _game._story_play_ctrl.State.WAITING_FOR_CHOICE)

	# Les choix doivent être affichés
	assert_true(_game._choice_overlay.visible, "Choice overlay should be visible")
	await _ui.wait_frames(3)

	# Clic sur "Chemin A" (choix index 0)
	await _ui.click_choice(_game._choice_panel, 0)

	# On doit jouer la Séquence A maintenant
	assert_eq(_game._story_play_ctrl.get_state(), _game._story_play_ctrl.State.PLAYING_SEQUENCE)
	var current = _game._story_play_ctrl.get_current_sequence()
	assert_eq(current.seq_name, "Séquence A")

	# La variable score doit avoir été mise à jour
	assert_eq(_game._story_play_ctrl.get_variable("score"), "10")


func test_pause_menu_resume_via_button_click():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(2)

	# Ouvrir le menu pause (on passe par show_menu directement car
	# _on_menu_button_pressed fait un screenshot qui peut échouer en test)
	_game._pause_menu.show_menu()
	_game.get_tree().paused = true
	await _ui.wait_frames(3)

	assert_true(_game._pause_menu.visible, "Pause menu should be visible")

	# Clic réel sur "Reprendre"
	await _ui.click_button(_game._pause_menu._resume_button, "Reprendre")

	# Le handler resume_pressed → _on_pause_resume doit se déclencher
	# Vérifier que le menu est fermé et le jeu dépaused
	await _ui.wait_frames(2)
	assert_false(_game._pause_menu.visible, "Pause menu should be hidden after resume")


func test_full_playthrough_to_be_continued_via_clicks():
	var story = await show_main_menu_with_story()

	# Démarrer la partie via clic sur Nouvelle partie
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")

	# Vérifier qu'on est sur Intro
	var current = _game._story_play_ctrl.get_current_sequence()
	assert_eq(current.seq_name, "Intro")

	# Fin de séquence Intro → choix apparaissent
	_game._story_play_ctrl.on_sequence_finished()
	assert_true(_game._choice_overlay.visible, "Choices should be visible")
	await _ui.wait_frames(3)

	# Clic sur "Chemin A" (index 0)
	await _ui.click_choice(_game._choice_panel, 0)
	current = _game._story_play_ctrl.get_current_sequence()
	assert_eq(current.seq_name, "Séquence A")

	# Fin de Séquence A → auto redirect vers Scène 2 → Finale
	_game._story_play_ctrl.on_sequence_finished()
	current = _game._story_play_ctrl.get_current_sequence()
	assert_eq(current.seq_name, "Finale")

	# Fin de Finale → to_be_continued
	watch_signals(_game._story_play_ctrl)
	_game._story_play_ctrl.on_sequence_finished()
	assert_signal_emitted_with_parameters(
		_game._story_play_ctrl, "play_finished", ["to_be_continued"])
