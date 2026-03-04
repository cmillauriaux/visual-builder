extends Control

## Contrôleur principal de l'éditeur de séquence.
## Gère : sélection dialogue, héritage foregrounds, mode Play, CRUD.

const DialogueScript = preload("res://src/models/dialogue.gd")
const ForegroundScript = preload("res://src/models/foreground.gd")

var _sequence = null
var _selected_dialogue_index: int = -1

# --- Mode Play ---
var _playing: bool = false
var _play_index: int = -1
var _visible_characters: int = 0
var _text_fully_displayed: bool = false

# --- Signaux ---
signal dialogue_selected(index: int)
signal play_dialogue_changed(index: int)
signal play_stopped()

# --- Chargement ---

func load_sequence(sequence) -> void:
	_sequence = sequence
	_selected_dialogue_index = -1
	_playing = false
	_play_index = -1

func get_sequence():
	return _sequence

# --- Sélection ---

func get_selected_dialogue_index() -> int:
	return _selected_dialogue_index

func select_dialogue(index: int) -> void:
	if _sequence == null:
		_selected_dialogue_index = -1
		return
	if index < 0 or index >= _sequence.dialogues.size():
		_selected_dialogue_index = -1
		return
	_selected_dialogue_index = index
	dialogue_selected.emit(index)

# --- Héritage foregrounds ---

func get_effective_foregrounds(dialogue_index: int) -> Array:
	if _sequence == null:
		return []
	if dialogue_index < 0 or dialogue_index >= _sequence.dialogues.size():
		return []
	var dlg = _sequence.dialogues[dialogue_index]
	if dlg.foregrounds.size() > 0:
		return dlg.foregrounds
	# Chercher le dialogue précédent le plus proche avec des foregrounds
	for i in range(dialogue_index - 1, -1, -1):
		if _sequence.dialogues[i].foregrounds.size() > 0:
			return _sequence.dialogues[i].foregrounds
	return []

func ensure_own_foregrounds(dialogue_index: int) -> void:
	if _sequence == null:
		return
	if dialogue_index < 0 or dialogue_index >= _sequence.dialogues.size():
		return
	var dlg = _sequence.dialogues[dialogue_index]
	if dlg.foregrounds.size() > 0:
		return  # Déjà ses propres foregrounds
	var inherited = get_effective_foregrounds(dialogue_index)
	if inherited.size() == 0:
		return  # Rien à copier
	# Copie complète
	for fg in inherited:
		var copy = _copy_foreground(fg)
		dlg.foregrounds.append(copy)

func _copy_foreground(fg):
	var copy = ForegroundScript.new()
	copy.fg_name = fg.fg_name
	copy.image = fg.image
	copy.z_order = fg.z_order
	copy.opacity = fg.opacity
	copy.flip_h = fg.flip_h
	copy.flip_v = fg.flip_v
	copy.scale = fg.scale
	copy.anchor_bg = fg.anchor_bg
	copy.anchor_fg = fg.anchor_fg
	copy.transition_type = fg.transition_type
	copy.transition_duration = fg.transition_duration
	return copy

# --- CRUD Dialogues ---

func add_dialogue(character: String, text: String) -> void:
	if _sequence == null:
		return
	var dlg = DialogueScript.new()
	dlg.character = character
	dlg.text = text
	_sequence.dialogues.append(dlg)

func remove_dialogue(index: int) -> void:
	if _sequence == null or index < 0 or index >= _sequence.dialogues.size():
		return
	_sequence.dialogues.remove_at(index)
	if _selected_dialogue_index == index:
		_selected_dialogue_index = -1
	elif _selected_dialogue_index > index:
		_selected_dialogue_index -= 1

func move_dialogue(from_index: int, to_index: int) -> void:
	if _sequence == null:
		return
	if from_index < 0 or from_index >= _sequence.dialogues.size():
		return
	if to_index < 0 or to_index > _sequence.dialogues.size():
		return
	var dlg = _sequence.dialogues[from_index]
	_sequence.dialogues.remove_at(from_index)
	_sequence.dialogues.insert(to_index, dlg)

func modify_dialogue(index: int, character: String, text: String) -> void:
	if _sequence == null or index < 0 or index >= _sequence.dialogues.size():
		return
	_sequence.dialogues[index].character = character
	_sequence.dialogues[index].text = text

# --- Background ---

func set_background(path: String) -> void:
	if _sequence == null:
		return
	_sequence.background = path

func get_background() -> String:
	if _sequence == null:
		return ""
	return _sequence.background

# --- Foreground CRUD sur dialogue courant ---

func add_foreground_to_current(fg_name: String, image: String) -> void:
	if _sequence == null or _selected_dialogue_index < 0:
		return
	ensure_own_foregrounds(_selected_dialogue_index)
	var fg = ForegroundScript.new()
	fg.fg_name = fg_name
	fg.image = image
	_sequence.dialogues[_selected_dialogue_index].foregrounds.append(fg)

func remove_foreground_from_current(uuid: String) -> void:
	if _sequence == null or _selected_dialogue_index < 0:
		return
	var dlg = _sequence.dialogues[_selected_dialogue_index]
	for i in range(dlg.foregrounds.size()):
		if dlg.foregrounds[i].uuid == uuid:
			dlg.foregrounds.remove_at(i)
			break

# --- Mode Play ---

func is_playing() -> bool:
	return _playing

func get_play_dialogue_index() -> int:
	return _play_index

func start_play() -> void:
	if _sequence == null or _sequence.dialogues.size() == 0:
		return
	_playing = true
	_play_index = 0
	_start_typewriter()
	play_dialogue_changed.emit(_play_index)

func start_play_at(index: int) -> void:
	if _sequence == null or _sequence.dialogues.is_empty():
		return
	_playing = true
	_play_index = clampi(index, 0, _sequence.dialogues.size() - 1)
	_start_typewriter()
	play_dialogue_changed.emit(_play_index)

func stop_play() -> void:
	_playing = false
	_play_index = -1
	play_stopped.emit()

func advance_play() -> void:
	if not _playing:
		return
	_play_index += 1
	if _play_index >= _sequence.dialogues.size():
		stop_play()
		return
	_start_typewriter()
	play_dialogue_changed.emit(_play_index)

# --- Typewriter ---

func _start_typewriter() -> void:
	_visible_characters = 0
	_text_fully_displayed = false

func is_text_fully_displayed() -> bool:
	return _text_fully_displayed

func get_visible_characters() -> int:
	return _visible_characters

func skip_typewriter() -> void:
	if not _playing or _play_index < 0:
		return
	var dlg = _sequence.dialogues[_play_index]
	_visible_characters = dlg.text.length()
	_text_fully_displayed = true

func advance_typewriter() -> void:
	if not _playing or _play_index < 0 or _text_fully_displayed:
		return
	var dlg = _sequence.dialogues[_play_index]
	_visible_characters += 1
	if _visible_characters >= dlg.text.length():
		_visible_characters = dlg.text.length()
		_text_fully_displayed = true
