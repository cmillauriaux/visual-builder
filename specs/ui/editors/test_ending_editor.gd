extends GutTest

# Tests pour l'éditeur de terminaison (UI + API)

const EndingEditorScene = preload("res://src/ui/editors/ending_editor.tscn")
const Sequence = preload("res://src/models/sequence.gd")
const Ending = preload("res://src/models/ending.gd")
const Consequence = preload("res://src/models/consequence.gd")
const SequenceGraphView = preload("res://src/views/sequence_graph_view.gd")
const SceneGraphView = preload("res://src/views/scene_graph_view.gd")
const ChapterGraphView = preload("res://src/views/chapter_graph_view.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const StoryScript = preload("res://src/models/story.gd")

var _editor = null
var _sequence = null

func before_each():
	_editor = EndingEditorScene.instantiate()
	add_child(_editor)
	_sequence = Sequence.new()

func after_each():
	if _editor:
		_editor.queue_free()
		_editor = null

# === API Tests (backward compat) ===

func test_load_sequence_without_ending():
	_editor.load_sequence(_sequence)
	assert_eq(_editor.get_ending_type(), "")

func test_set_choices_mode():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	assert_not_null(_sequence.ending)
	assert_eq(_sequence.ending.type, "choices")

func test_set_auto_redirect_mode():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("auto_redirect")
	assert_not_null(_sequence.ending)
	assert_eq(_sequence.ending.type, "auto_redirect")

func test_add_choice():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("Explorer", "redirect_sequence", "seq-002")
	assert_eq(_sequence.ending.choices.size(), 1)
	assert_eq(_sequence.ending.choices[0].text, "Explorer")
	assert_eq(_sequence.ending.choices[0].consequence.type, "redirect_sequence")
	assert_eq(_sequence.ending.choices[0].consequence.target, "seq-002")

func test_max_8_choices():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	for i in range(8):
		_editor.add_choice("Choix %d" % i, "game_over", "")
	assert_eq(_sequence.ending.choices.size(), 8)
	# Le 9e ne doit pas être ajouté
	_editor.add_choice("Choix 9", "game_over", "")
	assert_eq(_sequence.ending.choices.size(), 8)

func test_remove_choice():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("A", "game_over", "")
	_editor.add_choice("B", "game_over", "")
	_editor.remove_choice(0)
	assert_eq(_sequence.ending.choices.size(), 1)
	assert_eq(_sequence.ending.choices[0].text, "B")

func test_set_auto_consequence():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("auto_redirect")
	_editor.set_auto_consequence("to_be_continued", "")
	assert_eq(_sequence.ending.auto_consequence.type, "to_be_continued")

func test_conditions_present_on_choices():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("Test", "game_over", "")
	assert_true(_sequence.ending.choices[0].conditions is Dictionary)
	assert_eq(_sequence.ending.choices[0].conditions, {})

func test_all_consequence_types():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	var types = ["redirect_sequence", "redirect_scene", "redirect_chapter", "game_over", "to_be_continued"]
	for t in types:
		_editor.add_choice(t, t, "target-uuid" if t.begins_with("redirect") else "")
	assert_eq(_sequence.ending.choices.size(), 5)

func test_switch_mode_resets():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("Test", "game_over", "")
	_editor.set_ending_type("auto_redirect")
	assert_eq(_sequence.ending.type, "auto_redirect")
	assert_eq(_sequence.ending.choices.size(), 0)

# === Signal tests ===

func test_ending_changed_signal_exists():
	assert_has_signal(_editor, "ending_changed")

func test_ending_changed_emitted_on_mode_none():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("auto_redirect")
	watch_signals(_editor)
	_editor._on_mode_none()
	assert_signal_emitted(_editor, "ending_changed")

func test_ending_changed_emitted_on_mode_redirect():
	_editor.load_sequence(_sequence)
	watch_signals(_editor)
	_editor._on_mode_redirect()
	assert_signal_emitted(_editor, "ending_changed")

func test_ending_changed_emitted_on_mode_choices():
	_editor.load_sequence(_sequence)
	watch_signals(_editor)
	_editor._on_mode_choices()
	assert_signal_emitted(_editor, "ending_changed")

# === Available targets tests ===

func test_set_available_targets():
	var sequences = [{"uuid": "s1", "name": "Seq 1"}, {"uuid": "s2", "name": "Seq 2"}]
	var scenes = [{"uuid": "sc1", "name": "Scene 1"}]
	var chapters = [{"uuid": "ch1", "name": "Chap 1"}]
	_editor.set_available_targets(sequences, scenes, chapters)
	assert_eq(_editor.get_available_sequences().size(), 2)
	assert_eq(_editor.get_available_scenes().size(), 1)
	assert_eq(_editor.get_available_chapters().size(), 1)

func test_get_targets_for_type():
	var sequences = [{"uuid": "s1", "name": "Seq 1"}]
	var scenes = [{"uuid": "sc1", "name": "Scene 1"}]
	var chapters = [{"uuid": "ch1", "name": "Chap 1"}]
	_editor.set_available_targets(sequences, scenes, chapters)
	assert_eq(_editor._get_targets_for_type("redirect_sequence").size(), 1)
	assert_eq(_editor._get_targets_for_type("redirect_scene").size(), 1)
	assert_eq(_editor._get_targets_for_type("redirect_chapter").size(), 1)
	assert_eq(_editor._get_targets_for_type("game_over").size(), 0)
	assert_eq(_editor._get_targets_for_type("to_be_continued").size(), 0)

# === UI refresh tests ===

func test_refresh_ui_no_ending():
	_editor.load_sequence(_sequence)
	assert_true(_editor._mode_none_btn.button_pressed)
	assert_false(_editor._redirect_container.visible)
	assert_false(_editor._choices_container.visible)

func test_refresh_ui_auto_redirect():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("auto_redirect")
	_editor.set_auto_consequence("redirect_sequence", "s1")
	_editor.set_available_targets([{"uuid": "s1", "name": "Seq 1"}], [], [])
	_editor.load_sequence(_sequence)
	assert_true(_editor._mode_redirect_btn.button_pressed)
	assert_true(_editor._redirect_container.visible)
	assert_false(_editor._choices_container.visible)

func test_refresh_ui_choices():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("choices")
	_editor.add_choice("A", "game_over", "")
	_editor.load_sequence(_sequence)
	assert_true(_editor._mode_choices_btn.button_pressed)
	assert_false(_editor._redirect_container.visible)
	assert_true(_editor._choices_container.visible)

func test_mode_none_clears_ending():
	_editor.load_sequence(_sequence)
	_editor.set_ending_type("auto_redirect")
	_editor._on_mode_none()
	assert_null(_sequence.ending)

# === "Nouveau..." signal tests ===

func test_new_target_requested_signal_exists():
	assert_has_signal(_editor, "new_target_requested")

func test_redirect_nouveau_emits_new_target_requested():
	_editor.load_sequence(_sequence)
	_editor.set_available_targets(
		[{"uuid": "s1", "name": "Seq 1"}],
		[], []
	)
	_editor._on_mode_redirect()
	watch_signals(_editor)
	# Select index 0 which is "Nouveau..."
	_editor._on_redirect_target_changed(0)
	assert_signal_emitted(_editor, "new_target_requested")

func test_redirect_nouveau_callback_updates_model():
	_editor.load_sequence(_sequence)
	_editor.set_available_targets(
		[{"uuid": "s1", "name": "Seq 1"}],
		[], []
	)
	_editor._on_mode_redirect()
	# Use an array to capture by reference
	var received = [{"ctype": ""}]
	_editor.new_target_requested.connect(func(ctype, callback):
		received[0]["ctype"] = ctype
		_editor.set_available_targets(
			[{"uuid": "s1", "name": "Seq 1"}, {"uuid": "new-uuid", "name": "Séquence 2"}],
			[], []
		)
		callback.call("new-uuid")
	)
	_editor._on_redirect_target_changed(0)
	assert_eq(received[0]["ctype"], "redirect_sequence")
	assert_eq(_sequence.ending.auto_consequence.target, "new-uuid")

# === Graph view ending connection tests ===

func test_sequence_graph_ending_connections():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new()
	seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new()
	seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)

	# Add an auto_redirect ending from seq1 to seq2
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = "redirect_sequence"
	cons.target = seq2.uuid
	ending.auto_consequence = cons
	seq1.ending = ending

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	# The graph should have a connection from seq1 to seq2
	var connections = graph.get_connection_list()
	var found = false
	for conn in connections:
		if conn["from_node"] == StringName(seq1.uuid) and conn["to_node"] == StringName(seq2.uuid):
			found = true
			break
	assert_true(found, "Ending connection from seq1 to seq2 should exist")

