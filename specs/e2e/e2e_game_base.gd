extends GutTest

## Classe de base pour les tests e2e du jeu standalone avec interactions UI réelles.
##
## Instancie game.gd, fixe la taille du viewport pour un layout cohérent,
## et fournit un E2eActionHelper pré-configuré.

const GameScript = preload("res://src/game.gd")
const E2eActionHelper = preload("res://specs/e2e/e2e_action_helper.gd")
const E2eStoryBuilder = preload("res://specs/e2e/e2e_story_builder.gd")

var _game: Control
var _ui: RefCounted  # E2eActionHelper


func before_each():
	# Fixer la taille du viewport pour un layout cohérent
	get_tree().root.size = Vector2i(1920, 1080)

	_game = Control.new()
	_game.set_script(GameScript)
	_game.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_game)

	_ui = E2eActionHelper.create(self)
	await _ui.wait_for_layout()


func after_each():
	if _game and _game.get_tree():
		_game.get_tree().paused = false
	if _ui:
		_ui.release()
		_ui = null
	if _game:
		remove_child(_game)
		_game.queue_free()
		_game = null


## Charger une story et afficher le menu principal, prêt pour un clic "Nouvelle partie".
func show_main_menu_with_story(story = null):
	if story == null:
		story = E2eStoryBuilder.make_branching_story()
	_game._current_story = story
	_game._current_story_path = ""
	_game._show_main_menu(story)
	await _ui.wait_frames(3)
	return story
