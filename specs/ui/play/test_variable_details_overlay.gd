extends GutTest

var VariableDetailsOverlayScript = load("res://src/ui/play/variable_details_overlay.gd")
var StoryScript = load("res://src/models/story.gd")
var VariableDefinitionScript = load("res://src/models/variable_definition.gd")

var _overlay: CenterContainer


func before_each():
	_overlay = CenterContainer.new()
	_overlay.set_script(VariableDetailsOverlayScript)
	add_child(_overlay)
	_overlay.build_ui()


func after_each():
	_overlay.queue_free()


func _make_var(vname: String, on_details: bool = true, vis_mode: String = "always", vis_var: String = "", desc: String = "") -> RefCounted:
	var v = VariableDefinitionScript.new()
	v.var_name = vname
	v.initial_value = "0"
	v.show_on_details = on_details
	v.visibility_mode = vis_mode
	v.visibility_variable = vis_var
	v.description = desc
	return v


func _make_story(vars: Array) -> RefCounted:
	var story = StoryScript.new()
	for v in vars:
		story.variables.append(v)
	return story


# --- Tests ---

func test_overlay_hidden_initially():
	assert_eq(_overlay.visible, false)


func test_overlay_shows_on_show_details():
	var story = _make_story([_make_var("score")])
	_overlay.show_details(story, {"score": "10"})
	assert_eq(_overlay.visible, true)


func test_overlay_shows_details_variables():
	var story = _make_story([
		_make_var("score", true),
		_make_var("hidden", false),
		_make_var("hp", true),
	])
	_overlay.show_details(story, {"score": "10", "hidden": "5", "hp": "50"})
	assert_eq(_overlay.get_displayed_count(), 2)


func test_overlay_respects_visibility_rules():
	var v = _make_var("score", true, "variable", "unlocked")
	var story = _make_story([v])
	_overlay.show_details(story, {"score": "10", "unlocked": "0"})
	assert_eq(_overlay.get_displayed_count(), 0)


func test_overlay_shows_when_visibility_var_is_1():
	var v = _make_var("score", true, "variable", "unlocked")
	var story = _make_story([v])
	_overlay.show_details(story, {"score": "10", "unlocked": "1"})
	assert_eq(_overlay.get_displayed_count(), 1)


func test_overlay_close_signal():
	watch_signals(_overlay)
	_overlay._close_btn.pressed.emit()
	assert_signal_emitted(_overlay, "close_requested")


func test_overlay_hide_details():
	var story = _make_story([_make_var("score")])
	_overlay.show_details(story, {"score": "10"})
	assert_eq(_overlay.visible, true)
	_overlay.hide_details()
	assert_eq(_overlay.visible, false)


func test_overlay_null_story():
	_overlay.show_details(null, {})
	assert_eq(_overlay.get_displayed_count(), 0)


func test_overlay_card_shows_value():
	var v = _make_var("score", true, "always", "", "Score du joueur")
	var story = _make_story([v])
	_overlay.show_details(story, {"score": "42"})
	assert_eq(_overlay.get_displayed_count(), 1)
	# La carte contient la description et la valeur comme labels
	var card = _overlay._grid.get_child(0)
	var found_value := false
	for child in card.get_children():
		if child is Label and child.text == "42":
			found_value = true
	assert_true(found_value, "La valeur doit être affichée")


func test_overlay_card_shows_description():
	var v = _make_var("score", true, "always", "", "Score du joueur")
	var story = _make_story([v])
	_overlay.show_details(story, {"score": "10"})
	var card = _overlay._grid.get_child(0)
	var found_desc := false
	for child in card.get_children():
		if child is Label and child.text == "Score du joueur":
			found_desc = true
	assert_true(found_desc, "La description doit être affichée")
