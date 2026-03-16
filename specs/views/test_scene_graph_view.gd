extends GutTest

var SceneGraphViewScript
var ChapterScript
var SceneDataScript

var _view
var _chapter

func before_each():
	SceneGraphViewScript = load("res://src/views/scene_graph_view.gd")
	ChapterScript = load("res://src/models/chapter.gd")
	SceneDataScript = load("res://src/models/scene_data.gd")
	
	_view = GraphEdit.new()
	_view.set_script(SceneGraphViewScript)
	add_child_autofree(_view)
	_chapter = ChapterScript.new()

func test_load_chapter_empty():
	_view.load_chapter(_chapter)
	assert_eq(_view.get_node_count(), 0)

func test_load_chapter_with_scenes():
	var s1 = SceneDataScript.new()
	s1.scene_name = "S1"
	var s2 = SceneDataScript.new()
	s2.scene_name = "S2"
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_node_count(), 2)

func test_add_new_scene():
	_view.load_chapter(_chapter)
	_view.add_new_scene("New Scene", Vector2(100, 100))
	assert_eq(_chapter.scenes.size(), 1)
	assert_eq(_view.get_node_count(), 1)

func test_remove_scene():
	var s1 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_node_count(), 1)
	_view.remove_scene(s1.uuid)
	assert_eq(_chapter.scenes.size(), 0)
	assert_eq(_view.get_node_count(), 0)

func test_connection_type_transition():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_chapter.connections.append({"from": s1.uuid, "to": s2.uuid})
	_view.load_chapter(_chapter)
	assert_eq(_view.get_connection_type(s1.uuid, s2.uuid), "transition")

func test_entry_point_toggle():
	var s1 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_view.load_chapter(_chapter)
	_view._on_entry_point_toggled(s1.uuid, true)
	assert_eq(_chapter.entry_point_uuid, s1.uuid)
	_view._on_entry_point_toggled(s1.uuid, false)
	assert_eq(_chapter.entry_point_uuid, "")

func test_merge_connection_type():
	_view._merge_connection_type("key", "transition")
	assert_eq(_view._connection_type_map["key"], "transition")
	_view._merge_connection_type("key", "choice")
	assert_eq(_view._connection_type_map["key"], "both")

func test_compute_colors():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)

	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "transition"
	var color = _view._compute_outgoing_color(s1.uuid)
	assert_eq(color, _view.COLOR_TRANSITION)

	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "choice"
	color = _view._compute_outgoing_color(s1.uuid)
	assert_eq(color, _view.COLOR_CHOICE)

	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "both"
	color = _view._compute_outgoing_color(s1.uuid)
	assert_eq(color, _view.COLOR_BOTH)


func test_get_chapter():
	_view.load_chapter(_chapter)
	assert_eq(_view.get_chapter(), _chapter)


func test_rename_scene():
	var s = SceneDataScript.new()
	s.scene_name = "Old"
	_chapter.scenes.append(s)
	_view.load_chapter(_chapter)
	_view.rename_scene(s.uuid, "New", "Sub")
	assert_eq(_chapter.scenes[0].scene_name, "New")
	assert_eq(_chapter.scenes[0].subtitle, "Sub")


func test_rename_scene_unknown_uuid():
	_view.load_chapter(_chapter)
	_view.rename_scene("invalid-uuid", "Name")
	pass_test("rename_scene with unknown uuid should not crash")


func test_add_scene_connection():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	_view.add_scene_connection(s1.uuid, s2.uuid)
	assert_eq(_chapter.connections.size(), 1)


func test_sync_positions_to_model():
	var s = SceneDataScript.new()
	_chapter.scenes.append(s)
	_view.load_chapter(_chapter)
	_view.sync_positions_to_model()
	pass_test("sync_positions_to_model should not crash")


func test_compute_incoming_color():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "transition"
	var color = _view._compute_incoming_color(s2.uuid)
	assert_eq(color, _view.COLOR_TRANSITION)
	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "choice"
	color = _view._compute_incoming_color(s2.uuid)
	assert_eq(color, _view.COLOR_CHOICE)
	_view._connection_type_map[s1.uuid + "→" + s2.uuid] = "both"
	color = _view._compute_incoming_color(s2.uuid)
	assert_eq(color, _view.COLOR_BOTH)


func test_canvas_to_screen():
	var result = _view._canvas_to_screen(Vector2(100, 50))
	assert_true(result is Vector2)


func test_is_near_bezier_close():
	assert_true(_view._is_near_bezier(Vector2(150, 100), Vector2(100, 100), Vector2(200, 100)))


func test_is_near_bezier_far():
	assert_false(_view._is_near_bezier(Vector2(150, 500), Vector2(100, 100), Vector2(200, 100)))


func test_get_connection_line_backward():
	var points = _view._get_connection_line(Vector2(200, 100), Vector2(100, 100))
	assert_gt(points.size(), 0)


