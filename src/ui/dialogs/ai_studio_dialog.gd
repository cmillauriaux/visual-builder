extends Window

## Studio IA : dialogue avancé de génération d'images par IA.
## Deux onglets : Décliner (génération unitaire) et Expressions (génération par lots).

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ImagePreviewPopup = preload("res://src/ui/shared/image_preview_popup.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")
const ImageCategoryService = preload("res://src/services/image_category_service.gd")
const ExpressionQueueService = preload("res://src/services/expression_queue_service.gd")

const ELEMENTARY_EXPRESSIONS := [
	"smile", "sad", "shy", "grumpy", "laughing out loud",
	"angry", "surprised", "scared", "bored", "speaking",
	"happy", "calm", "crying", "determined", "exhausted",
	"annoyed",
]

const ADVANCED_EXPRESSIONS := [
	"worried", "neutral", "disgusted", "confused", "proud",
	"embarrassed", "idle", "thinking", "listening", "cheerful",
	"confident", "playful", "curious", "warm", "friendly",
	"joyful", "serene", "enthusiastic", "excited", "hopeful",
	"jealous", "dreamy", "mischievous", "relieved", "suspicious",
	"tender", "desperate", "nostalgic", "seductive",
]

var _story = null
var _story_base_path: String = ""
var _category_service: RefCounted = null

# Shared UI
var _tab_container: TabContainer
var _url_input: LineEdit
var _token_input: LineEdit
var _negative_prompt_input: TextEdit
var _image_preview: Control

# --- Décliner tab ---
var _decl_workflow_option: OptionButton
var _decl_source_preview: TextureRect
var _decl_source_path_label: Label
var _decl_choose_source_btn: Button
var _decl_choose_gallery_btn: Button
var _decl_prompt_input: TextEdit
var _decl_cfg_slider: HSlider
var _decl_cfg_value_label: Label
var _decl_cfg_hint: Label
var _decl_steps_slider: HSlider
var _decl_steps_value_label: Label
var _decl_generate_btn: Button
var _decl_result_preview: TextureRect
var _decl_status_label: Label
var _decl_progress_bar: ProgressBar
var _decl_name_input: LineEdit
var _decl_save_btn: Button
var _decl_regenerate_btn: Button

# Décliner state
var _decl_client: Node = null
var _decl_source_image_path: String = ""
var _decl_generated_image: Image = null

# --- Expressions tab ---
var _expr_source_preview: TextureRect
var _expr_source_path_label: Label
var _expr_choose_source_btn: Button
var _expr_choose_gallery_btn: Button
var _expr_prefix_input: LineEdit
var _expr_cfg_slider: HSlider
var _expr_cfg_value_label: Label
var _expr_cfg_hint: Label
var _expr_steps_slider: HSlider
var _expr_steps_value_label: Label
var _expr_denoise_slider: HSlider
var _expr_denoise_value_label: Label
var _expr_face_box_slider: HSlider
var _expr_face_box_value_label: Label
var _expr_elementary_checkboxes: Array = []
var _expr_advanced_checkboxes: Array = []
var _expr_elementary_select_all_btn: Button
var _expr_advanced_select_all_btn: Button
var _expr_custom_container: VBoxContainer
var _expr_custom_input: LineEdit
var _expr_add_custom_btn: Button
var _expr_generate_btn: Button
var _expr_cancel_btn: Button
var _expr_status_label: Label
var _expr_progress_bar: ProgressBar
var _expr_results_grid: GridContainer
var _expr_save_all_btn: Button
var _expr_preview_btn: Button
var _expr_context_menu: PopupMenu

# Expressions state
var _expr_source_image_path: String = ""
var _expr_client: Node = null
var _expr_queue: RefCounted = null
var _expr_generating: bool = false
var _expr_context_index: int = -1


func _ready() -> void:
	title = "Studio IA"
	size = Vector2i(1100, 700)
	exclusive = true
	close_requested.connect(_on_close)
	_build_ui()
	_load_config()


func setup(story, story_base_path: String) -> void:
	_story = story
	_story_base_path = story_base_path
	_category_service = ImageCategoryService.new()
	if story_base_path != "":
		_category_service.load_from(story_base_path)
	var has_story = story_base_path != ""
	_decl_choose_gallery_btn.disabled = not has_story
	_expr_choose_gallery_btn.disabled = not has_story


func _on_close() -> void:
	_cancel_decl_generation()
	_cancel_expr_generation()
	queue_free()


# ========================================================
# UI Construction
# ========================================================

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
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# --- Shared ComfyUI config ---
	var url_label = Label.new()
	url_label.text = "URL ComfyUI :"
	vbox.add_child(url_label)

	_url_input = LineEdit.new()
	_url_input.placeholder_text = "http://localhost:8188"
	_url_input.text_changed.connect(func(_t): _update_all_generate_buttons())
	vbox.add_child(_url_input)

	var token_label = Label.new()
	token_label.text = "Token (optionnel) :"
	vbox.add_child(token_label)

	_token_input = LineEdit.new()
	_token_input.secret = true
	_token_input.placeholder_text = "Laisser vide si pas d'auth"
	vbox.add_child(_token_input)

	var neg_label = Label.new()
	neg_label.text = "Negative prompt (global) :"
	vbox.add_child(neg_label)

	_negative_prompt_input = TextEdit.new()
	_negative_prompt_input.placeholder_text = "Ex: blurry, low quality, deformed..."
	_negative_prompt_input.custom_minimum_size = Vector2(0, 60)
	_negative_prompt_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_negative_prompt_input.text_changed.connect(_update_cfg_hints)
	vbox.add_child(_negative_prompt_input)

	vbox.add_child(HSeparator.new())

	# --- Tabs ---
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	_build_decliner_tab()
	_build_expressions_tab()

	vbox.add_child(HSeparator.new())

	# --- Bottom bar ---
	var bottom_hbox = HBoxContainer.new()
	vbox.add_child(bottom_hbox)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	var close_btn = Button.new()
	close_btn.text = "Fermer"
	close_btn.pressed.connect(_on_close)
	bottom_hbox.add_child(close_btn)

	# Image preview overlay
	_image_preview = Control.new()
	_image_preview.set_script(ImagePreviewPopup)
	_image_preview.regenerate_requested.connect(_on_preview_regenerate)
	_image_preview.delete_requested.connect(_on_preview_delete)
	add_child(_image_preview)


# ========================================================
# Décliner Tab
# ========================================================

