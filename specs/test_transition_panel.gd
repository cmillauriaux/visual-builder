extends GutTest

## Tests pour le mini-panel de propriétés de transition d'un foreground

const TransitionPanel = preload("res://src/ui/transition_panel.gd")
const Foreground = preload("res://src/models/foreground.gd")

var _panel: Control = null

func before_each():
	_panel = VBoxContainer.new()
	_panel.set_script(TransitionPanel)
	add_child_autofree(_panel)

# --- Affichage ---

func test_initially_hidden():
	assert_false(_panel.visible)

func test_show_for_foreground():
	var fg = Foreground.new()
	fg.transition_type = "fade"
	fg.transition_duration = 1.0
	_panel.show_for_foreground(fg)
	assert_true(_panel.visible)

func test_hide_panel():
	var fg = Foreground.new()
	_panel.show_for_foreground(fg)
	_panel.hide_panel()
	assert_false(_panel.visible)

# --- Valeurs affichées ---

func test_displays_transition_type():
	var fg = Foreground.new()
	fg.transition_type = "crossfade"
	_panel.show_for_foreground(fg)
	assert_eq(_panel.get_selected_type(), "crossfade")

func test_displays_transition_duration():
	var fg = Foreground.new()
	fg.transition_duration = 2.0
	_panel.show_for_foreground(fg)
	assert_almost_eq(_panel.get_displayed_duration(), 2.0, 0.01)

func test_default_values_displayed():
	var fg = Foreground.new()
	_panel.show_for_foreground(fg)
	assert_eq(_panel.get_selected_type(), "none")
	assert_almost_eq(_panel.get_displayed_duration(), 0.5, 0.01)

# --- Modification ---

func test_change_type_updates_foreground():
	var fg = Foreground.new()
	_panel.show_for_foreground(fg)
	_panel.set_type("fade")
	assert_eq(fg.transition_type, "fade")

func test_change_duration_updates_foreground():
	var fg = Foreground.new()
	_panel.show_for_foreground(fg)
	_panel.set_duration(1.5)
	assert_almost_eq(fg.transition_duration, 1.5, 0.01)

func test_change_type_to_crossfade():
	var fg = Foreground.new()
	_panel.show_for_foreground(fg)
	_panel.set_type("crossfade")
	assert_eq(fg.transition_type, "crossfade")

func test_change_type_to_none():
	var fg = Foreground.new()
	fg.transition_type = "fade"
	_panel.show_for_foreground(fg)
	_panel.set_type("none")
	assert_eq(fg.transition_type, "none")

func test_duration_clamped_on_set():
	var fg = Foreground.new()
	_panel.show_for_foreground(fg)
	_panel.set_duration(10.0)
	assert_eq(fg.transition_duration, 5.0)

# --- Signal ---

func test_emits_changed_on_type():
	var fg = Foreground.new()
	_panel.show_for_foreground(fg)
	watch_signals(_panel)
	_panel.set_type("fade")
	assert_signal_emitted(_panel, "transition_changed")

func test_emits_changed_on_duration():
	var fg = Foreground.new()
	_panel.show_for_foreground(fg)
	watch_signals(_panel)
	_panel.set_duration(2.0)
	assert_signal_emitted(_panel, "transition_changed")

# --- Show pour null ---

func test_show_for_null_hides():
	_panel.show_for_foreground(null)
	assert_false(_panel.visible)
