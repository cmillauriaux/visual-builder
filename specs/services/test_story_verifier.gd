extends GutTest

# Tests unitaires pour le verificateur d'histoire

const StoryVerifier = preload("res://src/services/story_verifier.gd")
const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const EndingScript = preload("res://src/models/ending.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")
const ChoiceScript = preload("res://src/models/choice.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const ConditionModelScript = preload("res://src/models/condition.gd")
const ConditionRuleScript = preload("res://src/models/condition_rule.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")
const VariableEffectScript = preload("res://src/models/variable_effect.gd")

var _verifier: RefCounted


func before_each():
	_verifier = StoryVerifier.new()


# === Helpers ===

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


# === Tests null/empty ===

func test_verify_null_story():
	var report = _verifier.verify(null)
	assert_false(report["success"])
	assert_eq(report["total_runs"], 0)

func test_verify_empty_story():
	var story = _make_story()
	var report = _verifier.verify(story)
	assert_false(report["success"])
	assert_eq(report["total_runs"], 0)


# === Single sequence tests ===

func test_verify_single_sequence_no_ending():
	var story = _build_simple_story()
	var report = _verifier.verify(story)
	assert_false(report["success"])
	assert_eq(report["runs"].size(), 1)
	assert_eq(report["runs"][0]["ending_reason"], "no_ending")
	assert_false(report["runs"][0]["is_valid"])

func test_verify_single_sequence_game_over():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["total_runs"], 1)
	assert_eq(report["runs"][0]["ending_reason"], "game_over")
	assert_true(report["runs"][0]["is_valid"])
	assert_eq(report["orphan_nodes"].size(), 0)

func test_verify_single_sequence_to_be_continued():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("to_be_continued", "")
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["runs"][0]["ending_reason"], "to_be_continued")

func test_verify_direct_game_over_ending():
	# ending.type = "game_over" directly (pas enveloppé dans auto_redirect)
	var story = _build_simple_story()
	var ending = EndingScript.new()
	ending.type = "game_over"
	story.chapters[0].scenes[0].sequences[0].ending = ending
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["runs"][0]["ending_reason"], "game_over")
	assert_true(report["runs"][0]["is_valid"])

func test_verify_direct_to_be_continued_ending():
	# ending.type = "to_be_continued" directement
	var story = _build_simple_story()
	var ending = EndingScript.new()
	ending.type = "to_be_continued"
	story.chapters[0].scenes[0].sequences[0].ending = ending
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["runs"][0]["ending_reason"], "to_be_continued")
	assert_true(report["runs"][0]["is_valid"])


# === Linear chain ===

func test_verify_linear_chain():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("Seq2", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_sequence", seq2.uuid)
	seq2.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["visited_nodes"], 2)
	assert_eq(report["orphan_nodes"].size(), 0)


# === Orphan detection ===

func test_verify_orphan_detection():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("OrphanSeq", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_false(report["success"])  # Orphan means not fully successful
	assert_eq(report["orphan_nodes"].size(), 1)
	assert_eq(report["orphan_nodes"][0]["name"], "OrphanSeq")
	assert_eq(report["orphan_nodes"][0]["type"], "sequence")
	assert_true(report["runs"][0]["is_valid"])  # Run itself is valid


# === Choices coverage ===

func test_verify_choices_coverage():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("SeqA", Vector2(200, 0))
	var seq3 = _make_sequence("SeqB", Vector2(200, 200))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.sequences.append(seq3)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_choices([
		{"text": "Go A", "type": "redirect_sequence", "target": seq2.uuid},
		{"text": "Go B", "type": "redirect_sequence", "target": seq3.uuid},
	])
	seq2.ending = _make_ending_auto("game_over", "")
	seq3.ending = _make_ending_auto("to_be_continued", "")
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["total_runs"], 2)
	assert_eq(report["visited_nodes"], 3)
	assert_eq(report["orphan_nodes"].size(), 0)

func test_verify_choices_different_each_run():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("SeqA", Vector2(200, 0))
	var seq3 = _make_sequence("SeqB", Vector2(200, 200))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.sequences.append(seq3)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_choices([
		{"text": "Go A", "type": "redirect_sequence", "target": seq2.uuid},
		{"text": "Go B", "type": "redirect_sequence", "target": seq3.uuid},
	])
	seq2.ending = _make_ending_auto("game_over", "")
	seq3.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	# Run 0 should take choice 0, Run 1 should take choice 1
	var run0_path = report["runs"][0]["path"]
	var run1_path = report["runs"][1]["path"]
	var run0_choice = _find_choice_step(run0_path)
	var run1_choice = _find_choice_step(run1_path)
	assert_eq(run0_choice["choice_index"], 0)
	assert_eq(run1_choice["choice_index"], 1)


