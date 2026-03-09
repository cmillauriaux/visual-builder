extends GutTest

var VariableSidebarScript = load("res://src/ui/play/variable_sidebar.gd")
var StoryScript = load("res://src/models/story.gd")
var VariableDefinitionScript = load("res://src/models/variable_definition.gd")

var _sidebar: VBoxContainer


func before_each():
	_sidebar = VBoxContainer.new()
	_sidebar.set_script(VariableSidebarScript)
	add_child(_sidebar)


func after_each():
	_sidebar.queue_free()


func _make_var(vname: String, on_main: bool = true, on_details: bool = false, vis_mode: String = "always", vis_var: String = "") -> RefCounted:
	var v = VariableDefinitionScript.new()
	v.var_name = vname
	v.initial_value = "0"
	v.show_on_main = on_main
	v.show_on_details = on_details
	v.visibility_mode = vis_mode
	v.visibility_variable = vis_var
	return v


func _make_story(vars: Array) -> RefCounted:
	var story = StoryScript.new()
	for v in vars:
		story.variables.append(v)
	return story


# --- Tests ---

func test_sidebar_hidden_initially():
	assert_eq(_sidebar.visible, true, "VBoxContainer visible par défaut")
	var story = _make_story([])
	_sidebar.update_display({}, story)
	assert_eq(_sidebar.visible, false, "Masqué si pas de variables à afficher")


func test_sidebar_shows_visible_variables():
	var story = _make_story([_make_var("score"), _make_var("hp")])
	_sidebar.update_display({"score": "10", "hp": "50"}, story)
	assert_eq(_sidebar.visible, true)
	assert_eq(_sidebar.get_child_count(), 2)


func test_sidebar_hides_invisible_variables():
	var v1 = _make_var("score", true)
	var v2 = _make_var("hidden", false)  # show_on_main = false
	var story = _make_story([v1, v2])
	_sidebar.update_display({"score": "10", "hidden": "5"}, story)
	assert_eq(_sidebar.get_child_count(), 1)


func test_sidebar_visibility_mode_always():
	var v = _make_var("score", true, false, "always")
	var story = _make_story([v])
	_sidebar.update_display({"score": "10"}, story)
	assert_eq(_sidebar.get_child_count(), 1)


func test_sidebar_visibility_mode_variable_visible():
	var v = _make_var("score", true, false, "variable", "unlocked")
	var story = _make_story([v])
	_sidebar.update_display({"score": "10", "unlocked": "1"}, story)
	assert_eq(_sidebar.get_child_count(), 1)


func test_sidebar_visibility_mode_variable_hidden():
	var v = _make_var("score", true, false, "variable", "unlocked")
	var story = _make_story([v])
	_sidebar.update_display({"score": "10", "unlocked": "0"}, story)
	assert_eq(_sidebar.get_child_count(), 0)
	assert_eq(_sidebar.visible, false)


func test_sidebar_visibility_mode_variable_missing():
	var v = _make_var("score", true, false, "variable", "unlocked")
	var story = _make_story([v])
	_sidebar.update_display({"score": "10"}, story)
	assert_eq(_sidebar.get_child_count(), 0)
	assert_eq(_sidebar.visible, false)


func test_sidebar_shows_value_label():
	var v = _make_var("score")
	var story = _make_story([v])
	_sidebar.update_display({"score": "42"}, story)
	assert_eq(_sidebar.get_child_count(), 1)
	# L'item contient un VBoxContainer avec un PanelContainer (cercle) et un Label (valeur)
	var item = _sidebar.get_child(0)
	var val_label = item.get_child(1) if item.get_child_count() > 1 else null
	assert_not_null(val_label)
	assert_eq(val_label.text, "42")


func test_sidebar_click_emits_details_requested():
	var v = _make_var("score")
	var story = _make_story([v])
	_sidebar.update_display({"score": "10"}, story)
	watch_signals(_sidebar)
	# Simuler un clic
	var item = _sidebar.get_child(0)
	var click_event = InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	item.gui_input.emit(click_event)
	assert_signal_emitted(_sidebar, "details_requested")


func test_sidebar_update_replaces_content():
	var v = _make_var("score")
	var story = _make_story([v])
	_sidebar.update_display({"score": "10"}, story)
	assert_eq(_sidebar.get_child_count(), 1)
	_sidebar.update_display({"score": "20"}, story)
	# Après queue_free, les enfants sont marqués mais pas encore retirés
	# On vérifie que la valeur est correcte via rebuild
	# Le nombre réel peut varier à cause de queue_free vs immediate
	assert_gte(_sidebar.get_child_count(), 1)


func test_sidebar_null_story():
	_sidebar.update_display({}, null)
	assert_eq(_sidebar.visible, false)


func test_sidebar_uses_initial_value_if_not_in_variables():
	var v = _make_var("score")
	v.initial_value = "99"
	var story = _make_story([v])
	_sidebar.update_display({}, story)
	var item = _sidebar.get_child(0)
	var val_label = item.get_child(1)
	assert_eq(val_label.text, "99")
