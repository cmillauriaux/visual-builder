# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends "res://src/plugins/game_plugin.gd"

## Plugin Bug Report : ajoute un bouton « Bug ? » dans la toolbar
## qui ouvre une fenêtre de rapport de bug envoyé via FormSubmit.co.

const GameContributions = preload("res://src/plugins/game_contributions.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")

const FORMSUBMIT_URL := "https://formsubmit.co/ajax/"

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


func _get_fresh_ctx(ctx: RefCounted) -> RefCounted:
	if ctx.game_node != null and ctx.game_node.has_method("_build_game_plugin_context"):
		return ctx.game_node._build_game_plugin_context()
	return ctx


func _on_bug_button_pressed(ctx: RefCounted) -> void:
	if ctx == null or ctx.game_node == null:
		return
	var fresh_ctx := _get_fresh_ctx(ctx)
	_ctx = fresh_ctx
	_show_bug_report_dialog(fresh_ctx)


func _show_bug_report_dialog(ctx: RefCounted) -> void:
	var game_node: Control = ctx.game_node

	# Cacher le dialogue de jeu pendant le bug report
	var play_overlay: Control = game_node.get("_play_overlay") if game_node != null else null
	var was_play_overlay_visible: bool = play_overlay.visible if play_overlay != null else false
	if play_overlay != null:
		play_overlay.visible = false

	# Overlay sombre plein écran
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game_node.add_child(overlay)

	# Restaurer le dialogue quand l'overlay est supprimé
	overlay.tree_exiting.connect(func():
		if play_overlay != null and is_instance_valid(play_overlay):
			play_overlay.visible = was_play_overlay_visible
	)

	# Centre
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	# Panel thémé
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UIScale.scale(420), 0)
	center.add_child(panel)

	# Contenu
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIScale.scale(10))
	panel.add_child(vbox)

	# Titre
	var title_label := Label.new()
	title_label.text = "Signaler un bug"
	title_label.add_theme_font_size_override("font_size", UIScale.scale(32))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var separator1 := HSeparator.new()
	vbox.add_child(separator1)

	# Instructions
	var instruction_label := Label.new()
	instruction_label.text = "Décrivez le problème rencontré :"
	vbox.add_child(instruction_label)

	# Zone de texte
	var text_edit := TextEdit.new()
	text_edit.placeholder_text = "Décrivez le bug ici..."
	text_edit.custom_minimum_size = Vector2(0, UIScale.scale(100))
	text_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_edit)

	var separator2 := HSeparator.new()
	vbox.add_child(separator2)

	# Infos système
	var info_label := Label.new()
	info_label.text = _build_system_info(ctx)
	info_label.add_theme_color_override("font_color", GameTheme.COLOR_TEXT_SECONDARY)
	info_label.add_theme_font_size_override("font_size", UIScale.scale(16))
	vbox.add_child(info_label)

	# Status label (succès/erreur)
	var status_label := Label.new()
	status_label.name = "StatusLabel"
	status_label.visible = false
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)

	# Boutons
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_hbox.add_theme_constant_override("separation", UIScale.scale(16))
	vbox.add_child(btn_hbox)

	var send_button := Button.new()
	send_button.text = "Envoyer"
	send_button.custom_minimum_size = Vector2(UIScale.scale(140), 0)
	btn_hbox.add_child(send_button)

	var cancel_button := Button.new()
	cancel_button.text = "Annuler"
	cancel_button.custom_minimum_size = Vector2(UIScale.scale(140), 0)
	btn_hbox.add_child(cancel_button)

	# Callbacks
	send_button.pressed.connect(func():
		var comment: String = text_edit.text.strip_edges()
		send_button.disabled = true
		send_button.text = "Envoi en cours..."
		status_label.visible = false
		_send_report(ctx, comment, overlay, send_button, status_label)
	)

	cancel_button.pressed.connect(func():
		overlay.queue_free()
	)

	# Clic sur l'overlay sombre ferme le dialog
	overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Ne fermer que si le clic est hors du panel
			if not panel.get_global_rect().has_point(event.global_position):
				overlay.queue_free()
	)


