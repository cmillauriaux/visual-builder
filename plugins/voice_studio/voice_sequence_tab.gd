extends VBoxContainer

## Onglet "Voix" dans l'éditeur de séquence.
## Affiche pour chaque dialogue : personnage, texte, statut voix,
## champ voice (description ElevenLabs), et boutons générer/supprimer.
## Sélecteur de langue + bouton "Générer toutes les voix" en haut.

const ElevenLabsConfig = preload("res://plugins/voice_studio/elevenlabs_config.gd")
const ElevenLabsClient = preload("res://plugins/voice_studio/elevenlabs_client.gd")
const GamePlugin = preload("res://plugins/voice_studio/game_plugin.gd")

var _ctx = null  # PluginContext
var _config: RefCounted = null
var _client: Node = null
var _dialogue_rows: Array = []  # Array of PanelContainer rows
var _generate_all_btn: Button = null
var _status_label: Label = null
var _scroll: ScrollContainer = null
var _list_container: VBoxContainer = null
var _lang_selector: OptionButton = null
var _pending_generation: Array = []  # Queue for individual generation
var _generating_all: bool = false  # True when using text-to-dialogue for whole sequence

signal voice_changed()


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	# Config ElevenLabs (API key + model persistés dans user://)
	_config = ElevenLabsConfig.new()
	_config.load_from()

	# Language selector row
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", 4)
	add_child(lang_row)

	var lang_label := Label.new()
	lang_label.text = tr("Langue :")
	lang_row.add_child(lang_label)

	_lang_selector = OptionButton.new()
	_lang_selector.size_flags_horizontal = SIZE_EXPAND_FILL
	_lang_selector.item_selected.connect(func(_idx: int): refresh())
	lang_row.add_child(_lang_selector)

	# Bouton Générer toutes les voix
	_generate_all_btn = Button.new()
	_generate_all_btn.text = tr("Générer toutes les voix de la séquence")
	_generate_all_btn.pressed.connect(_on_generate_all_pressed)
	add_child(_generate_all_btn)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	add_child(_status_label)

	add_child(HSeparator.new())

	# Scrollable list of dialogues
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_scroll)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list_container)


func setup(ctx) -> void:
	_ctx = ctx
	# Reload config (may have changed in Configurer le jeu)
	_config.load_from()
	# Create client node
	if _client != null:
		_client.queue_free()
	_client = Node.new()
	_client.set_script(ElevenLabsClient)
	add_child(_client)
	_client.setup(_config)
	_client.generation_completed.connect(_on_generation_completed)
	_client.generation_failed.connect(_on_generation_failed)
	_client.generation_progress.connect(_on_generation_progress)
	_refresh_language_selector()
	refresh()


func _refresh_language_selector() -> void:
	if _lang_selector == null:
		return
	var previous: String = _get_selected_language()
	_lang_selector.clear()
	var langs := _get_available_languages()
	if langs.is_empty():
		_lang_selector.add_item(tr("(aucune langue configurée)"))
		_lang_selector.disabled = true
		return
	_lang_selector.disabled = false
	var select_idx := 0
	for i in range(langs.size()):
		_lang_selector.add_item(langs[i])
		if langs[i] == previous:
			select_idx = i
	_lang_selector.selected = select_idx


func _get_selected_language() -> String:
	if _lang_selector == null or _lang_selector.get_item_count() == 0 or _lang_selector.disabled:
		return ""
	return _lang_selector.get_item_text(_lang_selector.selected)


func _get_available_languages() -> PackedStringArray:
	if _ctx == null or _ctx.story == null:
		return PackedStringArray()
	var ps: Dictionary = _ctx.story.plugin_settings.get("voice_studio", {})
	return GamePlugin.get_available_languages(ps)


