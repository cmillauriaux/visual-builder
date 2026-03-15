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
var _resolve_path_fn: Callable
var _story_base_path: String = ""

# UI widgets
var _source_preview: TextureRect
var _source_path_label: Label
var _choose_source_btn: Button
var _choose_gallery_btn: Button
var _max_dim_input: SpinBox
var _dim_feedback_label: Label
var _model_option: OptionButton
var _denoise_slider: HSlider
var _denoise_value_label: Label
var _tile_btns: Array = []
var _selected_tile_size: int = 512
var _prompt_input: TextEdit
var _generate_btn: Button
var _result_preview: TextureRect
var _status_label: Label
var _progress_bar: ProgressBar
var _save_btn: Button
var _regenerate_btn: Button

# State
var _source_image_path: String = ""
var _original_size: Vector2i = Vector2i.ZERO
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
	resolve_path_fn: Callable
) -> void:
	_parent_window = parent_window
	_url_input = url_input
	_token_input = token_input
	_neg_input = neg_input
	_show_preview_fn = show_preview_fn
	_open_gallery_fn = open_gallery_fn
	_save_config_fn = save_config_fn
	_resolve_path_fn = resolve_path_fn


func build_tab(tab_container: TabContainer) -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Upscale"
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

	# Dimension maximale
	var dim_label = Label.new()
	dim_label.text = "Dimension maximale :"
	vbox.add_child(dim_label)

	var dim_hbox = HBoxContainer.new()
	dim_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(dim_hbox)

	_max_dim_input = SpinBox.new()
	_max_dim_input.min_value = 64
	_max_dim_input.max_value = 8192
	_max_dim_input.step = 64
	_max_dim_input.value = 2048
	_max_dim_input.suffix = "px"
	_max_dim_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_max_dim_input.value_changed.connect(func(_v: float): _update_dim_feedback())
	dim_hbox.add_child(_max_dim_input)

	_dim_feedback_label = Label.new()
	_dim_feedback_label.text = ""
	_dim_feedback_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dim_hbox.add_child(_dim_feedback_label)

	var dim_hint = Label.new()
	dim_hint.text = "Ratio préservé. Valeur inférieure = downscale."
	dim_hint.add_theme_font_size_override("font_size", 11)
	dim_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(dim_hint)

	# Modèle d'upscale
	var model_label = Label.new()
	model_label.text = "Modèle d'upscale :"
	vbox.add_child(model_label)

	_model_option = OptionButton.new()
	_model_option.add_item("4x-UltraSharp.pth", 0)
	_model_option.add_item("4x_NMKD-Siax_200k.pth", 1)
	_model_option.add_item("RealESRGAN_x4plus.pth", 2)
	_model_option.add_item("RealESRGAN_x4plus_anime_6B.pth", 3)
	_model_option.selected = 0
	vbox.add_child(_model_option)

	# Denoise
	var denoise_hbox = HBoxContainer.new()
	denoise_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(denoise_hbox)

	var denoise_label = Label.new()
	denoise_label.text = "Denoise :"
	denoise_hbox.add_child(denoise_label)

	_denoise_slider = HSlider.new()
	_denoise_slider.min_value = 0.0
	_denoise_slider.max_value = 1.0
	_denoise_slider.step = 0.05
	_denoise_slider.value = 0.35
	_denoise_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_denoise_slider.value_changed.connect(func(val: float):
		_denoise_value_label.text = str(snapped(val, 0.01))
	)
	denoise_hbox.add_child(_denoise_slider)

	_denoise_value_label = Label.new()
	_denoise_value_label.text = "0.35"
	_denoise_value_label.custom_minimum_size.x = 36
	denoise_hbox.add_child(_denoise_value_label)

	var denoise_hint = Label.new()
	denoise_hint.text = "0.0 — fidèle / 1.0 — créatif"
	denoise_hint.add_theme_font_size_override("font_size", 11)
	denoise_hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(denoise_hint)

	# Tile size
	var tile_label = Label.new()
	tile_label.text = "Tile size :"
	vbox.add_child(tile_label)

	var tile_hbox = HBoxContainer.new()
	tile_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(tile_hbox)

	_tile_btns = []
	_selected_tile_size = 512
	var tile_sizes = [256, 512, 768, 1024]
	var make_tile_handler = func(s: int) -> Callable:
		return func():
			_selected_tile_size = s
			for b in _tile_btns:
				b.button_pressed = (b.text == str(s))
	for tile_size in tile_sizes:
		var btn = Button.new()
		btn.text = str(tile_size)
		btn.toggle_mode = true
		btn.button_pressed = (tile_size == 512)
		btn.pressed.connect(make_tile_handler.call(tile_size))
		tile_hbox.add_child(btn)
		_tile_btns.append(btn)

	# Prompt optionnel
	var prompt_label = Label.new()
	prompt_label.text = "Prompt (optionnel) :"
	vbox.add_child(prompt_label)

	_prompt_input = TextEdit.new()
	_prompt_input.custom_minimum_size.y = 48
	_prompt_input.placeholder_text = "sharp details, high quality, crisp edges..."
	vbox.add_child(_prompt_input)

	# Generate button
	_generate_btn = Button.new()
	_generate_btn.text = "▲ Upscaler"
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
				_show_preview_fn.call(_result_preview.texture, "Résultat Upscale")
	)
	vbox.add_child(_result_preview)

	_status_label = Label.new()
	_status_label.text = ""
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 8
	_progress_bar.indeterminate = true
	vbox.add_child(_progress_bar)

	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(action_hbox)

	_save_btn = Button.new()
	_save_btn.text = "💾 Sauvegarder"
	_save_btn.disabled = true
	_save_btn.pressed.connect(_on_save_pressed)
	action_hbox.add_child(_save_btn)

	_regenerate_btn = Button.new()
	_regenerate_btn.text = "↻ Regénérer"
	_regenerate_btn.disabled = true
	_regenerate_btn.pressed.connect(_on_generate_pressed)
	action_hbox.add_child(_regenerate_btn)


