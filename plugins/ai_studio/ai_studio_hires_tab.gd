extends RefCounted

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")

# Shared refs (set via initialize)
var _parent_window: Window
var _url_input: LineEdit
var _token_input: LineEdit
var _neg_input: TextEdit
var _show_preview_fn: Callable
var _open_gallery_fn: Callable
var _save_config_fn: Callable
var _story_base_path: String = ""

# UI widgets
var _source_preview: TextureRect
var _source_path_label: Label
var _choose_source_btn: Button
var _choose_gallery_btn: Button
var _prompt_input: TextEdit
var _cfg_slider: HSlider
var _cfg_value_label: Label
var _cfg_hint: Label
var _steps_slider: HSlider
var _steps_value_label: Label
var _denoise_slider: HSlider
var _denoise_value_label: Label
var _megapixels_slider: HSlider
var _megapixels_value_label: Label
var _generate_btn: Button
var _cancel_btn: Button
var _result_preview: TextureRect
var _dim_label: Label
var _status_label: Label
var _progress_bar: ProgressBar
var _accept_btn: Button
var _reject_btn: Button
var _regenerate_btn: Button
var _backup_info_label: Label

# State
var _source_image_path: String = ""
var _generated_image: Image = null
var _client: Node = null


func initialize(
	parent_window: Window,
	url_input: LineEdit,
	token_input: LineEdit,
	neg_input: TextEdit,
	show_preview_fn: Callable,
	open_gallery_fn: Callable,
	save_config_fn: Callable,
	_resolve_path_fn: Callable  # Non utilisé, mais requis pour la cohérence de l'interface
) -> void:
	_parent_window = parent_window
	_url_input = url_input
	_token_input = token_input
	_neg_input = neg_input
	_show_preview_fn = show_preview_fn
	_open_gallery_fn = open_gallery_fn
	_save_config_fn = save_config_fn


func build_tab(tab_container: TabContainer) -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Restauration"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 12)
	scroll.add_child(hbox)

	hbox.add_child(_build_params_column())
	hbox.add_child(_build_result_column())


func setup(story_base_path: String, has_story: bool) -> void:
	_story_base_path = story_base_path
	if _choose_gallery_btn:
		_choose_gallery_btn.disabled = not has_story


func update_generate_button() -> void:
	_update_generate_button()


func update_cfg_hint(has_negative: bool) -> void:
	if _cfg_hint:
		_cfg_hint.visible = has_negative and _cfg_slider.value < 3.0


func cancel_generation() -> void:
	if _client != null:
		_client.cancel()
		_client.queue_free()
		_client = null


# ========================================================
# Pure functions (testables sans UI)
# ========================================================

static func _compute_backup_path(source_path: String) -> String:
	var dir = source_path.get_base_dir()
	var basename = source_path.get_file().get_basename()
	return dir + "/" + basename + "_original.png"


# ========================================================
# UI construction
# ========================================================

