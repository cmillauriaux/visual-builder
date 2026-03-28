extends "res://src/plugins/game_plugin.gd"

## Plugin Voice Studio : configuration des voix ElevenLabs par personnage et langue.
## Gère la clé API, le modèle, les paramètres voix par défaut, le format de sortie,
## et les associations personnage/langue/voiceID.

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
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var config := ElevenLabsConfig.new()
	config.load_from()

	# ── API ───────────────────────────────────────────────────────────────────
	_add_section_title(vbox, "API")

	_add_line_edit_row(vbox, "Clé API :", config.get_api_key(), "sk_...", true,
		func(t: String): config.set_api_key(t); config.save_to())

	_add_line_edit_row(vbox, "Modèle :", config.get_model_id(), "eleven_v3", false,
		func(t: String): config.set_model_id(t); config.save_to())

	_add_line_edit_row(vbox, "Langue API :", config.get_language_code(), "fr, en, es...", false,
		func(t: String): config.set_language_code(t.strip_edges()); config.save_to())

	# Format de sortie
	var fmt_row := HBoxContainer.new()
	fmt_row.add_theme_constant_override("separation", 4)
	vbox.add_child(fmt_row)
	var fmt_label := Label.new()
	fmt_label.text = "Format :"
	fmt_label.custom_minimum_size = Vector2(100, 0)
	fmt_row.add_child(fmt_label)
	var fmt_select := OptionButton.new()
	fmt_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_fmt := config.get_output_format()
	var fmt_idx := 0
	for i in range(ElevenLabsConfig.OUTPUT_FORMATS.size()):
		fmt_select.add_item(ElevenLabsConfig.OUTPUT_FORMATS[i])
		if ElevenLabsConfig.OUTPUT_FORMATS[i] == current_fmt:
			fmt_idx = i
	fmt_select.selected = fmt_idx
	fmt_select.item_selected.connect(func(idx: int):
		config.set_output_format(ElevenLabsConfig.OUTPUT_FORMATS[idx])
		config.save_to()
	)
	fmt_row.add_child(fmt_select)

	var note := Label.new()
	note.text = "(Clé API et paramètres stockés localement, pas dans la story)"
	note.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	note.add_theme_font_size_override("font_size", 10)
	vbox.add_child(note)

	vbox.add_child(HSeparator.new())

	# ── Voice Settings (defaults) ─────────────────────────────────────────────
	_add_section_title(vbox, "Paramètres voix par défaut")

	_add_slider_row(vbox, "Stability :", config.get_stability(), 0.0, 1.0, 0.01,
		func(v: float): config.set_stability(v); config.save_to())

	_add_slider_row(vbox, "Similarity :", config.get_similarity_boost(), 0.0, 1.0, 0.01,
		func(v: float): config.set_similarity_boost(v); config.save_to())

	_add_slider_row(vbox, "Style :", config.get_style(), 0.0, 1.0, 0.01,
		func(v: float): config.set_style(v); config.save_to())

	_add_slider_row(vbox, "Speed :", config.get_speed(), 0.5, 2.0, 0.05,
		func(v: float): config.set_speed(v); config.save_to())

	var boost_row := HBoxContainer.new()
	boost_row.add_theme_constant_override("separation", 4)
	vbox.add_child(boost_row)
	var boost_label := Label.new()
	boost_label.text = "Speaker Boost :"
	boost_label.custom_minimum_size = Vector2(100, 0)
	boost_row.add_child(boost_label)
	var boost_check := CheckButton.new()
	boost_check.button_pressed = config.get_use_speaker_boost()
	boost_check.toggled.connect(func(v: bool):
		config.set_use_speaker_boost(v)
		config.save_to()
	)
	boost_row.add_child(boost_check)

	vbox.add_child(HSeparator.new())

	# ── Voix par personnage/langue ────────────────────────────────────────────
	_add_section_title(vbox, "Voix par personnage et langue")

	var voices_desc := Label.new()
	voices_desc.text = "Associez un Voice ID ElevenLabs à chaque couple personnage / langue."
	voices_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	voices_desc.add_theme_font_size_override("font_size", 11)
	vbox.add_child(voices_desc)

	# Header
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	vbox.add_child(header_row)
	for col in ["Personnage", "Langue", "Voice ID"]:
		var lbl := Label.new()
		lbl.text = col
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		header_row.add_child(lbl)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(30, 0)
	header_row.add_child(spacer)

	var list_container := VBoxContainer.new()
	list_container.name = "VoiceList"
	list_container.add_theme_constant_override("separation", 4)
	vbox.add_child(list_container)

	var voices: Array = plugin_settings.get("voices", [])

	var add_row := func(char_name: String, language: String, voice_id: String) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var n := LineEdit.new()
		n.text = char_name
		n.placeholder_text = "Personnage"
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var l := LineEdit.new()
		l.text = language
		l.placeholder_text = "fr, en..."
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var v := LineEdit.new()
		v.text = voice_id
		v.placeholder_text = "Voice ID"
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var rm := Button.new()
		rm.text = "✕"
		rm.pressed.connect(func(): row.queue_free())
		row.add_child(rm)
		list_container.add_child(row)

	for entry in voices:
		if entry is Dictionary:
			add_row.call(entry.get("character", ""), entry.get("language", ""), entry.get("voice_id", ""))

	var add_btn := Button.new()
	add_btn.text = "+ Ajouter une voix"
	add_btn.pressed.connect(func(): add_row.call("", "", ""))
	vbox.add_child(add_btn)

	# Read config (only voices go to plugin_settings, API config is in user://)
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
				result_voices.append({"character": inputs[0], "language": inputs[1], "voice_id": inputs[2]})
		return {"voices": result_voices}

	vbox.set_meta("read_config", read_config)
	return vbox


# ── UI Helpers ────────────────────────────────────────────────────────────────

static func _add_section_title(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = "Voice Studio — " + text
	lbl.add_theme_font_size_override("font_size", 14)
	parent.add_child(lbl)


static func _add_line_edit_row(parent: Control, label_text: String, value: String,
		placeholder: String, secret: bool, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(100, 0)
	row.add_child(lbl)
	var input := LineEdit.new()
	input.text = value
	input.placeholder_text = placeholder
	input.secret = secret
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.text_changed.connect(on_change)
	row.add_child(input)


static func _add_slider_row(parent: Control, label_text: String, value: float,
		min_val: float, max_val: float, step: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(100, 0)
	row.add_child(lbl)
	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var val_label := Label.new()
	val_label.text = "%.2f" % value
	val_label.custom_minimum_size = Vector2(40, 0)
	row.add_child(val_label)
	slider.value_changed.connect(func(v: float):
		val_label.text = "%.2f" % v
		on_change.call(v)
	)


## Retourne le voice_id associé à un personnage + langue, ou "" si non trouvé.
static func get_voice_id_for_character(plugin_settings: Dictionary, character_name: String, language: String = "") -> String:
	var voices: Array = plugin_settings.get("voices", [])
	if language != "":
		for entry in voices:
			if entry is Dictionary and entry.get("character", "") == character_name and entry.get("language", "") == language:
				return entry.get("voice_id", "")
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
