extends GutTest

## Tests pour PlayContext — objet d'injection de dépendances pour PlayController.

const PlayContextScript = preload("res://src/controllers/play_context.gd")


func test_instantiation() -> void:
	var ctx = PlayContextScript.new()
	assert_not_null(ctx, "should instantiate without error")


func test_default_values_are_null() -> void:
	var ctx = PlayContextScript.new()
	assert_null(ctx.sequence_editor_ctrl)
	assert_null(ctx.story_play_ctrl)
	assert_null(ctx.editor_main)
	assert_null(ctx.foreground_transition)
	assert_null(ctx.visual_editor)
	assert_null(ctx.play_button)
	assert_null(ctx.stop_button)
	assert_null(ctx.play_overlay)
	assert_null(ctx.play_character_label)
	assert_null(ctx.play_text_label)
	assert_null(ctx.typewriter_timer)
	assert_null(ctx.choice_overlay)
	assert_null(ctx.top_play_button)
	assert_null(ctx.top_stop_button)
	assert_null(ctx.vbox)
	assert_null(ctx.left_panel)
	assert_null(ctx.sequence_editor_panel)
	assert_null(ctx.chapter_graph_view)
	assert_null(ctx.scene_graph_view)
	assert_null(ctx.sequence_graph_view)
	assert_null(ctx.main_node)


func test_set_controller_references() -> void:
	var ctx = PlayContextScript.new()
	var ctrl = Control.new()
	ctx.sequence_editor_ctrl = ctrl
	assert_eq(ctx.sequence_editor_ctrl, ctrl)
	ctrl.free()


func test_set_ui_references() -> void:
	var ctx = PlayContextScript.new()
	var btn = Button.new()
	var label = Label.new()
	var timer = Timer.new()
	ctx.play_button = btn
	ctx.play_character_label = label
	ctx.typewriter_timer = timer
	assert_eq(ctx.play_button, btn)
	assert_eq(ctx.play_character_label, label)
	assert_eq(ctx.typewriter_timer, timer)
	btn.free()
	label.free()
	timer.free()


func test_set_layout_references() -> void:
	var ctx = PlayContextScript.new()
	var vbox = VBoxContainer.new()
	var graph = GraphEdit.new()
	ctx.vbox = vbox
	ctx.chapter_graph_view = graph
	assert_eq(ctx.vbox, vbox)
	assert_eq(ctx.chapter_graph_view, graph)
	vbox.free()
	graph.free()


func test_set_callables() -> void:
	var ctx = PlayContextScript.new()
	var calls := []
	ctx.update_preview_for_dialogue = func(_idx): calls.append(true)
	ctx.update_preview_for_dialogue.call(0)
	assert_eq(calls.size(), 1, "callable should have been called once")


func test_set_multiple_callables() -> void:
	var ctx = PlayContextScript.new()
	var results := []
	ctx.highlight_dialogue_in_list = func(idx): results.append("highlight_%d" % idx)
	ctx.load_sequence_editors = func(_seq): results.append("load")
	ctx.update_view = func(): results.append("view")
	ctx.refresh_current_view = func(): results.append("refresh")

	ctx.highlight_dialogue_in_list.call(3)
	ctx.load_sequence_editors.call(null)
	ctx.update_view.call()
	ctx.refresh_current_view.call()

	assert_eq(results, ["highlight_3", "load", "view", "refresh"])
