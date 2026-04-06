# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/plugins/game_plugin.gd"

## Plugin Bug Report : ajoute un bouton « Bug ? » dans la toolbar
## qui ouvre une fenêtre de rapport de bug envoyé par email via mailto:.

const GameContributions = preload("res://src/plugins/game_contributions.gd")

var _email: String = ""
var _ctx: RefCounted = null


func get_plugin_name() -> String:
	return "bug_report"


func get_plugin_description() -> String:
	return "Signaler un bug par email"


func is_configurable() -> bool:
	return false


func get_plugin_folder() -> String:
	return "bug_report"


# --- Lifecycle ---

func on_game_ready(ctx: RefCounted) -> void:
	_ctx = ctx
	_load_plugin_settings(ctx)


func on_game_cleanup(_context: RefCounted) -> void:
	_ctx = null


# --- Toolbar ---

func get_toolbar_buttons() -> Array:
	if _email == "":
		return []
	var btn_def := GameContributions.GameToolbarButton.new()
	btn_def.label = "Bug ?"
	btn_def.callback = _on_bug_button_pressed
	return [btn_def]


# --- Editor config ---

func get_editor_config_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_editor_config
	return [def]


func read_editor_config(ctrl: Control) -> Dictionary:
	if ctrl == null or not ctrl.has_meta("read_config"):
		return {}
	return ctrl.get_meta("read_config").call()


# --- Export options ---

func get_export_options() -> Array:
	var def := GameContributions.ExportOptionDef.new()
	def.label = "Inclure le rapport de bug"
	def.key = "bug_report_enabled"
	def.default_value = true
	return [def]


# ── Logique interne ──────────────────────────────────────────────────────────

func _load_plugin_settings(ctx: RefCounted) -> void:
	if ctx.story == null:
		_email = ""
		return
	var settings: Dictionary = ctx.story.plugin_settings.get("bug_report", {})
	_email = settings.get("email", "")


func _on_bug_button_pressed(ctx: RefCounted) -> void:
	if ctx == null or ctx.game_node == null:
		return
	_ctx = ctx
	_show_bug_report_dialog(ctx)


func _show_bug_report_dialog(ctx: RefCounted) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Signaler un bug"
	dialog.ok_button_text = "Envoyer"
	dialog.add_cancel_button("Annuler")
	dialog.min_size = Vector2i(500, 400)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)

	var instruction_label := Label.new()
	instruction_label.text = "Décrivez le problème rencontré :"
	vbox.add_child(instruction_label)

	var text_edit := TextEdit.new()
	text_edit.placeholder_text = "Décrivez le bug ici..."
	text_edit.custom_minimum_size = Vector2(0, 100)
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_edit)

	var separator := HSeparator.new()
	vbox.add_child(separator)

	var info_label := Label.new()
	info_label.text = _build_system_info(ctx)
	info_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	info_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info_label)

	dialog.add_child(vbox)

	dialog.confirmed.connect(func():
		var comment: String = text_edit.text.strip_edges()
		var mailto_url := _build_mailto_url(ctx, comment)
		OS.shell_open(mailto_url)
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		dialog.queue_free()
	)

	ctx.game_node.add_child(dialog)
	dialog.popup_centered()


func _get_chapter_title(ctx: RefCounted) -> String:
	if ctx.current_chapter != null and ctx.current_chapter.get("chapter_name") != null:
		return ctx.current_chapter.chapter_name
	return "Aucun"


func _get_scene_title(ctx: RefCounted) -> String:
	if ctx.current_scene != null and ctx.current_scene.get("scene_name") != null:
		return ctx.current_scene.scene_name
	return "Aucune"


func _get_sequence_title(ctx: RefCounted) -> String:
	if ctx.current_sequence != null and ctx.current_sequence.get("title") != null:
		return ctx.current_sequence.title
	return "Aucune"


func _get_os_name() -> String:
	return OS.get_name()


func _get_game_version() -> String:
	return ProjectSettings.get_setting("application/config/version", "inconnue")


func _get_engine_version() -> String:
	return Engine.get_version_info().string


func _build_system_info(ctx: RefCounted) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("--- Informations système ---")
	lines.append("OS : %s" % _get_os_name())
	lines.append("Version du jeu : %s" % _get_game_version())
	lines.append("Version du moteur : %s" % _get_engine_version())
	lines.append("Chapitre : %s" % _get_chapter_title(ctx))
	lines.append("Scène : %s" % _get_scene_title(ctx))
	lines.append("Séquence : %s" % _get_sequence_title(ctx))
	return "\n".join(lines)


func _build_mail_body(ctx: RefCounted, comment: String) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Commentaire du joueur :")
	lines.append(comment)
	lines.append("")
	lines.append(_build_system_info(ctx))
	return "\n".join(lines)


func _build_mail_subject(ctx: RefCounted) -> String:
	var story_title := ""
	var story_version := ""
	if ctx.story != null:
		story_title = ctx.story.title if ctx.story.get("title") != null else ""
		story_version = ctx.story.version if ctx.story.get("version") != null else ""
	return "[Bug Report] %s v%s" % [story_title, story_version]


func _build_mailto_url(ctx: RefCounted, comment: String) -> String:
	var subject := _build_mail_subject(ctx)
	var body := _build_mail_body(ctx, comment)
	return "mailto:%s?subject=%s&body=%s" % [
		_uri_encode(_email),
		_uri_encode(subject),
		_uri_encode(body),
	]


static func _uri_encode(text: String) -> String:
	return text.uri_encode()


# ── Configuration éditeur ────────────────────────────────────────────────────

func _create_editor_config(plugin_settings: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Bug Report — Configuration"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	var lbl := Label.new()
	lbl.text = "Email de destination :"
	hbox.add_child(lbl)

	var email_input := LineEdit.new()
	email_input.text = plugin_settings.get("email", "")
	email_input.placeholder_text = "bugs@example.com"
	email_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(email_input)

	var read_config := func() -> Dictionary:
		return {"email": email_input.text.strip_edges()}
	vbox.set_meta("read_config", read_config)

	return vbox
