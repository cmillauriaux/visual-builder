extends GutTest

# Tests pour la validation du dialogue de renommage (bouton OK désactivé si titre vide)

const RenameDialogScript = preload("res://src/ui/dialogs/rename_dialog.gd")

var _dialog: ConfirmationDialog = null

func before_each():
	_dialog = ConfirmationDialog.new()
	_dialog.set_script(RenameDialogScript)
	add_child_autofree(_dialog)

func test_ok_button_disabled_when_title_empty():
	_dialog.setup("uuid-001", "", "description")
	assert_true(_dialog.get_ok_button().disabled, "Le bouton OK doit être désactivé quand le titre est vide")

func test_ok_button_enabled_when_title_not_empty():
	_dialog.setup("uuid-001", "Mon titre", "description")
	assert_false(_dialog.get_ok_button().disabled, "Le bouton OK doit être activé quand le titre n'est pas vide")

func test_ok_button_updates_on_text_changed():
	_dialog.setup("uuid-001", "Mon titre", "")
	# Simuler la suppression du texte
	_dialog._name_edit.text = ""
	_dialog._name_edit.text_changed.emit("")
	assert_true(_dialog.get_ok_button().disabled, "Le bouton OK doit se désactiver quand le titre devient vide")

func test_ok_button_reenables_on_text_changed():
	_dialog.setup("uuid-001", "", "")
	assert_true(_dialog.get_ok_button().disabled)
	# Simuler la saisie de texte
	_dialog._name_edit.text = "Nouveau titre"
	_dialog._name_edit.text_changed.emit("Nouveau titre")
	assert_false(_dialog.get_ok_button().disabled, "Le bouton OK doit se réactiver quand le titre n'est plus vide")

func test_ok_button_disabled_with_whitespace_only():
	_dialog.setup("uuid-001", "   ", "description")
	assert_true(_dialog.get_ok_button().disabled, "Le bouton OK doit être désactivé avec un titre contenant uniquement des espaces")
