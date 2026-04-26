# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Control

## Grille de sauvegarde/chargement.
## Mode "save" : cliquer un slot sauvegarde la partie (confirmation si slot occupé).
## Mode "load" : trois onglets (manuelles, automatiques, rapides) avec boutons Charger et Supprimer.

const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")
const UIScale = preload("res://src/ui/themes/ui_scale.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

var _i18n_dict: Dictionary = {}

signal save_slot_pressed(index: int)
signal load_slot_pressed(index: int)
signal delete_slot_pressed(index: int)
signal close_pressed

enum Mode { SAVE, LOAD }

var _mode: int = Mode.LOAD
var _title_label: Label
var _tab_container: TabContainer
var _grid: GridContainer
var _auto_content: GridContainer
var _quick_content: GridContainer
var _overlay: ColorRect
var _confirm_overlay: Control
var _close_btn: Button


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
	panel.custom_minimum_size = Vector2(UIScale.scale(960), UIScale.scale(600))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIScale.scale(16))
	panel.add_child(vbox)

	# En-tête : titre + bouton fermer
	var header := HBoxContainer.new()
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = StoryI18nService.get_ui_string("Sauvegardes", _i18n_dict)
	_title_label.add_theme_font_size_override("font_size", UIScale.scale(40))
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_close_btn = Button.new()
	_close_btn.icon = GameTheme.create_close_icon(UIScale.scale(24), Color.WHITE)
	_close_btn.text = ""
	_close_btn.custom_minimum_size = Vector2(UIScale.scale(50), UIScale.scale(50))
	_close_btn.pressed.connect(func(): close_pressed.emit())
	GameTheme.apply_close_style(_close_btn)
	header.add_child(_close_btn)

	# TabContainer pour les trois onglets
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameTheme.apply_tab_container_style(_tab_container)
	vbox.add_child(_tab_container)

	# --- Onglet 0 : Sauvegardes manuelles ---
	var manual_scroll := ScrollContainer.new()
	manual_scroll.name = "ManualSaves"
	manual_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	manual_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(manual_scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", UIScale.scale(16))
	_grid.add_theme_constant_override("v_separation", UIScale.scale(16))
	manual_scroll.add_child(_grid)

	# --- Onglet 1 : Sauvegardes automatiques ---
	var auto_scroll := ScrollContainer.new()
	auto_scroll.name = "AutoSaves"
	auto_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	auto_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(auto_scroll)

	_auto_content = GridContainer.new()
	_auto_content.columns = 3
	_auto_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_content.add_theme_constant_override("h_separation", UIScale.scale(16))
	_auto_content.add_theme_constant_override("v_separation", UIScale.scale(16))
	auto_scroll.add_child(_auto_content)

	# --- Onglet 2 : Sauvegarde rapide ---
	var quick_scroll := ScrollContainer.new()
	quick_scroll.name = "QuickSaves"
	quick_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(quick_scroll)

	_quick_content = GridContainer.new()
	_quick_content.columns = 3
	_quick_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quick_content.add_theme_constant_override("h_separation", UIScale.scale(16))
	_quick_content.add_theme_constant_override("v_separation", UIScale.scale(16))
	quick_scroll.add_child(_quick_content)

	# Appliquer les titres d'onglets (traductibles)
	_tab_container.set_tab_title(0, StoryI18nService.get_ui_string("Sauvegardes", _i18n_dict))
	_tab_container.set_tab_title(1, StoryI18nService.get_ui_string("Automatiques", _i18n_dict))
	_tab_container.set_tab_title(2, StoryI18nService.get_ui_string("Rapides", _i18n_dict))

	# Overlay de confirmation (caché initialement)
	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)


func apply_ui_translations(i18n_dict: Dictionary) -> void:
	_i18n_dict = i18n_dict


func show_as_save_mode() -> void:
	_mode = Mode.SAVE
	_title_label.text = StoryI18nService.get_ui_string("Sauvegarder", _i18n_dict)
	_tab_container.tabs_visible = false
	_tab_container.current_tab = 0
	refresh()
	visible = true


func show_as_load_mode() -> void:
	_mode = Mode.LOAD
	_title_label.text = StoryI18nService.get_ui_string("Charger", _i18n_dict)
	_tab_container.tabs_visible = true
	refresh()
	visible = true


func hide_menu() -> void:
	visible = false
	_confirm_overlay.visible = false


## Recharge la liste des sauvegardes depuis le disque.
func refresh() -> void:
	_refresh_manual_saves()
	_refresh_auto_saves()
	_refresh_quick_saves()


