extends RefCounted

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const ExpressionQueueService = preload("res://src/services/expression_queue_service.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")

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
var _prefix_input: LineEdit
var _cfg_slider: HSlider
var _cfg_value_label: Label
var _cfg_hint: Label
var _steps_slider: HSlider
var _steps_value_label: Label
var _denoise_slider: HSlider
var _denoise_value_label: Label
var _megapixels_slider: HSlider
var _megapixels_value_label: Label
var _face_box_slider: HSlider
var _face_box_value_label: Label
var _elementary_checkboxes: Array = []
var _advanced_checkboxes: Array = []
var _elementary_select_all_btn: Button
var _advanced_select_all_btn: Button
var _custom_container: VBoxContainer
var _custom_input: LineEdit
var _add_custom_btn: Button
var _generate_btn: Button
var _cancel_btn: Button
var _status_label: Label
var _progress_bar: ProgressBar
var _results_grid: GridContainer
var _diffusion_controls: VBoxContainer
var _save_all_btn: Button
var _preview_btn: Button
var _context_menu: PopupMenu

# State
var _source_image_path: String = ""
var _client: Node = null
var _queue: RefCounted = null
var _generating: bool = false
var _context_index: int = -1

var _strategy_option: OptionButton = null
var _image_preview: Control = null


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


func set_image_preview(image_preview: Control) -> void:
	_image_preview = image_preview


