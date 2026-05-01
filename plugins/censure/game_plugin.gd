extends "res://src/plugins/game_plugin.gd"

## Plugin de censure : masque les mots interdits et affiche les foregrounds
## marqués comme censurés au-dessus du contenu.

const GameContributions = preload("res://src/plugins/game_contributions.gd")

const MODAL_Z := 4096

var _banned_words: Array[String] = [
	"merde", "putain", "connard", "salaud", "bordel",
	"enculé", "con", "pute", "foutre", "chier"
]
var _censored_this_dialogue: bool = false
var _bubble: PanelContainer = null
var _uncensored_popup: Control = null


func get_plugin_name() -> String:
	return "censure"


func get_plugin_description() -> String:
	return "Version censurée"


func is_configurable() -> bool:
	return false


func get_plugin_folder() -> String:
	return "censure"


func get_export_options() -> Array:
	var def := GameContributions.ExportOptionDef.new()
	def.label = "Inclure la censure"
	def.key = "censure_enabled"
	def.default_value = false
	return [def]


func on_game_ready(ctx: RefCounted) -> void:
	_enable_censored_foregrounds(ctx)


func on_before_sequence(ctx: RefCounted) -> void:
	_enable_censored_foregrounds(ctx)


func _enable_censored_foregrounds(ctx: RefCounted) -> void:
	if ctx == null or ctx.game_node == null:
		return
	var visual_editor = ctx.game_node.get("_visual_editor")
	if visual_editor != null:
		visual_editor.show_censored_foregrounds = true


func on_game_cleanup(_ctx: RefCounted) -> void:
	if _uncensored_popup != null and is_instance_valid(_uncensored_popup):
		_uncensored_popup.queue_free()
	_uncensored_popup = null
	_bubble = null


func on_before_dialogue(ctx: RefCounted, character: String, text: String) -> Dictionary:
	var censored_text := text
	var found := false
	for word in _banned_words:
		if _contains_ignore_case(censored_text, word):
			censored_text = _replace_ignore_case(censored_text, word, "*".repeat(word.length()))
			found = true
	_censored_this_dialogue = found or _has_censored_foregrounds(ctx)
	return {"character": character, "text": censored_text}


func on_after_dialogue(ctx: RefCounted, _character: String, _text: String) -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	if _censored_this_dialogue:
		_show_bubble(ctx)
	else:
		_bubble.visible = false


func get_overlay_panels() -> Array:
	var def := GameContributions.GameOverlayPanelDef.new()
	def.position = "left"
	def.create_panel = _create_bubble_panel
	return [def]


func _create_bubble_panel(ctx: RefCounted) -> Control:
	_bubble = PanelContainer.new()
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_STOP
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.8, 0.1, 0.1, 0.9)
	stylebox.set_corner_radius_all(8)
	stylebox.set_content_margin_all(8)
	_bubble.add_theme_stylebox_override("panel", stylebox)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_bubble.add_child(col)

	var label := Label.new()
	label.text = "Censuré"
	label.add_theme_color_override("font_color", Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)

	var link_btn := Button.new()
	link_btn.text = "Uncensored this ?"
	link_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	link_btn.add_theme_color_override("font_color", Color.WHITE)
	link_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	link_btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	link_btn.add_theme_color_override("font_focus_color", Color.WHITE)
	link_btn.add_theme_constant_override("h_separation", 0)

	var link_normal := StyleBoxFlat.new()
	link_normal.bg_color = Color(0.95, 0.45, 0.45, 0.95)
	link_normal.border_color = Color(0.6, 0.05, 0.05, 1.0)
	link_normal.set_border_width_all(2)
	link_normal.set_corner_radius_all(10)
	link_normal.set_content_margin_all(10)
	link_btn.add_theme_stylebox_override("normal", link_normal)

	var link_hover := link_normal.duplicate()
	link_hover.bg_color = Color(0.98, 0.55, 0.55, 1.0)
	link_btn.add_theme_stylebox_override("hover", link_hover)

	var link_pressed := link_normal.duplicate()
	link_pressed.bg_color = Color(0.88, 0.32, 0.32, 1.0)
	link_btn.add_theme_stylebox_override("pressed", link_pressed)

	var link_focus := link_normal.duplicate()
	link_focus.border_color = Color(1.0, 0.9, 0.9, 1.0)
	link_focus.set_border_width_all(3)
	link_btn.add_theme_stylebox_override("focus", link_focus)

	link_btn.pressed.connect(func(): _show_uncensored_popup(ctx))
	col.add_child(link_btn)

	return _bubble


func _show_bubble(_ctx: RefCounted) -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	_bubble.visible = true


