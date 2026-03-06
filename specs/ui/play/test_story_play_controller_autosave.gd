extends GutTest

## Tests autosave du StoryPlayController.

const StoryPlayController = preload("res://src/ui/play/story_play_controller.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")

var _ctrl: Node = null


func before_each() -> void:
	_ctrl = Node.new()
	_ctrl.set_script(StoryPlayController)
	add_child_autofree(_ctrl)


# --- Helpers ---

func _make_sequence(name: String, pos: Vector2 = Vector2(100, 100)) -> RefCounted:
	var seq = SequenceScript.new()
	seq.seq_name = name
	seq.position = pos
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	return seq


func _make_ending_choices(choices_data: Array) -> RefCounted:
	var ending = EndingScript.new()
	ending.type = "choices"
	for data in choices_data:
		var choice = ChoiceScript.new()
		choice.text = data["text"]
		var cons = ConsequenceScript.new()
		cons.type = data["type"]
		cons.target = data.get("target", "")
		choice.consequence = cons
		ending.choices.append(choice)
	return ending


func _build_simple_story_with_choices() -> Dictionary:
	var story = StoryScript.new()
	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapitre 1"
	var scene = SceneDataScript.new()
	scene.scene_name = "Scène 1"

	var seq1 = _make_sequence("seq1")
	seq1.ending = _make_ending_choices([
		{"text": "Choix A", "type": "game_over"},
		{"text": "Choix B", "type": "game_over"},
	])
	scene.sequences.append(seq1)
	scene.entry_point_uuid = seq1.uuid

	chapter.scenes.append(scene)
	chapter.entry_point_uuid = scene.uuid
	story.chapters.append(chapter)
	story.entry_point_uuid = chapter.uuid

	return {"story": story, "chapter": chapter, "scene": scene, "seq1": seq1}


# --- setup() avec autosave_enabled ---

func test_setup_accepts_autosave_enabled_true() -> void:
	_ctrl.setup(null, true)
	assert_true(_ctrl._autosave_enabled)


func test_setup_accepts_autosave_enabled_false() -> void:
	_ctrl.setup(null, false)
	assert_false(_ctrl._autosave_enabled)


func test_setup_default_autosave_enabled_is_true() -> void:
	_ctrl.setup(null)
	assert_true(_ctrl._autosave_enabled)


# --- Signal autosave_triggered ---

func test_autosave_triggered_signal_exists() -> void:
	assert_true(_ctrl.has_signal("autosave_triggered"))


func test_autosave_triggered_emitted_on_waiting_for_choice() -> void:
	_ctrl.setup(null, true)
	watch_signals(_ctrl)
	var data := _build_simple_story_with_choices()
	var story = data["story"]

	_ctrl.start_play_story(story)
	_ctrl.on_sequence_finished()
	assert_signal_emitted(_ctrl, "autosave_triggered")


func test_autosave_triggered_not_emitted_when_disabled() -> void:
	_ctrl.setup(null, false)
	watch_signals(_ctrl)
	var data := _build_simple_story_with_choices()
	var story = data["story"]

	_ctrl.start_play_story(story)
	_ctrl.on_sequence_finished()
	assert_signal_not_emitted(_ctrl, "autosave_triggered")


func test_autosave_triggered_emitted_on_chapter_entered() -> void:
	_ctrl.setup(null, true)
	watch_signals(_ctrl)
	var data := _build_simple_story_with_choices()
	var story = data["story"]

	_ctrl.start_play_story(story)
	assert_signal_emitted(_ctrl, "autosave_triggered")


func test_autosave_triggered_emitted_on_scene_entered() -> void:
	_ctrl.setup(null, true)
	watch_signals(_ctrl)
	var data := _build_simple_story_with_choices()
	var story = data["story"]
	var chapter = data["chapter"]
	var scene = data["scene"]

	_ctrl.start_play_scene(story, chapter, scene)
	assert_signal_emitted(_ctrl, "autosave_triggered")


func test_autosave_triggered_not_emitted_on_chapter_when_disabled() -> void:
	_ctrl.setup(null, false)
	watch_signals(_ctrl)
	var data := _build_simple_story_with_choices()
	var story = data["story"]

	_ctrl.start_play_story(story)
	assert_signal_not_emitted(_ctrl, "autosave_triggered")


func test_autosave_triggered_not_emitted_on_scene_when_disabled() -> void:
	_ctrl.setup(null, false)
	watch_signals(_ctrl)
	var data := _build_simple_story_with_choices()
	var story = data["story"]
	var chapter = data["chapter"]
	var scene = data["scene"]

	_ctrl.start_play_scene(story, chapter, scene)
	assert_signal_not_emitted(_ctrl, "autosave_triggered")


# --- notification_triggered avec "Auto-save..." ---

func test_notification_triggered_with_autosave_message_on_choice() -> void:
	_ctrl.setup(null, true)
	watch_signals(_ctrl)
	var data := _build_simple_story_with_choices()
	var story = data["story"]

	_ctrl.start_play_story(story)
	_ctrl.on_sequence_finished()
	assert_signal_emitted(_ctrl, "notification_triggered")
	var params = get_signal_parameters(_ctrl, "notification_triggered", 0)
	assert_eq(params[0], "Auto-save...")


func test_notification_not_emitted_when_autosave_disabled_on_choice() -> void:
	_ctrl.setup(null, false)
	watch_signals(_ctrl)
	var data := _build_simple_story_with_choices()
	var story = data["story"]

	_ctrl.start_play_story(story)
	_ctrl.on_sequence_finished()
	assert_signal_not_emitted(_ctrl, "autosave_triggered")
