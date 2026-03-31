extends RefCounted

## Onglet "Blink" du Studio IA.
## Permet la génération par lots de clignements d'yeux pour plusieurs images sources.
## Suit le même patron que ai_studio_expressions_tab.gd.

const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const BlinkQueueService = preload("res://src/services/blink_queue_service.gd")
const BlinkManifestService = preload("res://src/services/blink_manifest_service.gd")

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
var _gallery_btn: Button
var _selection_count_label: Label
var _selected_scroll: ScrollContainer
var _selected_grid: GridContainer
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
var _generate_btn: Button
var _cancel_btn: Button
var _status_label: Label
var _progress_bar: ProgressBar
var _results_grid: GridContainer
var _save_all_btn: Button
var _preview_btn: Button

# State
var _selected_sources: Array = []
var _client: Node = null
var _queue: RefCounted = null
var _generating: bool = false

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
	scroll.name = "Blink"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_container.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# --- Multi-image source selection ---
	var source_label = Label.new()
	source_label.text = "Images sources :"
	vbox.add_child(source_label)

	var source_hbox = HBoxContainer.new()
	source_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(source_hbox)

	_gallery_btn = Button.new()
	_gallery_btn.text = "Galerie..."
	_gallery_btn.pressed.connect(_open_multi_gallery)
	source_hbox.add_child(_gallery_btn)

	_selection_count_label = Label.new()
	_selection_count_label.text = "(0 sélectionnée(s))"
	source_hbox.add_child(_selection_count_label)

	# Selected images preview area
	_selected_scroll = ScrollContainer.new()
	_selected_scroll.custom_minimum_size = Vector2(0, 150)
	_selected_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_selected_scroll)

	_selected_grid = GridContainer.new()
	_selected_grid.columns = 4
	_selected_grid.add_theme_constant_override("h_separation", 4)
	_selected_grid.add_theme_constant_override("v_separation", 4)
	_selected_scroll.add_child(_selected_grid)

	vbox.add_child(HSeparator.new())

	# --- CFG slider ---
	var cfg_hbox = HBoxContainer.new()
	cfg_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(cfg_hbox)

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
	vbox.add_child(_cfg_hint)

	# --- Steps slider ---
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
	_steps_slider.value = 4
	_steps_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_steps_slider.value_changed.connect(func(val: float): _steps_value_label.text = str(int(val)))
	steps_hbox.add_child(_steps_slider)

	_steps_value_label = Label.new()
	_steps_value_label.text = "4"
	_steps_value_label.custom_minimum_size.x = 32
	steps_hbox.add_child(_steps_value_label)

	# --- Denoise slider ---
	var denoise_hbox = HBoxContainer.new()
	denoise_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(denoise_hbox)

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

	# --- Megapixels slider ---
	var mp_hbox = HBoxContainer.new()
	mp_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(mp_hbox)

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

	# --- Face box size slider ---
	var face_box_hbox = HBoxContainer.new()
	face_box_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(face_box_hbox)

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

	# --- Status + Generation ---
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
	_generate_btn.text = "Générer les blinks"
	_generate_btn.disabled = true
	_generate_btn.pressed.connect(_on_generate_pressed)
	gen_hbox.add_child(_generate_btn)

	_cancel_btn = Button.new()
	_cancel_btn.text = "Annuler"
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	gen_hbox.add_child(_cancel_btn)

	vbox.add_child(HSeparator.new())

	# --- Results header with preview button ---
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

	vbox.add_child(HSeparator.new())

	# --- Save all ---
	_save_all_btn = Button.new()
	_save_all_btn.text = "Tout sauvegarder"
	_save_all_btn.disabled = true
	_save_all_btn.pressed.connect(_on_save_all_pressed)
	vbox.add_child(_save_all_btn)