func refresh() -> void:
	_dialogue_rows.clear()
	for child in _list_container.get_children():
		child.queue_free()

	if _ctx == null or _ctx.current_sequence == null:
		_status_label.text = tr("Aucune séquence sélectionnée")
		_generate_all_btn.disabled = true
		return

	var sequence = _ctx.current_sequence
	_generate_all_btn.disabled = false

	# Afficher le statut du fichier voix de la séquence (dialogue complet)
	if sequence.voice_file != "" and _voice_file_exists(sequence.voice_file):
		var seq_voice_panel := HBoxContainer.new()
		seq_voice_panel.add_theme_constant_override("separation", 6)
		_list_container.add_child(seq_voice_panel)
		var seq_status := Label.new()
		seq_status.text = "✓ " + tr("Dialogue complet : ") + sequence.voice_file
		seq_status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		seq_status.add_theme_font_size_override("font_size", 11)
		seq_voice_panel.add_child(seq_status)
		var seq_del_btn := Button.new()
		seq_del_btn.text = tr("Supprimer")
		seq_del_btn.pressed.connect(func():
			var abs_path := _resolve_voice_path(sequence.voice_file)
			ElevenLabsClient.delete_voice_file(abs_path)
			sequence.voice_file = ""
			voice_changed.emit()
			refresh()
		)
		seq_voice_panel.add_child(seq_del_btn)
		_list_container.add_child(HSeparator.new())

	if sequence.dialogues.is_empty():
		var empty_label := Label.new()
		empty_label.text = tr("Aucun dialogue dans cette séquence")
		empty_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_list_container.add_child(empty_label)
		return

	for i in range(sequence.dialogues.size()):
		var dlg = sequence.dialogues[i]
		var row := _create_dialogue_row(i, dlg)
		_list_container.add_child(row)
		_dialogue_rows.append(row)


func _create_dialogue_row(index: int, dlg) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.15, 0.8)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Header: index + character + language info
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var index_label := Label.new()
	index_label.text = "#%d" % (index + 1)
	index_label.add_theme_font_size_override("font_size", 12)
	index_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(index_label)

	var char_label := Label.new()
	char_label.text = dlg.character if dlg.character != "" else tr("(narrateur)")
	char_label.add_theme_font_size_override("font_size", 13)
	char_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header.add_child(char_label)

	# Show voice ID match status for selected language
	var selected_lang := _get_selected_language()
	var voice_id := _get_voice_id(dlg.character, selected_lang)
	if voice_id == "" and dlg.character != "":
		var no_voice := Label.new()
		no_voice.text = tr("(pas de Voice ID pour %s)") % selected_lang if selected_lang != "" else tr("(pas de Voice ID)")
		no_voice.add_theme_font_size_override("font_size", 10)
		no_voice.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		header.add_child(no_voice)

	var spacer := Control.new()
	spacer.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(spacer)

	# Voice status indicator
	var status := Label.new()
	status.name = "VoiceStatus"
	if dlg.voice_file != "" and _voice_file_exists(dlg.voice_file):
		status.text = "✓ " + tr("Voix générée")
		status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		status.text = "○ " + tr("Pas de voix")
		status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status.add_theme_font_size_override("font_size", 11)
	header.add_child(status)

	# Dialogue text (read-only preview)
	var text_preview := Label.new()
	text_preview.text = _truncate(dlg.text, 120)
	text_preview.add_theme_font_size_override("font_size", 11)
	text_preview.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	text_preview.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(text_preview)

	# Voice description field
	var voice_row := HBoxContainer.new()
	voice_row.add_theme_constant_override("separation", 4)
	vbox.add_child(voice_row)

	var voice_label := Label.new()
	voice_label.text = tr("Voice :")
	voice_label.custom_minimum_size = Vector2(50, 0)
	voice_row.add_child(voice_label)

	var voice_edit := TextEdit.new()
	voice_edit.name = "VoiceEdit"
	voice_edit.text = dlg.voice
	voice_edit.placeholder_text = tr("Description vocale ElevenLabs (ex: [whispers] Texte... [sarcastically] Suite...)")
	voice_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	voice_edit.custom_minimum_size = Vector2(0, 50)
	voice_edit.text_changed.connect(func():
		_on_voice_text_changed(index, voice_edit.text)
	)
	voice_row.add_child(voice_edit)

	# Voice file info
	if dlg.voice_file != "":
		var file_label := Label.new()
		file_label.text = tr("Fichier : ") + dlg.voice_file
		file_label.add_theme_font_size_override("font_size", 10)
		file_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(file_label)

	# Buttons row
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)

	var generate_btn := Button.new()
	generate_btn.name = "GenerateBtn"
	if dlg.voice_file != "" and _voice_file_exists(dlg.voice_file):
		generate_btn.text = tr("Regénérer")
	else:
		generate_btn.text = tr("Générer la voix")
	generate_btn.pressed.connect(func():
		_on_generate_single(index)
	)
	btn_row.add_child(generate_btn)

	if dlg.voice_file != "" and _voice_file_exists(dlg.voice_file):
		var delete_btn := Button.new()
		delete_btn.text = tr("Supprimer la voix")
		delete_btn.pressed.connect(func():
			_on_delete_voice(index)
		)
		btn_row.add_child(delete_btn)

	return panel


