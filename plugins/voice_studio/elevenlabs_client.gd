extends Node

## Client HTTP pour l'API ElevenLabs Text-to-Speech.
## Gère la génération de voix et le téléchargement des fichiers audio MP3.

const ElevenLabsConfig = preload("res://plugins/voice_studio/elevenlabs_config.gd")

const BASE_URL := "https://api.elevenlabs.io/v1"

signal generation_completed(mp3_bytes: PackedByteArray, dialogue_uuid: String)
signal generation_failed(error: String, dialogue_uuid: String)
signal generation_progress(status: String, dialogue_uuid: String)

var _config: RefCounted = null
var _generating: bool = false


func setup(config: RefCounted) -> void:
	_config = config


func is_generating() -> bool:
	return _generating


## Génère la voix pour un dialogue donné.
## voice_id : identifiant de la voix ElevenLabs du personnage
## text : texte à synthétiser (peut inclure des annotations [sarcastically], etc.)
## dialogue_uuid : UUID du dialogue (pour identifier la réponse)
func generate_voice(voice_id: String, text: String, dialogue_uuid: String) -> void:
	if _config == null:
		generation_failed.emit("Configuration non initialisée", dialogue_uuid)
		return
	if _config.get_api_key() == "":
		generation_failed.emit("Clé API ElevenLabs non configurée", dialogue_uuid)
		return
	if voice_id == "":
		generation_failed.emit("Voice ID non défini pour ce personnage", dialogue_uuid)
		return
	if text.strip_edges() == "":
		generation_failed.emit("Texte vide", dialogue_uuid)
		return

	_generating = true
	generation_progress.emit("Génération en cours...", dialogue_uuid)

	var url := "%s/text-to-speech/%s" % [BASE_URL, voice_id]
	var payload := JSON.stringify({
		"text": text,
		"model_id": _config.get_model_id(),
	})

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		_generating = false
		if result != HTTPRequest.RESULT_SUCCESS:
			generation_failed.emit("Erreur réseau (code: %d)" % result, dialogue_uuid)
			return
		if code != 200:
			var error_msg := "Erreur API ElevenLabs (HTTP %d)" % code
			var parsed = JSON.parse_string(body.get_string_from_utf8())
			if parsed is Dictionary and parsed.has("detail"):
				var detail = parsed["detail"]
				if detail is Dictionary and detail.has("message"):
					error_msg += ": " + str(detail["message"])
				else:
					error_msg += ": " + str(detail)
			generation_failed.emit(error_msg, dialogue_uuid)
			return
		generation_completed.emit(body, dialogue_uuid)
	)

	var headers: PackedStringArray = _config.get_auth_headers()
	var err := http.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		_generating = false
		generation_failed.emit("Impossible d'envoyer la requête (erreur: %d)" % err, dialogue_uuid)


## Sauvegarde les bytes MP3 dans le fichier spécifié.
## Retourne true si la sauvegarde a réussi.
static func save_mp3(mp3_bytes: PackedByteArray, file_path: String) -> bool:
	var dir_path := file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(mp3_bytes)
	file.close()
	return true


## Supprime un fichier audio.
static func delete_voice_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		return true
	return DirAccess.remove_absolute(file_path) == OK