func setup(story_base_path: String, has_story: bool) -> void:
	_story_base_path = story_base_path
	if _gallery_btn:
		_gallery_btn.disabled = not has_story


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
	var has_sources = not _selected_sources.is_empty()
	_generate_btn.disabled = not (has_url and has_sources)


func _update_preview_button() -> void:
	if _preview_btn == null:
		return
	var has_completed = _queue != null and _queue.get_completed_count() > 0
	_preview_btn.disabled = not has_completed


# --- Multi-select gallery ---

func _open_multi_gallery() -> void:
	if _story_base_path == "":
		return

	var gallery_window = Window.new()
	gallery_window.title = "Choisir les images sources"
	gallery_window.size = Vector2i(640, 500)
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

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)

	# Track checkboxes per path
	var checkbox_map: Dictionary = {}

	var images: Array = []
	images.append_array(GalleryCacheService.get_file_list(_story_base_path + "/assets/foregrounds", ["png", "jpg", "jpeg", "webp"]))
	images.append_array(GalleryCacheService.get_file_list(_story_base_path + "/assets/backgrounds", ["png", "jpg", "jpeg", "webp"]))
	images.sort()

	for path in images:
		var container = PanelContainer.new()
		container.custom_minimum_size = Vector2(120, 160)

		var cv = VBoxContainer.new()
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		container.add_child(cv)

		var cb = CheckBox.new()
		cb.text = path.get_file()
		cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cb.button_pressed = path in _selected_sources
		cv.add_child(cb)

		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(100, 100)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture = GalleryCacheService.get_texture(path)
		cv.add_child(tex_rect)

		# Click anywhere on the panel toggles the checkbox
		container.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				cb.button_pressed = not cb.button_pressed
		)

		checkbox_map[path] = cb
		grid.add_child(container)

	# Bottom buttons
	var bottom_hbox = HBoxContainer.new()
	bottom_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom_hbox)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_hbox.add_child(spacer)

	var cancel_btn = Button.new()
	cancel_btn.text = "Annuler"
	cancel_btn.pressed.connect(func(): gallery_window.queue_free())
	bottom_hbox.add_child(cancel_btn)

	var validate_btn = Button.new()
	validate_btn.text = "Valider"
	validate_btn.pressed.connect(func():
		var selected: Array = []
		for p in checkbox_map:
			if checkbox_map[p].button_pressed:
				selected.append(p)
		_on_multi_gallery_selected(selected)
		gallery_window.queue_free()
	)
	bottom_hbox.add_child(validate_btn)

	gallery_window.close_requested.connect(func(): gallery_window.queue_free())
	_parent_window.add_child(gallery_window)
	gallery_window.popup_centered()


func _on_multi_gallery_selected(paths: Array) -> void:
	_selected_sources = paths
	_rebuild_selected_grid()
	_selection_count_label.text = "(%d sélectionnée(s))" % _selected_sources.size()
	_update_generate_button()


func _rebuild_selected_grid() -> void:
	for child in _selected_grid.get_children():
		child.queue_free()

	for path in _selected_sources:
		var panel = Panel.new()
		panel.custom_minimum_size = Vector2(110, 130)

		var cv = VBoxContainer.new()
		cv.set_anchors_preset(Control.PRESET_FULL_RECT)
		cv.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(cv)

		var tex_rect = TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(96, 96)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.texture = GalleryCacheService.get_texture(path)
		cv.add_child(tex_rect)

		var lbl = Label.new()
		lbl.text = path.get_file()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cv.add_child(lbl)

		var remove_path = path
		var remove_btn = Button.new()
		remove_btn.text = "✕"
		remove_btn.custom_minimum_size = Vector2(24, 0)
		remove_btn.pressed.connect(func():
			_selected_sources.erase(remove_path)
			_rebuild_selected_grid()
			_selection_count_label.text = "(%d sélectionnée(s))" % _selected_sources.size()
			_update_generate_button()
		)
		cv.add_child(remove_btn)

		_selected_grid.add_child(panel)


# --- Batch generation ---

