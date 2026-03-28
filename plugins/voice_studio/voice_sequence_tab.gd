extends VBoxContainer

## Onglet "Voix" dans l'éditeur de séquence.
## Sliders voice_settings, sélecteur de langue, génération par dialogue
## avec previous_text/next_text et previous_request_ids pour la continuité.

const ElevenLabsConfig = preload("res://plugins/voice_studio/elevenlabs_config.gd")
const ElevenLabsClient = preload("res://plugins/voice_studio/elevenlabs_client.gd")
const GamePlugin = preload("res://plugins/voice_studio/game_plugin.gd")

var _ctx = null  # PluginContext
var _config: RefCounted = null
var _client: Node = null
var _dialogue_rows: Array = []
var _generate_all_btn: Button = null
var _status_label: Label = null
var _scroll: ScrollContainer = null
var _list_container: VBoxContainer = null
var _lang_selector: OptionButton = null
var _pending_generation: Array = []

# Voice settings sliders (override defaults from config)
var _slider_stability: HSlider = null
var _slider_similarity: HSlider = null
var _slider_style: HSlider = null
var _slider_speed: HSlider = null
var _check_boost: CheckButton = null

signal voice_changed()


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	_config = ElevenLabsConfig.new()
	_config.load_from()

	# ── Language selector ─────────────────────────────────────────────────────
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

	# ── Voice settings sliders ────────────────────────────────────────────────
	_slider_stability = _add_slider("Stability :", _config.get_stability(), 0.0, 1.0, 0.01)
	_slider_similarity = _add_slider("Similarity :", _config.get_similarity_boost(), 0.0, 1.0, 0.01)
	_slider_style = _add_slider("Style :", _config.get_style(), 0.0, 1.0, 0.01)
	_slider_speed = _add_slider("Speed :", _config.get_speed(), 0.5, 2.0, 0.05)

	var boost_row := HBoxContainer.new()
	boost_row.add_theme_constant_override("separation", 4)
	add_child(boost_row)
	var boost_lbl := Label.new()
	boost_lbl.text = "Speaker Boost :"
	boost_lbl.custom_minimum_size = Vector2(85, 0)
	boost_row.add_child(boost_lbl)
	_check_boost = CheckButton.new()
	_check_boost.button_pressed = _config.get_use_speaker_boost()
	boost_row.add_child(_check_boost)

	add_child(HSeparator.new())

	# ── Generate all button ───────────────────────────────────────────────────
	_generate_all_btn = Button.new()
	_generate_all_btn.text = tr("Générer toutes les voix de la séquence")
	_generate_all_btn.pressed.connect(_on_generate_all_pressed)
	add_child(_generate_all_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", 11)
	add_child(_status_label)

	add_child(HSeparator.new())

	# ── Dialogue list ─────────────────────────────────────────────────────────
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	add_child(_scroll)
	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 8)
	_scroll.add_child(_list_container)


