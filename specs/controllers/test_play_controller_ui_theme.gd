extends GutTest

## Tests pour l'application du thème UI custom en mode Play éditeur.
## Les helpers reçoivent les overlays en paramètres explicites — pas de mock _main nécessaire.

const PlayControllerScript = preload("res://src/controllers/play_controller.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")

var _play_ctrl: Node
var _play_overlay: PanelContainer
var _choice_overlay: CenterContainer


func before_each() -> void:
	_play_overlay = PanelContainer.new()
	_choice_overlay = CenterContainer.new()
	add_child(_play_overlay)
	add_child(_choice_overlay)

	_play_ctrl = Node.new()
	_play_ctrl.set_script(PlayControllerScript)
	add_child(_play_ctrl)


func after_each() -> void:
	_play_ctrl.queue_free()
	_play_overlay.queue_free()
	_choice_overlay.queue_free()


func test_apply_play_theme_does_not_crash() -> void:
	# En headless, GameTheme.create_theme("") peut retourner un Theme ou null
	# On vérifie juste que la méthode existe et ne plante pas
	assert_true(_play_ctrl.has_method("_apply_play_ui_theme"))
	_play_ctrl._apply_play_ui_theme(_play_overlay, _choice_overlay, "")
	assert_true(_play_overlay.theme == null or _play_overlay.theme is Theme)


func test_clear_play_theme_sets_null_on_overlays() -> void:
	# D'abord appliquer un thème (peut rester null en headless — c'est OK)
	_play_ctrl._apply_play_ui_theme(_play_overlay, _choice_overlay, "")
	# Puis effacer — doit toujours mettre null
	_play_ctrl._clear_play_ui_theme(_play_overlay, _choice_overlay)
	assert_null(_play_overlay.theme, "play_overlay.theme should be null after clear")
	assert_null(_choice_overlay.theme, "choice_overlay.theme should be null after clear")