func _show_uncensored_popup(ctx: RefCounted) -> void:
	if ctx == null or ctx.game_node == null:
		return
	if _uncensored_popup != null and is_instance_valid(_uncensored_popup):
		_uncensored_popup.queue_free()
		_uncensored_popup = null

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = MODAL_Z

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.96)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Version non censurée"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)

	var message := Label.new()
	message.text = _get_uncensored_message(ctx)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	vbox.add_child(message)

	var links := _get_external_links(ctx)
	if not links.is_empty():
		var links_row := HBoxContainer.new()
		links_row.alignment = BoxContainer.ALIGNMENT_CENTER
		links_row.add_theme_constant_override("separation", 8)
		vbox.add_child(links_row)
		if links.has("itchio"):
			var itch_btn := Button.new()
			itch_btn.text = "itch.io"
			itch_btn.pressed.connect(func(): _open_external_link(ctx, "itchio", links["itchio"]))
			links_row.add_child(itch_btn)
		if links.has("patreon"):
			var patreon_btn := Button.new()
			patreon_btn.text = "Patreon"
			patreon_btn.pressed.connect(func(): _open_external_link(ctx, "patreon", links["patreon"]))
			links_row.add_child(patreon_btn)

	var close_btn := Button.new()
	close_btn.text = "Fermer"
	close_btn.pressed.connect(func():
		if overlay != null and is_instance_valid(overlay):
			overlay.queue_free()
		_uncensored_popup = null
	)
	vbox.add_child(close_btn)

	overlay.tree_exited.connect(func():
		if _uncensored_popup == overlay:
			_uncensored_popup = null
	)

	ctx.game_node.add_child(overlay)
	overlay.move_to_front()
	_uncensored_popup = overlay


func _open_external_link(ctx: RefCounted, link_type: String, url: String) -> void:
	if url == "":
		return
	OS.shell_open(url)
	if ctx != null and ctx.emit_game_event.is_valid():
		ctx.emit_game_event.call("external_link_opened", {
			"link_type": link_type,
			"context": "censure_popup",
		})


func _get_uncensored_message(ctx: RefCounted) -> String:
	var links := _get_external_links(ctx)
	if links.has("itchio") and links.has("patreon"):
		return "Rendez-vous sur itch.io ou Patreon pour obtenir la version non censurée."
	if links.has("itchio"):
		return "Rendez-vous sur itch.io pour obtenir la version non censurée."
	if links.has("patreon"):
		return "Rendez-vous sur Patreon pour obtenir la version non censurée."
	return "Aucun lien n'est configuré pour obtenir la version non censurée."


func _get_external_links(ctx: RefCounted) -> Dictionary:
	var links := {}
	if ctx == null or ctx.story == null:
		return links
	var story = ctx.story
	if story.get("itchio_url") != null and story.itchio_url != "":
		links["itchio"] = story.itchio_url
	if story.get("patreon_url") != null and story.patreon_url != "":
		links["patreon"] = story.patreon_url
	return links


func _has_censored_foregrounds(ctx: RefCounted) -> bool:
	if ctx == null or ctx.current_sequence == null:
		return false
	var fgs := _get_effective_foregrounds(ctx.current_sequence, ctx.current_dialogue_index)
	for fg in fgs:
		if fg.censored:
			return true
	return false


func _get_effective_foregrounds(sequence, dialogue_index: int) -> Array:
	if sequence == null:
		return []
	if dialogue_index < 0 or dialogue_index >= sequence.dialogues.size():
		return sequence.foregrounds
	var dlg = sequence.dialogues[dialogue_index]
	if dlg.foregrounds.size() > 0:
		return dlg.foregrounds
	for i in range(dialogue_index - 1, -1, -1):
		if sequence.dialogues[i].foregrounds.size() > 0:
			return sequence.dialogues[i].foregrounds
	return sequence.foregrounds


## Vérifie si le caractère à l'index donné est une lettre ou un chiffre.
static func _is_word_char(text: String, index: int) -> bool:
	if index < 0 or index >= text.length():
		return false
	var c := text.unicode_at(index)
	if c >= 65 and c <= 90:
		return true
	if c >= 97 and c <= 122:
		return true
	if c >= 48 and c <= 57:
		return true
	if (c >= 0xC0 and c <= 0xD6) or (c >= 0xD8 and c <= 0xF6) or (c >= 0xF8 and c <= 0x024F):
		return true
	return false


## Vérifie si text contient word comme mot entier (insensible à la casse).
static func _contains_ignore_case(text: String, word: String) -> bool:
	var lower := text.to_lower()
	var lower_word := word.to_lower()
	var pos := lower.find(lower_word)
	while pos >= 0:
		if not _is_word_char(text, pos - 1) and not _is_word_char(text, pos + word.length()):
			return true
		pos = lower.find(lower_word, pos + 1)
	return false


## Remplace toutes les occurrences du mot entier word dans text (insensible à la casse).
static func _replace_ignore_case(text: String, word: String, replacement: String) -> String:
	var result := text
	var lower := result.to_lower()
	var lower_word := word.to_lower()
	var pos := lower.find(lower_word)
	while pos >= 0:
		if not _is_word_char(result, pos - 1) and not _is_word_char(result, pos + word.length()):
			result = result.substr(0, pos) + replacement + result.substr(pos + word.length())
			lower = result.to_lower()
			pos = lower.find(lower_word, pos + replacement.length())
		else:
			pos = lower.find(lower_word, pos + 1)
	return result
