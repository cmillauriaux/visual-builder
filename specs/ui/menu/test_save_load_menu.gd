extends GutTest

var SaveLoadMenuScript

func before_each():
	SaveLoadMenuScript = load("res://src/ui/menu/save_load_menu.gd")

func test_build_ui():
	var menu = SaveLoadMenuScript.new()
	add_child_autofree(menu)
	menu.build_ui()
	assert_not_null(menu._tab_container)
	assert_not_null(menu._grid)
	assert_false(menu.visible)

func test_show_as_save_mode():
	var menu = SaveLoadMenuScript.new()
	add_child_autofree(menu)
	menu.build_ui()
	menu.show_as_save_mode()
	assert_true(menu.visible)
	assert_eq(menu._mode, menu.Mode.SAVE)
	assert_eq(menu.get_title_text(), "Sauvegarder")
	assert_false(menu._tab_container.tabs_visible)

func test_show_as_load_mode():
	var menu = SaveLoadMenuScript.new()
	add_child_autofree(menu)
	menu.build_ui()
	menu.show_as_load_mode()
	assert_true(menu.visible)
	assert_eq(menu._mode, menu.Mode.LOAD)
	assert_eq(menu.get_title_text(), "Charger")
	assert_true(menu._tab_container.tabs_visible)

func test_hide_menu():
	var menu = SaveLoadMenuScript.new()
	add_child_autofree(menu)
	menu.build_ui()
	menu.show_as_save_mode()
	menu.hide_menu()
	assert_false(menu.visible)
	assert_false(menu._confirm_overlay.visible)
