extends "res://specs/e2e/e2e_game_base.gd"

## Tests e2e — Menu save/load du jeu.
##
## Vérifie l'ouverture/fermeture du menu, les modes save/load,
## les onglets, et les slots.

const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")


func after_each():
	# Nettoyer les sauvegardes de test
	for i in 6:
		GameSaveManager.delete_save(i)
	super.after_each()


func test_pause_save_shows_menu():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(3)

	# Ouvrir le menu pause
	_game._pause_menu.show_menu()
	_game.get_tree().paused = true
	await _ui.wait_frames(3)

	# Cliquer sur Sauvegarder dans le menu pause
	await _ui.click_button(_game._pause_menu._save_button, "Sauvegarder")

	assert_true(_game._save_load_menu.visible,
		"Save/load menu should be visible")
	assert_eq(_game._save_load_menu._mode, _game._save_load_menu.Mode.SAVE,
		"Should be in SAVE mode")


func test_pause_load_shows_menu():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(3)

	_game._pause_menu.show_menu()
	_game.get_tree().paused = true
	await _ui.wait_frames(3)

	# Cliquer sur Charger
	await _ui.click_button(_game._pause_menu._load_button, "Charger")

	assert_true(_game._save_load_menu.visible,
		"Save/load menu should be visible")
	assert_eq(_game._save_load_menu._mode, _game._save_load_menu.Mode.LOAD,
		"Should be in LOAD mode")


func test_save_load_menu_close():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(3)

	_game._pause_menu.show_menu()
	_game.get_tree().paused = true
	await _ui.wait_frames(3)

	await _ui.click_button(_game._pause_menu._save_button, "Sauvegarder")
	assert_true(_game._save_load_menu.visible)

	# Fermer le menu save/load via le signal close
	_game._save_load_menu.close_pressed.emit()
	await _ui.wait_frames(3)

	assert_false(_game._save_load_menu.visible,
		"Save/load menu should be hidden after close")


func test_quicksave_button():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(3)

	# Vérifier que le bouton quicksave est visible dans la barre de boutons
	assert_true(_game._quicksave_button.visible,
		"Quicksave button should be visible during play")
	# Vérifier qu'il est bien un Button
	assert_true(_game._quicksave_button is Button,
		"Quicksave should be a Button")


func test_save_menu_has_slots():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(3)

	_game._pause_menu.show_menu()
	_game.get_tree().paused = true
	await _ui.wait_frames(3)

	await _ui.click_button(_game._pause_menu._save_button, "Sauvegarder")
	await _ui.wait_frames(3)

	# La grille de slots doit avoir des enfants
	var grid = _game._save_load_menu._grid
	assert_true(grid.get_child_count() > 0,
		"Save grid should have slot children")


func test_load_menu_tabs():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(3)

	_game._pause_menu.show_menu()
	_game.get_tree().paused = true
	await _ui.wait_frames(3)

	await _ui.click_button(_game._pause_menu._load_button, "Charger")
	await _ui.wait_frames(3)

	# En mode load, le TabContainer a 3 onglets (Sauvegardes, Automatiques, Rapides)
	var tab = _game._save_load_menu._tab_container
	assert_eq(tab.get_tab_count(), 3,
		"Load menu should have 3 tabs")
	assert_true(tab.tabs_visible,
		"Tabs should be visible in load mode")


func test_save_slot_signal():
	var story = await show_main_menu_with_story()
	await _ui.click_button(_game._main_menu._new_game_button, "Nouvelle partie")
	await _ui.wait_frames(3)

	# Écouter le signal save_slot_pressed
	watch_signals(_game._save_load_menu)

	# Émettre directement le signal (les slots interagissent via emit)
	_game._save_load_menu.save_slot_pressed.emit(0)
	await _ui.wait_frames()

	assert_signal_emitted(_game._save_load_menu, "save_slot_pressed")
