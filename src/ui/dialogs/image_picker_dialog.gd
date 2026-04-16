# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends Window

## Dialog unifié pour la sélection d'images (backgrounds ou foregrounds).
## Propose trois onglets : Fichier (FileDialog système + copie vers assets),
## Galerie (vignettes des images déjà présentes dans les assets de l'histoire),
## et IA (génération via ComfyUI).

signal image_selected(path: String)

const FICHIER_TAB := 0
const GALERIE_TAB := 1
const ImagePreviewPopup = preload("res://src/ui/shared/image_preview_popup.gd")
const ImageCategoryService = preload("res://src/services/image_category_service.gd")
const CategoryManagerDialogScript = preload("res://src/ui/dialogs/category_manager_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const StorySaver = preload("res://src/persistence/story_saver.gd")

signal image_renamed(old_path: String, new_path: String)

enum Mode { BACKGROUND, FOREGROUND, ICON }

var _mode: int = Mode.FOREGROUND
var _story_base_path: String = ""
var _story = null
var _selected_path: String = ""
var _selected_gallery_item = null
var _category_service: RefCounted = null

# Références UI
var _tab_container: TabContainer
var _validate_btn: Button
var _file_path_label: Label
var _gallery_grid: GridContainer
var _empty_label: Label
var _no_story_label: Label
var _gallery_category_filter_container: HBoxContainer
var _gallery_category_checkboxes: Array = []
var _gallery_search_edit: LineEdit
var _gallery_context_menu: PopupMenu
var _anim_filter_check: CheckBox = null

# Image preview
var _image_preview: Control

# Plugin tabs: Array of {control: Control, tab_def}
var _plugin_tabs: Array = []

func _ready() -> void:
	title = tr("Sélectionner un foreground")
	size = Vector2i(900, 600)
	exclusive = true
	close_requested.connect(_on_cancel)
	_build_ui()

func setup(mode: int, story_base_path: String, story = null) -> void:
	_mode = mode
	_story_base_path = story_base_path
	_story = story
	if mode == Mode.BACKGROUND:
		title = tr("Sélectionner un background")
	else:
		title = tr("Sélectionner un foreground")
	_reset_selection()
	_update_story_warning()
	_category_service = ImageCategoryService.new()
	if story_base_path != "":
		_category_service.load_from(story_base_path)
	_update_gallery_category_filter()
	if _anim_filter_check:
		_anim_filter_check.visible = (mode == Mode.FOREGROUND)

func _reset_selection() -> void:
	_selected_path = ""
	_selected_gallery_item = null
	if _validate_btn:
		_validate_btn.disabled = true
	if _file_path_label:
		_file_path_label.text = tr("Aucun fichier sélectionné")

func _update_story_warning() -> void:
	if _no_story_label:
		_no_story_label.visible = (_story_base_path == "")

## Forwards a source image path to any plugin tab that accepts it.
func set_source_image(path: String) -> void:
	for entry in _plugin_tabs:
		var ctrl: Control = entry.control
		if ctrl.has_method("set_source_image"):
			ctrl.set_source_image(path)

func _build_ui() -> void:
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_child(vbox)

	# Avertissement histoire manquante
	_no_story_label = Label.new()
	_no_story_label.text = tr("Aucune histoire ouverte. Veuillez ouvrir une histoire avant d'importer des images.")
	_no_story_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))
	_no_story_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_no_story_label.visible = false
	vbox.add_child(_no_story_label)

	# Onglets
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)
	_tab_container.tab_changed.connect(_on_tab_changed)

	_build_file_tab()
	_build_gallery_tab()

	# Séparateur
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# Barre de boutons
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(hbox)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var cancel_btn = Button.new()
	cancel_btn.text = tr("Annuler")
	cancel_btn.pressed.connect(_on_cancel)
	hbox.add_child(cancel_btn)

	_validate_btn = Button.new()
	_validate_btn.text = tr("Valider")
	_validate_btn.disabled = true
	_validate_btn.pressed.connect(_on_validate)
	hbox.add_child(_validate_btn)

	# Image preview overlay (must be last child to appear on top)
	_image_preview = Control.new()
	_image_preview.set_script(ImagePreviewPopup)
	add_child(_image_preview)