# === Condition evaluation ===

func test_verify_condition_evaluation():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	# Condition en entry point
	var cond = ConditionModelScript.new()
	cond.condition_name = "CheckScore"
	cond.position = Vector2(0, 0)
	# Default consequence -> game_over
	var default_cons = ConsequenceScript.new()
	default_cons.type = "game_over"
	cond.default_consequence = default_cons
	sc.conditions.append(cond)
	sc.entry_point_uuid = cond.uuid
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["visited_nodes"], 1)
	assert_eq(report["runs"][0]["ending_reason"], "game_over")

func test_verify_condition_no_default_no_match():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var cond = ConditionModelScript.new()
	cond.condition_name = "NoMatch"
	cond.position = Vector2(0, 0)
	# Pas de default, pas de regles
	sc.conditions.append(cond)
	sc.entry_point_uuid = cond.uuid
	var report = _verifier.verify(story)
	assert_false(report["success"])
	assert_eq(report["runs"][0]["ending_reason"], "no_ending")


# === Variable effects ===

func test_verify_variable_effects():
	var story = _make_story()
	# Ajouter une variable
	var var_def = VariableDefinitionScript.new()
	var_def.var_name = "score"
	var_def.initial_value = "0"
	story.variables.append(var_def)
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	# Seq1 -> auto_redirect vers condition, avec effet increment score
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	sc.sequences.append(seq1)
	# Condition: si score > 0 -> to_be_continued, sinon game_over
	var cond = ConditionModelScript.new()
	cond.condition_name = "CheckScore"
	cond.position = Vector2(200, 0)
	var rule = ConditionRuleScript.new()
	rule.variable = "score"
	rule.operator = "greater_than"
	rule.value = "0"
	var rule_cons = ConsequenceScript.new()
	rule_cons.type = "to_be_continued"
	rule.consequence = rule_cons
	cond.rules.append(rule)
	var default_cons = ConsequenceScript.new()
	default_cons.type = "game_over"
	cond.default_consequence = default_cons
	sc.conditions.append(cond)
	sc.entry_point_uuid = seq1.uuid
	# Ending seq1: auto_redirect vers condition avec effet increment
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_condition"
	cons.target = cond.uuid
	var effect = VariableEffectScript.new()
	effect.variable = "score"
	effect.operation = "increment"
	effect.value = "10"
	cons.effects.append(effect)
	ending.auto_consequence = cons
	seq1.ending = ending
	var report = _verifier.verify(story)
	assert_true(report["success"])
	# Score incremente a 10, donc > 0, donc to_be_continued
	assert_eq(report["runs"][0]["ending_reason"], "to_be_continued")


# === Cross-scene/chapter redirects ===

func test_verify_cross_scene_redirect():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc1 = _make_scene("Sc1", Vector2(0, 0))
	var sc2 = _make_scene("Sc2", Vector2(200, 0))
	ch.scenes.append(sc1)
	ch.scenes.append(sc2)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var seq2 = _make_sequence("Seq2")
	sc2.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_scene", sc2.uuid)
	seq2.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["visited_nodes"], 2)

func test_verify_cross_chapter_redirect():
	var story = _make_story()
	var ch1 = _make_chapter("Ch1", Vector2(0, 0))
	var ch2 = _make_chapter("Ch2", Vector2(200, 0))
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	var sc1 = _make_scene("Sc1")
	ch1.scenes.append(sc1)
	var sc2 = _make_scene("Sc2")
	ch2.scenes.append(sc2)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var seq2 = _make_sequence("Seq2")
	sc2.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_chapter", ch2.uuid)
	seq2.ending = _make_ending_auto("to_be_continued", "")
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["visited_nodes"], 2)


# === Loop detection ===

