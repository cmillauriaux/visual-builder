extends GutTest

const FxPanelScript = preload("res://src/ui/sequence/fx_panel.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const SequenceFx = preload("res://src/models/sequence_fx.gd")

var _panel: VBoxContainer


func before_each() -> void:
	_panel = VBoxContainer.new()
	_panel.set_script(FxPanelScript)
	add_child(_panel)


func after_each() -> void:
	remove_child(_panel)
	_panel.queue_free()


func test_panel_builds_ui() -> void:
	assert_not_null(_panel._fx_list_container, "should have fx list container")
	assert_not_null(_panel._add_button, "should have add button")


func test_load_sequence_empty_fx() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	assert_eq(_panel._fx_list_container.get_child_count(), 0)


func test_load_sequence_with_fx() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	assert_eq(_panel._fx_list_container.get_child_count(), 1)


func test_load_sequence_with_multiple_fx() -> void:
	var seq = SequenceScript.new()
	for i in range(3):
		var fx = SequenceFx.new()
		seq.fx.append(fx)
	_panel.load_sequence(seq)
	assert_eq(_panel._fx_list_container.get_child_count(), 3)


func test_clear_removes_fx_rows() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	assert_eq(_panel._fx_list_container.get_child_count(), 1)
	_panel.clear()
	# queue_free is deferred, check sequence is null
	assert_null(_panel._sequence)


func test_add_fx_fade_in() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	_panel._on_add_fx_type_selected(0)  # fade_in
	assert_eq(seq.fx.size(), 1)
	assert_eq(seq.fx[0].fx_type, "fade_in")


func test_add_fx_screen_shake() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	_panel._on_add_fx_type_selected(1)  # screen_shake
	assert_eq(seq.fx.size(), 1)
	assert_eq(seq.fx[0].fx_type, "screen_shake")


func test_add_fx_eyes_blink() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	_panel._on_add_fx_type_selected(2)  # eyes_blink
	assert_eq(seq.fx.size(), 1)
	assert_eq(seq.fx[0].fx_type, "eyes_blink")


func test_add_fx_flash() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	_panel._on_add_fx_type_selected(3)  # flash
	assert_eq(seq.fx.size(), 1)
	assert_eq(seq.fx[0].fx_type, "flash")


func test_add_fx_zoom() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	_panel._on_add_fx_type_selected(4)  # zoom
	assert_eq(seq.fx.size(), 1)
	assert_eq(seq.fx[0].fx_type, "zoom")


func test_add_fx_vignette() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	_panel._on_add_fx_type_selected(5)  # vignette
	assert_eq(seq.fx.size(), 1)
	assert_eq(seq.fx[0].fx_type, "vignette")


func test_add_fx_desaturation() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	_panel._on_add_fx_type_selected(6)  # desaturation
	assert_eq(seq.fx.size(), 1)
	assert_eq(seq.fx[0].fx_type, "desaturation")


func test_flash_row_has_color_picker() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	var row = _panel._fx_list_container.get_child(0)
	var color_picker = row.get_node_or_null("ColorPicker")
	assert_not_null(color_picker, "flash row should have color picker")


func test_non_flash_row_no_color_picker() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	fx.fx_type = "screen_shake"
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	var row = _panel._fx_list_container.get_child(0)
	var color_picker = row.get_node_or_null("ColorPicker")
	assert_null(color_picker, "non-flash row should not have color picker")


func test_color_changed() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	_panel._on_color_changed(0, Color.RED)
	assert_eq(seq.fx[0].color, Color.RED)


func test_color_changed_emits_signal() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	fx.fx_type = "flash"
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_color_changed(0, Color.BLUE)
	assert_signal_emitted(_panel, "fx_changed")


func test_add_fx_emits_signal() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_add_fx_type_selected(0)
	assert_signal_emitted(_panel, "fx_changed")


func test_delete_fx() -> void:
	var seq = SequenceScript.new()
	var fx1 = SequenceFx.new()
	fx1.fx_type = "fade_in"
	var fx2 = SequenceFx.new()
	fx2.fx_type = "screen_shake"
	seq.fx.append(fx1)
	seq.fx.append(fx2)
	_panel.load_sequence(seq)
	_panel._on_delete(0)
	assert_eq(seq.fx.size(), 1)
	assert_eq(seq.fx[0].fx_type, "screen_shake")


func test_delete_emits_signal() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_delete(0)
	assert_signal_emitted(_panel, "fx_changed")


func test_type_changed() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	fx.fx_type = "fade_in"
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	_panel._on_type_changed(0, 0)  # screen_shake is index 0 in VALID_FX_TYPES
	assert_eq(seq.fx[0].fx_type, "screen_shake")


func test_duration_changed() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	_panel._on_duration_changed(0, 2.0)
	assert_eq(seq.fx[0].duration, 2.0)


func test_intensity_changed() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	_panel._on_intensity_changed(0, 1.5)
	assert_eq(seq.fx[0].intensity, 1.5)


func test_type_changed_emits_signal() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_type_changed(0, 1)
	assert_signal_emitted(_panel, "fx_changed")


func test_duration_changed_emits_signal() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_duration_changed(0, 3.0)
	assert_signal_emitted(_panel, "fx_changed")


func test_intensity_changed_emits_signal() -> void:
	var seq = SequenceScript.new()
	var fx = SequenceFx.new()
	seq.fx.append(fx)
	_panel.load_sequence(seq)
	watch_signals(_panel)
	_panel._on_intensity_changed(0, 2.0)
	assert_signal_emitted(_panel, "fx_changed")


func test_add_without_sequence_does_nothing() -> void:
	_panel._on_add_fx_type_selected(0)
	pass_test("should not crash without sequence")


func test_delete_invalid_index_does_nothing() -> void:
	var seq = SequenceScript.new()
	_panel.load_sequence(seq)
	_panel._on_delete(99)
	pass_test("should not crash on invalid index")


func test_load_sequence_replaces_previous() -> void:
	var seq1 = SequenceScript.new()
	var fx1 = SequenceFx.new()
	seq1.fx.append(fx1)
	_panel.load_sequence(seq1)

	var seq2 = SequenceScript.new()
	_panel.load_sequence(seq2)
	assert_eq(_panel._sequence, seq2)
