# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Gère l'état de rechargement du graphe.

static var _needs_reload: bool = false


static func needs_reload() -> bool:
	return _needs_reload


static func set_needs_reload(value: bool) -> void:
	_needs_reload = value