func get_title_text() -> String:
	return _title_label.text if _title_label else ""


func apply_custom_theme(story_ui_path: String) -> void:
	if _close_btn:
		GameTheme.apply_close_style(_close_btn, story_ui_path)


func _refresh_manual_saves() -> void:
	while _grid.get_child_count() > 0:
		var child := _grid.get_child(0)
		_grid.remove_child(child)
		child.queue_free()

	var saves := GameSaveManager.list_saves()
	for entry in saves:
		var card := _build_card(entry, "manual")
		_grid.add_child(card)


func _refresh_auto_saves() -> void:
	while _auto_content.get_child_count() > 0:
		var child := _auto_content.get_child(0)
		_auto_content.remove_child(child)
		child.queue_free()

	var auto_saves := GameSaveManager.list_autosaves()
	if auto_saves.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = StoryI18nService.get_ui_string("Aucune sauvegarde automatique", _i18n_dict)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color("#C4A882"))
		empty_lbl.add_theme_font_size_override("font_size", UIScale.scale(24))
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_auto_content.add_child(empty_lbl)
		return

	for i in range(auto_saves.size()):
		var entry: Dictionary = auto_saves[i].duplicate()
		entry["display_index"] = i
		var card := _build_card(entry, "auto")
		_auto_content.add_child(card)


func _refresh_quick_saves() -> void:
	while _quick_content.get_child_count() > 0:
		var child := _quick_content.get_child(0)
		_quick_content.remove_child(child)
		child.queue_free()

	if GameSaveManager.quicksave_exists():
		var data := GameSaveManager.quickload()
		var entry := {
			"data": data,
			"has_screenshot": true,
			"has_data": true
		}
		var card := _build_card(entry, "quick")
		_quick_content.add_child(card)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = StoryI18nService.get_ui_string("Aucune sauvegarde rapide", _i18n_dict)
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color("#C4A882"))
		empty_lbl.add_theme_font_size_override("font_size", UIScale.scale(24))
		empty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_quick_content.add_child(empty_lbl)


