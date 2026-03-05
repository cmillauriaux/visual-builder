extends GutTest

const VariablePanelScript = preload("res://src/ui/editors/variable_panel.gd")
const StoryScript = preload("res://src/models/story.gd")
const VariableDefinitionScript = preload("res://src/models/variable_definition.gd")

var _panel: VBoxContainer


func before_each():
	_panel = VBoxContainer.new()
	# Créer la structure de nœuds attendue par @onready
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	_panel.add_child(scroll)
	var vars_list = VBoxContainer.new()
	vars_list.name = "VarsList"
	scroll.add_child(vars_list)
	var add_btn = Button.new()
	add_btn.name = "AddBtn"
	_panel.add_child(add_btn)
	_panel.set_script(VariablePanelScript)
	add_child(_panel)


func after_each():
	_panel.queue_free()


func _make_story_with_var(vname: String = "score", val: String = "0"):
	var story = StoryScript.new()
	var v = VariableDefinitionScript.new()
	v.var_name = vname
	v.initial_value = val
	story.variables.append(v)
	return story


# --- Affichage des checkboxes ---

func test_panel_shows_display_checkboxes():
	var story = _make_story_with_var()
	_panel.load_story(story)
	# Le bloc de la variable doit contenir des CheckBox
	var block = _panel._vars_list.get_child(0)
	assert_not_null(block)
	var checkboxes = _find_children_of_type(block, "CheckBox")
	assert_gte(checkboxes.size(), 2, "Au moins 2 checkboxes (main + details)")


func test_checkbox_updates_model_show_on_main():
	var story = _make_story_with_var()
	_panel.load_story(story)
	assert_eq(story.variables[0].show_on_main, false)
	_panel.update_show_on_main(0, true)
	assert_eq(story.variables[0].show_on_main, true)


func test_checkbox_updates_model_show_on_details():
	var story = _make_story_with_var()
	_panel.load_story(story)
	assert_eq(story.variables[0].show_on_details, false)
	_panel.update_show_on_details(0, true)
	assert_eq(story.variables[0].show_on_details, true)


# --- Mode de visibilité ---

func test_visibility_mode_updates_model():
	var story = _make_story_with_var()
	_panel.load_story(story)
	assert_eq(story.variables[0].visibility_mode, "always")
	_panel.update_visibility_mode(0, "variable")
	assert_eq(story.variables[0].visibility_mode, "variable")


func test_visibility_variable_updates_model():
	var story = _make_story_with_var()
	_panel.load_story(story)
	_panel.update_visibility_variable(0, "has_key")
	assert_eq(story.variables[0].visibility_variable, "has_key")


# --- Image ---

func test_image_updates_model():
	var story = _make_story_with_var()
	_panel.load_story(story)
	_panel.update_image(0, "assets/foregrounds/coin.png")
	assert_eq(story.variables[0].image, "assets/foregrounds/coin.png")


# --- Description ---

func test_description_updates_model():
	var story = _make_story_with_var()
	_panel.load_story(story)
	_panel.update_description(0, "Votre score actuel")
	assert_eq(story.variables[0].description, "Votre score actuel")


# --- Signal ---

func test_signal_emitted_on_display_change():
	var story = _make_story_with_var()
	_panel.load_story(story)
	watch_signals(_panel)
	_panel.update_show_on_main(0, true)
	assert_signal_emitted(_panel, "variables_changed")


func test_signal_emitted_on_description_change():
	var story = _make_story_with_var()
	_panel.load_story(story)
	watch_signals(_panel)
	_panel.update_description(0, "Test")
	assert_signal_emitted(_panel, "variables_changed")


# --- Rétrocompatibilité ---

func test_panel_loads_variable_with_display_fields():
	var story = StoryScript.new()
	var v = VariableDefinitionScript.new()
	v.var_name = "score"
	v.show_on_main = true
	v.show_on_details = true
	v.visibility_mode = "variable"
	v.visibility_variable = "unlocked"
	v.image = "assets/foregrounds/coin.png"
	v.description = "Le score"
	story.variables.append(v)
	_panel.load_story(story)
	assert_eq(_panel.get_variable_count(), 1)


# --- Invalid index ---

func test_update_display_invalid_index():
	var story = _make_story_with_var()
	_panel.load_story(story)
	# These should not crash
	_panel.update_show_on_main(-1, true)
	_panel.update_show_on_main(99, true)
	_panel.update_show_on_details(-1, true)
	_panel.update_visibility_mode(-1, "variable")
	_panel.update_visibility_variable(-1, "x")
	_panel.update_image(-1, "x")
	_panel.update_description(-1, "x")
	assert_eq(story.variables[0].show_on_main, false)


# --- Helpers ---

func _find_children_of_type(node: Node, type_name: String) -> Array:
	var result := []
	for child in node.get_children():
		if child.get_class() == type_name:
			result.append(child)
		result.append_array(_find_children_of_type(child, type_name))
	return result