func test_verify_loop_detection():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("Seq2", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_auto("redirect_sequence", seq2.uuid)
	seq2.ending = _make_ending_auto("redirect_sequence", seq1.uuid)
	var report = _verifier.verify(story)
	assert_false(report["success"])
	assert_eq(report["runs"][0]["ending_reason"], "loop_detected")

func test_verify_loop_with_variable_terminates():
	# Seq1 incremente counter, condition verifie si counter >= 3
	var story = _make_story()
	var var_def = VariableDefinitionScript.new()
	var_def.var_name = "counter"
	var_def.initial_value = "0"
	story.variables.append(var_def)
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	sc.sequences.append(seq1)
	sc.entry_point_uuid = seq1.uuid
	# Condition: counter >= 3 -> game_over, sinon redirect_sequence seq1
	var cond = ConditionModelScript.new()
	cond.condition_name = "CheckCounter"
	cond.position = Vector2(200, 0)
	var rule = ConditionRuleScript.new()
	rule.variable = "counter"
	rule.operator = "greater_than_equal"
	rule.value = "3"
	var rule_cons = ConsequenceScript.new()
	rule_cons.type = "game_over"
	rule.consequence = rule_cons
	cond.rules.append(rule)
	var default_cons = ConsequenceScript.new()
	default_cons.type = "redirect_sequence"
	default_cons.target = seq1.uuid
	cond.default_consequence = default_cons
	sc.conditions.append(cond)
	# Seq1 ending: auto_redirect vers condition, avec increment counter
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var cons = ConsequenceScript.new()
	cons.type = "redirect_condition"
	cons.target = cond.uuid
	var effect = VariableEffectScript.new()
	effect.variable = "counter"
	effect.operation = "increment"
	effect.value = "1"
	cons.effects.append(effect)
	ending.auto_consequence = cons
	seq1.ending = ending
	var report = _verifier.verify(story)
	assert_true(report["success"])
	assert_eq(report["runs"][0]["ending_reason"], "game_over")


# === Missing target ===

func test_verify_missing_target():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("redirect_sequence", "nonexistent_uuid")
	var report = _verifier.verify(story)
	assert_false(report["success"])
	assert_eq(report["runs"][0]["ending_reason"], "error")


# === Entry point UUID ===

func test_verify_entry_point_uuid():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("NotEntry", Vector2(0, 0))
	var seq2 = _make_sequence("Entry", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.entry_point_uuid = seq2.uuid
	seq2.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	# seq1 is orphan because entry goes to seq2 directly
	assert_false(report["success"])
	assert_eq(report["orphan_nodes"].size(), 1)
	assert_eq(report["orphan_nodes"][0]["name"], "NotEntry")
	assert_eq(report["runs"][0]["path"][0]["name"], "Entry")


# === Report success flag ===

func test_verify_report_success_all_valid_no_orphans():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_true(report["success"])

func test_verify_report_success_false_with_orphans():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("Orphan", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_false(report["success"])  # Orphan present

func test_verify_report_success_false_with_invalid_run():
	var story = _build_simple_story()
	# No ending -> no_ending -> invalid
	var report = _verifier.verify(story)
	assert_false(report["success"])


# === Choice effects applied ===

func test_verify_choice_effects_applied():
	var story = _make_story()
	var var_def = VariableDefinitionScript.new()
	var_def.var_name = "flag"
	var_def.initial_value = "0"
	story.variables.append(var_def)
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	sc.sequences.append(seq1)
	sc.entry_point_uuid = seq1.uuid
	# Condition: flag == "1" -> to_be_continued, sinon game_over
	var cond = ConditionModelScript.new()
	cond.condition_name = "CheckFlag"
	cond.position = Vector2(200, 0)
	var rule = ConditionRuleScript.new()
	rule.variable = "flag"
	rule.operator = "equal"
	rule.value = "1"
	var rule_cons = ConsequenceScript.new()
	rule_cons.type = "to_be_continued"
	rule.consequence = rule_cons
	cond.rules.append(rule)
	var default_cons = ConsequenceScript.new()
	default_cons.type = "game_over"
	cond.default_consequence = default_cons
	sc.conditions.append(cond)
	# Seq1 ending: choice with effect set flag=1, then redirect to condition
	var ending = EndingScript.new()
	ending.type = "choices"
	var choice = ChoiceScript.new()
	choice.text = "Set flag"
	var choice_effect = VariableEffectScript.new()
	choice_effect.variable = "flag"
	choice_effect.operation = "set"
	choice_effect.value = "1"
	choice.effects.append(choice_effect)
	var choice_cons = ConsequenceScript.new()
	choice_cons.type = "redirect_condition"
	choice_cons.target = cond.uuid
	choice.consequence = choice_cons
	ending.choices.append(choice)
	seq1.ending = ending
	var report = _verifier.verify(story)
	assert_true(report["success"])
	# Flag set to 1 by choice effect, condition matches rule -> to_be_continued
	assert_eq(report["runs"][0]["ending_reason"], "to_be_continued")


# === Path tracking ===

func test_verify_path_contains_all_visited_nodes():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("First", Vector2(0, 0))
	var seq2 = _make_sequence("Second", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_auto("redirect_sequence", seq2.uuid)
	seq2.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var path = report["runs"][0]["path"]
	assert_eq(path.size(), 2)
	assert_eq(path[0]["name"], "First")
	assert_eq(path[0]["type"], "sequence")
	assert_eq(path[1]["name"], "Second")
	assert_eq(path[1]["type"], "sequence")


# === Nodes count ===

func test_verify_all_nodes_count():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("Seq2", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	var cond = ConditionModelScript.new()
	cond.condition_name = "Cond1"
	cond.position = Vector2(400, 0)
	var default_cons = ConsequenceScript.new()
	default_cons.type = "game_over"
	cond.default_consequence = default_cons
	sc.conditions.append(cond)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_eq(report["all_nodes"], 3)  # 2 sequences + 1 condition


# === Enrichissement des étapes de path ===

func test_path_step_sequence_has_chapter_name():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_eq(step.get("chapter_name", "MISSING"), "Ch1")

func test_path_step_sequence_has_word_count():
	# _make_sequence ajoute 1 dialogue texte "Hello" = 1 mot
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_eq(step.get("word_count", -1), 1)

func test_path_step_sequence_has_dialogue_count():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_eq(step.get("dialogue_count", -1), 1)

func test_path_step_condition_has_chapter_name_and_zero_counts():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var cond = ConditionModelScript.new()
	cond.condition_name = "Cond"
	cond.position = Vector2(0, 0)
	var cons = ConsequenceScript.new()
	cons.type = "game_over"
	cond.default_consequence = cons
	sc.conditions.append(cond)
	sc.entry_point_uuid = cond.uuid
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_eq(step.get("chapter_name", "MISSING"), "Ch1")
	assert_eq(step.get("word_count", -1), 0)
	assert_eq(step.get("dialogue_count", -1), 0)

func test_path_step_choice_has_chapter_name_and_zero_counts():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("SeqA", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_choices([
		{"text": "Go A", "type": "redirect_sequence", "target": seq2.uuid},
	])
	seq2.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var choice_step = _find_choice_step(report["runs"][0]["path"])
	assert_eq(choice_step.get("chapter_name", "MISSING"), "Ch1")
	assert_eq(choice_step.get("word_count", -1), 0)
	assert_eq(choice_step.get("dialogue_count", -1), 0)

func test_path_step_chapter_name_correct_after_redirect_chapter():
	# ch1 -> redirect_chapter -> ch2 : les steps de ch2 doivent porter "Ch2"
	var story = _make_story()
	var ch1 = _make_chapter("Ch1", Vector2(0, 0))
	var ch2 = _make_chapter("Ch2", Vector2(200, 0))
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	story.entry_point_uuid = ch1.uuid
	var sc1 = _make_scene("Sc1")
	ch1.scenes.append(sc1)
	var sc2 = _make_scene("Sc2")
	ch2.scenes.append(sc2)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var seq2 = _make_sequence("Seq2")
	sc2.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_chapter", ch2.uuid)
	seq2.ending = _make_ending_auto("to_be_continued", "")
	var report = _verifier.verify(story)
	var path = report["runs"][0]["path"]
	# path[0] = seq1 dans Ch1, path[1] = seq2 dans Ch2
	assert_eq(path[0].get("chapter_name", "MISSING"), "Ch1")
	assert_eq(path[1].get("chapter_name", "MISSING"), "Ch2")


# === Helper ===

func _find_choice_step(path: Array) -> Dictionary:
	for step in path:
		if step["type"] == "choice":
			return step
	return {}


# === _count_sequence_words ===

func test_count_words_no_dialogues():
	var seq = SequenceScript.new()
	assert_eq(_verifier._count_sequence_words(seq), 0)

func test_count_words_one_dialogue():
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.text = "Hello world"
	seq.dialogues.append(dlg)
	assert_eq(_verifier._count_sequence_words(seq), 2)

func test_count_words_multiple_dialogues():
	var seq = SequenceScript.new()
	var dlg1 = DialogueScript.new()
	dlg1.text = "Hello world"
	var dlg2 = DialogueScript.new()
	dlg2.text = "Goodbye"
	seq.dialogues.append(dlg1)
	seq.dialogues.append(dlg2)
	assert_eq(_verifier._count_sequence_words(seq), 3)

func test_count_words_newline_separator():
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.text = "Hello\nworld"
	seq.dialogues.append(dlg)
	assert_eq(_verifier._count_sequence_words(seq), 2)

func test_count_words_empty_text():
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.text = ""
	seq.dialogues.append(dlg)
	assert_eq(_verifier._count_sequence_words(seq), 0)


# === _format_duration ===

func test_format_duration_seconds_only():
	assert_eq(_verifier._format_duration(45.0), "45 sec")

func test_format_duration_exact_minutes():
	assert_eq(_verifier._format_duration(120.0), "2 min")

func test_format_duration_minutes_and_seconds():
	assert_eq(_verifier._format_duration(150.0), "2 min 30 sec")

func test_format_duration_zero():
	assert_eq(_verifier._format_duration(0.0), "0 sec")

func test_format_duration_rounds_to_nearest_minute():
	assert_eq(_verifier._format_duration(59.6), "1 min")


# === _compute_timings ===

func test_compute_timings_direct_single_chapter():
	# 10 mots + 2 dialogues dans Ch1 via game_over : (10/250)*60 + 2*1.0 = 2.4 + 2.0 = 4.4 sec
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 10, "dialogue_count": 2, "type": "sequence"},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	var timings = result["chapters"]
	assert_eq(timings.size(), 1)
	assert_eq(timings[0]["chapter_name"], "Ch1")
	assert_true(timings[0].has("game_over"), "game_over doit etre present")
	assert_false(timings[0].has("to_be_continued"), "to_be_continued ne doit pas etre present")
	assert_almost_eq(timings[0]["game_over"]["min_seconds"], 4.4, 0.01)
	assert_almost_eq(timings[0]["game_over"]["max_seconds"], 4.4, 0.01)

func test_compute_timings_direct_two_runs_min_max():
	# Run 1 (game_over) : Ch1 = 0 mots, 1 dialogue -> 0 + 1.0 = 1.0 sec
	# Run 2 (to_be_continued) : Ch1 = 200 mots, 2 dialogues -> (200/250)*60 + 2 = 48.0 + 2.0 = 50.0 sec
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 1, "type": "sequence"}]
		},
		{
			"ending_reason": "to_be_continued",
			"path": [{"chapter_name": "Ch1", "word_count": 200, "dialogue_count": 2, "type": "sequence"}]
		},
	]
	var result = _verifier._compute_timings(runs)
	var timings = result["chapters"]
	assert_eq(timings.size(), 1)
	assert_true(timings[0].has("game_over"), "game_over doit etre present")
	assert_almost_eq(timings[0]["game_over"]["min_seconds"], 1.0, 0.01)
	assert_almost_eq(timings[0]["game_over"]["max_seconds"], 1.0, 0.01)
	assert_true(timings[0].has("to_be_continued"), "to_be_continued doit etre present")
	assert_almost_eq(timings[0]["to_be_continued"]["min_seconds"], 50.0, 0.01)
	assert_almost_eq(timings[0]["to_be_continued"]["max_seconds"], 50.0, 0.01)

func test_compute_timings_separates_game_over_from_to_be_continued():
	# Plusieurs runs game_over et to_be_continued : min/max separes
	var runs = [
		{"ending_reason": "game_over", "path": [{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 1, "type": "sequence"}]},
		{"ending_reason": "game_over", "path": [{"chapter_name": "Ch1", "word_count": 200, "dialogue_count": 0, "type": "sequence"}]},
		{"ending_reason": "to_be_continued", "path": [{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 2, "type": "sequence"}]},
		{"ending_reason": "to_be_continued", "path": [{"chapter_name": "Ch1", "word_count": 100, "dialogue_count": 0, "type": "sequence"}]},
	]
	var result = _verifier._compute_timings(runs)
	var timings = result["chapters"]
	assert_eq(timings.size(), 1)
	# game_over : 1.0 sec et 48.0 sec -> min=1.0, max=48.0
	assert_almost_eq(timings[0]["game_over"]["min_seconds"], 1.0, 0.01)
	assert_almost_eq(timings[0]["game_over"]["max_seconds"], 48.0, 0.01)
	# to_be_continued : 2.0 sec et 24.0 sec -> min=2.0, max=24.0
	assert_almost_eq(timings[0]["to_be_continued"]["min_seconds"], 2.0, 0.01)
	assert_almost_eq(timings[0]["to_be_continued"]["max_seconds"], 24.0, 0.01)

func test_compute_timings_with_choices():
	# Test specifique pour verifier que les choix ajoutent 5 secondes
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "choice"},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	assert_almost_eq(result["chapters"][0]["game_over"]["min_seconds"], 5.0, 0.01)

