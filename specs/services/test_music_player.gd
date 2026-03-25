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
	assert_eq(_player._current_music_path, "", "Le chemin musique ne doit pas changer")


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


func test_resolve_path_absolute_system_path_returns_empty() -> void:
	# Un chemin système absolu sans base_path ne peut pas être résolu
	var result = MusicPlayerScript._resolve_path("C:/Projets/Game/assets/music/theme.mp3", "")
	assert_eq(result, "")


func test_resolve_path_fallback_music_subfolder() -> void:
	# Créer un fichier temporaire dans assets/music/
	var base = "user://test_resolve_%d" % randi()
	DirAccess.make_dir_recursive_absolute(base + "/assets/music")
	var f = FileAccess.open(base + "/assets/music/theme.ogg", FileAccess.WRITE)
	f.store_string("fake")
	f.close()
	# Résoudre un chemin absolu qui n'existe pas mais dont le fichier est dans assets/music/
	var result = MusicPlayerScript._resolve_path("C:/Projets/Game/music/theme.ogg", base)
	assert_eq(result, base + "/assets/music/theme.ogg")
	# Nettoyage
	DirAccess.remove_absolute(base + "/assets/music/theme.ogg")
	DirAccess.remove_absolute(base + "/assets/music")
	DirAccess.remove_absolute(base + "/assets")
	DirAccess.remove_absolute(base)


func test_resolve_path_fallback_fx_subfolder() -> void:
	var base = "user://test_resolve_%d" % randi()
	DirAccess.make_dir_recursive_absolute(base + "/assets/fx")
	var f = FileAccess.open(base + "/assets/fx/click.ogg", FileAccess.WRITE)
	f.store_string("fake")
	f.close()
	var result = MusicPlayerScript._resolve_path("/home/user/fx/click.ogg", base)
	assert_eq(result, base + "/assets/fx/click.ogg")
	DirAccess.remove_absolute(base + "/assets/fx/click.ogg")
	DirAccess.remove_absolute(base + "/assets/fx")
	DirAccess.remove_absolute(base + "/assets")
	DirAccess.remove_absolute(base)


func test_load_audio_stream_empty_path() -> void:
	var result = MusicPlayerScript._load_audio_stream("/nonexistent/file.ogg")
	assert_null(result)


func test_load_audio_stream_unsupported_format() -> void:
	# Format non supporté — doit renvoyer null (avec warning)
	var result = MusicPlayerScript._load_audio_stream("/fake/file.aac")
	assert_null(result)


func test_play_music_nonexistent_path() -> void:
	# Chemin non vide mais fichier inexistant → stream null → early return
	_player.play_music("/nonexistent/music.ogg")
	assert_eq(_player._current_music_path, "")


func test_play_fx_nonexistent_path() -> void:
	# Chemin non vide mais fichier inexistant → stream null → early return
	_player.play_fx("/nonexistent/fx.ogg")
	assert_eq(_player._current_music_path, "")


func test_audio_exists_nonexistent() -> void:
	assert_false(MusicPlayerScript._audio_exists("/nonexistent/file.ogg"))


func test_audio_exists_with_existing_file() -> void:
	var f = FileAccess.open("user://test_audio_exists.ogg", FileAccess.WRITE)
	if f:
		f.store_string("fake")
		f.close()
	var path = OS.get_user_data_dir() + "/test_audio_exists.ogg"
	assert_true(MusicPlayerScript._audio_exists(path))
	DirAccess.remove_absolute(path)


func test_resolve_path_direct_hit() -> void:
	var f = FileAccess.open("user://test_resolve_direct.ogg", FileAccess.WRITE)
	if f:
		f.store_string("fake")
		f.close()
	var path = OS.get_user_data_dir() + "/test_resolve_direct.ogg"
	var result = MusicPlayerScript._resolve_path(path, "")
	assert_eq(result, path)
	DirAccess.remove_absolute(path)


func test_resolve_path_res_path_no_base() -> void:
	# res:// path qui n'existe pas, pas de base_path → ""
	var result = MusicPlayerScript._resolve_path("res://nonexistent_audio.ogg", "")
	assert_eq(result, "")


func test_resolve_path_res_path_with_fallback() -> void:
	var base = OS.get_user_data_dir() + "/test_res_fallback_%d" % randi()
	DirAccess.make_dir_recursive_absolute(base + "/assets/music")
	var f = FileAccess.open(base + "/assets/music/theme.ogg", FileAccess.WRITE)
	if f:
		f.store_string("fake")
		f.close()
	var result = MusicPlayerScript._resolve_path("res://some/path/theme.ogg", base)
	assert_eq(result, base + "/assets/music/theme.ogg")
	DirAccess.remove_absolute(base + "/assets/music/theme.ogg")
	DirAccess.remove_absolute(base + "/assets/music")
	DirAccess.remove_absolute(base + "/assets")
	DirAccess.remove_absolute(base)


