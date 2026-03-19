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
const StorySaver = preload("res://src/persistence/story_saver.gd")

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
	title = tr("Galerie — %s") % story.title
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
	filter_label.text = tr("Filtrer :")
	filter_hbox.add_child(filter_label)

	_category_filter_container = HBoxContainer.new()
	_category_filter_container.add_theme_constant_override("separation", 4)
	filter_hbox.add_child(_category_filter_container)

	var spacer_filt = Control.new()
	spacer_filt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_hbox.add_child(spacer_filt)

	var refresh_btn = Button.new()
	refresh_btn.text = tr("Rafraîchir")
	refresh_btn.pressed.connect(func():
		GalleryCacheService.clear_dir(_story_base_path + "/assets/backgrounds")
		GalleryCacheService.clear_dir(_story_base_path + "/assets/foregrounds")
		_refresh()
	)
	filter_hbox.add_child(refresh_btn)

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
	_bg_section_label.text = tr("Backgrounds")
	_bg_section_label.add_theme_font_size_override("font_size", 18)
	scroll_inner.add_child(_bg_section_label)

	_bg_empty_label = Label.new()
	_bg_empty_label.text = tr("Aucun background disponible.")
	_bg_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bg_empty_label.visible = false
	scroll_inner.add_child(_bg_empty_label)

	_bg_grid = GridContainer.new()
	_bg_grid.columns = 4
	scroll_inner.add_child(_bg_grid)

	# --- Section Foregrounds ---
	_fg_section_label = Label.new()
	_fg_section_label.text = tr("Foregrounds")
	_fg_section_label.add_theme_font_size_override("font_size", 18)
	scroll_inner.add_child(_fg_section_label)

	_fg_empty_label = Label.new()
	_fg_empty_label.text = tr("Aucun foreground disponible.")
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
	_clean_button.text = tr("Nettoyer la galerie")
	_clean_button.disabled = true
	_clean_button.pressed.connect(_on_clean_pressed)
	hbox.add_child(_clean_button)

	_normalize_button = Button.new()
	_normalize_button.text = tr("Normaliser les images")
	_normalize_button.disabled = true
	_normalize_button.pressed.connect(_on_normalize_pressed)
	hbox.add_child(_normalize_button)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	_close_button = Button.new()
	_close_button.text = tr("Fermer")
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
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	container.add_child(vbox)

	var tex_rect = TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(128, 128)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	tex_rect.texture = GalleryCacheService.get_texture(path)
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
	return GalleryCacheService.get_file_list(dir_path, ["png", "jpg", "jpeg", "webp"])


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
		info.dialog_text = tr("Toutes les images sont utilisées.")
		add_child(info)
		info.popup_centered()
		return

	var total_size = GalleryCleanerService.calculate_total_size(all_unused)
	var size_text = _format_size(total_size)

	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = tr("%d fichier(s) — %s") % [all_unused.size(), size_text]
	confirm.confirmed.connect(func():
		GalleryCleanerService.delete_files(all_unused)
		for path in all_unused:
			GalleryCacheService.clear_path(path)
		GalleryCacheService.clear_dir(_story_base_path + "/assets/backgrounds")
		GalleryCacheService.clear_dir(_story_base_path + "/assets/foregrounds")
		var raw = GalleryCleanerService.collect_used_images(_story)
		_used_images = GalleryCleanerService.normalize_paths(raw, _story_base_path)
		_refresh()
	)
	add_child(confirm)
	confirm.popup_centered()


func _format_size(bytes: int) -> String:
	if bytes < 1024:
		return tr("%d o") % bytes
	elif bytes < 1024 * 1024:
		return tr("%.1f Ko") % (bytes / 1024.0)
	else:
		return tr("%.1f Mo") % (bytes / (1024.0 * 1024.0))


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
	var replace_id = 8001
	_context_menu.add_item(tr("Renommer"), rename_id)
	_context_menu.add_item(tr("Remplacer"), replace_id)
	var dir_path = image_path.get_base_dir()
	var sibling_count = _list_images(dir_path).size()
	if sibling_count <= 1:
		_context_menu.set_item_disabled(_context_menu.get_item_index(replace_id), true)
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
	_context_menu.add_item(tr("Gérer les catégories..."), manage_id)

	_context_menu.id_pressed.connect(func(id: int):
		if id == rename_id:
			_show_rename_dialog(image_path)
		elif id == replace_id:
			_show_replace_dialog(image_path)
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
	dialog.title = tr("Renommer l'image")

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
				error_label.text = tr("Ce nom est déjà utilisé.")
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
					StorySaver.save_story(_story, _story_base_path)
			if _story_base_path != "":
				_category_service.save_to(_story_base_path)
			GalleryCacheService.clear_path(image_path)
			GalleryCacheService.clear_dir(image_path.get_base_dir())
			image_renamed.emit(image_path, result["new_path"])
			_refresh()
	)

	add_child(dialog)
	dialog.popup_centered()
	line_edit.select_all()
	line_edit.grab_focus()


