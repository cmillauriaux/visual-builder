extends GutTest

## Tests pour la fonctionnalité Skip (spec 057).
## Couvre :
##  - SequenceEditor.skip_to_end()
##  - GamePlayController.is_scene_available() (logique de disponibilité)
##  - GamePlayController.set_skip_progression() + update_skip_availability()

const SequenceEditorScript = preload("res://src/ui/sequence/sequence_editor.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const GamePlayControllerScript = preload("res://src/controllers/game_play_controller.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_sequence_with_dialogues(count: int):
	var seq = SequenceScript.new()
	for i in range(count):
		var dlg = DialogueScript.new()
		dlg.character = "Personnage"
		dlg.text = "Dialogue %d" % i
		seq.dialogues.append(dlg)
	return seq


# ---------------------------------------------------------------------------
# SequenceEditor — skip_to_end()
# ---------------------------------------------------------------------------

func test_skip_to_end_stops_playing() -> void:
	var editor = Control.new()
	editor.set_script(SequenceEditorScript)
	add_child_autofree(editor)
	var seq = _make_sequence_with_dialogues(3)
	editor.load_sequence(seq)
	editor.start_play()
	assert_true(editor.is_playing(), "doit être en lecture avant skip")
	editor.skip_to_end()
	assert_false(editor.is_playing(), "ne doit plus être en lecture après skip_to_end")


func test_skip_to_end_marks_text_fully_displayed() -> void:
	var editor = Control.new()
	editor.set_script(SequenceEditorScript)
	add_child_autofree(editor)
	var seq = _make_sequence_with_dialogues(2)
	editor.load_sequence(seq)
	editor.start_play()
	editor.skip_to_end()
	assert_true(editor.is_text_fully_displayed(), "texte doit être marqué comme entièrement affiché")


func test_skip_to_end_does_nothing_when_not_playing() -> void:
	var editor = Control.new()
	editor.set_script(SequenceEditorScript)
	add_child_autofree(editor)
	var seq = _make_sequence_with_dialogues(2)
	editor.load_sequence(seq)
	# Ne pas démarrer la lecture
	editor.skip_to_end()
	assert_false(editor.is_playing(), "ne doit pas démarrer la lecture")
	assert_false(editor.is_text_fully_displayed())


func test_skip_to_end_does_not_emit_play_stopped_signal() -> void:
	var editor = Control.new()
	editor.set_script(SequenceEditorScript)
	add_child_autofree(editor)
	var seq = _make_sequence_with_dialogues(2)
	editor.load_sequence(seq)
	editor.start_play()
	watch_signals(editor)
	editor.skip_to_end()
	assert_signal_not_emitted(editor, "play_stopped")


func test_skip_to_end_on_empty_sequence_does_not_crash() -> void:
	var editor = Control.new()
	editor.set_script(SequenceEditorScript)
	add_child_autofree(editor)
	var seq = _make_sequence_with_dialogues(0)
	editor.load_sequence(seq)
	# start_play ne démarre pas si vide, mais on vérifie qu'appeler skip_to_end ne crashe pas
	editor.skip_to_end()
	assert_true(true, "pas de crash")


# ---------------------------------------------------------------------------
# GamePlayController — is_scene_available() (logique statique de disponibilité)
# ---------------------------------------------------------------------------

func test_is_scene_available_no_saves() -> void:
	# max_ch = -1 → rien n'est disponible
	assert_false(
		GamePlayControllerScript.is_scene_available(0, 0, -1, -1),
		"aucune sauvegarde → toujours indisponible"
	)


func test_is_scene_available_chapter_before_max() -> void:
	# chapter_index < max_chapter_index → disponible
	assert_true(
		GamePlayControllerScript.is_scene_available(0, 5, 2, 0),
		"chapitre avant max → disponible"
	)


func test_is_scene_available_same_chapter_scene_at_max() -> void:
	# chapter_index == max_chapter_index ET scene_index == max_scene_index → disponible
	assert_true(
		GamePlayControllerScript.is_scene_available(1, 3, 1, 3),
		"chapitre et scène égaux au max → disponible"
	)


func test_is_scene_available_same_chapter_scene_before_max() -> void:
	assert_true(
		GamePlayControllerScript.is_scene_available(1, 1, 1, 5),
		"même chapitre, scène avant max → disponible"
	)


func test_is_scene_available_same_chapter_scene_after_max() -> void:
	assert_false(
		GamePlayControllerScript.is_scene_available(1, 6, 1, 5),
		"même chapitre, scène après max → indisponible"
	)


func test_is_scene_available_chapter_after_max() -> void:
	assert_false(
		GamePlayControllerScript.is_scene_available(3, 0, 2, 10),
		"chapitre après max → indisponible"
	)


func test_is_scene_available_first_chapter_first_scene_with_one_save() -> void:
	# Si la sauvegarde est au chapitre 0 scène 0, alors la scène 0-0 est disponible
	assert_true(
		GamePlayControllerScript.is_scene_available(0, 0, 0, 0),
		"scène 0-0 disponible si sauvegarde en 0-0"
	)


# ---------------------------------------------------------------------------
# GamePlayController — set_skip_progression() + update_skip_availability()
# ---------------------------------------------------------------------------

func test_set_skip_progression_then_available_scene_enables_button() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)

	var btn = Button.new()
	add_child_autofree(btn)
	ctrl._skip_button = btn
	btn.disabled = true

	ctrl.set_skip_progression(1, 2)
	# Scène disponible (ch=0 < max_ch=1)
	ctrl.update_skip_availability(0, 0)
	assert_false(btn.disabled, "bouton doit être activé pour une scène disponible")


func test_set_skip_progression_then_unavailable_scene_disables_button() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)

	var btn = Button.new()
	add_child_autofree(btn)
	ctrl._skip_button = btn
	btn.disabled = false

	ctrl.set_skip_progression(1, 2)
	# Scène non disponible (ch=2 > max_ch=1)
	ctrl.update_skip_availability(2, 0)
	assert_true(btn.disabled, "bouton doit être désactivé pour une scène non disponible")


func test_update_skip_availability_without_button_does_not_crash() -> void:
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)
	ctrl._skip_button = null
	ctrl.set_skip_progression(0, 0)
	ctrl.update_skip_availability(0, 0)
	assert_true(true, "pas de crash sans bouton")


func test_default_skip_button_is_disabled() -> void:
	# Sans progression définie (max_ch=-1), le bouton doit rester grisé
	var ctrl = Node.new()
	ctrl.set_script(GamePlayControllerScript)
	add_child_autofree(ctrl)

	var btn = Button.new()
	add_child_autofree(btn)
	btn.disabled = false
	ctrl._skip_button = btn

	# Sans appel à set_skip_progression, la progression est -1
	ctrl.update_skip_availability(0, 0)
	assert_true(btn.disabled, "sans sauvegarde, bouton doit être grisé")
