extends GutTest

## Tests pour SaveLoadMenu — grille de sauvegarde/chargement.

const SaveLoadMenuScript = preload("res://src/ui/menu/save_load_menu.gd")
const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")

var _menu: Control


func before_each() -> void:
	# Nettoyer les slots avant chaque test
	for i in range(GameSaveManager.NUM_SLOTS):
		GameSaveManager.delete_save(i)
	_menu = Control.new()
	_menu.set_script(SaveLoadMenuScript)
	_menu.build_ui()
	add_child_autofree(_menu)


func after_each() -> void:
	for i in range(GameSaveManager.NUM_SLOTS):
		GameSaveManager.delete_save(i)


# --- État initial ---

func test_starts_hidden() -> void:
	assert_false(_menu.visible)


func test_process_mode_always() -> void:
	assert_eq(_menu.process_mode, Node.PROCESS_MODE_ALWAYS)


# --- show_as_save_mode ---

func test_show_as_save_mode_makes_visible() -> void:
	_menu.show_as_save_mode()
	assert_true(_menu.visible)


func test_show_as_save_mode_sets_title() -> void:
	_menu.show_as_save_mode()
	assert_eq(_menu.get_title_text(), "Sauvegarder")


# --- show_as_load_mode ---

func test_show_as_load_mode_makes_visible() -> void:
	_menu.show_as_load_mode()
	assert_true(_menu.visible)


func test_show_as_load_mode_sets_title() -> void:
	_menu.show_as_load_mode()
	assert_eq(_menu.get_title_text(), "Charger")


# --- hide_menu ---

func test_hide_menu_hides_control() -> void:
	_menu.show_as_load_mode()
	_menu.hide_menu()
	assert_false(_menu.visible)


# --- Grille ---

func test_grid_has_six_slots() -> void:
	_menu.show_as_load_mode()
	assert_eq(_menu._grid.get_child_count(), GameSaveManager.NUM_SLOTS)


func test_empty_slot_shows_empty_label() -> void:
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(0)
	var empty_label := _find_child_by_name(card, "EmptyLabel")
	assert_not_null(empty_label, "slot vide doit avoir EmptyLabel")


func test_save_mode_empty_slot_has_save_button() -> void:
	_menu.show_as_save_mode()
	var card = _menu._grid.get_child(0)
	var save_btn := _find_child_by_name(card, "SaveButton")
	assert_not_null(save_btn, "slot vide en mode save doit avoir SaveButton")


func test_occupied_slot_shows_chapter_and_scene_labels() -> void:
	_make_save(0, "Chapitre Test", "Scène Test")
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(0)
	var chap_label := _find_child_by_name(card, "ChapterLabel")
	var scene_label := _find_child_by_name(card, "SceneLabel")
	assert_not_null(chap_label)
	assert_not_null(scene_label)
	assert_eq(chap_label.text, "Chapitre Test")
	assert_eq(scene_label.text, "Scène Test")


func test_occupied_slot_in_load_mode_has_load_button() -> void:
	_make_save(0)
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(0)
	var load_btn := _find_child_by_name(card, "LoadButton")
	assert_not_null(load_btn, "slot occupé en mode load doit avoir LoadButton")


func test_occupied_slot_in_load_mode_has_delete_button() -> void:
	_make_save(0)
	_menu.show_as_load_mode()
	var card = _menu._grid.get_child(0)
	var del_btn := _find_child_by_name(card, "DeleteButton")
	assert_not_null(del_btn, "slot occupé doit avoir DeleteButton")


# --- Signaux ---

func test_save_slot_pressed_signal_emitted_on_empty_slot() -> void:
	_menu.show_as_save_mode()
	watch_signals(_menu)
	var card = _menu._grid.get_child(0)
	var save_btn := _find_child_by_name(card, "SaveButton")
	save_btn.pressed.emit()
	assert_signal_emitted(_menu, "save_slot_pressed")


