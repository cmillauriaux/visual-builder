# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Classe de base pour toutes les commandes undo/redo.
## Chaque commande concrète doit surcharger execute(), undo() et get_label().

func execute() -> void:
	pass

func undo() -> void:
	pass

func get_label() -> String:
	return ""