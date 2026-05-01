extends GutTest

const CensurePluginScript = preload("res://plugins/censure/game_plugin.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")
const StoryScript = preload("res://src/models/story.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const DialogueScript = preload("res://src/models/dialogue.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")


var _plugin: RefCounted


func before_each():
	_plugin = CensurePluginScript.new()


func _create_context() -> RefCounted:
	var ctx = GamePluginContextScript.new()
	var game_node_script := GDScript.new()
	game_node_script.source_code = "extends Control\nvar _visual_editor = null\n"
	game_node_script.reload()
	ctx.game_node = Control.new()
	ctx.game_node.set_script(game_node_script)
	add_child(ctx.game_node)
	return ctx


func _create_context_with_story() -> RefCounted:
	var ctx = _create_context()
	ctx.story = StoryScript.new()
	ctx.story.itchio_url = "https://game.itch.io/test"
	ctx.story.patreon_url = "https://patreon.com/test"
	return ctx


func _create_context_with_censored_foreground() -> RefCounted:
	var ctx = _create_context()
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	var fg = ForegroundScript.new()
	fg.censored = true
	dlg.foregrounds.append(fg)
	seq.dialogues.append(dlg)
	ctx.current_sequence = seq
	ctx.current_dialogue_index = 0
	return ctx


# --- Identity ---

func test_plugin_name():
	assert_eq(_plugin.get_plugin_name(), "censure")


func test_plugin_description_not_empty():
	assert_ne(_plugin.get_plugin_description(), "")


func test_not_configurable():
	assert_false(_plugin.is_configurable())


func test_get_plugin_folder():
	assert_eq(_plugin.get_plugin_folder(), "censure")


func test_get_export_options_returns_one_option():
	var options = _plugin.get_export_options()
	assert_eq(options.size(), 1)
	assert_eq(options[0].key, "censure_enabled")
	assert_eq(options[0].label, "Inclure la censure")
	assert_false(options[0].default_value)


# --- Dialogue censorship ---

func test_replaces_banned_word():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "Quelle merde !")
	assert_eq(result["character"], "Alice")
	assert_eq(result["text"], "Quelle ***** !")
	ctx.game_node.queue_free()


func test_replaces_multiple_words():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Bob", "Putain de merde")
	assert_false(result["text"].to_lower().contains("putain"))
	assert_false(result["text"].to_lower().contains("merde"))
	ctx.game_node.queue_free()


func test_case_insensitive_replacement():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "MERDE alors")
	assert_eq(result["text"], "***** alors")
	ctx.game_node.queue_free()


func test_no_replacement_clean_text():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "Bonjour le monde")
	assert_eq(result["text"], "Bonjour le monde")
	ctx.game_node.queue_free()


func test_no_replacement_partial_word():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "La connière est belle")
	assert_eq(result["text"], "La connière est belle")
	ctx.game_node.queue_free()


func test_no_replacement_word_prefix():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "Le concert était bien")
	assert_eq(result["text"], "Le concert était bien")
	ctx.game_node.queue_free()


func test_replacement_whole_word_with_punctuation():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "Quel con!")
	assert_eq(result["text"], "Quel ***!")
	ctx.game_node.queue_free()


func test_character_unchanged():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "merde")
	assert_eq(result["character"], "Alice")
	ctx.game_node.queue_free()


func test_replacement_length_matches_word():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "", "putain")
	assert_eq(result["text"], "******")
	ctx.game_node.queue_free()

func test_marks_dialogue_censored_when_foreground_is_censored():
	var ctx = _create_context_with_censored_foreground()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "Bonjour")
	assert_eq(result["text"], "Bonjour")
	assert_true(_plugin._censored_this_dialogue)
	ctx.game_node.queue_free()


# --- Bubble ---

func test_overlay_panels_has_left_entry():
	var panels = _plugin.get_overlay_panels()
	assert_eq(panels.size(), 1)
	assert_eq(panels[0].position, "left")


func test_bubble_created_by_panel():
	var ctx = _create_context()
	var panels = _plugin.get_overlay_panels()
	var panel = panels[0].create_panel.call(ctx)
	assert_not_null(panel)
	assert_true(panel is PanelContainer)
	assert_false(panel.visible)
	assert_true(panel.get_child(0) is VBoxContainer)
	var link_btn = panel.get_child(0).get_child(1)
	assert_eq(link_btn.text, "Uncensored this ?")
	panel.queue_free()
	ctx.game_node.queue_free()


