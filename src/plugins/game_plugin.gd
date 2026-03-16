class_name VBGamePlugin
extends RefCounted

## Classe de base pour les plugins in-game.
## Chaque plugin étend cette classe et surcharge les méthodes souhaitées.


## Retourne le nom unique du plugin.
func get_plugin_name() -> String:
	return ""


## Retourne une description courte du plugin.
func get_plugin_description() -> String:
	return ""


## Indique si le plugin peut être activé/désactivé par l'utilisateur.
## Si false, le plugin est toujours actif (pas de toggle dans les options).
func is_configurable() -> bool:
	return true


# --- Lifecycle ---

## Appelé quand le jeu est prêt (story chargée, UI construite).
func on_game_ready(ctx: RefCounted) -> void:
	pass


## Appelé quand le jeu se termine (nettoyage).
func on_game_cleanup(ctx: RefCounted) -> void:
	pass


# --- Hooks événementiels ---

func on_before_chapter(ctx: RefCounted) -> void:
	pass


func on_after_chapter(ctx: RefCounted) -> void:
	pass


func on_before_scene(ctx: RefCounted) -> void:
	pass


func on_after_scene(ctx: RefCounted) -> void:
	pass


func on_before_sequence(ctx: RefCounted) -> void:
	pass


func on_after_sequence(ctx: RefCounted) -> void:
	pass


# --- Pipeline de transformation ---

## Appelé avant l'affichage d'un dialogue. Peut modifier character et text.
## Retourne {"character": String, "text": String}.
func on_before_dialogue(ctx: RefCounted, character: String, text: String) -> Dictionary:
	return {"character": character, "text": text}


## Appelé après l'affichage d'un dialogue.
func on_after_dialogue(ctx: RefCounted, character: String, text: String) -> void:
	pass


## Appelé avant l'affichage des choix. Peut modifier la liste.
## Retourne un Array de choix (même structure que l'entrée).
func on_before_choice(ctx: RefCounted, choices: Array) -> Array:
	return choices


## Appelé après qu'un choix a été fait.
func on_after_choice(ctx: RefCounted, choice_index: int, choice_text: String) -> void:
	pass


# --- Contributions UI ---

## Retourne les boutons à ajouter dans la toolbar au-dessus du dialogue.
## Chaque élément est un GameContributions.GameToolbarButton.
func get_toolbar_buttons() -> Array:
	return []


## Retourne les panneaux overlay (gauche, droit, haut).
## Chaque élément est un GameContributions.GameOverlayPanelDef.
func get_overlay_panels() -> Array:
	return []


## Retourne les contrôles à ajouter dans la section Plugins des options.
## Chaque élément est un GameContributions.GameOptionsControlDef.
func get_options_controls() -> Array:
	return []


## Retourne les contrôles de configuration éditeur pour ce plugin.
## Appelé dans le dialogue de configuration du jeu (onglet Plugins).
## Chaque élément est un GameContributions.GameOptionsControlDef.
## Le create_control reçoit un Dictionary (plugin_settings du plugin).
func get_editor_config_controls() -> Array:
	return []
