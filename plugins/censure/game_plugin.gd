extends "res://src/plugins/game_plugin.gd"

## Plugin de censure : remplace les mots inappropriés par des étoiles.
## Affiche une bulle rouge temporaire quand une censure est appliquée.

const GameContributions = preload("res://src/plugins/game_contributions.gd")

var _enabled: bool = true
var _banned_words: Array[String] = [
	"merde", "putain", "connard", "salaud", "bordel",
	"enculé", "con", "pute", "foutre", "chier"
]
var _censored_this_dialogue: bool = false
var _bubble: PanelContainer = null
var _bubble_timer_gen: int = 0


func get_plugin_name() -> String:
	return "censure"


func get_plugin_description() -> String:
	return "Remplace les mots inappropriés par *****"


## Toujours chargé mais gère son propre toggle interne via les options.
func is_configurable() -> bool:
	return false


func on_before_dialogue(ctx: RefCounted, character: String, text: String) -> Dictionary:
	if not _enabled:
		_censored_this_dialogue = false
		return {"character": character, "text": text}
	var censored_text := text
	var found := false
	for word in _banned_words:
		if _contains_ignore_case(censored_text, word):
			censored_text = _replace_ignore_case(censored_text, word, "*".repeat(word.length()))
			found = true
	_censored_this_dialogue = found
	return {"character": character, "text": censored_text}


func on_after_dialogue(ctx: RefCounted, _character: String, _text: String) -> void:
	if _censored_this_dialogue and _bubble != null:
		_show_bubble(ctx)


func get_overlay_panels() -> Array:
	var def := GameContributions.GameOverlayPanelDef.new()
	def.position = "top"
	def.create_panel = _create_bubble_panel
	return [def]


func get_options_controls() -> Array:
	var def := GameContributions.GameOptionsControlDef.new()
	def.create_control = _create_options_control
	return [def]


# --- Interne ---

func _create_bubble_panel(_ctx: RefCounted) -> Control:
	_bubble = PanelContainer.new()
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.8, 0.1, 0.1, 0.9)
	stylebox.set_corner_radius_all(8)
	stylebox.set_content_margin_all(6)
	_bubble.add_theme_stylebox_override("panel", stylebox)
	var label := Label.new()
	label.text = "Censuré"
	label.add_theme_color_override("font_color", Color.WHITE)
	_bubble.add_child(label)
	return _bubble


func _create_options_control(_settings: RefCounted) -> Control:
	var hbox := HBoxContainer.new()
	var label := Label.new()
	label.text = "Censure activée"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(label)
	var check := CheckButton.new()
	check.button_pressed = _enabled
	check.toggled.connect(func(v: bool): _enabled = v)
	hbox.add_child(check)
	return hbox


func _show_bubble(ctx: RefCounted) -> void:
	if _bubble == null or not is_instance_valid(_bubble):
		return
	_bubble.visible = true
	_bubble_timer_gen += 1
	var gen := _bubble_timer_gen
	if ctx != null and ctx.game_node != null:
		ctx.game_node.get_tree().create_timer(3.0).timeout.connect(func():
			if _bubble != null and is_instance_valid(_bubble) and gen == _bubble_timer_gen:
				_bubble.visible = false
		)


## Vérifie si text contient word (insensible à la casse).
static func _contains_ignore_case(text: String, word: String) -> bool:
	return text.to_lower().contains(word.to_lower())


## Remplace toutes les occurrences de word dans text (insensible à la casse).
static func _replace_ignore_case(text: String, word: String, replacement: String) -> String:
	var result := text
	var lower := result.to_lower()
	var lower_word := word.to_lower()
	var pos := lower.find(lower_word)
	while pos >= 0:
		result = result.substr(0, pos) + replacement + result.substr(pos + word.length())
		lower = result.to_lower()
		pos = lower.find(lower_word, pos + replacement.length())
	return result
