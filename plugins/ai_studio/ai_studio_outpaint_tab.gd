extends RefCounted

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")

# Shared refs (set via initialize)
var _parent_window: Window
var _get_config_fn: Callable
var _neg_input: TextEdit
var _show_preview_fn: Callable
var _open_gallery_fn: Callable
var _save_config_fn: Callable
var _resolve_path_fn: Callable
var _story_base_path: String = ""

# UI widgets
var _source_preview: TextureRect
var _source_path_label: Label
var _choose_source_btn: Button
var _choose_gallery_btn: Button
var _prompt_input: TextEdit
var _pad_left_spin: SpinBox
var _pad_top_spin: SpinBox
var _pad_right_spin: SpinBox
var _pad_bottom_spin: SpinBox
var _feathering_slider: HSlider
var _feathering_value_label: Label
var _guidance_slider: HSlider
var _guidance_value_label: Label
var _steps_slider: HSlider
var _steps_value_label: Label
var _cfg_slider: HSlider
var _cfg_value_label: Label
var _generate_btn: Button
var _result_preview: TextureRect
var _status_label: Label
var _progress_bar: ProgressBar
var _name_input: LineEdit
var _save_btn: Button
var _regenerate_btn: Button

# State
var _client: Node = null
var _source_image_path: String = ""
var _generated_image: Image = null


func initialize(
	parent_window: Window,
	get_config_fn: Callable,
	neg_input: TextEdit,
	show_preview_fn: Callable,
	open_gallery_fn: Callable,
	save_config_fn: Callable,
	resolve_path_fn: Callable
) -> void:
	_parent_window = parent_window
	_get_config_fn = get_config_fn
	_neg_input = neg_input
	_show_preview_fn = show_preview_fn
	_open_gallery_fn = open_gallery_fn
	_save_config_fn = save_config_fn
	_resolve_path_fn = resolve_path_fn


