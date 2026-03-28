extends Node

## Client HTTP pour l'API ElevenLabs Text-to-Dialogue (Eleven v3).
## Utilise l'endpoint /v1/text-to-dialogue qui accepte un tableau d'inputs
## avec voice_id par segment, permettant le dialogue multi-personnages.

const ElevenLabsConfig = preload("res://plugins/voice_studio/elevenlabs_config.gd")

const BASE_URL := "https://api.elevenlabs.io/v1"

signal generation_completed(mp3_bytes: PackedByteArray, request_id: String)
signal generation_failed(error: String, request_id: String)
signal generation_progress(status: String, request_id: String)

var _config: RefCounted = null
var _generating: bool = false


func setup(config: RefCounted) -> void:
	_config = config


func is_generating() -> bool:
	return _generating


## Génère la voix pour un dialogue unique via text-to-dialogue.
## voice_id : identifiant de la voix ElevenLabs du personnage
## text : texte à synthétiser (peut inclure des annotations [sarcastically], etc.)
## request_id : identifiant de la requête (UUID du dialogue)
func generate_voice(voice_id: String, text: String, request_id: String) -> void:
	var inputs := [{"text": text, "voice_id": voice_id}]
	generate_dialogue(inputs, request_id)


## Génère un dialogue multi-personnages en une seule requête.
## inputs : Array de {"text": String, "voice_id": String}
## request_id : identifiant de la requête (pour identifier la réponse)
func generate_dialogue(inputs: Array, request_id: String) -> void:
	if _config == null:
		generation_failed.emit("Configuration non initialisée", request_id)
		return
	if _config.get_api_key() == "":
		generation_failed.emit("Clé API ElevenLabs non configurée", request_id)
		return
	if inputs.is_empty():
		generation_failed.emit("Aucun input fourni", request_id)
		return

	# Valider les inputs
	for input in inputs:
		if not input is Dictionary:
			generation_failed.emit("Input invalide", request_id)
			return
		if input.get("voice_id", "") == "":
			generation_failed.emit("Voice ID non défini pour un personnage", request_id)
			return
		if input.get("text", "").strip_edges() == "":
			generation_failed.emit("Texte vide dans un input", request_id)
			return

	_generating = true
	generation_progress.emit("Génération en cours...", request_id)

	var url := "%s/text-to-dialogue" % BASE_URL
	var body := {
		"model_id": _config.get_model_id(),
		"inputs": inputs,
	}
	var lang: String = _config.get_language_code()
	if lang != "":
		body["language_code"] = lang
	var payload := JSON.stringify(body)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, response_body: PackedByteArray):
		http.queue_free()
		_generating = false
		if result != HTTPRequest.RESULT_SUCCESS:
			generation_failed.emit("Erreur réseau (code: %d)" % result, request_id)
			return
		if code != 200:
			var error_msg := "Erreur API ElevenLabs (HTTP %d)" % code
			var parsed = JSON.parse_string(response_body.get_string_from_utf8())
			if parsed is Dictionary and parsed.has("detail"):
				var detail = parsed["detail"]
				if detail is Dictionary and detail.has("message"):
					error_msg += ": " + str(detail["message"])
				else:
					error_msg += ": " + str(detail)
			generation_failed.emit(error_msg, request_id)
			return
		generation_completed.emit(response_body, request_id)
	)

	var headers: PackedStringArray = _config.get_auth_headers()
	var err := http.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		_generating = false
		generation_failed.emit("Impossible d'envoyer la requête (erreur: %d)" % err, request_id)


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
