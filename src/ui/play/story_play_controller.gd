extends Node

## Contrôleur orchestrant le play multi-niveaux (story, chapitre, scène).
## Machine à états : IDLE → PLAYING_SEQUENCE ↔ WAITING_FOR_CHOICE → IDLE

enum State { IDLE, PLAYING_SEQUENCE, WAITING_FOR_CHOICE }

signal sequence_play_requested(sequence)
signal choice_display_requested(choices)
signal play_finished(reason: String)
signal notification_triggered(message: String)

var _state: int = State.IDLE
var _story = null
var _current_chapter = null
var _current_scene = null
var _current_sequence = null
var _user_stopped: bool = false
var _variables: Dictionary = {}  # String → Variant
var _notification_service: RefCounted


func setup(notification_service: RefCounted) -> void:
	_notification_service = notification_service

func get_state() -> int:
	return _state

func is_playing() -> bool:
	return _state != State.IDLE

# --- Variables ---

func set_variable(key: String, value) -> void:
	_variables[key] = value

func get_variable(key: String):
	return _variables.get(key)

# --- Démarrage ---

func start_play_story(story) -> void:
	if story == null:
		return
	_story = story
	_user_stopped = false
	_variables = {}
	_init_variables_from_story(story)
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
	_start_scene_entry(scene)

func start_play_chapter(story, chapter) -> void:
	if story == null or chapter == null:
		return
	_story = story
	_current_chapter = chapter
	_user_stopped = false
	_variables = {}
	_init_variables_from_story(story)
	var scene = _find_entry(chapter.scenes, chapter.entry_point_uuid)
	if scene == null:
		_finish("error")
		return
	_current_scene = scene
	_start_scene_entry(scene)

func start_play_scene(story, chapter, scene) -> void:
	if story == null or chapter == null or scene == null:
		return
	_story = story
	_current_chapter = chapter
	_current_scene = scene
	_user_stopped = false
	_variables = {}
	_init_variables_from_story(story)
	_start_scene_entry(scene)

## Reprend une partie depuis une sauvegarde : restaure directement l'état sans passer
## par l'entry point. Émet sequence_play_requested avec la séquence sauvegardée.
func start_play_from_save(story, chapter, scene, sequence, variables: Dictionary) -> void:
	if story == null or chapter == null or scene == null or sequence == null:
		return
	_story = story
	_current_chapter = chapter
	_current_scene = scene
	_current_sequence = sequence
	_variables = variables.duplicate()
	_user_stopped = false
	_state = State.PLAYING_SEQUENCE
	sequence_play_requested.emit(sequence)

## Trouve l'entry point d'une scène (séquence ou condition) et démarre le play.
func _start_scene_entry(scene) -> void:
	var entry = _find_scene_entry(scene)
	if entry == null:
		_finish("error")
		return
	_resolve_entry(entry)

## Trouve l'entry point d'une scène en cherchant dans sequences ET conditions.
func _find_scene_entry(scene):
	var entry_uuid = scene.entry_point_uuid
	if entry_uuid != "":
		# Chercher dans les séquences
		var seq = scene.find_sequence(entry_uuid)
		if seq:
			return seq
		# Chercher dans les conditions
		if scene.has_method("find_condition"):
			var cond = scene.find_condition(entry_uuid)
			if cond:
				return cond
	# Fallback : chercher dans séquences + conditions par position
	var all_items: Array = []
	all_items.append_array(scene.sequences)
	if scene.get("conditions") != null:
		all_items.append_array(scene.conditions)
	if all_items.is_empty():
		return null
	var best = all_items[0]
	for i in range(1, all_items.size()):
		var item = all_items[i]
		if item.position.x < best.position.x:
			best = item
		elif item.position.x == best.position.x and item.position.y < best.position.y:
			best = item
	return best

## Résout un entry point : si c'est une séquence, on la joue ; si c'est une condition, on l'évalue.
func _resolve_entry(entry) -> void:
	if entry.get("rules") != null:
		# C'est une condition
		_evaluate_condition(entry)
	else:
		# C'est une séquence
		_current_sequence = entry
		_state = State.PLAYING_SEQUENCE
		sequence_play_requested.emit(entry)

## Évalue une condition et résout la conséquence.
func _evaluate_condition(condition) -> void:
	var consequence = condition.evaluate(_variables)
	if consequence == null:
		_finish("no_ending")
		return
	_resolve_consequence(consequence)

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
	# Appliquer les effets du choix d'abord, puis ceux de la conséquence
	_apply_effects(choice.effects)
	_resolve_consequence(choice.consequence)

func stop_play() -> void:
	_user_stopped = true
	_state = State.IDLE
	_current_sequence = null
	play_finished.emit("stopped")

# --- Résolution des conséquences ---

func _resolve_consequence(consequence) -> void:
	_apply_effects(consequence.effects)
	match consequence.type:
		"redirect_sequence":
			var target = _current_scene.find_sequence(consequence.target)
			if target:
				_current_sequence = target
				_state = State.PLAYING_SEQUENCE
				sequence_play_requested.emit(target)
				return
			_finish("error")
		"redirect_condition":
			if _current_scene.has_method("find_condition"):
				var cond = _current_scene.find_condition(consequence.target)
				if cond:
					_evaluate_condition(cond)
					return
			_finish("error")
		"redirect_scene":
			var target_scene = _current_chapter.find_scene(consequence.target)
			if target_scene == null:
				_finish("error")
				return
			_current_scene = target_scene
			_start_scene_entry(target_scene)
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
			_start_scene_entry(scene)
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

# --- Variables ---

func _init_variables_from_story(story) -> void:
	if story.get("variables") == null:
		return
	for var_def in story.variables:
		_variables[var_def.var_name] = var_def.initial_value

func _apply_effects(effects: Array) -> void:
	var before := _variables.duplicate()
	for effect in effects:
		effect.apply(_variables)
	_check_notifications(before)


func _check_notifications(before: Dictionary) -> void:
	if _story == null or _story.get("notifications") == null:
		return
	for var_name in _variables:
		if not before.has(var_name) or before[var_name] != _variables[var_name]:
			for notif in _story.notifications:
				if notif.matches(var_name):
					if _notification_service:
						_notification_service.show_notification(notif.message)
					else:
						notification_triggered.emit(notif.message)
