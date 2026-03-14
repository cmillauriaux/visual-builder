extends GutTest

## Tests pour DialogueTimelineItem — vignette individuelle dans la timeline.

var DialogueTimelineItemScript = load("res://src/ui/sequence/dialogue_timeline_item.gd")
var Dialogue = load("res://src/models/dialogue.gd")
var Foreground = load("res://src/models/foreground.gd")

var _item: PanelContainer
var _dialogue


func before_each() -> void:
	_dialogue = Dialogue.new()
	_dialogue.character = "Alice"
	_dialogue.text = "Bonjour le monde"


func _create_item(index: int, is_inherited: bool, fg_count: int) -> PanelContainer:
	var item = PanelContainer.new()
	item.set_script(DialogueTimelineItemScript)
	# Match production order: setup() before add_child() (as in dialogue_timeline.gd rebuild())
	# _ready() will then call _apply_style() using the values set by setup()
	item.setup(index, _dialogue, is_inherited, fg_count)
	add_child_autofree(item)
	return item


# --- Setup ---

func test_setup_sets_index() -> void:
	_item = _create_item(3, false, 2)
	assert_eq(_item._dialogue_index, 3)


func test_setup_sets_inherited_state() -> void:
	_item = _create_item(0, true, 1)
	assert_true(_item._is_inherited)


func test_setup_sets_fg_count() -> void:
	_item = _create_item(0, false, 5)
	assert_eq(_item._fg_count, 5)


func test_setup_before_ready_applies_data_in_ready() -> void:
	# setup() is called before add_child(), data is stored and applied in _ready()
	_item = _create_item(0, false, 1)
	assert_eq(_item._character_label.text, "Alice")
	assert_eq(_item._text_label.text, "Bonjour le monde")


func test_setup_after_ready_applies_dialogue_data() -> void:
	# When setup() is called after the item is in the tree, data is applied
	var item = PanelContainer.new()
	item.set_script(DialogueTimelineItemScript)
	add_child_autofree(item)
	item.setup(0, _dialogue, false, 1)
	assert_eq(item._character_label.text, "Alice")
	assert_eq(item._text_label.text, "Bonjour le monde")


func test_setup_after_ready_empty_character_shows_vide() -> void:
	_dialogue.character = ""
	var item = PanelContainer.new()
	item.set_script(DialogueTimelineItemScript)
	add_child_autofree(item)
	item.setup(0, _dialogue, false, 0)
	assert_eq(item._character_label.text, "(vide)")


# --- Inherited badge ---

func test_inherited_item_has_orange_badge_text() -> void:
	_item = _create_item(1, true, 2)
	assert_string_contains(_item._badge_label.text, "hérité")


func test_inherited_item_badge_color_is_orange() -> void:
	_item = _create_item(1, true, 2)
	var badge_color = _item._badge_label.get_theme_color("font_color")
	assert_eq(badge_color, Color("#ffaa00"))


func test_inherited_item_has_reduced_opacity() -> void:
	_item = _create_item(0, true, 1)
	assert_almost_eq(_item.modulate.a, 0.65, 0.01)


# --- Non-inherited badge ---

func test_non_inherited_item_shows_fg_count() -> void:
	_item = _create_item(0, false, 3)
	assert_eq(_item._badge_label.text, "3 FG")


func test_non_inherited_item_shows_zero_fg_count() -> void:
	_item = _create_item(0, false, 0)
	assert_eq(_item._badge_label.text, "0 FG")


func test_non_inherited_item_badge_color_is_blue() -> void:
	_item = _create_item(0, false, 2)
	var badge_color = _item._badge_label.get_theme_color("font_color")
	assert_eq(badge_color, Color(0.29, 0.29, 1.0))


func test_non_inherited_item_has_full_opacity() -> void:
	_item = _create_item(0, false, 1)
	assert_almost_eq(_item.modulate.a, 1.0, 0.01)


# --- Selection ---

func test_set_selected_true_changes_visual_state() -> void:
	_item = _create_item(0, false, 1)
	_item.set_selected(true)
	assert_true(_item._selected)
	# Should have a stylebox override when selected
	assert_not_null(_item.get_theme_stylebox("panel"))


func test_set_selected_false_clears_visual_state() -> void:
	_item = _create_item(0, false, 1)
	_item.set_selected(true)
	_item.set_selected(false)
	assert_false(_item._selected)


func test_selected_item_has_blue_character_color() -> void:
	_item = _create_item(0, false, 1)
	_item.set_selected(true)
	var color = _item._character_label.get_theme_color("font_color")
	assert_eq(color, Color(0.29, 0.29, 1.0))


# --- get_dialogue_index ---

func test_get_dialogue_index_returns_correct_index() -> void:
	_item = _create_item(7, false, 0)
	assert_eq(_item.get_dialogue_index(), 7)


func test_get_dialogue_index_returns_default_without_setup() -> void:
	var item = PanelContainer.new()
	item.set_script(DialogueTimelineItemScript)
	add_child_autofree(item)
	assert_eq(item.get_dialogue_index(), -1)


# --- Signals ---

func test_item_clicked_signal_emitted() -> void:
	_item = _create_item(2, false, 0)
	watch_signals(_item)
	_item.item_clicked.emit(2)
	assert_signal_emitted_with_parameters(_item, "item_clicked", [2])


# --- Minimum size ---

func test_minimum_width() -> void:
	_item = _create_item(0, false, 0)
	assert_eq(_item.custom_minimum_size.x, 110.0)
