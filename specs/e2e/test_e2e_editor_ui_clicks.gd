extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Workflows éditeur avec clics UI réels.
##
## Ces tests simulent de vrais clics souris aux coordonnées des contrôles
## via GutInputSender + Input.parse_input_event(), en mode non-headless.


func test_create_story_via_button_click():
	# L'écran d'accueil doit être visible
	assert_true(_main._welcome_screen.visible, "Welcome screen should be visible")
	assert_false(_main._chapter_graph_view.visible, "Chapter view should be hidden")

	# Clic réel sur "Nouvelle histoire"
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")

	# Vérifier que la story est créée et la vue chapitres affichée
	assert_false(_main._welcome_screen.visible, "Welcome screen should be hidden after create")
	assert_true(_main._chapter_graph_view.visible, "Chapter view should be visible")
	assert_eq(_main._editor_main._story.title, "Mon Histoire")
	assert_eq(_ui.count_graph_nodes(_main._chapter_graph_view), 1)


func test_full_navigation_via_double_clicks():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")

	# Niveau chapitres
	assert_eq(_main._editor_main.get_current_level(), "chapters")

	# Double-clic chapitre → scènes
	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	await _ui.double_click_graph_node(_main._chapter_graph_view, ch_uuid)
	assert_eq(_main._editor_main.get_current_level(), "scenes")
	assert_true(_main._scene_graph_view.visible, "Scene view should be visible")

	# Double-clic scène → séquences
	var sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	await _ui.double_click_graph_node(_main._scene_graph_view, sc_uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequences")
	assert_true(_main._sequence_graph_view.visible, "Sequence view should be visible")

	# Double-clic séquence → éditeur de séquence
	var seq_uuid = _main._editor_main._current_scene.sequences[0].uuid
	await _ui.double_click_graph_node(_main._sequence_graph_view, seq_uuid)
	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")
	assert_true(_main._sequence_editor_panel.visible, "Sequence editor should be visible")

	# Retour via bouton Back
	await _ui.click_button(_main._back_button, "Retour")
	assert_eq(_main._editor_main.get_current_level(), "sequences")

	await _ui.click_button(_main._back_button, "Retour")
	assert_eq(_main._editor_main.get_current_level(), "scenes")

	await _ui.click_button(_main._back_button, "Retour")
	assert_eq(_main._editor_main.get_current_level(), "chapters")


func test_create_chapters_via_button():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")
	assert_eq(_main._editor_main._story.chapters.size(), 1)

	# Clic sur le bouton Créer (contextuel : crée un chapitre au niveau chapitres)
	await _ui.click_button(_main._create_button, "Créer chapitre")
	assert_eq(_main._editor_main._story.chapters.size(), 2)
	assert_eq(_ui.count_graph_nodes(_main._chapter_graph_view), 2)

	# Créer un troisième chapitre
	await _ui.click_button(_main._create_button, "Créer chapitre")
	assert_eq(_main._editor_main._story.chapters.size(), 3)
	assert_eq(_ui.count_graph_nodes(_main._chapter_graph_view), 3)


func test_add_dialogue_via_button_click():
	await navigate_to_sequence_edit_via_ui()
	assert_eq(_main._editor_main.get_current_level(), "sequence_edit")

	# Vérifier le nombre initial de dialogues
	assert_eq(_main._editor_main._current_sequence.dialogues.size(), 1)

	# Clic sur "Ajouter dialogue"
	await _ui.click_button(_main._add_dialogue_btn, "Ajouter dialogue")
	assert_eq(_main._editor_main._current_sequence.dialogues.size(), 2)


func test_undo_redo_via_button_clicks():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")
	assert_eq(_main._editor_main._story.chapters.size(), 1)

	# Créer un chapitre
	await _ui.click_button(_main._create_button, "Créer chapitre")
	assert_eq(_main._editor_main._story.chapters.size(), 2)

	# Annuler
	await _ui.click_button(_main._undo_button, "Annuler")
	assert_eq(_main._editor_main._story.chapters.size(), 1)

	# Rétablir
	await _ui.click_button(_main._redo_button, "Rétablir")
	assert_eq(_main._editor_main._story.chapters.size(), 2)


func test_histoire_menu_new_story():
	# Créer une story d'abord pour que le menu soit visible
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")
	assert_eq(_main._editor_main._story.title, "Mon Histoire")
	_main._editor_main._story.title = "Titre Modifié"

	# Menu Histoire → Nouvelle histoire (id 0)
	await _ui.select_menu_item(_main._histoire_menu, 0, "Histoire > Nouvelle histoire")

	# Une nouvelle story devrait être créée
	assert_eq(_main._editor_main._story.title, "Mon Histoire")
	assert_eq(_main._editor_main._story.chapters.size(), 1)