func _on_generate_pressed() -> void:
	_save_config_fn.call()

	_queue = BlinkQueueService.new()
	_queue.build_queue(_selected_sources)

	_generating = true
	_generate_btn.disabled = true
	_cancel_btn.visible = true
	_save_all_btn.disabled = true
	_set_inputs_enabled(false)

	_build_results_grid()
	_update_status()
	_process_next_item()


func _process_next_item() -> void:
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
	var workflow_type: int = ComfyUIClient.WorkflowType.EXPRESSION
	var cfg_value = _cfg_slider.value
	var steps_value = int(_steps_slider.value)
	var denoise_value = _denoise_slider.value
	var face_box_value = int(_face_box_slider.value)
	var neg_prompt = _neg_input.text.strip_edges()
	_client.generate(config, item["source_path"], item["prompt"], true, cfg_value, steps_value, workflow_type, denoise_value, neg_prompt, face_box_value, _megapixels_slider.value)


func _on_item_completed(image: Image) -> void:
	var idx = _queue.get_current_index()
	_queue.mark_completed(idx, image)
	_update_grid_cell_image(idx, image)
	_update_grid_cell_status(idx)
	_update_status()
	_update_preview_button()
	_process_next_item()


func _on_item_failed(error: String) -> void:
	var idx = _queue.get_current_index()
	_queue.mark_failed(idx, error)
	_update_grid_cell_status(idx)
	_update_status()
	_process_next_item()


func _on_item_progress(status: String) -> void:
	var idx = _queue.get_current_index()
	if idx >= 0:
		var item = _queue.get_items()[idx]
		_status_label.text = "%s — %s" % [item["blink_filename"], status]


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


func _set_inputs_enabled(enabled: bool) -> void:
	_neg_input.editable = enabled
	if _story_base_path == "":
		_gallery_btn.disabled = true
	else:
		_gallery_btn.disabled = not enabled
	_denoise_slider.editable = enabled
	_megapixels_slider.editable = enabled
	_face_box_slider.editable = enabled


# --- Results grid ---

func _build_results_grid() -> void:
	for child in _results_grid.get_children():
		_results_grid.remove_child(child)
		child.queue_free()

	if _queue == null:
		return

	for i in range(_queue.get_total()):
		var item = _queue.get_items()[i]
		var cell = _create_grid_cell(i, item["blink_filename"])
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

	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
				var tex = tex_rect.texture
				if tex:
					_show_preview_fn.call(tex, label_text)
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
		BlinkQueueService.ItemStatus.PENDING:
			status_lbl.text = "En attente"
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		BlinkQueueService.ItemStatus.GENERATING:
			status_lbl.text = "En cours..."
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
		BlinkQueueService.ItemStatus.COMPLETED:
			status_lbl.text = "Terminé"
			status_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		BlinkQueueService.ItemStatus.FAILED:
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
		if item["status"] == BlinkQueueService.ItemStatus.COMPLETED and item["image"] != null:
			var tex = ImageTexture.create_from_image(item["image"])
			items.append({"texture": tex, "filename": item["blink_filename"], "index": i})
	return items


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
		var file_path = dir_path + "/" + item["blink_filename"]
		if FileAccess.file_exists(file_path):
			existing.append(item["blink_filename"])

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
		var file_path = dir_path + "/" + item["blink_filename"]
		if not overwrite and FileAccess.file_exists(file_path):
			file_path = _resolve_path_fn.call(dir_path, item["blink_filename"])
		item["image"].save_png(file_path)
		# Update blink manifest
		var source_filename = item["source_path"].get_file()
		BlinkManifestService.set_blink(_story_base_path, source_filename, item["blink_filename"].get_file())
		saved_count += 1
	GalleryCacheService.clear_dir(dir_path)
	_status_label.text = "%d images sauvegardées dans assets/foregrounds/" % saved_count
	_status_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	_save_all_btn.disabled = true
