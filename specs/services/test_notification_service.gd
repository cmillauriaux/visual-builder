extends GutTest

const NotificationServiceScript = preload("res://src/services/notification_service.gd")
var _service: RefCounted

func before_each():
	_service = NotificationServiceScript.new()

func test_show_notification_emits_signal():
	watch_signals(_service)
	_service.show_notification("Hello world")
	assert_signal_emitted_with_parameters(_service, "message_requested", ["Hello world"])
