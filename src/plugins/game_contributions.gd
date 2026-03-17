## Value objects pour les contributions des plugins in-game.
## Chaque classe représente un type de point d'intégration.


class GameToolbarButton extends RefCounted:
	## Texte du bouton
	var label: String = ""
	## Icône optionnelle (Texture2D)
	var icon = null
	## Callback appelé avec (ctx: GamePluginContext)
	var callback: Callable


class GameOverlayPanelDef extends RefCounted:
	## Position de l'overlay : "left" | "right" | "top"
	var position: String = ""
	## Callable qui retourne un Control, appelé avec (ctx: GamePluginContext)
	var create_panel: Callable


class GameOptionsControlDef extends RefCounted:
	## Callable qui retourne un Control, appelé avec (settings: RefCounted)
	var create_control: Callable
