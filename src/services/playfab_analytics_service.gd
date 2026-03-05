extends Node

## Service d'analytics PlayFab léger.
## Gère le login anonyme et l'envoi d'événements via Client/WritePlayerEvent.
## Ne fait rien si title_id est vide ou si enabled est false.

const DEVICE_ID_PATH = "user://playfab_device_id.txt"
const FLUSH_INTERVAL_SEC = 10.0

var _title_id: String = ""
var _enabled: bool = false
var _session_ticket: String = ""
var _device_id: String = ""
var _logged_in: bool = false
var _event_queue: Array = []
var _flush_timer: float = 0.0
var _http_login: HTTPRequest
var _http_pool: Array[HTTPRequest] = []
var _pending_login: bool = false


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
		add_child(_http_login)
	_http_login.request_completed.connect(_on_login_completed, CONNECT_ONE_SHOT)
	_http_login.request(url, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body)


func track_event(event_name: String, body: Dictionary = {}) -> void:
	if not is_configured():
		return
	_event_queue.append({
		"EventName": event_name,
		"Body": body,
	})
	if is_active() and _event_queue.size() >= 10:
		flush()


func flush() -> void:
	if _event_queue.is_empty() or not is_active():
		return
	var events_to_send = _event_queue.duplicate()
	_event_queue.clear()
	_flush_timer = 0.0
	for event in events_to_send:
		_send_single_event(event)


func _send_single_event(event: Dictionary) -> void:
	var url = "https://%s.playfabapi.com/Client/WritePlayerEvent" % _title_id
	var body = JSON.stringify(event)
	var http = _get_http_node()
	http.request_completed.connect(_on_event_completed.bind(http), CONNECT_ONE_SHOT)
	http.request(url, [
		"Content-Type: application/json",
		"X-Authorization: " + _session_ticket,
	], HTTPClient.METHOD_POST, body)


func _get_http_node() -> HTTPRequest:
	# Réutiliser un HTTPRequest libre ou en créer un nouveau
	for h in _http_pool:
		if is_instance_valid(h) and h.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
			return h
	var h = HTTPRequest.new()
	h.name = "HttpEvent_%d" % _http_pool.size()
	add_child(h)
	_http_pool.append(h)
	return h


func _process(delta: float) -> void:
	if not is_active() or _event_queue.is_empty():
		return
	_flush_timer += delta
	if _flush_timer >= FLUSH_INTERVAL_SEC:
		flush()


func get_event_queue() -> Array:
	return _event_queue


func get_session_ticket() -> String:
	return _session_ticket


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
	if data.has("SessionTicket"):
		_session_ticket = data["SessionTicket"]
		_logged_in = true
		print("PlayFab: logged in (PlayFabId: %s)" % data.get("PlayFabId", ""))
		# Flusher les événements mis en file avant la fin du login
		if not _event_queue.is_empty():
			flush()
	else:
		push_warning("PlayFab login: no SessionTicket in response")


func _on_event_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, _http: HTTPRequest) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		var error_detail = ""
		var err_json = JSON.parse_string(body.get_string_from_utf8())
		if err_json is Dictionary:
			error_detail = " — %s: %s" % [err_json.get("error", ""), err_json.get("errorMessage", "")]
		push_warning("PlayFab event send failed: HTTP %d%s" % [response_code, error_detail])


# --- Device ID ---

func _load_or_create_device_id() -> String:
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
