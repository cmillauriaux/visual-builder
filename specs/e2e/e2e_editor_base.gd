extends GutTest

## Classe de base pour les tests e2e de l'éditeur avec interactions UI réelles.
##
## Instancie main.gd, fixe la taille du viewport pour un layout cohérent,
## et fournit un E2eActionHelper pré-configuré.

const MainScript = preload("res://src/main.gd")
const E2eActionHelper = preload("res://specs/e2e/e2e_action_helper.gd")
const E2eStoryBuilder = preload("res://specs/e2e/e2e_story_builder.gd")

var _main: Control
var _ui: RefCounted  # E2eActionHelper


func before_each():
	# Fixer la taille du viewport pour un layout cohérent
	get_tree().root.size = Vector2i(1920, 1080)

	_main = Control.new()
	_main.set_script(MainScript)
	_main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_main)

	# Attendre que le layout soit complet
	_ui = E2eActionHelper.create(self)
	await _ui.wait_for_layout()


func after_each():
	if _ui:
		_ui.release()
		_ui = null
	if _main:
		_main.queue_free()
		_main = null


## Naviguer jusqu'au niveau "sequence_edit" via clics UI réels.
func navigate_to_sequence_edit_via_ui() -> void:
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")

	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	await _ui.double_click_graph_node(_main._chapter_graph_view, ch_uuid)

	var sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	await _ui.double_click_graph_node(_main._scene_graph_view, sc_uuid)

	var seq_uuid = _main._editor_main._current_scene.sequences[0].uuid
	await _ui.double_click_graph_node(_main._sequence_graph_view, seq_uuid)


## Naviguer jusqu'au niveau "sequences" (vue graphe) via clics UI réels.
func navigate_to_sequences_level_via_ui() -> void:
	await _ui.click_button(_main._new_story_button, "Nouvelle histoire")

	var ch_uuid = _main._editor_main._story.chapters[0].uuid
	await _ui.double_click_graph_node(_main._chapter_graph_view, ch_uuid)

	var sc_uuid = _main._editor_main._current_chapter.scenes[0].uuid
	await _ui.double_click_graph_node(_main._scene_graph_view, sc_uuid)
