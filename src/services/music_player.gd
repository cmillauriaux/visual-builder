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
		print("[MusicPlayer] play_music skipped — path='%s' current='%s'" % [path, _current_music_path])
		return
	print("[MusicPlayer] play_music loading '%s'" % path)
	var stream = _load_audio_stream(path, true)
	if stream == null:
		print("[MusicPlayer] play_music FAILED — stream is null for '%s'" % path)
		return
	_current_music_path = path
	_music_stream_player.stream = stream
	_music_stream_player.play()
	print("[MusicPlayer] play_music OK — playing '%s', bus='%s'" % [path, _music_stream_player.bus])


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

	print("[MusicPlayer] apply_sequence — base_path='%s' music='%s' fx='%s' stop=%s" % [base_path, sequence.music, sequence.audio_fx, str(sequence.stop_music)])

	# Stop music si demandé
	if sequence.stop_music:
		stop_music()

	# Musique
	var music_path = _resolve_path(sequence.music, base_path)
	print("[MusicPlayer] resolved music_path='%s'" % music_path)
	if music_path != "":
		play_music(music_path)

	# FX audio
	var fx_path = _resolve_path(sequence.audio_fx, base_path)
	if fx_path != "":
		play_fx(fx_path)


## Joue la musique du menu principal.
func play_menu_music(path: String) -> void:
	print("[MusicPlayer] play_menu_music — path='%s'" % path)
	if path == "":
		return
	play_music(path)


## Vérifie si un fichier audio existe (FileAccess ou ResourceLoader).
## ResourceLoader est nécessaire pour les builds exportés où les fichiers
## sont importés (.mp3str, .oggstr) et non accessibles en tant que fichiers bruts.
static func _audio_exists(p: String) -> bool:
	if FileAccess.file_exists(p):
		return true
	if p.begins_with("res://") and ResourceLoader.exists(p, "AudioStream"):
		return true
	return false


## Résout un chemin audio (absolu ou relatif à base_path).
## Gère les chemins res://, user://, relatifs, et absolus système.
static func _resolve_path(path: String, base_path: String) -> String:
	if path == "":
		return ""
	print("[MusicPlayer] _resolve_path — path='%s' base_path='%s'" % [path, base_path])
	if _audio_exists(path):
		print("[MusicPlayer]   → direct hit: '%s'" % path)
		return path
	else:
		print("[MusicPlayer]   → direct NOT found: '%s'" % path)
	# Si le chemin est déjà absolu (res://), ne pas tenter de joindre avec base_path
	if path.begins_with("res://"):
		# Tenter le fallback par nom de fichier dans base_path
		if base_path != "":
			var filename = path.get_file()
			for subfolder in ["assets/music", "assets/fx"]:
				var fallback = base_path.path_join(subfolder).path_join(filename)
				if _audio_exists(fallback):
					print("[MusicPlayer]   → fallback hit: '%s'" % fallback)
					return fallback
		print("[MusicPlayer]   → UNRESOLVED: '%s'" % path)
		return ""
	if base_path != "":
		var full = base_path.path_join(path)
		if _audio_exists(full):
			print("[MusicPlayer]   → joined hit: '%s'" % full)
			return full
		else:
			print("[MusicPlayer]   → joined NOT found: '%s'" % full)
		# Fallback : essayer avec juste le nom du fichier dans assets/music/ et assets/fx/
		var filename = path.get_file()
		for subfolder in ["assets/music", "assets/fx"]:
			var fallback = base_path.path_join(subfolder).path_join(filename)
			if _audio_exists(fallback):
				print("[MusicPlayer]   → fallback hit: '%s'" % fallback)
				return fallback
			else:
				print("[MusicPlayer]   → fallback NOT found: '%s'" % fallback)
	print("[MusicPlayer]   → UNRESOLVED: '%s'" % path)
	return ""


## Charge un stream audio depuis un chemin.
## Formats supportés : OGG, MP3, WAV.
## loop=true pour la musique, false pour les FX.
## Essaie ResourceLoader d'abord (builds exportés), puis FileAccess (fichiers bruts).
static func _load_audio_stream(path: String, loop: bool = false) -> AudioStream:
	print("[MusicPlayer] _load_audio_stream — path='%s' loop=%s" % [path, str(loop)])

	# 1. Essayer ResourceLoader (fonctionne pour les ressources importées dans les PCK)
	if path.begins_with("res://") and ResourceLoader.exists(path, "AudioStream"):
		var stream = ResourceLoader.load(path, "AudioStream")
		if stream:
			print("[MusicPlayer]   → loaded via ResourceLoader: %s" % str(stream))
			if stream is AudioStreamMP3:
				stream.loop = loop
			elif stream is AudioStreamOggVorbis:
				stream.loop = loop
			return stream

	# 2. Fallback : chargement manuel via FileAccess (fichiers bruts hors PCK)
	if not FileAccess.file_exists(path):
		print("[MusicPlayer]   → file NOT found (FileAccess nor ResourceLoader): '%s'" % path)
		push_warning("MusicPlayer: fichier audio introuvable : " + path)
		return null

	var ext = path.get_extension().to_lower()
	print("[MusicPlayer]   → manual load, ext='%s'" % ext)

	if ext == "ogg":
		var bytes = FileAccess.get_file_as_bytes(path)
		print("[MusicPlayer]   → OGG bytes=%d" % bytes.size())
		if bytes.is_empty():
			push_warning("MusicPlayer: impossible de lire le fichier OGG : " + path)
			return null
		var stream = AudioStreamOggVorbis.load_from_buffer(bytes)
		print("[MusicPlayer]   → OGG stream=%s" % str(stream))
		if stream:
			stream.loop = loop
		return stream

	if ext == "mp3":
		var bytes = FileAccess.get_file_as_bytes(path)
		print("[MusicPlayer]   → MP3 bytes=%d" % bytes.size())
		if bytes.is_empty():
			push_warning("MusicPlayer: impossible de lire le fichier MP3 : " + path)
			return null
		var stream = AudioStreamMP3.new()
		stream.data = bytes
		stream.loop = loop
		print("[MusicPlayer]   → MP3 stream OK")
		return stream

	if ext == "wav":
		if path.begins_with("res://"):
			var stream = ResourceLoader.load(path, "AudioStream")
			if stream:
				print("[MusicPlayer]   → WAV stream OK via ResourceLoader")
				return stream
		push_warning("MusicPlayer: WAV externe non supporté directement. Utilisez OGG ou MP3.")
		return null

	push_warning("MusicPlayer: format audio non supporté : " + ext)
	return null
