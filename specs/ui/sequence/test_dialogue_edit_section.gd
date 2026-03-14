extends GutTest

## Tests pour DialogueEditSection — section d'édition du dialogue sélectionné.

var DialogueEditSectionScript = load("res://src/ui/sequence/dialogue_edit_section.gd")
var Dialogue = load("res://src/models/dialogue.gd")

var _section: VBoxContainer
var _dialogue


func before_each() -> void:
	_dialogue = Dialogue.new()
	_dialogue.character = "Alice"
	_dialogue.text = "Bonjour le monde"

	_section = VBoxContainer.new()
	_section.set_script(DialogueEditSectionScript)
	add_child_autofree(_section)


# --- load_dialogue ---

func test_load_dialogue_populates_character() -> void:
	_section.load_dialogue(0, _dialogue)
	assert_eq(_section._character_edit.text, "Alice")


func test_load_dialogue_populates_text() -> void:
	_section.load_dialogue(0, _dialogue)
	assert_eq(_section._text_edit.text, "Bonjour le monde")


func test_load_dialogue_sets_header() -> void:
	_section.load_dialogue(2, _dialogue)
	assert_eq(_section._header_label.text, "Dialogue #3")


func test_load_dialogue_makes_fields_editable() -> void:
	_section.load_dialogue(0, _dialogue)
	assert_true(_section._character_edit.editable)
	assert_true(_section._text_edit.editable)


func test_load_dialogue_shows_delete_button() -> void:
	_section.load_dialogue(0, _dialogue)
	assert_true(_section._delete_button.visible)


func test_load_dialogue_stores_index() -> void:
	_section.load_dialogue(5, _dialogue)
	assert_eq(_section._dialogue_index, 5)


func test_load_dialogue_with_null_shows_empty_state() -> void:
	_section.load_dialogue(-1, null)
	assert_eq(_section._character_edit.text, "")
	assert_eq(_section._text_edit.text, "")
	assert_false(_section._character_edit.editable)
	assert_false(_section._text_edit.editable)
	assert_false(_section._delete_button.visible)
	assert_eq(_section._header_label.text, "Aucun dialogue sélectionné")


# --- clear ---

func test_clear_hides_content() -> void:
	_section.load_dialogue(0, _dialogue)
	_section.clear()
	assert_eq(_section._character_edit.text, "")
	assert_eq(_section._text_edit.text, "")
	assert_false(_section._character_edit.editable)
	assert_false(_section._text_edit.editable)
	assert_false(_section._delete_button.visible)


func test_clear_resets_index() -> void:
	_section.load_dialogue(3, _dialogue)
	_section.clear()
	assert_eq(_section._dialogue_index, -1)


# --- character edit signal ---

func test_character_edit_emits_signal() -> void:
	_section.load_dialogue(0, _dialogue)
	watch_signals(_section)
	_section._on_character_changed("Bob")
	assert_signal_emitted_with_parameters(_section, "dialogue_character_changed", [0, "Bob"])


func test_character_edit_not_emitted_during_update() -> void:
	watch_signals(_section)
	# load_dialogue sets _updating = true during execution
	_section.load_dialogue(0, _dialogue)
	assert_signal_not_emitted(_section, "dialogue_character_changed")


func test_character_edit_not_emitted_without_dialogue() -> void:
	watch_signals(_section)
	_section._on_character_changed("Bob")
	assert_signal_not_emitted(_section, "dialogue_character_changed")


# --- text edit signal ---

func test_text_edit_emits_signal() -> void:
	_section.load_dialogue(0, _dialogue)
	watch_signals(_section)
	_section._text_edit.text = "Nouveau texte"
	_section._on_text_changed()
	assert_signal_emitted_with_parameters(_section, "dialogue_text_changed", [0, "Nouveau texte"])


func test_text_edit_not_emitted_during_update() -> void:
	watch_signals(_section)
	_section.load_dialogue(0, _dialogue)
	assert_signal_not_emitted(_section, "dialogue_text_changed")


func test_text_edit_not_emitted_without_dialogue() -> void:
	watch_signals(_section)
	_section._on_text_changed()
	assert_signal_not_emitted(_section, "dialogue_text_changed")


# --- delete signal ---

func test_delete_emits_signal() -> void:
	_section.load_dialogue(2, _dialogue)
	watch_signals(_section)
	_section._on_delete_pressed()
	assert_signal_emitted_with_parameters(_section, "dialogue_delete_requested", [2])


func test_delete_not_emitted_without_dialogue() -> void:
	watch_signals(_section)
	_section._on_delete_pressed()
	assert_signal_not_emitted(_section, "dialogue_delete_requested")


# --- UI elements ---

func test_character_edit_exists() -> void:
	assert_not_null(_section._character_edit)
	assert_eq(_section._character_edit.placeholder_text, "Nom du personnage")


func test_text_edit_exists() -> void:
	assert_not_null(_section._text_edit)
	assert_eq(_section._text_edit.placeholder_text, "Texte du dialogue...")


func test_delete_button_exists() -> void:
	assert_not_null(_section._delete_button)
	assert_eq(_section._delete_button.text, "Supprimer")


func test_header_label_default_text() -> void:
	assert_eq(_section._header_label.text, "Dialogue")


# --- Multiple loads ---

func test_multiple_loads_updates_fields() -> void:
	_section.load_dialogue(0, _dialogue)
	var dialogue2 = Dialogue.new()
	dialogue2.character = "Bob"
	dialogue2.text = "Au revoir"
	_section.load_dialogue(1, dialogue2)
	assert_eq(_section._character_edit.text, "Bob")
	assert_eq(_section._text_edit.text, "Au revoir")
	assert_eq(_section._header_label.text, "Dialogue #2")