func _build_file_tab() -> void:
	var file_tab = VBoxContainer.new()
	file_tab.name = tr("Fichier")
	file_tab.add_theme_constant_override("separation", 12)
	_tab_container.add_child(file_tab)

	var margin = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	file_tab.add_child(margin)

	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	margin.add_child(inner)

	var browse_btn = Button.new()
	browse_btn.text = tr("Parcourir le système de fichiers...")
	browse_btn.pressed.connect(_on_browse_file)
	inner.add_child(browse_btn)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	inner.add_child(hbox)

	var prefix = Label.new()
	prefix.text = tr("Fichier sélectionné :")
	hbox.add_child(prefix)

	_file_path_label = Label.new()
	_file_path_label.text = tr("Aucun fichier sélectionné")
	_file_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_path_label.clip_text = true
	hbox.add_child(_file_path_label)

func _build_gallery_tab() -> void:
	var gallery_tab = VBoxContainer.new()
	gallery_tab.name = tr("Galerie")
	_tab_container.add_child(gallery_tab)

	# Filtre par catégorie
	var filter_hbox = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 8)
	gallery_tab.add_child(filter_hbox)

	var filter_label = Label.new()
	filter_label.text = tr("Filtrer :")
	filter_hbox.add_child(filter_label)

	_gallery_category_filter_container = HBoxContainer.new()
	_gallery_category_filter_container.add_theme_constant_override("separation", 4)
	filter_hbox.add_child(_gallery_category_filter_container)

	_gallery_search_edit = LineEdit.new()
	_gallery_search_edit.placeholder_text = tr("Rechercher...")
	_gallery_search_edit.custom_minimum_size.x = 180
	_gallery_search_edit.clear_button_enabled = true
	_gallery_search_edit.text_changed.connect(func(_t): _refresh_gallery())
	filter_hbox.add_child(_gallery_search_edit)

	_anim_filter_check = CheckBox.new()
	_anim_filter_check.text = tr("Animations")
	_anim_filter_check.visible = false
	_anim_filter_check.toggled.connect(func(_v): _refresh_gallery())
	filter_hbox.add_child(_anim_filter_check)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_hbox.add_child(spacer)

	var refresh_btn = Button.new()
	refresh_btn.text = tr("Rafraîchir")
	refresh_btn.pressed.connect(func():
		GalleryCacheService.clear_dir(_get_assets_dir())
		if _mode == Mode.FOREGROUND and _story_base_path != "":
			GalleryCacheService.clear_dir(_story_base_path + "/assets/animation")
		_refresh_gallery()
	)
	filter_hbox.add_child(refresh_btn)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery_tab.add_child(scroll)

	var gallery_inner = VBoxContainer.new()
	gallery_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_inner.add_theme_constant_override("separation", 8)
	scroll.add_child(gallery_inner)

	_empty_label = Label.new()
	_empty_label.text = tr("Aucune image disponible. Importez d'abord une image via l'onglet Fichier.")
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_empty_label.visible = false
	gallery_inner.add_child(_empty_label)

	_gallery_grid = GridContainer.new()
	_gallery_grid.columns = 4
	gallery_inner.add_child(_gallery_grid)

## Adds a plugin-contributed tab to the TabContainer.
## Must be called after setup() so context is available.
func add_plugin_tab(tab_def: RefCounted) -> void:
	var ctx := {
		"mode": _mode,
		"story_base_path": _story_base_path,
		"story": _story,
		"category_service": _category_service,
		"on_image_selected": func(path: String): image_selected.emit(path); hide(),
		"on_show_preview": func(tex: Texture2D, name: String): _show_image_preview(tex, name),
	}
	var tab_control: Control = tab_def.create_tab.call(ctx)
	tab_control.name = tab_def.label
	_tab_container.add_child(tab_control)
	if tab_control.has_method("setup"):
		tab_control.setup(ctx)
	_plugin_tabs.append({"control": tab_control, "tab_def": tab_def})


