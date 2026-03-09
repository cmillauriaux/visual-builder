extends GutTest

# Tests pour les signaux analytics du StoryPlayController

var StoryPlayController = load("res://src/ui/play/story_play_controller.gd")
var StoryScript = load("res://src/models/story.gd")
var ChapterScript = load("res://src/models/chapter.gd")
var SceneDataScript = load("res://src/models/scene_data.gd")
var SequenceScript = load("res://src/models/sequence.gd")
var EndingScript = load("res://src/models/ending.gd")
var ConsequenceScript = load("res://src/models/consequence.gd")
var ChoiceScript = load("res://src/models/choice.gd")
var DialogueScript = load("res://src/models/dialogue.gd")

var _ctrl: Node = null


func before_each():
	_ctrl = Node.new()
	_ctrl.set_script(StoryPlayController)
	add_child_autofree(_ctrl)


# === Helpers ===

func _make_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Test Story"
	return story

func _make_chapter(ch_name: String) -> RefCounted:
	var ch = ChapterScript.new()
	ch.chapter_name = ch_name
	ch.position = Vector2(100, 100)
	return ch

func _make_scene(sc_name: String) -> RefCounted:
	var sc = SceneDataScript.new()
	sc.scene_name = sc_name
	sc.position = Vector2(100, 100)
	return sc

func _make_sequence(name: String) -> RefCounted:
	var seq = SequenceScript.new()
	seq.seq_name = name
	seq.position = Vector2(100, 100)
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	return seq

func _build_simple_story():
	var story = _make_story()
	var ch = _make_chapter("Chapitre 1")
	var sc = _make_scene("Scène 1")
	var seq = _make_sequence("Séquence 1")
	sc.sequences.append(seq)
	sc.entry_point_uuid = seq.uuid
	ch.scenes.append(sc)
	ch.entry_point_uuid = sc.uuid
	story.chapters.append(ch)
	story.entry_point_uuid = ch.uuid
	return {"story": story, "chapter": ch, "scene": sc, "sequence": seq}


# === Signal existence tests ===

func test_has_chapter_entered_signal():
	assert_has_signal(_ctrl, "chapter_entered")

func test_has_scene_entered_signal():
	assert_has_signal(_ctrl, "scene_entered")

func test_has_sequence_entered_signal():
	assert_has_signal(_ctrl, "sequence_entered")

func test_has_choice_made_signal():
	assert_has_signal(_ctrl, "choice_made")

func test_has_story_finished_with_reason_signal():
	assert_has_signal(_ctrl, "story_finished_with_reason")


# === Signal emission tests ===

func test_start_play_story_emits_chapter_entered():
	var data = _build_simple_story()
	watch_signals(_ctrl)
	_ctrl.start_play_story(data["story"])
	assert_signal_emitted(_ctrl, "chapter_entered")
	var params = get_signal_parameters(_ctrl, "chapter_entered")
	assert_eq(params[0], "Chapitre 1")


func test_start_play_story_emits_scene_entered():
	var data = _build_simple_story()
	watch_signals(_ctrl)
	_ctrl.start_play_story(data["story"])
	assert_signal_emitted(_ctrl, "scene_entered")
	var params = get_signal_parameters(_ctrl, "scene_entered")
	assert_eq(params[0], "Scène 1")


func test_start_play_story_emits_sequence_entered():
	var data = _build_simple_story()
	watch_signals(_ctrl)
	_ctrl.start_play_story(data["story"])
	assert_signal_emitted(_ctrl, "sequence_entered")
	var params = get_signal_parameters(_ctrl, "sequence_entered")
	assert_eq(params[0], "Séquence 1")


func test_choice_made_signal_emitted():
	var data = _build_simple_story()
	var seq = data["sequence"]

	# Ajouter un ending avec choix
	var ending = EndingScript.new()
	ending.type = "choices"
	var choice = ChoiceScript.new()
	choice.text = "Aller à gauche"
	var cons = ConsequenceScript.new()
	cons.type = "game_over"
	choice.consequence = cons
	ending.choices.append(choice)
	seq.ending = ending

	_ctrl.start_play_story(data["story"])
	_ctrl.on_sequence_finished()
	watch_signals(_ctrl)
	_ctrl.on_choice_selected(0)
	assert_signal_emitted(_ctrl, "choice_made")
	var params = get_signal_parameters(_ctrl, "choice_made")
	assert_eq(params[0], seq.uuid)
	assert_eq(params[1], 0)
	assert_eq(params[2], "Aller à gauche")


func test_story_finished_with_reason_game_over():
	var data = _build_simple_story()
	var seq = data["sequence"]

	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = "game_over"
	ending.auto_consequence = cons
	seq.ending = ending

	_ctrl.start_play_story(data["story"])
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_signal_emitted(_ctrl, "story_finished_with_reason")
	var params = get_signal_parameters(_ctrl, "story_finished_with_reason")
	assert_eq(params[0], "game_over")


func test_story_finished_with_reason_to_be_continued():
	var data = _build_simple_story()
	var seq = data["sequence"]

	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = "to_be_continued"
	ending.auto_consequence = cons
	seq.ending = ending

	_ctrl.start_play_story(data["story"])
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_signal_emitted(_ctrl, "story_finished_with_reason")
	var params = get_signal_parameters(_ctrl, "story_finished_with_reason")
	assert_eq(params[0], "to_be_continued")


func test_story_finished_with_reason_not_emitted_for_error():
	var data = _build_simple_story()
	var seq = data["sequence"]
	seq.ending = null  # Pas d'ending → error

	_ctrl.start_play_story(data["story"])
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_signal_not_emitted(_ctrl, "story_finished_with_reason")


# === start_play_from_save analytics signals ===

func test_start_play_from_save_emits_chapter_entered():
	var data = _build_simple_story()
	watch_signals(_ctrl)
	_ctrl.start_play_from_save(data["story"], data["chapter"], data["scene"], data["sequence"], {})
	assert_signal_emitted(_ctrl, "chapter_entered")
	var params = get_signal_parameters(_ctrl, "chapter_entered")
	assert_eq(params[0], "Chapitre 1")

func test_start_play_from_save_emits_scene_entered():
	var data = _build_simple_story()
	watch_signals(_ctrl)
	_ctrl.start_play_from_save(data["story"], data["chapter"], data["scene"], data["sequence"], {})
	assert_signal_emitted(_ctrl, "scene_entered")
	var params = get_signal_parameters(_ctrl, "scene_entered")
	assert_eq(params[0], "Scène 1")

func test_start_play_from_save_emits_sequence_entered():
	var data = _build_simple_story()
	watch_signals(_ctrl)
	_ctrl.start_play_from_save(data["story"], data["chapter"], data["scene"], data["sequence"], {})
	assert_signal_emitted(_ctrl, "sequence_entered")
	var params = get_signal_parameters(_ctrl, "sequence_entered")
	assert_eq(params[0], "Séquence 1")