func _build_decliner_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Décliner"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Workflow selector
	var workflow_label = Label.new()
	workflow_label.text = "Workflow :"
	vbox.add_child(workflow_label)

	_decl_workflow_option = OptionButton.new()
	_decl_workflow_option.add_item("Création", 0)
	_decl_workflow_option.add_item("Expression", 1)
	_decl_workflow_option.selected = 0
	vbox.add_child(_decl_workflow_option)

	# Image source
	var source_label = Label.new()
	source_label.text = "Image source :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	vbox.add_child(source_hbox)

	_decl_source_preview = TextureRect.new()
	_decl_source_preview.custom_minimum_size = Vector2(64, 64)
	_decl_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_decl_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_decl_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_decl_source_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _decl_source_preview.texture:
				_show_image_preview(_decl_source_preview.texture, _decl_source_image_path.get_file())
	)
	source_hbox.add_child(_decl_source_preview)

	_decl_source_path_label = Label.new()
	_decl_source_path_label.text = "Aucune image sélectionnée"
	_decl_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(_decl_source_path_label)

	_decl_choose_source_btn = Button.new()
	_decl_choose_source_btn.text = "Parcourir..."
	_decl_choose_source_btn.pressed.connect(_on_decl_choose_source)
	source_hbox.add_child(_decl_choose_source_btn)

	_decl_choose_gallery_btn = Button.new()
	_decl_choose_gallery_btn.text = "Galerie..."
	_decl_choose_gallery_btn.pressed.connect(_on_decl_choose_from_gallery)
	source_hbox.add_child(_decl_choose_gallery_btn)

	# Prompt
	var prompt_label = Label.new()
	prompt_label.text = "Prompt :"
	vbox.add_child(prompt_label)

	_decl_prompt_input = TextEdit.new()
	_decl_prompt_input.custom_minimum_size.y = 60
	_decl_prompt_input.placeholder_text = "Décrivez l'image à générer..."
	_decl_prompt_input.text_changed.connect(func(): _update_decl_generate_button())
	vbox.add_child(_decl_prompt_input)

	# CFG slider
	var cfg_hbox = HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(cfg_hbox)

	var cfg_label = Label.new()
	cfg_label.text = "CFG :"
	cfg_hbox.add_child(cfg_label)

	_decl_cfg_slider = HSlider.new()
	_decl_cfg_slider.min_value = 1.0
	_decl_cfg_slider.max_value = 30.0
	_decl_cfg_slider.step = 0.5
	_decl_cfg_slider.value = 1.0
	_decl_cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decl_cfg_slider.value_changed.connect(func(val: float):
		_decl_cfg_value_label.text = str(val)
		_update_cfg_hints()
	)
	cfg_hbox.add_child(_decl_cfg_slider)

	_decl_cfg_value_label = Label.new()
	_decl_cfg_value_label.text = "1.0"
	_decl_cfg_value_label.custom_minimum_size.x = 32
	cfg_hbox.add_child(_decl_cfg_value_label)

	_decl_cfg_hint = Label.new()
	_decl_cfg_hint.text = "CFG >= 3 requis pour le negative prompt"
	_decl_cfg_hint.add_theme_font_size_override("font_size", 11)
	_decl_cfg_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_decl_cfg_hint.visible = false
	vbox.add_child(_decl_cfg_hint)

	# Steps slider
	var steps_hbox = HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(steps_hbox)

	var steps_label = Label.new()
	steps_label.text = "Steps :"
	steps_hbox.add_child(steps_label)

	_decl_steps_slider = HSlider.new()
	_decl_steps_slider.min_value = 1
	_decl_steps_slider.max_value = 50
	_decl_steps_slider.step = 1
	_decl_steps_slider.value = 4
	_decl_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decl_steps_slider.value_changed.connect(func(val: float): _decl_steps_value_label.text = str(int(val)))
	steps_hbox.add_child(_decl_steps_slider)

	_decl_steps_value_label = Label.new()
	_decl_steps_value_label.text = "4"
	_decl_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_decl_steps_value_label)

	# Generate button
	_decl_generate_btn = Button.new()
	_decl_generate_btn.text = "Générer"
	_decl_generate_btn.disabled = true
	_decl_generate_btn.pressed.connect(_on_decl_generate_pressed)
	vbox.add_child(_decl_generate_btn)

	vbox.add_child(HSeparator.new())

	# Result preview
	_decl_result_preview = TextureRect.new()
	_decl_result_preview.custom_minimum_size = Vector2(200, 200)
	_decl_result_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_decl_result_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_decl_result_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_decl_result_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_decl_result_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _decl_result_preview.texture:
				_show_image_preview(_decl_result_preview.texture, "Résultat IA")
	)
	vbox.add_child(_decl_result_preview)

	# Status
	_decl_status_label = Label.new()
	_decl_status_label.text = ""
	vbox.add_child(_decl_status_label)

	_decl_progress_bar = ProgressBar.new()
	_decl_progress_bar.visible = false
	_decl_progress_bar.custom_minimum_size.y = 8
	_decl_progress_bar.indeterminate = true
	vbox.add_child(_decl_progress_bar)

	# Image name
	var name_label = Label.new()
	name_label.text = "Nom de l'image :"
	vbox.add_child(name_label)

	_decl_name_input = LineEdit.new()
	_decl_name_input.placeholder_text = "Nom du fichier (sans extension)"
	_decl_name_input.editable = false
	vbox.add_child(_decl_name_input)

	# Action buttons
	var action_hbox = HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(action_hbox)

	_decl_save_btn = Button.new()
	_decl_save_btn.text = "Sauvegarder"
	_decl_save_btn.disabled = true
	_decl_save_btn.pressed.connect(_on_decl_save_pressed)
	action_hbox.add_child(_decl_save_btn)

	_decl_regenerate_btn = Button.new()
	_decl_regenerate_btn.text = "Regénérer"
	_decl_regenerate_btn.disabled = true
	_decl_regenerate_btn.pressed.connect(_on_decl_generate_pressed)
	action_hbox.add_child(_decl_regenerate_btn)


# ========================================================
# Expressions Tab
# ========================================================