func test_compute_timings_excludes_error_runs():
	var runs = [
		{
			"ending_reason": "error",
			"path": [{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence"}]
		},
		{
			"ending_reason": "game_over",
			"path": [{"chapter_name": "Ch1", "word_count": 100, "dialogue_count": 3, "type": "sequence"}]
		},
	]
	var result = _verifier._compute_timings(runs)
	var timings = result["chapters"]
	# Seul le run game_over compte : (100/250)*60 + 3*1.0 = 24 + 3 = 27 sec
	assert_eq(timings.size(), 1)
	assert_true(timings[0].has("game_over"))
	assert_false(timings[0].has("to_be_continued"))
	assert_almost_eq(timings[0]["game_over"]["min_seconds"], 27.0, 0.01)
	assert_almost_eq(timings[0]["game_over"]["max_seconds"], 27.0, 0.01)

func test_compute_timings_excludes_loop_detected_runs():
	var runs = [
		{
			"ending_reason": "loop_detected",
			"path": [{"chapter_name": "Ch1", "word_count": 50, "dialogue_count": 2, "type": "sequence"}]
		},
		{
			"ending_reason": "to_be_continued",
			"path": [{"chapter_name": "Ch1", "word_count": 10, "dialogue_count": 1, "type": "sequence"}]
		},
	]
	var result = _verifier._compute_timings(runs)
	var timings = result["chapters"]
	assert_eq(timings.size(), 1)
	# Seul to_be_continued compte : (10/250)*60 + 1*1.0 = 2.4 + 1.0 = 3.4 sec
	assert_true(timings[0].has("to_be_continued"))
	assert_false(timings[0].has("game_over"))
	assert_almost_eq(timings[0]["to_be_continued"]["min_seconds"], 3.4, 0.01)
	assert_almost_eq(timings[0]["to_be_continued"]["max_seconds"], 3.4, 0.01)

func test_compute_timings_two_chapters_preserved_order():
	var runs = [
		{
			"ending_reason": "to_be_continued",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 1, "type": "sequence"},
				{"chapter_name": "Ch2", "word_count": 0, "dialogue_count": 2, "type": "sequence"},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	var timings = result["chapters"]
	assert_eq(timings.size(), 2)
	assert_eq(timings[0]["chapter_name"], "Ch1")
	assert_eq(timings[1]["chapter_name"], "Ch2")

func test_compute_timings_total_calculation():
	# Verifie le calcul de total_timings
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 100, "dialogue_count": 0, "type": "sequence"}, # 24s
				{"chapter_name": "Ch2", "word_count": 0, "dialogue_count": 6, "type": "sequence"},  # 6s
			]
		}, # Total 30s
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 10, "type": "sequence"}, # 10s
			]
		} # Total 10s
	]
	var result = _verifier._compute_timings(runs)
	assert_eq(result["total"]["game_over"]["min_seconds"], 10.0)
	assert_eq(result["total"]["game_over"]["max_seconds"], 30.0)