func test_sequence_graph_ending_choices_connections():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new()
	seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new()
	seq2.seq_name = "Seq 2"
	var seq3 = Sequence.new()
	seq3.seq_name = "Seq 3"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)
	scene.sequences.append(seq3)

	# Add choices ending from seq1 pointing to seq2 and seq3
	var ending = Ending.new()
	ending.type = "choices"
	var choice1_cons = Consequence.new()
	choice1_cons.type = "redirect_sequence"
	choice1_cons.target = seq2.uuid
	var choice1 = load("res://src/models/choice.gd").new()
	choice1.text = "Go to 2"
	choice1.consequence = choice1_cons
	ending.choices.append(choice1)

	var choice2_cons = Consequence.new()
	choice2_cons.type = "redirect_sequence"
	choice2_cons.target = seq3.uuid
	var choice2 = load("res://src/models/choice.gd").new()
	choice2.text = "Go to 3"
	choice2.consequence = choice2_cons
	ending.choices.append(choice2)
	seq1.ending = ending

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	var connections = graph.get_connection_list()
	var found_seq2 = false
	var found_seq3 = false
	for conn in connections:
		if conn["from_node"] == StringName(seq1.uuid) and conn["to_node"] == StringName(seq2.uuid):
			found_seq2 = true
		if conn["from_node"] == StringName(seq1.uuid) and conn["to_node"] == StringName(seq3.uuid):
			found_seq3 = true
	assert_true(found_seq2, "Ending choice connection to seq2 should exist")
	assert_true(found_seq3, "Ending choice connection to seq3 should exist")

