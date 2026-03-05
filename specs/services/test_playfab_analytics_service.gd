extends GutTest

const PlayFabAnalyticsServiceScript = preload("res://src/services/playfab_analytics_service.gd")

var _service: Node


func before_each():
	_service = Node.new()
	_service.set_script(PlayFabAnalyticsServiceScript)
	add_child_autofree(_service)


# --- configure ---

func test_configure_sets_state():
	_service.configure("ABCDEF", true)
	assert_eq(_service._title_id, "ABCDEF")
	assert_eq(_service._enabled, true)


func test_configure_disabled():
	_service.configure("ABCDEF", false)
	assert_eq(_service._enabled, false)


# --- is_configured ---

func test_is_configured_true():
	_service.configure("ABCDEF", true)
	assert_true(_service.is_configured())


func test_is_configured_false_no_title():
	_service.configure("", true)
	assert_false(_service.is_configured())


func test_is_configured_false_disabled():
	_service.configure("ABCDEF", false)
	assert_false(_service.is_configured())


# --- is_active ---

func test_is_active_false_when_not_logged_in():
	_service.configure("ABCDEF", true)
	assert_false(_service.is_active(), "pas encore loggé → inactif")


func test_is_active_false_when_no_title_id():
	_service.configure("", true)
	_service._logged_in = true
	assert_false(_service.is_active())


func test_is_active_false_when_disabled():
	_service.configure("ABCDEF", false)
	_service._logged_in = true
	assert_false(_service.is_active())


func test_is_active_true_when_logged_in_and_configured():
	_service.configure("ABCDEF", true)
	_service._logged_in = true
	assert_true(_service.is_active())


# --- track_event ---

func test_track_event_queues_event():
	_service.configure("ABCDEF", true)
	_service.track_event("test_event", {"key": "value"})
	var queue = _service.get_event_queue()
	assert_eq(queue.size(), 1)
	assert_eq(queue[0]["EventName"], "test_event")
	assert_eq(queue[0]["Body"]["key"], "value")


func test_track_event_ignored_when_not_configured():
	_service.configure("", false)
	_service.track_event("test_event", {"key": "value"})
	assert_eq(_service.get_event_queue().size(), 0)


func test_track_event_queued_before_login():
	_service.configure("ABCDEF", true)
	# Pas encore loggé, mais configuré → l'event doit être mis en file
	_service.track_event("test_event", {})
	assert_eq(_service.get_event_queue().size(), 1, "event doit être en file même sans login")


func test_track_event_multiple():
	_service.configure("ABCDEF", true)
	_service.track_event("event_1", {})
	_service.track_event("event_2", {"data": 42})
	assert_eq(_service.get_event_queue().size(), 2)
	assert_eq(_service.get_event_queue()[0]["EventName"], "event_1")
	assert_eq(_service.get_event_queue()[1]["EventName"], "event_2")


# --- generate_uuid ---

func test_generate_uuid_format():
	var uuid = PlayFabAnalyticsServiceScript._generate_uuid()
	assert_ne(uuid, "")
	# Format : xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
	var parts = uuid.split("-")
	assert_eq(parts.size(), 5, "UUID doit avoir 5 segments")
	assert_eq(parts[0].length(), 8)
	assert_eq(parts[1].length(), 4)
	assert_eq(parts[2].length(), 4)
	assert_eq(parts[3].length(), 4)
	assert_eq(parts[4].length(), 12)


func test_generate_uuid_unique():
	var uuid1 = PlayFabAnalyticsServiceScript._generate_uuid()
	var uuid2 = PlayFabAnalyticsServiceScript._generate_uuid()
	assert_ne(uuid1, uuid2, "Deux UUIDs doivent être différents")
