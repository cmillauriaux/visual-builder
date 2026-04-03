# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

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


## Appelé pour chaque bouton de choix après sa création.
## Permet de personnaliser le style visuel du bouton (couleur, icône...).
func on_style_choice_button(ctx: RefCounted, btn: Button, choice: RefCounted, index: int) -> void:
	pass


## Appelé après qu'un choix a été fait.
func on_after_choice(ctx: RefCounted, choice_index: int, choice_text: String) -> void:
	pass


# --- Hooks cycle de vie de la story ---

## Appelé quand une nouvelle partie démarre.
func on_story_started(ctx: RefCounted, story_title: String, story_version: String) -> void:
	pass


## Appelé quand la story se termine (fin narrative ou abandon).
func on_story_finished(ctx: RefCounted, reason: String) -> void:
	pass


## Appelé quand une partie est sauvegardée dans un slot.
func on_story_saved(ctx: RefCounted, story_title: String, slot_index: int, chapter: String, scene: String, sequence: String) -> void:
	pass


## Appelé quand une partie est chargée depuis un slot.
func on_story_loaded(ctx: RefCounted, story_title: String, slot_index: int) -> void:
	pass


## Appelé quand le joueur quitte le jeu (menu principal ou pause).
func on_game_quit(ctx: RefCounted, chapter: String, scene: String, sequence: String) -> void:
	pass


## Appelé quand une sauvegarde rapide est effectuée.
func on_quicksave(ctx: RefCounted, story_title: String, chapter: String) -> void:
	pass


## Appelé quand une sauvegarde rapide est restaurée.
func on_quickload(ctx: RefCounted, story_title: String) -> void:
	pass


## Appelé quand le menu principal est affiché pour la première fois (une fois par session).
func on_main_menu_displayed(ctx: RefCounted, platform: String, app_version: String, story_version: String) -> void:
	pass


## Hook générique pour les événements analytics (options, liens, écrans de fin, etc.).
func on_game_event(ctx: RefCounted, event_name: String, data: Dictionary) -> void:
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


## Retourne les options d'export pour ce plugin.
## Chaque élément est un GameContributions.ExportOptionDef.
## Affichées comme cases à cocher dans la fenêtre d'export.
func get_export_options() -> Array:
	return []


## Retourne le nom du dossier du plugin (sous res://plugins/).
## Utilisé par le service d'export pour exclure le plugin si l'option est décochée.
func get_plugin_folder() -> String:
	return ""