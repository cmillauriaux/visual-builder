extends "res://specs/e2e/e2e_game_base.gd"

## Tests e2e — Historique et skip du jeu.
##
## Utilise make_multi_dialogue_story() : 4 dialogues + ending to_be_continued.


func _start_game_with_multi_dialogues():
	var story = E2eStoryBuilder.make_multi_dialogue_story()
	await show_main_menu_with_story(story)
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(3)
	# Désactiver le typewriter pour que chaque clic avance directement
	_game._play_ctrl.set_typewriter_speed(0.0)
	# Forcer l'affichage complet du texte courant (le dialogue 0 a déjà démarré avec typewriter)
	_game._play_ctrl._sequence_editor_ctrl.skip_typewriter()
	_game._play_ctrl._play_text_label.visible_characters = _game._play_ctrl._sequence_editor_ctrl.get_visible_characters()
	await _ui.wait_frames()
	return story


func test_history_records_dialogues():
	await _start_game_with_multi_dialogues()

	# Le dialogue 0 est déjà affiché → 1 entrée dans l'historique
	assert_true(_game._play_ctrl._dialogue_history.size() >= 1,
		"History should have at least 1 entry for first dialogue")

	# Avancer directement via le contrôleur (plus fiable que le clic UI)
	_game._play_ctrl._sequence_editor_ctrl.advance_play()
	await _ui.wait_frames(3)
	_game._play_ctrl._sequence_editor_ctrl.advance_play()
	await _ui.wait_frames(3)

	# Vérifier que l'historique contient au moins 3 entrées (dialogues 0, 1, 2)
	assert_true(_game._play_ctrl._dialogue_history.size() >= 3,
		"History should have at least 3 entries after advancing 2 times")


func test_history_close():
	await _start_game_with_multi_dialogues()

	# Ouvrir l'historique
	_game._play_ctrl.open_history()
	await _ui.wait_frames(3)

	assert_true(_game._play_ctrl._history_open,
		"History should be open")

	# Fermer l'historique
	_game._play_ctrl.close_history()
	await _ui.wait_frames(3)

	assert_false(_game._play_ctrl._history_open,
		"History should be closed")


func test_history_toggle_via_button():
	await _start_game_with_multi_dialogues()

	# Vérifier que le bouton historique existe et est activé
	assert_not_null(_game._history_button, "History button should exist")

	# Ouvrir via le contrôleur (simule le clic sur le bouton)
	_game._play_ctrl.open_history()
	await _ui.wait_frames(3)
	assert_true(_game._play_ctrl._history_open, "History should be open")

	# Re-toggle pour fermer
	_game._play_ctrl.open_history()  # open_history() est un toggle
	await _ui.wait_frames(3)
	assert_false(_game._play_ctrl._history_open, "History should be closed after toggle")


func test_skip_advances_to_end():
	await _start_game_with_multi_dialogues()

	# Activer le skip (débloquer le bouton en définissant la progression max)
	_game._play_ctrl.set_skip_progression(0, 0)
	_game._play_ctrl.update_skip_availability(0, 0)
	await _ui.wait_frames()

	# Exécuter le skip
	_game._play_ctrl.execute_skip()
	await _ui.wait_frames(3)

	# Après skip, la séquence devrait être terminée
	# (le play controller est passé à finished ou attend la prochaine action)
	assert_false(_game._play_ctrl._sequence_editor_ctrl.is_playing(),
		"Sequence should not be playing after skip")


func test_auto_play_button_toggle():
	await _start_game_with_multi_dialogues()

	var auto_play_mgr = _game._play_ctrl.get_auto_play_manager()
	assert_not_null(auto_play_mgr, "Auto play manager should exist")

	# Vérifier l'état initial
	assert_false(auto_play_mgr.enabled, "Auto play should be off initially")

	# Toggle
	_game._play_ctrl.toggle_auto_play()
	await _ui.wait_frames()

	assert_true(auto_play_mgr.enabled, "Auto play should be on after toggle")

	# Re-toggle
	_game._play_ctrl.toggle_auto_play()
	await _ui.wait_frames()

	assert_false(auto_play_mgr.enabled, "Auto play should be off after second toggle")
