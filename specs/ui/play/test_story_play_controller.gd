extends GutTest

# Tests pour le StoryPlayController — play multi-niveaux

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

# === Helper functions ===

func _make_story() -> RefCounted:
	var story = StoryScript.new()
	story.title = "Test Story"
	return story

func _make_chapter(ch_name: String, pos: Vector2 = Vector2(100, 100)) -> RefCounted:
	var ch = ChapterScript.new()
	ch.chapter_name = ch_name
	ch.position = pos
	return ch

func _make_scene(sc_name: String, pos: Vector2 = Vector2(100, 100)) -> RefCounted:
	var sc = SceneDataScript.new()
	sc.scene_name = sc_name
	sc.position = pos
	return sc

func _make_sequence(name: String, pos: Vector2 = Vector2(100, 100)) -> RefCounted:
	var seq = SequenceScript.new()
	seq.seq_name = name
	seq.position = pos
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	seq.dialogues.append(dlg)
	return seq

func _make_sequence_empty(name: String, pos: Vector2 = Vector2(100, 100)) -> RefCounted:
	var seq = SequenceScript.new()
	seq.seq_name = name
	seq.position = pos
	return seq

func _make_ending_auto(type: String, target: String) -> RefCounted:
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = type
	cons.target = target
	ending.auto_consequence = cons
	return ending

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

func _build_simple_story() -> RefCounted:
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq = _make_sequence("Seq1")
	sc.sequences.append(seq)
	return story

# === State tests ===

func test_initial_state_is_idle():
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)

func test_is_playing_false_initially():
	assert_false(_ctrl.is_playing())

# === Signals exist ===

func test_signals_exist():
	assert_has_signal(_ctrl, "sequence_play_requested")
	assert_has_signal(_ctrl, "choice_display_requested")
	assert_has_signal(_ctrl, "play_finished")

# === Start play story ===

func test_start_play_story():
	var story = _build_simple_story()
	watch_signals(_ctrl)
	_ctrl.start_play_story(story)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_true(_ctrl.is_playing())
	assert_signal_emitted(_ctrl, "sequence_play_requested")

func test_start_play_story_null():
	watch_signals(_ctrl)
	_ctrl.start_play_story(null)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_not_emitted(_ctrl, "sequence_play_requested")

func test_start_play_story_no_chapters():
	var story = _make_story()
	watch_signals(_ctrl)
	_ctrl.start_play_story(story)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_start_play_story_empty_chapter():
	var story = _make_story()
	var ch = _make_chapter("Empty")
	story.chapters.append(ch)
	watch_signals(_ctrl)
	_ctrl.start_play_story(story)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_start_play_story_empty_scene():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	watch_signals(_ctrl)
	_ctrl.start_play_story(story)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Start play chapter ===

func test_start_play_chapter():
	var story = _build_simple_story()
	var ch = story.chapters[0]
	watch_signals(_ctrl)
	_ctrl.start_play_chapter(story, ch)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_signal_emitted(_ctrl, "sequence_play_requested")

func test_start_play_chapter_empty_scenes():
	var story = _make_story()
	var ch = _make_chapter("Empty")
	story.chapters.append(ch)
	watch_signals(_ctrl)
	_ctrl.start_play_chapter(story, ch)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_start_play_chapter_empty_sequences():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	watch_signals(_ctrl)
	_ctrl.start_play_chapter(story, ch)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_start_play_chapter_null():
	watch_signals(_ctrl)
	_ctrl.start_play_chapter(null, null)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_not_emitted(_ctrl, "sequence_play_requested")

# === Start play scene ===

func test_start_play_scene():
	var story = _build_simple_story()
	var ch = story.chapters[0]
	var sc = ch.scenes[0]
	watch_signals(_ctrl)
	_ctrl.start_play_scene(story, ch, sc)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_signal_emitted(_ctrl, "sequence_play_requested")

func test_start_play_scene_empty_sequences():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	watch_signals(_ctrl)
	_ctrl.start_play_scene(story, ch, sc)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_start_play_scene_null():
	watch_signals(_ctrl)
	_ctrl.start_play_scene(null, null, null)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_not_emitted(_ctrl, "sequence_play_requested")

# === First element selection (by position) ===

