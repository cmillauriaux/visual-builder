extends Window

## Dialog unifié pour la sélection d'images (backgrounds ou foregrounds).
## Propose trois onglets : Fichier (FileDialog système + copie vers assets),
## Galerie (vignettes des images déjà présentes dans les assets de l'histoire),
## et IA (génération via ComfyUI).

signal image_selected(path: String)

const FICHIER_TAB := 0
const GALERIE_TAB := 1
const IA_TAB := 2
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ComfyUIClient = preload("res://src/services/comfyui_client.gd")

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

# IA tab UI
var _ia_url_input: LineEdit
var _ia_token_input: LineEdit
var _ia_source_path_label: Label
var _ia_source_preview: TextureRect
var _ia_choose_source_btn: Button
var _ia_choose_gallery_btn: Button
var _ia_prompt_input: TextEdit
var _ia_generate_btn: Button
var _ia_result_preview: TextureRect
var _ia_status_label: Label
var _ia_progress_bar: ProgressBar
var _ia_accept_btn: Button
var _ia_regenerate_btn: Button

# IA state
var _ia_client: Node = null
var _ia_source_image_path: String = ""
var _ia_generated_image: Image = null

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
	if _ia_choose_gallery_btn:
		_ia_choose_gallery_btn.disabled = (story_name == "")

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

func set_source_image(path: String) -> void:
	_ia_source_image_path = path
	if _ia_source_path_label:
		if path != "":
			_ia_source_path_label.text = path.get_file()
		else:
			_ia_source_path_label.text = "Aucune image sélectionnée"
	_ia_load_source_preview(path)
	_ia_update_generate_button_state()

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
	_build_ia_tab()

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

func _build_ia_tab() -> void:
	var ia_tab = ScrollContainer.new()
	ia_tab.name = "IA"
	ia_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(ia_tab)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	ia_tab.add_child(vbox)

	# --- URL ComfyUI ---
	var url_label = Label.new()
	url_label.text = "URL ComfyUI :"
	vbox.add_child(url_label)

	_ia_url_input = LineEdit.new()
	_ia_url_input.placeholder_text = "http://localhost:8188"
	_ia_url_input.text_changed.connect(func(_t): _ia_update_generate_button_state())
	vbox.add_child(_ia_url_input)

	# --- Token ---
	var token_label = Label.new()
	token_label.text = "Token (optionnel) :"
	vbox.add_child(token_label)

	_ia_token_input = LineEdit.new()
	_ia_token_input.secret = true
	_ia_token_input.placeholder_text = "Laisser vide si pas d'auth"
	vbox.add_child(_ia_token_input)

	# --- Image source ---
	var source_label = Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	vbox.add_child(source_hbox)

	_ia_source_preview = TextureRect.new()
	_ia_source_preview.custom_minimum_size = Vector2(64, 64)
	_ia_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_ia_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	source_hbox.add_child(_ia_source_preview)

	_ia_source_path_label = Label.new()
	_ia_source_path_label.text = "Aucune image sélectionnée"
	_ia_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(_ia_source_path_label)

	_ia_choose_source_btn = Button.new()
	_ia_choose_source_btn.text = "Parcourir..."
	_ia_choose_source_btn.pressed.connect(_on_ia_choose_source)
	source_hbox.add_child(_ia_choose_source_btn)

	_ia_choose_gallery_btn = Button.new()
	_ia_choose_gallery_btn.text = "Galerie..."
	_ia_choose_gallery_btn.pressed.connect(_on_ia_choose_from_gallery)
	source_hbox.add_child(_ia_choose_gallery_btn)

	# --- Prompt ---
	var prompt_label = Label.new()
	prompt_label.text = "Prompt :"
	vbox.add_child(prompt_label)

	_ia_prompt_input = TextEdit.new()
	_ia_prompt_input.custom_minimum_size.y = 60
	_ia_prompt_input.placeholder_text = "Décrivez l'image à générer..."
	_ia_prompt_input.text_changed.connect(func(): _ia_update_generate_button_state())
	vbox.add_child(_ia_prompt_input)

	# --- Generate button ---
	_ia_generate_btn = Button.new()
	_ia_generate_btn.text = "Générer"
	_ia_generate_btn.disabled = true
	_ia_generate_btn.pressed.connect(_on_ia_generate_pressed)
	vbox.add_child(_ia_generate_btn)

	# --- Separator ---
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# --- Result preview ---
	_ia_result_preview = TextureRect.new()
	_ia_result_preview.custom_minimum_size = Vector2(200, 200)
	_ia_result_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ia_result_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_ia_result_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_ia_result_preview)

	# --- Status ---
	_ia_status_label = Label.new()
	_ia_status_label.text = ""
	vbox.add_child(_ia_status_label)

	_ia_progress_bar = ProgressBar.new()
	_ia_progress_bar.visible = false
	_ia_progress_bar.custom_minimum_size.y = 8
	_ia_progress_bar.indeterminate = true
	vbox.add_child(_ia_progress_bar)

	# --- Action buttons ---
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(action_hbox)

	_ia_accept_btn = Button.new()
	_ia_accept_btn.text = "Accepter"
	_ia_accept_btn.disabled = true
	_ia_accept_btn.pressed.connect(_on_ia_accept_pressed)
	action_hbox.add_child(_ia_accept_btn)

	_ia_regenerate_btn = Button.new()
	_ia_regenerate_btn.text = "Regénérer"
	_ia_regenerate_btn.disabled = true
	_ia_regenerate_btn.pressed.connect(_on_ia_regenerate_pressed)
	action_hbox.add_child(_ia_regenerate_btn)

