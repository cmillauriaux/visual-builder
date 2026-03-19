extends GutTest

# Tests pour ExportDialog (dialogue d'export en jeu standalone)

var ExportDialogScript = load("res://src/ui/dialogs/export_dialog.gd")
var Story = load("res://src/models/story.gd")

var _dialog: ConfirmationDialog


func before_each():
	_dialog = ConfirmationDialog.new()
	_dialog.set_script(ExportDialogScript)
	add_child_autofree(_dialog)


# --- Structure ---

func test_dialog_is_confirmation_dialog():
	assert_true(_dialog is ConfirmationDialog)


func test_dialog_has_title():
	assert_eq(_dialog.title, tr("Exporter le jeu"))


func test_dialog_has_platform_dropdown():
	assert_not_null(_dialog._platform_dropdown)
	assert_true(_dialog._platform_dropdown is OptionButton)


func test_dialog_shows_all_platforms():
	var dd = _dialog._platform_dropdown
	assert_eq(dd.item_count, 5)
	assert_eq(dd.get_item_text(0), "Web (HTML5)")
	assert_eq(dd.get_item_text(1), "macOS")
	assert_eq(dd.get_item_text(2), "Linux")
	assert_eq(dd.get_item_text(3), "Windows")
	assert_eq(dd.get_item_text(4), "Android")


func test_dialog_has_path_edit():
	assert_not_null(_dialog._path_edit)
	assert_true(_dialog._path_edit is LineEdit)


func test_dialog_has_browse_button():
	assert_not_null(_dialog._browse_button)
	assert_eq(_dialog._browse_button.text, tr("Parcourir..."))


func test_dialog_has_status_label():
	assert_not_null(_dialog._status_label)


# --- Setup ---

func test_export_button_disabled_without_story():
	_dialog.setup(null)
	assert_true(_dialog.get_ok_button().disabled)


func test_status_shows_warning_without_story():
	_dialog.setup(null)
	assert_eq(_dialog._status_label.text, tr("Aucune histoire chargée"))


func test_export_button_disabled_without_path():
	var story = Story.new()
	story.title = "Test"
	_dialog.setup(story)
	assert_true(_dialog.get_ok_button().disabled)


func test_export_button_enabled_with_path():
	var story = Story.new()
	story.title = "Test"
	_dialog._path_edit.text = "/tmp/export"
	_dialog.setup(story)
	assert_false(_dialog.get_ok_button().disabled)


func test_status_empty_with_story():
	var story = Story.new()
	story.title = "Test"
	_dialog.setup(story)
	assert_eq(_dialog._status_label.text, "")


# --- Plateforme ---

func test_default_platform_is_web():
	assert_eq(_dialog.get_selected_platform(), "web")


func test_select_macos():
	_dialog._platform_dropdown.selected = 1
	assert_eq(_dialog.get_selected_platform(), "macos")


func test_select_linux():
	_dialog._platform_dropdown.selected = 2
	assert_eq(_dialog.get_selected_platform(), "linux")


func test_select_windows():
	_dialog._platform_dropdown.selected = 3
	assert_eq(_dialog.get_selected_platform(), "windows")


func test_select_android():
	_dialog._platform_dropdown.selected = 4
	assert_eq(_dialog.get_selected_platform(), "android")


# --- Chemin de sortie ---

func test_output_path_empty_by_default():
	assert_eq(_dialog.get_output_path(), "")


func test_output_path_returns_entered_value():
	_dialog._path_edit.text = "/Users/test/build"
	assert_eq(_dialog.get_output_path(), "/Users/test/build")


func test_typing_path_enables_export():
	var story = Story.new()
	story.title = "Test"
	_dialog.setup(story)
	_dialog._path_edit.text = "/tmp"
	_dialog._on_path_changed("/tmp")
	assert_false(_dialog.get_ok_button().disabled)


func test_clearing_path_disables_export():
	var story = Story.new()
	story.title = "Test"
	_dialog._path_edit.text = "/tmp"
	_dialog.setup(story)
	_dialog._path_edit.text = ""
	_dialog._on_path_changed("")
	assert_true(_dialog.get_ok_button().disabled)


# --- Signal ---

func test_export_requested_signal_exists():
	assert_has_signal(_dialog, "export_requested")