func test_compute_timings_empty_runs():
	var result = _verifier._compute_timings([])
	assert_eq(result["chapters"].size(), 0)
	assert_eq(result["total"].size(), 0)


# === verify() inclut chapter_timings ===

func test_verify_includes_timings_keys():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_true(report.has("chapter_timings"), "chapter_timings doit être présent dans le rapport")
	assert_true(report.has("total_timings"), "total_timings doit être présent dans le rapport")

func test_verify_chapter_timings_one_chapter():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var timings = report["chapter_timings"]
	assert_eq(timings.size(), 1)
	assert_eq(timings[0]["chapter_name"], "Ch1")
	# _make_sequence crée 1 dialogue "Hello" = 1 mot
	# time = (1/250)*60 + 1*1.0 = 0.24 + 1.0 = 1.24 sec — chemin game_over
	assert_true(timings[0].has("game_over"))
	assert_almost_eq(timings[0]["game_over"]["min_seconds"], 1.24, 0.01)
	assert_almost_eq(timings[0]["game_over"]["max_seconds"], 1.24, 0.01)

func test_verify_total_timings_one_chapter():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var total = report["total_timings"]
	# time = (1/250)*60 + 1*1.0 = 1.24 sec
	assert_true(total.has("game_over"))
	assert_almost_eq(total["game_over"]["min_seconds"], 1.24, 0.01)

