extends ScrollContainer

## Onglet IA pour ImagePickerDialog, géré par le plugin AI Studio.
## Reçoit son contexte via setup(ctx: Dictionary).

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")

## Context keys provided by image_picker_dialog:
##   mode: int (0=BACKGROUND, 1=FOREGROUND, 2=ICON)
##   story_base_path: String
##   story
##   category_service
##   on_image_selected: Callable(path: String)
##   on_show_preview: Callable(texture: Texture2D, filename: String)
var _ctx: Dictionary = {}

# UI references
var _ia_workflow_option: OptionButton
var _ia_source_path_label: Label
var _ia_source_preview: TextureRect
var _ia_choose_source_btn: Button
var _ia_choose_gallery_btn: Button
var _ia_prompt_input: TextEdit
var _ia_cfg_slider: HSlider
var _ia_cfg_value_label: Label
var _ia_steps_slider: HSlider
var _ia_steps_value_label: Label
var _ia_generate_btn: Button
var _ia_result_preview: TextureRect
var _ia_status_label: Label
var _ia_progress_bar: ProgressBar
var _ia_name_input: LineEdit
var _ia_accept_btn: Button
var _ia_regenerate_btn: Button

# State
var _ia_client: Node = null
var _ia_source_image_path: String = ""
var _ia_generated_image: Image = null


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_ui()
	visibility_changed.connect(func():
		if visible:
			_ia_load_config()
	)


func setup(ctx: Dictionary) -> void:
	_ctx = ctx
	if _ia_choose_gallery_btn:
		_ia_choose_gallery_btn.disabled = (ctx.get("story_base_path", "") == "")


func set_source_image(path: String) -> void:
	_ia_source_image_path = path
	if _ia_source_path_label:
		_ia_source_path_label.text = path.get_file() if path != "" else "Aucune image sélectionnée"
	_ia_load_source_preview(path)
	_ia_update_generate_button_state()


func cleanup() -> void:
	_ia_cancel_generation()


func _build_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# --- Workflow ---
	var workflow_label := Label.new()
	workflow_label.text = "Workflow :"
	vbox.add_child(workflow_label)

	_ia_workflow_option = OptionButton.new()
	_ia_workflow_option.add_item("Création", 0)
	_ia_workflow_option.add_item("Expression", 1)
	_ia_workflow_option.selected = 0
	vbox.add_child(_ia_workflow_option)

	# --- Image source ---
	var source_label := Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox := HBoxContainer.new()
	vbox.add_child(source_hbox)

	_ia_source_preview = TextureRect.new()
	_ia_source_preview.custom_minimum_size = Vector2(64, 64)
	_ia_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_ia_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ia_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_ia_source_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _ia_source_preview.texture and _ctx.has("on_show_preview"):
				_ctx.on_show_preview.call(_ia_source_preview.texture, _ia_source_image_path.get_file())
	)
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
	var prompt_label := Label.new()
	prompt_label.text = "Prompt :"
	vbox.add_child(prompt_label)

	_ia_prompt_input = TextEdit.new()
	_ia_prompt_input.custom_minimum_size.y = 60
	_ia_prompt_input.placeholder_text = "Décrivez l'image à générer..."
	_ia_prompt_input.text_changed.connect(func(): _ia_update_generate_button_state())
	vbox.add_child(_ia_prompt_input)

	# --- CFG slider ---
	var cfg_hbox := HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(cfg_hbox)

	var cfg_label := Label.new()
	cfg_label.text = "CFG :"
	cfg_hbox.add_child(cfg_label)

	_ia_cfg_slider = HSlider.new()
	_ia_cfg_slider.min_value = 1.0
	_ia_cfg_slider.max_value = 30.0
	_ia_cfg_slider.step = 0.5
	_ia_cfg_slider.value = 1.0
	_ia_cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ia_cfg_slider.value_changed.connect(func(val: float): _ia_cfg_value_label.text = str(val))
	cfg_hbox.add_child(_ia_cfg_slider)

	_ia_cfg_value_label = Label.new()
	_ia_cfg_value_label.text = "1.0"
	_ia_cfg_value_label.custom_minimum_size.x = 32
	cfg_hbox.add_child(_ia_cfg_value_label)

	# --- Steps slider ---
	var steps_hbox := HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(steps_hbox)

	var steps_label := Label.new()
	steps_label.text = "Steps :"
	steps_hbox.add_child(steps_label)

	_ia_steps_slider = HSlider.new()
	_ia_steps_slider.min_value = 1
	_ia_steps_slider.max_value = 50
	_ia_steps_slider.step = 1
	_ia_steps_slider.value = 4
	_ia_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ia_steps_slider.value_changed.connect(func(val: float): _ia_steps_value_label.text = str(int(val)))
	steps_hbox.add_child(_ia_steps_slider)

	_ia_steps_value_label = Label.new()
	_ia_steps_value_label.text = "4"
	_ia_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_ia_steps_value_label)

	# --- Generate button ---
	_ia_generate_btn = Button.new()
	_ia_generate_btn.text = "Générer"
	_ia_generate_btn.disabled = true
	_ia_generate_btn.pressed.connect(_on_ia_generate_pressed)
	vbox.add_child(_ia_generate_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# --- Result preview ---
	_ia_result_preview = TextureRect.new()
	_ia_result_preview.custom_minimum_size = Vector2(200, 200)
	_ia_result_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_ia_result_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_ia_result_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ia_result_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_ia_result_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _ia_result_preview.texture and _ctx.has("on_show_preview"):
				_ctx.on_show_preview.call(_ia_result_preview.texture, "Résultat IA")
	)
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

	# --- Image name ---
	var name_label := Label.new()
	name_label.text = "Nom de l'image :"
	vbox.add_child(name_label)

	_ia_name_input = LineEdit.new()
	_ia_name_input.placeholder_text = "Nom du fichier (sans extension)"
	_ia_name_input.editable = false
	vbox.add_child(_ia_name_input)

	# --- Action buttons ---
	var action_hbox := HBoxContainer.new()
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


