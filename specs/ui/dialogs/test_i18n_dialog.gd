extends GutTest

## Tests pour I18nDialog — affichage des résultats i18n.

const I18nDialogScript = preload("res://src/ui/dialogs/i18n_dialog.gd")

var _dialog: AcceptDialog


func before_each() -> void:
	_dialog = AcceptDialog.new()
	_dialog.set_script(I18nDialogScript)
	add_child_autofree(_dialog)


func test_dialog_exists() -> void:
	assert_not_null(_dialog)


func test_ok_button_text() -> void:
	assert_eq(_dialog.ok_button_text, "Fermer")


func test_show_regenerate_result_empty() -> void:
	_dialog.show_regenerate_result({})
	assert_eq(_dialog.title, "Regénération des clés i18n")
	assert_gt(_dialog._content.get_child_count(), 0)


func test_show_regenerate_result_with_added_keys() -> void:
	_dialog.show_regenerate_result({"fr": 0, "en": 3})
	assert_eq(_dialog.title, "Regénération des clés i18n")
	assert_gt(_dialog._content.get_child_count(), 0)


func test_show_regenerate_result_all_up_to_date() -> void:
	_dialog.show_regenerate_result({"fr": 0, "en": 0})
	assert_eq(_dialog.title, "Regénération des clés i18n")


func test_show_check_result_empty() -> void:
	_dialog.show_check_result({})
	assert_eq(_dialog.title, "Vérification des traductions")
	assert_gt(_dialog._content.get_child_count(), 0)


func test_show_check_result_with_missing() -> void:
	_dialog.show_check_result({
		"en": {"missing": ["key1", "key2"], "orphans": [], "total": 10, "translated": 8}
	})
	assert_eq(_dialog.title, "Vérification des traductions")


func test_show_check_result_complete() -> void:
	_dialog.show_check_result({
		"en": {"missing": [], "orphans": [], "total": 10, "translated": 10}
	})
	assert_eq(_dialog.title, "Vérification des traductions")


func test_show_check_result_with_orphans() -> void:
	_dialog.show_check_result({
		"de": {"missing": [], "orphans": ["old_key"], "total": 5, "translated": 5}
	})
	assert_eq(_dialog.title, "Vérification des traductions")
