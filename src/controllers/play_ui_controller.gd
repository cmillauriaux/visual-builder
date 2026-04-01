extends Node

## Gère les éléments UI spécifiques au mode Play : overlay de dialogue,
## machine à écrire, et affichage des choix.

const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

var _main: Control


func setup(main: Control) -> void:
	_main = main
	EventBus.play_dialogue_changed.connect(_on_play_dialogue_changed)
	EventBus.play_typewriter_tick.connect(_on_play_typewriter_tick)
	EventBus.play_choice_requested.connect(_on_play_choice_requested)
	EventBus.play_finished.connect(_on_play_finished)


func _on_play_dialogue_changed(character: String, text: String, _index: int) -> void:
	_main._play_character_label.text = character
	_main._play_character_box.visible = character != ""
	_main._play_text_label.text = text
	_main._play_text_label.visible_characters = 0


func _on_play_typewriter_tick(visible_chars: int) -> void:
	_main._play_text_label.visible_characters = visible_chars


func _on_play_choice_requested(choices: Array) -> void:
	_hide_choice_overlay()
	var container = VBoxContainer.new()
	container.name = "ChoiceVBox"
	var title = Label.new()
	title.text = "Faites votre choix"  # Fallback — traduit via StoryI18nService dans game mode
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	container.add_child(title)
	for i in range(choices.size()):
		var btn = Button.new()
		btn.text = choices[i].text
		var idx = i
		btn.pressed.connect(func(): _on_play_choice_selected(idx))
		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
				btn.accept_event()
		)
		container.add_child(btn)
	_main._choice_panel.add_child(container)
	_main._choice_overlay.visible = true
	if not _main._choice_overlay.get_parent():
		_main._visual_editor._overlay_container.add_child(_main._choice_overlay)


func _on_play_choice_selected(index: int) -> void:
	_hide_choice_overlay()
	_main._play_ctrl.on_choice_selected(index)


func _on_play_finished(reason: String) -> void:
	_hide_choice_overlay()
	var messages = {
		"game_over": "Fin de la lecture — Game Over",
		"to_be_continued": "Fin de la lecture — À suivre...",
		"no_ending": "Fin de la lecture (aucune terminaison configurée)",
		"error": "Fin de la lecture — Erreur (cible introuvable ou contenu vide)",
		"stopped": "Lecture arrêtée",
	}
	var raw_msg = messages.get(reason, "Fin de la lecture")
	var dialog = AcceptDialog.new()
	dialog.dialog_text = raw_msg  # Traduit via StoryI18nService dans game mode
	dialog.confirmed.connect(dialog.queue_free)
	_main.add_child(dialog)
	if dialog.is_inside_tree():
		dialog.popup_centered()


func _hide_choice_overlay() -> void:
	_main._choice_overlay.visible = false
	for child in _main._choice_panel.get_children():
		child.queue_free()
	if _main._choice_overlay.get_parent():
		_main._choice_overlay.get_parent().remove_child(_main._choice_overlay)
