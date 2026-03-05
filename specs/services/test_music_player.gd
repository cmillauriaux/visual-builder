extends GutTest

## Tests pour MusicPlayer — service de lecture audio.

const MusicPlayerScript = preload("res://src/services/music_player.gd")
const SequenceScript = preload("res://src/models/sequence.gd")

var _player: Node


func before_each() -> void:
	_player = Node.new()
	_player.set_script(MusicPlayerScript)
	add_child_autofree(_player)


func test_initial_state() -> void:
	assert_not_null(_player)
	assert_eq(_player._current_music_path, "")


func test_stop_music_when_nothing_playing() -> void:
	# Ne doit pas provoquer d'erreur
	_player.stop_music()
	assert_eq(_player._current_music_path, "")


func test_apply_sequence_null_does_nothing() -> void:
	# apply_sequence(null) ne doit pas provoquer d'erreur
	_player.apply_sequence(null, "")
	assert_eq(_player._current_music_path, "")


func test_apply_sequence_stop_music() -> void:
	# Simuler une musique en cours
	_player._current_music_path = "/fake/music.ogg"
	# Créer une séquence avec stop_music = true
	var seq = SequenceScript.new()
	seq.stop_music = true
	seq.music = ""
	seq.audio_fx = ""
	_player.apply_sequence(seq, "")
	assert_eq(_player._current_music_path, "", "La musique doit être arrêtée")


func test_apply_sequence_no_audio() -> void:
	# Séquence sans audio — ne change rien
	var seq = SequenceScript.new()
	seq.stop_music = false
	seq.music = ""
	seq.audio_fx = ""
	_player.apply_sequence(seq, "")
	assert_eq(_player._current_music_path, "")


func test_play_music_empty_path() -> void:
	# play_music("") ne doit pas changer l'état
	_player.play_music("")
	assert_eq(_player._current_music_path, "")


func test_play_fx_empty_path() -> void:
	# play_fx("") ne doit pas provoquer d'erreur
	_player.play_fx("")


func test_play_menu_music_empty_path() -> void:
	# play_menu_music("") ne doit pas provoquer d'erreur
	_player.play_menu_music("")
	assert_eq(_player._current_music_path, "")


func test_resolve_path_empty() -> void:
	var result = MusicPlayerScript._resolve_path("", "")
	assert_eq(result, "")


func test_resolve_path_nonexistent() -> void:
	var result = MusicPlayerScript._resolve_path("/nonexistent/path.ogg", "")
	assert_eq(result, "")


func test_load_audio_stream_empty_path() -> void:
	var result = MusicPlayerScript._load_audio_stream("/nonexistent/file.ogg")
	assert_null(result)


func test_load_audio_stream_unsupported_format() -> void:
	# Format non supporté — doit renvoyer null (avec warning)
	var result = MusicPlayerScript._load_audio_stream("/fake/file.aac")
	assert_null(result)
