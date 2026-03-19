extends Window

## Dialog de normalisation d'images.
## Permet de sélectionner des images, choisir une référence,
## et normaliser la balance des blancs, luminosité et contraste.

const ImageNormalizerService = preload("res://src/services/image_normalizer_service.gd")
const ImagePreviewPopup = preload("res://src/ui/shared/image_preview_popup.gd")

signal normalization_applied

var _story_base_path: String = ""
var _all_image_paths: Array = []  # [{path, type}]
var _selected_paths: Array = []
var _reference_path: String = ""
var _temp_dir: String = ""
var _current_phase: int = 1

# Phase 1 UI
var _selection_container: VBoxContainer
var _selection_grid: GridContainer
var _selection_checkboxes: Dictionary = {}  # path -> CheckBox
var _select_all_button: Button
var _deselect_all_button: Button
var _next_button: Button
var _selection_count_label: Label

# Phase 2 UI
var _reference_container: VBoxContainer
var _reference_grid: GridContainer
var _reference_label: Label
var _normalize_button: Button
var _back_to_selection_button: Button

# Phase 3 UI
var _preview_container: VBoxContainer
var _preview_grid: GridContainer
var _apply_button: Button
var _back_to_reference_button: Button

var _close_button: Button
var _image_preview: Control


func _ready() -> void:
	size = Vector2i(1000, 700)
	exclusive = true
	title = tr("Normalisation des images")
	close_requested.connect(_on_close)
	_build_ui()


func setup(story_base_path: String) -> void:
	_story_base_path = story_base_path
	_all_image_paths.clear()
	_collect_images(story_base_path + "/assets/backgrounds", "bg")
	_collect_images(story_base_path + "/assets/foregrounds", "fg")
	_all_image_paths.sort_custom(func(a, b): return a["path"].get_file().to_lower() < b["path"].get_file().to_lower())
	_populate_selection_grid()
	_show_phase(1)


func _collect_images(dir_path: String, type: String) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext = fname.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp"]:
				_all_image_paths.append({"path": dir_path + "/" + fname, "type": type})
		fname = dir.get_next()
	dir.list_dir_end()


func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	_build_phase_1(vbox)
	_build_phase_2(vbox)
	_build_phase_3(vbox)

	# Close button (shared)
	var sep = HSeparator.new()
	vbox.add_child(sep)

	var bottom_bar = HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom_bar)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(spacer)

	_close_button = Button.new()
	_close_button.text = tr("Fermer")
	_close_button.pressed.connect(_on_close)
	bottom_bar.add_child(_close_button)

	# Image preview overlay
	_image_preview = Control.new()
	_image_preview.set_script(ImagePreviewPopup)
	add_child(_image_preview)


func _build_phase_1(parent: VBoxContainer) -> void:
	_selection_container = VBoxContainer.new()
	_selection_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selection_container.add_theme_constant_override("separation", 8)
	parent.add_child(_selection_container)

	var title_label = Label.new()
	title_label.text = tr("Sélectionner les images à normaliser")
	title_label.add_theme_font_size_override("font_size", 18)
	_selection_container.add_child(title_label)

	# Toolbar
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	_selection_container.add_child(toolbar)

	_select_all_button = Button.new()
	_select_all_button.text = tr("Tout sélectionner")
	_select_all_button.pressed.connect(_on_select_all)
	toolbar.add_child(_select_all_button)

	_deselect_all_button = Button.new()
	_deselect_all_button.text = tr("Tout désélectionner")
	_deselect_all_button.pressed.connect(_on_deselect_all)
	toolbar.add_child(_deselect_all_button)

	var toolbar_spacer = Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	_selection_count_label = Label.new()
	_selection_count_label.text = tr("0 image(s) sélectionnée(s)")
	toolbar.add_child(_selection_count_label)

	_next_button = Button.new()
	_next_button.text = tr("Suivant →")
	_next_button.disabled = true
	_next_button.pressed.connect(_on_next_to_reference)
	toolbar.add_child(_next_button)

	# Grid in scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selection_container.add_child(scroll)

	_selection_grid = GridContainer.new()
	_selection_grid.columns = 4
	_selection_grid.add_theme_constant_override("h_separation", 12)
	_selection_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_selection_grid)


func _build_phase_2(parent: VBoxContainer) -> void:
	_reference_container = VBoxContainer.new()
	_reference_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reference_container.add_theme_constant_override("separation", 8)
	_reference_container.visible = false
	parent.add_child(_reference_container)

	var title_label = Label.new()
	title_label.text = tr("Choisir l'image de référence")
	title_label.add_theme_font_size_override("font_size", 18)
	_reference_container.add_child(title_label)

	_reference_label = Label.new()
	_reference_label.text = tr("Cliquez sur l'image de référence")
	_reference_container.add_child(_reference_label)

	# Toolbar
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	_reference_container.add_child(toolbar)

	_back_to_selection_button = Button.new()
	_back_to_selection_button.text = tr("← Retour")
	_back_to_selection_button.pressed.connect(func(): _show_phase(1))
	toolbar.add_child(_back_to_selection_button)

	var toolbar_spacer = Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	_normalize_button = Button.new()
	_normalize_button.text = tr("Normaliser")
	_normalize_button.disabled = true
	_normalize_button.pressed.connect(_on_normalize_pressed)
	toolbar.add_child(_normalize_button)

	# Grid in scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_reference_container.add_child(scroll)

	_reference_grid = GridContainer.new()
	_reference_grid.columns = 4
	_reference_grid.add_theme_constant_override("h_separation", 12)
	_reference_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_reference_grid)


