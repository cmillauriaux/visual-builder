extends PanelContainer

## Vignette individuelle dans la timeline des dialogues.
## Affiche mini-aperçu, compteur FG, personnage et texte.

const TextureLoaderScript = preload("res://src/ui/shared/texture_loader.gd")

var _dialogue_index: int = -1
var _is_inherited: bool = false
var _fg_count: int = 0
var _selected: bool = false
var _dialogue_data = null
var _bg_path: String = ""
var _fg_images: Array = []  # Array of {image: String, anchor_bg: Vector2, scale: float}

var _preview_bg: ColorRect
var _preview_tex: TextureRect
var _badge_label: Label
var _character_label: Label
var _text_label: Label

signal item_clicked(index: int)
signal item_right_clicked(index: int, global_pos: Vector2)

func setup(index: int, dialogue, is_inherited: bool, fg_count: int, bg_path: String = "", foregrounds: Array = []) -> void:
	_dialogue_index = index
	_is_inherited = is_inherited
	_fg_count = fg_count
	_dialogue_data = dialogue
	_bg_path = bg_path
	_fg_images = []
	for fg in foregrounds:
		_fg_images.append({"image": fg.image, "anchor_bg": fg.anchor_bg, "anchor_fg": fg.anchor_fg, "scale": fg.scale})
	if _character_label:
		_apply_dialogue_data(dialogue)
		_apply_preview()
		_apply_style()

func _ready() -> void:
	custom_minimum_size = Vector2(110, 0)
	mouse_filter = MOUSE_FILTER_STOP

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	# Preview area (top) — ColorRect as bg + TextureRect for image
	_preview_bg = ColorRect.new()
	_preview_bg.custom_minimum_size = Vector2(0, 55)
	_preview_bg.color = Color(0.07, 0.07, 0.07)
	_preview_bg.mouse_filter = MOUSE_FILTER_IGNORE
	_preview_bg.clip_contents = true
	vbox.add_child(_preview_bg)

	_preview_tex = TextureRect.new()
	_preview_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_preview_tex.set_anchors_preset(PRESET_FULL_RECT)
	_preview_tex.mouse_filter = MOUSE_FILTER_IGNORE
	_preview_bg.add_child(_preview_tex)

	# Badge (top-right of preview)
	_badge_label = Label.new()
	_badge_label.add_theme_font_size_override("font_size", 9)
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge_label.set_anchors_preset(PRESET_TOP_RIGHT)
	_badge_label.offset_right = -4
	_badge_label.offset_top = 2
	_preview_bg.add_child(_badge_label)

	# Character name
	_character_label = Label.new()
	_character_label.add_theme_font_size_override("font_size", 11)
	_character_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(_character_label)

	# Text preview
	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 9)
	_text_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	_text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vbox.add_child(_text_label)

	gui_input.connect(_on_gui_input)

	# Apply stored data from setup() (called before _ready)
	if _dialogue_data:
		_apply_dialogue_data(_dialogue_data)
	_apply_preview()
	_apply_style()


func _apply_dialogue_data(dialogue) -> void:
	if dialogue == null:
		return
	_character_label.text = dialogue.character if dialogue.character != "" else "(vide)"
	_text_label.text = dialogue.text if dialogue.text != "" else ""


func _apply_preview() -> void:
	if _preview_tex == null:
		return
	# Background
	if _bg_path != "":
		var tex = TextureLoaderScript.load_texture(_bg_path)
		if tex:
			_preview_tex.texture = tex
	# Foreground silhouettes — same positioning as sequence_visual_editor.gd
	# 1. Compute canvas-space position using actual bg texture size
	# 2. Scale from canvas viewport (1920x1080) to preview space
	var canvas_ref = Vector2(1920.0, 1080.0)
	var preview_size = Vector2(110.0, 55.0)
	var bg_tex_size = _preview_tex.texture.get_size() if _preview_tex.texture else canvas_ref
	for fg_data in _fg_images:
		var fg_tex = TextureLoaderScript.load_texture(fg_data["image"])
		if fg_tex == null:
			continue
		var fg_rect = TextureRect.new()
		fg_rect.texture = fg_tex
		fg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		fg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		fg_rect.mouse_filter = MOUSE_FILTER_IGNORE
		# Canvas-space position (same formula as sequence_visual_editor.gd)
		var fg_canvas_size = fg_tex.get_size() * fg_data["scale"]
		var canvas_pos = fg_data["anchor_bg"] * bg_tex_size - fg_data["anchor_fg"] * fg_canvas_size
		# Scale to preview
		var scale_uniform = preview_size.x / canvas_ref.x
		var fg_preview_sz = fg_canvas_size * scale_uniform
		var fg_preview_pos = canvas_pos * (preview_size / canvas_ref)
		fg_rect.custom_minimum_size = fg_preview_sz
		fg_rect.size = fg_preview_sz
		fg_rect.position = fg_preview_pos
		_preview_bg.add_child(fg_rect)


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_style()


func _apply_style() -> void:
	if _selected:
		add_theme_stylebox_override("panel", _create_selected_style())
		_character_label.add_theme_color_override("font_color", Color(0.29, 0.29, 1.0))
	else:
		remove_theme_stylebox_override("panel")
		if _is_inherited:
			_character_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			_character_label.remove_theme_color_override("font_color")

	# Badge
	if _is_inherited:
		_badge_label.text = "⟵ hérité"
		_badge_label.add_theme_color_override("font_color", Color("#ffaa00"))
		modulate.a = 0.65
	else:
		_badge_label.text = "%d FG" % _fg_count
		_badge_label.add_theme_color_override("font_color", Color(0.29, 0.29, 1.0))
		modulate.a = 1.0


func _create_selected_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.29, 0.29, 1.0, 0.1)
	style.border_color = Color(0.29, 0.29, 1.0, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			item_clicked.emit(_dialogue_index)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			item_right_clicked.emit(_dialogue_index, get_global_mouse_position())


func get_dialogue_index() -> int:
	return _dialogue_index


func _can_drop_data(_at_position: Vector2, data) -> bool:
	if data is Dictionary and data.get("type") == "foreground_layer":
		add_theme_stylebox_override("panel", _create_drop_highlight_style())
		return true
	return false


func _drop_data(_at_position: Vector2, data) -> void:
	_apply_style()
	if data is Dictionary and data.get("type") == "foreground_layer":
		# Propagate up to the timeline
		var timeline = get_parent()
		while timeline and not timeline.has_method("_on_foreground_dropped"):
			timeline = timeline.get_parent()
		if timeline:
			timeline._on_foreground_dropped(data, _dialogue_index)


func _create_drop_highlight_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.5, 0.1, 0.2)
	style.border_color = Color(0.2, 0.8, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style