func _on_tab_changed(tab: int) -> void:
	_reset_selection()
	if tab == GALERIE_TAB:
		_refresh_gallery()

func _refresh_gallery() -> void:
	for child in _gallery_grid.get_children():
		child.queue_free()

	if _story_base_path == "":
		_empty_label.text = tr("Aucune histoire ouverte. Veuillez ouvrir une histoire avant d'utiliser la galerie.")
		_empty_label.visible = true
		_gallery_grid.visible = false
		return

	var images = _list_gallery_images()
	if _anim_filter_check != null and _anim_filter_check.button_pressed:
		images = images.filter(func(p): return p.get_extension().to_lower() == "apng")
	var selected_cats = _get_gallery_selected_categories()
	if not selected_cats.is_empty() and _category_service:
		images = _category_service.filter_paths_by_categories(images, selected_cats)
	var search_term = _gallery_search_edit.text.strip_edges().to_lower() if _gallery_search_edit else ""
	if search_term != "":
		images = images.filter(func(p): return p.get_file().to_lower().contains(search_term))
	if images.is_empty():
		_empty_label.text = tr("Aucune image disponible. Importez d'abord une image via l'onglet Fichier.")
		_empty_label.visible = true
		_gallery_grid.visible = false
	else:
		_empty_label.visible = false
		_gallery_grid.visible = true
		for path in images:
			_add_gallery_item(path)

func _add_gallery_item(path: String) -> void:
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

	tex_rect.texture = GalleryCacheService.get_texture(path)
	vbox.add_child(tex_rect)

	var name_label = Label.new()
	name_label.text = path.get_file()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.custom_minimum_size.x = 128
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)

	if path.get_extension().to_lower() == "apng":
		var badge = Label.new()
		badge.text = "▶"
		badge.add_theme_color_override("font_color", Color(0.3, 0.85, 0.3))
		badge.add_theme_font_size_override("font_size", 14)
		badge.position = Vector2(4, 4)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(badge)

	container.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.double_click:
					_show_image_preview_from_path(path)
				else:
					_on_gallery_item_selected(container, path)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_show_gallery_context_menu(path, container.get_global_mouse_position())
	)
	_gallery_grid.add_child(container)

func _on_gallery_item_selected(container: Panel, path: String) -> void:
	if _selected_gallery_item != null:
		_selected_gallery_item.modulate = Color.WHITE
	_selected_gallery_item = container
	container.modulate = Color(0.5, 0.8, 1.0)
	_selected_path = path
	_validate_btn.disabled = false

func _on_browse_file() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(_on_file_selected_from_dialog)
	add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))

func _on_file_selected_from_dialog(source_path: String) -> void:
	if _story_base_path == "":
		_file_path_label.text = tr("Impossible de copier : aucune histoire ouverte")
		return
	var copied_path = _copy_to_assets(source_path)
	if copied_path != "":
		_selected_path = copied_path
		_file_path_label.text = source_path.get_file()
		_validate_btn.disabled = false

func _copy_to_assets(source_path: String) -> String:
	if _story_base_path == "":
		return ""
	var dest_dir = _get_assets_dir()
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var filename = source_path.get_file()
	var dest_path = _resolve_unique_path(dest_dir, filename)
	var err = DirAccess.copy_absolute(source_path, dest_path)
	if err != OK:
		return ""
	GalleryCacheService.clear_dir(dest_dir)
	return dest_path

func _on_validate() -> void:
	if _selected_path != "":
		image_selected.emit(_selected_path)
		hide()

func _on_cancel() -> void:
	for entry in _plugin_tabs:
		var ctrl: Control = entry.control
		if ctrl.has_method("cleanup"):
			ctrl.cleanup()
	hide()

func _get_assets_dir() -> String:
	if _mode == Mode.BACKGROUND:
		return _story_base_path + "/assets/backgrounds"
	if _mode == Mode.ICON:
		return _story_base_path + "/assets/icons"
	return _story_base_path + "/assets/foregrounds"