func build_tab(tab_container: TabContainer) -> void:
	var scroll = ScrollContainer.new()
	scroll.name = "Expressions"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Stratégie de génération
	var strategy_label = Label.new()
	strategy_label.text = "Stratégie :"
	vbox.add_child(strategy_label)

	_strategy_option = OptionButton.new()
	_strategy_option.add_item("Pleine image (actuelle)", 0)
	_strategy_option.add_item("FaceDetailer — crop visage (Impact Pack)", 1)
	_strategy_option.add_item("LivePortrait — morphing sans diffusion", 2)
	_strategy_option.selected = 0
	_strategy_option.item_selected.connect(_on_strategy_changed)
	vbox.add_child(_strategy_option)

	vbox.add_child(HSeparator.new())

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

	# Prefix
	var prefix_label = Label.new()
	prefix_label.text = "Préfixe des images :"
	vbox.add_child(prefix_label)

	_prefix_input = LineEdit.new()
	_prefix_input.placeholder_text = "personnage_nom"
	_prefix_input.text_changed.connect(func(_t): _update_generate_button())
	vbox.add_child(_prefix_input)

	# Conteneur pour les contrôles de diffusion (masqué en mode LivePortrait)
	_diffusion_controls = VBoxContainer.new()
	_diffusion_controls.add_theme_constant_override("separation", 8)
	vbox.add_child(_diffusion_controls)

	# CFG slider
	var cfg_hbox = HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	_diffusion_controls.add_child(cfg_hbox)

	var cfg_label = Label.new()
	cfg_label.text = "CFG :"
	cfg_hbox.add_child(cfg_label)

	_cfg_slider = HSlider.new()
	_cfg_slider.min_value = 1.0
	_cfg_slider.max_value = 30.0
	_cfg_slider.step = 0.5
	_cfg_slider.value = 1.0
	_cfg_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_cfg_slider.value_changed.connect(func(val: float):
		_cfg_value_label.text = str(val)
		var has_negative = _neg_input.text.strip_edges() != ""
		update_cfg_hint(has_negative)
	)
	cfg_hbox.add_child(_cfg_slider)

	_cfg_value_label = Label.new()
	_cfg_value_label.text = "1.0"
	_cfg_value_label.custom_minimum_size.x = 32
	cfg_hbox.add_child(_cfg_value_label)

	_cfg_hint = Label.new()
	_cfg_hint.text = "CFG >= 3 requis pour le negative prompt"
	_cfg_hint.add_theme_font_size_override("font_size", 11)
	_cfg_hint.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	_cfg_hint.visible = false
	_diffusion_controls.add_child(_cfg_hint)

	# Steps slider
	var steps_hbox = HBoxContainer.new()
	steps_hbox.add_theme_constant_override("separation", 8)
	_diffusion_controls.add_child(steps_hbox)

	var steps_label = Label.new()
	steps_label.text = "Steps :"
	steps_hbox.add_child(steps_label)

	_steps_slider = HSlider.new()
	_steps_slider.min_value = 1
	_steps_slider.max_value = 50
	_steps_slider.step = 1
	_steps_slider.value = 4
	_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_slider.value_changed.connect(func(val: float): _steps_value_label.text = str(int(val)))
	steps_hbox.add_child(_steps_slider)

	_steps_value_label = Label.new()
	_steps_value_label.text = "4"
	_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_steps_value_label)

	# Denoise slider
	var denoise_hbox = HBoxContainer.new()
	denoise_hbox.add_theme_constant_override("separation", 8)
	_diffusion_controls.add_child(denoise_hbox)

	var denoise_label = Label.new()
	denoise_label.text = "Denoise :"
	denoise_hbox.add_child(denoise_label)

	_denoise_slider = HSlider.new()
	_denoise_slider.min_value = 0.1
	_denoise_slider.max_value = 1.0
	_denoise_slider.step = 0.05
	_denoise_slider.value = 0.55
	_denoise_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_denoise_slider.value_changed.connect(func(val: float): _denoise_value_label.text = str(snapped(val, 0.05)))
	denoise_hbox.add_child(_denoise_slider)

	_denoise_value_label = Label.new()
	_denoise_value_label.text = "0.55"
	_denoise_value_label.custom_minimum_size.x = 32
	denoise_hbox.add_child(_denoise_value_label)

	# Megapixels slider
	var mp_hbox = HBoxContainer.new()
	mp_hbox.add_theme_constant_override("separation", 8)
	_diffusion_controls.add_child(mp_hbox)

	var mp_label = Label.new()
	mp_label.text = "Mégapixels :"
	mp_hbox.add_child(mp_label)

	_megapixels_slider = HSlider.new()
	_megapixels_slider.min_value = 0.5
	_megapixels_slider.max_value = 4.0
	_megapixels_slider.step = 0.5
	_megapixels_slider.value = 2.0
	_megapixels_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_megapixels_slider.value_changed.connect(func(val: float): _megapixels_value_label.text = str(snapped(val, 0.5)))
	mp_hbox.add_child(_megapixels_slider)

	_megapixels_value_label = Label.new()
	_megapixels_value_label.text = "2.0"
	_megapixels_value_label.custom_minimum_size.x = 32
	mp_hbox.add_child(_megapixels_value_label)

	# Face box size slider
	var face_box_hbox = HBoxContainer.new()
	face_box_hbox.add_theme_constant_override("separation", 8)
	_diffusion_controls.add_child(face_box_hbox)

	var face_box_label = Label.new()
	face_box_label.text = "Zone visage :"
	face_box_hbox.add_child(face_box_label)

	_face_box_slider = HSlider.new()
	_face_box_slider.min_value = 10
	_face_box_slider.max_value = 200
	_face_box_slider.step = 5
	_face_box_slider.value = 10
	_face_box_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_face_box_slider.value_changed.connect(func(val: float): _face_box_value_label.text = str(int(val)))
	face_box_hbox.add_child(_face_box_slider)

	_face_box_value_label = Label.new()
	_face_box_value_label.text = "10"
	_face_box_value_label.custom_minimum_size.x = 32
	face_box_hbox.add_child(_face_box_value_label)

	vbox.add_child(HSeparator.new())

	# Expressions élémentaires
	var elem_header = HBoxContainer.new()
	vbox.add_child(elem_header)

	var elem_label = Label.new()
	elem_label.text = "Expressions élémentaires"
	elem_label.add_theme_font_size_override("font_size", 16)
	elem_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elem_header.add_child(elem_label)

	_elementary_select_all_btn = Button.new()
	_elementary_select_all_btn.text = "Cocher tout"
	_elementary_select_all_btn.pressed.connect(func():
		var all_checked = _elementary_checkboxes.all(func(c): return c.button_pressed)
		for c in _elementary_checkboxes:
			c.button_pressed = not all_checked
		_update_group_select_all_btn(_elementary_select_all_btn, _elementary_checkboxes)
		_update_generate_button()
	)
	elem_header.add_child(_elementary_select_all_btn)

	var elem_flow = HFlowContainer.new()
	elem_flow.add_theme_constant_override("h_separation", 8)
	elem_flow.add_theme_constant_override("v_separation", 4)
	vbox.add_child(elem_flow)

	for i in range(ELEMENTARY_EXPRESSIONS.size()):
		var cb = CheckBox.new()
		cb.text = ELEMENTARY_EXPRESSIONS[i]
		cb.button_pressed = (i == 0)
		cb.toggled.connect(func(_p):
			_update_group_select_all_btn(_elementary_select_all_btn, _elementary_checkboxes)
			_update_generate_button()
		)
		elem_flow.add_child(cb)
		_elementary_checkboxes.append(cb)

	vbox.add_child(HSeparator.new())

	# Expressions avancées
	var adv_header = HBoxContainer.new()
	vbox.add_child(adv_header)

	var adv_label = Label.new()
	adv_label.text = "Expressions avancées"
	adv_label.add_theme_font_size_override("font_size", 16)
	adv_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	adv_header.add_child(adv_label)

	_advanced_select_all_btn = Button.new()
	_advanced_select_all_btn.text = "Cocher tout"
	_advanced_select_all_btn.pressed.connect(func():
		var all_checked = _advanced_checkboxes.all(func(c): return c.button_pressed)
		for c in _advanced_checkboxes:
			c.button_pressed = not all_checked
		_update_group_select_all_btn(_advanced_select_all_btn, _advanced_checkboxes)
		_update_generate_button()
	)
	adv_header.add_child(_advanced_select_all_btn)

	var adv_flow = HFlowContainer.new()
	adv_flow.add_theme_constant_override("h_separation", 8)
	adv_flow.add_theme_constant_override("v_separation", 4)
	vbox.add_child(adv_flow)

	for expr in ADVANCED_EXPRESSIONS:
		var cb = CheckBox.new()
		cb.text = expr
		cb.button_pressed = false
		cb.toggled.connect(func(_p):
			_update_group_select_all_btn(_advanced_select_all_btn, _advanced_checkboxes)
			_update_generate_button()
		)
		adv_flow.add_child(cb)
		_advanced_checkboxes.append(cb)

	# Custom expressions
	vbox.add_child(HSeparator.new())

	var custom_label = Label.new()
	custom_label.text = "Expressions personnalisées :"
	vbox.add_child(custom_label)

	_custom_container = VBoxContainer.new()
	_custom_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_custom_container)

	var add_hbox = HBoxContainer.new()
	add_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(add_hbox)

	_custom_input = LineEdit.new()
	_custom_input.placeholder_text = "Nouvelle expression..."
	_custom_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_hbox.add_child(_custom_input)

	_add_custom_btn = Button.new()
	_add_custom_btn.text = "+ Ajouter"
	_add_custom_btn.pressed.connect(_on_add_custom)
	add_hbox.add_child(_add_custom_btn)

	vbox.add_child(HSeparator.new())

	# Status + Generation
	_status_label = Label.new()
	_status_label.text = ""
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 8
	vbox.add_child(_progress_bar)

	var gen_hbox = HBoxContainer.new()
	gen_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(gen_hbox)

	_generate_btn = Button.new()
	_generate_btn.text = "Générer les expressions"
	_generate_btn.disabled = true
	_generate_btn.pressed.connect(_on_generate_pressed)
	gen_hbox.add_child(_generate_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Annuler"
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	gen_hbox.add_child(_cancel_btn)

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

	_preview_btn = Button.new()
	_preview_btn.text = "Prévisualiser"
	_preview_btn.disabled = true
	_preview_btn.pressed.connect(_on_preview_pressed)
	results_hbox.add_child(_preview_btn)

	_results_grid = GridContainer.new()
	_results_grid.columns = 4
	_results_grid.add_theme_constant_override("h_separation", 8)
	_results_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(_results_grid)

	# Context menu for right-click
	_context_menu = PopupMenu.new()
	_context_menu.add_item("Régénérer", 0)
	_context_menu.add_item("Supprimer", 1)
	_context_menu.id_pressed.connect(_on_context_menu_pressed)
	_parent_window.add_child(_context_menu)

	vbox.add_child(HSeparator.new())

	# Save all button
	_save_all_btn = Button.new()
	_save_all_btn.text = "Tout sauvegarder"
	_save_all_btn.disabled = true
	_save_all_btn.pressed.connect(_on_save_all_pressed)
	vbox.add_child(_save_all_btn)

	# Load saved custom expressions
	_load_custom_expressions()


func setup(story_base_path: String, has_story: bool) -> void:
	_story_base_path = story_base_path
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
# Private logic
# ========================================================

func _update_generate_button() -> void:
	if _generate_btn == null:
		return
	if _generating:
		return
	var has_url = _get_config_fn.call().get_url() != ""
	var has_source = _source_image_path != ""
	var has_prefix = _prefix_input.text.strip_edges() != ""
	var has_expr = _get_selected_expressions().size() > 0
	_generate_btn.disabled = not (has_url and has_source and has_prefix and has_expr)


func _update_group_select_all_btn(btn: Button, checkboxes: Array) -> void:
	var all_checked = checkboxes.all(func(c): return c.button_pressed)
	btn.text = "Décocher tout" if all_checked else "Cocher tout"


func _update_preview_button() -> void:
	if _preview_btn == null:
		return
	var has_completed = _queue != null and _queue.get_completed_count() > 0
	_preview_btn.disabled = not has_completed


func _get_selected_expressions() -> Array:
	var expressions: Array = []
	for cb in _elementary_checkboxes + _advanced_checkboxes:
		if cb.button_pressed:
			expressions.append(cb.text)
	for child in _custom_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var cb = child.get_child(0)
			if cb is CheckBox and cb.button_pressed:
				expressions.append(cb.text)
	return expressions


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


func _on_add_custom() -> void:
	var expr_text = _custom_input.text.strip_edges()
	if expr_text == "":
		return
	if _expression_already_exists(expr_text):
		_custom_input.text = ""
		return
	_add_custom_expression_ui(expr_text)
	_custom_input.text = ""
	_save_custom_expressions()
	_update_generate_button()


func _expression_already_exists(expr_text: String) -> bool:
	for cb in _elementary_checkboxes + _advanced_checkboxes:
		if cb.text.to_lower() == expr_text.to_lower():
			return true
	for child in _custom_container.get_children():
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
	cb.toggled.connect(func(_p): _update_generate_button())
	cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(cb)

	var del_btn = Button.new()
	del_btn.text = "✕"
	del_btn.custom_minimum_size = Vector2(30, 0)
	del_btn.pressed.connect(func():
		hbox.queue_free()
		_save_custom_expressions()
		_update_generate_button()
	)
	hbox.add_child(del_btn)

	_custom_container.add_child(hbox)


func _save_custom_expressions() -> void:
	var config = ComfyUIConfig.new()
	config.load_from()
	var customs: PackedStringArray = PackedStringArray([])
	for child in _custom_container.get_children():
		if child is HBoxContainer and child.get_child_count() > 0:
			var cb = child.get_child(0)
			if cb is CheckBox:
				customs.append(cb.text)
	config.set_custom_expressions(customs)
	config.save_to()


# --- Batch generation ---

func _on_generate_pressed() -> void:
	_save_config_fn.call()

	var expressions = _get_selected_expressions()
	var prefix = _prefix_input.text.strip_edges()

	_queue = ExpressionQueueService.new()
	var is_live_portrait = _strategy_option.get_selected_id() == 2
	_queue.build_queue(expressions, prefix, is_live_portrait)

	_generating = true
	_generate_btn.disabled = true
	_cancel_btn.visible = true
	_save_all_btn.disabled = true
	_set_inputs_enabled(false)

	# Build grid placeholders
	_build_results_grid()

	# Start processing
	_update_status()
	_process_next_expression()


func _process_next_expression() -> void:
	if _queue == null or _queue.is_cancelled():
		_on_batch_finished()
		return

	var idx = _queue.get_next_pending_index()
	if idx == -1:
		_on_batch_finished()
		return

	_queue.mark_generating(idx)
	var item = _queue.get_items()[idx]
	_update_grid_cell_status(idx)
	_update_status()

	if _client != null:
		_client.cancel()
		_client.queue_free()

	_client = Node.new()
	_client.set_script(ComfyUIClient)
	_parent_window.add_child(_client)

	_client.generation_completed.connect(_on_item_completed)
	_client.generation_failed.connect(_on_item_failed)
	_client.generation_progress.connect(_on_item_progress)

	var config = _get_config_fn.call()

	var strategy_id = _strategy_option.get_selected_id()
	var workflow_type: int
	match strategy_id:
		1: workflow_type = ComfyUIClient.WorkflowType.EXPRESSION_FACE_DETAILER
		2: workflow_type = ComfyUIClient.WorkflowType.EXPRESSION_LIVE_PORTRAIT
		_: workflow_type = ComfyUIClient.WorkflowType.EXPRESSION
	var cfg_value = _cfg_slider.value
	var steps_value = int(_steps_slider.value)
	var denoise_value = _denoise_slider.value
	var face_box_value = int(_face_box_slider.value)
	var neg_prompt = _neg_input.text.strip_edges()
	_client.generate(config, _source_image_path, item["prompt"], true, cfg_value, steps_value, workflow_type, denoise_value, neg_prompt, face_box_value, "4x-UltraSharp.pth", 512, 0, 0, _megapixels_slider.value)


func _on_item_completed(image: Image) -> void:
	var idx = _queue.get_current_index()
	_queue.mark_completed(idx, image)
	_update_grid_cell_image(idx, image)
	_update_grid_cell_status(idx)
	_update_status()
	_update_preview_button()
	# Update the preview popup if it's showing this item
	if _image_preview and _image_preview.visible and _image_preview.get_current_queue_index() == idx:
		var tex = ImageTexture.create_from_image(image)
		_image_preview.update_current_image(tex)
	_process_next_expression()


func _on_item_failed(error: String) -> void:
	var idx = _queue.get_current_index()
	_queue.mark_failed(idx, error)
	_update_grid_cell_status(idx)
	_update_status()
	# If preview is showing this item, show error and re-enable buttons
	if _image_preview and _image_preview.visible and _image_preview.get_current_queue_index() == idx:
		_image_preview._filename_label.text = _queue.get_items()[idx]["filename"] + " — Échoué"
		_image_preview._regenerating = false
		_image_preview._regenerate_btn.disabled = false
		_image_preview._delete_btn.disabled = false
	_process_next_expression()


func _on_item_progress(status: String) -> void:
	var idx = _queue.get_current_index()
	if idx >= 0:
		var item = _queue.get_items()[idx]
		_status_label.text = "%s — %s" % [item["filename"], status]


func _on_cancel_pressed() -> void:
	if _queue:
		_queue.cancel()
	cancel_generation()
	_on_batch_finished()


func _on_batch_finished() -> void:
	_generating = false
	_cancel_btn.visible = false
	_progress_bar.visible = false
	_set_inputs_enabled(true)
	_update_generate_button()
	_update_preview_button()
	if _queue and _queue.get_completed_count() > 0:
		_save_all_btn.disabled = false
		_status_label.text = "%d/%d terminés" % [_queue.get_completed_count(), _queue.get_total()]
		_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		_status_label.text = "Génération terminée (aucun résultat)"
		_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))


