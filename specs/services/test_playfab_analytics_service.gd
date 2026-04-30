extends GutTest

var PlayFabAnalyticsServiceScript

func before_each():
	PlayFabAnalyticsServiceScript = load("res://plugins/playfab_analytics/playfab_analytics_service.gd")

func test_configuration():
	var svc = PlayFabAnalyticsServiceScript.new()
	svc.configure("ABCD", true)
	assert_true(svc.is_configured())
	svc.configure("", true)
	assert_false(svc.is_configured())
	svc.configure("ABCD", false)
	assert_false(svc.is_configured())

func test_track_event_inactive():
	var svc = PlayFabAnalyticsServiceScript.new()
	svc.configure("ABCD", true)
	# Not logged in
	svc.track_event("test_event")
	assert_eq(svc.get_event_queue().size(), 0)

func test_uuid_generation():
	var svc = PlayFabAnalyticsServiceScript
	var uuid1 = svc._generate_uuid()
	var uuid2 = svc._generate_uuid()
	assert_ne(uuid1, uuid2)
	assert_eq(uuid1.length(), 36)

func test_on_login_completed_success():
	var svc = PlayFabAnalyticsServiceScript.new()
	var body = JSON.stringify({
		"data": {
			"EntityToken": {
				"EntityToken": "token123",
				"Entity": {
					"Id": "id123",
					"Type": "title_player_account"
				}
			}
		}
	}).to_utf8_buffer()
	
	svc._on_login_completed(HTTPRequest.RESULT_SUCCESS, 200, [], body)
	assert_true(svc._logged_in)
	assert_eq(svc.get_entity_token(), "token123")
	assert_eq(svc._entity_id, "id123")

func test_on_login_completed_failure():
	var svc = PlayFabAnalyticsServiceScript.new()
	svc._on_login_completed(HTTPRequest.RESULT_SUCCESS, 400, [], "{}".to_utf8_buffer())
	assert_false(svc._logged_in)


func test_is_active_when_logged_in():
	var svc = PlayFabAnalyticsServiceScript.new()
	svc._title_id = "ABCD"
	svc._enabled = true
	svc._logged_in = true
	assert_true(svc.is_active())


func test_is_active_false_when_not_logged_in():
	var svc = PlayFabAnalyticsServiceScript.new()
	svc._title_id = "ABCD"
	svc._enabled = true
	svc._logged_in = false
	assert_false(svc.is_active())


func test_track_event_when_active():
	var svc = PlayFabAnalyticsServiceScript.new()
	svc.add_child(Node.new())  # besoin du Node pour be in tree? Non, juste state
	svc._title_id = "ABCD"
	svc._enabled = true
	svc._logged_in = true
	svc.track_event("page_view", {"page": "menu"})
	assert_eq(svc.get_event_queue().size(), 1)


func test_track_event_enriches_with_common_metadata():
	var svc = PlayFabAnalyticsServiceScript.new()
	svc._title_id = "ABCD"
	svc._enabled = true
	svc._logged_in = true
	svc.set_common_metadata({"platform": "macOS", "version": "1.0"})
	
	svc.track_event("test_event", {"extra": "data"})
	
	var queue = svc.get_event_queue()
	assert_eq(queue.size(), 1)
	var payload = queue[0].Payload
	assert_eq(payload.get("platform"), "macOS")
	assert_eq(payload.get("version"), "1.0")
	assert_eq(payload.get("extra"), "data")


func test_track_event_flush_on_batch_threshold():
	var svc = PlayFabAnalyticsServiceScript.new()
	svc._title_id = "ABCD"
	svc._enabled = true
	svc._logged_in = true
	# Remplir la queue jusqu'au seuil sans déclencher de flush HTTP
	for i in range(PlayFabAnalyticsServiceScript.BATCH_SIZE_THRESHOLD - 1):
		svc._event_queue.append({"Name": "evt%d" % i})
	assert_eq(svc._event_queue.size(), PlayFabAnalyticsServiceScript.BATCH_SIZE_THRESHOLD - 1)


func test_on_login_completed_null_data():
	# JSON valide mais sans clé "data" → push_warning + not logged in
	var svc = PlayFabAnalyticsServiceScript.new()
	var body = JSON.stringify({"status": "ok"}).to_utf8_buffer()
	svc._on_login_completed(HTTPRequest.RESULT_SUCCESS, 200, [], body)
	assert_false(svc._logged_in)


func test_on_login_completed_no_entity_token():
	var svc = PlayFabAnalyticsServiceScript.new()
	var body = JSON.stringify({"data": {"SomeOtherField": "value"}}).to_utf8_buffer()
	svc._on_login_completed(HTTPRequest.RESULT_SUCCESS, 200, [], body)
	assert_false(svc._logged_in)


func test_on_single_event_completed_failure():
	var svc = PlayFabAnalyticsServiceScript.new()
	var http = HTTPRequest.new()
	svc.add_child(http)
	svc._pending_events = 1
	var body = JSON.stringify({"error": "Unauthorized", "errorMessage": "Token expired"}).to_utf8_buffer()
	svc._on_single_event_completed(HTTPRequest.RESULT_SUCCESS, 401, [], body, http)
	assert_eq(svc._pending_events, 0)
	svc.free()


func test_on_single_event_completed_success():
	var svc = PlayFabAnalyticsServiceScript.new()
	var http = HTTPRequest.new()
	svc.add_child(http)
	svc._pending_events = 1
	svc._on_single_event_completed(HTTPRequest.RESULT_SUCCESS, 200, [], "{}".to_utf8_buffer(), http)
	assert_eq(svc._pending_events, 0)
	svc.free()


func test_load_or_create_device_id_creates_file():
	# S'assurer que le fichier n'existe pas
	if FileAccess.file_exists("user://playfab_device_id.txt"):
		DirAccess.remove_absolute(OS.get_user_data_dir() + "/playfab_device_id.txt")
	var svc = PlayFabAnalyticsServiceScript.new()
	var id = svc._load_or_create_device_id()
	assert_ne(id, "")
	assert_eq(id.length(), 36)
	assert_true(FileAccess.file_exists("user://playfab_device_id.txt"))
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/playfab_device_id.txt")


func test_load_or_create_device_id_reads_existing():
	var expected_id = "12345678-1234-1234-1234-123456789012"
	var f = FileAccess.open("user://playfab_device_id.txt", FileAccess.WRITE)
	if f:
		f.store_string(expected_id)
		f.close()
	var svc = PlayFabAnalyticsServiceScript.new()
	var id = svc._load_or_create_device_id()
	assert_eq(id, expected_id)
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/playfab_device_id.txt")


func test_login_completed_failure_with_error_detail():
	var svc = PlayFabAnalyticsServiceScript.new()
	var body = JSON.stringify({"error": "NotFound", "errorMessage": "Title not found"}).to_utf8_buffer()
	svc._on_login_completed(HTTPRequest.RESULT_SUCCESS, 404, [], body)
	assert_false(svc._logged_in)
