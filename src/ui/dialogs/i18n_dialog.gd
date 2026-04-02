# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends AcceptDialog

## Dialog affichant les résultats d'une opération i18n (vérification ou regénération).

var _scroll: ScrollContainer
var _content: VBoxContainer


func _ready() -> void:
	ok_button_text = "Fermer"
	_build_ui()


func show_regenerate_result(added_per_lang: Dictionary) -> void:
	title = "Regénération des clés i18n"
	_content_clear()

	if added_per_lang.is_empty():
		_add_line("Aucun fichier de traduction trouvé dans i18n/.", false)
		_add_line("Sauvegardez l'histoire pour générer i18n/fr.yaml.", false)
		return

	var any_added := false
	for lang in added_per_lang:
		var count: int = added_per_lang[lang]
		if count > 0:
			_add_line("✅ [%s] : %d clé(s) ajoutée(s)" % [lang.to_upper(), count], false)
			any_added = true
		else:
			_add_line("— [%s] : aucune clé manquante" % lang.to_upper(), false)

	if not any_added:
		_add_separator()
		_add_line("Tous les fichiers de traduction sont à jour.", false)


func show_check_result(check: Dictionary) -> void:
	title = "Vérification des traductions"
	_content_clear()

	if check.is_empty():
		_add_line("Aucune langue à vérifier (seul fr.yaml existe).", false)
		_add_line("Ajoutez des fichiers i18n/{lang}.yaml pour d'autres langues.", false)
		return

	for lang in check:
		var data: Dictionary = check[lang]
		var missing: Array = data["missing"]
		var orphans: Array = data["orphans"]
		var total: int = data["total"]
		var translated: int = data["translated"]
		var pct := 100 if total == 0 else translated * 100 / total

		_add_separator()
		var status := "✅" if missing.is_empty() and orphans.is_empty() else "❌"
		_add_title("%s [%s] — %d/%d traduit(s) (%d%%)" % [status, lang.to_upper(), translated, total, pct])

		if not missing.is_empty():
			_add_line("  Traductions manquantes (%d) :" % missing.size(), true)
			for s in missing:
				_add_line("    • %s" % s, false)

		if not orphans.is_empty():
			_add_line("  Clés orphelines (%d, plus dans l'histoire) :" % orphans.size(), true)
			for s in orphans:
				_add_line("    • %s" % s, false)

		if missing.is_empty() and orphans.is_empty():
			_add_line("  Toutes les traductions sont complètes.", false)


# --- Private ---

func _build_ui() -> void:
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(550, 350)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)


func _content_clear() -> void:
	for child in _content.get_children():
		child.queue_free()


func _add_title(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	_content.add_child(lbl)


func _add_line(text: String, bold: bool) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if bold:
		lbl.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	_content.add_child(lbl)


func _add_separator() -> void:
	_content.add_child(HSeparator.new())