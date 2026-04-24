extends "res://src/plugins/game_plugin.gd"

## Plugin Walkthrough : affiche la nature des choix (positif/équilibré/pénalisant)
## via un code d'activation saisi par le joueur dans les options.

const GameContributions = preload("res://src/plugins/game_contributions.gd")
const ChoiceScript = preload("res://src/models/choice.gd")

const WALKTHROUGH_PATH := "user://walkthrough.json"

var _plugin_settings: Dictionary = {}
var _validated_code: String = ""
var _enabled: bool = false


func get_plugin_name() -> String:
	return "walkthrough"


func get_plugin_description() -> String:
	return "Guide de choix (Walkthrough)"


func is_configurable() -> bool:
	return false


func get_plugin_folder() -> String:
	return "walkthrough"


# --- Lifecycle ---

func on_game_ready(ctx: RefCounted) -> void:
	_load_plugin_settings(ctx)
	_load_and_revalidate()


func on_game_cleanup(_ctx: RefCounted) -> void:
	pass


# --- Hook : styliser les boutons de choix ---

func on_style_choice_button(_ctx: RefCounted, btn: Button, choice: RefCounted, _index: int) -> void:
	if not _enabled or not _is_unlocked():
		return
	if not choice.has_method("to_dict"):
		return
	var nature: String = choice.get("nature") if choice.get("nature") != null else ""
	if nature == "":
		return
	var color := _get_nature_color(nature)
	if color == Color.TRANSPARENT:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("normal", style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(color.r, color.g, color.b, minf(color.a + 0.15, 1.0))
	hover_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("hover", hover_style)
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(color.r, color.g, color.b, minf(color.a + 0.25, 1.0))
	pressed_style.set_corner_radius_all(4)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	# Focus : même couleur que hover pour ne pas écraser la couleur walkthrough
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(color.r, color.g, color.b, minf(color.a + 0.15, 1.0))
	focus_style.set_corner_radius_all(4)
	focus_style.border_width_left = 2
	focus_style.border_width_right = 2
	focus_style.border_width_top = 2
	focus_style.border_width_bottom = 2
	focus_style.border_color = Color(color.r, color.g, color.b, 0.8)
	btn.add_theme_stylebox_override("focus", focus_style)


# --- Options in-game ---

func get_options_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_options_control
	return [def]


# --- Configuration éditeur ---

func get_editor_config_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_editor_config
	return [def]


func read_editor_config(ctrl: Control) -> Dictionary:
	if ctrl == null or not ctrl.has_meta("read_config"):
		return {}
	return ctrl.get_meta("read_config").call()


# --- Export options ---

func get_export_options() -> Array:
	var def := GameContributions.ExportOptionDef.new()
	def.label = "Inclure le walkthrough (guide de choix)"
	def.key = "walkthrough_enabled"
	def.default_value = true
	return [def]


# ── Logique interne ──────────────────────────────────────────────────────────

func _load_plugin_settings(ctx: RefCounted) -> void:
	if ctx.story == null:
		_plugin_settings = {}
		return
	_plugin_settings = ctx.story.plugin_settings.get("walkthrough", {})


func _get_activation_code() -> String:
	return _plugin_settings.get("activation_code", "")


func _is_code_valid(code: String) -> bool:
	var expected := _get_activation_code()
	return expected != "" and code == expected


func _is_unlocked() -> bool:
	# Débloqué si un code valide a été saisi
	if _validated_code != "":
		return true
	# Débloqué si embarqué dans un export standalone
	# (On détecte l'export par la présence du story_path dans les settings)
	if ProjectSettings.has_setting("application/config/story_path"):
		return true
	return false


func _get_nature_color(nature: String) -> Color:
	match nature:
		"positive":
			return Color(0.2, 1.0, 0.2, 0.25)
		"balanced":
			return Color(1.0, 0.9, 0.2, 0.25)
		"negative":
			return Color(1.0, 0.2, 0.2, 0.25)
	return Color.TRANSPARENT


# ── Persistance données joueur ────────────────────────────────────────────────

func _load_and_revalidate() -> void:
	if not FileAccess.file_exists(WALKTHROUGH_PATH):
		_validated_code = ""
		_enabled = false
		return
	var file := FileAccess.open(WALKTHROUGH_PATH, FileAccess.READ)
	if file == null:
		_validated_code = ""
		_enabled = false
		return
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if not parsed is Dictionary:
		_validated_code = ""
		_enabled = false
		_save_player_data()
		return
	var saved_code: String = parsed.get("validated_code", "")
	var saved_enabled: bool = parsed.get("enabled", false)
	# Re-valider le code contre la config actuelle
	if saved_code != "" and not _is_code_valid(saved_code):
		_validated_code = ""
		_enabled = false
		_save_player_data()
		return
	_validated_code = saved_code
	_enabled = saved_enabled and _is_unlocked()


func _save_player_data() -> void:
	var file := FileAccess.open(WALKTHROUGH_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({
		"validated_code": _validated_code,
		"enabled": _enabled,
	}, "\t"))
	file.close()


# ── Contrôle des options in-game ─────────────────────────────────────────────

func _create_options_control(_settings: RefCounted) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title_label := Label.new()
	title_label.text = "Walkthrough (guide de choix)"
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	var is_standalone := ProjectSettings.has_setting("application/config/story_path")

	# Checkbox activation
	var check_hbox := HBoxContainer.new()
	vbox.add_child(check_hbox)
	var check_label := Label.new()
	check_label.text = "Activer le walkthrough :"
	check_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check_hbox.add_child(check_label)
	var check_btn := CheckButton.new()
	check_btn.button_pressed = _enabled
	check_btn.disabled = not _is_unlocked()
	check_hbox.add_child(check_btn)

	# Statut du code
	var status_label := Label.new()
	if is_standalone:
		status_label.text = "Inclus dans le jeu (gratuit)"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	elif _validated_code != "":
		status_label.text = "Code actif"
		status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
	else:
		status_label.text = "Aucun code validé"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(status_label)

	# Saisie du code (masquée si standalone)
	var input_hbox := HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(input_hbox)
	var code_input := LineEdit.new()
	code_input.placeholder_text = "Entrez le code walkthrough..."
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_hbox.add_child(code_input)
	var validate_btn := Button.new()
	validate_btn.text = "Valider"
	input_hbox.add_child(validate_btn)

	# Label feedback
	var feedback_label := Label.new()
	feedback_label.text = ""
	feedback_label.visible = false
	vbox.add_child(feedback_label)

	# Bouton supprimer (visible seulement si code validé et pas standalone)
	var remove_btn := Button.new()
	remove_btn.text = "Supprimer le code"
	remove_btn.visible = _validated_code != "" and not is_standalone
	vbox.add_child(remove_btn)

	if is_standalone:
		input_hbox.visible = false
	
	# Logique toggle activation
	check_btn.toggled.connect(func(pressed: bool):
		_enabled = pressed
		_save_player_data()
	)

	# Logique validation code
	var on_validate := func():
		var code := code_input.text.strip_edges()
		if code == "":
			feedback_label.text = "Veuillez entrer un code."
			feedback_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			feedback_label.visible = true
			return
		if _is_code_valid(code):
			_validated_code = code
			_enabled = true
			_save_player_data()
			code_input.text = ""
			status_label.text = "Code actif"
			status_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			check_btn.button_pressed = true
			check_btn.disabled = false
			remove_btn.visible = true
			feedback_label.text = "Code validé !"
			feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
			feedback_label.visible = true
		else:
			feedback_label.text = "Code invalide."
			feedback_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
			feedback_label.visible = true

	validate_btn.pressed.connect(on_validate)
	code_input.text_submitted.connect(func(_t): on_validate.call())

	# Logique suppression code
	remove_btn.pressed.connect(func():
		_validated_code = ""
		_enabled = false
		_save_player_data()
		status_label.text = "Aucun code validé"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		check_btn.button_pressed = false
		check_btn.disabled = true
		remove_btn.visible = false
		feedback_label.text = "Code supprimé."
		feedback_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		feedback_label.visible = true
	)

	return vbox


# ── Configuration éditeur ────────────────────────────────────────────────────

func _create_editor_config(plugin_settings: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var title := Label.new()
	title.text = "Walkthrough — Configuration"
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	vbox.add_child(hbox)

	var lbl := Label.new()
	lbl.text = "Code d'activation :"
	hbox.add_child(lbl)

	var code_input := LineEdit.new()
	code_input.text = plugin_settings.get("activation_code", "")
	code_input.placeholder_text = "Ex: GUIDE2024"
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(code_input)

	var read_config := func() -> Dictionary:
		return {"activation_code": code_input.text.strip_edges()}
	vbox.set_meta("read_config", read_config)

	return vbox