func _build_expressions_tab() -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Expressions"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tab_container.add_child(scroll)

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

	_expr_source_preview = TextureRect.new()
	_expr_source_preview.custom_minimum_size = Vector2(64, 64)
	_expr_source_preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_expr_source_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_expr_source_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_expr_source_preview.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if _expr_source_preview.texture:
				_show_image_preview(_expr_source_preview.texture, _expr_source_image_path.get_file())
	)
	source_hbox.add_child(_expr_source_preview)

	_expr_source_path_label = Label.new()
	_expr_source_path_label.text = "Aucune image sélectionnée"
	_expr_source_path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	source_hbox.add_child(_expr_source_path_label)

	_expr_choose_source_btn = Button.new()
	_expr_choose_source_btn.text = "Parcourir..."
	_expr_choose_source_btn.pressed.connect(_on_expr_choose_source)
	source_hbox.add_child(_expr_choose_source_btn)

	_expr_choose_gallery_btn = Button.new()
	_expr_choose_gallery_btn.text = "Galerie..."
	_expr_choose_gallery_btn.pressed.connect(_on_expr_choose_from_gallery)
	source_hbox.add_child(_expr_choose_gallery_btn)

	# Prefix
	var prefix_label = Label.new()
	prefix_label.text = "Préfixe des images :"
	vbox.add_child(prefix_label)

	_expr_prefix_input = LineEdit.new()
	_expr_prefix_input.placeholder_text = "personnage_nom"
	_expr_prefix_input.text_changed.connect(func(_t): _update_expr_generate_button())
	vbox.add_child(_expr_prefix_input)

	# CFG slider
	var cfg_hbox = HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(cfg_hbox)

	var cfg_label = Label.new()
	cfg_label.text = "CFG :"
	cfg_hbox.add_child(cfg_label)

	_expr_cfg_slider = HSlider.new()
	_expr_cfg_slider.min_value = 1.0
	_expr_cfg_slider.max_value = 30.0
	_expr_cfg_slider.step = 0.5
	_expr_cfg_slider.value = 1.0
	_expr_cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expr_cfg_slider.value_changed.connect(func(val: float):
		_expr_cfg_value_label.text = str(val)
		_update_cfg_hints()
	)
	cfg_hbox.add_child(_expr_cfg_slider)

	_expr_cfg_value_label = Label.new()
	_expr_cfg_value_label.text = "1.0"
	_expr_cfg_value_label.custom_minimum_size.x = 32
	cfg_hbox.add_child(_expr_cfg_value_label)

	_expr_cfg_hint = Label.new()
	_expr_cfg_hint.text = "CFG >= 3 requis pour le negative prompt"
	_expr_cfg_hint.add_theme_font_size_override("font_size", 11)
	_expr_cfg_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_expr_cfg_hint.visible = false
	vbox.add_child(_expr_cfg_hint)

	# Steps slider
	var steps_hbox = HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(steps_hbox)

	var steps_label = Label.new()
	steps_label.text = "Steps :"
	steps_hbox.add_child(steps_label)

	_expr_steps_slider = HSlider.new()
	_expr_steps_slider.min_value = 1
	_expr_steps_slider.max_value = 50
	_expr_steps_slider.step = 1
	_expr_steps_slider.value = 4
	_expr_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expr_steps_slider.value_changed.connect(func(val: float): _expr_steps_value_label.text = str(int(val)))
	steps_hbox.add_child(_expr_steps_slider)

	_expr_steps_value_label = Label.new()
	_expr_steps_value_label.text = "4"
	_expr_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_expr_steps_value_label)

	# Denoise slider
	var denoise_hbox = HBoxContainer.new()
	denoise_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(denoise_hbox)

	var denoise_label = Label.new()
	denoise_label.text = "Denoise :"
	denoise_hbox.add_child(denoise_label)

	_expr_denoise_slider = HSlider.new()
	_expr_denoise_slider.min_value = 0.1
	_expr_denoise_slider.max_value = 1.0
	_expr_denoise_slider.step = 0.05
	_expr_denoise_slider.value = 0.5
	_expr_denoise_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expr_denoise_slider.value_changed.connect(func(val: float): _expr_denoise_value_label.text = str(snapped(val, 0.05)))
	denoise_hbox.add_child(_expr_denoise_slider)

	_expr_denoise_value_label = Label.new()
	_expr_denoise_value_label.text = "0.5"
	_expr_denoise_value_label.custom_minimum_size.x = 32
	denoise_hbox.add_child(_expr_denoise_value_label)

	# Face box size slider
	var face_box_hbox = HBoxContainer.new()
	face_box_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(face_box_hbox)

	var face_box_label = Label.new()
	face_box_label.text = "Zone visage :"
	face_box_hbox.add_child(face_box_label)

	_expr_face_box_slider = HSlider.new()
	_expr_face_box_slider.min_value = 10
	_expr_face_box_slider.max_value = 200
	_expr_face_box_slider.step = 5
	_expr_face_box_slider.value = 80
	_expr_face_box_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_expr_face_box_slider.value_changed.connect(func(val: float): _expr_face_box_value_label.text = str(int(val)))
	face_box_hbox.add_child(_expr_face_box_slider)

	_expr_face_box_value_label = Label.new()
	_expr_face_box_value_label.text = "80"
	_expr_face_box_value_label.custom_minimum_size.x = 32
	face_box_hbox.add_child(_expr_face_box_value_label)

	vbox.add_child(HSeparator.new())

	# Expressions élémentaires
	var elem_header = HBoxContainer.new()
	vbox.add_child(elem_header)

	var elem_label = Label.new()
	elem_label.text = "Expressions élémentaires"
	elem_label.add_theme_font_size_override("font_size", 16)
	elem_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elem_header.add_child(elem_label)

	_expr_elementary_select_all_btn = Button.new()
	_expr_elementary_select_all_btn.text = "Cocher tout"
	_expr_elementary_select_all_btn.pressed.connect(func():
		var all_checked = _expr_elementary_checkboxes.all(func(c): return c.button_pressed)
		for c in _expr_elementary_checkboxes:
			c.button_pressed = not all_checked
		_update_group_select_all_btn(_expr_elementary_select_all_btn, _expr_elementary_checkboxes)
		_update_expr_generate_button()
	)
	elem_header.add_child(_expr_elementary_select_all_btn)

	var elem_flow = HFlowContainer.new()
	elem_flow.add_theme_constant_override("h_separation", 8)
	elem_flow.add_theme_constant_override("v_separation", 4)
	vbox.add_child(elem_flow)

	for i in range(ELEMENTARY_EXPRESSIONS.size()):
		var cb = CheckBox.new()
		cb.text = ELEMENTARY_EXPRESSIONS[i]
		cb.button_pressed = (i == 0)
		cb.toggled.connect(func(_p):
			_update_group_select_all_btn(_expr_elementary_select_all_btn, _expr_elementary_checkboxes)
			_update_expr_generate_button()
		)
		elem_flow.add_child(cb)
		_expr_elementary_checkboxes.append(cb)

	vbox.add_child(HSeparator.new())

	# Expressions avancées
	var adv_header = HBoxContainer.new()
	vbox.add_child(adv_header)

	var adv_label = Label.new()
	adv_label.text = "Expressions avancées"
	adv_label.add_theme_font_size_override("font_size", 16)
	adv_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adv_header.add_child(adv_label)

	_expr_advanced_select_all_btn = Button.new()
	_expr_advanced_select_all_btn.text = "Cocher tout"
	_expr_advanced_select_all_btn.pressed.connect(func():
		var all_checked = _expr_advanced_checkboxes.all(func(c): return c.button_pressed)
		for c in _expr_advanced_checkboxes:
			c.button_pressed = not all_checked
		_update_group_select_all_btn(_expr_advanced_select_all_btn, _expr_advanced_checkboxes)
		_update_expr_generate_button()
	)
	adv_header.add_child(_expr_advanced_select_all_btn)

	var adv_flow = HFlowContainer.new()
	adv_flow.add_theme_constant_override("h_separation", 8)
	adv_flow.add_theme_constant_override("v_separation", 4)
	vbox.add_child(adv_flow)

	for expr in ADVANCED_EXPRESSIONS:
		var cb = CheckBox.new()
		cb.text = expr
		cb.button_pressed = false
		cb.toggled.connect(func(_p):
			_update_group_select_all_btn(_expr_advanced_select_all_btn, _expr_advanced_checkboxes)
			_update_expr_generate_button()
		)
		adv_flow.add_child(cb)
		_expr_advanced_checkboxes.append(cb)

	# Custom expressions
	vbox.add_child(HSeparator.new())

	var custom_label = Label.new()
	custom_label.text = "Expressions personnalisées :"
	vbox.add_child(custom_label)

	_expr_custom_container = VBoxContainer.new()
	_expr_custom_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_expr_custom_container)

	var add_hbox = HBoxContainer.new()
	add_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(add_hbox)

	_expr_custom_input = LineEdit.new()
	_expr_custom_input.placeholder_text = "Nouvelle expression..."
	_expr_custom_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_hbox.add_child(_expr_custom_input)

	_expr_add_custom_btn = Button.new()
	_expr_add_custom_btn.text = "+ Ajouter"
	_expr_add_custom_btn.pressed.connect(_on_expr_add_custom)
	add_hbox.add_child(_expr_add_custom_btn)

	# Load saved custom expressions
	_load_custom_expressions()

	vbox.add_child(HSeparator.new())

	# Status + Generation
	_expr_status_label = Label.new()
	_expr_status_label.text = ""
	vbox.add_child(_expr_status_label)

	_expr_progress_bar = ProgressBar.new()
	_expr_progress_bar.visible = false
	_expr_progress_bar.custom_minimum_size.y = 8
	vbox.add_child(_expr_progress_bar)

	var gen_hbox = HBoxContainer.new()
	gen_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(gen_hbox)

	_expr_generate_btn = Button.new()
	_expr_generate_btn.text = "Générer les expressions"
	_expr_generate_btn.disabled = true
	_expr_generate_btn.pressed.connect(_on_expr_generate_pressed)
	gen_hbox.add_child(_expr_generate_btn)

	_expr_cancel_btn = Button.new()
	_expr_cancel_btn.text = "Annuler"
	_expr_cancel_btn.visible = false
	_expr_cancel_btn.pressed.connect(_on_expr_cancel_pressed)
	gen_hbox.add_child(_expr_cancel_btn)

	vbox.add_child(HSeparator.new())

	# Results header with preview button
	var results_hbox = HBoxContainer.new()
	results_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(results_hbox)

	var results_label = Label.new()
	results_label.text = "Résultats :"
	results_label.add_theme_font_size_override("font_size", 16)
	results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_hbox.add_child(results_label)

	_expr_preview_btn = Button.new()
	_expr_preview_btn.text = "Prévisualiser"
	_expr_preview_btn.disabled = true
	_expr_preview_btn.pressed.connect(_on_expr_preview_pressed)
	results_hbox.add_child(_expr_preview_btn)

	_expr_results_grid = GridContainer.new()
	_expr_results_grid.columns = 4
	_expr_results_grid.add_theme_constant_override("h_separation", 8)
	_expr_results_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(_expr_results_grid)

	# Context menu for right-click
	_expr_context_menu = PopupMenu.new()
	_expr_context_menu.add_item("Régénérer", 0)
	_expr_context_menu.add_item("Supprimer", 1)
	_expr_context_menu.id_pressed.connect(_on_expr_context_menu_pressed)
	add_child(_expr_context_menu)

	vbox.add_child(HSeparator.new())

	# Save all button
	_expr_save_all_btn = Button.new()
	_expr_save_all_btn.text = "Tout sauvegarder"
	_expr_save_all_btn.disabled = true
	_expr_save_all_btn.pressed.connect(_on_expr_save_all_pressed)
	vbox.add_child(_expr_save_all_btn)


