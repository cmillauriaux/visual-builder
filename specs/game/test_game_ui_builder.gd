extends GutTest

## Tests pour GameUIBuilder — construction de l'UI du jeu standalone.

const GameScript = preload("res://src/game.gd")
const GameUIBuilder = preload("res://src/controllers/game_ui_builder.gd")
const SequenceVisualEditorScript = preload("res://src/ui/sequence/sequence_visual_editor.gd")
const ForegroundTransitionScript = preload("res://src/ui/visual/foreground_transition.gd")
const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")
const SequenceEditorScript = preload("res://src/ui/sequence/sequence_editor.gd")

var _game: Control


func before_each() -> void:
	# Utiliser un vrai objet game avec les variables déclarées
	_game = Control.new()
	_game.set_script(GameScript)
	# On appelle build manuellement au lieu de laisser _ready() tout faire
	# car _ready() connecte aussi les signaux (qui nécessitent _play_ctrl)
	# On veut juste tester le builder
	# Astuce : on inhibe _ready en ajoutant l'enfant puis appelant build
	# En fait game._ready appelle tout. Ajoutons-le directement.
	add_child(_game)
	# _ready() a été appelé automatiquement, donc tout est construit


func after_each() -> void:
	remove_child(_game)
	_game.queue_free()


func test_builds_visual_editor() -> void:
	assert_not_null(_game._visual_editor, "visual_editor should be created")
	assert_true(_game._visual_editor.get_script() == SequenceVisualEditorScript)


func test_builds_play_overlay() -> void:
	assert_not_null(_game._play_overlay, "play_overlay should be created")
	assert_false(_game._play_overlay.visible, "play_overlay should start hidden")


func test_builds_character_label() -> void:
	assert_not_null(_game._play_character_label, "character label should be created")


func test_builds_text_label() -> void:
	assert_not_null(_game._play_text_label, "text label should be created")
	assert_true(_game._play_text_label is RichTextLabel)


func test_builds_typewriter_timer() -> void:
	assert_not_null(_game._typewriter_timer, "typewriter timer should be created")
	assert_almost_eq(_game._typewriter_timer.wait_time, 0.03, 0.001)


func test_builds_choice_overlay() -> void:
	assert_not_null(_game._choice_overlay, "choice overlay should be created")
	assert_false(_game._choice_overlay.visible, "choice overlay should start hidden")


func test_builds_menu_button() -> void:
	assert_not_null(_game._menu_button, "menu button should be created")
	assert_false(_game._menu_button.visible, "menu button should start hidden")
	assert_eq(_game._menu_button.text, "☰ Menu")
	assert_eq(_game._menu_button.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_builds_pause_menu() -> void:
	assert_not_null(_game._pause_menu, "pause menu should be created")
	assert_false(_game._pause_menu.visible, "pause menu should start hidden")
	assert_eq(_game._pause_menu.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_builds_sequence_editor_ctrl() -> void:
	assert_not_null(_game._sequence_editor_ctrl, "sequence editor ctrl should be created")
	assert_true(_game._sequence_editor_ctrl.get_script() == SequenceEditorScript)


func test_builds_foreground_transition() -> void:
	assert_not_null(_game._foreground_transition, "foreground transition should be created")
	assert_true(_game._foreground_transition.get_script() == ForegroundTransitionScript)


func test_builds_story_play_ctrl() -> void:
	assert_not_null(_game._story_play_ctrl, "story play ctrl should be created")
	assert_true(_game._story_play_ctrl.get_script() == StoryPlayControllerScript)


func test_builds_story_selector() -> void:
	assert_not_null(_game._story_selector, "story selector should be created")
	assert_true(_game._story_selector.visible, "story selector should be visible initially")


func test_builds_story_list() -> void:
	assert_not_null(_game._story_list, "story list should be created")
	assert_true(_game._story_list is VBoxContainer)


func test_no_editor_components() -> void:
	# Vérifier qu'aucun composant éditeur n'est présent
	for child in _game.get_children():
		assert_false(child is GraphEdit, "should not contain any GraphEdit (editor views)")


func test_builds_variable_sidebar_in_scroll() -> void:
	assert_not_null(_game._variable_sidebar_scroll, "scroll container should be created")
	assert_true(_game._variable_sidebar_scroll is ScrollContainer)
	assert_false(_game._variable_sidebar_scroll.visible, "scroll should start hidden")
	assert_eq(_game._variable_sidebar.get_parent(), _game._variable_sidebar_scroll,
		"sidebar should be child of scroll container")


func test_game_has_kenney_theme() -> void:
	assert_not_null(_game.theme, "Game should have a theme applied")
	var panel_style = _game.theme.get_stylebox("panel", "PanelContainer")
	assert_not_null(panel_style, "Theme should have PanelContainer panel style")
	assert_true(panel_style is StyleBoxTexture, "Panel style should be StyleBoxTexture")
