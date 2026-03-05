extends GutTest

## Tests pour la fonctionnalité Quicksave / Quickload (spec 050).

const GameScript = preload("res://src/game.gd")
const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")

var _game: Control


func before_each() -> void:
	GameSaveManager.delete_quicksave()
	_game = Control.new()
	_game.set_script(GameScript)
	add_child(_game)


func after_each() -> void:
	GameSaveManager.delete_quicksave()
	remove_child(_game)
	_game.queue_free()


# --- Boutons UI ---

func test_quicksave_button_exists() -> void:
	assert_not_null(_game._quicksave_button, "quicksave button should be created")
	assert_eq(_game._quicksave_button.text, "Save (F5)")


func test_quickload_button_exists() -> void:
	assert_not_null(_game._quickload_button, "quickload button should be created")
	assert_eq(_game._quickload_button.text, "Load (F9)")


func test_play_buttons_bar_exists() -> void:
	assert_not_null(_game._play_buttons_bar, "play buttons bar should be created")
	assert_true(_game._play_buttons_bar is HBoxContainer)


func test_play_buttons_bar_hidden_by_default() -> void:
	assert_false(_game._play_buttons_bar.visible, "play buttons bar should start hidden")


func test_play_buttons_bar_contains_three_buttons() -> void:
	var buttons := []
	for child in _game._play_buttons_bar.get_children():
		if child is Button:
			buttons.append(child)
	assert_eq(buttons.size(), 3, "bar should contain Save, Load, Auto buttons")


func test_play_buttons_bar_order() -> void:
	var children = _game._play_buttons_bar.get_children()
	assert_eq(children[0], _game._quicksave_button, "Save button should be first")
	assert_eq(children[1], _game._quickload_button, "Load button should be second")
	assert_eq(children[2], _game._auto_play_button, "Auto button should be third")


# --- Toast overlay ---

func test_toast_overlay_exists() -> void:
	assert_not_null(_game._toast_overlay, "toast overlay should be created")
	assert_true(_game._toast_overlay is PanelContainer)


func test_toast_overlay_hidden_by_default() -> void:
	assert_false(_game._toast_overlay.visible, "toast overlay should start hidden")


func test_toast_label_exists() -> void:
	assert_not_null(_game._toast_label, "toast label should be created")
	assert_true(_game._toast_label is Label)


func test_toast_overlay_mouse_filter_ignore() -> void:
	assert_eq(_game._toast_overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_toast_overlay_z_index() -> void:
	assert_eq(_game._toast_overlay.z_index, 100)


# --- Quickload confirmation overlay ---

func test_quickload_confirm_overlay_exists() -> void:
	assert_not_null(_game._quickload_confirm_overlay, "quickload confirm overlay should be created")


func test_quickload_confirm_overlay_hidden_by_default() -> void:
	assert_false(_game._quickload_confirm_overlay.visible, "quickload confirm should start hidden")


func test_quickload_confirm_overlay_process_mode_always() -> void:
	assert_eq(_game._quickload_confirm_overlay.process_mode, Node.PROCESS_MODE_ALWAYS)


func test_quickload_confirm_has_yes_no_buttons() -> void:
	assert_not_null(_game._quickload_yes_btn, "yes button should be created")
	assert_eq(_game._quickload_yes_btn.text, "Oui")
	assert_not_null(_game._quickload_no_btn, "no button should be created")
	assert_eq(_game._quickload_no_btn.text, "Non")


func test_quickload_confirm_label_text() -> void:
	assert_not_null(_game._quickload_confirm_label, "confirm label should be created")
	assert_eq(_game._quickload_confirm_label.text, "Charger la sauvegarde rapide ?")


# --- _can_quicksave guard ---

func test_can_quicksave_false_when_not_playing() -> void:
	# Par défaut, _sequence_editor_ctrl.is_playing() retourne false
	assert_false(_game._can_quicksave())