func _add_slider(label_text: String, value: float, min_v: float, max_v: float, step: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(85, 0)
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(slider)
	var val_lbl := Label.new()
	val_lbl.text = "%.2f" % value
	val_lbl.custom_minimum_size = Vector2(35, 0)
	val_lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(val_lbl)
	slider.value_changed.connect(func(v: float): val_lbl.text = "%.2f" % v)
	return slider


func _get_voice_settings_override() -> Dictionary:
	return {
		"stability": _slider_stability.value,
		"similarity_boost": _slider_similarity.value,
		"style": _slider_style.value,
		"speed": _slider_speed.value,
		"use_speaker_boost": _check_boost.button_pressed,
	}


func setup(ctx) -> void:
	_ctx = ctx
	_config.load_from()
	# Reset sliders to config defaults
	_slider_stability.value = _config.get_stability()
	_slider_similarity.value = _config.get_similarity_boost()
	_slider_style.value = _config.get_style()
	_slider_speed.value = _config.get_speed()
	_check_boost.button_pressed = _config.get_use_speaker_boost()
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
	if sequence.dialogues.is_empty():
		var lbl := Label.new()
		lbl.text = tr("Aucun dialogue dans cette séquence")
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		_list_container.add_child(lbl)
		return
	for i in range(sequence.dialogues.size()):
		var row := _create_dialogue_row(i, sequence.dialogues[i])
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

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)
	var idx_lbl := Label.new()
	idx_lbl.text = "#%d" % (index + 1)
	idx_lbl.add_theme_font_size_override("font_size", 12)
	idx_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	header.add_child(idx_lbl)
	var char_lbl := Label.new()
	char_lbl.text = dlg.character if dlg.character != "" else tr("(narrateur)")
	char_lbl.add_theme_font_size_override("font_size", 13)
	char_lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.4))
	header.add_child(char_lbl)

	var lang := _get_selected_language()
	var vid := _get_voice_id(dlg.character, lang)
	if vid == "" and dlg.character != "":
		var warn := Label.new()
		warn.text = tr("(pas de Voice ID)")
		warn.add_theme_font_size_override("font_size", 10)
		warn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
		header.add_child(warn)

	var sp := Control.new()
	sp.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(sp)

	var status := Label.new()
	if dlg.voice_file != "" and _voice_file_exists(dlg.voice_file):
		status.text = "✓ " + tr("Voix générée")
		status.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		status.text = "○ " + tr("Pas de voix")
		status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status.add_theme_font_size_override("font_size", 11)
	header.add_child(status)

	# Text preview
	var preview := Label.new()
	preview.text = _truncate(dlg.text, 120)
	preview.add_theme_font_size_override("font_size", 11)
	preview.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(preview)

	# Voice field
	var voice_row := HBoxContainer.new()
	voice_row.add_theme_constant_override("separation", 4)
	vbox.add_child(voice_row)
	var voice_lbl := Label.new()
	voice_lbl.text = tr("Voice :")
	voice_lbl.custom_minimum_size = Vector2(50, 0)
	voice_row.add_child(voice_lbl)
	var voice_edit := TextEdit.new()
	voice_edit.text = dlg.voice
	voice_edit.placeholder_text = tr("[whispers] Texte... [sarcastically] Suite...")
	voice_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	voice_edit.custom_minimum_size = Vector2(0, 40)
	voice_edit.text_changed.connect(func():
		_on_voice_text_changed(index, voice_edit.text)
	)
	voice_row.add_child(voice_edit)

	# File info + request_id
	if dlg.voice_file != "":
		var info := Label.new()
		var info_text: String = dlg.voice_file
		if dlg.voice_request_id != "":
			info_text += " (req: %s)" % _truncate(dlg.voice_request_id, 20)
		info.text = info_text
		info.add_theme_font_size_override("font_size", 10)
		info.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
		vbox.add_child(info)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)
	var gen_btn := Button.new()
	gen_btn.text = tr("Regénérer") if (dlg.voice_file != "" and _voice_file_exists(dlg.voice_file)) else tr("Générer la voix")
	gen_btn.pressed.connect(func(): _on_generate_single(index))
	btn_row.add_child(gen_btn)
	if dlg.voice_file != "" and _voice_file_exists(dlg.voice_file):
		var del_btn := Button.new()
		del_btn.text = tr("Supprimer la voix")
		del_btn.pressed.connect(func(): _on_delete_voice(index))
		btn_row.add_child(del_btn)

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
		_set_status(tr("Erreur : aucun Voice ID pour '%s'. Configurer le jeu > Plugins.") % dlg.character)
		return
	var text_to_speak: String = dlg.voice if dlg.voice != "" else dlg.text
	var prev_text := _get_previous_text(index)
	var next_text := _get_next_text(index)
	var prev_ids := _get_previous_request_ids(index)
	_client.generate_voice(voice_id, text_to_speak, dlg.uuid,
		_get_voice_settings_override(), prev_text, next_text, prev_ids)


func _on_delete_voice(index: int) -> void:
	if _ctx == null or _ctx.current_sequence == null:
		return
	var seq = _ctx.current_sequence
	if index < 0 or index >= seq.dialogues.size():
		return
	var dlg = seq.dialogues[index]
	if dlg.voice_file != "":
		ElevenLabsClient.delete_voice_file(_resolve_voice_path(dlg.voice_file))
		dlg.voice_file = ""
		dlg.voice_request_id = ""
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
	var missing: Array = []
	for dlg in seq.dialogues:
		var cn: String = dlg.character if dlg.character != "" else ""
		if cn != "" and _get_voice_id(cn, lang) == "":
			if cn not in missing:
				missing.append(cn)
	if not missing.is_empty():
		_set_status(tr("Voice ID manquant pour : %s") % ", ".join(missing))
		return

	_pending_generation.clear()
	for i in range(seq.dialogues.size()):
		var dlg = seq.dialogues[i]
		var voice_id := _get_voice_id(dlg.character, lang)
		if voice_id == "":
			continue
		var tts: String = dlg.voice if dlg.voice != "" else dlg.text
		if tts.strip_edges() == "":
			continue
		_pending_generation.append({"index": i, "voice_id": voice_id, "text": tts, "uuid": dlg.uuid})

	if _pending_generation.is_empty():
		_set_status(tr("Rien à générer"))
		return
	_generate_all_btn.disabled = true
	_set_status(tr("Génération 1/%d...") % _pending_generation.size())
	_process_next_in_queue()


func _process_next_in_queue() -> void:
	if _pending_generation.is_empty():
		_generate_all_btn.disabled = false
		_set_status(tr("Toutes les voix ont été générées !"))
		refresh()
		return
	var item: Dictionary = _pending_generation[0]
	var idx: int = item["index"]
	var prev_text := _get_previous_text(idx)
	var next_text := _get_next_text(idx)
	var prev_ids := _get_previous_request_ids(idx)
	_client.generate_voice(item["voice_id"], item["text"], item["uuid"],
		_get_voice_settings_override(), prev_text, next_text, prev_ids)


