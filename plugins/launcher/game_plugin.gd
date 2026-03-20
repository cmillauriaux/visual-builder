extends "res://src/plugins/game_plugin.gd"

## Plugin Launcher : affiche une séquence d'écrans de lancement avant le menu.
## Étapes configurables : logo studio, logo moteur, disclaimer, texte libre.
## Configuration lue depuis story.plugin_settings["launcher"].

const GameContributions = preload("res://src/plugins/game_contributions.gd")

## Overlay plein écran utilisé pendant la séquence de lancement
var _overlay: ColorRect = null
## Référence au noeud de jeu pour pouvoir y ajouter l'overlay
var _game_node: Control = null
## Indique si la séquence est en cours de lecture
var _is_playing: bool = false
## Génération pour annuler les séquences en cours si le jeu redémarre
var _play_generation: int = 0


func get_plugin_name() -> String:
	return "launcher"


func get_plugin_description() -> String:
	return "Écrans de lancement (logo, disclaimer, texte)"


func is_configurable() -> bool:
	return true


func get_plugin_folder() -> String:
	return "launcher"


func on_game_ready(ctx: RefCounted) -> void:
	if ctx == null or ctx.game_node == null:
		return
	_game_node = ctx.game_node
	var config := _get_config(ctx)
	var steps := _build_steps(config, ctx)
	if steps.is_empty():
		return
	_play_generation += 1
	await _play_sequence(steps, _play_generation)


func on_game_cleanup(_ctx: RefCounted) -> void:
	_cleanup_overlay()


# --- Génération des étapes ---

## Retourne la configuration du plugin depuis la story.
func _get_config(ctx: RefCounted) -> Dictionary:
	if ctx.story == null:
		return _get_default_config()
	if ctx.story.get("plugin_settings") == null:
		return _get_default_config()
	if not ctx.story.plugin_settings.has("launcher"):
		return _get_default_config()
	var cfg: Dictionary = ctx.story.plugin_settings["launcher"]
	return cfg


static func _get_default_config() -> Dictionary:
	return {
		"studio_logo_enabled": false,
		"studio_logo_path": "",
		"studio_logo_duration": 2.0,
		"engine_logo_enabled": true,
		"engine_logo_duration": 2.0,
		"disclaimer_enabled": false,
		"disclaimer_text": "DISCLAIMER",
		"disclaimer_duration": 3.0,
		"free_text_enabled": false,
		"free_text_content": "",
		"free_text_duration": 3.0,
	}


## Construit la liste des étapes à afficher, chaque étape est un Dictionary.
## Retourne un Array de {"type": String, "config": Dictionary}.
func _build_steps(config: Dictionary, ctx: RefCounted) -> Array:
	var steps: Array = []

	if config.get("studio_logo_enabled", false):
		var logo_path: String = config.get("studio_logo_path", "")
		if logo_path != "":
			# Résoudre le chemin relatif
			if not logo_path.begins_with("res://") and not logo_path.begins_with("user://"):
				logo_path = ctx.story_base_path + "/" + logo_path
		steps.append({
			"type": "studio_logo",
			"path": logo_path,
			"duration": config.get("studio_logo_duration", 2.0),
		})

	if config.get("engine_logo_enabled", true):
		steps.append({
			"type": "engine_logo",
			"duration": config.get("engine_logo_duration", 2.0),
		})

	if config.get("disclaimer_enabled", false):
		steps.append({
			"type": "disclaimer",
			"text": config.get("disclaimer_text", "DISCLAIMER"),
			"duration": config.get("disclaimer_duration", 3.0),
		})

	if config.get("free_text_enabled", false):
		var text: String = config.get("free_text_content", "")
		if text != "":
			steps.append({
				"type": "free_text",
				"text": text,
				"duration": config.get("free_text_duration", 3.0),
			})

	return steps


# --- Lecture de la séquence ---