func test_first_element_by_position_x():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq_right = _make_sequence("Right", Vector2(500, 100))
	var seq_left = _make_sequence("Left", Vector2(100, 100))
	sc.sequences.append(seq_right)
	sc.sequences.append(seq_left)
	watch_signals(_ctrl)
	_ctrl.start_play_scene(story, ch, sc)
	assert_eq(_ctrl.get_current_sequence(), seq_left)

func test_first_element_by_position_y_tiebreak():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq_bottom = _make_sequence("Bottom", Vector2(100, 500))
	var seq_top = _make_sequence("Top", Vector2(100, 100))
	sc.sequences.append(seq_bottom)
	sc.sequences.append(seq_top)
	watch_signals(_ctrl)
	_ctrl.start_play_scene(story, ch, sc)
	assert_eq(_ctrl.get_current_sequence(), seq_top)

func test_first_chapter_by_position():
	var story = _make_story()
	var ch_right = _make_chapter("Right", Vector2(500, 100))
	var ch_left = _make_chapter("Left", Vector2(100, 100))
	story.chapters.append(ch_right)
	story.chapters.append(ch_left)
	var sc_r = _make_scene("Sc R")
	ch_right.scenes.append(sc_r)
	sc_r.sequences.append(_make_sequence("Seq R"))
	var sc_l = _make_scene("Sc L")
	ch_left.scenes.append(sc_l)
	sc_l.sequences.append(_make_sequence("Seq L"))
	watch_signals(_ctrl)
	_ctrl.start_play_story(story)
	assert_eq(_ctrl.get_current_chapter(), ch_left)

func test_first_scene_by_position():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc_right = _make_scene("Right", Vector2(500, 100))
	var sc_left = _make_scene("Left", Vector2(100, 100))
	ch.scenes.append(sc_right)
	ch.scenes.append(sc_left)
	sc_right.sequences.append(_make_sequence("Seq R"))
	sc_left.sequences.append(_make_sequence("Seq L"))
	watch_signals(_ctrl)
	_ctrl.start_play_story(story)
	assert_eq(_ctrl.get_current_scene(), sc_left)

# === Sequence finished — no ending ===

func test_sequence_finished_no_ending():
	var story = _build_simple_story()
	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Sequence finished — auto_redirect sequence ===

func test_redirect_sequence():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(100, 100))
	var seq2 = _make_sequence("Seq2", Vector2(400, 100))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_sequence", seq2.uuid)

	_ctrl.start_play_scene(story, ch, sc)
	assert_eq(_ctrl.get_current_sequence(), seq1)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_eq(_ctrl.get_current_sequence(), seq2)
	assert_signal_emitted(_ctrl, "sequence_play_requested")

# === Sequence finished — auto_redirect scene ===

func test_redirect_scene():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc1 = _make_scene("Sc1", Vector2(100, 100))
	var sc2 = _make_scene("Sc2", Vector2(400, 100))
	ch.scenes.append(sc1)
	ch.scenes.append(sc2)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var seq2 = _make_sequence("Seq2")
	sc2.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_scene", sc2.uuid)

	_ctrl.start_play_scene(story, ch, sc1)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_eq(_ctrl.get_current_scene(), sc2)
	assert_eq(_ctrl.get_current_sequence(), seq2)

# === Sequence finished — auto_redirect chapter ===

func test_redirect_chapter():
	var story = _make_story()
	var ch1 = _make_chapter("Ch1", Vector2(100, 100))
	var ch2 = _make_chapter("Ch2", Vector2(400, 100))
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	var sc1 = _make_scene("Sc1")
	ch1.scenes.append(sc1)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var sc2 = _make_scene("Sc2")
	ch2.scenes.append(sc2)
	var seq2 = _make_sequence("Seq2")
	sc2.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_chapter", ch2.uuid)

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_eq(_ctrl.get_current_chapter(), ch2)
	assert_eq(_ctrl.get_current_scene(), sc2)
	assert_eq(_ctrl.get_current_sequence(), seq2)

# === Sequence finished — game_over ===

func test_game_over():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	seq.ending = _make_ending_auto("game_over", "")

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Sequence finished — to_be_continued ===