func _build_params_column() -> Control:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	# Source image
	var source_label = Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	source_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(source_hbox)

	_source_preview = TextureRect.new()
	_source_preview.custom_minimum_size = Vector2(72, 72)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_source_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _source_preview.texture:
				_show_preview_fn.call(_source_preview.texture, _source_image_path.get_file())
	)
	source_hbox.add_child(_source_preview)

	var source_vbox = VBoxContainer.new()
	source_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(source_vbox)

	_source_path_label = Label.new()
	_source_path_label.text = "Aucune image sélectionnée"
	_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_path_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_vbox.add_child(_source_path_label)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 4)
	source_vbox.add_child(btn_hbox)

	_choose_source_btn = Button.new()
	_choose_source_btn.text = "📂 Importer…"
	_choose_source_btn.pressed.connect(_on_choose_source)
	btn_hbox.add_child(_choose_source_btn)

	_choose_gallery_btn = Button.new()
	_choose_gallery_btn.text = "🖼 Galerie…"
	_choose_gallery_btn.pressed.connect(_on_choose_from_gallery)
	_choose_gallery_btn.disabled = true
	btn_hbox.add_child(_choose_gallery_btn)

	vbox.add_child(HSeparator.new())

	# Prompt
	var prompt_label = Label.new()
	prompt_label.text = "Prompt de restauration :"
	vbox.add_child(prompt_label)

	_prompt_input = TextEdit.new()
	_prompt_input.custom_minimum_size.y = 56
	_prompt_input.placeholder_text = "high quality, sharp details, clean skin, beautiful eyes…"
	vbox.add_child(_prompt_input)

	# CFG
	var cfg_hbox = HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(cfg_hbox)

	var cfg_label = Label.new()
	cfg_label.text = "CFG :"
	cfg_label.custom_minimum_size.x = 56
	cfg_hbox.add_child(cfg_label)

	_cfg_slider = HSlider.new()
	_cfg_slider.min_value = 1.0
	_cfg_slider.max_value = 30.0
	_cfg_slider.step = 0.5
	_cfg_slider.value = 7.0
	_cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cfg_slider.value_changed.connect(func(val: float):
		_cfg_value_label.text = str(snapped(val, 0.1))
		if _cfg_hint:
			_cfg_hint.visible = (_neg_input.text.strip_edges() != "") and val < 3.0
	)
	cfg_hbox.add_child(_cfg_slider)

	_cfg_value_label = Label.new()
	_cfg_value_label.text = "7.0"
	_cfg_value_label.custom_minimum_size.x = 32
	cfg_hbox.add_child(_cfg_value_label)

	_cfg_hint = Label.new()
	_cfg_hint.text = "⚠ CFG faible avec negative prompt"
	_cfg_hint.add_theme_font_size_override("font_size", 11)
	_cfg_hint.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_cfg_hint.visible = false
	vbox.add_child(_cfg_hint)

	# Steps
	var steps_hbox = HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(steps_hbox)

	var steps_label = Label.new()
	steps_label.text = "Steps :"
	steps_label.custom_minimum_size.x = 56
	steps_hbox.add_child(steps_label)

	_steps_slider = HSlider.new()
	_steps_slider.min_value = 1
	_steps_slider.max_value = 50
	_steps_slider.step = 1
	_steps_slider.value = 25
	_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_slider.value_changed.connect(func(val: float):
		_steps_value_label.text = str(int(val))
	)
	steps_hbox.add_child(_steps_slider)

	_steps_value_label = Label.new()
	_steps_value_label.text = "25"
	_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_steps_value_label)

	# Denoise
	var denoise_hbox = HBoxContainer.new()
	denoise_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(denoise_hbox)

	var denoise_label = Label.new()
	denoise_label.text = "Denoise :"
	denoise_label.custom_minimum_size.x = 56
	denoise_hbox.add_child(denoise_label)

	_denoise_slider = HSlider.new()
	_denoise_slider.min_value = 0.0
	_denoise_slider.max_value = 1.0
	_denoise_slider.step = 0.05
	_denoise_slider.value = 0.3
	_denoise_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_denoise_slider.value_changed.connect(func(val: float):
		_denoise_value_label.text = str(snapped(val, 0.01))
	)
	denoise_hbox.add_child(_denoise_slider)

	_denoise_value_label = Label.new()
	_denoise_value_label.text = "0.30"
	_denoise_value_label.custom_minimum_size.x = 32
	denoise_hbox.add_child(_denoise_value_label)

	var denoise_hint = Label.new()
	denoise_hint.text = "0.0 = fidèle à la source · 1.0 = libre"
	denoise_hint.add_theme_font_size_override("font_size", 11)
	denoise_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(denoise_hint)

	# Megapixels slider
	var mp_hbox = HBoxContainer.new()
	mp_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(mp_hbox)

	var mp_label = Label.new()
	mp_label.text = "Mégapixels :"
	mp_label.custom_minimum_size.x = 56
	mp_hbox.add_child(mp_label)

	_megapixels_slider = HSlider.new()
	_megapixels_slider.min_value = 0.5
	_megapixels_slider.max_value = 4.0
	_megapixels_slider.step = 0.5
	_megapixels_slider.value = 1.0
	_megapixels_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_megapixels_slider.value_changed.connect(func(val: float): _megapixels_value_label.text = str(snapped(val, 0.5)))
	mp_hbox.add_child(_megapixels_slider)

	_megapixels_value_label = Label.new()
	_megapixels_value_label.text = "1.0"
	_megapixels_value_label.custom_minimum_size.x = 32
	mp_hbox.add_child(_megapixels_value_label)

	# Generate + Cancel buttons
	var gen_hbox = HBoxContainer.new()
	gen_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(gen_hbox)

	_generate_btn = Button.new()
	_generate_btn.text = "✨ Restaurer"
	_generate_btn.disabled = true
	_generate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_generate_btn.pressed.connect(_on_generate_pressed)
	gen_hbox.add_child(_generate_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "✕ Annuler"
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(func():
		cancel_generation()
		_set_inputs_enabled(true)
		_show_status("")
		_update_generate_button()
	)
	gen_hbox.add_child(_cancel_btn)

	return vbox


func _build_result_column() -> Control:
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)

	var result_label = Label.new()
	result_label.text = "Résultat :"
	vbox.add_child(result_label)

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
				_show_preview_fn.call(_result_preview.texture, "Résultat Restauration")
	)
	vbox.add_child(_result_preview)

	_dim_label = Label.new()
	_dim_label.text = ""
	_dim_label.add_theme_font_size_override("font_size", 11)
	_dim_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(_dim_label)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 8
	_progress_bar.indeterminate = true
	vbox.add_child(_progress_bar)

	_backup_info_label = Label.new()
	_backup_info_label.text = ""
	_backup_info_label.add_theme_font_size_override("font_size", 11)
	_backup_info_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	_backup_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_backup_info_label.visible = false
	vbox.add_child(_backup_info_label)

	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(action_hbox)

	_accept_btn = Button.new()
	_accept_btn.text = "✓ Accepter et remplacer"
	_accept_btn.disabled = true
	_accept_btn.pressed.connect(_on_accept_pressed)
	_accept_btn.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	action_hbox.add_child(_accept_btn)

	_reject_btn = Button.new()
	_reject_btn.text = "✕ Rejeter"
	_reject_btn.disabled = true
	_reject_btn.pressed.connect(_on_reject_pressed)
	action_hbox.add_child(_reject_btn)

	_regenerate_btn = Button.new()
	_regenerate_btn.text = "↻ Regénérer"
	_regenerate_btn.disabled = true
	_regenerate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(_regenerate_btn)

	return vbox