func _build_phase_3(parent: VBoxContainer) -> void:
	_preview_container = VBoxContainer.new()
	_preview_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_container.add_theme_constant_override("separation", 8)
	_preview_container.visible = false
	parent.add_child(_preview_container)

	var title_label = Label.new()
	title_label.text = tr("Aperçu de la normalisation")
	title_label.add_theme_font_size_override("font_size", 18)
	_preview_container.add_child(title_label)

	# Toolbar
	var toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	_preview_container.add_child(toolbar)

	_back_to_reference_button = Button.new()
	_back_to_reference_button.text = tr("← Retour")
	_back_to_reference_button.pressed.connect(_on_back_from_preview)
	toolbar.add_child(_back_to_reference_button)

	var toolbar_spacer = Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	_apply_button = Button.new()
	_apply_button.text = tr("Appliquer")
	_apply_button.pressed.connect(_on_apply_pressed)
	toolbar.add_child(_apply_button)

	# Grid in scroll
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_container.add_child(scroll)

	_preview_grid = GridContainer.new()
	_preview_grid.columns = 2
	_preview_grid.add_theme_constant_override("h_separation", 16)
	_preview_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_preview_grid)


func _show_phase(phase: int) -> void:
	_current_phase = phase
	_selection_container.visible = (phase == 1)
	_reference_container.visible = (phase == 2)
	_preview_container.visible = (phase == 3)


func _populate_selection_grid() -> void:
	for child in _selection_grid.get_children():
		_selection_grid.remove_child(child)
		child.queue_free()
	_selection_checkboxes.clear()

	for item in _all_image_paths:
		var path: String = item["path"]
		_add_selection_item(path)
	_update_selection_count()


func _add_selection_item(path: String) -> void:
	var container = Panel.new()
	container.custom_minimum_size = Vector2(120, 140)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(vbox)

	var cb = CheckBox.new()
	cb.text = ""
	cb.toggled.connect(func(_p): _update_selection_count())
	vbox.add_child(cb)
	_selection_checkboxes[path] = cb

	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(96, 96)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
	vbox.add_child(tex_rect)

	var name_label = Label.new()
	name_label.text = path.get_file()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 96
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				_show_image_preview(path)
	)
	_selection_grid.add_child(container)


func _update_selection_count() -> void:
	var count = 0
	for path in _selection_checkboxes:
		if _selection_checkboxes[path].button_pressed:
			count += 1
	_selection_count_label.text = tr("%d image(s) sélectionnée(s)") % count
	_next_button.disabled = count < 2


func _on_select_all() -> void:
	for path in _selection_checkboxes:
		_selection_checkboxes[path].button_pressed = true
	_update_selection_count()


func _on_deselect_all() -> void:
	for path in _selection_checkboxes:
		_selection_checkboxes[path].button_pressed = false
	_update_selection_count()


func _on_next_to_reference() -> void:
	_selected_paths.clear()
	for path in _selection_checkboxes:
		if _selection_checkboxes[path].button_pressed:
			_selected_paths.append(path)
	_reference_path = ""
	_normalize_button.disabled = true
	_reference_label.text = tr("Cliquez sur l'image de référence")
	_populate_reference_grid()
	_show_phase(2)


func _populate_reference_grid() -> void:
	for child in _reference_grid.get_children():
		_reference_grid.remove_child(child)
		child.queue_free()

	for path in _selected_paths:
		_add_reference_item(path)


func _add_reference_item(path: String) -> void:
	var container = Panel.new()
	container.custom_minimum_size = Vector2(140, 160)
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(vbox)

	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(128, 128)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
	vbox.add_child(tex_rect)

	var name_label = Label.new()
	name_label.text = path.get_file()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 128
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				_show_image_preview(path)
			else:
				_select_reference(path)
	)
	_reference_grid.add_child(container)


func _select_reference(path: String) -> void:
	_reference_path = path
	_normalize_button.disabled = false
	_reference_label.text = tr("Référence : %s") % path.get_file()

	# Update visuals
	var idx = 0
	for p in _selected_paths:
		var container = _reference_grid.get_child(idx)
		if p == path:
			container.modulate = Color(0.5, 0.8, 1.0)
		else:
			container.modulate = Color.WHITE
		idx += 1