func _on_tab_changed(tab: int) -> void:
	_reset_selection()
	if tab == GALERIE_TAB:
		_refresh_gallery()
	elif tab == IA_TAB:
		_ia_load_config()

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
	_ia_cancel_generation()
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


# --- IA Tab Methods ---

func _ia_load_config() -> void:
	var config = ComfyUIConfig.new()
	config.load_from()
	_ia_url_input.text = config.get_url()
	_ia_token_input.text = config.get_token()
	_ia_update_generate_button_state()

func _ia_update_generate_button_state() -> void:
	if _ia_generate_btn == null:
		return
	var has_url = _ia_url_input.text.strip_edges() != ""
	var has_prompt = _ia_prompt_input.text.strip_edges() != ""
	var has_source = _ia_source_image_path != ""
	_ia_generate_btn.disabled = not (has_url and has_prompt and has_source)

func _ia_show_status(message: String) -> void:
	_ia_status_label.text = message
	_ia_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_ia_progress_bar.visible = true

func _ia_show_success(message: String) -> void:
	_ia_status_label.text = message
	_ia_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_ia_progress_bar.visible = false

func _ia_show_error(message: String) -> void:
	_ia_status_label.text = message
	_ia_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_ia_progress_bar.visible = false

func _ia_set_inputs_enabled(enabled: bool) -> void:
	_ia_url_input.editable = enabled
	_ia_token_input.editable = enabled
	_ia_prompt_input.editable = enabled
	_ia_choose_source_btn.disabled = not enabled
	_ia_choose_gallery_btn.disabled = not enabled