func _send_report(ctx: RefCounted, comment: String, overlay: Control, send_button: Button, status_label: Label) -> void:
	var http_request := HTTPRequest.new()
	ctx.game_node.add_child(http_request)

	var url := _build_endpoint_url()
	var json_body := _build_json_body(ctx, comment)
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"Origin: https://formsubmit.co",
		"Referer: https://formsubmit.co/",
	])

	print("[BugReport] Sending to: ", url)
	print("[BugReport] Body: ", json_body)

	http_request.request_completed.connect(func(result: int, response_code: int, _resp_headers: PackedStringArray, body: PackedByteArray):
		var body_text := body.get_string_from_utf8()
		print("[BugReport] Result: ", result, " HTTP code: ", response_code)
		print("[BugReport] Response: ", body_text)
		http_request.queue_free()
		var json_response: Dictionary = {}
		if body_text != "":
			var parsed = JSON.parse_string(body_text)
			if parsed is Dictionary:
				json_response = parsed
		var api_success: bool = json_response.get("success", "") == "true"
		if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and api_success:
			status_label.add_theme_color_override("font_color", Color(0.2, 0.6, 0.2))
			status_label.text = "Rapport envoyé ! Merci."
			status_label.visible = true
			send_button.visible = false
			var timer := overlay.get_tree().create_timer(2.0)
			timer.timeout.connect(func():
				if is_instance_valid(overlay):
					overlay.queue_free()
			)
		else:
			var api_message: String = json_response.get("message", "")
			print("[BugReport] ERROR - result: ", result, " code: ", response_code, " message: ", api_message)
			status_label.add_theme_color_override("font_color", Color(0.7, 0.15, 0.15))
			if api_message.contains("Activation"):
				status_label.text = "Formulaire en attente d'activation.\nVérifiez l'email envoyé à l'adresse configurée."
			else:
				status_label.text = "Erreur lors de l'envoi. Veuillez réessayer."
			status_label.visible = true
			send_button.disabled = false
			send_button.text = "Envoyer"
	)

	var err := http_request.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		print("[BugReport] Request failed to start, error: ", err)
		send_button.disabled = false
		send_button.text = "Envoyer"
		status_label.add_theme_color_override("font_color", Color(0.7, 0.15, 0.15))
		status_label.text = "Erreur de connexion."
		status_label.visible = true


func _get_chapter_title(ctx: RefCounted) -> String:
	if ctx.current_chapter != null and ctx.current_chapter.get("chapter_name") != null:
		return ctx.current_chapter.chapter_name
	return "Aucun"


func _get_scene_title(ctx: RefCounted) -> String:
	if ctx.current_scene != null and ctx.current_scene.get("scene_name") != null:
		return ctx.current_scene.scene_name
	return "Aucune"


func _get_sequence_title(ctx: RefCounted) -> String:
	if ctx.current_sequence != null:
		if ctx.current_sequence.get("title") != null and ctx.current_sequence.title != "":
			return ctx.current_sequence.title
		if ctx.current_sequence.get("seq_name") != null and ctx.current_sequence.seq_name != "":
			return ctx.current_sequence.seq_name
		if ctx.current_sequence.get("uuid") != null:
			return ctx.current_sequence.uuid
	return "Aucune"


func _get_os_name() -> String:
	return OS.get_name()


func _get_game_version(ctx: RefCounted) -> String:
	if ctx.story != null and ctx.story.get("version") != null and ctx.story.version != "":
		return ctx.story.version
	return ProjectSettings.get_setting("application/config/version", "inconnue")


func _get_engine_version() -> String:
	return Engine.get_version_info().string


func _build_system_info(ctx: RefCounted) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("--- Informations système ---")
	lines.append("OS : %s" % _get_os_name())
	lines.append("Version du jeu : %s" % _get_game_version(ctx))
	lines.append("Version du moteur : %s" % _get_engine_version())
	lines.append("Chapitre : %s" % _get_chapter_title(ctx))
	lines.append("Scène : %s" % _get_scene_title(ctx))
	lines.append("Séquence : %s" % _get_sequence_title(ctx))
	return "\n".join(lines)


func _build_endpoint_url() -> String:
	return FORMSUBMIT_URL + _email


func _build_json_body(ctx: RefCounted, comment: String) -> String:
	var story_title := ""
	var story_version := ""
	if ctx.story != null:
		story_title = ctx.story.title if ctx.story.get("title") != null else ""
		story_version = ctx.story.version if ctx.story.get("version") != null else ""

	var data := {
		"_subject": "[Bug Report] %s v%s" % [story_title, story_version],
		"_captcha": "false",
		"_template": "box",
		"Commentaire": comment,
		"OS": _get_os_name(),
		"Version du jeu": _get_game_version(ctx),
		"Version du moteur": _get_engine_version(),
		"Chapitre": _get_chapter_title(ctx),
		"Scène": _get_scene_title(ctx),
		"Séquence": _get_sequence_title(ctx),
	}
	return JSON.stringify(data)


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
