extends GutTest

var PlayFabAnalyticsServiceScript

func before_each():
	PlayFabAnalyticsServiceScript = load("res://src/services/playfab_analytics_service.gd")

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