func test_verify_chapter_timings_two_chapters():
	var story = _make_story()
	var ch1 = _make_chapter("Ch1", Vector2(0, 0))
	var ch2 = _make_chapter("Ch2", Vector2(200, 0))
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	var sc1 = _make_scene("Sc1")
	ch1.scenes.append(sc1)
	var sc2 = _make_scene("Sc2")
	ch2.scenes.append(sc2)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var seq2 = _make_sequence("Seq2")
	sc2.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_chapter", ch2.uuid)
	seq2.ending = _make_ending_auto("to_be_continued", "")
	var report = _verifier.verify(story)
	var timings = report["chapter_timings"]
	assert_eq(timings.size(), 2)
	assert_eq(timings[0]["chapter_name"], "Ch1")
	assert_eq(timings[1]["chapter_name"], "Ch2")


# === _empty_report inclut chapter_timings ===

func test_empty_report_has_chapter_timings():
	var report = _verifier.verify(null)
	assert_true(report.has("chapter_timings"))
	assert_eq(report["chapter_timings"], [])


# === Audio duration ===

func test_get_audio_duration_returns_zero_for_empty_path():
	assert_almost_eq(_verifier._get_audio_duration(""), 0.0, 0.01)

func test_get_audio_duration_returns_zero_for_nonexistent_file():
	assert_almost_eq(_verifier._get_audio_duration("/tmp/nonexistent_audio_file.mp3"), 0.0, 0.01)

