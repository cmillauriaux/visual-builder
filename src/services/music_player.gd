extends Node

## Service de lecture audio pour le jeu standalone.
## Gère la musique (boucle continue) et les FX (lecture unique).
## Utilise les bus audio "Music" et "FX" de Godot.

class_name MusicPlayer

var _music_stream_player: AudioStreamPlayer
var _fx_stream_player: AudioStreamPlayer
var _current_music_path: String = ""


func _ready() -> void:
	_music_stream_player = AudioStreamPlayer.new()
	_music_stream_player.bus = "Music"
	add_child(_music_stream_player)

	_fx_stream_player = AudioStreamPlayer.new()
	_fx_stream_player.bus = "FX"
	add_child(_fx_stream_player)


## Joue une musique en boucle. Si le même fichier est déjà en cours, ne recharge pas.
func play_music(path: String) -> void:
	if path == "" or path == _current_music_path:
		return
	var stream = _load_audio_stream(path, true)
	if stream == null:
		return
	_current_music_path = path
	_music_stream_player.stream = stream
	_music_stream_player.play()


## Arrête la musique en cours.
func stop_music() -> void:
	_music_stream_player.stop()
	_current_music_path = ""


## Joue un FX (lecture unique, sans boucle).
func play_fx(path: String) -> void:
	if path == "":
		return
	var stream = _load_audio_stream(path, false)
	if stream == null:
		return
	_fx_stream_player.stream = stream
	_fx_stream_player.play()


## Applique les paramètres audio d'une séquence.
## Doit être appelé au démarrage de chaque séquence.
func apply_sequence(sequence, base_path: String) -> void:
	if sequence == null:
		return

	# Stop music si demandé
	if sequence.stop_music:
		stop_music()

	# Musique
	var music_path = _resolve_path(sequence.music, base_path)
	if music_path != "":
		play_music(music_path)

	# FX audio
	var fx_path = _resolve_path(sequence.audio_fx, base_path)
	if fx_path != "":
		play_fx(fx_path)


## Joue la musique du menu principal.
func play_menu_music(path: String) -> void:
	if path == "":
		return
	play_music(path)


## Résout un chemin audio (absolu ou relatif à base_path).
static func _resolve_path(path: String, base_path: String) -> String:
	if path == "":
		return ""
	if FileAccess.file_exists(path):
		return path
	if base_path != "":
		var full = base_path.path_join(path)
		if FileAccess.file_exists(full):
			return full
	return ""


## Charge un stream audio depuis un chemin absolu.
## Formats supportés : OGG, MP3, WAV.
## loop=true pour la musique, false pour les FX.
static func _load_audio_stream(path: String, loop: bool = false) -> AudioStream:
	if not FileAccess.file_exists(path):
		push_warning("MusicPlayer: fichier audio introuvable : " + path)
		return null

	var ext = path.get_extension().to_lower()

	if ext == "ogg":
		var stream = AudioStreamOggVorbis.load_from_file(path)
		if stream:
			stream.loop = loop
		return stream

	if ext == "mp3":
		var bytes = FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			push_warning("MusicPlayer: impossible de lire le fichier MP3 : " + path)
			return null
		var stream = AudioStreamMP3.new()
		stream.data = bytes
		stream.loop = loop
		return stream

	if ext == "wav":
		# Tentative de chargement via ResourceLoader (WAV importés dans Godot)
		if path.begins_with("res://"):
			var stream = ResourceLoader.load(path, "AudioStream")
			if stream:
				return stream
		push_warning("MusicPlayer: WAV externe non supporté directement. Utilisez OGG ou MP3.")
		return null

	push_warning("MusicPlayer: format audio non supporté : " + ext)
	return null
