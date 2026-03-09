extends "res://addons/gut/test.gd"

const MainUI = load("res://src/main.gd")
const EditorState = load("res://src/controllers/editor_state.gd")

func test_initial_ui_state_hides_top_bar():
	var main = MainUI.new()
	# Construction of UI
	add_child_autofree(main)
	
	# Wait one frame for _ready and signal emission
	await wait_frames(1)
	
	assert_false(main._top_bar_panel.visible, "Le top bar panel devrait être masqué au démarrage")
	assert_true(main._welcome_screen.visible, "L'écran d'accueil devrait être visible au démarrage")
	
	assert_false(main._back_button.visible, "Le bouton retour devrait être masqué")
	assert_false(main._create_condition_button.visible, "Le bouton nouvelle condition devrait être masqué")
	assert_false(main._parametres_menu.visible, "Le menu paramètres devrait être masqué")
	assert_false(main._histoire_menu.visible, "Le menu histoire devrait être masqué")
	assert_false(main._breadcrumb.visible, "Le fil d'Ariane devrait être masqué")

func test_navigation_shows_top_bar():
	var main = MainUI.new()
	add_child_autofree(main)
	await wait_frames(1)
	
	# Simulate loading a story/new story
	main._nav_ctrl.on_new_story_pressed()
	await wait_frames(1)
	
	assert_true(main._top_bar_panel.visible, "Le top bar panel devrait être visible après avoir créé une histoire")
	assert_false(main._welcome_screen.visible, "L'écran d'accueil devrait être masqué après avoir créé une histoire")
	assert_true(main._histoire_menu.visible, "Le menu histoire devrait être visible")
	assert_true(main._breadcrumb.visible, "Le fil d'Ariane devrait être visible")
	# At chapters level, back button should still be hidden
	assert_false(main._back_button.visible, "Le bouton retour devrait être masqué au niveau chapitres")
