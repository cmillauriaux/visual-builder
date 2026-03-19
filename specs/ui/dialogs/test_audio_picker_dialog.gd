extends GutTest

## Tests pour AudioPickerDialog — sélection de fichiers audio.

var AudioPickerDialogScript = load("res://src/ui/dialogs/audio_picker_dialog.gd")

var _dialog: Window


func before_each() -> void:
	_dialog = Window.new()
	_dialog.set_script(AudioPickerDialogScript)
	add_child_autofree(_dialog)


func test_dialog_exists() -> void:
	assert_not_null(_dialog)


func test_default_title() -> void:
	assert_eq(_dialog.title, tr("Sélectionner un fichier audio"))


func test_setup_music_mode() -> void:
	_dialog.setup(AudioPickerDialogScript.Mode.MUSIC, "")
	assert_eq(_dialog.title, tr("Sélectionner une musique"))
	assert_eq(_dialog._mode, AudioPickerDialogScript.Mode.MUSIC)


func test_setup_fx_mode() -> void:
	_dialog.setup(AudioPickerDialogScript.Mode.FX, "")
	assert_eq(_dialog.title, tr("Sélectionner un FX audio"))
	assert_eq(_dialog._mode, AudioPickerDialogScript.Mode.FX)


func test_validate_button_disabled_by_default() -> void:
	assert_true(_dialog._validate_btn.disabled)


func test_reset_selection_clears_path() -> void:
	_dialog._selected_path = "/some/path.ogg"
	_dialog._reset_selection()
	assert_eq(_dialog._selected_path, "")
	assert_true(_dialog._validate_btn.disabled)


func test_no_story_label_hidden_with_path() -> void:
	_dialog.setup(AudioPickerDialogScript.Mode.MUSIC, "/some/story")
	assert_false(_dialog._no_story_label.visible)


func test_no_story_label_visible_without_path() -> void:
	_dialog.setup(AudioPickerDialogScript.Mode.MUSIC, "")
	assert_true(_dialog._no_story_label.visible)


func test_get_assets_dir_music() -> void:
	_dialog._mode = AudioPickerDialogScript.Mode.MUSIC
	_dialog._story_base_path = "/stories/test"
	assert_eq(_dialog._get_assets_dir(), "/stories/test/assets/music")


func test_get_assets_dir_fx() -> void:
	_dialog._mode = AudioPickerDialogScript.Mode.FX
	_dialog._story_base_path = "/stories/test"
	assert_eq(_dialog._get_assets_dir(), "/stories/test/assets/fx")


func test_resolve_unique_path_no_conflict() -> void:
	var result = AudioPickerDialogScript._resolve_unique_path("/nonexistent_dir_xyz", "test.ogg")
	assert_eq(result, "/nonexistent_dir_xyz/test.ogg")


func test_tab_container_has_two_tabs() -> void:
	assert_eq(_dialog._tab_container.get_tab_count(), 2)
