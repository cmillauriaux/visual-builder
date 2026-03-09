extends GutTest

# Tests pour le PopupMenu du breadcrumb sur le nom de l'histoire

var Breadcrumb = load("res://src/ui/navigation/breadcrumb.gd")

var _breadcrumb: HBoxContainer = null

func before_each():
	_breadcrumb = HBoxContainer.new()
	_breadcrumb.set_script(Breadcrumb)
	add_child_autofree(_breadcrumb)

func _get_button_at_path_index(index: int) -> Button:
	# Le PopupMenu est un enfant caché, on cherche le n-ième Button
	var btn_count = 0
	for child in _breadcrumb.get_children():
		if child is Button:
			if btn_count == index:
				return child
			btn_count += 1
	return null

func test_story_click_emits_story_context_menu_requested():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1"])
	watch_signals(_breadcrumb)
	var story_btn = _get_button_at_path_index(0)
	assert_not_null(story_btn, "Le bouton de l'histoire doit exister")
	story_btn.pressed.emit()
	# Ne doit PAS émettre level_clicked pour index 0
	assert_signal_not_emitted(_breadcrumb, "level_clicked")
	# Doit émettre story_context_menu_requested
	assert_signal_emitted(_breadcrumb, "story_context_menu_requested")

func test_story_click_at_chapters_level_emits_story_context_menu():
	_breadcrumb.set_path(["Mon Histoire"])
	watch_signals(_breadcrumb)
	var story_btn = _get_button_at_path_index(0)
	assert_not_null(story_btn)
	story_btn.pressed.emit()
	assert_signal_not_emitted(_breadcrumb, "level_clicked")
	assert_signal_emitted(_breadcrumb, "story_context_menu_requested")

func test_other_buttons_still_emit_level_clicked():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1", "Scène 1"])
	watch_signals(_breadcrumb)
	var chapter_btn = _get_button_at_path_index(1)
	assert_not_null(chapter_btn, "Le bouton du chapitre doit exister")
	chapter_btn.pressed.emit()
	assert_signal_emitted(_breadcrumb, "level_clicked")
	assert_signal_not_emitted(_breadcrumb, "story_context_menu_requested")

func test_scene_button_emits_level_clicked():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1", "Scène 1"])
	watch_signals(_breadcrumb)
	var scene_btn = _get_button_at_path_index(2)
	assert_not_null(scene_btn, "Le bouton de la scène doit exister")
	scene_btn.pressed.emit()
	assert_signal_emitted(_breadcrumb, "level_clicked")

func test_story_context_menu_requested_signal_exists():
	assert_has_signal(_breadcrumb, "story_context_menu_requested")

func test_popup_menu_exists():
	_breadcrumb.set_path(["Mon Histoire"])
	var popup = _breadcrumb.get_popup_menu()
	assert_not_null(popup, "Le PopupMenu doit exister")
	assert_true(popup is PopupMenu, "Doit être un PopupMenu")

func test_popup_has_rename_option():
	_breadcrumb.set_path(["Mon Histoire"])
	var popup = _breadcrumb.get_popup_menu()
	assert_not_null(popup)
	var found = false
	for i in range(popup.item_count):
		if popup.get_item_text(i) == "Renommer":
			found = true
			break
	assert_true(found, "Le PopupMenu doit contenir l'option 'Renommer'")

func test_popup_has_go_to_chapters_when_not_at_chapters():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1"])
	_breadcrumb.set_current_level("scenes")
	var popup = _breadcrumb.get_popup_menu()
	_breadcrumb._update_popup_items()
	var found = false
	for i in range(popup.item_count):
		if popup.get_item_text(i) == "Aller aux chapitres":
			found = true
			break
	assert_true(found, "Le PopupMenu doit contenir 'Aller aux chapitres' quand on n'est pas au niveau chapitres")

func test_popup_no_go_to_chapters_when_at_chapters():
	_breadcrumb.set_path(["Mon Histoire"])
	_breadcrumb.set_current_level("chapters")
	_breadcrumb._update_popup_items()
	var popup = _breadcrumb.get_popup_menu()
	var found = false
	for i in range(popup.item_count):
		if popup.get_item_text(i) == "Aller aux chapitres":
			found = true
			break
	assert_false(found, "Le PopupMenu ne doit PAS contenir 'Aller aux chapitres' au niveau chapitres")

func test_popup_rename_action_emits_signal():
	_breadcrumb.set_path(["Mon Histoire"])
	_breadcrumb.set_current_level("chapters")
	_breadcrumb._update_popup_items()
	watch_signals(_breadcrumb)
	var popup = _breadcrumb.get_popup_menu()
	# Trouver l'index de "Renommer"
	for i in range(popup.item_count):
		if popup.get_item_text(i) == "Renommer":
			popup.id_pressed.emit(popup.get_item_id(i))
			break
	assert_signal_emitted(_breadcrumb, "story_rename_requested")

func test_popup_go_to_chapters_emits_level_clicked_0():
	_breadcrumb.set_path(["Mon Histoire", "Chapitre 1"])
	_breadcrumb.set_current_level("scenes")
	_breadcrumb._update_popup_items()
	watch_signals(_breadcrumb)
	var popup = _breadcrumb.get_popup_menu()
	for i in range(popup.item_count):
		if popup.get_item_text(i) == "Aller aux chapitres":
			popup.id_pressed.emit(popup.get_item_id(i))
			break
	assert_signal_emitted(_breadcrumb, "level_clicked")