func test_bubble_shown_after_censored_dialogue():
	var ctx = _create_context()
	# Create the bubble panel first
	var panels = _plugin.get_overlay_panels()
	var panel = panels[0].create_panel.call(ctx)
	ctx.game_node.add_child(panel)
	# Now trigger a censored dialogue
	_plugin.on_before_dialogue(ctx, "Alice", "Quelle merde")
	_plugin.on_after_dialogue(ctx, "Alice", "Quelle *****")
	assert_true(panel.visible)
	panel.queue_free()
	ctx.game_node.queue_free()


func test_bubble_not_shown_for_clean_dialogue():
	var ctx = _create_context()
	var panels = _plugin.get_overlay_panels()
	var panel = panels[0].create_panel.call(ctx)
	ctx.game_node.add_child(panel)
	_plugin.on_before_dialogue(ctx, "Alice", "Bonjour")
	_plugin.on_after_dialogue(ctx, "Alice", "Bonjour")
	assert_false(panel.visible)
	panel.queue_free()
	ctx.game_node.queue_free()


func test_bubble_hidden_again_on_next_clean_dialogue():
	var ctx = _create_context()
	var panels = _plugin.get_overlay_panels()
	var panel = panels[0].create_panel.call(ctx)
	ctx.game_node.add_child(panel)
	_plugin.on_before_dialogue(ctx, "Alice", "Quelle merde")
	_plugin.on_after_dialogue(ctx, "Alice", "Quelle *****")
	assert_true(panel.visible)
	_plugin.on_before_dialogue(ctx, "Alice", "Bonjour")
	_plugin.on_after_dialogue(ctx, "Alice", "Bonjour")
	assert_false(panel.visible)
	panel.queue_free()
	ctx.game_node.queue_free()

func test_show_uncensored_popup_creates_overlay():
	var ctx = _create_context_with_story()
	_plugin._show_uncensored_popup(ctx)
	assert_not_null(_plugin._uncensored_popup)
	assert_true(is_instance_valid(_plugin._uncensored_popup))
	assert_eq(_plugin._uncensored_popup.get_child_count(), 1)
	ctx.game_node.queue_free()


func test_uncensored_message_prefers_both_links_when_available():
	var ctx = _create_context_with_story()
	assert_eq(
		_plugin._get_uncensored_message(ctx),
		"Rendez-vous sur itch.io ou Patreon pour obtenir la version non censurée."
	)
	ctx.game_node.queue_free()


func test_on_game_ready_enables_censored_foregrounds_in_visual_editor():
	var ctx = _create_context()
	var visual_script := GDScript.new()
	visual_script.source_code = "extends RefCounted\nvar show_censored_foregrounds = false\n"
	visual_script.reload()
	var fake_visual_editor = visual_script.new()
	ctx.game_node._visual_editor = fake_visual_editor
	_plugin.on_game_ready(ctx)
	assert_true(fake_visual_editor.show_censored_foregrounds)
	ctx.game_node.queue_free()


func test_on_before_sequence_enables_censored_foregrounds_in_visual_editor():
	var ctx = _create_context()
	var visual_script := GDScript.new()
	visual_script.source_code = "extends RefCounted\nvar show_censored_foregrounds = false\n"
	visual_script.reload()
	var fake_visual_editor = visual_script.new()
	ctx.game_node._visual_editor = fake_visual_editor
	_plugin.on_before_sequence(ctx)
	assert_true(fake_visual_editor.show_censored_foregrounds)
	ctx.game_node.queue_free()


# --- Static helpers ---

func test_contains_ignore_case():
	assert_true(CensurePluginScript._contains_ignore_case("Hello WORLD", "world"))
	assert_false(CensurePluginScript._contains_ignore_case("Hello", "xyz"))


func test_contains_ignore_case_whole_word_only():
	assert_false(CensurePluginScript._contains_ignore_case("connière", "con"))
	assert_true(CensurePluginScript._contains_ignore_case("quel con !", "con"))
	assert_false(CensurePluginScript._contains_ignore_case("concert", "con"))


func test_replace_ignore_case():
	assert_eq(CensurePluginScript._replace_ignore_case("Hello WORLD world", "world", "***"), "Hello *** ***")


func test_replace_ignore_case_whole_word_only():
	assert_eq(CensurePluginScript._replace_ignore_case("connière et con", "con", "***"), "connière et ***")