func _update_status() -> void:
	if _queue == null:
		return
	var done = _queue.get_done_count()
	var total = _queue.get_total()
	_status_label.text = "%d/%d générés" % [done, total]
	_status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_progress_bar.visible = true
	_progress_bar.indeterminate = false
	_progress_bar.min_value = 0
	_progress_bar.max_value = total
	_progress_bar.value = done


func _on_strategy_changed(_index: int) -> void:
	var is_live_portrait = _strategy_option.get_selected_id() == 2
	_diffusion_controls.visible = not is_live_portrait


func _set_inputs_enabled(enabled: bool) -> void:
	_neg_input.editable = enabled
	_choose_source_btn.disabled = not enabled
	if _story_base_path == "":
		_choose_gallery_btn.disabled = true
	else:
		_choose_gallery_btn.disabled = not enabled
	_prefix_input.editable = enabled
	_denoise_slider.editable = enabled
	_megapixels_slider.editable = enabled
	_face_box_slider.editable = enabled
	_custom_input.editable = enabled
	_add_custom_btn.disabled = not enabled
	_elementary_select_all_btn.disabled = not enabled
	_advanced_select_all_btn.disabled = not enabled
	for cb in _elementary_checkboxes + _advanced_checkboxes:
		cb.disabled = not enabled


