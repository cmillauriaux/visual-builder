extends Window

## Dialog unifié pour la sélection d'images (backgrounds ou foregrounds).
## Propose deux onglets : Fichier (FileDialog système + copie vers assets)
## et Galerie (vignettes des images déjà présentes dans les assets de l'histoire).

signal image_selected(path: String)

const FICHIER_TAB := 0
const GALERIE_TAB := 1

enum Mode { BACKGROUND, FOREGROUND }

var _mode: int = Mode.FOREGROUND
var _story_name: String = ""
var _selected_path: String = ""
var _selected_gallery_item = null

# Références UI
var _tab_container: TabContainer
var _validate_btn: Button
var _file_path_label: Label
var _gallery_grid: GridContainer
var _empty_label: Label
var _no_story_label: Label

func _ready() -> void:
	title = "Sélectionner un foreground"
	size = Vector2i(900, 600)
	exclusive = true
	close_requested.connect(_on_cancel)
	_build_ui()

func setup(mode: int, story_name: String) -> void:
	_mode = mode
	_story_name = story_name
	if mode == Mode.BACKGROUND:
		title = "Sélectionner un background"
	else:
		title = "Sélectionner un foreground"
	_reset_selection()
	_update_story_warning()

func _reset_selection() -> void:
	_selected_path = ""
	_selected_gallery_item = null
	if _validate_btn:
		_validate_btn.disabled = true
	if _file_path_label:
		_file_path_label.text = "Aucun fichier sélectionné"

func _update_story_warning() -> void:
	if _no_story_label:
		_no_story_label.visible = (_story_name == "")

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
	_no_story_label.text = "Aucune histoire ouverte. Veuillez ouvrir une histoire avant d'importer des images."
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
	cancel_btn.text = "Annuler"
	cancel_btn.pressed.connect(_on_cancel)
	hbox.add_child(cancel_btn)

	_validate_btn = Button.new()
	_validate_btn.text = "Valider"
	_validate_btn.disabled = true
	_validate_btn.pressed.connect(_on_validate)
	hbox.add_child(_validate_btn)

func _build_file_tab() -> void:
	var file_tab = VBoxContainer.new()
	file_tab.name = "Fichier"
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
	browse_btn.text = "Parcourir le système de fichiers..."
	browse_btn.pressed.connect(_on_browse_file)
	inner.add_child(browse_btn)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	inner.add_child(hbox)

	var prefix = Label.new()
	prefix.text = "Fichier sélectionné :"
	hbox.add_child(prefix)

	_file_path_label = Label.new()
	_file_path_label.text = "Aucun fichier sélectionné"
	_file_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_path_label.clip_text = true
	hbox.add_child(_file_path_label)

func _build_gallery_tab() -> void:
	var gallery_tab = VBoxContainer.new()
	gallery_tab.name = "Galerie"
	_tab_container.add_child(gallery_tab)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery_tab.add_child(scroll)

	var gallery_inner = VBoxContainer.new()
	gallery_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_inner.add_theme_constant_override("separation", 8)
	scroll.add_child(gallery_inner)

	_empty_label = Label.new()
	_empty_label.text = "Aucune image disponible. Importez d'abord une image via l'onglet Fichier."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_empty_label.visible = false
	gallery_inner.add_child(_empty_label)

	_gallery_grid = GridContainer.new()
	_gallery_grid.columns = 4
	gallery_inner.add_child(_gallery_grid)

func _on_tab_changed(tab: int) -> void:
	_reset_selection()
	if tab == GALERIE_TAB:
		_refresh_gallery()

func _refresh_gallery() -> void:
	for child in _gallery_grid.get_children():
		child.queue_free()

	if _story_name == "":
		_empty_label.text = "Aucune histoire ouverte. Veuillez ouvrir une histoire avant d'utiliser la galerie."
		_empty_label.visible = true
		_gallery_grid.visible = false
		return

	var images = _list_gallery_images()
	if images.is_empty():
		_empty_label.text = "Aucune image disponible. Importez d'abord une image via l'onglet Fichier."
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
			_on_gallery_item_selected(container, path)
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
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg ; JPG", "*.jpeg ; JPEG", "*.webp ; WEBP"])
	dialog.file_selected.connect(_on_file_selected_from_dialog)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_file_selected_from_dialog(source_path: String) -> void:
	if _story_name == "":
		_file_path_label.text = "Impossible de copier : aucune histoire ouverte"
		return
	var copied_path = _copy_to_assets(source_path)
	if copied_path != "":
		_selected_path = copied_path
		_file_path_label.text = source_path.get_file()
		_validate_btn.disabled = false

func _copy_to_assets(source_path: String) -> String:
	if _story_name == "":
		return ""
	var dest_dir = _get_assets_dir()
	DirAccess.make_dir_recursive_absolute(dest_dir)
	var filename = source_path.get_file()
	var dest_path = _resolve_unique_path(dest_dir, filename)
	var err = DirAccess.copy_absolute(source_path, dest_path)
	if err != OK:
		return ""
	return dest_path

func _on_validate() -> void:
	if _selected_path != "":
		image_selected.emit(_selected_path)
		hide()

func _on_cancel() -> void:
	hide()

func _get_assets_dir() -> String:
	if _mode == Mode.BACKGROUND:
		return "user://stories/" + _story_name + "/assets/backgrounds"
	return "user://stories/" + _story_name + "/assets/foregrounds"

func _list_gallery_images() -> Array:
	var result = []
	var assets_dir = _get_assets_dir()
	var dir = DirAccess.open(assets_dir)
	if dir == null:
		return result
	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext = fname.get_extension().to_lower()
			if ext in ["png", "jpg", "jpeg", "webp"]:
				result.append(assets_dir + "/" + fname)
		fname = dir.get_next()
	dir.list_dir_end()
	return result

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