func setup(story_base_path: String, has_story: bool) -> void:
	_story_base_path = story_base_path
	_choose_gallery_btn.disabled = not has_story


func update_generate_button() -> void:
	_update_generate_button()


func cancel_generation() -> void:
	if _client != null:
		_client.cancel()
		_client.queue_free()
		_client = null


# ========================================================
# Private logic
# ========================================================

static func _compute_upscale_target(original: Vector2i, max_dim: int) -> Vector2i:
	if original == Vector2i.ZERO:
		return Vector2i.ZERO
	var scale = float(max_dim) / float(max(original.x, original.y))
	return Vector2i(roundi(original.x * scale), roundi(original.y * scale))


func _update_dim_feedback() -> void:
	if _original_size == Vector2i.ZERO:
		_dim_feedback_label.text = ""
		return
	var max_dim = int(_max_dim_input.value)
	var target = _compute_upscale_target(_original_size, max_dim)
	var scale = float(max_dim) / float(max(_original_size.x, _original_size.y))
	var arrow = "↑" if scale >= 1.0 else "↓"
	_dim_feedback_label.text = "→ %d × %d px (%s%.1f×)" % [target.x, target.y, arrow, scale]


func _set_source(path: String) -> void:
	_source_image_path = path
	_source_path_label.text = path.get_file()
	_load_preview(_source_preview, path)
	var img = Image.new()
	if img.load(path) == OK:
		_original_size = Vector2i(img.get_width(), img.get_height())
	else:
		_original_size = Vector2i.ZERO
	_update_dim_feedback()
	_update_generate_button()


func _on_choose_source() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String): _set_source(path))
	_parent_window.add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_choose_from_gallery() -> void:
	_open_gallery_fn.call(func(path: String): _set_source(path))


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
	_set_inputs_enabled(false)
	_show_status("Lancement...")

	var config = ComfyUIConfig.new()
	config.set_url(_url_input.text.strip_edges())
	config.set_token(_token_input.text.strip_edges())

	var max_dim = int(_max_dim_input.value)
	var target = _compute_upscale_target(_original_size, max_dim)
	var model_name = _model_option.get_item_text(_model_option.selected)
	var denoise_val = _denoise_slider.value
	var tile_size = _selected_tile_size
	var prompt_text = _prompt_input.text.strip_edges()
	var neg_prompt = _neg_input.text.strip_edges()

	_client.generate(
		config,
		_source_image_path,
		prompt_text,
		false,
		1.0,
		4,
		ComfyUIClient.WorkflowType.UPSCALE,
		denoise_val,
		neg_prompt,
		80,
		model_name,
		tile_size,
		target.x,
		target.y
	)


func _on_generation_completed(image: Image) -> void:
	_generated_image = image
	var tex = ImageTexture.create_from_image(image)
	_result_preview.texture = tex
	_show_success("Upscale terminé !")
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
	_url_input.editable = enabled
	_token_input.editable = enabled
	_neg_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	if _story_base_path == "":
		_choose_gallery_btn.disabled = true
	else:
		_choose_gallery_btn.disabled = not enabled
	_max_dim_input.editable = enabled
	_model_option.disabled = not enabled
	_denoise_slider.editable = enabled
	_prompt_input.editable = enabled
	for btn in _tile_btns:
		btn.disabled = not enabled


func _on_save_pressed() -> void:
	if _generated_image == null:
		return

	var fg_path = _story_base_path + "/assets/foregrounds"
	var bg_path = _story_base_path + "/assets/backgrounds"
	var base_name = _source_image_path.get_file().get_basename() + "_upscaled"
	if base_name == "_upscaled":
		base_name = "upscaled_" + str(Time.get_unix_time_from_system()).replace(".", "_")

	if _source_image_path.begins_with(fg_path) and fg_path != "/assets/foregrounds":
		_do_save(fg_path, base_name)
	elif _source_image_path.begins_with(bg_path) and bg_path != "/assets/backgrounds":
		_do_save(bg_path, base_name)
	else:
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = "Où sauvegarder l'image upscalée ?"
		dialog.ok_button_text = "Foreground"
		dialog.add_button("Background", true, "background")
		_parent_window.add_child(dialog)
		dialog.confirmed.connect(func():
			_do_save(fg_path, base_name)
			dialog.queue_free()
		)
		dialog.custom_action.connect(func(action: String):
			if action == "background":
				_do_save(bg_path, base_name)
				dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()


func _do_save(dir_path: String, base_name: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path = _resolve_path_fn.call(dir_path, base_name + ".png")
	_generated_image.save_png(file_path)
	GalleryCacheService.clear_dir(dir_path)
	_show_success("Sauvegardé : " + file_path.get_file())
	_generated_image = null
	_result_preview.texture = null
	_save_btn.disabled = true


func _load_preview(tex_rect: TextureRect, path: String) -> void:
	if path == "":
		tex_rect.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
	else:
		tex_rect.texture = null