func test_ending_connections_no_duplicates():
	var scene = SceneDataScript.new()
	var seq1 = Sequence.new()
	seq1.seq_name = "Seq 1"
	var seq2 = Sequence.new()
	seq2.seq_name = "Seq 2"
	scene.sequences.append(seq1)
	scene.sequences.append(seq2)

	# Add manual connection
	scene.connections.append({"from": seq1.uuid, "to": seq2.uuid})

	# Also add ending that would create the same connection
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = "redirect_sequence"
	cons.target = seq2.uuid
	ending.auto_consequence = cons
	seq1.ending = ending

	var graph = GraphEdit.new()
	graph.set_script(SequenceGraphView)
	add_child_autofree(graph)
	graph.load_scene(scene)

	# Count connections from seq1 to seq2 — should be exactly 1
	var connections = graph.get_connection_list()
	var count = 0
	for conn in connections:
		if conn["from_node"] == StringName(seq1.uuid) and conn["to_node"] == StringName(seq2.uuid):
			count += 1
	assert_eq(count, 1, "Should not duplicate existing manual connection")

func test_scene_graph_ending_connections():
	var chapter = ChapterScript.new()
	var scene1 = SceneDataScript.new()
	scene1.scene_name = "Scene 1"
	var scene2 = SceneDataScript.new()
	scene2.scene_name = "Scene 2"
	chapter.scenes.append(scene1)
	chapter.scenes.append(scene2)

	# Add a sequence in scene1 with redirect_scene to scene2
	var seq = Sequence.new()
	seq.seq_name = "Seq in Scene 1"
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = "redirect_scene"
	cons.target = scene2.uuid
	ending.auto_consequence = cons
	seq.ending = ending
	scene1.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(SceneGraphView)
	add_child_autofree(graph)
	graph.load_chapter(chapter)

	var connections = graph.get_connection_list()
	var found = false
	for conn in connections:
		if conn["from_node"] == StringName(scene1.uuid) and conn["to_node"] == StringName(scene2.uuid):
			found = true
			break
	assert_true(found, "Scene ending connection should exist")

func test_chapter_graph_ending_connections():
	var story = StoryScript.new()
	var ch1 = ChapterScript.new()
	ch1.chapter_name = "Chapter 1"
	var ch2 = ChapterScript.new()
	ch2.chapter_name = "Chapter 2"
	story.chapters.append(ch1)
	story.chapters.append(ch2)

	# Add scene with sequence that has redirect_chapter
	var scene = SceneDataScript.new()
	scene.scene_name = "Scene 1"
	ch1.scenes.append(scene)

	var seq = Sequence.new()
	seq.seq_name = "Seq 1"
	var ending = Ending.new()
	ending.type = "auto_redirect"
	var cons = Consequence.new()
	cons.type = "redirect_chapter"
	cons.target = ch2.uuid
	ending.auto_consequence = cons
	seq.ending = ending
	scene.sequences.append(seq)

	var graph = GraphEdit.new()
	graph.set_script(ChapterGraphView)
	add_child_autofree(graph)
	graph.load_story(story)

	var connections = graph.get_connection_list()
	var found = false
	for conn in connections:
		if conn["from_node"] == StringName(ch1.uuid) and conn["to_node"] == StringName(ch2.uuid):
			found = true
			break
	assert_true(found, "Chapter ending connection should exist")