func _ia_load_config() -> void:
	_ia_update_generate_button_state()


func _ia_update_generate_button_state() -> void:
	if _ia_generate_btn == null:
		return
	var config := ComfyUIConfig.new()
	config.load_from()
	var has_url := config.get_url() != ""
	var has_prompt := _ia_prompt_input.text.strip_edges() != ""
	var has_source := _ia_source_image_path != ""
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
	_ia_prompt_input.editable = enabled
	_ia_name_input.editable = enabled
	_ia_choose_source_btn.disabled = not enabled
	_ia_choose_gallery_btn.disabled = not enabled
	_ia_workflow_option.disabled = not enabled


func _on_ia_choose_source() -> void:
	var dialog := ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String):
		_ia_source_image_path = path
		_ia_source_path_label.text = path.get_file()
		_ia_load_source_preview(path)
		_ia_update_generate_button_state()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_ia_choose_from_gallery() -> void:
	var story_base_path: String = _ctx.get("story_base_path", "")
	var category_service = _ctx.get("category_service", null)

	var gallery_window := Window.new()
	gallery_window.title = "Choisir une image source"
	gallery_window.size = Vector2i(600, 450)
	gallery_window.exclusive = true

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	gallery_window.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var filter_hbox := HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(filter_hbox)

	var filter_label := Label.new()
	filter_label.text = "Filtrer :"
	filter_hbox.add_child(filter_label)

	var source_checkboxes: Array = []
	if category_service:
		for cat in category_service.get_categories():
			var cb := CheckBox.new()
			cb.text = cat
			filter_hbox.add_child(cb)
			source_checkboxes.append(cb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var empty_msg := Label.new()
	empty_msg.text = "Aucune image dans la galerie."
	empty_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_msg.visible = false
	vbox.add_child(empty_msg)

	var rebuild_grid := func():
		for child in grid.get_children():
			child.queue_free()
		var mode: int = _ctx.get("mode", 1)
		var assets_dir := _get_assets_dir(mode, story_base_path)
		var all_images: Array = []
		if story_base_path != "":
			all_images = DirAccess.get_files_at(assets_dir) if DirAccess.dir_exists_absolute(assets_dir) else []
			all_images = all_images.filter(func(f): return f.get_extension() in ["png", "jpg", "jpeg", "webp"])
			all_images = all_images.map(func(f): return assets_dir + "/" + f)
		var selected_cats: Array = []
		for cb in source_checkboxes:
			if cb.button_pressed:
				selected_cats.append(cb.text)
		var images := all_images
		if not selected_cats.is_empty() and category_service:
			images = category_service.filter_paths_by_categories(all_images, selected_cats)
		empty_msg.visible = images.is_empty()
		scroll.visible = not images.is_empty()
		for path in images:
			var container := Panel.new()
			container.custom_minimum_size = Vector2(120, 140)
			container.mouse_filter = Control.MOUSE_FILTER_STOP
			var item_vbox := VBoxContainer.new()
			item_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			item_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			item_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
			container.add_child(item_vbox)
			var tex_rect := TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(100, 100)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var img := Image.new()
			if img.load(path) == OK:
				tex_rect.texture = ImageTexture.create_from_image(img)
			item_vbox.add_child(tex_rect)
			var name_label := Label.new()
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

	for cb in source_checkboxes:
		cb.toggled.connect(func(_p): rebuild_grid.call())

	rebuild_grid.call()

	var cancel_btn := Button.new()
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
	if not FileAccess.file_exists(path):
		_ia_source_preview.texture = null
		return
	var img := Image.new()
	if img.load(path) == OK:
		_ia_source_preview.texture = ImageTexture.create_from_image(img)
	else:
		_ia_source_preview.texture = null


func _on_ia_generate_pressed() -> void:
	var config := ComfyUIConfig.new()
	config.load_from()

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
	_ia_name_input.text = ""
	_ia_name_input.editable = false
	_ia_set_inputs_enabled(false)
	_ia_show_status("Lancement...")

	var mode: int = _ctx.get("mode", 1)
	var remove_bg := (mode != 0)  # 0 = BACKGROUND
	var cfg_value := _ia_cfg_slider.value
	var steps_value := int(_ia_steps_slider.value)
	var workflow_type := _ia_workflow_option.get_selected_id()
	var neg_prompt := config.get_negative_prompt()
	_ia_client.generate(config, _ia_source_image_path, _ia_prompt_input.text, remove_bg, cfg_value, steps_value, workflow_type, 0.5, neg_prompt)


func _on_ia_generation_completed(image: Image) -> void:
	_ia_generated_image = image
	var tex := ImageTexture.create_from_image(image)
	_ia_result_preview.texture = tex
	_ia_show_success("Génération terminée !")
	var timestamp := str(Time.get_unix_time_from_system()).replace(".", "_")
	_ia_name_input.text = "ai_" + timestamp
	_ia_name_input.editable = true
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

	var name := _ia_name_input.text.strip_edges()
	if name == "":
		var timestamp := str(Time.get_unix_time_from_system()).replace(".", "_")
		name = "ai_" + timestamp

	var format_error := ImageRenameService.validate_name_format(name)
	if format_error != "":
		_ia_show_error(format_error)
		return

	var mode: int = _ctx.get("mode", 1)
	var story_base_path: String = _ctx.get("story_base_path", "")
	var dir_path := _get_assets_dir(mode, story_base_path)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path := dir_path + "/" + name + ".png"

	if FileAccess.file_exists(file_path):
		var dialog := ConfirmationDialog.new()
		dialog.dialog_text = "L'image « %s » existe déjà.\nVoulez-vous l'écraser ?" % file_path.get_file()
		dialog.ok_button_text = "Écraser"
		add_child(dialog)
		dialog.confirmed.connect(func():
			_ia_do_save(file_path, dir_path)
			dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return

	_ia_do_save(file_path, dir_path)


func _ia_do_save(file_path: String, dir_path: String) -> void:
	_ia_generated_image.save_png(file_path)
	var GalleryCacheService = load("res://src/services/gallery_cache_service.gd")
	GalleryCacheService.clear_dir(dir_path)
	if _ctx.has("on_image_selected"):
		_ctx.on_image_selected.call(file_path)


func _on_ia_regenerate_pressed() -> void:
	_on_ia_generate_pressed()


func _ia_cancel_generation() -> void:
	if _ia_client != null:
		_ia_client.cancel()
		_ia_client.queue_free()
		_ia_client = null


static func _get_assets_dir(mode: int, story_base_path: String) -> String:
	if mode == 0:  # BACKGROUND
		return story_base_path + "/assets/backgrounds"
	if mode == 2:  # ICON
		return story_base_path + "/assets/icons"
	return story_base_path + "/assets/foregrounds"
