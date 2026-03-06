extends Control

## Grille de sauvegarde/chargement.
## Mode "save" : cliquer un slot sauvegarde la partie (confirmation si slot occupé).
## Mode "load" : trois onglets (manuelles, automatiques, rapides) avec boutons Charger et Supprimer.

const GameSaveManager = preload("res://src/persistence/game_save_manager.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")

signal save_slot_pressed(index: int)
signal load_slot_pressed(index: int)
signal delete_slot_pressed(index: int)
signal close_pressed

enum Mode { SAVE, LOAD }

var _mode: int = Mode.LOAD
var _title_label: Label
var _tab_container: TabContainer
var _grid: GridContainer
var _auto_content: VBoxContainer
var _quick_content: VBoxContainer
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
	panel.custom_minimum_size = Vector2(960, 600)
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
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(50, 50)
	close_btn.add_theme_font_size_override("font_size", 24)
	close_btn.pressed.connect(func(): close_pressed.emit())
	GameTheme.apply_close_style(close_btn)
	header.add_child(close_btn)

	# TabContainer pour les trois onglets
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	GameTheme.apply_tab_container_style(_tab_container)
	vbox.add_child(_tab_container)

	# --- Onglet 0 : Sauvegardes manuelles ---
	var manual_scroll := ScrollContainer.new()
	manual_scroll.name = "Sauvegardes"
	manual_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	manual_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(manual_scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	manual_scroll.add_child(_grid)

	# --- Onglet 1 : Sauvegardes automatiques ---
	var auto_scroll := ScrollContainer.new()
	auto_scroll.name = "Automatiques"
	auto_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	auto_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(auto_scroll)

	_auto_content = VBoxContainer.new()
	_auto_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_content.add_theme_constant_override("separation", 16)
	auto_scroll.add_child(_auto_content)

	# --- Onglet 2 : Sauvegarde rapide ---
	var quick_scroll := ScrollContainer.new()
	quick_scroll.name = "Rapides"
	quick_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tab_container.add_child(quick_scroll)

	_quick_content = VBoxContainer.new()
	_quick_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quick_content.add_theme_constant_override("separation", 16)
	quick_scroll.add_child(_quick_content)

	# Overlay de confirmation (caché initialement)
	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.visible = false
	add_child(_confirm_overlay)


func show_as_save_mode() -> void:
	_mode = Mode.SAVE
	_title_label.text = "Sauvegarder"
	_tab_container.tabs_visible = false
	_tab_container.current_tab = 0
	refresh()
	visible = true


func show_as_load_mode() -> void:
	_mode = Mode.LOAD
	_title_label.text = "Charger"
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


func _refresh_manual_saves() -> void:
	while _grid.get_child_count() > 0:
		var child := _grid.get_child(0)
		_grid.remove_child(child)
		child.queue_free()

	var saves := GameSaveManager.list_saves()
	for entry in saves:
		var card := _build_slot_card(entry)
		_grid.add_child(card)


func _refresh_auto_saves() -> void:
	while _auto_content.get_child_count() > 0:
		var child := _auto_content.get_child(0)
		_auto_content.remove_child(child)
		child.queue_free()

	var auto_saves := GameSaveManager.list_autosaves()
	if auto_saves.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Aucune sauvegarde automatique"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color("#C4A882"))
		empty_lbl.add_theme_font_size_override("font_size", 18)
		_auto_content.add_child(empty_lbl)
		return

	for i in range(auto_saves.size()):
		var entry: Dictionary = auto_saves[i]
		var card := _build_autosave_card(entry, i)
		_auto_content.add_child(card)


func _refresh_quick_saves() -> void:
	while _quick_content.get_child_count() > 0:
		var child := _quick_content.get_child(0)
		_quick_content.remove_child(child)
		child.queue_free()

	if GameSaveManager.quicksave_exists():
		var data := GameSaveManager.quickload()
		var card := _build_quicksave_card(data)
		_quick_content.add_child(card)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "Aucune sauvegarde rapide"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", Color("#C4A882"))
		empty_lbl.add_theme_font_size_override("font_size", 18)
		_quick_content.add_child(empty_lbl)


func _build_autosave_card(entry: Dictionary, display_index: int) -> Control:
	var slot_index: int = entry.get("slot_index", 0)
	var data: Dictionary = entry.get("data", {})
	var has_screenshot: bool = entry.get("has_screenshot", false)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(290, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.name = "AutosaveCard_%d" % display_index
	GameTheme.apply_dark_panel_style(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Thumbnail screenshot
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(290, 163)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.name = "AutoThumbnail_%d" % display_index
	if has_screenshot:
		var png_path := GameSaveManager.get_autosave_screenshot_path(slot_index)
		if FileAccess.file_exists(png_path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(png_path))
			if img:
				thumb.texture = ImageTexture.create_from_image(img)
	vbox.add_child(thumb)

	# Infos textuelles
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(info_vbox)

	var chap_label := Label.new()
	chap_label.text = data.get("chapter_name", "")
	chap_label.add_theme_font_size_override("font_size", 13)
	chap_label.add_theme_color_override("font_color", Color("#E8D5B5"))
	chap_label.name = "AutoChapterLabel_%d" % display_index
	info_vbox.add_child(chap_label)

	var scene_label := Label.new()
	scene_label.text = data.get("scene_name", "")
	scene_label.add_theme_font_size_override("font_size", 12)
	scene_label.add_theme_color_override("font_color", Color("#C4A882"))
	scene_label.name = "AutoSceneLabel_%d" % display_index
	info_vbox.add_child(scene_label)

	var date_label := Label.new()
	date_label.text = data.get("timestamp", "")
	date_label.add_theme_font_size_override("font_size", 11)
	date_label.add_theme_color_override("font_color", Color("#A08060"))
	date_label.name = "AutoDateLabel_%d" % display_index
	info_vbox.add_child(date_label)

	# Bouton Charger — index spécial -(slot_index + 2)
	var load_btn := Button.new()
	load_btn.text = "Charger"
	load_btn.name = "AutoLoadButton_%d" % display_index
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var load_index := -(slot_index + 2)
	load_btn.pressed.connect(func(): load_slot_pressed.emit(load_index))
	vbox.add_child(load_btn)

	return card


func _build_quicksave_card(data: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(290, 0)
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.name = "QuicksaveCard"
	GameTheme.apply_dark_panel_style(card)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# Thumbnail screenshot
	var thumb := TextureRect.new()
	thumb.custom_minimum_size = Vector2(290, 163)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumb.name = "QuickThumbnail"
	var png_path := GameSaveManager.QUICKSAVE_DIR + "/screenshot.png"
	if FileAccess.file_exists(png_path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(png_path))
		if img:
			thumb.texture = ImageTexture.create_from_image(img)
	vbox.add_child(thumb)

	# Infos textuelles
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(info_vbox)

	var chap_label := Label.new()
	chap_label.text = data.get("chapter_name", "")
	chap_label.add_theme_font_size_override("font_size", 13)
	chap_label.add_theme_color_override("font_color", Color("#E8D5B5"))
	chap_label.name = "QuickChapterLabel"
	info_vbox.add_child(chap_label)

	var scene_label := Label.new()
	scene_label.text = data.get("scene_name", "")
	scene_label.add_theme_font_size_override("font_size", 12)
	scene_label.add_theme_color_override("font_color", Color("#C4A882"))
	scene_label.name = "QuickSceneLabel"
	info_vbox.add_child(scene_label)

	var date_label := Label.new()
	date_label.text = data.get("timestamp", "")
	date_label.add_theme_font_size_override("font_size", 11)
	date_label.add_theme_color_override("font_color", Color("#A08060"))
	date_label.name = "QuickDateLabel"
	info_vbox.add_child(date_label)

	# Bouton Charger
	var load_btn := Button.new()
	load_btn.text = "Charger"
	load_btn.name = "QuickLoadButton"
	load_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_btn.pressed.connect(func(): load_slot_pressed.emit(-1))
	vbox.add_child(load_btn)

	return card


# --- Construction des cartes ---

func _build_slot_card(entry: Dictionary) -> Control:
	var idx: int = entry.get("slot_index", 0)
	var has_data: bool = entry.get("has_data", false)
	var data: Dictionary = entry.get("data", {})
	var has_screenshot: bool = entry.get("has_screenshot", false)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(290, 0)
	card.name = "Slot_%d" % idx
	GameTheme.apply_dark_panel_style(card)

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
		chap_label.add_theme_color_override("font_color", Color("#E8D5B5"))
		chap_label.name = "ChapterLabel"
		info_vbox.add_child(chap_label)

		var scene_label := Label.new()
		scene_label.text = data.get("scene_name", "")
		scene_label.add_theme_font_size_override("font_size", 12)
		scene_label.add_theme_color_override("font_color", Color("#C4A882"))
		scene_label.name = "SceneLabel"
		info_vbox.add_child(scene_label)

		var date_label := Label.new()
		date_label.text = data.get("timestamp", "")
		date_label.add_theme_font_size_override("font_size", 11)
		date_label.add_theme_color_override("font_color", Color("#A08060"))
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
		GameTheme.apply_danger_style(del_btn)
		btn_row.add_child(del_btn)
	else:
		# Slot vide
		var empty_label := Label.new()
		empty_label.text = "+ Vide"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty_label.add_theme_color_override("font_color", Color("#C4A882"))
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
