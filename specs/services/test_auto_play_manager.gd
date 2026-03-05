extends GutTest

const AutoPlayManager = preload("res://src/services/auto_play_manager.gd")

var _manager: RefCounted


func before_each():
	_manager = AutoPlayManager.new()
	_manager.setup(get_tree())


# --- Valeurs par defaut ---

func test_default_enabled():
	assert_eq(_manager.enabled, false)

func test_default_delay():
	assert_eq(_manager.delay, 2.0)


# --- Toggle ---

func test_toggle_enables():
	_manager.toggle()
	assert_eq(_manager.enabled, true)

func test_toggle_twice_disables():
	_manager.toggle()
	_manager.toggle()
	assert_eq(_manager.enabled, false)

func test_toggle_emits_signal_on():
	watch_signals(_manager)
	_manager.toggle()
	assert_signal_emitted_with_parameters(_manager, "auto_play_toggled", [true])

func test_toggle_emits_signal_off():
	_manager.toggle()
	watch_signals(_manager)
	_manager.toggle()
	assert_signal_emitted_with_parameters(_manager, "auto_play_toggled", [false])


# --- Reset ---

func test_reset_disables():
	_manager.toggle()
	_manager.reset()
	assert_eq(_manager.enabled, false)

func test_reset_emits_signal():
	_manager.toggle()
	watch_signals(_manager)
	_manager.reset()
	assert_signal_emitted_with_parameters(_manager, "auto_play_toggled", [false])

func test_reset_when_already_disabled_does_nothing():
	watch_signals(_manager)
	_manager.reset()
	assert_signal_not_emitted(_manager, "auto_play_toggled")


# --- Timer ---

func test_start_timer_does_nothing_when_disabled():
	watch_signals(_manager)
	_manager.start_timer()
	# Wait longer than default delay
	await get_tree().create_timer(0.1).timeout
	assert_signal_not_emitted(_manager, "auto_advance_requested")

func test_start_timer_emits_after_delay():
	_manager.toggle()
	_manager.delay = 0.1
	watch_signals(_manager)
	_manager.start_timer()
	await get_tree().create_timer(0.2).timeout
	assert_signal_emitted(_manager, "auto_advance_requested")

func test_stop_timer_prevents_signal():
	_manager.toggle()
	_manager.delay = 0.2
	watch_signals(_manager)
	_manager.start_timer()
	_manager.stop_timer()
	await get_tree().create_timer(0.3).timeout
	assert_signal_not_emitted(_manager, "auto_advance_requested")

func test_reset_stops_timer():
	_manager.toggle()
	_manager.delay = 0.2
	watch_signals(_manager)
	_manager.start_timer()
	_manager.reset()
	await get_tree().create_timer(0.3).timeout
	assert_signal_not_emitted(_manager, "auto_advance_requested")

func test_start_timer_without_setup_does_nothing():
	var mgr = AutoPlayManager.new()
	mgr.toggle()
	watch_signals(mgr)
	mgr.start_timer()
	assert_signal_not_emitted(mgr, "auto_advance_requested")

func test_custom_delay():
	_manager.toggle()
	_manager.delay = 0.05
	watch_signals(_manager)
	_manager.start_timer()
	await get_tree().create_timer(0.1).timeout
	assert_signal_emitted(_manager, "auto_advance_requested")
