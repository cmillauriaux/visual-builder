extends "res://src/plugins/game_plugin.gd"

## Plugin Premium Code : bloque la progression du joueur sur certains chapitres
## s'il ne possède pas un code d'accès valide.

const GameContributions = preload("res://src/plugins/game_contributions.gd")

const CODES_PATH := "user://codes.json"

var _plugin_settings: Dictionary = {}
var _validated_codes: Array = []
var _popup: Control = null
var _story_ref = null


func get_plugin_name() -> String:
	return "premium_code"


func get_plugin_description() -> String:
	return "Vérification de code premium"


func is_configurable() -> bool:
	return false


func get_plugin_folder() -> String:
	return "premium_code"


# --- Lifecycle ---

func on_game_ready(ctx: RefCounted) -> void:
	_load_validated_codes()
	_load_plugin_settings(ctx)
	_story_ref = ctx.story


func on_game_cleanup(_ctx: RefCounted) -> void:
	_popup = null
	_story_ref = null


# --- Hook : bloquer l'accès aux chapitres protégés ---

func on_before_chapter(ctx: RefCounted) -> void:
	if ctx.current_chapter == null or ctx.story == null:
		return

	_load_plugin_settings(ctx)
	_load_validated_codes()

	var chapter_uuid: String = ctx.current_chapter.uuid
	var required_codes := _get_required_codes_for_chapter(chapter_uuid, ctx.story)

	if required_codes.is_empty():
		return

	# Vérifier si le joueur possède au moins un code valide
	for code_entry in required_codes:
		if _validated_codes.has(code_entry["code"]):
			return

	# Pas de code valide → afficher le popup de blocage
	_show_code_popup(ctx)


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
	def.label = "Version limitée (vérification de code)"
	def.key = "premium_code_enabled"
	def.default_value = true
	return [def]


# ── Logique interne ──────────────────────────────────────────────────────────

func _load_plugin_settings(ctx: RefCounted) -> void:
	if ctx.story == null:
		_plugin_settings = {}
		return
	_plugin_settings = ctx.story.plugin_settings.get("premium_code", {})


func _get_codes_config() -> Array:
	return _plugin_settings.get("codes", [])


func _get_purchase_message() -> String:
	return _plugin_settings.get("purchase_message",
		"Procurez-vous le jeu complet pour débloquer ce contenu !")


func _get_purchase_url() -> String:
	var url: String = _plugin_settings.get("purchase_url", "")
	if url != "":
		return url
	if _story_ref != null:
		if _story_ref.get("itchio_url") != null and _story_ref.itchio_url != "":
			return _story_ref.itchio_url
		if _story_ref.get("patreon_url") != null and _story_ref.patreon_url != "":
			return _story_ref.patreon_url
	return ""


## Retourne la liste des codes requis pour accéder à un chapitre donné.
func _get_required_codes_for_chapter(chapter_uuid: String, story) -> Array:
	var codes_config := _get_codes_config()
	if codes_config.is_empty():
		return []

	var chapter_indices := {}
	for i in range(story.chapters.size()):
		chapter_indices[story.chapters[i].uuid] = i

	var chapter_index: int = chapter_indices.get(chapter_uuid, -1)
	if chapter_index < 0:
		return []

	var matching_codes: Array = []
	for entry in codes_config:
		var from_uuid: String = entry.get("from_chapter_uuid", "")
		var to_uuid: String = entry.get("to_chapter_uuid", "")
		var from_idx: int = chapter_indices.get(from_uuid, -1)
		var to_idx: int = chapter_indices.get(to_uuid, -1)
		if from_idx < 0 or to_idx < 0:
			continue
		if chapter_index >= from_idx and chapter_index <= to_idx:
			matching_codes.append(entry)

	return matching_codes


## Vérifie si un code est valide (présent dans la config).
func _is_code_valid(code: String) -> bool:
	for entry in _get_codes_config():
		if entry.get("code", "") == code:
			return true
	return false


# ── Persistance des codes joueur ─────────────────────────────────────────────

