extends "res://src/plugins/game_plugin.gd"

## Plugin Voice Studio : configuration des voix ElevenLabs par personnage.
## Permet d'associer un Voice ID ElevenLabs à chaque personnage de la story
## via l'onglet Plugins de "Configurer le jeu".

const GameContributions = preload("res://src/plugins/game_contributions.gd")


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

	var title := Label.new()
	title.text = "Voice Studio — Voix par personnage"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = "Associez un Voice ID ElevenLabs à chaque personnage."
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	desc.add_theme_font_size_override("font_size", 11)
	vbox.add_child(desc)

	# Liste des associations personnage/voiceID
	var list_container := VBoxContainer.new()
	list_container.name = "CharacterVoiceList"
	list_container.add_theme_constant_override("separation", 4)
	vbox.add_child(list_container)

	# Charger les associations existantes
	var characters: Array = plugin_settings.get("characters", [])

	var add_row := func(char_name: String, voice_id: String) -> void:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var name_input := LineEdit.new()
		name_input.text = char_name
		name_input.placeholder_text = "Personnage"
		name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_input)

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

	for entry in characters:
		if entry is Dictionary:
			add_row.call(entry.get("name", ""), entry.get("voice_id", ""))

	# Bouton ajouter
	var add_btn := Button.new()
	add_btn.text = "+ Ajouter un personnage"
	add_btn.pressed.connect(func():
		add_row.call("", "")
	)
	vbox.add_child(add_btn)

	# Fonction de lecture de la config
	var read_config := func() -> Dictionary:
		var chars: Array = []
		for child in list_container.get_children():
			if not is_instance_valid(child) or not child is HBoxContainer:
				continue
			var inputs := []
			for c in child.get_children():
				if c is LineEdit:
					inputs.append(c.text.strip_edges())
			if inputs.size() >= 2 and inputs[0] != "":
				chars.append({"name": inputs[0], "voice_id": inputs[1]})
		return {"characters": chars}

	vbox.set_meta("read_config", read_config)
	return vbox


## Retourne le voice_id associé à un personnage, ou "" si non trouvé.
static func get_voice_id_for_character(plugin_settings: Dictionary, character_name: String) -> String:
	var characters: Array = plugin_settings.get("characters", [])
	for entry in characters:
		if entry is Dictionary and entry.get("name", "") == character_name:
			return entry.get("voice_id", "")
	return ""
