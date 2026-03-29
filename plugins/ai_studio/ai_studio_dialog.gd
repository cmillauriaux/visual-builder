extends Window

## Studio IA : dialogue avancé de génération d'images par IA.
## Six onglets : Décliner, Expressions, Outpainting, Upscale, Enhance, Upscale + Enhance.

const ComfyUIConfig = preload("res://src/services/comfyui_config.gd")
const ComfyUIClient = preload("res://src/services/comfyui_client.gd")
const ImagePreviewPopup = preload("res://src/ui/shared/image_preview_popup.gd")
const ImageFileDialog = preload("res://src/ui/shared/image_file_dialog.gd")
const ImageRenameService = preload("res://src/services/image_rename_service.gd")
const ImageCategoryService = preload("res://src/services/image_category_service.gd")
const ExpressionQueueService = preload("res://src/services/expression_queue_service.gd")

const DeclinerTab = preload("res://plugins/ai_studio/ai_studio_decliner_tab.gd")
const ExpressionsTab = preload("res://plugins/ai_studio/ai_studio_expressions_tab.gd")
const OutpaintTab = preload("res://plugins/ai_studio/ai_studio_outpaint_tab.gd")
const UpscaleTab = preload("res://plugins/ai_studio/ai_studio_upscale_tab.gd")
const EnhanceTab = preload("res://plugins/ai_studio/ai_studio_enhance_tab.gd")
const UpscaleEnhanceTab = preload("res://plugins/ai_studio/ai_studio_upscale_enhance_tab.gd")

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
var _provider_option: OptionButton
var _url_label: Label
var _url_input: LineEdit
var _token_label: Label
var _token_input: LineEdit
var _negative_prompt_input: TextEdit
var _image_preview: Control

# Tab controllers
var _decl_tab: RefCounted = null
var _expr_tab: RefCounted = null
var _outpaint_tab: RefCounted = null
var _upscale_tab: RefCounted = null
var _enhance_tab: RefCounted = null
var _upscale_enhance_tab: RefCounted = null


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
	_decl_tab.setup(story_base_path, has_story)
	_expr_tab.setup(story_base_path, has_story)
	_outpaint_tab.setup(story_base_path, has_story)
	_upscale_tab.setup(story_base_path, has_story)
	_enhance_tab.setup(story_base_path, has_story)
	_upscale_enhance_tab.setup(story_base_path, has_story)


func _on_close() -> void:
	_decl_tab.cancel_generation()
	_expr_tab.cancel_generation()
	_outpaint_tab.cancel_generation()
	_upscale_tab.cancel_generation()
	_enhance_tab.cancel_generation()
	_upscale_enhance_tab.cancel_generation()
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

	# --- Shared IA config ---
	var provider_label = Label.new()
	provider_label.text = "Provider :"
	vbox.add_child(provider_label)

	_provider_option = OptionButton.new()
	_provider_option.add_item("ComfyUI local", ComfyUIConfig.PROVIDER_LOCAL)
	_provider_option.add_item("RunPod", ComfyUIConfig.PROVIDER_RUNPOD)
	_provider_option.item_selected.connect(_on_provider_changed)
	vbox.add_child(_provider_option)

	_url_label = Label.new()
	_url_label.text = "URL ComfyUI :"
	vbox.add_child(_url_label)

	_url_input = LineEdit.new()
	_url_input.placeholder_text = "http://localhost:8188"
	_url_input.text_changed.connect(func(_t): _update_all_generate_buttons())
	vbox.add_child(_url_input)

	_token_label = Label.new()
	_token_label.text = "Token (optionnel) :"
	vbox.add_child(_token_label)

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

	_decl_tab = DeclinerTab.new()
	_expr_tab = ExpressionsTab.new()
	_outpaint_tab = OutpaintTab.new()
	_upscale_tab = UpscaleTab.new()
	_enhance_tab = EnhanceTab.new()
	_upscale_enhance_tab = UpscaleEnhanceTab.new()

	for tab in [_decl_tab, _expr_tab, _outpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab]:
		tab.initialize(self, _get_config, _negative_prompt_input,
			_show_image_preview, _open_gallery_source_picker, _save_config, _resolve_unique_path)
		tab.build_tab(_tab_container)

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
	_image_preview.regenerate_requested.connect(_expr_tab._on_regenerate_item)
	_image_preview.delete_requested.connect(_expr_tab._on_delete_item)
	add_child(_image_preview)
	_expr_tab.set_image_preview(_image_preview)


# ========================================================
# Config
# ========================================================

func _load_config() -> void:
	var config = ComfyUIConfig.new()
	config.load_from()
	_provider_option.select(config.get_provider())
	_url_input.text = config.get_url()
	_token_input.text = config.get_token()
	_negative_prompt_input.text = config.get_negative_prompt()
	_apply_provider_ui(config.get_provider())
	_update_all_generate_buttons()
	_update_cfg_hints()


func _save_config() -> void:
	var config = ComfyUIConfig.new()
	config.set_provider(_provider_option.get_selected_id())
	config.set_url(_url_input.text.strip_edges())
	config.set_token(_token_input.text.strip_edges())
	config.set_negative_prompt(_negative_prompt_input.text.strip_edges())
	# Preserve custom expressions
	var existing = ComfyUIConfig.new()
	existing.load_from()
	config.set_custom_expressions(existing.get_custom_expressions())
	config.save_to()


func _get_config() -> RefCounted:
	var config = ComfyUIConfig.new()
	config.set_provider(_provider_option.get_selected_id())
	config.set_url(_url_input.text.strip_edges())
	config.set_token(_token_input.text.strip_edges())
	return config


func _on_provider_changed(index: int) -> void:
	var provider = _provider_option.get_item_id(index)
	_apply_provider_ui(provider)
	_update_all_generate_buttons()


func _apply_provider_ui(provider: int) -> void:
	if provider == ComfyUIConfig.PROVIDER_RUNPOD:
		_url_label.text = "Endpoint RunPod :"
		_url_input.placeholder_text = "https://api.runpod.ai/v2/..."
		_token_label.text = "API Key :"
		_token_input.placeholder_text = "rpa_..."
	else:
		_url_label.text = "URL ComfyUI :"
		_url_input.placeholder_text = "http://localhost:8188"
		_token_label.text = "Token (optionnel) :"
		_token_input.placeholder_text = "Laisser vide si pas d'auth"


func _update_all_generate_buttons() -> void:
	_decl_tab.update_generate_button()
	_expr_tab.update_generate_button()
	_outpaint_tab.update_generate_button()
	_upscale_tab.update_generate_button()
	_enhance_tab.update_generate_button()
	_upscale_enhance_tab.update_generate_button()


func _update_cfg_hints() -> void:
	var has_negative = _negative_prompt_input.text.strip_edges() != ""
	for tab in [_decl_tab, _expr_tab, _outpaint_tab, _upscale_tab, _enhance_tab, _upscale_enhance_tab]:
		tab.update_cfg_hint(has_negative)


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