func _play_sequence(steps: Array, generation: int) -> void:
	if _game_node == null or not is_instance_valid(_game_node):
		return
	_is_playing = true
	_create_overlay()

	for step in steps:
		if generation != _play_generation:
			break
		_clear_overlay_content()
		var content := _create_step_content(step)
		if content != null:
			_overlay.add_child(content)
		# Fade in
		_overlay.modulate.a = 0.0
		var fade_in := _game_node.get_tree().create_tween()
		fade_in.tween_property(_overlay, "modulate:a", 1.0, 0.3)
		await fade_in.finished
		if generation != _play_generation:
			break
		# Attendre la durée ou un input utilisateur
		var duration: float = step.get("duration", 2.0)
		var skipped := await _wait_or_skip(duration, generation)
		if generation != _play_generation:
			break
		# Fade out
		var fade_out := _game_node.get_tree().create_tween()
		fade_out.tween_property(_overlay, "modulate:a", 0.0, 0.3)
		await fade_out.finished
		if generation != _play_generation:
			break

	_cleanup_overlay()
	_is_playing = false


## Attend la durée spécifiée ou un input utilisateur (clic/touche).
## Retourne true si skippé par l'utilisateur.
func _wait_or_skip(duration: float, generation: int) -> bool:
	if _game_node == null or not is_instance_valid(_game_node):
		return true
	var tree := _game_node.get_tree()
	var elapsed := 0.0
	var step_time := 0.05
	while elapsed < duration:
		if generation != _play_generation:
			return true
		if _overlay == null or not is_instance_valid(_overlay):
			return true
		if _overlay.has_meta("_skipped") and _overlay.get_meta("_skipped"):
			_overlay.set_meta("_skipped", false)
			return true
		await tree.create_timer(step_time).timeout
		elapsed += step_time
	return false


# --- Création de l'overlay ---

func _create_overlay() -> void:
	_cleanup_overlay()
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.z_index = 100
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_meta("_skipped", false)
	_overlay.gui_input.connect(_on_overlay_input)
	_game_node.add_child(_overlay)


func _cleanup_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
		_overlay = null
	_is_playing = false


func _clear_overlay_content() -> void:
	if _overlay == null:
		return
	for child in _overlay.get_children():
		child.queue_free()


func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.set_meta("_skipped", true)
	elif event is InputEventKey and event.pressed:
		if _overlay != null and is_instance_valid(_overlay):
			_overlay.set_meta("_skipped", true)


# --- Contenu de chaque étape ---

func _create_step_content(step: Dictionary) -> Control:
	match step["type"]:
		"studio_logo":
			return _create_studio_logo_content(step)
		"engine_logo":
			return _create_engine_logo_content()
		"disclaimer":
			return _create_disclaimer_content(step)
		"free_text":
			return _create_free_text_content(step)
	return null


func _create_studio_logo_content(step: Dictionary) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var logo_path: String = step.get("path", "")
	if logo_path != "" and (FileAccess.file_exists(logo_path) or ResourceLoader.exists(logo_path)):
		var tex: Texture2D = null
		if logo_path.begins_with("res://"):
			tex = load(logo_path)
		else:
			var img := Image.load_from_file(logo_path)
			if img != null:
				tex = ImageTexture.create_from_image(img)
		if tex != null:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.custom_minimum_size = Vector2(512, 512)
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(tex_rect)
			return center

	# Fallback: texte "Studio" si pas d'image
	var label := Label.new()
	label.text = "Studio"
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)
	return center


func _create_engine_logo_content() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	# Logo Godot intégré (icône du projet ou icône par défaut)
	var icon_tex: Texture2D = null
	if ResourceLoader.exists("res://icon.svg"):
		icon_tex = load("res://icon.svg")
	elif ResourceLoader.exists("res://icon.png"):
		icon_tex = load("res://icon.png")
	if icon_tex != null:
		var tex_rect := TextureRect.new()
		tex_rect.texture = icon_tex
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(128, 128)
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tex_rect)

	var label := Label.new()
	label.text = "Made with Godot Engine"
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(label)

	return center


func _create_disclaimer_content(step: Dictionary) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = step.get("text", "DISCLAIMER")
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(1, 0, 0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)

	return center


func _create_free_text_content(step: Dictionary) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label := Label.new()
	label.text = step.get("text", "")
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(label)

	return center


# --- Configuration éditeur ---

func get_editor_config_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_editor_config
	return [def]


