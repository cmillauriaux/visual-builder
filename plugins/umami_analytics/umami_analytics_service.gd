extends Node

## Service d'analytics Umami ultra-robuste.
## Envoie des événements à l'API Umami (endpoint /api/send).

const LOG_PATH = "user://umami_debug.log"
const DEVICE_ID_PATH = "user://umami_device_id.txt"
const LOCALSTORAGE_KEY = "umami_device_id"

var _website_id: String = ""
var _umami_url: String = ""
var _enabled: bool = false
var _device_id: String = ""
var _common_metadata: Dictionary = {}
var _user_agent: String = ""

var _request_queue: Array = []
var _is_processing: bool = false
var _http_client: HTTPRequest = null

func _ready() -> void:
	_http_client = HTTPRequest.new()
	_http_client.name = "UmamiHttpClient"
	_http_client.timeout = 10.0
	_http_client.accept_gzip = false # Désactiver gzip pour éviter les problèmes de décompression
	add_child(_http_client)
	_http_client.request_completed.connect(_on_request_completed)


func configure(website_id: String, umami_url: String, enabled: bool) -> void:
	_website_id = website_id.strip_edges()
	_umami_url = umami_url.strip_edges()
	if _umami_url != "" and not _umami_url.ends_with("/api/send"):
		if _umami_url.ends_with("/"):
			_umami_url += "api/send"
		else:
			_umami_url += "/api/send"
	
	_enabled = enabled
	_device_id = _load_or_create_device_id()
	_user_agent = _build_user_agent()
	
	_log("Configuration: ID=%s, URL=%s, Enabled=%s" % [_website_id, _umami_url, str(_enabled)])


func set_common_metadata(metadata: Dictionary) -> void:
	_common_metadata = metadata


func is_active() -> bool:
	return _enabled and _website_id != "" and _umami_url != ""


func is_configured() -> bool:
	return _enabled and _website_id != ""


func track_screen(screen_name: String, title: String = "") -> void:
	if not is_active(): return
	
	var payload = _build_base_payload()
	payload["url"] = "/" + screen_name.replace(" ", "_").to_lower()
	payload["title"] = title if title != "" else screen_name
	_queue_request(payload)


func track_event(event_name: String, body: Dictionary = {}) -> void:
	if not is_active(): return
	
	var event_data = _common_metadata.duplicate()
	event_data.merge(body, true)

	var payload = _build_base_payload()
	payload["name"] = event_name
	payload["data"] = event_data
	_queue_request(payload)


func _build_base_payload() -> Dictionary:
	var os_name = OS.get_name().to_lower().replace(" ", "-")
	# Correction locale : Godot utilise fr_FR, Umami préfère fr-FR
	var locale = OS.get_locale().replace("_", "-")
	
	return {
		"website": _website_id,
		"hostname": "%s.visual-builder.app" % os_name,
		"language": locale,
		"screen": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"url": "/game",
		"referrer": ""
	}


func _queue_request(payload: Dictionary) -> void:
	_request_queue.append(payload)
	_process_queue()


func _process_queue() -> void:
	if _is_processing or _request_queue.is_empty():
		return
	
	_is_processing = true
	var payload = _request_queue[0]
	
	var full_payload = {
		"type": "event",
		"payload": payload
	}
	
	var headers = [
		"Content-Type: application/json",
		"Accept: application/json",
		"User-Agent: " + _user_agent
	]
	
	var json_body = JSON.stringify(full_payload)
	var err = _http_client.request(_umami_url, headers, HTTPClient.METHOD_POST, json_body)
	
	if err != OK:
		_log("ERREUR: Impossible de lancer la requête (%d)" % err)
		_request_queue.remove_at(0)
		_is_processing = false
		# Réessayer au prochain frame si nécessaire
		call_deferred("_process_queue")


func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_log("ERREUR HTTP: Résultat=%d" % result)
	elif response_code < 200 or response_code >= 300:
		_log("ERREUR SERVEUR: Code=%d, Body=%s" % [response_code, body.get_string_from_utf8()])
	else:
		_log("SUCCÈS: Événement envoyé (Code %d)" % response_code)
	
	_request_queue.remove_at(0)
	_is_processing = false
	_process_queue()


func _log(msg: String) -> void:
	var timestamp = Time.get_datetime_string_from_system()
	var line = "[%s] %s" % [timestamp, msg]
	print(line)
	
	var file = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE)
	if file:
		file.seek_end()
		file.store_line(line)
		file.close()


func _build_user_agent() -> String:
	var os_name = OS.get_name()
	var platform = "Unknown"
	match os_name:
		"macOS": platform = "Macintosh; Intel Mac OS X 10_15_7"
		"Windows": platform = "Windows NT 10.0; Win64; x64"
		"Android": platform = "Linux; Android 10"
		"iOS": platform = "iPhone; CPU iPhone OS 14_4 like Mac OS X"
	
	return "Mozilla/5.0 (%s) AppleWebKit/537.36 (KHTML, like Gecko) VisualBuilder/%s" % [
		platform, 
		ProjectSettings.get_setting("application/config/version", "1.0.0")
	]


func _load_or_create_device_id() -> String:
	if OS.has_feature("web"):
		var stored = JavaScriptBridge.eval("localStorage.getItem('%s')" % LOCALSTORAGE_KEY)
		if stored is String and stored != "": return stored
		var new_id = _generate_uuid()
		JavaScriptBridge.eval("localStorage.setItem('%s', '%s')" % [LOCALSTORAGE_KEY, new_id])
		return new_id
	
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var file = FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if file:
			var id = file.get_as_text().strip_edges()
			file.close()
			if id != "": return id
	
	var new_id = _generate_uuid()
	var file = FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
	if file:
		file.store_string(new_id)
		file.close()
	return new_id


static func _generate_uuid() -> String:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var hex = ""
	for i in range(16): hex += "%02x" % rng.randi_range(0, 255)
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