func _on_voice_text_changed(index: int, new_voice: String) -> void:
	if _ctx == null or _ctx.current_sequence == null:
		return
	var seq = _ctx.current_sequence
	if index < 0 or index >= seq.dialogues.size():
		return
	seq.dialogues[index].voice = new_voice
	voice_changed.emit()


func _on_generate_single(index: int) -> void:
	if _ctx == null or _ctx.current_sequence == null:
		return
	var seq = _ctx.current_sequence
	if index < 0 or index >= seq.dialogues.size():
		return

	var dlg = seq.dialogues[index]
	var lang := _get_selected_language()
	var voice_id := _get_voice_id(dlg.character, lang)
	if voice_id == "":
		var msg := tr("Erreur : aucun Voice ID pour '%s'") % dlg.character
		if lang != "":
			msg += tr(" en langue '%s'") % lang
		msg += tr(". Configurez-le dans Configurer le jeu > Plugins.")
		_set_status(msg)
		return

	var text_to_speak: String = dlg.voice if dlg.voice != "" else dlg.text
	_client.generate_voice(voice_id, text_to_speak, dlg.uuid)


func _on_delete_voice(index: int) -> void:
	if _ctx == null or _ctx.current_sequence == null:
		return
	var seq = _ctx.current_sequence
	if index < 0 or index >= seq.dialogues.size():
		return

	var dlg = seq.dialogues[index]
	if dlg.voice_file != "":
		var abs_path := _resolve_voice_path(dlg.voice_file)
		ElevenLabsClient.delete_voice_file(abs_path)
		dlg.voice_file = ""
		voice_changed.emit()
		_set_status(tr("Voix supprimée pour le dialogue #%d") % (index + 1))
		refresh()


func _on_generate_all_pressed() -> void:
	if _ctx == null or _ctx.current_sequence == null:
		return
	var seq = _ctx.current_sequence
	if seq.dialogues.is_empty():
		_set_status(tr("Aucun dialogue à générer"))
		return

	var lang := _get_selected_language()

	# Vérifier que tous les personnages ont un Voice ID pour cette langue
	var missing: Array = []
	for dlg in seq.dialogues:
		var char_name: String = dlg.character if dlg.character != "" else ""
		if char_name != "" and _get_voice_id(char_name, lang) == "":
			if char_name not in missing:
				missing.append(char_name)

	if not missing.is_empty():
		var msg := tr("Erreur : Voice ID manquant pour : %s") % ", ".join(missing)
		if lang != "":
			msg += tr(" (langue: %s)") % lang
		msg += tr(". Configurez-les dans Configurer le jeu > Plugins.")
		_set_status(msg)
		return

	# Construire les inputs pour text-to-dialogue (une seule requête)
	var inputs: Array = []
	for dlg in seq.dialogues:
		var voice_id := _get_voice_id(dlg.character, lang)
		if voice_id == "":
			continue
		var text_to_speak: String = dlg.voice if dlg.voice != "" else dlg.text
		if text_to_speak.strip_edges() == "":
			continue
		inputs.append({"text": text_to_speak, "voice_id": voice_id})

	if inputs.is_empty():
		_set_status(tr("Rien à générer (textes vides)"))
		return

	_generating_all = true
	_set_status(tr("Génération du dialogue complet (%d répliques)...") % inputs.size())
	_generate_all_btn.disabled = true
	_client.generate_dialogue(inputs, seq.uuid)