# ========================================================
# Config
# ========================================================

func _load_config() -> void:
	var config = ComfyUIConfig.new()
	config.load_from()
	_url_input.text = config.get_url()
	_token_input.text = config.get_token()
	_negative_prompt_input.text = config.get_negative_prompt()
	_update_all_generate_buttons()
	_update_cfg_hints()


func _save_config() -> void:
	var config = ComfyUIConfig.new()
	config.set_url(_url_input.text.strip_edges())
	config.set_token(_token_input.text.strip_edges())
	config.set_negative_prompt(_negative_prompt_input.text.strip_edges())
	# Preserve custom expressions
	var existing = ComfyUIConfig.new()
	existing.load_from()
	config.set_custom_expressions(existing.get_custom_expressions())
	config.save_to()


func _update_all_generate_buttons() -> void:
	_update_decl_generate_button()
	_update_expr_generate_button()


func _update_cfg_hints() -> void:
	var has_negative = _negative_prompt_input.text.strip_edges() != ""
	if _decl_cfg_hint:
		_decl_cfg_hint.visible = has_negative and _decl_cfg_slider.value < 3.0
	if _expr_cfg_hint:
		_expr_cfg_hint.visible = has_negative and _expr_cfg_slider.value < 3.0


# ========================================================
# Décliner Logic
# ========================================================

