extends GutTest

# Tests pour le dialogue de renommage

var RenameDialogScript = load("res://src/ui/dialogs/rename_dialog.gd")

var _dialog: ConfirmationDialog = null

func before_each():
	_dialog = ConfirmationDialog.new()
	_dialog.set_script(RenameDialogScript)
	add_child_autofree(_dialog)

func test_setup():
	_dialog.setup("uuid-001", "Chapitre 1", "La forêt maudite")
	assert_eq(_dialog.get_uuid(), "uuid-001")
	assert_eq(_dialog.get_new_name(), "Chapitre 1")
	assert_eq(_dialog.get_new_subtitle(), "La forêt maudite")

func test_setup_empty_subtitle():
	_dialog.setup("uuid-002", "Scène 1", "")
	assert_eq(_dialog.get_new_name(), "Scène 1")
	assert_eq(_dialog.get_new_subtitle(), "")

func test_has_name_edit():
	assert_true(_dialog.has_node("ContentVBox/NameEdit"), "Le champ de nom doit exister")

func test_has_subtitle_edit():
	assert_true(_dialog.has_node("ContentVBox/SubtitleEdit"), "Le champ de sous-titre doit exister")

func test_rename_confirmed_signal():
	_dialog.setup("uuid-001", "Chapitre 1", "Description")
	watch_signals(_dialog)
	_dialog._on_confirmed()
	assert_signal_emitted(_dialog, "rename_confirmed")

func test_title_is_renommer():
	assert_eq(_dialog.title, "Renommer")
