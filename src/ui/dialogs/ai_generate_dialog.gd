extends Window

## Dialog pour générer un foreground via ComfyUI (IA).

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ImagePickerDialog = preload("res://src/ui/dialogs/image_picker_dialog.gd")

signal foreground_accepted(image_path: String)

var _config: RefCounted = null
var _client: Node = null
var _source_image_path: String = ""
var _generated_image: Image = null
var _story_name: String = ""

# UI elements
var _url_input: LineEdit
var _token_input: LineEdit
var _source_path_label: Label
var _source_preview: TextureRect
var _choose_source_btn: Button
var _prompt_input: TextEdit
var _generate_btn: Button
var _result_preview: TextureRect
var _status_label: Label
var _progress_bar: ProgressBar
var _accept_btn: Button
var _regenerate_btn: Button

func _ready() -> void:
	title = "Générer un foreground avec l'IA"
	size = Vector2i(700, 600)
	exclusive = true
	close_requested.connect(_on_close_requested)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.add_child(vbox)
	add_child(margin)

	# --- URL ComfyUI ---
	var url_label = Label.new()
	url_label.text = "URL ComfyUI :"
	vbox.add_child(url_label)

	_url_input = LineEdit.new()
	_url_input.placeholder_text = "http://localhost:8188"
	_url_input.text_changed.connect(func(_t): _update_generate_button_state())
	vbox.add_child(_url_input)

	# --- Token ---
	var token_label = Label.new()
	token_label.text = "Token (optionnel) :"
	vbox.add_child(token_label)

	_token_input = LineEdit.new()
	_token_input.secret = true
	_token_input.placeholder_text = "Laisser vide si pas d'auth"
	vbox.add_child(_token_input)

	# --- Image source ---
	var source_label = Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	vbox.add_child(source_hbox)

	_source_preview = TextureRect.new()
	_source_preview.custom_minimum_size = Vector2(64, 64)
	_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	source_hbox.add_child(_source_preview)

	_source_path_label = Label.new()
	_source_path_label.text = "Aucune image sélectionnée"
	_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(_source_path_label)

	_choose_source_btn = Button.new()
	_choose_source_btn.text = "Choisir..."
	_choose_source_btn.pressed.connect(_on_choose_source)
	source_hbox.add_child(_choose_source_btn)

	# --- Prompt ---
	var prompt_label = Label.new()
	prompt_label.text = "Prompt :"
	vbox.add_child(prompt_label)

	_prompt_input = TextEdit.new()
	_prompt_input.custom_minimum_size.y = 60
	_prompt_input.placeholder_text = "Décrivez le personnage ou l'objet à générer..."
	_prompt_input.text_changed.connect(func(): _update_generate_button_state())
	vbox.add_child(_prompt_input)

	# --- Generate button ---
	_generate_btn = Button.new()
	_generate_btn.text = "Générer"
	_generate_btn.disabled = true
	_generate_btn.pressed.connect(_on_generate_pressed)
	vbox.add_child(_generate_btn)

	# --- Separator ---
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# --- Result preview ---
	_result_preview = TextureRect.new()
	_result_preview.custom_minimum_size = Vector2(200, 200)
	_result_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_result_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vbox.add_child(_result_preview)

	# --- Status ---
	_status_label = Label.new()
	_status_label.text = ""
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 8
	_progress_bar.indeterminate = true
	vbox.add_child(_progress_bar)

	# --- Action buttons ---
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(action_hbox)

	_accept_btn = Button.new()
	_accept_btn.text = "Accepter"
	_accept_btn.disabled = true
	_accept_btn.pressed.connect(_on_accept_pressed)
	action_hbox.add_child(_accept_btn)

	_regenerate_btn = Button.new()
	_regenerate_btn.text = "Regénérer"
	_regenerate_btn.disabled = true
	_regenerate_btn.pressed.connect(_on_regenerate_pressed)
	action_hbox.add_child(_regenerate_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "Fermer"
	cancel_btn.pressed.connect(_on_close_requested)
	action_hbox.add_child(cancel_btn)

func setup(config: RefCounted, source_path: String) -> void:
	_config = config
	_url_input.text = config.get_url()
	_token_input.text = config.get_token()
	_source_image_path = source_path
	if source_path != "":
		_source_path_label.text = source_path.get_file()
	else:
		_source_path_label.text = "Aucune image sélectionnée"
	_update_generate_button_state()

func set_story_name(name: String) -> void:
	_story_name = name

func _update_generate_button_state() -> void:
	var has_url = _url_input.text.strip_edges() != ""
	var has_prompt = _prompt_input.text.strip_edges() != ""
	var has_source = _source_image_path != ""
	_generate_btn.disabled = not (has_url and has_prompt and has_source)

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
	_prompt_input.editable = enabled
	_choose_source_btn.disabled = not enabled

func _on_choose_source() -> void:
	var picker = Window.new()
	picker.set_script(ImagePickerDialog)
	add_child(picker)
	picker.setup(ImagePickerDialog.Mode.FOREGROUND, _story_name)
	picker.image_selected.connect(func(path: String):
		_source_image_path = path
		_source_path_label.text = path.get_file()
		_load_source_preview(path)
		_update_generate_button_state()
	)
	picker.popup_centered()

func _load_source_preview(path: String) -> void:
	var img = Image.new()
	if img.load(path) == OK:
		_source_preview.texture = ImageTexture.create_from_image(img)
	else:
		_source_preview.texture = null

func _on_generate_pressed() -> void:
	# Save config
	if _config:
		_config.set_url(_url_input.text.strip_edges())
		_config.set_token(_token_input.text.strip_edges())
		_config.save_to()

	# Create client
	if _client != null:
		_client.cancel()
		_client.queue_free()

	_client = Node.new()
	_client.set_script(ComfyUIClient)
	add_child(_client)

	_client.generation_completed.connect(_on_generation_completed)
	_client.generation_failed.connect(_on_generation_failed)
	_client.generation_progress.connect(_on_generation_progress)

	_generate_btn.disabled = true
	_accept_btn.disabled = true
	_regenerate_btn.disabled = true
	_generated_image = null
	_result_preview.texture = null
	_set_inputs_enabled(false)
	_show_status("Lancement...")

	_client.generate(_config, _source_image_path, _prompt_input.text)

func _on_generation_completed(image: Image) -> void:
	_generated_image = image
	var tex = ImageTexture.create_from_image(image)
	_result_preview.texture = tex
	_show_success("Génération terminée !")
	_accept_btn.disabled = false
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button_state()

func _on_generation_failed(error: String) -> void:
	_show_error("Erreur : " + error)
	_regenerate_btn.disabled = false
	_set_inputs_enabled(true)
	_update_generate_button_state()

func _on_generation_progress(status: String) -> void:
	_show_status(status)

func _on_regenerate_pressed() -> void:
	_on_generate_pressed()

func _on_accept_pressed() -> void:
	if _generated_image == null:
		return

	# Build save path
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	var dir_path = "user://stories/" + _story_name + "/assets/foregrounds"

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(dir_path)

	var file_path = dir_path + "/ai_" + timestamp + ".png"
	_generated_image.save_png(file_path)

	foreground_accepted.emit(file_path)
	_on_close_requested()

func _on_close_requested() -> void:
	if _client != null:
		_client.cancel()
		_client.queue_free()
		_client = null
	hide()
