# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

## Détection automatique de la locale système/navigateur.
##
## Fournit deux méthodes statiques :
## - detect_locale() : détecte la locale courante (web ou desktop).
## - resolve_language() : résout la langue à utiliser selon la chaîne de fallback.

class_name LocaleDetector


## Détecte la locale courante et retourne un code langue 2 lettres (ex: "fr", "en").
## - Web : utilise navigator.language via JavaScriptBridge.
## - Desktop : utilise OS.get_locale_language().
## - Retourne "" en cas d'échec.
static func detect_locale() -> String:
	if OS.get_name() == "Web":
		return _detect_web_locale()
	return _detect_desktop_locale()


## Résout la langue à utiliser parmi les langues disponibles.
## Chaîne de fallback :
## 1. Si detected est dans available → detected
## 2. Si "en" est dans available → "en"
## 3. Sinon → default_lang (langue source de la story)
static func resolve_language(detected: String, available: Array, default_lang: String) -> String:
	if detected != "" and available.has(detected):
		return detected
	if available.has("en"):
		return "en"
	return default_lang


# --- Helpers privés ---

static func _detect_desktop_locale() -> String:
	var locale := OS.get_locale_language()
	if locale.length() >= 2:
		return locale.substr(0, 2).to_lower()
	return ""


static func _detect_web_locale() -> String:
	if not ClassDB.class_exists(&"JavaScriptBridge"):
		return ""
	var expr := Expression.new()
	if expr.parse("JavaScriptBridge.eval('navigator.language || \"\"')") != OK:
		return ""
	var result = expr.execute()
	if expr.has_execute_failed() or result == null:
		return ""
	var lang: String = str(result).strip_edges()
	if lang == "":
		return ""
	# navigator.language retourne ex: "fr-FR", "en-US" — extraire le préfixe 2 lettres
	var parts := lang.split("-")
	if parts.size() > 0 and parts[0].length() >= 2:
		return parts[0].substr(0, 2).to_lower()
	return ""