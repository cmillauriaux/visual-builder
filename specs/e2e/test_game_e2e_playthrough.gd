extends GutTest

## Tests e2e — Playthrough complet du jeu standalone.

const GameScript = preload("res://src/game.gd")
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


func test_new_game_to_dialogue_display():
	var story = E2eStoryBuilder.make_branching_story()
	_game._play_ctrl.start_story(story)
	assert_true(_game._menu_button.visible, "Menu button should be visible during play")
	assert_true(_game._play_overlay.visible, "Play overlay should be visible")

	# Vérifier que le premier dialogue est affiché
	_game._play_ctrl.on_play_dialogue_changed(0)
	assert_eq(_game._play_character_label.text, "Narrateur")
	assert_eq(_game._play_text_label.text, "Bienvenue, que choisissez-vous ?")


func test_full_playthrough_path_a_to_be_continued():
	var story = E2eStoryBuilder.make_branching_story()
	_game._play_ctrl.start_story(story)

	# Vérifier qu'on est sur la séquence Intro
	var current = _game._story_play_ctrl.get_current_sequence()
	assert_eq(current.seq_name, "Intro")

	# Simuler fin de séquence → choix affiché
	watch_signals(_game._story_play_ctrl)
	_game._story_play_ctrl.on_sequence_finished()
	assert_eq(_game._story_play_ctrl.get_state(), _game._story_play_ctrl.State.WAITING_FOR_CHOICE)
	assert_signal_emitted(_game._story_play_ctrl, "choice_display_requested")

	# Choisir "Chemin A" (index 0) → redirect vers Séquence A
	_game._story_play_ctrl.on_choice_selected(0)
	assert_eq(_game._story_play_ctrl.get_state(), _game._story_play_ctrl.State.PLAYING_SEQUENCE)
	current = _game._story_play_ctrl.get_current_sequence()
	assert_eq(current.seq_name, "Séquence A")

	# Fin de Séquence A → auto redirect vers Scène 2 → Finale
	_game._story_play_ctrl.on_sequence_finished()
	assert_eq(_game._story_play_ctrl.get_state(), _game._story_play_ctrl.State.PLAYING_SEQUENCE)
	current = _game._story_play_ctrl.get_current_sequence()
	assert_eq(current.seq_name, "Finale")

	# Fin de Finale → to_be_continued
	_game._story_play_ctrl.on_sequence_finished()
	assert_eq(_game._story_play_ctrl.get_state(), _game._story_play_ctrl.State.IDLE)
	assert_signal_emitted_with_parameters(_game._story_play_ctrl, "play_finished", ["to_be_continued"])


func test_game_over_path():
	var story = E2eStoryBuilder.make_branching_story()
	_game._play_ctrl.start_story(story)

	watch_signals(_game._story_play_ctrl)

	# Fin de l'intro → choix
	_game._story_play_ctrl.on_sequence_finished()
	assert_eq(_game._story_play_ctrl.get_state(), _game._story_play_ctrl.State.WAITING_FOR_CHOICE)

	# Choisir "Game Over" (index 1) → game_over
	_game._story_play_ctrl.on_choice_selected(1)
	assert_eq(_game._story_play_ctrl.get_state(), _game._story_play_ctrl.State.IDLE)
	assert_signal_emitted_with_parameters(_game._story_play_ctrl, "play_finished", ["game_over"])


func test_variables_updated_by_choice():
	var story = E2eStoryBuilder.make_branching_story()
	_game._play_ctrl.start_story(story)

	# Score initial = "0"
	assert_eq(_game._story_play_ctrl.get_variable("score"), "0")

	# Fin intro → choix
	_game._story_play_ctrl.on_sequence_finished()

	# Choisir "Chemin A" (index 0) → score incrémenté de 10
	_game._story_play_ctrl.on_choice_selected(0)
	assert_eq(_game._story_play_ctrl.get_variable("score"), "10")