func _update_decl_generate_button() -> void:
	if _decl_generate_btn == null:
		return
	var has_url = _url_input.text.strip_edges() != ""
	var has_prompt = _decl_prompt_input.text.strip_edges() != ""
	var has_source = _decl_source_image_path != ""
	_decl_generate_btn.disabled = not (has_url and has_prompt and has_source)


func _on_decl_choose_source() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String):
		_decl_source_image_path = path
		_decl_source_path_label.text = path.get_file()
		_load_preview(_decl_source_preview, path)
		_update_decl_generate_button()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_decl_choose_from_gallery() -> void:
	_open_gallery_source_picker(func(path: String):
		_decl_source_image_path = path
		_decl_source_path_label.text = path.get_file()
		_load_preview(_decl_source_preview, path)
		_update_decl_generate_button()
	)


func _on_decl_generate_pressed() -> void:
	_save_config()

	if _decl_client != null:
		_decl_client.cancel()
		_decl_client.queue_free()

	_decl_client = Node.new()
	_decl_client.set_script(ComfyUIClient)
	add_child(_decl_client)

	_decl_client.generation_completed.connect(_on_decl_generation_completed)
	_decl_client.generation_failed.connect(_on_decl_generation_failed)
	_decl_client.generation_progress.connect(_on_decl_generation_progress)

	_decl_generate_btn.disabled = true
	_decl_save_btn.disabled = true
	_decl_regenerate_btn.disabled = true
	_decl_generated_image = null
	_decl_result_preview.texture = null
	_decl_name_input.text = ""
	_decl_name_input.editable = false
	_decl_set_inputs_enabled(false)
	_decl_show_status("Lancement...")

	var config = ComfyUIConfig.new()
	config.set_url(_url_input.text.strip_edges())
	config.set_token(_token_input.text.strip_edges())

	var cfg_value = _decl_cfg_slider.value
	var steps_value = int(_decl_steps_slider.value)
	var workflow_type = _decl_workflow_option.get_selected_id()
	var neg_prompt = _negative_prompt_input.text.strip_edges()
	_decl_client.generate(config, _decl_source_image_path, _decl_prompt_input.text, true, cfg_value, steps_value, workflow_type, 0.5, neg_prompt)


func _on_decl_generation_completed(image: Image) -> void:
	_decl_generated_image = image
	var tex = ImageTexture.create_from_image(image)
	_decl_result_preview.texture = tex
	_decl_show_success("Génération terminée !")
	var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
	_decl_name_input.text = "ai_" + timestamp
	_decl_name_input.editable = true
	_decl_save_btn.disabled = false
	_decl_regenerate_btn.disabled = false
	_decl_set_inputs_enabled(true)
	_update_decl_generate_button()


func _on_decl_generation_failed(error: String) -> void:
	_decl_show_error("Erreur : " + error)
	_decl_regenerate_btn.disabled = false
	_decl_set_inputs_enabled(true)
	_update_decl_generate_button()


func _on_decl_generation_progress(status: String) -> void:
	_decl_show_status(status)