func test_to_be_continued():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	seq.ending = _make_ending_auto("to_be_continued", "")

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Choices ===

func test_choices_waiting_state():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	var seq2 = _make_sequence("Seq2", Vector2(400, 100))
	story.chapters[0].scenes[0].sequences.append(seq2)
	seq.ending = _make_ending_choices([
		{"text": "Option A", "type": "redirect_sequence", "target": seq2.uuid},
		{"text": "Option B", "type": "game_over"},
	])

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.WAITING_FOR_CHOICE)
	assert_signal_emitted(_ctrl, "choice_display_requested")

func test_choice_selected_redirect():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	var seq2 = _make_sequence("Seq2", Vector2(400, 100))
	story.chapters[0].scenes[0].sequences.append(seq2)
	seq.ending = _make_ending_choices([
		{"text": "Go to Seq2", "type": "redirect_sequence", "target": seq2.uuid},
		{"text": "Game Over", "type": "game_over"},
	])

	_ctrl.start_play_story(story)
	_ctrl.on_sequence_finished()
	watch_signals(_ctrl)
	_ctrl.on_choice_selected(0)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_eq(_ctrl.get_current_sequence(), seq2)
	assert_signal_emitted(_ctrl, "sequence_play_requested")

func test_choice_selected_game_over():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	seq.ending = _make_ending_choices([
		{"text": "Game Over", "type": "game_over"},
		{"text": "Continue", "type": "to_be_continued"},
	])

	_ctrl.start_play_story(story)
	_ctrl.on_sequence_finished()
	watch_signals(_ctrl)
	_ctrl.on_choice_selected(0)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_choice_selected_invalid_index():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	seq.ending = _make_ending_choices([
		{"text": "Option A", "type": "game_over"},
	])

	_ctrl.start_play_story(story)
	_ctrl.on_sequence_finished()
	watch_signals(_ctrl)
	_ctrl.on_choice_selected(5)
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_choice_selected_not_in_waiting_state():
	var story = _build_simple_story()
	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_choice_selected(0)
	# Should not change state — still PLAYING_SEQUENCE
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)
	assert_signal_not_emitted(_ctrl, "play_finished")

# === Target not found ===

func test_redirect_sequence_target_not_found():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	seq.ending = _make_ending_auto("redirect_sequence", "nonexistent-uuid")

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_redirect_scene_target_not_found():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	seq.ending = _make_ending_auto("redirect_scene", "nonexistent-uuid")

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_redirect_chapter_target_not_found():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	seq.ending = _make_ending_auto("redirect_chapter", "nonexistent-uuid")

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Redirect to empty containers ===

func test_redirect_scene_empty_sequences():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc1 = _make_scene("Sc1", Vector2(100, 100))
	var sc2 = _make_scene("Sc2 (empty)", Vector2(400, 100))
	ch.scenes.append(sc1)
	ch.scenes.append(sc2)
	sc1.sequences.append(_make_sequence("Seq1"))
	# sc2 has no sequences
	sc1.sequences[0].ending = _make_ending_auto("redirect_scene", sc2.uuid)

	_ctrl.start_play_scene(story, ch, sc1)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

func test_redirect_chapter_empty_scenes():
	var story = _make_story()
	var ch1 = _make_chapter("Ch1", Vector2(100, 100))
	var ch2 = _make_chapter("Ch2 (empty)", Vector2(400, 100))
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	var sc = _make_scene("Sc1")
	ch1.scenes.append(sc)
	sc.sequences.append(_make_sequence("Seq1"))
	# ch2 has no scenes
	sc.sequences[0].ending = _make_ending_auto("redirect_chapter", ch2.uuid)

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Stop play ===

func test_stop_play():
	var story = _build_simple_story()
	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.stop_play()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_false(_ctrl.is_playing())
	assert_signal_emitted(_ctrl, "play_finished")

func test_stop_play_during_choice():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	seq.ending = _make_ending_choices([
		{"text": "Option", "type": "game_over"},
	])
	_ctrl.start_play_story(story)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.WAITING_FOR_CHOICE)
	watch_signals(_ctrl)
	_ctrl.stop_play()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === on_sequence_finished not in PLAYING_SEQUENCE ===