func _load_validated_codes() -> void:
	if not FileAccess.file_exists(CODES_PATH):
		_validated_codes = []
		return
	var file := FileAccess.open(CODES_PATH, FileAccess.READ)
	if file == null:
		_validated_codes = []
		return
	var content := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(content)
	if parsed is Dictionary and parsed.has("validated_codes"):
		_validated_codes = parsed["validated_codes"]
	else:
		_validated_codes = []


func _save_validated_codes() -> void:
	var file := FileAccess.open(CODES_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"validated_codes": _validated_codes}, "\t"))
	file.close()


func _add_validated_code(code: String) -> void:
	if not _validated_codes.has(code):
		_validated_codes.append(code)
		_save_validated_codes()


func _remove_validated_code(code: String) -> void:
	_validated_codes.erase(code)
	_save_validated_codes()


# ── Popup de blocage ─────────────────────────────────────────────────────────

func _show_code_popup(ctx: RefCounted) -> void:
	if ctx.game_node == null:
		return

	# Supprimer un popup précédent s'il existe
	if _popup != null and is_instance_valid(_popup):
		_popup.queue_free()

	# Overlay sombre plein écran
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 4096  # UI_OVERLAY_Z — au-dessus de tout le contenu de jeu

	# Panneau central
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Message
	var msg_label := Label.new()
	msg_label.text = _get_purchase_message()
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(msg_label)

	# Champ de saisie
	var input_hbox := HBoxContainer.new()
	input_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(input_hbox)

	var code_input := LineEdit.new()
	code_input.placeholder_text = "Entrez votre code..."
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_hbox.add_child(code_input)

	var validate_btn := Button.new()
	validate_btn.text = "Valider"
	input_hbox.add_child(validate_btn)

	# Label d'erreur
	var error_label := Label.new()
	error_label.text = ""
	error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.visible = false
	vbox.add_child(error_label)

	# Lien d'achat
	var purchase_url := _get_purchase_url()
	if purchase_url != "":
		var link_btn := Button.new()
		link_btn.text = "Obtenir le jeu complet"
		link_btn.pressed.connect(func():
			OS.shell_open(purchase_url)
			if ctx.emit_game_event.is_valid():
				ctx.emit_game_event.call("premium_code_purchase_link", {"url": purchase_url})
				ctx.emit_game_event.call("external_link_opened", {"link_type": "itchio", "context": "premium_code"})
		)
		vbox.add_child(link_btn)

	# Bouton retour
	var back_btn := Button.new()
	back_btn.text = "Retour au menu"
	back_btn.pressed.connect(func():
		overlay.get_tree().paused = false
		overlay.queue_free()
		_popup = null
		if ctx.game_node != null and ctx.game_node.has_method("_on_return_to_menu"):
			ctx.game_node._on_return_to_menu()
	)
	vbox.add_child(back_btn)

	# Logique de validation
	var chapter_uuid: String = ctx.current_chapter.uuid if ctx.current_chapter else ""
	var on_validate := func():
		var code := code_input.text.strip_edges()
		if code == "":
			error_label.text = "Veuillez entrer un code."
			error_label.visible = true
			return
		if _is_code_valid(code):
			_add_validated_code(code)
			if ctx.emit_game_event.is_valid():
				ctx.emit_game_event.call("premium_code_attempt", {"success": true, "chapter_uuid": chapter_uuid})
			overlay.get_tree().paused = false
			overlay.queue_free()
			_popup = null
		else:
			error_label.text = "Code invalide."
			error_label.visible = true
			if ctx.emit_game_event.is_valid():
				ctx.emit_game_event.call("premium_code_attempt", {"success": false, "chapter_uuid": chapter_uuid})

	validate_btn.pressed.connect(on_validate)
	code_input.text_submitted.connect(func(_t): on_validate.call())

	# L'overlay continue de fonctionner même quand le jeu est en pause
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	ctx.game_node.add_child(overlay)
	overlay.move_to_front()
	_popup = overlay

	# Figer le jeu tant que le popup est actif
	overlay.get_tree().paused = true

	code_input.grab_focus()