# ========================================================
# Private logic
# ========================================================

func _on_choose_source() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String): _set_source(path))
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_choose_from_gallery() -> void:
	_open_gallery_fn.call(func(path: String): _set_source(path))


func _set_source(path: String) -> void:
	_source_image_path = path
	_source_path_label.text = path.get_file()
	_load_preview(_source_preview, path)
	_update_backup_info()
	_update_generate_button()


func _update_backup_info() -> void:
	if _source_image_path == "" or _backup_info_label == null:
		return
	var backup_path = _compute_backup_path(_source_image_path)
	_backup_info_label.text = "Backup : " + backup_path.get_file()
	_backup_info_label.visible = true


func _update_generate_button() -> void:
	if _generate_btn == null:
		return
	var has_url = _url_input.text.strip_edges() != ""
	var has_source = _source_image_path != ""
	_generate_btn.disabled = not (has_url and has_source)


func _on_generate_pressed() -> void:
	_save_config_fn.call()

	if _client != null:
		_client.cancel()
		_client.queue_free()
		_client = null

	_client = Node.new()
	_client.set_script(ComfyUIClient)
	_parent_window.add_child(_client)

	_client.generation_completed.connect(_on_generation_completed)
	_client.generation_failed.connect(_on_generation_failed)
	_client.generation_progress.connect(_on_generation_progress)

	_generate_btn.disabled = true
	_cancel_btn.visible = true
	_accept_btn.disabled = true
	_reject_btn.disabled = true
	_regenerate_btn.disabled = true
	_generated_image = null
	_result_preview.texture = null
	_dim_label.text = ""
	_set_inputs_enabled(false)
	_show_status("Lancement de la restauration…")

	var config = ComfyUIConfig.new()
	config.set_url(_url_input.text.strip_edges())
	config.set_token(_token_input.text.strip_edges())

	_client.generate(
		config,
		_source_image_path,
		_prompt_input.text.strip_edges(),
		false,  # remove_background non utilisé pour HIRES
		_cfg_slider.value,
		int(_steps_slider.value),
		ComfyUIClient.WorkflowType.HIRES,
		_denoise_slider.value,
		_neg_input.text.strip_edges(),
		80, "4x-UltraSharp.pth", 512, 0, 0,
		_megapixels_slider.value
	)