func build_tab(tab_container: TabContainer) -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Outpainting"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Image source
	var source_label = Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	vbox.add_child(source_hbox)

	_source_preview = TextureRect.new()
	_source_preview.custom_minimum_size = Vector2(64, 64)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _source_preview.texture:
				_show_preview_fn.call(_source_preview.texture, _source_image_path.get_file())
	)
	source_hbox.add_child(_source_preview)

	_source_path_label = Label.new()
	_source_path_label.text = "Aucune image sélectionnée"
	_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(_source_path_label)

	_choose_source_btn = Button.new()
	_choose_source_btn.text = "Parcourir..."
	_choose_source_btn.pressed.connect(_on_choose_source)
	source_hbox.add_child(_choose_source_btn)

	_choose_gallery_btn = Button.new()
	_choose_gallery_btn.text = "Galerie..."
	_choose_gallery_btn.pressed.connect(_on_choose_from_gallery)
	source_hbox.add_child(_choose_gallery_btn)

	# Prompt
	var prompt_label = Label.new()
	prompt_label.text = "Prompt :"
	vbox.add_child(prompt_label)

	_prompt_input = TextEdit.new()
	_prompt_input.custom_minimum_size.y = 60
	_prompt_input.placeholder_text = "Décrivez ce qui doit apparaître dans les zones étendues..."
	_prompt_input.text_changed.connect(func(): _update_generate_button())
	vbox.add_child(_prompt_input)

	# Padding (extension pixels)
	vbox.add_child(HSeparator.new())
	var pad_label = Label.new()
	pad_label.text = "Extension (pixels) :"
	vbox.add_child(pad_label)

	var pad_grid = GridContainer.new()
	pad_grid.columns = 2
	pad_grid.add_theme_constant_override("h_separation", 12)
	pad_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(pad_grid)

	var lbl_top = Label.new()
	lbl_top.text = "Haut :"
	pad_grid.add_child(lbl_top)
	_pad_top_spin = _create_pad_spinbox()
	pad_grid.add_child(_pad_top_spin)

	var lbl_bottom = Label.new()
	lbl_bottom.text = "Bas :"
	pad_grid.add_child(lbl_bottom)
	_pad_bottom_spin = _create_pad_spinbox()
	pad_grid.add_child(_pad_bottom_spin)

	var lbl_left = Label.new()
	lbl_left.text = "Gauche :"
	pad_grid.add_child(lbl_left)
	_pad_left_spin = _create_pad_spinbox()
	pad_grid.add_child(_pad_left_spin)

	var lbl_right = Label.new()
	lbl_right.text = "Droite :"
	pad_grid.add_child(lbl_right)
	_pad_right_spin = _create_pad_spinbox()
	pad_grid.add_child(_pad_right_spin)

	# Feathering
	var feath_hbox = HBoxContainer.new()
	feath_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(feath_hbox)

	var feath_label = Label.new()
	feath_label.text = "Feathering :"
	feath_hbox.add_child(feath_label)

	_feathering_slider = HSlider.new()
	_feathering_slider.min_value = 0
	_feathering_slider.max_value = 100
	_feathering_slider.step = 1
	_feathering_slider.value = 24
	_feathering_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_feathering_slider.value_changed.connect(func(val: float): _feathering_value_label.text = str(int(val)))
	feath_hbox.add_child(_feathering_slider)

	_feathering_value_label = Label.new()
	_feathering_value_label.text = "24"
	_feathering_value_label.custom_minimum_size.x = 32
	feath_hbox.add_child(_feathering_value_label)

	vbox.add_child(HSeparator.new())

	# Guidance (FluxGuidance)
	var guid_hbox = HBoxContainer.new()
	guid_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(guid_hbox)

	var guid_label = Label.new()
	guid_label.text = "Guidance :"
	guid_hbox.add_child(guid_label)

	_guidance_slider = HSlider.new()
	_guidance_slider.min_value = 1.0
	_guidance_slider.max_value = 100.0
	_guidance_slider.step = 1.0
	_guidance_slider.value = 40.0
	_guidance_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guidance_slider.value_changed.connect(func(val: float): _guidance_value_label.text = str(int(val)))
	guid_hbox.add_child(_guidance_slider)

	_guidance_value_label = Label.new()
	_guidance_value_label.text = "40"
	_guidance_value_label.custom_minimum_size.x = 32
	guid_hbox.add_child(_guidance_value_label)

	# Steps
	var steps_hbox = HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(steps_hbox)

	var steps_label = Label.new()
	steps_label.text = "Steps :"
	steps_hbox.add_child(steps_label)

	_steps_slider = HSlider.new()
	_steps_slider.min_value = 1
	_steps_slider.max_value = 50
	_steps_slider.step = 1
	_steps_slider.value = 20
	_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_slider.value_changed.connect(func(val: float): _steps_value_label.text = str(int(val)))
	steps_hbox.add_child(_steps_slider)

	_steps_value_label = Label.new()
	_steps_value_label.text = "20"
	_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_steps_value_label)

	# CFG
	var cfg_hbox = HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(cfg_hbox)

	var cfg_label = Label.new()
	cfg_label.text = "CFG :"
	cfg_hbox.add_child(cfg_label)

	_cfg_slider = HSlider.new()
	_cfg_slider.min_value = 0.1
	_cfg_slider.max_value = 5.0
	_cfg_slider.step = 0.1
	_cfg_slider.value = 0.7
	_cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cfg_slider.value_changed.connect(func(val: float): _cfg_value_label.text = str(snapped(val, 0.1)))
	cfg_hbox.add_child(_cfg_slider)

	_cfg_value_label = Label.new()
	_cfg_value_label.text = "0.7"
	_cfg_value_label.custom_minimum_size.x = 32
	cfg_hbox.add_child(_cfg_value_label)

	# Generate button
	_generate_btn = Button.new()
	_generate_btn.text = "Générer"
	_generate_btn.disabled = true
	_generate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(_generate_btn)

	vbox.add_child(HSeparator.new())

	# Result preview
	_result_preview = TextureRect.new()
	_result_preview.custom_minimum_size = Vector2(200, 200)
	_result_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_result_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_result_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_result_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _result_preview.texture:
				_show_preview_fn.call(_result_preview.texture, "Résultat Outpaint")
	)
	vbox.add_child(_result_preview)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 8
	_progress_bar.indeterminate = true
	vbox.add_child(_progress_bar)

	# Image name
	var name_label = Label.new()
	name_label.text = "Nom de l'image :"
	vbox.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.placeholder_text = "Nom du fichier (sans extension)"
	_name_input.editable = false
	vbox.add_child(_name_input)

	# Action buttons
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(action_hbox)

	_save_btn = Button.new()
	_save_btn.text = "Sauvegarder"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_on_save_pressed)
	action_hbox.add_child(_save_btn)

	_regenerate_btn = Button.new()
	_regenerate_btn.text = "Regénérer"
	_regenerate_btn.disabled = true
	_regenerate_btn.pressed.connect(_on_generate_pressed)
	action_hbox.add_child(_regenerate_btn)


func setup(story_base_path: String, has_story: bool) -> void:
	_story_base_path = story_base_path
	_choose_gallery_btn.disabled = not has_story


func update_generate_button() -> void:
	_update_generate_button()


func update_cfg_hint(_has_negative: bool) -> void:
	pass


func cancel_generation() -> void:
	if _client != null:
		_client.cancel()
		_client.queue_free()
		_client = null


