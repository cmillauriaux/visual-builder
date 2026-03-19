extends VBoxContainer

## Panel UI pour configurer la musique et les FX audio d'une séquence dans l'éditeur.

const AudioPickerDialogScript = preload("res://src/ui/dialogs/audio_picker_dialog.gd")

signal audio_changed

var _sequence = null
var _story_base_path: String = ""

# UI — Musique
var _music_label: Label
var _music_clear_btn: Button
var _stop_music_check: CheckBox

# UI — FX
var _fx_label: Label
var _fx_clear_btn: Button

# Référence au nœud parent pour ouvrir les dialogs
var _dialog_parent: Node = null


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	add_theme_constant_override("separation", 12)

	# --- Section Musique ---
	var music_title = Label.new()
	music_title.text = tr("Musique")
	music_title.add_theme_font_size_override("font_size", 14)
	add_child(music_title)

	var music_row = HBoxContainer.new()
	music_row.add_theme_constant_override("separation", 6)
	add_child(music_row)

	_music_label = Label.new()
	_music_label.text = tr("Aucune musique")
	_music_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_label.clip_text = true
	_music_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	music_row.add_child(_music_label)

	var music_pick_btn = Button.new()
	music_pick_btn.text = tr("Choisir...")
	music_pick_btn.pressed.connect(_on_music_pick)
	music_row.add_child(music_pick_btn)

	_music_clear_btn = Button.new()
	_music_clear_btn.text = "✕"
	_music_clear_btn.disabled = true
	_music_clear_btn.pressed.connect(_on_music_clear)
	music_row.add_child(_music_clear_btn)

	_stop_music_check = CheckBox.new()
	_stop_music_check.text = tr("Arrêter la musique")
	_stop_music_check.toggled.connect(_on_stop_music_toggled)
	add_child(_stop_music_check)

	add_child(HSeparator.new())

	# --- Section FX Audio ---
	var fx_title = Label.new()
	fx_title.text = tr("FX Audio")
	fx_title.add_theme_font_size_override("font_size", 14)
	add_child(fx_title)

	var fx_info = Label.new()
	fx_info.text = tr("Joué une fois à l'apparition de la séquence")
	fx_info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	fx_info.add_theme_font_size_override("font_size", 11)
	add_child(fx_info)

	var fx_row = HBoxContainer.new()
	fx_row.add_theme_constant_override("separation", 6)
	add_child(fx_row)

	_fx_label = Label.new()
	_fx_label.text = tr("Aucun FX")
	_fx_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fx_label.clip_text = true
	_fx_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	fx_row.add_child(_fx_label)

	var fx_pick_btn = Button.new()
	fx_pick_btn.text = tr("Choisir...")
	fx_pick_btn.pressed.connect(_on_fx_pick)
	fx_row.add_child(fx_pick_btn)

	_fx_clear_btn = Button.new()
	_fx_clear_btn.text = "✕"
	_fx_clear_btn.disabled = true
	_fx_clear_btn.pressed.connect(_on_fx_clear)
	fx_row.add_child(_fx_clear_btn)


func load_sequence(seq) -> void:
	_sequence = seq
	_refresh_ui()


func setup_story_path(base_path: String, dialog_parent: Node) -> void:
	_story_base_path = base_path
	_dialog_parent = dialog_parent


func clear() -> void:
	_sequence = null
	_refresh_ui()


func _refresh_ui() -> void:
	if _sequence == null:
		_music_label.text = tr("Aucune musique")
		_music_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_music_clear_btn.disabled = true
		_stop_music_check.button_pressed = false
		_fx_label.text = tr("Aucun FX")
		_fx_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_fx_clear_btn.disabled = true
		return

	# Music
	if _sequence.music != "":
		_music_label.text = _sequence.music.get_file()
		_music_label.add_theme_color_override("font_color", Color.WHITE)
		_music_clear_btn.disabled = false
	else:
		_music_label.text = tr("Aucune musique")
		_music_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_music_clear_btn.disabled = true

	_stop_music_check.set_block_signals(true)
	_stop_music_check.button_pressed = _sequence.stop_music
	_stop_music_check.set_block_signals(false)

	# FX
	if _sequence.audio_fx != "":
		_fx_label.text = _sequence.audio_fx.get_file()
		_fx_label.add_theme_color_override("font_color", Color.WHITE)
		_fx_clear_btn.disabled = false
	else:
		_fx_label.text = tr("Aucun FX")
		_fx_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_fx_clear_btn.disabled = true


func _on_music_pick() -> void:
	var parent = _dialog_parent if _dialog_parent else get_tree().root
	var picker = Window.new()
	picker.set_script(AudioPickerDialogScript)
	parent.add_child(picker)
	picker.setup(AudioPickerDialogScript.Mode.MUSIC, _story_base_path)
	picker.audio_selected.connect(_on_music_selected)
	picker.popup_centered()


func _on_music_selected(path: String) -> void:
	if _sequence == null:
		return
	_sequence.music = path
	_refresh_ui()
	audio_changed.emit()


func _on_music_clear() -> void:
	if _sequence == null:
		return
	_sequence.music = ""
	_refresh_ui()
	audio_changed.emit()


func _on_stop_music_toggled(pressed: bool) -> void:
	if _sequence == null:
		return
	_sequence.stop_music = pressed
	audio_changed.emit()


func _on_fx_pick() -> void:
	var parent = _dialog_parent if _dialog_parent else get_tree().root
	var picker = Window.new()
	picker.set_script(AudioPickerDialogScript)
	parent.add_child(picker)
	picker.setup(AudioPickerDialogScript.Mode.FX, _story_base_path)
	picker.audio_selected.connect(_on_fx_selected)
	picker.popup_centered()


func _on_fx_selected(path: String) -> void:
	if _sequence == null:
		return
	_sequence.audio_fx = path
	_refresh_ui()
	audio_changed.emit()


func _on_fx_clear() -> void:
	if _sequence == null:
		return
	_sequence.audio_fx = ""
	_refresh_ui()
	audio_changed.emit()