func _on_generation_completed(image: Image) -> void:
	if _client != null:
		_client.queue_free()
	_client = null
	_generated_image = image
	_result_preview.texture = ImageTexture.create_from_image(image)
	_dim_label.text = "%d × %d px (même résolution que la source)" % [image.get_width(), image.get_height()]
	_cancel_btn.visible = false
	_show_success("Restauration terminée !")
	_accept_btn.disabled = false
	_reject_btn.disabled = false
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_failed(error: String) -> void:
	if _client != null:
		_client.queue_free()
	_client = null
	_cancel_btn.visible = false
	_accept_btn.disabled = true
	_reject_btn.disabled = true
	_show_error("Erreur : " + error)
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button()


func _on_generation_progress(status: String) -> void:
	_show_status(status)


func _on_accept_pressed() -> void:
	if _generated_image == null or _source_image_path == "":
		return

	var backup_path = _compute_backup_path(_source_image_path)
	if not FileAccess.file_exists(backup_path):
		var err = DirAccess.copy_absolute(_source_image_path, backup_path)
		if err != OK:
			_show_error("Backup échoué (%s). Source non modifiée." % error_string(err))
			return

	var dir_path = _source_image_path.get_base_dir()
	var save_err = _generated_image.save_png(_source_image_path)
	if save_err != OK:
		_show_error("Échec de la sauvegarde (%s)." % error_string(save_err))
		return

	GalleryCacheService.clear_dir(dir_path)
	_reset_to_empty()
	_show_success("Image remplacée avec succès !")


func _on_reject_pressed() -> void:
	_generated_image = null
	_result_preview.texture = null
	_accept_btn.disabled = true
	_reject_btn.disabled = true
	_regenerate_btn.disabled = true
	_show_status("")


func _reset_to_empty() -> void:
	_source_image_path = ""
	_source_path_label.text = "Aucune image sélectionnée"
	_source_preview.texture = null
	_generated_image = null
	_result_preview.texture = null
	_dim_label.text = ""
	_cancel_btn.visible = false
	_accept_btn.disabled = true
	_reject_btn.disabled = true
	_regenerate_btn.disabled = true
	_backup_info_label.visible = false
	_show_status("")
	_update_generate_button()


func _set_inputs_enabled(enabled: bool) -> void:
	_url_input.editable = enabled
	_token_input.editable = enabled
	_neg_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	if _story_base_path == "":
		_choose_gallery_btn.disabled = true
	else:
		_choose_gallery_btn.disabled = not enabled
	_prompt_input.editable = enabled
	_cfg_slider.editable = enabled
	_steps_slider.editable = enabled
	_denoise_slider.editable = enabled
	_megapixels_slider.editable = enabled


func _show_status(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_progress_bar.visible = message != ""


func _show_success(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_progress_bar.visible = false


func _show_error(message: String) -> void:
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_progress_bar.visible = false


func _load_preview(tex_rect: TextureRect, path: String) -> void:
	if path == "":
		tex_rect.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
	else:
		tex_rect.texture = null