func _on_generation_completed(mp3_bytes: PackedByteArray, request_id: String, dialogue_uuid: String) -> void:
	if _ctx == null or _ctx.current_sequence == null:
		return
	var seq = _ctx.current_sequence
	var dlg = null
	for d in seq.dialogues:
		if d.uuid == dialogue_uuid:
			dlg = d
			break
	if dlg == null:
		return
	var rel_path := "assets/voices/%s.mp3" % dialogue_uuid
	if ElevenLabsClient.save_mp3(mp3_bytes, _resolve_voice_path(rel_path)):
		dlg.voice_file = rel_path
		dlg.voice_request_id = request_id
		voice_changed.emit()
		_set_status(tr("Voix générée pour '%s'") % dlg.character)
	else:
		_set_status(tr("Erreur sauvegarde pour '%s'") % dlg.character)

	if not _pending_generation.is_empty():
		_pending_generation.remove_at(0)
		if not _pending_generation.is_empty():
			var total: int = _pending_generation.size()
			_set_status(tr("Génération... %d restant(s)") % total)
			_process_next_in_queue()
		else:
			_generate_all_btn.disabled = false
			_set_status(tr("Toutes les voix ont été générées !"))
			refresh()
	else:
		refresh()


func _on_generation_failed(error: String, _dialogue_uuid: String) -> void:
	_set_status(tr("Erreur : ") + error)
	_pending_generation.clear()
	_generate_all_btn.disabled = false
	refresh()


func _on_generation_progress(status: String, _dialogue_uuid: String) -> void:
	_set_status(status)


# ── Continuity helpers ────────────────────────────────────────────────────────

func _get_previous_text(dialogue_index: int) -> String:
	if _ctx == null or _ctx.current_sequence == null:
		return ""
	var seq = _ctx.current_sequence
	if dialogue_index > 0:
		var prev = seq.dialogues[dialogue_index - 1]
		return prev.voice if prev.voice != "" else prev.text
	# Premier dialogue : chercher le dernier dialogue de la séquence précédente
	var prev_dlg = _get_last_dialogue_before_sequence()
	if prev_dlg != null:
		var v: String = prev_dlg.voice if prev_dlg.voice != "" else prev_dlg.text
		return v
	return ""


func _get_next_text(dialogue_index: int) -> String:
	if _ctx == null or _ctx.current_sequence == null:
		return ""
	var seq = _ctx.current_sequence
	if dialogue_index < seq.dialogues.size() - 1:
		var nxt = seq.dialogues[dialogue_index + 1]
		return nxt.voice if nxt.voice != "" else nxt.text
	return ""


func _get_previous_request_ids(dialogue_index: int) -> Array:
	var ids: Array = []
	if _ctx == null or _ctx.current_sequence == null:
		return ids
	var seq = _ctx.current_sequence
	# Collecter les IDs des dialogues précédents dans la séquence
	var start := maxi(0, dialogue_index - 3)
	for i in range(dialogue_index - 1, start - 1, -1):
		var rid: String = seq.dialogues[i].voice_request_id
		if rid != "":
			ids.append(rid)
		if ids.size() >= 3:
			return ids
	# Si pas assez, chercher dans les séquences/scènes/chapitres précédents
	if ids.size() < 3:
		var prev_ids := _collect_previous_request_ids_from_story(3 - ids.size())
		ids.append_array(prev_ids)
	return ids.slice(0, 3) if ids.size() > 3 else ids


func _get_last_dialogue_before_sequence():
	if _ctx == null or _ctx.current_scene == null or _ctx.current_sequence == null:
		return null
	var scene = _ctx.current_scene
	var found_current := false
	# Parcourir les séquences en ordre inverse pour trouver la précédente
	for i in range(scene.sequences.size() - 1, -1, -1):
		var s = scene.sequences[i]
		if s.uuid == _ctx.current_sequence.uuid:
			found_current = true
			continue
		if found_current and not s.dialogues.is_empty():
			return s.dialogues[s.dialogues.size() - 1]
	return null


func _collect_previous_request_ids_from_story(max_count: int) -> Array:
	var ids: Array = []
	if _ctx == null or _ctx.current_scene == null or _ctx.current_sequence == null:
		return ids
	var scene = _ctx.current_scene
	var found_current := false
	# Chercher dans les séquences précédentes de la scène
	for i in range(scene.sequences.size() - 1, -1, -1):
		var s = scene.sequences[i]
		if s.uuid == _ctx.current_sequence.uuid:
			found_current = true
			continue
		if found_current:
			for j in range(s.dialogues.size() - 1, -1, -1):
				var rid: String = s.dialogues[j].voice_request_id
				if rid != "":
					ids.append(rid)
				if ids.size() >= max_count:
					return ids
	return ids


# ── Utilities ─────────────────────────────────────────────────────────────────

func _get_voice_id(character_name: String, language: String = "") -> String:
	if _ctx == null or _ctx.story == null:
		return ""
	var ps: Dictionary = _ctx.story.plugin_settings.get("voice_studio", {})
	return GamePlugin.get_voice_id_for_character(ps, character_name, language)


func _voice_file_exists(rel_path: String) -> bool:
	if rel_path == "":
		return false
	return FileAccess.file_exists(_resolve_voice_path(rel_path))


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
