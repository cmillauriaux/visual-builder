extends Node

## Service d'analytics PlayFab léger.
## Gère le login anonyme et l'envoi d'événements de télémétrie via l'API REST PlayFab.
## Ne fait rien si title_id est vide ou si enabled est false.

const DEVICE_ID_PATH = "user://playfab_device_id.txt"
const LOCALSTORAGE_KEY = "playfab_device_id"
const BATCH_SIZE_THRESHOLD = 10
const FLUSH_INTERVAL_SEC = 10.0
const MAX_BATCH_SIZE = 200

var _title_id: String = ""
var _enabled: bool = false
var _entity_token: String = ""
var _entity_id: String = ""
var _entity_type: String = ""
var _device_id: String = ""
var _logged_in: bool = false
var _event_queue: Array = []
var _flush_timer: float = 0.0
var _http_login: HTTPRequest
var _pending_login: bool = false
var _pending_events: int = 0


func configure(title_id: String, enabled: bool) -> void:
	_title_id = title_id
	_enabled = enabled


func is_active() -> bool:
	return _enabled and _title_id != "" and _logged_in


func is_configured() -> bool:
	return _enabled and _title_id != ""


func login_anonymous() -> void:
	if not is_configured():
		return
	if _pending_login or _logged_in:
		return
	_device_id = _load_or_create_device_id()
	_pending_login = true
	var url = "https://%s.playfabapi.com/Client/LoginWithCustomID" % _title_id
	var body = JSON.stringify({
		"TitleId": _title_id,
		"CustomId": _device_id,
		"CreateAccount": true,
	})
	if _http_login == null:
		_http_login = HTTPRequest.new()
		_http_login.name = "HttpLogin"
		_http_login.accept_gzip = false
		add_child(_http_login)
	_http_login.request_completed.connect(_on_login_completed, CONNECT_ONE_SHOT)
	_http_login.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func track_event(event_name: String, body: Dictionary = {}) -> void:
	if not is_active():
		return
	_event_queue.append({
		"EventNamespace": "custom.visualbuilder",
		"Name": event_name,
		"Payload": body,
		"Entity": {
			"Id": _entity_id,
			"Type": _entity_type,
		},
	})
	if _event_queue.size() >= BATCH_SIZE_THRESHOLD:
		flush()


func flush() -> void:
	if _event_queue.is_empty() or not is_active():
		return
	var events_to_send = _event_queue.slice(0, MAX_BATCH_SIZE)
	_event_queue = _event_queue.slice(MAX_BATCH_SIZE)
	_flush_timer = 0.0
	var url = "https://%s.playfabapi.com/Event/WriteEvents" % _title_id
	var headers = [
		"Content-Type: application/json",
		"X-EntityToken: " + _entity_token,
	]
	_pending_events += events_to_send.size()
	for i in range(events_to_send.size()):
		var http = HTTPRequest.new()
		http.name = "HttpEvent_%d" % i
		http.accept_gzip = false
		add_child(http)
		http.request_completed.connect(_on_single_event_completed.bind(http), CONNECT_ONE_SHOT)
		var body = JSON.stringify({"Events": [events_to_send[i]]})
		http.request(url, headers, HTTPClient.METHOD_POST, body)


func _process(delta: float) -> void:
	if not is_active() or _event_queue.is_empty():
		return
	_flush_timer += delta
	if _flush_timer >= FLUSH_INTERVAL_SEC:
		flush()


func get_event_queue() -> Array:
	return _event_queue


func get_entity_token() -> String:
	return _entity_token


# --- Callbacks ---

func _on_login_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_pending_login = false
	var body_text = body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error_detail = ""
		var err_json = JSON.parse_string(body_text)
		if err_json is Dictionary:
			error_detail = " — %s: %s" % [err_json.get("error", ""), err_json.get("errorMessage", "")]
		push_warning("PlayFab login failed: HTTP %d%s" % [response_code, error_detail])
		return
	var json = JSON.parse_string(body_text)
	if json == null or not json.has("data"):
		push_warning("PlayFab login: invalid response")
		return
	var data = json["data"]
	if data.has("EntityToken") and data["EntityToken"].has("EntityToken"):
		_entity_token = data["EntityToken"]["EntityToken"]
		if data["EntityToken"].has("Entity"):
			_entity_id = data["EntityToken"]["Entity"].get("Id", "")
			_entity_type = data["EntityToken"]["Entity"].get("Type", "")
		_logged_in = true
		print("PlayFab: logged in (entity: %s)" % _entity_id)
	else:
		push_warning("PlayFab login: no entity token in response")


func _on_single_event_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error_detail = ""
		var err_json = JSON.parse_string(body.get_string_from_utf8())
		if err_json is Dictionary:
			error_detail = " — %s: %s" % [err_json.get("error", ""), err_json.get("errorMessage", "")]
		push_warning("PlayFab event failed: HTTP %d%s" % [response_code, error_detail])
	_pending_events -= 1
	http.queue_free()


# --- Device ID ---

func _load_or_create_device_id() -> String:
	# Sur le web, utiliser localStorage (plus fiable que IndexedDB/user://)
	if OS.has_feature("web"):
		var stored = JavaScriptBridge.eval("localStorage.getItem('%s')" % LOCALSTORAGE_KEY)
		if stored is String and stored != "":
			return stored
		var new_id = _generate_uuid()
		JavaScriptBridge.eval("localStorage.setItem('%s', '%s')" % [LOCALSTORAGE_KEY, new_id])
		return new_id
	# Sur les plateformes natives, utiliser le fichier classique
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
