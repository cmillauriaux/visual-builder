extends GutTest

const ConsequenceTargetHelperScript = preload("res://src/ui/consequence_target_helper.gd")
const ConsequenceScript = preload("res://src/models/consequence.gd")

var _helper: RefCounted

func before_each():
	_helper = ConsequenceTargetHelperScript.new()


# --- Constantes ---

func test_consequence_types_match_model():
	assert_eq(_helper.CONSEQUENCE_TYPES, ConsequenceScript.VALID_TYPES)

func test_redirect_types_match_model():
	assert_eq(_helper.REDIRECT_TYPES, ConsequenceScript.REDIRECT_TYPES)

func test_consequence_labels_count_matches_types():
	assert_eq(ConsequenceTargetHelperScript.CONSEQUENCE_LABELS.size(), ConsequenceTargetHelperScript.CONSEQUENCE_TYPES.size())

func test_consequence_labels_are_french():
	var labels = ConsequenceTargetHelperScript.CONSEQUENCE_LABELS
	assert_eq(labels[0], "Séquence")
	assert_eq(labels[1], "Condition")
	assert_eq(labels[2], "Scène")
	assert_eq(labels[3], "Chapitre")
	assert_eq(labels[4], "Game Over")
	assert_eq(labels[5], "To be continued")


# --- set_available_targets ---

func test_set_available_targets_stores_all():
	var seqs = [{"uuid": "s1", "name": "Seq1"}]
	var scenes = [{"uuid": "sc1", "name": "Scene1"}]
	var chapters = [{"uuid": "ch1", "name": "Chap1"}]
	var conditions = [{"uuid": "c1", "name": "Cond1"}]
	_helper.set_available_targets(seqs, scenes, chapters, conditions)
	assert_eq(_helper.available_sequences, seqs)
	assert_eq(_helper.available_scenes, scenes)
	assert_eq(_helper.available_chapters, chapters)
	assert_eq(_helper.available_conditions, conditions)

func test_set_available_targets_conditions_default_empty():
	_helper.set_available_targets([], [], [])
	assert_eq(_helper.available_conditions, [])


# --- get_targets_for_type ---

func test_get_targets_for_redirect_sequence():
	var seqs = [{"uuid": "s1", "name": "Seq1"}]
	_helper.set_available_targets(seqs, [], [])
	assert_eq(_helper.get_targets_for_type("redirect_sequence"), seqs)

func test_get_targets_for_redirect_condition():
	var conds = [{"uuid": "c1", "name": "Cond1"}]
	_helper.set_available_targets([], [], [], conds)
	assert_eq(_helper.get_targets_for_type("redirect_condition"), conds)

func test_get_targets_for_redirect_scene():
	var scenes = [{"uuid": "sc1", "name": "Scene1"}]
	_helper.set_available_targets([], scenes, [])
	assert_eq(_helper.get_targets_for_type("redirect_scene"), scenes)

func test_get_targets_for_redirect_chapter():
	var chapters = [{"uuid": "ch1", "name": "Chap1"}]
	_helper.set_available_targets([], [], chapters)
	assert_eq(_helper.get_targets_for_type("redirect_chapter"), chapters)

func test_get_targets_for_unknown_type_returns_empty():
	assert_eq(_helper.get_targets_for_type("game_over"), [])
	assert_eq(_helper.get_targets_for_type("to_be_continued"), [])
	assert_eq(_helper.get_targets_for_type("invalid"), [])


# --- populate_target_dropdown ---

func test_populate_target_dropdown_fills_items():
	var dropdown = OptionButton.new()
	add_child_autofree(dropdown)
	_helper.set_available_targets(
		[{"uuid": "s1", "name": "Seq1"}, {"uuid": "s2", "name": "Seq2"}],
		[], []
	)
	_helper.populate_target_dropdown(dropdown, "redirect_sequence")
	assert_eq(dropdown.item_count, 2)
	assert_eq(dropdown.get_item_text(0), "Seq1")
	assert_eq(dropdown.get_item_metadata(0), "s1")
	assert_eq(dropdown.get_item_text(1), "Seq2")
	assert_eq(dropdown.get_item_metadata(1), "s2")

func test_populate_target_dropdown_clears_previous():
	var dropdown = OptionButton.new()
	add_child_autofree(dropdown)
	dropdown.add_item("Old")
	_helper.set_available_targets([{"uuid": "s1", "name": "New"}], [], [])
	_helper.populate_target_dropdown(dropdown, "redirect_sequence")
	assert_eq(dropdown.item_count, 1)
	assert_eq(dropdown.get_item_text(0), "New")

func test_populate_target_dropdown_empty_for_non_redirect():
	var dropdown = OptionButton.new()
	add_child_autofree(dropdown)
	_helper.populate_target_dropdown(dropdown, "game_over")
	assert_eq(dropdown.item_count, 0)


# --- variable_names ---

func test_variable_names_default_empty():
	assert_eq(_helper.variable_names, [])

func test_variable_names_set_and_get():
	_helper.variable_names = ["hp", "score"]
	assert_eq(_helper.variable_names, ["hp", "score"])
