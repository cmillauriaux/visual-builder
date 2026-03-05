extends GutTest

## Tests pour LanguageManagerDialog — gestion des langues.

const LanguageManagerDialogScript = preload("res://src/ui/dialogs/language_manager_dialog.gd")

var _dialog: AcceptDialog


func before_each() -> void:
	_dialog = AcceptDialog.new()
	_dialog.set_script(LanguageManagerDialogScript)
	add_child_autofree(_dialog)


func test_dialog_exists() -> void:
	assert_not_null(_dialog)


func test_title() -> void:
	assert_eq(_dialog.title, "Langues de l'histoire")


func test_ok_button_text() -> void:
	assert_eq(_dialog.ok_button_text, "Fermer")


func test_has_languages_changed_signal() -> void:
	assert_has_signal(_dialog, "languages_changed")


func test_get_languages_default_empty() -> void:
	assert_eq(_dialog.get_languages(), [])


func test_get_default_language() -> void:
	assert_eq(_dialog.get_default_language(), "fr")


func test_add_language_empty_code() -> void:
	var err = _dialog.add_language("")
	assert_ne(err, "")


func test_add_language_valid_code() -> void:
	_dialog._config = {"languages": [], "default": "fr"}
	var err = _dialog.add_language("en")
	assert_eq(err, "")
	assert_true(_dialog.get_languages().has("en"))


func test_add_language_duplicate() -> void:
	_dialog._config = {"languages": ["fr"], "default": "fr"}
	var err = _dialog.add_language("fr")
	assert_ne(err, "")


func test_add_language_invalid_code() -> void:
	_dialog._config = {"languages": [], "default": "fr"}
	var err = _dialog.add_language("123")
	assert_ne(err, "")


func test_add_first_language_becomes_default() -> void:
	_dialog._config = {"languages": [], "default": ""}
	_dialog.add_language("fr")
	assert_eq(_dialog.get_default_language(), "fr")


func test_remove_language() -> void:
	_dialog._config = {"languages": ["fr", "en"], "default": "fr"}
	var err = _dialog.remove_language("en")
	assert_eq(err, "")
	assert_false(_dialog.get_languages().has("en"))


func test_remove_default_language_fails() -> void:
	_dialog._config = {"languages": ["fr", "en"], "default": "fr"}
	var err = _dialog.remove_language("fr")
	assert_ne(err, "")
	assert_true(_dialog.get_languages().has("fr"))


func test_set_default_language() -> void:
	_dialog._config = {"languages": ["fr", "en"], "default": "fr"}
	_dialog.set_default_language("en")
	assert_eq(_dialog.get_default_language(), "en")


func test_is_valid_lang_code_valid() -> void:
	assert_true(_dialog._is_valid_lang_code("fr"))
	assert_true(_dialog._is_valid_lang_code("en"))
	assert_true(_dialog._is_valid_lang_code("zh_TW"))


func test_is_valid_lang_code_invalid() -> void:
	assert_false(_dialog._is_valid_lang_code(""))
	assert_false(_dialog._is_valid_lang_code("a"))
	assert_false(_dialog._is_valid_lang_code("12345"))