func test_on_sequence_finished_when_idle():
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_not_emitted(_ctrl, "play_finished")

# === Ending with empty choices array ===

func test_choices_ending_empty_array():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	var ending = EndingScript.new()
	ending.type = "choices"
	# No choices added
	seq.ending = ending

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Auto redirect with null consequence ===

func test_auto_redirect_null_consequence():
	var story = _build_simple_story()
	var seq = story.chapters[0].scenes[0].sequences[0]
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	ending.auto_consequence = null
	seq.ending = ending

	_ctrl.start_play_story(story)
	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Chain of redirections ===

func test_chain_redirect_seq1_to_seq2_to_seq3():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(100, 100))
	var seq2 = _make_sequence("Seq2", Vector2(400, 100))
	var seq3 = _make_sequence("Seq3", Vector2(700, 100))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.sequences.append(seq3)
	seq1.ending = _make_ending_auto("redirect_sequence", seq2.uuid)
	seq2.ending = _make_ending_auto("redirect_sequence", seq3.uuid)
	# seq3 has no ending

	_ctrl.start_play_scene(story, ch, sc)
	assert_eq(_ctrl.get_current_sequence(), seq1)

	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_current_sequence(), seq2)

	watch_signals(_ctrl)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_current_sequence(), seq3)

	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
	assert_signal_emitted(_ctrl, "play_finished")

# === Multi-level redirect chain ===

func test_redirect_scene_then_sequence():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc1 = _make_scene("Sc1", Vector2(100, 100))
	var sc2 = _make_scene("Sc2", Vector2(400, 100))
	ch.scenes.append(sc1)
	ch.scenes.append(sc2)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var seq2a = _make_sequence("Seq2a", Vector2(100, 100))
	var seq2b = _make_sequence("Seq2b", Vector2(400, 100))
	sc2.sequences.append(seq2a)
	sc2.sequences.append(seq2b)
	seq1.ending = _make_ending_auto("redirect_scene", sc2.uuid)
	seq2a.ending = _make_ending_auto("redirect_sequence", seq2b.uuid)

	_ctrl.start_play_scene(story, ch, sc1)
	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_current_scene(), sc2)
	assert_eq(_ctrl.get_current_sequence(), seq2a)

	_ctrl.on_sequence_finished()
	assert_eq(_ctrl.get_current_sequence(), seq2b)

# === start_play_from_save ===

func test_start_play_from_save_sets_state_playing():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	var sc = _make_scene("Sc1")
	var seq = _make_sequence("Seq1")
	_ctrl.start_play_from_save(story, ch, sc, seq, {})
	assert_eq(_ctrl.get_state(), StoryPlayController.State.PLAYING_SEQUENCE)

func test_start_play_from_save_emits_sequence_play_requested():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	var sc = _make_scene("Sc1")
	var seq = _make_sequence("Seq1")
	watch_signals(_ctrl)
	_ctrl.start_play_from_save(story, ch, sc, seq, {})
	assert_signal_emitted(_ctrl, "sequence_play_requested")

func test_start_play_from_save_sets_correct_sequence():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	var sc = _make_scene("Sc1")
	var seq = _make_sequence("SeqTarget")
	_ctrl.start_play_from_save(story, ch, sc, seq, {})
	assert_eq(_ctrl.get_current_sequence(), seq)

func test_start_play_from_save_restores_variables():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	var sc = _make_scene("Sc1")
	var seq = _make_sequence("Seq1")
	var vars := {"hero_trust": 7, "choice": "war"}
	_ctrl.start_play_from_save(story, ch, sc, seq, vars)
	assert_eq(_ctrl.get_variable("hero_trust"), 7)
	assert_eq(_ctrl.get_variable("choice"), "war")

func test_start_play_from_save_does_nothing_with_null_sequence():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	var sc = _make_scene("Sc1")
	_ctrl.start_play_from_save(story, ch, sc, null, {})
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)

func test_start_play_from_save_does_nothing_with_null_story():
	var ch = _make_chapter("Ch1")
	var sc = _make_scene("Sc1")
	var seq = _make_sequence("Seq1")
	_ctrl.start_play_from_save(null, ch, sc, seq, {})
	assert_eq(_ctrl.get_state(), StoryPlayController.State.IDLE)
