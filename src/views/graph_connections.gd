# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Utilitaire pour extraire le type de connexion depuis le nom d'un port.

static func get_connection_type_from_name(name: String) -> String:
	if name.begins_with("chapter_"):
		return "chapter"
	if name.begins_with("scene_"):
		return "scene"
	if name.begins_with("seq_"):
		return "sequence"
	if name.begins_with("cond_"):
		return "condition"
	if name.begins_with("end_"):
		return "ending"
	return name.trim_suffix("_")