func _create_editor_config(current_settings) -> Control:
	var ps: Dictionary = {}
	if current_settings is Dictionary:
		ps = current_settings
	# Merge avec les valeurs par défaut
	var defaults := _get_default_config()
	for key in defaults:
		if not ps.has(key):
			ps[key] = defaults[key]

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	# --- Section Logo Studio ---
	var studio_check := CheckButton.new()
	studio_check.name = "StudioLogoCheck"
	studio_check.text = "Logo Studio"
	studio_check.button_pressed = ps.get("studio_logo_enabled", false)
	vbox.add_child(studio_check)

	var studio_path_edit := LineEdit.new()
	studio_path_edit.name = "StudioLogoPathEdit"
	studio_path_edit.placeholder_text = "Chemin vers l'image du logo"
	studio_path_edit.text = ps.get("studio_logo_path", "")
	vbox.add_child(studio_path_edit)

	# --- Section Logo Moteur ---
	var engine_check := CheckButton.new()
	engine_check.name = "EngineLogoCheck"
	engine_check.text = "Logo Moteur (Made with Godot Engine)"
	engine_check.button_pressed = ps.get("engine_logo_enabled", true)
	vbox.add_child(engine_check)

	# --- Section Disclaimer ---
	var disclaimer_check := CheckButton.new()
	disclaimer_check.name = "DisclaimerCheck"
	disclaimer_check.text = "Disclaimer"
	disclaimer_check.button_pressed = ps.get("disclaimer_enabled", false)
	vbox.add_child(disclaimer_check)

	var disclaimer_edit := LineEdit.new()
	disclaimer_edit.name = "DisclaimerTextEdit"
	disclaimer_edit.placeholder_text = "Texte du disclaimer"
	disclaimer_edit.text = ps.get("disclaimer_text", "DISCLAIMER")
	vbox.add_child(disclaimer_edit)

	# --- Section Texte Libre ---
	var free_text_check := CheckButton.new()
	free_text_check.name = "FreeTextCheck"
	free_text_check.text = "Texte Libre"
	free_text_check.button_pressed = ps.get("free_text_enabled", false)
	vbox.add_child(free_text_check)

	var free_text_edit := TextEdit.new()
	free_text_edit.name = "FreeTextEdit"
	free_text_edit.placeholder_text = "Texte libre à afficher"
	free_text_edit.text = ps.get("free_text_content", "")
	free_text_edit.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(free_text_edit)

	# Stocker les références pour la lecture
	vbox.set_meta("_studio_check", studio_check)
	vbox.set_meta("_studio_path_edit", studio_path_edit)
	vbox.set_meta("_engine_check", engine_check)
	vbox.set_meta("_disclaimer_check", disclaimer_check)
	vbox.set_meta("_disclaimer_edit", disclaimer_edit)
	vbox.set_meta("_free_text_check", free_text_check)
	vbox.set_meta("_free_text_edit", free_text_edit)

	return vbox


## Lit les valeurs actuelles des contrôles éditeur et retourne un Dictionary.
static func read_editor_config(control: Control) -> Dictionary:
	if control == null:
		return {}
	return {
		"studio_logo_enabled": control.get_meta("_studio_check").button_pressed if control.has_meta("_studio_check") else false,
		"studio_logo_path": control.get_meta("_studio_path_edit").text if control.has_meta("_studio_path_edit") else "",
		"studio_logo_duration": 2.0,
		"engine_logo_enabled": control.get_meta("_engine_check").button_pressed if control.has_meta("_engine_check") else true,
		"engine_logo_duration": 2.0,
		"disclaimer_enabled": control.get_meta("_disclaimer_check").button_pressed if control.has_meta("_disclaimer_check") else false,
		"disclaimer_text": control.get_meta("_disclaimer_edit").text if control.has_meta("_disclaimer_edit") else "DISCLAIMER",
		"disclaimer_duration": 3.0,
		"free_text_enabled": control.get_meta("_free_text_check").button_pressed if control.has_meta("_free_text_check") else false,
		"free_text_content": control.get_meta("_free_text_edit").text if control.has_meta("_free_text_edit") else "",
		"free_text_duration": 3.0,
	}


func get_export_options() -> Array:
	var def := GameContributions.ExportOptionDef.new()
	def.label = "Launcher (écrans de lancement)"
	def.key = "launcher"
	def.default_value = true
	return [def]