func _show_replace_dialog(image_path: String) -> void:
	var dir_path = image_path.get_base_dir()
	var all_images = _list_images(dir_path)
	var selected_cats = _get_selected_categories()
	if not selected_cats.is_empty() and _category_service:
		all_images = _category_service.filter_paths_by_categories(all_images, selected_cats)
	var candidates: Array = []
	for p in all_images:
		if p != image_path:
			candidates.append(p)
	if candidates.is_empty():
		return

	var dialog = Window.new()
	dialog.title = tr("Remplacer l'image")
	dialog.size = Vector2i(700, 500)
	dialog.exclusive = true
	dialog.close_requested.connect(func(): dialog.queue_free())

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	dialog.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	var info_label = Label.new()
	info_label.text = tr("Sélectionnez l'image de remplacement pour « %s » :") % image_path.get_file()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info_label)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 4
	scroll.add_child(grid)
	dialog.set_meta("grid", grid)

	# État partagé via Dictionary pour garantir la propagation entre closures
	var state := {"path": "", "panel": null}

	var validate_btn = Button.new()
	validate_btn.text = tr("Valider")
	validate_btn.disabled = true

	for path in candidates:
		var container = Panel.new()
		container.custom_minimum_size = Vector2(140, 160)
		container.mouse_filter = Control.MOUSE_FILTER_STOP

		var item_vbox = VBoxContainer.new()
		item_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
		item_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		container.add_child(item_vbox)

		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(128, 128)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var img = Image.new()
		if img.load(path) == OK:
			tex_rect.texture = ImageTexture.create_from_image(img)
		item_vbox.add_child(tex_rect)

		var name_label = Label.new()
		name_label.text = path.get_file()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		name_label.custom_minimum_size.x = 128
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_vbox.add_child(name_label)

		container.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if state.panel != null:
					state.panel.modulate = Color(1, 1, 1, 1)
				state.path = path
				state.panel = container
				container.modulate = Color(0.6, 0.8, 1.0, 1.0)
				validate_btn.disabled = false
		)
		grid.add_child(container)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 8)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(btn_hbox)

	var cancel_btn = Button.new()
	cancel_btn.text = tr("Annuler")
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	btn_hbox.add_child(cancel_btn)

	validate_btn.pressed.connect(func():
		var chosen_path: String = state.path
		dialog.queue_free()
		_show_replace_confirmation(image_path, chosen_path)
	)
	btn_hbox.add_child(validate_btn)

	add_child(dialog)
	dialog.popup_centered()


func _show_replace_confirmation(old_path: String, new_path: String) -> void:
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = tr("Remplacer « %s » par « %s » ?\nL'image « %s » sera supprimée.") % [
		old_path.get_file(), new_path.get_file(), old_path.get_file()
	]
	confirm.confirmed.connect(func():
		_execute_replace(old_path, new_path)
	)
	add_child(confirm)
	confirm.popup_centered()


func _execute_replace(old_path: String, new_path: String) -> void:
	# 1. Mise à jour des références dans la story
	if _story != null:
		ImageRenameService.update_story_references(_story, old_path, new_path)

	# 2. Transfert des catégories (fusion)
	if _category_service:
		var old_key = ImageCategoryService.path_to_key(old_path)
		var new_key = ImageCategoryService.path_to_key(new_path)
		var old_cats: Array = _category_service.get_image_categories(old_key)
		for cat in old_cats:
			if not _category_service.is_image_in_category(new_key, cat):
				_category_service.assign_image_to_category(new_key, cat)
		for cat in old_cats:
			_category_service.unassign_image_from_category(old_key, cat)

	# 3. Suppression de l'ancienne image
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(old_path)
		GalleryCacheService.clear_path(old_path)
		GalleryCacheService.clear_dir(old_path.get_base_dir())

	# 4. Marquage de la story comme modifiée
	if _story != null:
		_story.touch()

	# 5. Sauvegarde
	if _story != null and _story_base_path != "":
		StorySaver.save_story(_story, _story_base_path)
	if _category_service and _story_base_path != "":
		_category_service.save_to(_story_base_path)

	# 6. Rafraîchissement
	var raw = GalleryCleanerService.collect_used_images(_story)
	_used_images = GalleryCleanerService.normalize_paths(raw, _story_base_path)
	_refresh()


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
		GalleryCacheService.clear_dir(_story_base_path + "/assets/backgrounds")
		GalleryCacheService.clear_dir(_story_base_path + "/assets/foregrounds")
		_refresh()
	)
	normalizer.popup_centered()


func _on_close() -> void:
	hide()
