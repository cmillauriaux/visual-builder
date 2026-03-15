extends GutTest

## Tests pour l'application du thème UI custom dans le jeu exporté.

const GameScript = preload("res://src/game.gd")
const StoryScript = preload("res://src/models/story.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")


func test_apply_game_ui_theme_method_exists() -> void:
	var game = Control.new()
	game.set_script(GameScript)
	add_child(game)
	assert_true(game.has_method("_apply_game_ui_theme"),
		"game should have _apply_game_ui_theme method")
	game.queue_free()


func test_apply_game_ui_theme_default_mode_does_not_change_theme() -> void:
	var game = Control.new()
	game.set_script(GameScript)
	add_child(game)
	var story = StoryScript.new()
	story.ui_theme_mode = "default"
	var theme_before = game.theme
	game._apply_game_ui_theme(story)
	# En mode default, le helper retourne sans toucher au thème
	assert_eq(game.theme, theme_before, "default mode should not change game.theme")
	game.queue_free()


func test_apply_game_ui_theme_custom_mode_does_not_crash() -> void:
	var game = Control.new()
	game.set_script(GameScript)
	add_child(game)
	var story = StoryScript.new()
	story.ui_theme_mode = "custom"
	# res://story/assets/ui n'existe probablement pas en test → fallback Kenney
	# Vérifier juste pas de crash et theme reste un Theme ou null
	game._apply_game_ui_theme(story)
	assert_true(game.theme == null or game.theme is Theme)
	game.queue_free()
