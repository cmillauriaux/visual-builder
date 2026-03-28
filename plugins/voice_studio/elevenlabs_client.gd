extends Node

## Client HTTP pour l'API ElevenLabs Text-to-Speech.
## Utilise POST /v1/text-to-speech/{voice_id} avec voice_settings,
## previous_text, next_text et previous_request_ids pour la continuité.

const ElevenLabsConfig = preload("res://plugins/voice_studio/elevenlabs_config.gd")

const BASE_URL := "https://api.elevenlabs.io/v1"

signal generation_completed(mp3_bytes: PackedByteArray, request_id: String, dialogue_uuid: String)
signal generation_failed(error: String, dialogue_uuid: String)
signal generation_progress(status: String, dialogue_uuid: String)

var _config: RefCounted = null
var _generating: bool = false


func setup(config: RefCounted) -> void:
	_config = config


func is_generating() -> bool:
	return _generating


## Génère la voix pour un dialogue.
## voice_id : identifiant de la voix ElevenLabs
## text : texte à synthétiser
## dialogue_uuid : UUID du dialogue (pour identifier la réponse)
## voice_settings : override des paramètres voix (ou {} pour utiliser les defaults config)
## previous_text : texte du dialogue précédent (continuité)
## next_text : texte du dialogue suivant (continuité)
## previous_request_ids : IDs des requêtes précédentes (max 3, continuité)
func generate_voice(voice_id: String, text: String, dialogue_uuid: String,
		voice_settings: Dictionary = {}, previous_text: String = "",
		next_text: String = "", previous_request_ids: Array = []) -> void:
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

	var output_format: String = _config.get_output_format()
	var url := "%s/text-to-speech/%s?output_format=%s" % [BASE_URL, voice_id, output_format]

	# Build request body
	var body := {
		"text": text,
		"model_id": _config.get_model_id(),
	}

	# Voice settings: merge defaults from config with overrides
	var settings: Dictionary = _config.get_voice_settings()
	for key in voice_settings:
		settings[key] = voice_settings[key]
	body["voice_settings"] = settings

	# Language code
	var lang: String = _config.get_language_code()
	if lang != "":
		body["language_code"] = lang

	# Continuity: previous_text/next_text not supported by eleven_v3
	# but previous_request_ids IS supported by all models
	var model: String = _config.get_model_id()
	if not model.begins_with("eleven_v3"):
		if previous_text != "":
			body["previous_text"] = previous_text
		if next_text != "":
			body["next_text"] = next_text
	if not previous_request_ids.is_empty():
		var ids: Array = previous_request_ids.slice(0, 3) if previous_request_ids.size() > 3 else previous_request_ids
		body["previous_request_ids"] = ids

	var payload := JSON.stringify(body)
	print("[VoiceStudio] POST %s" % url)
	print("[VoiceStudio] body: %s" % payload)

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, resp_headers: PackedStringArray, resp_body: PackedByteArray):
		http.queue_free()
		_generating = false
		print("[VoiceStudio] Response: result=%d code=%d body_size=%d" % [result, code, resp_body.size()])
		if result != HTTPRequest.RESULT_SUCCESS:
			print("[VoiceStudio] ERROR: network result=%d" % result)
			generation_failed.emit("Erreur réseau (code: %d)" % result, dialogue_uuid)
			return
		if code != 200:
			var error_msg := "Erreur API ElevenLabs (HTTP %d)" % code
			var resp_text: String = resp_body.get_string_from_utf8()
			print("[VoiceStudio] ERROR: %s — %s" % [error_msg, resp_text])
			var parsed = JSON.parse_string(resp_text)
			if parsed is Dictionary and parsed.has("detail"):
				var detail = parsed["detail"]
				if detail is Dictionary and detail.has("message"):
					error_msg += ": " + str(detail["message"])
				else:
					error_msg += ": " + str(detail)
			generation_failed.emit(error_msg, dialogue_uuid)
			return
		var req_id := _extract_request_id(resp_headers)
		print("[VoiceStudio] OK: request_id=%s audio_bytes=%d" % [req_id, resp_body.size()])
		generation_completed.emit(resp_body, req_id, dialogue_uuid)
	)

	var headers: PackedStringArray = _config.get_auth_headers()
	var err := http.request(url, headers, HTTPClient.METHOD_POST, payload)
	if err != OK:
		http.queue_free()
		_generating = false
		generation_failed.emit("Impossible d'envoyer la requête (erreur: %d)" % err, dialogue_uuid)


static func _extract_request_id(headers: PackedStringArray) -> String:
	for h in headers:
		var lower: String = h.to_lower()
		if lower.begins_with("request-id:") or lower.begins_with("x-request-id:"):
			return h.substr(h.find(":") + 1).strip_edges()
	return ""


## Sauvegarde les bytes audio dans le fichier spécifié.
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
