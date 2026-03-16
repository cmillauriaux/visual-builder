extends GutTest

const SaveLoadMenuScript = preload("res://src/ui/menu/save_load_menu.gd")
const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")

var _menu: Control
var _test_slot := 5

func before_each():
	_cleanup_all_autosaves()
	GameSaveManager.delete_save(_test_slot)
	GameSaveManager.delete_quicksave()
	_menu = Control.new()
	_menu.set_script(SaveLoadMenuScript)
	_menu.build_ui()
	add_child_autofree(_menu)

func after_each():
	GameSaveManager.delete_save(_test_slot)
	GameSaveManager.delete_quicksave()
	_cleanup_all_autosaves()

func _cleanup_all_autosaves() -> void:
	for i in range(GameSaveManager.NUM_AUTOSAVE_SLOTS):
		var path := GameSaveManager.get_autosave_save_path(i)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var idx := GameSaveManager.AUTOSAVE_INDEX_PATH
	if FileAccess.file_exists(idx):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(idx))


# --- build_ui ---

func test_build_ui():
	assert_not_null(_menu._tab_container)
	assert_not_null(_menu._grid)
	assert_false(_menu.visible)

func test_has_three_tabs():
	assert_eq(_menu._tab_container.get_tab_count(), 3)

func test_confirm_overlay_hidden_by_default():
	assert_false(_menu._confirm_overlay.visible)


# --- show_as_save_mode / load_mode ---

func test_show_as_save_mode():
	_menu.show_as_save_mode()
	assert_true(_menu.visible)
	assert_eq(_menu._mode, _menu.Mode.SAVE)
	assert_eq(_menu.get_title_text(), "Sauvegarder")
	assert_false(_menu._tab_container.tabs_visible)

func test_show_as_load_mode():
	_menu.show_as_load_mode()
	assert_true(_menu.visible)
	assert_eq(_menu._mode, _menu.Mode.LOAD)
	assert_eq(_menu.get_title_text(), "Charger")
	assert_true(_menu._tab_container.tabs_visible)

func test_hide_menu():
	_menu.show_as_save_mode()
	_menu.hide_menu()
	assert_false(_menu.visible)
	assert_false(_menu._confirm_overlay.visible)


# --- refresh / _refresh_manual_saves (slots vides) ---

func test_refresh_manual_saves_empty_builds_num_slots_cards():
	# Pas de sauvegardes → NUM_SLOTS cartes "vides"
	_menu.show_as_load_mode()
	assert_eq(_menu._grid.get_child_count(), GameSaveManager.NUM_SLOTS)

func test_empty_slot_card_has_empty_label():
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(0)
	var empty_lbl = card.find_child("EmptyLabel", true, false)
	assert_not_null(empty_lbl, "Slot vide doit avoir un EmptyLabel")
	assert_eq(empty_lbl.text, "+ Vide")

func test_empty_slot_card_in_save_mode_has_save_button():
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(0)
	var btn = card.find_child("SaveButton", true, false)
	assert_not_null(btn, "Slot vide en mode SAVE doit avoir SaveButton")
	assert_eq(btn.text, "Sauvegarder ici")

func test_empty_slot_card_in_load_mode_has_no_save_button():
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(0)
	var btn = card.find_child("SaveButton", true, false)
	assert_null(btn, "Slot vide en mode LOAD ne doit pas avoir de SaveButton")


# --- _build_slot_card avec données (has_data=true) ---

func test_occupied_slot_card_in_load_mode_has_load_and_delete_buttons():
	GameSaveManager.save_game_state(_test_slot, {
		"chapter_name": "Ch Test",
		"scene_name": "Sc Test",
		"story_path": ""
	}, null)
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(_test_slot)
	var load_btn = card.find_child("LoadButton", true, false)
	var del_btn = card.find_child("DeleteButton", true, false)
	assert_not_null(load_btn, "Slot occupé en LOAD doit avoir un bouton Charger")
	assert_not_null(del_btn, "Slot occupé en LOAD doit avoir un bouton Supprimer")

