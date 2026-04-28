extends "res://specs/e2e/e2e_editor_base.gd"

## Tests e2e — Opérations de renommage (chapitres, scènes, séquences, story).
##
## Utilise emit_rename_confirmed() pour simuler la confirmation du
## RenameDialog (fenêtre séparée → fallback signal).


func test_rename_chapter_via_menu():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")
	var story = _main._editor_main._story
	var ch_uuid = story.chapters[0].uuid

	await _ui.emit_rename_confirmed(
		_main._nav_ctrl, "on_chapter_rename_requested", ch_uuid,
		"Chapitre Renommé", "Sous-titre chapitre")

	assert_eq(story.chapters[0].chapter_name, "Chapitre Renommé",
		"Chapter name should be updated")
	assert_eq(story.chapters[0].subtitle, "Sous-titre chapitre",
		"Chapter subtitle should be updated")


func test_rename_scene_via_menu():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")

	# Naviguer au niveau scènes
	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	await _ui.double_click_graph_node(_main._chapter_graph_view, ch_uuid)

	var scene = _main._editor_main._current_chapter.scenes[0]
	var sc_uuid = scene.uuid

	await _ui.emit_rename_confirmed(
		_main._nav_ctrl, "on_scene_rename_requested", sc_uuid,
		"Scène Renommée", "Sous-titre scène")

	assert_eq(scene.scene_name, "Scène Renommée",
		"Scene name should be updated")
	assert_eq(scene.subtitle, "Sous-titre scène",
		"Scene subtitle should be updated")


func test_rename_sequence_via_menu():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")

	# Naviguer au niveau séquences
	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	await _ui.double_click_graph_node(_main._chapter_graph_view, ch_uuid)

	var sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	await _ui.double_click_graph_node(_main._scene_graph_view, sc_uuid)

	var seq = _main._editor_main._current_scene.sequences[0]
	var seq_uuid = seq.uuid

	await _ui.emit_rename_confirmed(
		_main._nav_ctrl, "on_sequence_rename_requested", seq_uuid,
		"Séquence Renommée", "")

	assert_eq(seq.seq_name, "Séquence Renommée",
		"Sequence name should be updated")


func test_rename_story_via_config():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")
	var story = _main._editor_main._story
	assert_eq(story.title, "Mon Histoire")

	# Le renommage se fait maintenant via le dialogue de configuration
	# On teste ici directement la méthode confirmée car simuler tout le dialogue est complexe en E2E
	_main._nav_ctrl.on_story_rename_confirmed("Titre Modifié")
	await _ui.wait_frames()

	assert_eq(story.title, "Titre Modifié",
		"Story title should be updated")


func test_rename_with_subtitle():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")
	var story = _main._editor_main._story
	var ch_uuid = story.chapters[0].uuid

	await _ui.emit_rename_confirmed(
		_main._nav_ctrl, "on_chapter_rename_requested", ch_uuid,
		"Prologue", "Le début de l'aventure")

	assert_eq(story.chapters[0].chapter_name, "Prologue")
	assert_eq(story.chapters[0].subtitle, "Le début de l'aventure")


func test_delete_chapter_via_menu():
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")

	# Créer un deuxième chapitre
	await _ui.click_button(_main._create_button, "Créer chapitre")
	var story = _main._editor_main._story
	assert_eq(story.chapters.size(), 2)

	var ch2_uuid = story.chapters[1].uuid
	# Supprimer via le menu contextuel du nœud graphe (id=2)
	await _ui.right_click_graph_node_menu(_main._chapter_graph_view, ch2_uuid, 2)

	assert_eq(story.chapters.size(), 1,
		"Should have 1 chapter after deletion")
