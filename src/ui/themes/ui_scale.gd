# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Facteur d'échelle UI appliqué à toutes les tailles (fonts, marges, etc.).
##
## Avec le stretch mode canvas_items, Godot gère déjà le mapping de la
## résolution de design (1920×1080) vers la taille réelle de la fenêtre.
## Ce module applique uniquement le multiplicateur choisi par l'utilisateur
## (Petit / Moyen / Gros) sans compensation DPI ni ratio d'écran.

const SCALE_MIN := 0.5
const SCALE_MAX := 5.0

static var _scale: float = -1.0
static var _user_multiplier: float = 1.0


## Retourne le facteur d'échelle UI courant.
## Calculé une seule fois à la première utilisation.
static func get_scale() -> float:
	if _scale < 0.0:
		_scale = _compute_scale()
	return _scale


## Retourne `pixels` multiplié par le facteur d'échelle, arrondi à l'entier le plus proche.
static func scale(pixels: float) -> int:
	return roundi(pixels * get_scale())


## Définit le multiplicateur utilisateur (1.0 = petit, 1.25 = moyen, 1.5 = gros).
## Invalide le cache pour forcer un recalcul.
static func set_user_multiplier(multiplier: float) -> void:
	_user_multiplier = multiplier
	_scale = -1.0


## Retourne le multiplicateur utilisateur courant.
static func get_user_multiplier() -> float:
	return _user_multiplier


## Remet à zéro le cache (utile pour les tests).
static func reset() -> void:
	_scale = -1.0
	_user_multiplier = 1.0


static func _compute_scale() -> float:
	# With canvas_items stretch mode, Godot already maps the design resolution
	# (1920×1080) to the actual window size. No need to compensate for DPI or
	# window size — just apply the user's preferred multiplier.
	return clampf(_user_multiplier, SCALE_MIN, SCALE_MAX)