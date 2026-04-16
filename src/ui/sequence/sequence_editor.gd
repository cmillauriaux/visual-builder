# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

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
var _display_text_length: int = 0

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
	# Aucun dialogue précédent → hérite de la séquence
	return _sequence.foregrounds

func is_dialogue_inheriting(dialogue_index: int) -> bool:
	if _sequence == null:
		return false
	if dialogue_index < 0 or dialogue_index >= _sequence.dialogues.size():
		return false
	var dlg = _sequence.dialogues[dialogue_index]
	if dlg.foregrounds.size() > 0:
		return false
	return get_effective_foregrounds(dialogue_index).size() > 0


func get_inheritance_source_index(dialogue_index: int) -> int:
	if _sequence == null:
		return -1
	if dialogue_index < 0 or dialogue_index >= _sequence.dialogues.size():
		return -1
	var dlg = _sequence.dialogues[dialogue_index]
	if dlg.foregrounds.size() > 0:
		return -1
	for i in range(dialogue_index - 1, -1, -1):
		if _sequence.dialogues[i].foregrounds.size() > 0:
			return i
	return -1


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
	copy.uuid = fg.uuid
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
	copy.anim_speed = fg.anim_speed
	copy.anim_reverse = fg.anim_reverse
	copy.anim_loop = fg.anim_loop
	copy.anim_reverse_loop = fg.anim_reverse_loop
	return copy

# --- Normalisation foregrounds ---

func normalize_dialogue_foregrounds() -> int:
	if _sequence == null:
		return 0
	# Passe 1 : aligner les positions proches sur la référence héritée
	for i in range(_sequence.dialogues.size()):
		var dlg = _sequence.dialogues[i]
		if dlg.foregrounds.size() == 0:
			continue
		var inherited = _get_inherited_foregrounds(i)
		if inherited.size() > 0:
			_align_foreground_positions(dlg.foregrounds, inherited)
	# Passe 2 : supprimer les dialogues dont les foregrounds sont identiques à l'héritage
	var cleared_count := 0
	for i in range(_sequence.dialogues.size()):
		var dlg = _sequence.dialogues[i]
		if dlg.foregrounds.size() == 0:
			continue
		var inherited = _get_inherited_foregrounds(i)
		if _are_foregrounds_equivalent(dlg.foregrounds, inherited):
			dlg.foregrounds.clear()
			cleared_count += 1
	return cleared_count

func _get_inherited_foregrounds(dialogue_index: int) -> Array:
	# Le dialogue 0 hérite des foregrounds de la séquence
	if dialogue_index == 0:
		return _sequence.foregrounds
	# Les autres héritent du dialogue précédent le plus proche avec des foregrounds
	for i in range(dialogue_index - 1, -1, -1):
		if _sequence.dialogues[i].foregrounds.size() > 0:
			return _sequence.dialogues[i].foregrounds
	# Aucun dialogue précédent → hérite de la séquence
	return _sequence.foregrounds

func _are_foregrounds_equivalent(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	# Pour chaque fg de a, chercher un match dans b
	var matched := []
	for fg_a in a:
		var found := false
		for j in range(b.size()):
			if j in matched:
				continue
			if _fg_match(fg_a, b[j]):
				matched.append(j)
				found = true
				break
		if not found:
			return false
	return true

func _fg_match(a, b) -> bool:
	if a.image != b.image:
		return false
	return _positions_close(a, b)

func _positions_close(a, b) -> bool:
	var threshold = 0.05
	if absf(a.anchor_bg.x - b.anchor_bg.x) > threshold:
		return false
	if absf(a.anchor_bg.y - b.anchor_bg.y) > threshold:
		return false
	if absf(a.anchor_fg.x - b.anchor_fg.x) > threshold:
		return false
	if absf(a.anchor_fg.y - b.anchor_fg.y) > threshold:
		return false
	return true

func _align_foreground_positions(foregrounds: Array, reference: Array) -> void:
	for fg in foregrounds:
		for ref in reference:
			if _positions_close(fg, ref):
				fg.anchor_bg = ref.anchor_bg
				fg.anchor_fg = ref.anchor_fg
				break

# --- Propagation foregrounds ---

const PROPAGATION_THRESHOLD := 0.01

func find_similar_foregrounds(anchor_bg: Vector2, from_dialogue_index: int, threshold: float = PROPAGATION_THRESHOLD) -> Array:
	if _sequence == null:
		return []
	var matches := []
	for i in range(from_dialogue_index + 1, _sequence.dialogues.size()):
		var dlg = _sequence.dialogues[i]
		if dlg.foregrounds.size() == 0:
			continue
		for fg in dlg.foregrounds:
			if absf(fg.anchor_bg.x - anchor_bg.x) <= threshold and absf(fg.anchor_bg.y - anchor_bg.y) <= threshold:
				matches.append({"dialogue_index": i, "foreground": fg})
	return matches

func propagate_fg_changes(matches: Array, changes: Dictionary, initial_anchor_bg: Vector2) -> void:
	for match_entry in matches:
		var fg = match_entry["foreground"]
		for prop in changes.keys():
			if prop == "anchor_bg":
				var delta = changes["anchor_bg"] - initial_anchor_bg
				fg.anchor_bg += delta
			else:
				fg.set(prop, changes[prop])

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

func duplicate_dialogue(index: int) -> int:
	if _sequence == null or index < 0 or index >= _sequence.dialogues.size():
		return -1
	var src = _sequence.dialogues[index]
	var dlg = DialogueScript.new()
	dlg.character = src.character
	dlg.text = src.text
	# Deep copy foregrounds
	for fg in get_effective_foregrounds(index):
		var copy = _copy_foreground(fg)
		copy.uuid = ForegroundScript.new().uuid  # New UUID
		dlg.foregrounds.append(copy)
	var insert_idx = index + 1
	_sequence.dialogues.insert(insert_idx, dlg)
	return insert_idx


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

func set_display_text_length(length: int) -> void:
	_display_text_length = length

func _start_typewriter() -> void:
	_visible_characters = 0
	_text_fully_displayed = false
	# Default to original text length; callers override via set_display_text_length()
	if _play_index >= 0 and _play_index < _sequence.dialogues.size():
		_display_text_length = _sequence.dialogues[_play_index].text.length()

func is_text_fully_displayed() -> bool:
	return _text_fully_displayed

func get_visible_characters() -> int:
	return _visible_characters

func skip_typewriter() -> void:
	if not _playing or _play_index < 0:
		return
	_visible_characters = _display_text_length
	_text_fully_displayed = true

func advance_typewriter() -> void:
	if not _playing or _play_index < 0 or _text_fully_displayed:
		return
	_visible_characters += 1
	if _visible_characters >= _display_text_length:
		_visible_characters = _display_text_length
		_text_fully_displayed = true

func skip_to_end() -> void:
	## Stoppe la lecture instantanément sans émettre play_stopped.
	## Utilisé par le Skip pour déclencher directement la fin de séquence.
	if not _playing:
		return
	_playing = false
	_play_index = -1
	_text_fully_displayed = true