func _on_decl_save_pressed() -> void:
	if _decl_generated_image == null:
		return

	var img_name = _decl_name_input.text.strip_edges()
	if img_name == "":
		var timestamp = str(Time.get_unix_time_from_system()).replace(".", "_")
		img_name = "ai_" + timestamp

	var format_error = ImageRenameService.validate_name_format(img_name)
	if format_error != "":
		_decl_show_error(format_error)
		return

	var dir_path = _story_base_path + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path = dir_path + "/" + img_name + ".png"

	if FileAccess.file_exists(file_path):
		var dialog = ConfirmationDialog.new()
		dialog.dialog_text = "L'image « %s » existe déjà.\nVoulez-vous l'écraser ?" % file_path.get_file()
		dialog.ok_button_text = "Écraser"
		add_child(dialog)
		dialog.confirmed.connect(func():
			_decl_do_save(file_path, dir_path)
			dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return

	_decl_do_save(file_path, dir_path)


func _decl_do_save(file_path: String, dir_path: String) -> void:
	_decl_generated_image.save_png(file_path)
	GalleryCacheService.clear_dir(dir_path)
	_decl_show_success("Image sauvegardée : " + file_path.get_file())

	# Reset for next generation
	_decl_generated_image = null
	_decl_result_preview.texture = null
	_decl_name_input.text = ""
	_decl_name_input.editable = false
	_decl_save_btn.disabled = true


func _decl_show_status(message: String) -> void:
	_decl_status_label.text = message
	_decl_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_decl_progress_bar.visible = true


func _decl_show_success(message: String) -> void:
	_decl_status_label.text = message
	_decl_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_decl_progress_bar.visible = false


func _decl_show_error(message: String) -> void:
	_decl_status_label.text = message
	_decl_status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	_decl_progress_bar.visible = false


func _decl_set_inputs_enabled(enabled: bool) -> void:
	_url_input.editable = enabled
	_token_input.editable = enabled
	_negative_prompt_input.editable = enabled
	_decl_prompt_input.editable = enabled
	_decl_choose_source_btn.disabled = not enabled
	_decl_choose_gallery_btn.disabled = not enabled
	_decl_workflow_option.disabled = not enabled


func _cancel_decl_generation() -> void:
	if _decl_client != null:
		_decl_client.cancel()
		_decl_client.queue_free()
		_decl_client = null


# ========================================================
# Expressions Logic
# ========================================================

func _update_expr_generate_button() -> void:
	if _expr_generate_btn == null:
		return
	if _expr_generating:
		return
	var has_url = _url_input.text.strip_edges() != ""
	var has_source = _expr_source_image_path != ""
	var has_prefix = _expr_prefix_input.text.strip_edges() != ""
	var has_expr = _get_selected_expressions().size() > 0
	_expr_generate_btn.disabled = not (has_url and has_source and has_prefix and has_expr)


func _update_group_select_all_btn(btn: Button, checkboxes: Array) -> void:
	var all_checked = checkboxes.all(func(c): return c.button_pressed)
	btn.text = "Décocher tout" if all_checked else "Cocher tout"


func _update_expr_preview_button() -> void:
	if _expr_preview_btn == null:
		return
	var has_completed = _expr_queue != null and _expr_queue.get_completed_count() > 0
	_expr_preview_btn.disabled = not has_completed


func _get_selected_expressions() -> Array:
	var expressions: Array = []
	for cb in _expr_elementary_checkboxes + _expr_advanced_checkboxes:
		if cb.button_pressed:
			expressions.append(cb.text)
	for child in _expr_custom_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var cb = child.get_child(0)
			if cb is CheckBox and cb.button_pressed:
				expressions.append(cb.text)
	return expressions


func _on_expr_choose_source() -> void:
	var dialog = ImageFileDialog.new()
	dialog.file_selected.connect(func(path: String):
		_expr_source_image_path = path
		_expr_source_path_label.text = path.get_file()
		_load_preview(_expr_source_preview, path)
		_update_expr_generate_button()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(900, 600))


func _on_expr_choose_from_gallery() -> void:
	_open_gallery_source_picker(func(path: String):
		_expr_source_image_path = path
		_expr_source_path_label.text = path.get_file()
		_load_preview(_expr_source_preview, path)
		_update_expr_generate_button()
	)


# --- Custom expressions ---

func _load_custom_expressions() -> void:
	var config = ComfyUIConfig.new()
	config.load_from()
	for expr in config.get_custom_expressions():
		var trimmed = expr.strip_edges()
		if trimmed == "":
			continue
		if _expression_already_exists(trimmed):
			continue
		_add_custom_expression_ui(trimmed)


func _on_expr_add_custom() -> void:
	var expr_text = _expr_custom_input.text.strip_edges()
	if expr_text == "":
		return
	if _expression_already_exists(expr_text):
		_expr_custom_input.text = ""
		return
	_add_custom_expression_ui(expr_text)
	_expr_custom_input.text = ""
	_save_custom_expressions()
	_update_expr_generate_button()


func _expression_already_exists(expr_text: String) -> bool:
	for cb in _expr_elementary_checkboxes + _expr_advanced_checkboxes:
		if cb.text.to_lower() == expr_text.to_lower():
			return true
	for child in _expr_custom_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var cb = child.get_child(0)
			if cb is CheckBox and cb.text.to_lower() == expr_text.to_lower():
				return true
	return false


func _add_custom_expression_ui(expr_text: String) -> void:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	var cb = CheckBox.new()
	cb.text = expr_text
	cb.button_pressed = false
	cb.toggled.connect(func(_p): _update_expr_generate_button())
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(cb)

	var del_btn = Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size = Vector2(30, 0)
	del_btn.pressed.connect(func():
		hbox.queue_free()
		_save_custom_expressions()
		_update_expr_generate_button()
	)
	hbox.add_child(del_btn)

	_expr_custom_container.add_child(hbox)


func _save_custom_expressions() -> void:
	var config = ComfyUIConfig.new()
	config.load_from()
	var customs: PackedStringArray = PackedStringArray([])
	for child in _expr_custom_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var cb = child.get_child(0)
			if cb is CheckBox:
				customs.append(cb.text)
	config.set_custom_expressions(customs)
	config.save_to()


# --- Batch generation ---

func _on_expr_generate_pressed() -> void:
	_save_config()

	var expressions = _get_selected_expressions()
	var prefix = _expr_prefix_input.text.strip_edges()

	_expr_queue = ExpressionQueueService.new()
	_expr_queue.build_queue(expressions, prefix)

	_expr_generating = true
	_expr_generate_btn.disabled = true
	_expr_cancel_btn.visible = true
	_expr_save_all_btn.disabled = true
	_expr_set_inputs_enabled(false)

	# Build grid placeholders
	_build_results_grid()

	# Start processing
	_expr_update_status()
	_process_next_expression()


func _process_next_expression() -> void:
	if _expr_queue == null or _expr_queue.is_cancelled():
		_on_expr_batch_finished()
		return

	var idx = _expr_queue.get_next_pending_index()
	if idx == -1:
		_on_expr_batch_finished()
		return

	_expr_queue.mark_generating(idx)
	var item = _expr_queue.get_items()[idx]
	_update_grid_cell_status(idx)
	_expr_update_status()

	if _expr_client != null:
		_expr_client.cancel()
		_expr_client.queue_free()

	_expr_client = Node.new()
	_expr_client.set_script(ComfyUIClient)
	add_child(_expr_client)

	_expr_client.generation_completed.connect(_on_expr_item_completed)
	_expr_client.generation_failed.connect(_on_expr_item_failed)
	_expr_client.generation_progress.connect(_on_expr_item_progress)

	var config = ComfyUIConfig.new()
	config.set_url(_url_input.text.strip_edges())
	config.set_token(_token_input.text.strip_edges())

	var cfg_value = _expr_cfg_slider.value
	var steps_value = int(_expr_steps_slider.value)
	var denoise_value = _expr_denoise_slider.value
	var face_box_value = int(_expr_face_box_slider.value)
	var neg_prompt = _negative_prompt_input.text.strip_edges()
	_expr_client.generate(config, _expr_source_image_path, item["prompt"], true, cfg_value, steps_value, ComfyUIClient.WorkflowType.EXPRESSION, denoise_value, neg_prompt, face_box_value)


func _on_expr_item_completed(image: Image) -> void:
	var idx = _expr_queue.get_current_index()
	_expr_queue.mark_completed(idx, image)
	_update_grid_cell_image(idx, image)
	_update_grid_cell_status(idx)
	_expr_update_status()
	_update_expr_preview_button()
	# Update the preview popup if it's showing this item
	if _image_preview and _image_preview.visible and _image_preview.get_current_queue_index() == idx:
		var tex = ImageTexture.create_from_image(image)
		_image_preview.update_current_image(tex)
	_process_next_expression()


func _on_expr_item_failed(error: String) -> void:
	var idx = _expr_queue.get_current_index()
	_expr_queue.mark_failed(idx, error)
	_update_grid_cell_status(idx)
	_expr_update_status()
	# If preview is showing this item, show error and re-enable buttons
	if _image_preview and _image_preview.visible and _image_preview.get_current_queue_index() == idx:
		_image_preview._filename_label.text = _expr_queue.get_items()[idx]["filename"] + " — Échoué"
		_image_preview._regenerating = false
		_image_preview._regenerate_btn.disabled = false
		_image_preview._delete_btn.disabled = false
	_process_next_expression()


func _on_expr_item_progress(status: String) -> void:
	var idx = _expr_queue.get_current_index()
	if idx >= 0:
		var item = _expr_queue.get_items()[idx]
		_expr_status_label.text = "%s — %s" % [item["filename"], status]


func _on_expr_cancel_pressed() -> void:
	if _expr_queue:
		_expr_queue.cancel()
	_cancel_expr_generation()
	_on_expr_batch_finished()


func _on_expr_batch_finished() -> void:
	_expr_generating = false
	_expr_cancel_btn.visible = false
	_expr_progress_bar.visible = false
	_expr_set_inputs_enabled(true)
	_update_expr_generate_button()
	_update_expr_preview_button()
	if _expr_queue and _expr_queue.get_completed_count() > 0:
		_expr_save_all_btn.disabled = false
		_expr_status_label.text = "%d/%d terminés" % [_expr_queue.get_completed_count(), _expr_queue.get_total()]
		_expr_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		_expr_status_label.text = "Génération terminée (aucun résultat)"
		_expr_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))


