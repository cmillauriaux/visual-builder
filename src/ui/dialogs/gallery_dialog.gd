extends Window

## Dialog de consultation de la galerie d'images de l'histoire.
## Affiche backgrounds et foregrounds en deux sections avec indication
## des images utilisées/non utilisées et bouton de nettoyage.

const GalleryCleanerService = preload("res://src/services/gallery_cleaner_service.gd")
const ImagePreviewPopup = preload("res://src/ui/shared/image_preview_popup.gd")

var _story = null
var _story_base_path: String = ""
var _used_images: Array = []

# Références UI
var _bg_section_label: Label
var _bg_grid: GridContainer
var _bg_empty_label: Label
var _fg_section_label: Label
var _fg_grid: GridContainer
var _fg_empty_label: Label
var _clean_button: Button
var _close_button: Button
var _image_preview: Control


func _ready() -> void:
	size = Vector2i(900, 600)
	exclusive = true
	close_requested.connect(_on_close)
	_build_ui()


func setup(story, story_base_path: String) -> void:
	_story = story
	_story_base_path = story_base_path
	title = "Galerie — " + story.title
	_used_images = GalleryCleanerService.collect_used_images(story)
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
		child.queue_free()

	var images = _list_images(dir_path)
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
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				_show_image_preview(path)
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
		_used_images = GalleryCleanerService.collect_used_images(_story)
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


func _on_close() -> void:
	hide()
