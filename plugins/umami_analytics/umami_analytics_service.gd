extends Node

## Service d'analytics Umami.
## Envoie des événements à l'API Umami (endpoint /api/send).
## Ne fait rien si website_id ou umami_url est vide, ou si enabled est false.

const DEVICE_ID_PATH = "user://umami_device_id.txt"
const LOCALSTORAGE_KEY = "umami_device_id"

var _website_id: String = ""
var _umami_url: String = ""
var _enabled: bool = false
var _device_id: String = ""
var _common_metadata: Dictionary = {}
var _user_agent: String = ""

func configure(website_id: String, umami_url: String, enabled: bool) -> void:
	_website_id = website_id
	_umami_url = umami_url
	if not _umami_url.ends_with("/api/send"):
		if _umami_url.ends_with("/"):
			_umami_url += "api/send"
		else:
			_umami_url += "/api/send"
	_enabled = enabled
	_device_id = _load_or_create_device_id()
	_user_agent = _build_user_agent()


func set_common_metadata(metadata: Dictionary) -> void:
	_common_metadata = metadata


func is_active() -> bool:
	return _enabled and _website_id != "" and _umami_url != ""


func is_configured() -> bool:
	return _enabled and _website_id != ""


func track_event(event_name: String, body: Dictionary = {}) -> void:
	if not is_active():
		return
	
	# Enrichir avec les métadonnées communes
	var event_data = _common_metadata.duplicate()
	event_data.merge(body, true)

	var payload = {
		"website": _website_id,
		"hostname": OS.get_name(),
		"language": OS.get_locale(),
		"screen": "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"url": "/game", # Umami nécessite une URL même pour les événements
		"name": event_name,
		"data": event_data
	}
	
	_send_to_umami(payload)


func _send_to_umami(payload: Dictionary) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	
	var full_payload = {
		"type": "event",
		"payload": payload
	}
	
	var headers = [
		"Content-Type: application/json",
		"User-Agent: " + _user_agent
	]
	
	var json_body = JSON.stringify(full_payload)
	http.request_completed.connect(func(_result, response_code, _headers, _body):
		if response_code != 200:
			push_warning("Umami error: Server returned code %d" % response_code)
		http.queue_free()
	)
	
	var error = http.request(_umami_url, headers, HTTPClient.METHOD_POST, json_body)
	if error != OK:
		push_warning("Umami: Failed to start HTTP request")
		http.queue_free()


func _build_user_agent() -> String:
	var os_name = OS.get_name()
	var app_version = ProjectSettings.get_setting("application/config/version", "1.0.0")
	return "VisualBuilder/%s (%s)" % [app_version, os_name]


# --- Device ID (pour la cohérence des sessions si nécessaire, 
# bien qu'Umami utilise souvent IP+UA par défaut) ---

func _load_or_create_device_id() -> String:
	if OS.has_feature("web"):
		var stored = JavaScriptBridge.eval("localStorage.getItem('%s')" % LOCALSTORAGE_KEY)
		if stored is String and stored != "":
			return stored
		var new_id = _generate_uuid()
		JavaScriptBridge.eval("localStorage.setItem('%s', '%s')" % [LOCALSTORAGE_KEY, new_id])
		return new_id
	
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var file = FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		if file:
			var id = file.get_as_text().strip_edges()
			file.close()
			if id != "":
				return id
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
	for i in range(16):
		hex += "%02x" % rng.randi_range(0, 255)
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]