func _expr_update_status() -> void:
	if _expr_queue == null:
		return
	var done = _expr_queue.get_done_count()
	var total = _expr_queue.get_total()
	_expr_status_label.text = "%d/%d générés" % [done, total]
	_expr_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_expr_progress_bar.visible = true
	_expr_progress_bar.indeterminate = false
	_expr_progress_bar.min_value = 0
	_expr_progress_bar.max_value = total
	_expr_progress_bar.value = done


func _expr_set_inputs_enabled(enabled: bool) -> void:
	_url_input.editable = enabled
	_token_input.editable = enabled
	_negative_prompt_input.editable = enabled
	_expr_choose_source_btn.disabled = not enabled
	if _story_base_path == "":
		_expr_choose_gallery_btn.disabled = true
	else:
		_expr_choose_gallery_btn.disabled = not enabled
	_expr_prefix_input.editable = enabled
	_expr_denoise_slider.editable = enabled
	_expr_face_box_slider.editable = enabled
	_expr_custom_input.editable = enabled
	_expr_add_custom_btn.disabled = not enabled
	for cb in _expr_elementary_checkboxes + _expr_advanced_checkboxes:
		cb.disabled = not enabled


func _cancel_expr_generation() -> void:
	if _expr_client != null:
		_expr_client.cancel()
		_expr_client.queue_free()
		_expr_client = null


# --- Results grid ---

func _build_results_grid() -> void:
	for child in _expr_results_grid.get_children():
		_expr_results_grid.remove_child(child)
		child.queue_free()

	if _expr_queue == null:
		return

	for i in range(_expr_queue.get_total()):
		var item = _expr_queue.get_items()[i]
		var cell = _create_grid_cell(i, item["filename"])
		_expr_results_grid.add_child(cell)


func _create_grid_cell(index: int, label_text: String) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(150, 180)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox_cell = VBoxContainer.new()
	vbox_cell.name = "VBox"
	vbox_cell.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox_cell.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox_cell.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(vbox_cell)

	var tex_rect = TextureRect.new()
	tex_rect.name = "Preview"
	tex_rect.custom_minimum_size = Vector2(128, 128)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_cell.add_child(tex_rect)

	var lbl = Label.new()
	lbl.name = "Label"
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_cell.add_child(lbl)

	var status_lbl = Label.new()
	status_lbl.name = "Status"
	status_lbl.text = "En attente"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.add_theme_font_size_override("font_size", 9)
	status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox_cell.add_child(status_lbl)

	# Double-click to zoom
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				var tex = tex_rect.texture
				if tex:
					_show_image_preview(tex, label_text)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_expr_context_index = index
				_expr_context_menu.position = Vector2i(
					int(get_position().x + event.global_position.x),
					int(get_position().y + event.global_position.y)
				)
				_expr_context_menu.popup()
	)

	return panel


func _update_grid_cell_status(index: int) -> void:
	if index < 0 or index >= _expr_results_grid.get_child_count():
		return
	var panel = _expr_results_grid.get_child(index)
	var status_lbl = panel.get_node("VBox/Status") if panel.has_node("VBox/Status") else null
	if status_lbl == null:
		return
	var item = _expr_queue.get_items()[index]
	match item["status"]:
		ExpressionQueueService.ItemStatus.PENDING:
			status_lbl.text = "En attente"
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		ExpressionQueueService.ItemStatus.GENERATING:
			status_lbl.text = "En cours..."
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		ExpressionQueueService.ItemStatus.COMPLETED:
			status_lbl.text = "Terminé"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		ExpressionQueueService.ItemStatus.FAILED:
			var error_msg = item.get("error", "")
			if error_msg != "":
				status_lbl.text = error_msg
			else:
				status_lbl.text = "Échoué"
			status_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


func _update_grid_cell_image(index: int, image: Image) -> void:
	if index < 0 or index >= _expr_results_grid.get_child_count():
		return
	var panel = _expr_results_grid.get_child(index)
	var tex_rect = panel.get_node("VBox/Preview") if panel.has_node("VBox/Preview") else null
	if tex_rect == null:
		return
	tex_rect.texture = ImageTexture.create_from_image(image)


# --- Context menu ---

func _on_expr_context_menu_pressed(id: int) -> void:
	if _expr_queue == null or _expr_context_index < 0:
		return
	match id:
		0: _on_expr_regenerate_item(_expr_context_index)
		1: _on_expr_delete_item(_expr_context_index)


func _on_expr_regenerate_item(index: int) -> void:
	if index < 0 or index >= _expr_queue.get_total():
		return
	_expr_queue.reset_item(index)
	_update_grid_cell_status(index)
	# Clear the preview
	var panel = _expr_results_grid.get_child(index)
	if panel.has_node("VBox/Preview"):
		panel.get_node("VBox/Preview").texture = null
	if not _expr_generating:
		_expr_generating = true
		_expr_cancel_btn.visible = true
		_expr_save_all_btn.disabled = true
		_expr_set_inputs_enabled(false)
		_process_next_expression()


func _on_expr_delete_item(index: int) -> void:
	if index < 0 or index >= _expr_queue.get_total():
		return
	_expr_queue.remove_item(index)
	# Rebuild grid
	_build_results_grid()
	# Update images for completed items
	for i in range(_expr_queue.get_total()):
		var item = _expr_queue.get_items()[i]
		if item["status"] == ExpressionQueueService.ItemStatus.COMPLETED and item["image"] != null:
			_update_grid_cell_image(i, item["image"])
		_update_grid_cell_status(i)
	if _expr_queue.get_completed_count() > 0:
		_expr_save_all_btn.disabled = false
	else:
		_expr_save_all_btn.disabled = true
	_update_expr_preview_button()


# --- Save all ---