func test_get_audio_duration_caches_result():
	# Call twice, second call should use cache
	_verifier._get_audio_duration("/tmp/nonexistent_audio_file.mp3")
	_verifier._get_audio_duration("/tmp/nonexistent_audio_file.mp3")
	# If we got here without error, caching works
	assert_true(_verifier._audio_duration_cache.has("/tmp/nonexistent_audio_file.mp3"))

func test_compute_sequence_audio_duration_no_voice_files():
	var seq = _make_sequence("NoVoice")
	# Default dialogue has no voice_files
	var duration = _verifier._compute_sequence_audio_duration(seq, "/tmp")
	assert_almost_eq(duration, 0.0, 0.01)

func test_compute_sequence_audio_duration_with_voice_files_nonexistent():
	var seq = SequenceScript.new()
	seq.seq_name = "WithVoice"
	seq.position = Vector2(0, 0)
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	dlg.voice_files = {"fr": "assets/voices/test_fr.mp3"}
	seq.dialogues.append(dlg)
	var duration = _verifier._compute_sequence_audio_duration(seq, "/tmp")
	# File doesn't exist, so duration = 0
	assert_almost_eq(duration, 0.0, 0.01)

func test_compute_sequence_audio_duration_empty_story_base_path():
	var seq = SequenceScript.new()
	seq.seq_name = "WithVoice"
	seq.position = Vector2(0, 0)
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	dlg.voice_files = {"fr": "assets/voices/test_fr.mp3"}
	seq.dialogues.append(dlg)
	var duration = _verifier._compute_sequence_audio_duration(seq, "")
	assert_almost_eq(duration, 0.0, 0.01)


# === Audio duration in simulation steps and timings ===

func test_simulate_step_includes_audio_duration_key():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_true(step.has("audio_duration"), "Step should have audio_duration key")
	assert_almost_eq(step["audio_duration"], 0.0, 0.01)

func test_compute_timings_includes_audio_fields():
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 10, "dialogue_count": 2, "type": "sequence", "audio_duration": 5.5},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	var ch = result["chapters"][0]
	assert_true(ch["game_over"].has("audio_min_seconds"))
	assert_true(ch["game_over"].has("audio_max_seconds"))
	assert_almost_eq(ch["game_over"]["audio_min_seconds"], 5.5, 0.01)
	assert_almost_eq(ch["game_over"]["audio_max_seconds"], 5.5, 0.01)

func test_compute_timings_audio_min_max_across_runs():
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 3.0},
			]
		},
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 10.0},
			]
		},
	]
	var result = _verifier._compute_timings(runs)
	var ch = result["chapters"][0]
	assert_almost_eq(ch["game_over"]["audio_min_seconds"], 3.0, 0.01)
	assert_almost_eq(ch["game_over"]["audio_max_seconds"], 10.0, 0.01)