# --- Results grid ---

func _build_results_grid() -> void:
	for child in _results_grid.get_children():
		_results_grid.remove_child(child)
		child.queue_free()

	if _queue == null:
		return

	for i in range(_queue.get_total()):
		var item = _queue.get_items()[i]
		var cell = _create_grid_cell(i, item["filename"])
		_results_grid.add_child(cell)


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
					_show_preview_fn.call(tex, label_text)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				_context_index = index
				_context_menu.position = Vector2i(
					int(_parent_window.get_position().x + event.global_position.x),
					int(_parent_window.get_position().y + event.global_position.y)
				)
				_context_menu.popup()
	)

	return panel


func _update_grid_cell_status(index: int) -> void:
	if index < 0 or index >= _results_grid.get_child_count():
		return
	var panel = _results_grid.get_child(index)
	var status_lbl = panel.get_node("VBox/Status") if panel.has_node("VBox/Status") else null
	if status_lbl == null:
		return
	var item = _queue.get_items()[index]
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
	if index < 0 or index >= _results_grid.get_child_count():
		return
	var panel = _results_grid.get_child(index)
	var tex_rect = panel.get_node("VBox/Preview") if panel.has_node("VBox/Preview") else null
	if tex_rect == null:
		return
	tex_rect.texture = ImageTexture.create_from_image(image)