func _list_gallery_images() -> Array:
	var extensions = ["png", "jpg", "jpeg", "webp", "apng"]
	var images = GalleryCacheService.get_file_list(_get_assets_dir(), extensions)
	if _mode == Mode.FOREGROUND and _story_base_path != "":
		var anim_dir = _story_base_path + "/assets/animation"
		var anim_images = GalleryCacheService.get_file_list(anim_dir, extensions)
		images.append_array(anim_images)
	return images

static func _resolve_unique_path(dir_path: String, filename: String) -> String:
	var name = filename.get_basename()
	var ext = "." + filename.get_extension()
	var target = dir_path + "/" + filename
	if not FileAccess.file_exists(target):
		return target
	var i = 1
	while FileAccess.file_exists(dir_path + "/" + name + "_" + str(i) + ext):
		i += 1
	return dir_path + "/" + name + "_" + str(i) + ext


# --- Category Methods ---

func _update_gallery_category_filter() -> void:
	if _gallery_category_filter_container == null:
		return
	for child in _gallery_category_filter_container.get_children():
		child.queue_free()
	_gallery_category_checkboxes.clear()
	if _category_service:
		for cat in _category_service.get_categories():
			var cb = CheckBox.new()
			cb.text = cat
			cb.toggled.connect(func(_p): _refresh_gallery())
			_gallery_category_filter_container.add_child(cb)
			_gallery_category_checkboxes.append(cb)


func _get_gallery_selected_categories() -> Array:
	var result := []
	for cb in _gallery_category_checkboxes:
		if cb.button_pressed:
			result.append(cb.text)
	return result


func _show_gallery_context_menu(image_path: String, pos: Vector2) -> void:
	if _gallery_context_menu != null:
		_gallery_context_menu.queue_free()

	_gallery_context_menu = PopupMenu.new()
	var image_key = ImageCategoryService.path_to_key(image_path)

	var rename_id = 8000
	_gallery_context_menu.add_item(tr("Renommer"), rename_id)
	_gallery_context_menu.add_separator()

	if _category_service:
		var categories = _category_service.get_categories()
		for i in range(categories.size()):
			var cat = categories[i]
			_gallery_context_menu.add_check_item(cat, i)
			_gallery_context_menu.set_item_checked(
				_gallery_context_menu.get_item_index(i),
				_category_service.is_image_in_category(image_key, cat)
			)

		if not categories.is_empty():
			_gallery_context_menu.add_separator()

	var manage_id = 9000
	_gallery_context_menu.add_item(tr("Gérer les catégories..."), manage_id)

	_gallery_context_menu.id_pressed.connect(func(id: int):
		if id == rename_id:
			_show_rename_dialog(image_path)
		elif id == manage_id:
			_open_gallery_category_manager()
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
				_refresh_gallery()
	)
	add_child(_gallery_context_menu)
	_gallery_context_menu.position = Vector2i(int(pos.x), int(pos.y))
	_gallery_context_menu.popup()


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
			_refresh_gallery()
	)

	add_child(dialog)
	dialog.popup_centered()
	line_edit.select_all()
	line_edit.grab_focus()


func _open_gallery_category_manager() -> void:
	var manager = Window.new()
	manager.set_script(CategoryManagerDialogScript)
	add_child(manager)
	manager.setup(_category_service)
	manager.categories_changed.connect(func():
		if _story_base_path != "":
			_category_service.save_to(_story_base_path)
		_update_gallery_category_filter()
		_refresh_gallery()
	)
	manager.popup_centered()

# --- Image Preview ---

func _show_image_preview(texture: Texture2D, filename: String) -> void:
	if _image_preview:
		_image_preview.show_preview(texture, filename)

func _show_image_preview_from_path(path: String) -> void:
	if path == "":
		return
	var img = Image.new()
	if img.load(path) == OK:
		var tex = ImageTexture.create_from_image(img)
		_show_image_preview(tex, path.get_file())