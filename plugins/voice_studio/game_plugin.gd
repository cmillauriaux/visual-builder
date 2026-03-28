extends "res://src/plugins/game_plugin.gd"

## Plugin Voice Studio : configuration des voix ElevenLabs par personnage et langue.
## Permet d'associer un Voice ID ElevenLabs à chaque couple personnage/langue
## via l'onglet Plugins de "Configurer le jeu".
## La clé API et le modèle TTS sont aussi configurés ici (persistés dans user://).

const GameContributions = preload("res://src/plugins/game_contributions.gd")
const ElevenLabsConfig = preload("res://plugins/voice_studio/elevenlabs_config.gd")


func get_plugin_name() -> String:
	return "voice_studio"


func get_plugin_description() -> String:
	return "Voice Studio (ElevenLabs)"


func is_configurable() -> bool:
	return false


func get_plugin_folder() -> String:
	return "voice_studio"


# --- Configuration éditeur (onglet Plugins de Configurer le jeu) ---

func get_editor_config_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_editor_config
	return [def]


func read_editor_config(ctrl: Control) -> Dictionary:
	if ctrl == null or not ctrl.has_meta("read_config"):
		return {}
	return ctrl.get_meta("read_config").call()


func _create_editor_config(plugin_settings: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# ── Section API ──────────────────────────────────────────────────────────
	var api_title := Label.new()
	api_title.text = "Voice Studio — Configuration API"
	api_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(api_title)

	# Clé API (persistée dans user://, pas dans la story)
	var config := ElevenLabsConfig.new()
	config.load_from()

	var api_row := HBoxContainer.new()
	api_row.add_theme_constant_override("separation", 4)
	vbox.add_child(api_row)

	var api_label := Label.new()
	api_label.text = "Clé API :"
	api_label.custom_minimum_size = Vector2(80, 0)
	api_row.add_child(api_label)

	var api_input := LineEdit.new()
	api_input.text = config.get_api_key()
	api_input.secret = true
	api_input.placeholder_text = "sk_..."
	api_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	api_input.text_changed.connect(func(t: String):
		config.set_api_key(t)
		config.save_to()
	)
	api_row.add_child(api_input)

	# Modèle TTS
	var model_row := HBoxContainer.new()
	model_row.add_theme_constant_override("separation", 4)
	vbox.add_child(model_row)

	var model_label := Label.new()
	model_label.text = "Modèle :"
	model_label.custom_minimum_size = Vector2(80, 0)
	model_row.add_child(model_label)

	var model_input := LineEdit.new()
	model_input.text = config.get_model_id()
	model_input.placeholder_text = "eleven_multilingual_v2"
	model_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_input.text_changed.connect(func(t: String):
		config.set_model_id(t)
		config.save_to()
	)
	model_row.add_child(model_input)

	var api_note := Label.new()
	api_note.text = "(La clé API est stockée localement, pas dans la story)"
	api_note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	api_note.add_theme_font_size_override("font_size", 10)
	vbox.add_child(api_note)

	vbox.add_child(HSeparator.new())

	# ── Section Voix par personnage/langue ────────────────────────────────────
	var voices_title := Label.new()
	voices_title.text = "Voix par personnage et langue"
	voices_title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(voices_title)

	var voices_desc := Label.new()
	voices_desc.text = "Associez un Voice ID ElevenLabs à chaque couple personnage / langue."
	voices_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	voices_desc.add_theme_font_size_override("font_size", 11)
	vbox.add_child(voices_desc)

	# En-tête colonnes
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	vbox.add_child(header_row)
	for col_name in ["Personnage", "Langue", "Voice ID"]:
		var lbl := Label.new()
		lbl.text = col_name
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		header_row.add_child(lbl)
	# Spacer pour le bouton ✕
	var header_spacer := Control.new()
	header_spacer.custom_minimum_size = Vector2(30, 0)
	header_row.add_child(header_spacer)

	# Liste des associations
	var list_container := VBoxContainer.new()
	list_container.name = "VoiceList"
	list_container.add_theme_constant_override("separation", 4)
	vbox.add_child(list_container)

	# Charger les associations existantes
	var voices: Array = plugin_settings.get("voices", [])

	var add_row := func(char_name: String, language: String, voice_id: String) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var name_input := LineEdit.new()
		name_input.text = char_name
		name_input.placeholder_text = "Personnage"
		name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_input)

		var lang_input := LineEdit.new()
		lang_input.text = language
		lang_input.placeholder_text = "fr, en, es..."
		lang_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lang_input)

		var id_input := LineEdit.new()
		id_input.text = voice_id
		id_input.placeholder_text = "Voice ID ElevenLabs"
		id_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(id_input)

		var remove_btn := Button.new()
		remove_btn.text = "✕"
		remove_btn.pressed.connect(func():
			row.queue_free()
		)
		row.add_child(remove_btn)

		list_container.add_child(row)

	for entry in voices:
		if entry is Dictionary:
			add_row.call(
				entry.get("character", ""),
				entry.get("language", ""),
				entry.get("voice_id", "")
			)

	# Bouton ajouter
	var add_btn := Button.new()
	add_btn.text = "+ Ajouter une voix"
	add_btn.pressed.connect(func():
		add_row.call("", "", "")
	)
	vbox.add_child(add_btn)

	# Fonction de lecture de la config (clé API exclue — persistée séparément)
	var read_config := func() -> Dictionary:
		var result_voices: Array = []
		for child in list_container.get_children():
			if not is_instance_valid(child) or not child is HBoxContainer:
				continue
			var inputs := []
			for c in child.get_children():
				if c is LineEdit:
					inputs.append(c.text.strip_edges())
			if inputs.size() >= 3 and inputs[0] != "":
				result_voices.append({
					"character": inputs[0],
					"language": inputs[1],
					"voice_id": inputs[2],
				})
		return {"voices": result_voices}

	vbox.set_meta("read_config", read_config)
	return vbox


## Retourne le voice_id associé à un personnage + langue, ou "" si non trouvé.
static func get_voice_id_for_character(plugin_settings: Dictionary, character_name: String, language: String = "") -> String:
	var voices: Array = plugin_settings.get("voices", [])
	# Chercher d'abord avec la langue exacte
	if language != "":
		for entry in voices:
			if entry is Dictionary and entry.get("character", "") == character_name and entry.get("language", "") == language:
				return entry.get("voice_id", "")
	# Fallback : premier match sans filtre de langue
	for entry in voices:
		if entry is Dictionary and entry.get("character", "") == character_name:
			return entry.get("voice_id", "")
	return ""


## Retourne les langues disponibles (uniques) depuis la config.
static func get_available_languages(plugin_settings: Dictionary) -> PackedStringArray:
	var langs := PackedStringArray()
	var voices: Array = plugin_settings.get("voices", [])
	for entry in voices:
		if entry is Dictionary:
			var lang: String = entry.get("language", "")
			if lang != "" and lang not in langs:
				langs.append(lang)
	return langs