func test_occupied_slot_card_shows_chapter_and_scene():
	GameSaveManager.save_game_state(_test_slot, {
		"chapter_name": "Mon Chapitre",
		"scene_name": "Ma Scène",
		"story_path": ""
	}, null)
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(_test_slot)
	var chap_lbl = card.find_child("ChapterLabel", true, false)
	var scene_lbl = card.find_child("SceneLabel", true, false)
	assert_not_null(chap_lbl)
	assert_eq(chap_lbl.text, "Mon Chapitre")
	assert_not_null(scene_lbl)
	assert_eq(scene_lbl.text, "Ma Scène")

func test_occupied_slot_card_in_save_mode_has_overwrite_button():
	GameSaveManager.save_game_state(_test_slot, {"chapter_name": "X", "story_path": ""}, null)
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(_test_slot)
	# En mode SAVE sur slot occupé → bouton "Écraser"
	var overwrite_btn: Button = null
	for child in card.find_children("*", "Button", true, false):
		if child.text == "Écraser":
			overwrite_btn = child
			break
	assert_not_null(overwrite_btn, "Slot occupé en SAVE doit avoir bouton Écraser")


# --- _show_confirm_dialog ---

func test_show_confirm_dialog_makes_overlay_visible():
	GameSaveManager.save_game_state(_test_slot, {"chapter_name": "X", "story_path": ""}, null)
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(_test_slot)
	var overwrite_btn: Button = null
	for child in card.find_children("*", "Button", true, false):
		if child.text == "Écraser":
			overwrite_btn = child
			break
	assert_not_null(overwrite_btn)
	overwrite_btn.pressed.emit()
	assert_true(_menu._confirm_overlay.visible, "L'overlay de confirmation doit être visible")

func test_confirm_dialog_has_yes_and_no_buttons():
	GameSaveManager.save_game_state(_test_slot, {"chapter_name": "X", "story_path": ""}, null)
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(_test_slot)
	var overwrite_btn: Button = null
	for child in card.find_children("*", "Button", true, false):
		if child.text == "Écraser":
			overwrite_btn = child
			break
	overwrite_btn.pressed.emit()
	var yes_btn = _menu._confirm_overlay.find_child("ConfirmYesButton", true, false)
	var no_btn = _menu._confirm_overlay.find_child("ConfirmNoButton", true, false)
	assert_not_null(yes_btn)
	assert_not_null(no_btn)

func test_confirm_no_button_hides_overlay():
	GameSaveManager.save_game_state(_test_slot, {"chapter_name": "X", "story_path": ""}, null)
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(_test_slot)
	var overwrite_btn: Button = null
	for child in card.find_children("*", "Button", true, false):
		if child.text == "Écraser":
			overwrite_btn = child
			break
	overwrite_btn.pressed.emit()
	assert_true(_menu._confirm_overlay.visible)
	var no_btn = _menu._confirm_overlay.find_child("ConfirmNoButton", true, false)
	no_btn.pressed.emit()
	assert_false(_menu._confirm_overlay.visible)


# --- Signaux ---

func test_close_button_emits_close_pressed():
	watch_signals(_menu)
	_menu._close_btn.pressed.emit()
	assert_signal_emitted(_menu, "close_pressed")

func test_save_slot_pressed_signal_on_empty_slot():
	watch_signals(_menu)
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(0)
	var save_btn = card.find_child("SaveButton", true, false)
	assert_not_null(save_btn)
	save_btn.pressed.emit()
	assert_signal_emitted(_menu, "save_slot_pressed")
	assert_eq(get_signal_parameters(_menu, "save_slot_pressed")[0], 0)

