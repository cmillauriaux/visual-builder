extends Control

## Grille de sauvegarde/chargement.
## Mode "save" : cliquer un slot sauvegarde la partie (confirmation si slot occupé).
## Mode "load" : boutons Charger et Supprimer par slot.

const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")

signal save_slot_pressed(index: int)
signal load_slot_pressed(index: int)
signal delete_slot_pressed(index: int)
signal close_pressed

enum Mode { SAVE, LOAD }

var _mode: int = Mode.LOAD
var _title_label: Label
var _grid: GridContainer
var _overlay: ColorRect
var _confirm_overlay: Control


func build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	# Fond sombre
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.75)
	add_child(_overlay)

	# Conteneur global (centré verticalement)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(960, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# En-tête : titre + bouton fermer
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "Sauvegardes"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	var close_btn := Button.new()
	close_btn.text = "×"
	close_btn.custom_minimum_size = Vector2(50, 50)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(func(): close_pressed.emit())
	header.add_child(close_btn)

	# Grille 3 colonnes
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	vbox.add_child(_grid)

	# Overlay de confirmation (caché initialement)
	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)


func show_as_save_mode() -> void:
	_mode = Mode.SAVE
	_title_label.text = "Sauvegarder"
	refresh()
	visible = true


func show_as_load_mode() -> void:
	_mode = Mode.LOAD
	_title_label.text = "Charger"
	refresh()
	visible = true


func hide_menu() -> void:
	visible = false
	_confirm_overlay.visible = false


## Recharge la liste des sauvegardes depuis le disque.
func refresh() -> void:
	while _grid.get_child_count() > 0:
		var child := _grid.get_child(0)
		_grid.remove_child(child)
		child.queue_free()

	var saves := GameSaveManager.list_saves()
	for entry in saves:
		var card := _build_slot_card(entry)
		_grid.add_child(card)


func get_title_text() -> String:
	return _title_label.text if _title_label else ""


# --- Construction des cartes ---

func _build_slot_card(entry: Dictionary) -> Control:
	var idx: int = entry.get("slot_index", 0)
	var has_data: bool = entry.get("has_data", false)
	var data: Dictionary = entry.get("data", {})
	var has_screenshot: bool = entry.get("has_screenshot", false)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(290, 0)
	card.name = "Slot_%d" % idx

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Thumbnail screenshot
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(290, 163)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.name = "Thumbnail"
	if has_data and has_screenshot:
		var img := Image.load_from_file(
			ProjectSettings.globalize_path(GameSaveManager.get_screenshot_path(idx))
		)
		if img:
			thumb.texture = ImageTexture.create_from_image(img)
	vbox.add_child(thumb)

	if has_data:
		# Infos textuelles
		var info_vbox := VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 2)
		vbox.add_child(info_vbox)

		var chap_label := Label.new()
		chap_label.text = data.get("chapter_name", "")
		chap_label.add_theme_font_size_override("font_size", 13)
		chap_label.name = "ChapterLabel"
		info_vbox.add_child(chap_label)

		var scene_label := Label.new()
		scene_label.text = data.get("scene_name", "")
		scene_label.add_theme_font_size_override("font_size", 12)
		scene_label.modulate = Color(0.8, 0.8, 0.8)
		scene_label.name = "SceneLabel"
		info_vbox.add_child(scene_label)

		var date_label := Label.new()
		date_label.text = data.get("timestamp", "")
		date_label.add_theme_font_size_override("font_size", 11)
		date_label.modulate = Color(0.65, 0.65, 0.65)
		date_label.name = "DateLabel"
		info_vbox.add_child(date_label)

		# Boutons d'action
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", 8)
		vbox.add_child(btn_row)

		if _mode == Mode.SAVE:
			var save_btn := Button.new()
			save_btn.text = "Écraser"
			save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			save_btn.pressed.connect(func(): _on_save_occupied_slot(idx))
			btn_row.add_child(save_btn)
		else:
			var load_btn := Button.new()
			load_btn.text = "Charger"
			load_btn.name = "LoadButton"
			load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			load_btn.pressed.connect(func(): load_slot_pressed.emit(idx))
			btn_row.add_child(load_btn)

		var del_btn := Button.new()
		del_btn.text = "Supprimer"
		del_btn.name = "DeleteButton"
		del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		del_btn.pressed.connect(func(): _on_delete_slot(idx))
		btn_row.add_child(del_btn)
	else:
		# Slot vide
		var empty_label := Label.new()
		empty_label.text = "+ Vide"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.name = "EmptyLabel"
		vbox.add_child(empty_label)

		if _mode == Mode.SAVE:
			var save_btn := Button.new()
			save_btn.text = "Sauvegarder ici"
			save_btn.name = "SaveButton"
			save_btn.pressed.connect(func(): save_slot_pressed.emit(idx))
			vbox.add_child(save_btn)

	return card


func _on_save_occupied_slot(slot_index: int) -> void:
	_show_confirm_dialog(
		"Écraser cette sauvegarde ?",
		func(): _on_confirm_overwrite(slot_index)
	)


func _on_confirm_overwrite(slot_index: int) -> void:
	_confirm_overlay.visible = false
	save_slot_pressed.emit(slot_index)


func _on_delete_slot(slot_index: int) -> void:
	delete_slot_pressed.emit(slot_index)
	refresh()


func _show_confirm_dialog(message: String, on_yes: Callable) -> void:
	# Nettoyer un éventuel dialog précédent
	for child in _confirm_overlay.get_children():
		child.queue_free()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.5)
	_confirm_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	vbox.add_child(lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var yes_btn := Button.new()
	yes_btn.text = "Oui"
	yes_btn.name = "ConfirmYesButton"
	yes_btn.custom_minimum_size = Vector2(120, 44)
	yes_btn.pressed.connect(on_yes)
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "Non"
	no_btn.name = "ConfirmNoButton"
	no_btn.custom_minimum_size = Vector2(120, 44)
	no_btn.pressed.connect(func(): _confirm_overlay.visible = false)
	btn_row.add_child(no_btn)

	_confirm_overlay.visible = true
