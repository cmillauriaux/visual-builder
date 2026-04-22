# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends PanelContainer

## Timeline horizontale des dialogues en bas de l'éditeur de séquence.
## Affiche des vignettes pour chaque dialogue avec mini-aperçu et indicateurs d'héritage.

const DialogueTimelineItemScript = preload("res://src/ui/sequence/dialogue_timeline_item.gd")

var _seq_editor = null
var _items: Array = []
var _hbox: HBoxContainer
var _add_btn: PanelContainer
var _selected_index: int = -1
var _context_menu: PopupMenu
var _context_target_index: int = -1

signal dialogue_clicked(index: int)
signal dialogue_delete_requested(index: int)
signal dialogue_duplicate_requested(index: int)
signal dialogue_insert_before_requested(index: int)
signal dialogue_insert_after_requested(index: int)
signal add_dialogue_requested()
signal foreground_dropped_on_dialogue(fg_data, target_index: int)

func _ready() -> void:
	custom_minimum_size = Vector2(0, 100)

	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_hbox = HBoxContainer.new()
	_hbox.add_theme_constant_override("separation", 6)
	_hbox.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(_hbox)

	# Add dialogue button (always at the end)
	_add_btn = PanelContainer.new()
	_add_btn.custom_minimum_size = Vector2(50, 0)
	_add_btn.mouse_filter = MOUSE_FILTER_STOP
	var add_label = Label.new()
	add_label.text = "+"
	add_label.add_theme_font_size_override("font_size", 20)
	add_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_label.add_theme_color_override("font_color", Color(0.35, 0.35, 0.35))
	_add_btn.add_child(add_label)
	_add_btn.gui_input.connect(_on_add_btn_input)

	# Context menu
	_context_menu = PopupMenu.new()
	_context_menu.add_item(tr("Dupliquer"), 0)
	_context_menu.add_separator()
	_context_menu.add_item(tr("Insérer à gauche"), 1)
	_context_menu.add_item(tr("Insérer à droite"), 2)
	_context_menu.add_separator()
	_context_menu.add_item(tr("Supprimer"), 3)
	_context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(_context_menu)


func setup(seq_editor) -> void:
	_seq_editor = seq_editor
	rebuild()


func rebuild() -> void:
	if _seq_editor == null:
		_clear_items()
		return
	var seq = _seq_editor.get_sequence()
	if seq == null:
		_clear_items()
		return

	var bg_path = seq.background if seq.background else ""
	var dialogues = seq.dialogues
	
	# If number of items changed, it's easier to rebuild
	if _items.size() != dialogues.size():
		_clear_items()
		for i in range(dialogues.size()):
			var dlg = dialogues[i]
			var item = _create_item(i, dlg, bg_path)
			_hbox.add_child(item)
			_items.append(item)
	else:
		# Update existing items
		for i in range(dialogues.size()):
			var dlg = dialogues[i]
			var has_own_fg = dlg.foregrounds.size() > 0
			var effective_fgs = _seq_editor.get_effective_foregrounds(i)
			var fg_count = effective_fgs.size()
			var is_inherited = not has_own_fg and fg_count > 0
			_items[i].setup(i, dlg, is_inherited, fg_count, bg_path, effective_fgs)

	# Re-add the "+" button at the end
	if _add_btn.get_parent():
		_add_btn.get_parent().remove_child(_add_btn)
	_hbox.add_child(_add_btn)

	# Restore selection
	if _selected_index >= 0 and _selected_index < _items.size():
		_items[_selected_index].set_selected(true)


func _create_item(index: int, dlg, bg_path: String) -> DialogueTimelineItemScript:
	var has_own_fg = dlg.foregrounds.size() > 0
	var effective_fgs = _seq_editor.get_effective_foregrounds(index)
	var fg_count = effective_fgs.size()
	var is_inherited = not has_own_fg and fg_count > 0
	var item = DialogueTimelineItemScript.new()
	item.setup(index, dlg, is_inherited, fg_count, bg_path, effective_fgs)
	item.item_clicked.connect(_on_item_clicked)
	item.item_right_clicked.connect(_on_item_right_clicked)
	return item


func update_item(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var seq = _seq_editor.get_sequence()
	if seq == null or index >= seq.dialogues.size():
		return
	var dlg = seq.dialogues[index]
	var bg_path = seq.background if seq.background else ""
	var has_own_fg = dlg.foregrounds.size() > 0
	var effective_fgs = _seq_editor.get_effective_foregrounds(index)
	var fg_count = effective_fgs.size()
	var is_inherited = not has_own_fg and fg_count > 0
	_items[index].setup(index, dlg, is_inherited, fg_count, bg_path, effective_fgs)


func update_item_text(index: int, character: String, text: String) -> void:
	if index < 0 or index >= _items.size():
		return
	_items[index].update_data(character, text)


func select_item(index: int) -> void:
	_selected_index = index
	for i in range(_items.size()):
		if is_instance_valid(_items[i]):
			_items[i].set_selected(i == index)


func highlight_item(index: int) -> void:
	select_item(index)


func _clear_items() -> void:
	for item in _items:
		if is_instance_valid(item):
			item.queue_free()
	_items.clear()
	if _add_btn.get_parent():
		_add_btn.get_parent().remove_child(_add_btn)


func _on_item_clicked(index: int) -> void:
	select_item(index)
	dialogue_clicked.emit(index)


func _on_item_right_clicked(index: int, global_pos: Vector2) -> void:
	_context_target_index = index
	select_item(index)
	dialogue_clicked.emit(index)
	_context_menu.position = Vector2i(global_pos)
	_context_menu.popup()


func _on_context_menu_id_pressed(id: int) -> void:
	if _context_target_index < 0:
		return
	match id:
		0:  # Dupliquer
			dialogue_duplicate_requested.emit(_context_target_index)
		1:  # Insérer à gauche
			dialogue_insert_before_requested.emit(_context_target_index)
		2:  # Insérer à droite
			dialogue_insert_after_requested.emit(_context_target_index)
		3:  # Supprimer
			dialogue_delete_requested.emit(_context_target_index)


func _on_add_btn_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		add_dialogue_requested.emit()


func _on_foreground_dropped(fg_data, target_index: int) -> void:
	foreground_dropped_on_dialogue.emit(fg_data, target_index)


func get_item_count() -> int:
	return _items.size()