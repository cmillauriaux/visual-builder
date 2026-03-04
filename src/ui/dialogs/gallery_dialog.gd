extends Window

## Dialog de consultation de la galerie d'images de l'histoire.
## Affiche backgrounds et foregrounds en deux sections avec indication
## des images utilisées/non utilisées et bouton de nettoyage.

const GalleryCleanerService = preload("res://src/services/gallery_cleaner_service.gd")
const ImagePreviewPopup = preload("res://src/ui/shared/image_preview_popup.gd")
const ImageCategoryService = preload("res://src/services/image_category_service.gd")
const CategoryManagerDialogScript = preload("res://src/ui/dialogs/category_manager_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")
const ImageNormalizerDialogScript = preload("res://src/ui/dialogs/image_normalizer_dialog.gd")

signal image_renamed(old_path: String, new_path: String)

var _story = null
var _story_base_path: String = ""
var _used_images: Array = []
var _category_service: RefCounted = null

# Références UI
var _bg_section_label: Label
var _bg_grid: GridContainer
var _bg_empty_label: Label
var _fg_section_label: Label
var _fg_grid: GridContainer
var _fg_empty_label: Label
var _clean_button: Button
var _normalize_button: Button
var _close_button: Button
var _image_preview: Control
var _category_filter_container: HBoxContainer
var _category_checkboxes: Array = []
var _context_menu: PopupMenu


func _ready() -> void:
	size = Vector2i(900, 600)
	exclusive = true
	close_requested.connect(_on_close)
	_build_ui()


func setup(story, story_base_path: String) -> void:
	_story = story
	_story_base_path = story_base_path
	title = "Galerie — " + story.title
	var raw_used = GalleryCleanerService.collect_used_images(story)
	_used_images = GalleryCleanerService.normalize_paths(raw_used, story_base_path)
	_category_service = ImageCategoryService.new()
	if story_base_path != "":
		_category_service.load_from(story_base_path)
	_update_category_filter()
	_refresh()


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

	# Filtre par catégorie
	var filter_hbox = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(filter_hbox)

	var filter_label = Label.new()
	filter_label.text = "Filtrer :"
	filter_hbox.add_child(filter_label)

	_category_filter_container = HBoxContainer.new()
	_category_filter_container.add_theme_constant_override("separation", 4)
	filter_hbox.add_child(_category_filter_container)

	# Scroll pour le contenu
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var scroll_inner = VBoxContainer.new()
	scroll_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.add_theme_constant_override("separation", 12)
	scroll.add_child(scroll_inner)

	# --- Section Backgrounds ---
	_bg_section_label = Label.new()
	_bg_section_label.text = "Backgrounds"
	_bg_section_label.add_theme_font_size_override("font_size", 18)
	scroll_inner.add_child(_bg_section_label)

	_bg_empty_label = Label.new()
	_bg_empty_label.text = "Aucun background disponible."
	_bg_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg_empty_label.visible = false
	scroll_inner.add_child(_bg_empty_label)

	_bg_grid = GridContainer.new()
	_bg_grid.columns = 4
	scroll_inner.add_child(_bg_grid)

	# --- Section Foregrounds ---
	_fg_section_label = Label.new()
	_fg_section_label.text = "Foregrounds"
	_fg_section_label.add_theme_font_size_override("font_size", 18)
	scroll_inner.add_child(_fg_section_label)

	_fg_empty_label = Label.new()
	_fg_empty_label.text = "Aucun foreground disponible."
	_fg_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fg_empty_label.visible = false
	scroll_inner.add_child(_fg_empty_label)

	_fg_grid = GridContainer.new()
	_fg_grid.columns = 4
	scroll_inner.add_child(_fg_grid)

	# --- Separator ---
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# --- Bottom bar ---
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	_clean_button = Button.new()
	_clean_button.text = "Nettoyer la galerie"
	_clean_button.disabled = true
	_clean_button.pressed.connect(_on_clean_pressed)
	hbox.add_child(_clean_button)

	_normalize_button = Button.new()
	_normalize_button.text = "Normaliser les images"
	_normalize_button.disabled = true
	_normalize_button.pressed.connect(_on_normalize_pressed)
	hbox.add_child(_normalize_button)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_close_button = Button.new()
	_close_button.text = "Fermer"
	_close_button.pressed.connect(_on_close)
	hbox.add_child(_close_button)

	# Image preview overlay
	_image_preview = Control.new()
	_image_preview.set_script(ImagePreviewPopup)
	add_child(_image_preview)