func _build_card(entry: Dictionary, type: String) -> Control:
	var slot_index: int = entry.get("slot_index", 0)
	var has_data: bool = entry.get("has_data", true)
	var data: Dictionary = entry.get("data", {})
	var has_screenshot: bool = entry.get("has_screenshot", false)
	var display_index: int = entry.get("display_index", slot_index)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# On utilise une largeur minimum raisonnable mais on laisse expand
	card.custom_minimum_size = Vector2(UIScale.scale(200), 0)
	
	match type:
		"manual": card.name = "Slot_%d" % slot_index
		"auto": card.name = "AutosaveCard_%d" % display_index
		"quick": card.name = "QuicksaveCard"
	
	GameTheme.apply_dark_panel_style(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIScale.scale(6))
	card.add_child(vbox)

	# Thumbnail screenshot
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(0, UIScale.scale(150))
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	match type:
		"manual": thumb.name = "Thumbnail"
		"auto": thumb.name = "AutoThumbnail_%d" % display_index
		"quick": thumb.name = "QuickThumbnail"

	if has_data and has_screenshot:
		var png_path := ""
		match type:
			"manual": png_path = GameSaveManager.get_screenshot_path(slot_index)
			"auto": png_path = GameSaveManager.get_autosave_screenshot_path(slot_index)
			"quick": png_path = GameSaveManager.QUICKSAVE_DIR + "/screenshot.png"
		
		if FileAccess.file_exists(png_path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(png_path))
			if img:
				thumb.texture = ImageTexture.create_from_image(img)
	
	vbox.add_child(thumb)

	if has_data:
		# Infos textuelles
		var info_vbox := VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", UIScale.scale(2))
		vbox.add_child(info_vbox)

		var chap_label := Label.new()
		chap_label.text = data.get("chapter_name", "")
		chap_label.add_theme_font_size_override("font_size", UIScale.scale(18))
		chap_label.add_theme_color_override("font_color", Color("#E8D5B5"))
		chap_label.name = "ChapterLabel"
		if type == "auto": chap_label.name = "AutoChapterLabel_%d" % display_index
		elif type == "quick": chap_label.name = "QuickChapterLabel"
		info_vbox.add_child(chap_label)

		var scene_label := Label.new()
		scene_label.text = data.get("scene_name", "")
		scene_label.add_theme_font_size_override("font_size", UIScale.scale(16))
		scene_label.add_theme_color_override("font_color", Color("#C4A882"))
		scene_label.name = "SceneLabel"
		if type == "auto": scene_label.name = "AutoSceneLabel_%d" % display_index
		elif type == "quick": scene_label.name = "QuickSceneLabel"
		info_vbox.add_child(scene_label)

		var date_label := Label.new()
		date_label.text = data.get("timestamp", "")
		date_label.add_theme_font_size_override("font_size", UIScale.scale(14))
		date_label.add_theme_color_override("font_color", Color("#A08060"))
		date_label.name = "DateLabel"
		if type == "auto": date_label.name = "AutoDateLabel_%d" % display_index
		elif type == "quick": date_label.name = "QuickDateLabel"
		info_vbox.add_child(date_label)

		# Boutons d'action
		var btn_row := HBoxContainer.new()
		btn_row.add_theme_constant_override("separation", UIScale.scale(8))
		vbox.add_child(btn_row)

		if type == "manual":
			if _mode == Mode.SAVE:
				var save_btn := Button.new()
				save_btn.text = StoryI18nService.get_ui_string("Écraser", _i18n_dict)
				save_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				save_btn.pressed.connect(func(): _on_save_occupied_slot(slot_index))
				btn_row.add_child(save_btn)
			else:
				var load_btn := Button.new()
				load_btn.text = StoryI18nService.get_ui_string("Charger", _i18n_dict)
				load_btn.name = "LoadButton"
				load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				load_btn.pressed.connect(func(): load_slot_pressed.emit(slot_index))
				btn_row.add_child(load_btn)

			var del_btn := Button.new()
			del_btn.text = StoryI18nService.get_ui_string("Supprimer", _i18n_dict)
			del_btn.name = "DeleteButton"
			del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			del_btn.pressed.connect(func(): _on_delete_slot(slot_index))
			GameTheme.apply_danger_style(del_btn)
			btn_row.add_child(del_btn)
		
		elif type == "auto":
			var load_btn := Button.new()
			load_btn.text = StoryI18nService.get_ui_string("Charger", _i18n_dict)
			load_btn.name = "AutoLoadButton_%d" % display_index
			load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var load_index := -(slot_index + 2)
			load_btn.pressed.connect(func(): load_slot_pressed.emit(load_index))
			btn_row.add_child(load_btn)
			
		elif type == "quick":
			var load_btn := Button.new()
			load_btn.text = StoryI18nService.get_ui_string("Charger", _i18n_dict)
			load_btn.name = "QuickLoadButton"
			load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			load_btn.pressed.connect(func(): load_slot_pressed.emit(-1))
			btn_row.add_child(load_btn)

	else:
		# Slot vide (uniquement pour manual)
		var empty_label := Label.new()
		empty_label.text = StoryI18nService.get_ui_string("+ Vide", _i18n_dict)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_color_override("font_color", Color("#C4A882"))
		empty_label.add_theme_font_size_override("font_size", UIScale.scale(20))
		empty_label.name = "EmptyLabel"
		vbox.add_child(empty_label)

		if _mode == Mode.SAVE:
			var save_btn := Button.new()
			save_btn.text = StoryI18nService.get_ui_string("Sauvegarder ici", _i18n_dict)
			save_btn.name = "SaveButton"
			save_btn.pressed.connect(func(): save_slot_pressed.emit(slot_index))
			vbox.add_child(save_btn)

	return card


func _on_save_occupied_slot(slot_index: int) -> void:
	_show_confirm_dialog(
		StoryI18nService.get_ui_string("Écraser cette sauvegarde ?", _i18n_dict),
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
	panel.custom_minimum_size = Vector2(UIScale.scale(360), 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIScale.scale(16))
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = message
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", UIScale.scale(24))
	vbox.add_child(lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", UIScale.scale(16))
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var yes_btn := Button.new()
	yes_btn.text = StoryI18nService.get_ui_string("Oui", _i18n_dict)
	yes_btn.name = "ConfirmYesButton"
	yes_btn.custom_minimum_size = Vector2(UIScale.scale(120), UIScale.scale(44))
	yes_btn.pressed.connect(on_yes)
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = StoryI18nService.get_ui_string("Non", _i18n_dict)
	no_btn.name = "ConfirmNoButton"
	no_btn.custom_minimum_size = Vector2(UIScale.scale(120), UIScale.scale(44))
	no_btn.pressed.connect(func(): _confirm_overlay.visible = false)
	btn_row.add_child(no_btn)

	_confirm_overlay.visible = true