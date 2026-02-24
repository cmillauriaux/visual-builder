extends Node

## Contrôleur orchestrant le play multi-niveaux (story, chapitre, scène).
## Machine à états : IDLE → PLAYING_SEQUENCE ↔ WAITING_FOR_CHOICE → IDLE

enum State { IDLE, PLAYING_SEQUENCE, WAITING_FOR_CHOICE }

signal sequence_play_requested(sequence)
signal choice_display_requested(choices)
signal play_finished(reason: String)

var _state: int = State.IDLE
var _story = null
var _current_chapter = null
var _current_scene = null
var _current_sequence = null
var _user_stopped: bool = false

func get_state() -> int:
	return _state

func is_playing() -> bool:
	return _state != State.IDLE

# --- Démarrage ---

func start_play_story(story) -> void:
	if story == null:
		return
	_story = story
	_user_stopped = false
	var chapter = _find_entry(story.chapters, story.entry_point_uuid)
	if chapter == null:
		_finish("error")
		return
	_current_chapter = chapter
	var scene = _find_entry(chapter.scenes, chapter.entry_point_uuid)
	if scene == null:
		_finish("error")
		return
	_current_scene = scene
	var seq = _find_entry(scene.sequences, scene.entry_point_uuid)
	if seq == null:
		_finish("error")
		return
	_current_sequence = seq
	_state = State.PLAYING_SEQUENCE
	sequence_play_requested.emit(seq)

func start_play_chapter(story, chapter) -> void:
	if story == null or chapter == null:
		return
	_story = story
	_current_chapter = chapter
	_user_stopped = false
	var scene = _find_entry(chapter.scenes, chapter.entry_point_uuid)
	if scene == null:
		_finish("error")
		return
	_current_scene = scene
	var seq = _find_entry(scene.sequences, scene.entry_point_uuid)
	if seq == null:
		_finish("error")
		return
	_current_sequence = seq
	_state = State.PLAYING_SEQUENCE
	sequence_play_requested.emit(seq)

func start_play_scene(story, chapter, scene) -> void:
	if story == null or chapter == null or scene == null:
		return
	_story = story
	_current_chapter = chapter
	_current_scene = scene
	_user_stopped = false
	var seq = _find_entry(scene.sequences, scene.entry_point_uuid)
	if seq == null:
		_finish("error")
		return
	_current_sequence = seq
	_state = State.PLAYING_SEQUENCE
	sequence_play_requested.emit(seq)

# --- Événements ---

func on_sequence_finished() -> void:
	if _state != State.PLAYING_SEQUENCE:
		return
	var seq = _current_sequence
	if seq == null:
		_finish("error")
		return

	if seq.ending == null:
		_finish("no_ending")
		return

	if seq.ending.type == "auto_redirect":
		if seq.ending.auto_consequence == null:
			_finish("no_ending")
			return
		_resolve_consequence(seq.ending.auto_consequence)
	elif seq.ending.type == "choices":
		if seq.ending.choices.size() == 0:
			_finish("no_ending")
			return
		_state = State.WAITING_FOR_CHOICE
		choice_display_requested.emit(seq.ending.choices)
	else:
		_finish("no_ending")

func on_choice_selected(index: int) -> void:
	if _state != State.WAITING_FOR_CHOICE:
		return
	var seq = _current_sequence
	if seq == null or seq.ending == null:
		_finish("error")
		return
	if index < 0 or index >= seq.ending.choices.size():
		_finish("error")
		return
	var choice = seq.ending.choices[index]
	if choice.consequence == null:
		_finish("error")
		return
	_resolve_consequence(choice.consequence)

func stop_play() -> void:
	_user_stopped = true
	_state = State.IDLE
	_current_sequence = null
	play_finished.emit("stopped")

# --- Résolution des conséquences ---

func _resolve_consequence(consequence) -> void:
	match consequence.type:
		"redirect_sequence":
			var target = _current_scene.find_sequence(consequence.target)
			if target == null:
				_finish("error")
				return
			_current_sequence = target
			_state = State.PLAYING_SEQUENCE
			sequence_play_requested.emit(target)
		"redirect_scene":
			var target_scene = _current_chapter.find_scene(consequence.target)
			if target_scene == null:
				_finish("error")
				return
			_current_scene = target_scene
			var seq = _find_entry(target_scene.sequences, target_scene.entry_point_uuid)
			if seq == null:
				_finish("error")
				return
			_current_sequence = seq
			_state = State.PLAYING_SEQUENCE
			sequence_play_requested.emit(seq)
		"redirect_chapter":
			var target_ch = _story.find_chapter(consequence.target)
			if target_ch == null:
				_finish("error")
				return
			_current_chapter = target_ch
			var scene = _find_entry(target_ch.scenes, target_ch.entry_point_uuid)
			if scene == null:
				_finish("error")
				return
			_current_scene = scene
			var seq = _find_entry(scene.sequences, scene.entry_point_uuid)
			if seq == null:
				_finish("error")
				return
			_current_sequence = seq
			_state = State.PLAYING_SEQUENCE
			sequence_play_requested.emit(seq)
		"game_over":
			_finish("game_over")
		"to_be_continued":
			_finish("to_be_continued")
		_:
			_finish("error")

func _finish(reason: String) -> void:
	_state = State.IDLE
	_current_sequence = null
	play_finished.emit(reason)

# --- Utilitaires ---

## Trouve l'élément d'entrée par UUID explicite, ou fallback par position.
func _find_entry(items: Array, entry_uuid: String = ""):
	if items.is_empty():
		return null
	if entry_uuid != "":
		for item in items:
			if item.uuid == entry_uuid:
				return item
	# Fallback : heuristique position gauche→droite, haut→bas
	var best = items[0]
	for i in range(1, items.size()):
		var item = items[i]
		if item.position.x < best.position.x:
			best = item
		elif item.position.x == best.position.x and item.position.y < best.position.y:
			best = item
	return best

func get_current_sequence():
	return _current_sequence

func get_current_scene():
	return _current_scene

func get_current_chapter():
	return _current_chapter