func test_update_tooltip_empty_hovered_key():
	_view._hovered_key = ""
	_view._update_tooltip(Vector2(100, 100))
	assert_false(_view._tooltip_panel.visible)


func test_update_tooltip_transition():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	var key = s1.uuid + "→" + s2.uuid
	_view._connection_type_map[key] = "transition"
	_view._hovered_key = key
	_view._update_tooltip(Vector2(100, 100))
	assert_eq(_view._tooltip_label.text, "Transition automatique")


func test_update_tooltip_choice():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	var key = s1.uuid + "→" + s2.uuid
	_view._connection_type_map[key] = "choice"
	_view._hovered_key = key
	_view._update_tooltip(Vector2(100, 100))
	assert_eq(_view._tooltip_label.text, "Choix du joueur")


func test_update_tooltip_both():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	var key = s1.uuid + "→" + s2.uuid
	_view._connection_type_map[key] = "both"
	_view._hovered_key = key
	_view._update_tooltip(Vector2(100, 100))
	assert_eq(_view._tooltip_label.text, "Transition et Choix")


func test_on_node_double_clicked_emits_signal():
	var s = SceneDataScript.new()
	_chapter.scenes.append(s)
	_view.load_chapter(_chapter)
	watch_signals(_view)
	_view._on_node_double_clicked(s.uuid)
	assert_signal_emitted(_view, "scene_double_clicked")


func test_on_node_rename_requested_emits_signal():
	var s = SceneDataScript.new()
	_chapter.scenes.append(s)
	_view.load_chapter(_chapter)
	watch_signals(_view)
	_view._on_node_rename_requested(s.uuid)
	assert_signal_emitted(_view, "scene_rename_requested")


func test_on_node_delete_requested_emits_signal():
	var s = SceneDataScript.new()
	_chapter.scenes.append(s)
	_view.load_chapter(_chapter)
	watch_signals(_view)
	_view._on_node_delete_requested(s.uuid)
	assert_signal_emitted(_view, "scene_delete_requested")


func test_build_connection_map_auto_redirect_scene():
	var EndingScript = load("res://src/models/ending.gd")
	var ConsequenceScript = load("res://src/models/consequence.gd")
	var SequenceScript = load("res://src/models/sequence.gd")
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	var seq = SequenceScript.new()
	var ending = EndingScript.new()
	ending.type = "auto_redirect"
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_scene"
	consequence.target = s2.uuid
	ending.auto_consequence = consequence
	seq.ending = ending
	s1.sequences.append(seq)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_connection_type(s1.uuid, s2.uuid), "transition")


func test_build_connection_map_choice_redirect_scene():
	var EndingScript = load("res://src/models/ending.gd")
	var ConsequenceScript = load("res://src/models/consequence.gd")
	var ChoiceScript = load("res://src/models/choice.gd")
	var SequenceScript = load("res://src/models/sequence.gd")
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	var seq = SequenceScript.new()
	var ending = EndingScript.new()
	ending.type = "choices"
	var choice = ChoiceScript.new()
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_scene"
	consequence.target = s2.uuid
	choice.consequence = consequence
	ending.choices.append(choice)
	seq.ending = ending
	s1.sequences.append(seq)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_connection_type(s1.uuid, s2.uuid), "choice")


func test_build_connection_map_condition_rule_redirect_scene():
	var ConsequenceScript = load("res://src/models/consequence.gd")
	var ConditionScript = load("res://src/models/condition.gd")
	var ConditionRuleScript = load("res://src/models/condition_rule.gd")
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	var cond = ConditionScript.new()
	var rule = ConditionRuleScript.new()
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_scene"
	consequence.target = s2.uuid
	rule.consequence = consequence
	cond.rules.append(rule)
	s1.conditions.append(cond)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_connection_type(s1.uuid, s2.uuid), "transition")


func test_build_connection_map_condition_default_consequence():
	var ConsequenceScript = load("res://src/models/consequence.gd")
	var ConditionScript = load("res://src/models/condition.gd")
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	var cond = ConditionScript.new()
	var consequence = ConsequenceScript.new()
	consequence.type = "redirect_scene"
	consequence.target = s2.uuid
	cond.default_consequence = consequence
	s1.conditions.append(cond)
	_view.load_chapter(_chapter)
	assert_eq(_view.get_connection_type(s1.uuid, s2.uuid), "transition")


func test_entry_point_switch():
	var s1 = SceneDataScript.new()
	var s2 = SceneDataScript.new()
	_chapter.scenes.append(s1)
	_chapter.scenes.append(s2)
	_view.load_chapter(_chapter)
	_view._on_entry_point_toggled(s1.uuid, true)
	assert_eq(_chapter.entry_point_uuid, s1.uuid)
	_view._on_entry_point_toggled(s2.uuid, true)
	assert_eq(_chapter.entry_point_uuid, s2.uuid)