func test_compute_timings_audio_in_total():
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 7.0},
				{"chapter_name": "Ch2", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 3.0},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	var total = result["total"]
	assert_true(total["game_over"].has("audio_min_seconds"))
	assert_almost_eq(total["game_over"]["audio_min_seconds"], 10.0, 0.01)
	assert_almost_eq(total["game_over"]["audio_max_seconds"], 10.0, 0.01)

func test_compute_timings_audio_zero_when_no_audio():
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 10, "dialogue_count": 1, "type": "sequence", "audio_duration": 0.0},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	var ch = result["chapters"][0]
	assert_almost_eq(ch["game_over"]["audio_min_seconds"], 0.0, 0.01)
	assert_almost_eq(ch["game_over"]["audio_max_seconds"], 0.0, 0.01)

func test_compute_timings_audio_choices_and_conditions_zero():
	# Choices and conditions should contribute 0 audio_duration
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "choice", "audio_duration": 0.0},
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "condition", "audio_duration": 0.0},
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 5.0},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	assert_almost_eq(result["chapters"][0]["game_over"]["audio_min_seconds"], 5.0, 0.01)


# === _compute_max_runs ===

func test_compute_max_runs_no_choices_returns_min():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	assert_eq(_verifier._compute_max_runs(story), StoryVerifier.MIN_RUNS)

func test_compute_max_runs_few_choices_returns_min():
	# 2 choix * 2 = 4 < MIN_RUNS -> MIN_RUNS
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("SeqA", Vector2(200, 0))
	var seq3 = _make_sequence("SeqB", Vector2(200, 200))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.sequences.append(seq3)
	seq1.ending = _make_ending_choices([
		{"text": "Go A", "type": "redirect_sequence", "target": seq2.uuid},
		{"text": "Go B", "type": "redirect_sequence", "target": seq3.uuid},
	])
	seq2.ending = _make_ending_auto("game_over", "")
	seq3.ending = _make_ending_auto("game_over", "")
	assert_eq(_verifier._compute_max_runs(story), StoryVerifier.MIN_RUNS)

func test_compute_max_runs_many_choices_scales_up():
	# Creer une histoire avec beaucoup de choix pour depasser MIN_RUNS
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	# Creer 30 sequences, chacune avec 4 choix = 120 choix total -> 240 runs
	var targets := []
	for i in range(30):
		var target = _make_sequence("Target%d" % i, Vector2(400, i * 50))
		target.ending = _make_ending_auto("game_over", "")
		sc.sequences.append(target)
		targets.append(target)
	for i in range(30):
		var seq = _make_sequence("Seq%d" % i, Vector2(0, i * 50))
		var t0 = targets[i].uuid
		var t1 = targets[(i + 1) % 30].uuid
		var t2 = targets[(i + 2) % 30].uuid
		var t3 = targets[(i + 3) % 30].uuid
		seq.ending = _make_ending_choices([
			{"text": "A", "type": "redirect_sequence", "target": t0},
			{"text": "B", "type": "redirect_sequence", "target": t1},
			{"text": "C", "type": "redirect_sequence", "target": t2},
			{"text": "D", "type": "redirect_sequence", "target": t3},
		])
		sc.sequences.append(seq)
	# 30 sequences * 4 choix = 120 choix -> max(100, 120 * 2) = 240
	assert_eq(_verifier._compute_max_runs(story), 240)

func test_compute_max_runs_no_ending_ignored():
	var story = _build_simple_story()
	# No ending set -> no choices counted
	assert_eq(_verifier._compute_max_runs(story), StoryVerifier.MIN_RUNS)

func test_compute_max_runs_auto_redirect_not_counted():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	# auto_redirect is not a choice, should not inflate count
	assert_eq(_verifier._compute_max_runs(story), StoryVerifier.MIN_RUNS)


# === _compute_max_steps ===

func test_compute_max_steps_few_nodes_returns_min():
	assert_eq(_verifier._compute_max_steps(5), StoryVerifier.MIN_STEPS)

func test_compute_max_steps_many_nodes_scales_up():
	# 500 nodes * 50 = 25000 > MIN_STEPS
	assert_eq(_verifier._compute_max_steps(500), 25000)

func test_compute_max_steps_boundary():
	# 200 nodes * 50 = 10000 == MIN_STEPS -> MIN_STEPS
	assert_eq(_verifier._compute_max_steps(200), StoryVerifier.MIN_STEPS)
