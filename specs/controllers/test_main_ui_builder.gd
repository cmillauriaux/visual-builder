extends GutTest

## Tests pour MainUIBuilder — construction de l'UI de l'éditeur principal.

const MainScript = load("res://src/main.gd")

var _main: Control


func before_each() -> void:
	_main = Control.new()
	_main.set_script(MainScript)
	add_child(_main)


func after_each() -> void:
	remove_child(_main)
	_main.queue_free()


func test_builds_vbox() -> void:
	assert_not_null(_main._vbox)
	assert_true(_main._vbox is VBoxContainer)


func test_builds_top_bar() -> void:
	assert_not_null(_main._top_bar_panel)
	assert_true(_main._top_bar_panel is PanelContainer)
	assert_not_null(_main._top_bar)
	assert_true(_main._top_bar is HBoxContainer)


func test_builds_back_button() -> void:
	assert_not_null(_main._back_button)
	assert_eq(_main._back_button.text, "← Retour")


func test_builds_breadcrumb() -> void:
	assert_not_null(_main._breadcrumb)


func test_builds_create_button() -> void:
	assert_not_null(_main._create_button)


func test_builds_histoire_menu() -> void:
	assert_not_null(_main._histoire_menu)
	assert_eq(_main._histoire_menu.text, "Histoire")
	var popup = _main._histoire_menu.get_popup()
	assert_eq(popup.get_item_text(popup.get_item_index(0)), "Nouvelle histoire")
	assert_eq(popup.get_item_text(popup.get_item_index(1)), "Charger")
	assert_true(popup.get_item_text(popup.get_item_index(2)).begins_with("Sauvegarder"))
	assert_eq(popup.get_item_text(popup.get_item_index(3)), "Sauvegarder sous...")
	assert_eq(popup.get_item_text(popup.get_item_index(4)), "Exporter")
	assert_eq(popup.get_item_text(popup.get_item_index(5)), "Vérifier l'histoire")


func test_builds_graph_views() -> void:
	assert_not_null(_main._chapter_graph_view)
	assert_not_null(_main._scene_graph_view)
	assert_not_null(_main._sequence_graph_view)
	assert_true(_main._chapter_graph_view is GraphEdit)
	assert_true(_main._scene_graph_view is GraphEdit)
	assert_true(_main._sequence_graph_view is GraphEdit)


func test_builds_visual_editor() -> void:
	assert_not_null(_main._visual_editor)


func test_builds_play_overlay() -> void:
	assert_not_null(_main._play_overlay)
	assert_false(_main._play_overlay.visible)


func test_builds_play_buttons() -> void:
	assert_not_null(_main._play_button)
	assert_not_null(_main._stop_button)
	assert_false(_main._stop_button.visible)


func test_builds_typewriter_timer() -> void:
	assert_not_null(_main._typewriter_timer)
	assert_almost_eq(_main._typewriter_timer.wait_time, 0.03, 0.001)


func test_builds_sequence_editor_panel() -> void:
	assert_not_null(_main._sequence_editor_panel)


func test_builds_condition_editor() -> void:
	assert_not_null(_main._condition_editor)
	assert_not_null(_main._condition_editor_panel)
	assert_false(_main._condition_editor_panel.visible)


func test_builds_tab_container_with_5_tabs() -> void:
	assert_not_null(_main._tab_container)
	assert_eq(_main._tab_container.get_tab_count(), 5)


func test_builds_ending_editor() -> void:
	assert_not_null(_main._ending_editor)


func test_builds_parametres_menu() -> void:
	assert_not_null(_main._parametres_menu)
	assert_eq(_main._parametres_menu.text, "Paramètres")
	var popup = _main._parametres_menu.get_popup()
	assert_eq(popup.get_item_text(popup.get_item_index(0)), "Variables")
	assert_eq(popup.get_item_text(popup.get_item_index(1)), "Menu")
	assert_eq(popup.get_item_text(popup.get_item_index(2)), "Galerie")
	assert_eq(popup.get_item_text(popup.get_item_index(3)), "Notifications")


func test_builds_top_play_stop_buttons() -> void:
	assert_not_null(_main._top_play_button)
	assert_not_null(_main._top_stop_button)
	assert_false(_main._top_play_button.visible)
	assert_false(_main._top_stop_button.visible)
