extends VBoxContainer

## Sidebar gauche affichant les variables visibles pendant le jeu.
## Chaque variable est affichée comme un cercle avec une image et une valeur en dessous.

signal details_requested()

const TextureLoaderScript = preload("res://src/ui/shared/texture_loader.gd")

var _story = null


func update_display(variables: Dictionary, story) -> void:
	_story = story
	_clear()
	if story == null:
		visible = false
		return
	var display_vars = story.get_main_display_variables()
	var has_visible := false
	for var_def in display_vars:
		if _is_variable_visible(var_def, variables):
			has_visible = true
			var value = str(variables.get(var_def.var_name, var_def.initial_value))
			_add_variable_item(var_def, value)
	visible = has_visible


func _is_variable_visible(var_def, variables: Dictionary) -> bool:
	if var_def.visibility_mode == "always":
		return true
	if var_def.visibility_mode == "variable":
		var ctrl_val = str(variables.get(var_def.visibility_variable, "0"))
		return ctrl_val == "1"
	return false


func _add_variable_item(var_def, value: String) -> void:
	var item = VBoxContainer.new()
	item.mouse_filter = Control.MOUSE_FILTER_STOP
	item.add_theme_constant_override("separation", 4)

	# Cercle avec image
	var circle = PanelContainer.new()
	circle.custom_minimum_size = Vector2(96, 96)
	var circle_style = StyleBoxFlat.new()
	circle_style.bg_color = Color(0.3, 0.25, 0.15, 0.8)
	circle_style.set_corner_radius_all(48)
	circle_style.content_margin_left = 8
	circle_style.content_margin_right = 8
	circle_style.content_margin_top = 8
	circle_style.content_margin_bottom = 8
	circle.add_theme_stylebox_override("panel", circle_style)
	circle.clip_contents = true

	var tex_rect = TextureRect.new()
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(80, 80)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if var_def.image != "":
		var tex = TextureLoaderScript.load_texture(var_def.image)
		if tex:
			tex_rect.texture = tex
	circle.add_child(tex_rect)
	item.add_child(circle)

	# Valeur
	var val_label = Label.new()
	val_label.text = value
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_label.add_theme_font_size_override("font_size", 24)
	val_label.add_theme_color_override("font_color", Color.WHITE)
	val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(val_label)

	item.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			details_requested.emit()
	)

	add_child(item)


func _clear() -> void:
	for child in get_children():
		child.queue_free()
