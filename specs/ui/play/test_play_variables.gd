extends GutTest

const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const EndingScript = preload("res://src/models/ending.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")

var _controller: Node

func before_each():
	_controller = StoryPlayControllerScript.new()
	add_child(_controller)

func after_each():
	_controller.queue_free()

# --- Initialisation des variables ---

func test_variables_initialized_from_story_definitions():
	var story = _make_story_with_variables({"score": "0", "hp": "100"})
	_controller.start_play_story(story)
	assert_eq(_controller.get_variable("score"), "0")
	assert_eq(_controller.get_variable("hp"), "100")

func test_variables_empty_when_no_definitions():
	var story = _make_simple_story()
	_controller.start_play_story(story)
	assert_null(_controller.get_variable("nonexistent"))

func test_start_play_chapter_initializes_variables():
	var story = _make_story_with_variables({"level": "1"})
	var chapter = story.chapters[0]
	_controller.start_play_chapter(story, chapter)
	assert_eq(_controller.get_variable("level"), "1")

# --- Effets sur auto_redirect ---

func test_auto_redirect_applies_consequence_effects():
	var story = _make_simple_story()
	var scene = story.chapters[0].scenes[0]
	var seq1 = scene.sequences[0]
	var seq2 = _make_sequence("seq2", "Destination")
	scene.sequences.append(seq2)

	# seq1 ending = auto_redirect vers seq2 avec effet
	seq1.ending = EndingScript.new()
	seq1.ending.type = "auto_redirect"
	seq1.ending.auto_consequence = ConsequenceScript.new()
	seq1.ending.auto_consequence.type = "redirect_sequence"
	seq1.ending.auto_consequence.target = seq2.uuid
	var effect = VariableEffectScript.new()
	effect.variable = "visited"
	effect.operation = "set"
	effect.value = "true"
	seq1.ending.auto_consequence.effects.append(effect)

	_controller.start_play_story(story)
	# La séquence 1 est en cours
	_controller.on_sequence_finished()
	# L'effet devrait avoir été appliqué
	assert_eq(_controller.get_variable("visited"), "true")

# --- Effets sur choix ---

func test_choice_applies_choice_effects_then_consequence_effects():
	var story = _make_simple_story()
	var scene = story.chapters[0].scenes[0]
	var seq1 = scene.sequences[0]
	var seq2 = _make_sequence("seq2", "Destination")
	scene.sequences.append(seq2)

	# seq1 ending = choices
	seq1.ending = EndingScript.new()
	seq1.ending.type = "choices"
	var choice = ChoiceScript.new()
	choice.text = "Go"
	choice.consequence = ConsequenceScript.new()
	choice.consequence.type = "redirect_sequence"
	choice.consequence.target = seq2.uuid

	# Effet sur le choix
	var choice_effect = VariableEffectScript.new()
	choice_effect.variable = "choice_made"
	choice_effect.operation = "set"
	choice_effect.value = "go"
	choice.effects.append(choice_effect)

	# Effet sur la conséquence
	var cons_effect = VariableEffectScript.new()
	cons_effect.variable = "transitions"
	cons_effect.operation = "increment"
	cons_effect.value = "1"
	choice.consequence.effects.append(cons_effect)

	seq1.ending.choices.append(choice)

	_controller.start_play_story(story)
	_controller.on_sequence_finished()
	_controller.on_choice_selected(0)

	assert_eq(_controller.get_variable("choice_made"), "go")
	assert_eq(_controller.get_variable("transitions"), "1.0")

func test_choice_effects_applied_before_consequence_effects():
	var story = _make_story_with_variables({"counter": "0"})
	var scene = story.chapters[0].scenes[0]
	var seq1 = scene.sequences[0]
	var seq2 = _make_sequence("seq2", "Dest")
	scene.sequences.append(seq2)

	seq1.ending = EndingScript.new()
	seq1.ending.type = "choices"
	var choice = ChoiceScript.new()
	choice.text = "Act"
	choice.consequence = ConsequenceScript.new()
	choice.consequence.type = "redirect_sequence"
	choice.consequence.target = seq2.uuid

	# Choix: set counter = 10
	var e1 = VariableEffectScript.new()
	e1.variable = "counter"
	e1.operation = "set"
	e1.value = "10"
	choice.effects.append(e1)

	# Conséquence: increment counter + 5 → 15
	var e2 = VariableEffectScript.new()
	e2.variable = "counter"
	e2.operation = "increment"
	e2.value = "5"
	choice.consequence.effects.append(e2)

	seq1.ending.choices.append(choice)

	_controller.start_play_story(story)
	_controller.on_sequence_finished()
	_controller.on_choice_selected(0)

	assert_eq(_controller.get_variable("counter"), "15.0", "Choice effects avant consequence effects")

# --- Effets avec conditions ---

func test_variables_work_with_conditions():
	var story = _make_story_with_variables({"score": "50"})
	_controller.start_play_story(story)
	assert_eq(_controller.get_variable("score"), "50")

# --- Helpers ---

func _make_simple_story():
	var story = StoryScript.new()
	story.title = "Test"
	var chapter = ChapterScript.new()
	chapter.uuid = "ch1"
	var scene = SceneDataScript.new()
	scene.uuid = "sc1"
	var seq = _make_sequence("seq1", "Start")
	scene.sequences.append(seq)
	scene.entry_point_uuid = seq.uuid
	chapter.scenes.append(scene)
	chapter.entry_point_uuid = scene.uuid
	story.chapters.append(chapter)
	story.entry_point_uuid = chapter.uuid
	return story

func _make_story_with_variables(vars: Dictionary):
	var story = _make_simple_story()
	for key in vars:
		var v = VariableDefinitionScript.new()
		v.var_name = key
		v.initial_value = vars[key]
		story.variables.append(v)
	return story

func _make_sequence(id: String, name: String):
	var seq = SequenceScript.new()
	seq.uuid = id
	seq.seq_name = name
	return seq
