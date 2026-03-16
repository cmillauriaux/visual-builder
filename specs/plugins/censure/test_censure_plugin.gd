extends GutTest

const CensurePluginScript = preload("res://plugins/censure/game_plugin.gd")
const GamePluginContextScript = preload("res://src/plugins/game_plugin_context.gd")


var _plugin: RefCounted


func before_each():
	_plugin = CensurePluginScript.new()


func _create_context() -> RefCounted:
	var ctx = GamePluginContextScript.new()
	ctx.game_node = Control.new()
	add_child(ctx.game_node)
	return ctx


# --- Identity ---

func test_plugin_name():
	assert_eq(_plugin.get_plugin_name(), "censure")


func test_plugin_description_not_empty():
	assert_ne(_plugin.get_plugin_description(), "")


func test_not_configurable():
	assert_false(_plugin.is_configurable())


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


func test_character_unchanged():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "Alice", "merde")
	assert_eq(result["character"], "Alice")
	ctx.game_node.queue_free()


func test_replacement_length_matches_word():
	var ctx = _create_context()
	var result = _plugin.on_before_dialogue(ctx, "", "putain")
	# "putain" = 6 chars → 6 stars
	assert_eq(result["text"], "******")
	ctx.game_node.queue_free()


# --- Toggle ---

func test_disabled_no_replacement():
	var ctx = _create_context()
	_plugin._enabled = false
	var result = _plugin.on_before_dialogue(ctx, "Alice", "merde alors")
	assert_eq(result["text"], "merde alors")
	ctx.game_node.queue_free()


func test_reenable_replacement():
	var ctx = _create_context()
	_plugin._enabled = false
	_plugin._enabled = true
	var result = _plugin.on_before_dialogue(ctx, "Alice", "merde")
	assert_eq(result["text"], "*****")
	ctx.game_node.queue_free()


# --- Bubble ---

func test_overlay_panels_has_top_entry():
	var panels = _plugin.get_overlay_panels()
	assert_eq(panels.size(), 1)
	assert_eq(panels[0].position, "top")


func test_bubble_created_by_panel():
	var ctx = _create_context()
	var panels = _plugin.get_overlay_panels()
	var panel = panels[0].create_panel.call(ctx)
	assert_not_null(panel)
	assert_true(panel is PanelContainer)
	assert_false(panel.visible)
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


# --- Options ---

func test_options_controls_has_entry():
	var ctrls = _plugin.get_options_controls()
	assert_eq(ctrls.size(), 1)


func test_options_creates_control():
	var ctrls = _plugin.get_options_controls()
	var ctrl = ctrls[0].create_control.call(null)
	assert_not_null(ctrl)
	assert_true(ctrl is HBoxContainer)
	ctrl.queue_free()


# --- Static helpers ---

func test_contains_ignore_case():
	assert_true(CensurePluginScript._contains_ignore_case("Hello WORLD", "world"))
	assert_false(CensurePluginScript._contains_ignore_case("Hello", "xyz"))


func test_replace_ignore_case():
	assert_eq(CensurePluginScript._replace_ignore_case("Hello WORLD world", "world", "***"), "Hello *** ***")
