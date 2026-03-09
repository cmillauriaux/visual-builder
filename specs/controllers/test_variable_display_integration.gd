extends GutTest

## Tests d'intégration pour l'affichage des variables pendant le jeu.
## Vérifie que le signal variables_display_changed est émis aux bons moments
## et que le cleanup masque correctement la sidebar et l'overlay.

const StoryPlayController = preload("res://src/ui/play/story_play_controller.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")
const EffectScript = preload("res://src/models/variable_effect.gd")
const VariableSidebarScript = preload("res://src/ui/play/variable_sidebar.gd")
const VariableDetailsOverlayScript = preload("res://src/ui/play/variable_details_overlay.gd")

var _ctrl: Node
var _sidebar: VBoxContainer
var _overlay: CenterContainer


func before_each() -> void:
	_ctrl = Node.new()
	_ctrl.set_script(StoryPlayController)
	add_child_autofree(_ctrl)
	_sidebar = VBoxContainer.new()
	_sidebar.set_script(VariableSidebarScript)
	add_child_autofree(_sidebar)
	_overlay = CenterContainer.new()
	_overlay.set_script(VariableDetailsOverlayScript)
	_overlay.build_ui()
	add_child_autofree(_overlay)


# --- Helpers ---

func _make_story_with_display_vars() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Test"
	var v1 = VariableDefinitionScript.new()
	v1.var_name = "score"
	v1.initial_value = "0"
	v1.show_on_main = true
	v1.show_on_details = true
	story.variables.append(v1)
	var v2 = VariableDefinitionScript.new()
	v2.var_name = "hidden"
	v2.initial_value = "0"
	v2.show_on_main = true
	v2.visibility_mode = "variable"
	v2.visibility_variable = "score"
	story.variables.append(v2)
	var ch = ChapterScript.new()
	ch.chapter_name = "Ch1"
	ch.position = Vector2(100, 100)
	var sc = SceneDataScript.new()
	sc.scene_name = "Sc1"
	sc.position = Vector2(100, 100)
	var seq = SequenceScript.new()
	seq.seq_name = "Seq1"
	seq.position = Vector2(100, 100)
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	sc.sequences.append(seq)
	sc.entry_point_uuid = seq.uuid
	ch.scenes.append(sc)
	ch.entry_point_uuid = sc.uuid
	story.chapters.append(ch)
	story.entry_point_uuid = ch.uuid
	return story


# --- Tests : Signal emission ---

func test_signal_emitted_on_start_play_story() -> void:
	var story = _make_story_with_display_vars()
	watch_signals(_ctrl)
	_ctrl.start_play_story(story)
	assert_signal_emitted(_ctrl, "variables_display_changed")


func test_signal_emitted_on_start_play_chapter() -> void:
	var story = _make_story_with_display_vars()
	var chapter = story.chapters[0]
	watch_signals(_ctrl)
	_ctrl.start_play_chapter(story, chapter)
	assert_signal_emitted(_ctrl, "variables_display_changed")


func test_signal_emitted_on_start_play_scene() -> void:
	var story = _make_story_with_display_vars()
	var chapter = story.chapters[0]
	var scene = chapter.scenes[0]
	watch_signals(_ctrl)
	_ctrl.start_play_scene(story, chapter, scene)
	assert_signal_emitted(_ctrl, "variables_display_changed")


func test_signal_emitted_on_start_play_from_save() -> void:
	var story = _make_story_with_display_vars()
	var chapter = story.chapters[0]
	var scene = chapter.scenes[0]
	var seq = scene.sequences[0]
	watch_signals(_ctrl)
	_ctrl.start_play_from_save(story, chapter, scene, seq, {"score": "5"})
	assert_signal_emitted(_ctrl, "variables_display_changed")


func test_signal_emitted_on_apply_effects() -> void:
	var story = _make_story_with_display_vars()
	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	# Simuler un choix avec effet
	var seq = story.chapters[0].scenes[0].sequences[0]
	var ending = EndingScript.new()
	ending.type = "choices"
	var choice = ChoiceScript.new()
	choice.text = "Add score"
	var effect = EffectScript.new()
	effect.operation = "set"
	effect.variable = "score"
	effect.value = "10"
	choice.effects.append(effect)
	var cons = ConsequenceScript.new()
	cons.type = "game_over"
	choice.consequence = cons
	ending.choices.append(choice)
	seq.ending = ending
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.WAITING_FOR_CHOICE)
	_ctrl.on_choice_selected(0)
	assert_signal_emitted(_ctrl, "variables_display_changed")


func test_signal_contains_variables_dict() -> void:
	var story = _make_story_with_display_vars()
	var received_vars := []
	_ctrl.variables_display_changed.connect(func(vars): received_vars.append(vars))
	_ctrl.start_play_story(story)
	assert_eq(received_vars.size(), 1)
	assert_eq(received_vars[0]["score"], "0")
	assert_eq(received_vars[0]["hidden"], "0")


# --- Tests : Sidebar update via signal ---

func test_sidebar_updated_on_signal() -> void:
	var story = _make_story_with_display_vars()
	_ctrl.variables_display_changed.connect(func(vars): _sidebar.update_display(vars, story))
	_ctrl.start_play_story(story)
	# score has show_on_main=true and visibility_mode="always" → visible
	# hidden has show_on_main=true but visibility_mode="variable" with score="0" → hidden
	assert_true(_sidebar.visible)
	assert_eq(_sidebar.get_child_count(), 1)  # Only "score" visible


func test_sidebar_hidden_after_cleanup() -> void:
	var story = _make_story_with_display_vars()
	_ctrl.variables_display_changed.connect(func(vars): _sidebar.update_display(vars, story))
	_ctrl.start_play_story(story)
	assert_true(_sidebar.visible)
	# Simulate cleanup
	_sidebar.visible = false
	assert_false(_sidebar.visible)


# --- Tests : Overlay ---

func test_overlay_show_details() -> void:
	var story = _make_story_with_display_vars()
	_ctrl.start_play_story(story)
	var vars = {"score": "5", "hidden": "0"}
	_overlay.show_details(story, vars)
	assert_true(_overlay.visible)
	# score has show_on_details=true → visible
	assert_eq(_overlay.get_displayed_count(), 1)


func test_overlay_hide_details() -> void:
	var story = _make_story_with_display_vars()
	var vars = {"score": "5"}
	_overlay.show_details(story, vars)
	assert_true(_overlay.visible)
	_overlay.hide_details()
	assert_false(_overlay.visible)


func test_overlay_close_signal() -> void:
	watch_signals(_overlay)
	_overlay._close_btn.emit_signal("pressed")
	assert_signal_emitted(_overlay, "close_requested")