func _on_generation_completed(mp3_bytes: PackedByteArray, request_id: String) -> void:
	if _ctx == null or _ctx.current_sequence == null:
		return

	var seq = _ctx.current_sequence

	if _generating_all and request_id == seq.uuid:
		# Résultat de "Générer toutes les voix" → fichier séquence
		var rel_path := "assets/voices/sequence_%s.mp3" % seq.uuid
		var abs_path := _resolve_voice_path(rel_path)
		if ElevenLabsClient.save_mp3(mp3_bytes, abs_path):
			seq.voice_file = rel_path
			voice_changed.emit()
			_set_status(tr("Dialogue complet généré !"))
		else:
			_set_status(tr("Erreur sauvegarde fichier séquence"))
		_generating_all = false
		_generate_all_btn.disabled = false
		refresh()
		return

	# Résultat d'une génération individuelle → fichier dialogue
	var dlg = null
	for d in seq.dialogues:
		if d.uuid == request_id:
			dlg = d
			break
	if dlg == null:
		return

	var rel_path := "assets/voices/%s.mp3" % request_id
	var abs_path := _resolve_voice_path(rel_path)
	if ElevenLabsClient.save_mp3(mp3_bytes, abs_path):
		dlg.voice_file = rel_path
		voice_changed.emit()
		_set_status(tr("Voix générée pour '%s'") % dlg.character)
	else:
		_set_status(tr("Erreur sauvegarde fichier pour '%s'") % dlg.character)

	# Traiter la queue (génération individuelle séquentielle)
	if not _pending_generation.is_empty():
		_pending_generation.remove_at(0)
		var remaining := _pending_generation.size()
		if remaining > 0:
			_set_status(tr("Génération en cours... %d restant(s)") % remaining)
			var item = _pending_generation[0]
			_client.generate_voice(item["voice_id"], item["text"], item["uuid"])
		else:
			refresh()
	else:
		refresh()


func _on_generation_failed(error: String, _request_id: String) -> void:
	_set_status(tr("Erreur : ") + error)
	_generating_all = false
	_pending_generation.clear()
	_generate_all_btn.disabled = false
	refresh()


func _on_generation_progress(status: String, _dialogue_uuid: String) -> void:
	_set_status(status)


# --- Utilitaires ---

func _get_voice_id(character_name: String, language: String = "") -> String:
	if _ctx == null or _ctx.story == null:
		return ""
	var ps: Dictionary = _ctx.story.plugin_settings.get("voice_studio", {})
	return GamePlugin.get_voice_id_for_character(ps, character_name, language)


func _voice_file_exists(rel_path: String) -> bool:
	if rel_path == "":
		return false
	var abs_path := _resolve_voice_path(rel_path)
	return FileAccess.file_exists(abs_path)


func _resolve_voice_path(rel_path: String) -> String:
	if rel_path.begins_with("/") or rel_path.begins_with("res://") or rel_path.begins_with("user://"):
		return rel_path
	if _ctx != null and _ctx.story_base_path != "":
		return _ctx.story_base_path + "/" + rel_path
	return rel_path


func _set_status(text: String) -> void:
	if _status_label:
		_status_label.text = text


static func _truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len) + "..."
