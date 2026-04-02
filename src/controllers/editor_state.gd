# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Définition des états de l'éditeur.
class_name EditorState

enum Mode {
	NONE,
	CHAPTER_VIEW,    # Vue graphe des chapitres
	SCENE_VIEW,      # Vue graphe des scènes
	SEQUENCE_VIEW,   # Vue graphe des séquences
	SEQUENCE_EDIT,   # Édition d'une séquence (Visual + Dialogues)
	CONDITION_EDIT,  # Édition d'une condition
	MAP_VIEW,        # Vue map globale de la story
	PLAY_MODE        # Mode test de jeu
}