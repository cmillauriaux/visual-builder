class_name GamePluginContext
extends RefCounted

## Contexte riche passé aux hooks des plugins in-game.

## Story courante (peut être null)
var story = null

## Chemin absolu vers le répertoire de la story
var story_base_path: String = ""

## Chapitre courant (peut être null)
var current_chapter = null

## Scène courante (peut être null)
var current_scene = null

## Séquence courante (peut être null)
var current_sequence = null

## Index du dialogue en cours (-1 si aucun)
var current_dialogue_index: int = -1

## Référence directe aux variables du jeu (lecture/écriture)
var variables: Dictionary = {}

## Nœud principal du jeu — pour ajouter des popups, overlays, etc.
var game_node: Control = null

## Référence aux paramètres du jeu (GameSettings)
var settings: RefCounted = null
