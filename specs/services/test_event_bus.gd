extends GutTest

func test_event_bus_autoload_exists():
	# Les autoloads sont accessibles par leur nom s'ils sont chargés.
	# En test headless avec GUT, il faut s'assurer qu'il est bien là.
	var eb = get_tree().root.get_node_or_null("EventBus")
	assert_not_null(eb, "EventBus should be an Autoload node")

func test_signal_notification_requested():
	var eb = get_tree().root.get_node_or_null("EventBus")
	if eb:
		watch_signals(eb)
		eb.notification_requested.emit("Hello global")
		assert_signal_emitted(eb, "notification_requested")
		assert_signal_emitted_with_parameters(eb, "notification_requested", ["Hello global"])