# ── Contrôle des options in-game ─────────────────────────────────────────────

func _create_options_control(settings: RefCounted) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var title_label := Label.new()
	title_label.text = "Codes premium"
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	var codes_container := VBoxContainer.new()
	codes_container.name = "CodesContainer"
	vbox.add_child(codes_container)

	# Champ d'ajout
	var add_hbox := HBoxContainer.new()
	add_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(add_hbox)

	var new_code_input := LineEdit.new()
	new_code_input.placeholder_text = "Entrez un code..."
	new_code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_hbox.add_child(new_code_input)

	var feedback_label := Label.new()
	feedback_label.text = ""
	feedback_label.visible = false
	vbox.add_child(feedback_label)

	var add_btn := Button.new()
	add_btn.text = "+"
	add_hbox.add_child(add_btn)

	var refresh_list: Callable
	refresh_list = func():
		for child in codes_container.get_children():
			child.queue_free()
		for code in _validated_codes:
			var hbox := HBoxContainer.new()
			var lbl := Label.new()
			lbl.text = str(code)
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(lbl)
			var del_btn := Button.new()
			del_btn.text = "Supprimer"
			var c: String = str(code)
			del_btn.pressed.connect(func():
				_remove_validated_code(c)
				refresh_list.call()
			)
			hbox.add_child(del_btn)
			codes_container.add_child(hbox)

	var on_add := func():
		var code := new_code_input.text.strip_edges()
		if code == "":
			return
		if _is_code_valid(code):
			_add_validated_code(code)
			new_code_input.text = ""
			feedback_label.text = "Code ajouté !"
			feedback_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
			feedback_label.visible = true
			refresh_list.call()
		else:
			feedback_label.text = "Code invalide."
			feedback_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			feedback_label.visible = true

	add_btn.pressed.connect(on_add)
	new_code_input.text_submitted.connect(func(_t): on_add.call())

	_load_validated_codes()
	refresh_list.call()

	return vbox


# ── Configuration éditeur ────────────────────────────────────────────────────