func test_resolve_path_joined_hit() -> void:
	var base = OS.get_user_data_dir() + "/test_joined_%d" % randi()
	DirAccess.make_dir_recursive_absolute(base)
	var f = FileAccess.open(base + "/theme.ogg", FileAccess.WRITE)
	if f:
		f.store_string("fake")
		f.close()
	var result = MusicPlayerScript._resolve_path("theme.ogg", base)
	assert_eq(result, base + "/theme.ogg")
	DirAccess.remove_absolute(base + "/theme.ogg")
	DirAccess.remove_absolute(base)


func test_load_audio_stream_empty_ogg_file() -> void:
	var f = FileAccess.open("user://test_load.ogg", FileAccess.WRITE)
	if f:
		f.close()  # fichier vide
	var path = OS.get_user_data_dir() + "/test_load.ogg"
	var result = MusicPlayerScript._load_audio_stream(path, false)
	assert_null(result)
	DirAccess.remove_absolute(path)


func test_load_audio_stream_empty_mp3_file() -> void:
	var f = FileAccess.open("user://test_load.mp3", FileAccess.WRITE)
	if f:
		f.close()  # fichier vide
	var path = OS.get_user_data_dir() + "/test_load.mp3"
	var result = MusicPlayerScript._load_audio_stream(path, false)
	assert_null(result)
	DirAccess.remove_absolute(path)


func test_load_audio_stream_existing_wav_external() -> void:
	var f = FileAccess.open("user://test_load.wav", FileAccess.WRITE)
	if f:
		f.store_string("fake wav data")
		f.close()
	var path = OS.get_user_data_dir() + "/test_load.wav"
	var result = MusicPlayerScript._load_audio_stream(path, false)
	assert_null(result)  # WAV externe non supporté
	DirAccess.remove_absolute(path)

# --- play_music duplicate path skip ---

func test_play_music_duplicate_path_skips() -> void:
	_player._current_music_path = "/fake/music.ogg"
	_player.play_music("/fake/music.ogg")
	# Should still be the same path, no stream change
	assert_eq(_player._current_music_path, "/fake/music.ogg")


func test_play_music_nonexistent_exercises_load_path() -> void:
	# Exercises play_music with a nonexistent path that isn't empty
	# (path != "" and path != _current_music_path, so the load branch is reached)
	_player.play_music("/tmp/nonexistent_audio_file.ogg")
	assert_eq(_player._current_music_path, "", "Stream null → path not set")


func test_apply_sequence_with_music_resolves_path() -> void:
	# Use .wav extension — WAV non-res:// returns null gracefully (no engine error)
	var base = "user://test_apply_%d" % randi()
	DirAccess.make_dir_recursive_absolute(base)
	var f = FileAccess.open(base + "/music.wav", FileAccess.WRITE)
	if f:
		f.store_string("x")
		f.close()
	var seq = SequenceScript.new()
	seq.stop_music = false
	seq.music = "music.wav"
	seq.audio_fx = ""
	var abs_base = base.replace("user://", OS.get_user_data_dir() + "/")
	_player.apply_sequence(seq, abs_base)
	assert_eq(_player._current_music_path, "", "WAV externe non supporté → not set")
	DirAccess.remove_absolute(abs_base + "/music.wav")
	DirAccess.remove_absolute(abs_base)


func test_apply_sequence_with_fx_resolves_path() -> void:
	var base = "user://test_apply_fx_%d" % randi()
	DirAccess.make_dir_recursive_absolute(base)
	var f = FileAccess.open(base + "/click.wav", FileAccess.WRITE)
	if f:
		f.store_string("x")
		f.close()
	var seq = SequenceScript.new()
	seq.stop_music = false
	seq.music = ""
	seq.audio_fx = "click.wav"
	var abs_base = base.replace("user://", OS.get_user_data_dir() + "/")
	_player.apply_sequence(seq, abs_base)
	assert_eq(_player._current_music_path, "")
	DirAccess.remove_absolute(abs_base + "/click.wav")
	DirAccess.remove_absolute(abs_base)


func test_play_menu_music_with_valid_path() -> void:
	_player.play_menu_music("/nonexistent/but/valid.ogg")
	# Stream null so play_music returns early, but play_menu_music code is exercised
	assert_eq(_player._current_music_path, "")