func _on_ia_choose_source() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg ; JPG", "*.jpeg ; JPEG", "*.webp ; WEBP"])
	dialog.file_selected.connect(func(path: String):
		_ia_source_image_path = path
		_ia_source_path_label.text = path.get_file()
		_ia_load_source_preview(path)
		_ia_update_generate_button_state()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_ia_choose_from_gallery() -> void:
	var gallery_window = Window.new()
	gallery_window.title = "Choisir une image source"
	gallery_window.size = Vector2i(600, 450)
	gallery_window.exclusive = true

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	gallery_window.add_child(margin)
	margin.add_child(vbox)

	var images = _list_gallery_images()

	if images.is_empty():
		var empty_msg = Label.new()
		empty_msg.text = "Aucune image dans la galerie."
		empty_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_msg.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(empty_msg)
	else:
		var scroll = ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)

		var grid = GridContainer.new()
		grid.columns = 4
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(grid)

		for path in images:
			var container = Panel.new()
			container.custom_minimum_size = Vector2(120, 140)
			container.mouse_filter = Control.MOUSE_FILTER_STOP

			var item_vbox = VBoxContainer.new()
			item_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			item_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			container.add_child(item_vbox)

			var tex_rect = TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(100, 100)
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
			name_label.custom_minimum_size.x = 100
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			item_vbox.add_child(name_label)

			container.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					_ia_source_image_path = path
					_ia_source_path_label.text = path.get_file()
					_ia_load_source_preview(path)
					_ia_update_generate_button_state()
					gallery_window.queue_free()
			)
			grid.add_child(container)

	var cancel_btn = Button.new()
	cancel_btn.text = "Annuler"
	cancel_btn.pressed.connect(func(): gallery_window.queue_free())
	vbox.add_child(cancel_btn)

	gallery_window.close_requested.connect(func(): gallery_window.queue_free())
	add_child(gallery_window)
	gallery_window.popup_centered()

func _ia_load_source_preview(path: String) -> void:
	if path == "":
		_ia_source_preview.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		_ia_source_preview.texture = ImageTexture.create_from_image(img)
	else:
		_ia_source_preview.texture = null

func _on_ia_generate_pressed() -> void:
	# Save config
	var config = ComfyUIConfig.new()
	config.set_url(_ia_url_input.text.strip_edges())
	config.set_token(_ia_token_input.text.strip_edges())
	config.save_to()

	# Create client
	if _ia_client != null:
		_ia_client.cancel()
		_ia_client.queue_free()

	_ia_client = Node.new()
	_ia_client.set_script(ComfyUIClient)
	add_child(_ia_client)

	_ia_client.generation_completed.connect(_on_ia_generation_completed)
	_ia_client.generation_failed.connect(_on_ia_generation_failed)
	_ia_client.generation_progress.connect(_on_ia_generation_progress)

	_ia_generate_btn.disabled = true
	_ia_accept_btn.disabled = true
	_ia_regenerate_btn.disabled = true
	_ia_generated_image = null
	_ia_result_preview.texture = null
	_ia_set_inputs_enabled(false)
	_ia_show_status("Lancement...")

	var remove_bg = (_mode != Mode.BACKGROUND)
	_ia_client.generate(config, _ia_source_image_path, _ia_prompt_input.text, remove_bg)

func _on_ia_generation_completed(image: Image) -> void:
	_ia_generated_image = image
	var tex = ImageTexture.create_from_image(image)
	_ia_result_preview.texture = tex
	_ia_show_success("Génération terminée !")
	_ia_accept_btn.disabled = false
	_ia_regenerate_btn.disabled = false
	_ia_set_inputs_enabled(true)
	_ia_update_generate_button_state()

func _on_ia_generation_failed(error: String) -> void:
	_ia_show_error("Erreur : " + error)
	_ia_regenerate_btn.disabled = false
	_ia_set_inputs_enabled(true)
	_ia_update_generate_button_state()

func _on_ia_generation_progress(status: String) -> void:
	_ia_show_status(status)

func _on_ia_accept_pressed() -> void:
	if _ia_generated_image == null:
		return

	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var dir_path = _get_assets_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path = dir_path + "/ai_" + timestamp + ".png"
	_ia_generated_image.save_png(file_path)

	image_selected.emit(file_path)
	hide()

func _on_ia_regenerate_pressed() -> void:
	_on_ia_generate_pressed()

func _ia_cancel_generation() -> void:
	if _ia_client != null:
		_ia_client.cancel()
		_ia_client.queue_free()
		_ia_client = null