func _create_editor_config(plugin_settings: Dictionary) -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)

	var codes: Array = plugin_settings.get("codes", [])

	# Message d'achat
	var msg_hbox := HBoxContainer.new()
	msg_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(msg_hbox)

	var msg_label := Label.new()
	msg_label.text = "Message d'achat :"
	msg_hbox.add_child(msg_label)

	var msg_input := LineEdit.new()
	msg_input.name = "PurchaseMessage"
	msg_input.text = plugin_settings.get("purchase_message",
		"Procurez-vous le jeu complet pour débloquer ce contenu !")
	msg_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg_hbox.add_child(msg_input)

	# URL d'achat
	var url_hbox := HBoxContainer.new()
	url_hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(url_hbox)

	var url_label := Label.new()
	url_label.text = "URL d'achat (optionnel) :"
	url_hbox.add_child(url_label)

	var url_input := LineEdit.new()
	url_input.name = "PurchaseUrl"
	url_input.text = plugin_settings.get("purchase_url", "")
	url_input.placeholder_text = "Laisser vide pour utiliser les liens itch.io/Patreon de la story"
	url_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	url_hbox.add_child(url_input)

	# Titre section codes
	var codes_title := Label.new()
	codes_title.text = "Codes d'accès :"
	vbox.add_child(codes_title)

	# Container pour les lignes de codes
	var codes_container := VBoxContainer.new()
	codes_container.name = "CodesContainer"
	vbox.add_child(codes_container)

	# Bouton ajouter
	var add_btn := Button.new()
	add_btn.text = "+ Ajouter un code"
	vbox.add_child(add_btn)

	# Stocker la callable read_config dans un meta pour read_editor_config
	var read_config := func() -> Dictionary:
		var result: Dictionary = {}
		result["purchase_message"] = msg_input.text
		result["purchase_url"] = url_input.text
		var codes_arr: Array = []
		for child in codes_container.get_children():
			if child.has_meta("get_code_data"):
				codes_arr.append(child.get_meta("get_code_data").call())
		result["codes"] = codes_arr
		return result
	vbox.set_meta("read_config", read_config)

	# Fonction pour ajouter une ligne de code
	var add_code_row: Callable
	add_code_row = func(code_data: Dictionary):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var code_edit := LineEdit.new()
		code_edit.placeholder_text = "Code"
		code_edit.text = code_data.get("code", "")
		code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(code_edit)

		var from_label := Label.new()
		from_label.text = "Du chapitre"
		row.add_child(from_label)

		var from_dropdown := OptionButton.new()
		from_dropdown.name = "FromChapter"
		row.add_child(from_dropdown)

		var to_label := Label.new()
		to_label.text = "au chapitre"
		row.add_child(to_label)

		var to_dropdown := OptionButton.new()
		to_dropdown.name = "ToChapter"
		row.add_child(to_dropdown)

		var del_btn := Button.new()
		del_btn.text = "×"
		del_btn.pressed.connect(func(): row.queue_free())
		row.add_child(del_btn)

		# Stocker les données pour read_config
		row.set_meta("get_code_data", func() -> Dictionary:
			var from_uuid := ""
			var to_uuid := ""
			if from_dropdown.selected >= 0 and from_dropdown.has_meta("uuids"):
				var uuids: Array = from_dropdown.get_meta("uuids")
				if from_dropdown.selected < uuids.size():
					from_uuid = uuids[from_dropdown.selected]
			if to_dropdown.selected >= 0 and to_dropdown.has_meta("uuids"):
				var uuids: Array = to_dropdown.get_meta("uuids")
				if to_dropdown.selected < uuids.size():
					to_uuid = uuids[to_dropdown.selected]
			return {
				"code": code_edit.text,
				"from_chapter_uuid": from_uuid,
				"to_chapter_uuid": to_uuid,
			}
		)

		# Stocker les metadata pour le peuplement des dropdowns
		row.set_meta("from_chapter_uuid", code_data.get("from_chapter_uuid", ""))
		row.set_meta("to_chapter_uuid", code_data.get("to_chapter_uuid", ""))

		codes_container.add_child(row)

	# Ajouter les lignes existantes
	for code_data in codes:
		add_code_row.call(code_data)

	# Fonction pour peupler les dropdowns d'une seule ligne
	var populate_row := func(row: HBoxContainer, chapters: Array):
		var from_dd: OptionButton = row.get_node_or_null("FromChapter")
		var to_dd: OptionButton = row.get_node_or_null("ToChapter")
		if from_dd == null or to_dd == null:
			return
		from_dd.clear()
		to_dd.clear()
		var uuids: Array = []
		for ch in chapters:
			from_dd.add_item(ch.chapter_name if ch.chapter_name != "" else ch.uuid)
			to_dd.add_item(ch.chapter_name if ch.chapter_name != "" else ch.uuid)
			uuids.append(ch.uuid)
		from_dd.set_meta("uuids", uuids)
		to_dd.set_meta("uuids", uuids)
		# Sélectionner les valeurs sauvegardées
		var from_uuid: String = row.get_meta("from_chapter_uuid") if row.has_meta("from_chapter_uuid") else ""
		var to_uuid: String = row.get_meta("to_chapter_uuid") if row.has_meta("to_chapter_uuid") else ""
		for i in range(uuids.size()):
			if uuids[i] == from_uuid:
				from_dd.selected = i
			if uuids[i] == to_uuid:
				to_dd.selected = i

	add_btn.pressed.connect(func():
		add_code_row.call({})
		if vbox.has_meta("_chapters_cache"):
			var last_row = codes_container.get_child(codes_container.get_child_count() - 1)
			populate_row.call(last_row, vbox.get_meta("_chapters_cache"))
	)

	# Stocker une callback pour peupler les dropdowns quand la story est disponible
	vbox.set_meta("populate_chapters", func(chapters: Array):
		vbox.set_meta("_chapters_cache", chapters)
		for row in codes_container.get_children():
			populate_row.call(row, chapters)
	)

	return vbox