# ========================================================
# Private logic
# ========================================================

func _create_pad_spinbox() -> SpinBox:
	var spin = SpinBox.new()
	spin.min_value = 0
	spin.max_value = 2048
	spin.step = 8
	spin.value = 0
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.value_changed.connect(func(_val: float): _update_generate_button())
	return spin


func _has_any_padding() -> bool:
	return int(_pad_left_spin.value) > 0 or int(_pad_top_spin.value) > 0 \
		or int(_pad_right_spin.value) > 0 or int(_pad_bottom_spin.value) > 0


func _update_generate_button() -> void:
	if _generate_btn == null:
		return
	var has_url = _get_config_fn.call().get_url() != ""
	var has_prompt = _prompt_input.text.strip_edges() != ""
	var has_source = _source_image_path != ""
	var has_padding = _has_any_padding()
	_generate_btn.disabled = not (has_url and has_prompt and has_source and has_padding)


func _on_choose_source() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String):
		_source_image_path = path
		_source_path_label.text = path.get_file()
		_load_preview(_source_preview, path)
		_update_generate_button()
	)
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_choose_from_gallery() -> void:
	_open_gallery_fn.call(func(path: String):
		_source_image_path = path
		_source_path_label.text = path.get_file()
		_load_preview(_source_preview, path)
		_update_generate_button()
	)


func _on_generate_pressed() -> void:
	_save_config_fn.call()

	if _client != null:
		_client.cancel()
		_client.queue_free()

	_client = Node.new()
	_client.set_script(ComfyUIClient)
	_parent_window.add_child(_client)

	_client.generation_completed.connect(_on_generation_completed)
	_client.generation_failed.connect(_on_generation_failed)
	_client.generation_progress.connect(_on_generation_progress)

	_generate_btn.disabled = true
	_save_btn.disabled = true
	_regenerate_btn.disabled = true
	_generated_image = null
	_result_preview.texture = null
	_name_input.text = ""
	_name_input.editable = false
	_set_inputs_enabled(false)
	_show_status("Lancement...")

	var config = _get_config_fn.call()
	var neg_prompt = _neg_input.text.strip_edges()

	_client.generate_outpaint(
		config,
		_source_image_path,
		_prompt_input.text,
		int(_pad_left_spin.value),
		int(_pad_top_spin.value),
		int(_pad_right_spin.value),
		int(_pad_bottom_spin.value),
		int(_feathering_slider.value),
		_guidance_slider.value,
		_cfg_slider.value,
		int(_steps_slider.value),
		neg_prompt
	)


func _on_generation_completed(image: Image) -> void:
	_generated_image = image
	var tex = ImageTexture.create_from_image(image)
	_result_preview.texture = tex
	_show_success("Génération terminée !")
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	_name_input.text = "ai_outpaint_" + timestamp
	_name_input.editable = true
	_save_btn.disabled = false
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_failed(error: String) -> void:
	_show_error("Erreur : " + error)
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_progress(status: String) -> void:
	_show_status(status)


func _on_save_pressed() -> void:
	if _generated_image == null:
		return

	var img_name = _name_input.text.strip_edges()
	if img_name == "":
		var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
		img_name = "ai_outpaint_" + timestamp

	var format_error = ImageRenameService.validate_name_format(img_name)
	if format_error != "":
		_show_error(format_error)
		return

	var dir_path = _story_base_path + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path = dir_path + "/" + img_name + ".png"

	if FileAccess.file_exists(file_path):
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = "L'image \u00ab %s \u00bb existe d\u00e9j\u00e0.\nVoulez-vous l'\u00e9craser ?" % file_path.get_file()
		dialog.ok_button_text = "\u00c9craser"
		_parent_window.add_child(dialog)
		dialog.confirmed.connect(func():
			_do_save(file_path, dir_path)
			dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return

	_do_save(file_path, dir_path)


func _do_save(file_path: String, dir_path: String) -> void:
	_generated_image.save_png(file_path)
	GalleryCacheService.clear_dir(dir_path)
	_show_success("Image sauvegard\u00e9e : " + file_path.get_file())

	# Reset for next generation
	_generated_image = null
	_result_preview.texture = null
	_name_input.text = ""
	_name_input.editable = false
	_save_btn.disabled = true


func _show_status(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_progress_bar.visible = true


func _show_success(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_progress_bar.visible = false


func _show_error(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_progress_bar.visible = false


func _set_inputs_enabled(enabled: bool) -> void:
	_neg_input.editable = enabled
	_prompt_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	_choose_gallery_btn.disabled = not enabled


func _load_preview(tex_rect: TextureRect, path: String) -> void:
	if path == "":
		tex_rect.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
	else:
		tex_rect.texture = null