func _on_normalize_pressed() -> void:
	_temp_dir = _story_base_path + "/assets/.normalizer_temp"
	DirAccess.make_dir_recursive_absolute(_temp_dir)

	# Analyze reference image
	var ref_stats = ImageNormalizerService.analyze_image(_reference_path)
	if ref_stats.is_empty():
		return

	# Normalize each non-reference image
	for path in _selected_paths:
		if path == _reference_path:
			continue
		var img_stats = ImageNormalizerService.analyze_image(path)
		if img_stats.is_empty():
			continue
		var prefix = _get_prefix_for_path(path)
		var temp_path = ImageNormalizerService.get_temp_path(path, _temp_dir, prefix)
		ImageNormalizerService.normalize_image(path, img_stats, ref_stats, temp_path)

	_populate_preview_grid()
	_show_phase(3)


func _get_prefix_for_path(path: String) -> String:
	for item in _all_image_paths:
		if item["path"] == path:
			return item["type"] + "_"
	return ""


func _populate_preview_grid() -> void:
	for child in _preview_grid.get_children():
		_preview_grid.remove_child(child)
		child.queue_free()

	for path in _selected_paths:
		# Column 1: Before
		var before_panel = Panel.new()
		before_panel.custom_minimum_size = Vector2(140, 180)
		before_panel.mouse_filter = Control.MOUSE_FILTER_STOP

		var before_vbox = VBoxContainer.new()
		before_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		before_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		before_panel.add_child(before_vbox)

		var before_label = Label.new()
		if path == _reference_path:
			before_label.text = tr("%s (référence — non modifiée)") % path.get_file()
		else:
			before_label.text = tr("%s — Avant") % path.get_file()
		before_label.clip_text = true
		before_label.custom_minimum_size.x = 128
		before_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		before_vbox.add_child(before_label)

		var before_tex = TextureRect.new()
		before_tex.custom_minimum_size = Vector2(128, 128)
		before_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		before_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		before_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var before_img = Image.new()
		if before_img.load(path) == OK:
			before_tex.texture = ImageTexture.create_from_image(before_img)
		before_vbox.add_child(before_tex)

		var before_path = path
		before_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
					_show_image_preview(before_path)
		)
		_preview_grid.add_child(before_panel)

		# Column 2: After
		var after_panel = Panel.new()
		after_panel.custom_minimum_size = Vector2(140, 180)
		after_panel.mouse_filter = Control.MOUSE_FILTER_STOP

		var after_vbox = VBoxContainer.new()
		after_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		after_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
		after_panel.add_child(after_vbox)

		var after_label = Label.new()
		if path == _reference_path:
			after_label.text = tr("(inchangée)")
		else:
			after_label.text = tr("Après")
		after_label.clip_text = true
		after_label.custom_minimum_size.x = 128
		after_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		after_vbox.add_child(after_label)

		var after_tex = TextureRect.new()
		after_tex.custom_minimum_size = Vector2(128, 128)
		after_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		after_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		after_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var after_preview_path = path
		if path == _reference_path:
			var ref_img = Image.new()
			if ref_img.load(path) == OK:
				after_tex.texture = ImageTexture.create_from_image(ref_img)
		else:
			var prefix = _get_prefix_for_path(path)
			var temp_path = ImageNormalizerService.get_temp_path(path, _temp_dir, prefix)
			after_preview_path = temp_path
			var after_img = Image.new()
			if after_img.load(temp_path) == OK:
				after_tex.texture = ImageTexture.create_from_image(after_img)
		after_vbox.add_child(after_tex)

		after_panel.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
					_show_image_preview(after_preview_path)
		)
		_preview_grid.add_child(after_panel)


func _on_apply_pressed() -> void:
	var mappings := []
	for path in _selected_paths:
		if path == _reference_path:
			continue
		var prefix = _get_prefix_for_path(path)
		var temp_path = ImageNormalizerService.get_temp_path(path, _temp_dir, prefix)
		mappings.append({"original": path, "temp": temp_path})

	var count = ImageNormalizerService.apply_normalized_images(mappings)
	_cleanup_temp()

	var info = AcceptDialog.new()
	info.dialog_text = tr("%d image(s) normalisée(s) avec succès.") % count
	add_child(info)
	info.popup_centered()
	info.confirmed.connect(func():
		normalization_applied.emit()
		hide()
	)


func _on_back_from_preview() -> void:
	_cleanup_temp()
	_show_phase(1)


func _cleanup_temp() -> void:
	if _temp_dir != "":
		ImageNormalizerService.cleanup_temp_dir(_temp_dir)
		_temp_dir = ""


func _show_image_preview(path: String) -> void:
	if path == "":
		return
	var img = Image.new()
	if img.load(path) == OK:
		var tex = ImageTexture.create_from_image(img)
		if _image_preview:
			_image_preview.show_preview(tex, path.get_file())


func _on_close() -> void:
	_cleanup_temp()
	hide()