func test_load_slot_pressed_signal():
	GameSaveManager.save_game_state(_test_slot, {"story_path": ""}, null)
	watch_signals(_menu)
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(_test_slot)
	var load_btn = card.find_child("LoadButton", true, false)
	assert_not_null(load_btn)
	load_btn.pressed.emit()
	assert_signal_emitted(_menu, "load_slot_pressed")
	assert_eq(get_signal_parameters(_menu, "load_slot_pressed")[0], _test_slot)

func test_delete_slot_pressed_signal():
	GameSaveManager.save_game_state(_test_slot, {"story_path": ""}, null)
	watch_signals(_menu)
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(_test_slot)
	var del_btn = card.find_child("DeleteButton", true, false)
	assert_not_null(del_btn)
	del_btn.pressed.emit()
	assert_signal_emitted(_menu, "delete_slot_pressed")

func test_confirm_overwrite_emits_save_slot_pressed():
	GameSaveManager.save_game_state(_test_slot, {"chapter_name": "X", "story_path": ""}, null)
	watch_signals(_menu)
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(_test_slot)
	var overwrite_btn: Button = null
	for child in card.find_children("*", "Button", true, false):
		if child.text == "Écraser":
			overwrite_btn = child
			break
	overwrite_btn.pressed.emit()
	var yes_btn = _menu._confirm_overlay.find_child("ConfirmYesButton", true, false)
	yes_btn.pressed.emit()
	assert_signal_emitted(_menu, "save_slot_pressed")
	assert_false(_menu._confirm_overlay.visible)


# --- _refresh_auto_saves (aucune autosave) ---

func test_refresh_auto_saves_empty_shows_label():
	# Sans autosaves → affiche le label "Aucune sauvegarde automatique"
	_menu.show_as_load_mode()
	var auto_content = _menu._auto_content
	assert_gt(auto_content.get_child_count(), 0)
	var lbl = auto_content.get_child(0)
	assert_true(lbl is Label)
	assert_true(lbl.text.contains("Aucune"), "Doit afficher le message vide")


# --- _refresh_quick_saves (aucune quicksave) ---

func test_refresh_quick_saves_empty_shows_label():
	GameSaveManager.delete_quicksave()
	_menu.show_as_load_mode()
	var quick_content = _menu._quick_content
	assert_gt(quick_content.get_child_count(), 0)
	var lbl = quick_content.get_child(0)
	assert_true(lbl is Label)
	assert_true(lbl.text.contains("Aucune"), "Doit afficher le message vide")


# --- _refresh_quick_saves (avec quicksave) ---

func test_refresh_quick_saves_with_quicksave_shows_card():
	GameSaveManager.quicksave({"chapter_name": "Quick", "story_path": ""}, null)
	_menu.show_as_load_mode()
	var quick_content = _menu._quick_content
	var card = quick_content.find_child("QuicksaveCard", true, false)
	assert_not_null(card, "Doit afficher QuicksaveCard quand quicksave existe")

func test_quicksave_card_has_load_button():
	GameSaveManager.quicksave({"chapter_name": "Quick"}, null)
	_menu.show_as_load_mode()
	var load_btn = _menu._quick_content.find_child("QuickLoadButton", true, false)
	assert_not_null(load_btn)
	assert_eq(load_btn.text, "Charger")

func test_quicksave_load_button_emits_signal():
	GameSaveManager.quicksave({"chapter_name": "Quick"}, null)
	watch_signals(_menu)
	_menu.show_as_load_mode()
	var load_btn = _menu._quick_content.find_child("QuickLoadButton", true, false)
	assert_not_null(load_btn)
	load_btn.pressed.emit()
	assert_signal_emitted(_menu, "load_slot_pressed")
	assert_eq(get_signal_parameters(_menu, "load_slot_pressed")[0], -1)


# --- apply_custom_theme ---

func test_apply_custom_theme_method_exists() -> void:
	assert_true(_menu.has_method("apply_custom_theme"), "save_load_menu should have apply_custom_theme")

func test_apply_custom_theme_does_not_crash() -> void:
	_menu.apply_custom_theme("")
	pass_test("apply_custom_theme did not crash")