func test_load_slot_pressed_signal_emitted() -> void:
	_make_save(0)
	_menu.show_as_load_mode()
	watch_signals(_menu)
	var card = _menu._grid.get_child(0)
	var load_btn := _find_child_by_name(card, "LoadButton")
	load_btn.pressed.emit()
	assert_signal_emitted(_menu, "load_slot_pressed")


func test_delete_slot_pressed_signal_emitted() -> void:
	_make_save(1)
	_menu.show_as_load_mode()
	watch_signals(_menu)
	var card = _menu._grid.get_child(1)
	var del_btn = _find_child_by_name(card, "DeleteButton")
	del_btn.pressed.emit()
	assert_signal_emitted(_menu, "delete_slot_pressed")


func test_close_pressed_signal_emitted() -> void:
	_menu.show_as_load_mode()
	watch_signals(_menu)
	# Le bouton fermer (×) est dans l'en-tête
	var close_btn := _find_child_by_name(_menu, "×")
	if close_btn == null:
		# Trouver par parcours : premier Button avec text "×"
		close_btn = _find_button_with_text(_menu, "×")
	assert_not_null(close_btn, "bouton × doit exister")
	close_btn.pressed.emit()
	assert_signal_emitted(_menu, "close_pressed")


# --- Confirmation d'écrasement ---

func test_overwrite_shows_confirm_dialog() -> void:
	_make_save(0)
	_menu.show_as_save_mode()
	# Simuler le clic sur un slot occupé
	_menu._on_save_occupied_slot(0)
	assert_true(_menu._confirm_overlay.visible, "dialog de confirmation doit être visible")


func test_confirm_no_hides_dialog() -> void:
	_make_save(0)
	_menu.show_as_save_mode()
	_menu._on_save_occupied_slot(0)
	var no_btn := _find_child_by_name(_menu._confirm_overlay, "ConfirmNoButton")
	assert_not_null(no_btn)
	no_btn.pressed.emit()
	assert_false(_menu._confirm_overlay.visible)


func test_confirm_yes_emits_save_slot_pressed() -> void:
	_make_save(0)
	_menu.show_as_save_mode()
	watch_signals(_menu)
	_menu._on_save_occupied_slot(0)
	var yes_btn := _find_child_by_name(_menu._confirm_overlay, "ConfirmYesButton")
	assert_not_null(yes_btn)
	yes_btn.pressed.emit()
	assert_signal_emitted(_menu, "save_slot_pressed")


# --- refresh ---

func test_refresh_updates_grid() -> void:
	_menu.show_as_load_mode()
	# Initialement vide
	var card0_before = _menu._grid.get_child(0)
	var empty_label_before := _find_child_by_name(card0_before, "EmptyLabel")
	assert_not_null(empty_label_before)
	# Sauvegarder puis rafraîchir
	_make_save(0, "Après refresh")
	_menu.refresh()
	var card0_after = _menu._grid.get_child(0)
	var chap_label := _find_child_by_name(card0_after, "ChapterLabel")
	assert_not_null(chap_label)
	assert_eq(chap_label.text, "Après refresh")


# --- Helpers ---

func _make_save(slot: int, chapter_name: String = "Chapitre 1", scene_name: String = "Scène 1") -> void:
	var state := {
		"timestamp": "2026-03-04 10:00:00",
		"story_path": "",
		"chapter_uuid": "chap-001",
		"chapter_name": chapter_name,
		"scene_uuid": "scene-001",
		"scene_name": scene_name,
		"sequence_uuid": "seq-001",
		"sequence_name": "Intro",
		"dialogue_index": 0,
		"variables": {},
	}
	GameSaveManager.save_game(slot, state, null)


func _find_child_by_name(node: Node, child_name: String) -> Node:
	for child in node.get_children():
		if child.name == child_name:
			return child
		var found := _find_child_by_name(child, child_name)
		if found:
			return found
	return null


func _find_button_with_text(node: Node, text: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == text:
			return child
		var found := _find_button_with_text(child, text)
		if found:
			return found
	return null