# --- Context menu ---

func _on_context_menu_pressed(id: int) -> void:
	if _queue == null or _context_index < 0:
		return
	match id:
		0: _on_regenerate_item(_context_index)
		1: _on_delete_item(_context_index)


func _on_regenerate_item(index: int) -> void:
	if index < 0 or index >= _queue.get_total():
		return
	_queue.reset_item(index)
	_update_grid_cell_status(index)
	# Clear the preview
	var panel = _results_grid.get_child(index)
	if panel.has_node("VBox/Preview"):
		panel.get_node("VBox/Preview").texture = null
	if not _generating:
		_generating = true
		_cancel_btn.visible = true
		_save_all_btn.disabled = true
		_set_inputs_enabled(false)
		_process_next_expression()


func _on_delete_item(index: int) -> void:
	if index < 0 or index >= _queue.get_total():
		return
	_queue.remove_item(index)
	# Rebuild grid
	_build_results_grid()
	# Update images for completed items
	for i in range(_queue.get_total()):
		var item = _queue.get_items()[i]
		if item["status"] == ExpressionQueueService.ItemStatus.COMPLETED and item["image"] != null:
			_update_grid_cell_image(i, item["image"])
		_update_grid_cell_status(i)
	if _queue.get_completed_count() > 0:
		_save_all_btn.disabled = false
	else:
		_save_all_btn.disabled = true
	_update_preview_button()


