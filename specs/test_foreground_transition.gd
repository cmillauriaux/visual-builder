extends GutTest

## Tests pour les transitions visuelles de foregrounds

const ForegroundTransition = preload("res://src/ui/foreground_transition.gd")
const Foreground = preload("res://src/models/foreground.gd")

var _transition: Node = null

func before_each():
	_transition = Node.new()
	_transition.set_script(ForegroundTransition)
	add_child_autofree(_transition)

# --- Calcul des transitions ---

func test_no_transition_needed_same_foregrounds():
	var fg1 = _make_fg("a", "img.png", "none", 0.5)
	var result = _transition.compute_transitions([fg1], [fg1])
	assert_eq(result.size(), 0, "Même foreground → pas de transition")

func test_fade_in_new_foreground():
	var fg1 = _make_fg("a", "img.png", "fade", 1.0)
	var result = _transition.compute_transitions([], [fg1])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "a")
	assert_eq(result[0]["action"], "fade_in")
	assert_eq(result[0]["duration"], 1.0)

func test_fade_out_removed_foreground():
	var fg1 = _make_fg("a", "img.png", "fade", 0.8)
	var result = _transition.compute_transitions([fg1], [])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "a")
	assert_eq(result[0]["action"], "fade_out")
	assert_eq(result[0]["duration"], 0.8)

func test_crossfade_replaced_foreground():
	var fg_old = _make_fg("a", "old.png", "none", 0.5)
	var fg_new = _make_fg("b", "new.png", "crossfade", 1.5)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	# fg_old doit disparaître (fade_out), fg_new doit apparaître (fade_in)
	assert_true(result.size() >= 1)
	var has_fade_in = false
	for r in result:
		if r["uuid"] == "b" and r["action"] == "fade_in":
			has_fade_in = true
			assert_eq(r["duration"], 1.5)
	assert_true(has_fade_in, "Le nouveau foreground doit avoir un fade_in")

func test_crossfade_same_uuid_different_image():
	# Même UUID, image différente, type crossfade → action crossfade avec old_image
	var fg_old = _make_fg("a", "old.png", "crossfade", 1.0)
	var fg_new = _make_fg("a", "new.png", "crossfade", 1.0)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "a")
	assert_eq(result[0]["action"], "crossfade")
	assert_eq(result[0]["old_image"], "old.png")
	assert_eq(result[0]["duration"], 1.0)

func test_fade_same_uuid_different_image():
	# Même UUID, image différente, type fade → action fade_in (pas crossfade)
	var fg_old = _make_fg("a", "old.png", "fade", 0.8)
	var fg_new = _make_fg("a", "new.png", "fade", 0.8)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "a")
	assert_eq(result[0]["action"], "fade_in")
	assert_eq(result[0]["duration"], 0.8)

func test_no_transition_if_type_none():
	var fg_new = _make_fg("a", "img.png", "none", 0.5)
	var result = _transition.compute_transitions([], [fg_new])
	assert_eq(result.size(), 0, "transition_type=none → pas de transition animée")

func test_transition_with_changed_image():
	# Même UUID mais image différente → transition
	var fg_old = _make_fg("a", "old.png", "none", 0.5)
	var fg_new = _make_fg("a", "new.png", "fade", 1.0)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_true(result.size() > 0)

func test_multiple_foregrounds_mixed():
	var fg_stay = _make_fg("stay", "stay.png", "none", 0.5)
	var fg_new = _make_fg("new", "new.png", "fade", 0.5)
	var result = _transition.compute_transitions([fg_stay], [fg_stay, fg_new])
	# Seul le nouveau doit avoir une transition
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "new")

# --- Application de transition sur un Control ---

func test_apply_fade_in():
	var target = Control.new()
	add_child_autofree(target)
	target.modulate.a = 0.0
	_transition.apply_instant_fade_in(target)
	# Après apply_instant (pour test), alpha doit être 1
	assert_eq(target.modulate.a, 1.0)

func test_apply_fade_out():
	var target = Control.new()
	add_child_autofree(target)
	target.modulate.a = 1.0
	_transition.apply_instant_fade_out(target)
	assert_eq(target.modulate.a, 0.0)

# --- Helper ---

func _make_fg(uuid: String, image: String, trans_type: String, trans_dur: float):
	var fg = Foreground.new()
	fg.uuid = uuid
	fg.image = image
	fg.transition_type = trans_type
	fg.transition_duration = trans_dur
	return fg
