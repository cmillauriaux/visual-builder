extends GutTest

## Tests pour les transitions visuelles de foregrounds

const ForegroundTransition = preload("res://src/ui/visual/foreground_transition.gd")
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

func test_fade_out_removed_foreground_with_fade():
	var fg1 = _make_fg("a", "img.png", "fade", 0.8)
	var result = _transition.compute_transitions([fg1], [])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "a")
	assert_eq(result[0]["action"], "fade_out")
	assert_eq(result[0]["duration"], 0.8)

func test_fade_out_always_emitted_for_removed_fg_even_type_none():
	# La disparition est TOUJOURS un fade out, quel que soit le transition_type
	var fg1 = _make_fg("a", "img.png", "none", 0.5)
	var result = _transition.compute_transitions([fg1], [])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "a")
	assert_eq(result[0]["action"], "fade_out")
	assert_eq(result[0]["duration"], 0.5)

func test_replace_fade_same_uuid_different_image():
	# Même UUID, image différente, type fade → replace_fade (nouveau par-dessus)
	var fg_old = _make_fg("a", "old.png", "fade", 0.8)
	var fg_new = _make_fg("a", "new.png", "fade", 0.8)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "a")
	assert_eq(result[0]["action"], "replace_fade")
	assert_eq(result[0]["duration"], 0.8)

func test_replace_instant_same_uuid_different_image_type_none():
	# Même UUID, image différente, type none → replace_instant (ancien par-dessus)
	var fg_old = _make_fg("a", "old.png", "none", 0.5)
	var fg_new = _make_fg("a", "new.png", "none", 0.5)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "a")
	assert_eq(result[0]["action"], "replace_instant")
	assert_eq(result[0]["duration"], 0.5)

func test_replace_instant_uses_old_fg_duration():
	var fg_old = _make_fg("a", "old.png", "none", 1.5)
	var fg_new = _make_fg("a", "new.png", "none", 0.3)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["duration"], 1.5, "replace_instant utilise la durée de l'ancien fg")

func test_no_transition_if_type_none():
	var fg_new = _make_fg("a", "img.png", "none", 0.5)
	var result = _transition.compute_transitions([], [fg_new])
	assert_eq(result.size(), 0, "transition_type=none → pas de transition animée à l'apparition")

func test_no_transition_for_same_image():
	# Même UUID, même image → pas de transition
	var fg = _make_fg("a", "same.png", "fade", 0.5)
	var result = _transition.compute_transitions([fg], [fg])
	assert_eq(result.size(), 0)

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

func test_multiple_mixed_with_removal():
	# Un qui reste, un supprimé (type none), un nouveau (type fade)
	var fg_stay = _make_fg("stay", "stay.png", "none", 0.5)
	var fg_removed = _make_fg("removed", "old.png", "none", 0.5)
	var fg_new = _make_fg("new", "new.png", "fade", 0.5)
	var result = _transition.compute_transitions(
		[fg_stay, fg_removed],
		[fg_stay, fg_new]
	)
	# removed → fade_out (toujours), new → fade_in
	assert_eq(result.size(), 2)
	var actions = {}
	for r in result:
		actions[r["uuid"]] = r["action"]
	assert_eq(actions["removed"], "fade_out")
	assert_eq(actions["new"], "fade_in")

func test_replaced_fg_different_uuids():
	# Ancien et nouveau avec des UUIDs différents → fade_out + fade_in
	var fg_old = _make_fg("a", "old.png", "none", 0.5)
	var fg_new = _make_fg("b", "new.png", "fade", 1.5)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_true(result.size() >= 1)
	var has_fade_out = false
	var has_fade_in = false
	for r in result:
		if r["uuid"] == "a" and r["action"] == "fade_out":
			has_fade_out = true
		if r["uuid"] == "b" and r["action"] == "fade_in":
			has_fade_in = true
			assert_eq(r["duration"], 1.5)
	assert_true(has_fade_out, "L'ancien foreground doit avoir un fade_out")
	assert_true(has_fade_in, "Le nouveau foreground doit avoir un fade_in")

# --- Seen UUIDs (pas de re-fade après première apparition) ---

func test_no_fade_in_if_already_seen():
	var fg = _make_fg("a", "img.png", "fade", 1.0)
	var seen = {"a": true}
	var result = _transition.compute_transitions([], [fg], seen)
	assert_eq(result.size(), 0, "Foreground déjà vu → pas de fade_in")

func test_fade_in_only_first_time_with_seen():
	var fg = _make_fg("a", "img.png", "fade", 1.0)
	# Premier appel sans seen → fade_in
	var result1 = _transition.compute_transitions([], [fg], {})
	assert_eq(result1.size(), 1)
	assert_eq(result1[0]["action"], "fade_in")
	# Deuxième appel avec seen → pas de fade_in
	var result2 = _transition.compute_transitions([], [fg], {"a": true})
	assert_eq(result2.size(), 0)

func test_fade_out_still_works_with_seen():
	var fg = _make_fg("a", "img.png", "fade", 0.5)
	var seen = {"a": true}
	var result = _transition.compute_transitions([fg], [], seen)
	assert_eq(result.size(), 1, "fade_out n'est pas affecté par seen_uuids")
	assert_eq(result[0]["action"], "fade_out")

func test_seen_does_not_affect_type_none():
	var fg = _make_fg("a", "img.png", "none", 0.5)
	var result = _transition.compute_transitions([], [fg], {})
	assert_eq(result.size(), 0, "transition_type=none → jamais de fade_in")

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
