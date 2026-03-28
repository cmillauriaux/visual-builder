extends "res://src/plugins/editor_plugin.gd"

## Plugin Voice Studio : intégration ElevenLabs pour la génération de voix.
## Ajoute un onglet "Voix" dans l'éditeur de séquence pour gérer
## la synthèse vocale de chaque dialogue.

const VoiceSequenceTab = preload("res://plugins/voice_studio/voice_sequence_tab.gd")
const Contributions = preload("res://src/plugins/contributions.gd")


func get_plugin_name() -> String:
	return "voice_studio"


func get_sequence_tabs() -> Array:
	var tab_def := Contributions.SequenceTabDef.new()
	tab_def.title = "Voix"
	tab_def.create_tab = func(ctx) -> Control:
		var tab := VBoxContainer.new()
		tab.set_script(VoiceSequenceTab)
		return tab
	return [tab_def]