func _on_expr_save_all_pressed() -> void:
	if _expr_queue == null:
		return

	var completed = _expr_queue.get_completed_items()
	if completed.is_empty():
		return

	var dir_path = _story_base_path + "/assets/foregrounds"
	DirAccess.make_dir_recursive_absolute(dir_path)

	var existing: Array[String] = []
	for item in completed:
		var file_path = dir_path + "/" + item["filename"] + ".png"
		if FileAccess.file_exists(file_path):
			existing.append(item["filename"] + ".png")

	if not existing.is_empty():
		var dialog = ConfirmationDialog.new()
		var names = "\n".join(existing)
		dialog.dialog_text = "Ces images existent déjà :\n%s\nVoulez-vous les écraser ?" % names
		dialog.ok_button_text = "Écraser"
		dialog.wrap_controls = true
		dialog.max_size = Vector2i(500, 400)
		add_child(dialog)
		dialog.confirmed.connect(func():
			_expr_do_save_all(completed, dir_path, true)
			dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return

	_expr_do_save_all(completed, dir_path, false)


func _expr_do_save_all(completed: Array, dir_path: String, overwrite: bool) -> void:
	var saved_count := 0
	for item in completed:
		var filename = item["filename"] + ".png"
		var file_path = dir_path + "/" + filename
		if not overwrite and FileAccess.file_exists(file_path):
			file_path = _resolve_unique_path(dir_path, filename)
		item["image"].save_png(file_path)
		saved_count += 1

	GalleryCacheService.clear_dir(dir_path)

	_expr_status_label.text = "%d images sauvegardées dans assets/foregrounds/" % saved_count
	_expr_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_expr_save_all_btn.disabled = true


# ========================================================
# Shared helpers
# ========================================================

func _load_preview(tex_rect: TextureRect, path: String) -> void:
	if path == "":
		tex_rect.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
	else:
		tex_rect.texture = null


func _show_image_preview(texture: Texture2D, filename: String) -> void:
	if _image_preview:
		_image_preview.show_preview(texture, filename)


func _on_expr_preview_pressed() -> void:
	if _expr_queue == null or _image_preview == null:
		return
	var items = _build_preview_collection()
	if items.is_empty():
		return
	_image_preview.show_collection(items, 0)


func _build_preview_collection() -> Array:
	var items: Array = []
	if _expr_queue == null:
		return items
	var queue_items = _expr_queue.get_items()
	for i in range(queue_items.size()):
		var item = queue_items[i]
		if item["status"] == ExpressionQueueService.ItemStatus.COMPLETED and item["image"] != null:
			var tex = ImageTexture.create_from_image(item["image"])
			items.append({"texture": tex, "filename": item["filename"], "index": i})
	return items


func _on_preview_regenerate(index: int) -> void:
	_on_expr_regenerate_item(index)


func _on_preview_delete(index: int) -> void:
	_on_expr_delete_item(index)
	_update_expr_preview_button()


func _open_gallery_source_picker(on_selected: Callable) -> void:
	if _story_base_path == "":
		return

	var gallery_window = Window.new()
	gallery_window.title = "Choisir une image source"
	gallery_window.size = Vector2i(600, 450)
	gallery_window.exclusive = true

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	gallery_window.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Category filter
	var filter_hbox = HBoxContainer.new()
	filter_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(filter_hbox)

	var filter_label = Label.new()
	filter_label.text = "Filtrer :"
	filter_hbox.add_child(filter_label)

	var source_checkboxes: Array = []
	if _category_service:
		for cat in _category_service.get_categories():
			var cb = CheckBox.new()
			cb.text = cat
			cb.button_pressed = true
			filter_hbox.add_child(cb)
			source_checkboxes.append(cb)

	var spacer_filt = Control.new()
	spacer_filt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_hbox.add_child(spacer_filt)

	var refresh_btn = Button.new()
	refresh_btn.text = "Rafraîchir"
	var rebuild_grid_ref = {"rebuild": func(): pass}
	refresh_btn.pressed.connect(func():
		GalleryCacheService.clear_dir(_story_base_path + "/assets/backgrounds")
		GalleryCacheService.clear_dir(_story_base_path + "/assets/foregrounds")
		rebuild_grid_ref.rebuild.call()
	)
	filter_hbox.add_child(refresh_btn)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	var rebuild_grid = func():
		for child in grid.get_children():
			child.queue_free()

		var images = _list_gallery_images()
		var selected_cats: Array = []
		for cb in source_checkboxes:
			if cb.button_pressed:
				selected_cats.append(cb.text)
		if not selected_cats.is_empty() and _category_service:
			images = _category_service.filter_paths_by_categories(images, selected_cats)

		for path in images:
			var container = Panel.new()
			container.custom_minimum_size = Vector2(120, 140)
			container.mouse_filter = Control.MOUSE_FILTER_STOP

			var cv = VBoxContainer.new()
			cv.set_anchors_preset(Control.PRESET_FULL_RECT)
			cv.alignment = BoxContainer.ALIGNMENT_CENTER
			container.add_child(cv)

			var tex_rect = TextureRect.new()
			tex_rect.custom_minimum_size = Vector2(100, 100)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			tex_rect.texture = GalleryCacheService.get_texture(path)
			cv.add_child(tex_rect)

			var lbl = Label.new()
			lbl.text = path.get_file()
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 10)
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.add_child(lbl)

			container.gui_input.connect(func(event: InputEvent):
				if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
					on_selected.call(path)
					gallery_window.queue_free()
			)
			grid.add_child(container)

	for cb in source_checkboxes:
		cb.toggled.connect(func(_p): rebuild_grid.call())

	rebuild_grid_ref.rebuild = rebuild_grid
	rebuild_grid.call()

	var cancel_btn = Button.new()
	cancel_btn.text = "Annuler"
	cancel_btn.pressed.connect(func(): gallery_window.queue_free())
	vbox.add_child(cancel_btn)

	gallery_window.close_requested.connect(func(): gallery_window.queue_free())
	add_child(gallery_window)
	gallery_window.popup_centered()


func _list_gallery_images() -> Array:
	var result = []
	result.append_array(GalleryCacheService.get_file_list(_story_base_path + "/assets/foregrounds", ["png", "jpg", "jpeg", "webp"]))
	result.append_array(GalleryCacheService.get_file_list(_story_base_path + "/assets/backgrounds", ["png", "jpg", "jpeg", "webp"]))
	result.sort()
	return result


static func _resolve_unique_path(dir_path: String, filename: String) -> String:
	var name_part = filename.get_basename()
	var ext = "." + filename.get_extension()
	var target = dir_path + "/" + filename
	if not FileAccess.file_exists(target):
		return target
	var i = 1
	while FileAccess.file_exists(dir_path + "/" + name_part + "_" + str(i) + ext):
		i += 1
	return dir_path + "/" + name_part + "_" + str(i) + ext