func _refresh() -> void:
	_refresh_grid(_bg_grid, _bg_empty_label, _story_base_path + "/assets/backgrounds")
	_refresh_grid(_fg_grid, _fg_empty_label, _story_base_path + "/assets/foregrounds")
	_update_clean_button_state()


func _refresh_grid(grid: GridContainer, empty_label: Label, dir_path: String) -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()

	var images = _list_images(dir_path)
	var selected_cats = _get_selected_categories()
	if not selected_cats.is_empty() and _category_service:
		images = _category_service.filter_paths_by_categories(images, selected_cats)
	if images.is_empty():
		empty_label.visible = true
		grid.visible = false
	else:
		empty_label.visible = false
		grid.visible = true
		for path in images:
			_add_gallery_item(grid, path)


func _add_gallery_item(grid: GridContainer, path: String) -> void:
	var is_used = path in _used_images

	var container = Panel.new()
	container.custom_minimum_size = Vector2(140, 160)
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	if not is_used:
		container.modulate = Color(1, 1, 1, 0.5)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
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
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				_show_image_preview(path)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_show_context_menu(path, container.get_global_mouse_position())
	)
	grid.add_child(container)


func _list_images(dir_path: String) -> Array:
	var result := []
	var dir = DirAccess.open(dir_path)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext = fname.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp"]:
				result.append(dir_path + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return result


func _update_clean_button_state() -> void:
	var has_any = _bg_grid.get_child_count() > 0 or _fg_grid.get_child_count() > 0
	_clean_button.disabled = not has_any
	var total_images = _bg_grid.get_child_count() + _fg_grid.get_child_count()
	_normalize_button.disabled = total_images < 2


func _on_clean_pressed() -> void:
	var unused = GalleryCleanerService.find_unused_images(_story_base_path, _used_images)
	var all_unused: Array = []
	all_unused.append_array(unused["backgrounds"])
	all_unused.append_array(unused["foregrounds"])

	if all_unused.is_empty():
		var info = AcceptDialog.new()
		info.dialog_text = "Toutes les images sont utilisées."
		add_child(info)
		info.popup_centered()
		return

	var total_size = GalleryCleanerService.calculate_total_size(all_unused)
	var size_text = _format_size(total_size)

	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "%d fichier(s) — %s" % [all_unused.size(), size_text]
	confirm.confirmed.connect(func():
		GalleryCleanerService.delete_files(all_unused)
		var raw = GalleryCleanerService.collect_used_images(_story)
		_used_images = GalleryCleanerService.normalize_paths(raw, _story_base_path)
		_refresh()
	)
	add_child(confirm)
	confirm.popup_centered()


func _format_size(bytes: int) -> String:
	if bytes < 1024:
		return str(bytes) + " o"
	elif bytes < 1024 * 1024:
		return "%.1f Ko" % (bytes / 1024.0)
	else:
		return "%.1f Mo" % (bytes / (1024.0 * 1024.0))


func _show_image_preview(path: String) -> void:
	if path == "":
		return
	var img = Image.new()
	if img.load(path) == OK:
		var tex = ImageTexture.create_from_image(img)
		if _image_preview:
			_image_preview.show_preview(tex, path.get_file())


func _update_category_filter() -> void:
	for child in _category_filter_container.get_children():
		child.queue_free()
	_category_checkboxes.clear()
	if _category_service:
		for cat in _category_service.get_categories():
			var cb = CheckBox.new()
			cb.text = cat
			cb.toggled.connect(func(_p): _refresh())
			_category_filter_container.add_child(cb)
			_category_checkboxes.append(cb)


func _get_selected_categories() -> Array:
	var result := []
	for cb in _category_checkboxes:
		if cb.button_pressed:
			result.append(cb.text)
	return result


func _show_context_menu(image_path: String, pos: Vector2) -> void:
	if _context_menu != null:
		_context_menu.queue_free()

	_context_menu = PopupMenu.new()
	var image_key = ImageCategoryService.path_to_key(image_path)

	var rename_id = 8000
	_context_menu.add_item("Renommer", rename_id)
	_context_menu.add_separator()

	if _category_service:
		var categories = _category_service.get_categories()
		for i in range(categories.size()):
			var cat = categories[i]
			_context_menu.add_check_item(cat, i)
			_context_menu.set_item_checked(
				_context_menu.get_item_index(i),
				_category_service.is_image_in_category(image_key, cat)
			)

		if not categories.is_empty():
			_context_menu.add_separator()

	var manage_id = 9000
	_context_menu.add_item("Gérer les catégories...", manage_id)

	_context_menu.id_pressed.connect(func(id: int):
		if id == rename_id:
			_show_rename_dialog(image_path)
		elif id == manage_id:
			_open_category_manager()
		elif _category_service:
			var categories = _category_service.get_categories()
			if id >= 0 and id < categories.size():
				var cat = categories[id]
				if _category_service.is_image_in_category(image_key, cat):
					_category_service.unassign_image_from_category(image_key, cat)
				else:
					_category_service.assign_image_to_category(image_key, cat)
				if _story_base_path != "":
					_category_service.save_to(_story_base_path)
				_refresh()
	)
	add_child(_context_menu)
	_context_menu.position = Vector2i(int(pos.x), int(pos.y))
	_context_menu.popup()


func _show_rename_dialog(image_path: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Renommer l'image"

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var line_edit := LineEdit.new()
	var current_name := image_path.get_file().get_basename()
	line_edit.text = current_name
	vbox.add_child(line_edit)

	var error_label := Label.new()
	error_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	error_label.visible = false
	vbox.add_child(error_label)

	dialog.add_child(vbox)

	line_edit.text_changed.connect(func(new_text: String):
		var trimmed := new_text.strip_edges()
		if trimmed == "":
			error_label.visible = false
			dialog.get_ok_button().disabled = true
			return
		var format_error := ImageRenameService.validate_name_format(trimmed)
		if format_error != "":
			error_label.text = format_error
			error_label.visible = true
			dialog.get_ok_button().disabled = true
			return
		if trimmed != current_name:
			var ext := "." + image_path.get_extension()
			var new_full_path := image_path.get_base_dir().path_join(trimmed + ext)
			if FileAccess.file_exists(new_full_path):
				error_label.text = "Ce nom est déjà utilisé."
				error_label.visible = true
				dialog.get_ok_button().disabled = true
				return
		error_label.visible = false
		dialog.get_ok_button().disabled = false
	)

	dialog.confirmed.connect(func():
		var new_name := line_edit.text.strip_edges()
		var result := ImageRenameService.rename(image_path, new_name, _category_service)
		if result["ok"] and not result["same_name"]:
			if _story != null:
				ImageRenameService.update_story_references(_story, image_path, result["new_path"])
				_story.touch()
			if _story_base_path != "":
				_category_service.save_to(_story_base_path)
			image_renamed.emit(image_path, result["new_path"])
			_refresh()
	)

	add_child(dialog)
	dialog.popup_centered()
	line_edit.select_all()
	line_edit.grab_focus()


func _open_category_manager() -> void:
	var manager = Window.new()
	manager.set_script(CategoryManagerDialogScript)
	add_child(manager)
	manager.setup(_category_service)
	manager.categories_changed.connect(func():
		if _story_base_path != "":
			_category_service.save_to(_story_base_path)
		_update_category_filter()
		_refresh()
	)
	manager.popup_centered()


func _on_normalize_pressed() -> void:
	var normalizer = Window.new()
	normalizer.set_script(ImageNormalizerDialogScript)
	add_child(normalizer)
	normalizer.setup(_story_base_path)
	normalizer.normalization_applied.connect(func():
		_refresh()
	)
	normalizer.popup_centered()


func _on_close() -> void:
	hide()