# --- Save all ---

func _on_save_all_pressed() -> void:
	if _queue == null:
		return

	var completed = _queue.get_completed_items()
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
		_parent_window.add_child(dialog)
		dialog.confirmed.connect(func():
			_do_save_all(completed, dir_path, true)
			dialog.queue_free()
		)
		dialog.canceled.connect(dialog.queue_free)
		dialog.popup_centered()
		return

	_do_save_all(completed, dir_path, false)


func _do_save_all(completed: Array, dir_path: String, overwrite: bool) -> void:
	var saved_count := 0
	for item in completed:
		var filename = item["filename"] + ".png"
		var file_path = dir_path + "/" + filename
		if not overwrite and FileAccess.file_exists(file_path):
			file_path = _resolve_path_fn.call(dir_path, filename)
		item["image"].save_png(file_path)
		saved_count += 1

	GalleryCacheService.clear_dir(dir_path)

	_status_label.text = "%d images sauvegardées dans assets/foregrounds/" % saved_count
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_save_all_btn.disabled = true


# --- Preview ---

func _on_preview_pressed() -> void:
	if _queue == null or _image_preview == null:
		return
	var items = _build_preview_collection()
	if items.is_empty():
		return
	_image_preview.show_collection(items, 0)


func _build_preview_collection() -> Array:
	var items: Array = []
	if _queue == null:
		return items
	var queue_items = _queue.get_items()
	for i in range(queue_items.size()):
		var item = queue_items[i]
		if item["status"] == ExpressionQueueService.ItemStatus.COMPLETED and item["image"] != null:
			var tex = ImageTexture.create_from_image(item["image"])
			items.append({"texture": tex, "filename": item["filename"], "index": i})
	return items


func _load_preview(tex_rect: TextureRect, path: String) -> void:
	if path == "":
		tex_rect.texture = null
		return
	var img = Image.new()
	if img.load(path) == OK:
		tex_rect.texture = ImageTexture.create_from_image(img)
	else:
		tex_rect.texture = null
