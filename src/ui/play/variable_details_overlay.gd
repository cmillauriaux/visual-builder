# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends CenterContainer

## Overlay plein écran affichant la grille détaillée des variables.

signal close_requested()

const TextureLoaderScript = preload("res://src/ui/shared/texture_loader.gd")
const StoryI18nService = preload("res://src/services/story_i18n_service.gd")

var _grid: GridContainer
var _panel: PanelContainer
var _close_btn: Button
var _i18n: Dictionary = {}


func build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(600, 400)
	add_child(_panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	var title_label = Label.new()
	title_label.text = StoryI18nService.get_ui_string("Détails", _i18n)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 250
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_grid)

	_close_btn = Button.new()
	_close_btn.text = StoryI18nService.get_ui_string("Fermer", _i18n)
	_close_btn.pressed.connect(func(): close_requested.emit())
	vbox.add_child(_close_btn)


func set_i18n(i18n_dict: Dictionary) -> void:
	_i18n = i18n_dict


func show_details(story, variables: Dictionary) -> void:
	if _grid == null:
		return
	# Vider la grille
	for child in _grid.get_children():
		child.queue_free()
	if story == null:
		return
	var display_vars = story.get_details_display_variables()
	for var_def in display_vars:
		if _is_variable_visible(var_def, variables):
			_add_detail_card(var_def, variables)
	visible = true


func hide_details() -> void:
	visible = false


func _is_variable_visible(var_def, variables: Dictionary) -> bool:
	if var_def.visibility_mode == "always":
		return true
	if var_def.visibility_mode == "variable":
		var ctrl_val = str(variables.get(var_def.visibility_variable, "0"))
		return ctrl_val == "1"
	return false


func _add_detail_card(var_def, variables: Dictionary) -> void:
	var card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 4)
	card.custom_minimum_size = Vector2(150, 0)

	# Image
	if var_def.image != "":
		var tex_rect = TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(80, 80)
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tex = TextureLoaderScript.load_texture(var_def.image)
		if tex:
			tex_rect.texture = tex
		card.add_child(tex_rect)

	# Description
	if var_def.description != "":
		var desc_label = Label.new()
		desc_label.text = var_def.description
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.custom_minimum_size.x = 140
		desc_label.add_theme_font_size_override("font_size", 14)
		card.add_child(desc_label)

	# Valeur
	var value = str(variables.get(var_def.var_name, var_def.initial_value))
	var val_label = Label.new()
	val_label.text = value
	val_label.add_theme_font_size_override("font_size", 18)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(val_label)

	_grid.add_child(card)


func get_displayed_count() -> int:
	if _grid == null:
		return 0
	var count := 0
	for child in _grid.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count