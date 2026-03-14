extends GutTest

## Tests pour les transitions visuelles de foregrounds

var ForegroundTransition = load("res://src/ui/visual/foreground_transition.gd")
var Foreground = load("res://src/models/foreground.gd")

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
	# Positions éloignées pour éviter le matching par position (morph)
	var fg_stay = _make_fg("stay", "stay.png", "none", 0.5)
	var fg_removed = _make_fg("removed", "old.png", "none", 0.5)
	fg_removed.anchor_bg = Vector2(0.90, 0.90)
	var fg_new = _make_fg("new", "new.png", "fade", 0.5)
	fg_new.anchor_bg = Vector2(0.10, 0.10)
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
	# Ancien et nouveau avec des UUIDs différents, positions éloignées → fade_out + fade_in
	var fg_old = _make_fg("a", "old.png", "none", 0.5)
	fg_old.anchor_bg = Vector2(0.10, 0.50)
	var fg_new = _make_fg("b", "new.png", "fade", 1.5)
	fg_new.anchor_bg = Vector2(0.90, 0.50)
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

# --- z_order dans les transitions ---

func test_fade_in_includes_z_order():
	var fg = _make_fg("a", "img.png", "fade", 0.5, 5)
	var result = _transition.compute_transitions([], [fg])
	assert_eq(result[0]["z_order"], 5)

func test_fade_out_includes_z_order():
	var fg = _make_fg("a", "img.png", "none", 0.5, -3)
	var result = _transition.compute_transitions([fg], [])
	assert_eq(result[0]["z_order"], -3)

func test_replace_fade_includes_z_order():
	var fg_old = _make_fg("a", "old.png", "fade", 0.5, 7)
	var fg_new = _make_fg("a", "new.png", "fade", 0.5, 7)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result[0]["z_order"], 7)

func test_replace_instant_includes_z_order():
	var fg_old = _make_fg("a", "old.png", "none", 0.5, 2)
	var fg_new = _make_fg("a", "new.png", "none", 0.5, 2)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result[0]["z_order"], 2)

func test_mixed_transitions_preserve_z_order():
	var fg_removed = _make_fg("removed", "old.png", "none", 0.5, -1)
	var fg_stay = _make_fg("stay", "stay.png", "none", 0.5, 0)
	var fg_new = _make_fg("new", "new.png", "fade", 0.5, 10)
	var result = _transition.compute_transitions(
		[fg_stay, fg_removed],
		[fg_stay, fg_new]
	)
	for r in result:
		if r["uuid"] == "removed":
			assert_eq(r["z_order"], -1, "fade_out garde le z_order de l'ancien FG")
		elif r["uuid"] == "new":
			assert_eq(r["z_order"], 10, "fade_in a le z_order du nouveau FG")

# --- Matching visuel (UUIDs différents mais même image/position) ---

func test_no_transition_when_visually_equivalent_different_uuid():
	# Même image, même position, UUID différent → pas de transition
	var fg_old = _make_fg("a", "img.png", "fade", 0.5)
	var fg_new = _make_fg("b", "img.png", "fade", 0.5)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 0, "Visuellement identique → pas de transition")

func test_transition_when_different_image_different_uuid():
	# Image différente, UUID différent → fade_out + fade_in
	var fg_old = _make_fg("a", "old.png", "fade", 0.5)
	var fg_new = _make_fg("b", "new.png", "fade", 0.5)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_true(result.size() >= 1, "Image différente → transition nécessaire")

func test_transition_when_position_changed_different_uuid():
	# Même image mais position différente → transition
	var fg_old = _make_fg("a", "img.png", "fade", 0.5)
	fg_old.anchor_bg = Vector2(0.2, 0.5)
	var fg_new = _make_fg("b", "img.png", "fade", 0.5)
	fg_new.anchor_bg = Vector2(0.8, 0.5)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_true(result.size() >= 1, "Position différente → transition nécessaire")

func test_transition_when_scale_changed_different_uuid():
	# Même image mais scale différent → transition
	var fg_old = _make_fg("a", "img.png", "fade", 0.5)
	fg_old.scale = 1.0
	var fg_new = _make_fg("b", "img.png", "fade", 0.5)
	fg_new.scale = 2.0
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_true(result.size() >= 1, "Scale différent → transition nécessaire")

func test_transition_when_flip_changed_different_uuid():
	# Même image mais flip différent → transition
	var fg_old = _make_fg("a", "img.png", "fade", 0.5)
	fg_old.flip_h = false
	var fg_new = _make_fg("b", "img.png", "fade", 0.5)
	fg_new.flip_h = true
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_true(result.size() >= 1, "Flip différent → transition nécessaire")

func test_visual_matching_multiple_foregrounds():
	# 3 FGs : décor (inchangé), personnage A → B (image change, position similaire)
	var decor_old = _make_fg("d1", "decor.png", "fade", 0.5)
	decor_old.anchor_bg = Vector2(0.50, 0.50)
	var char_old = _make_fg("c1", "charA.png", "fade", 0.5)
	char_old.anchor_bg = Vector2(0.30, 0.70)
	var decor_new = _make_fg("d2", "decor.png", "fade", 0.5)
	decor_new.anchor_bg = Vector2(0.50, 0.50)
	var char_new = _make_fg("c2", "charB.png", "fade", 0.5)
	char_new.anchor_bg = Vector2(0.30, 0.70)
	var result = _transition.compute_transitions(
		[decor_old, char_old],
		[decor_new, char_new]
	)
	# Le décor ne doit PAS avoir de transition (visuellement identique)
	# Le personnage → morph (position similaire, image différente)
	for r in result:
		assert_ne(r["uuid"], "d1", "Décor ancien ne doit pas avoir de transition")
		assert_ne(r["uuid"], "d2", "Décor nouveau ne doit pas avoir de transition")
	assert_eq(result.size(), 1)
	assert_eq(result[0]["uuid"], "c2")
	assert_eq(result[0]["action"], "morph")

func test_visual_matching_does_not_match_same_image_different_position():
	# Deux FGs avec même image mais positions différentes ne doivent pas se matcher
	var fg_old = _make_fg("a", "char.png", "fade", 0.5)
	fg_old.anchor_bg = Vector2(0.2, 0.5)
	var fg_new = _make_fg("b", "char.png", "fade", 0.5)
	fg_new.anchor_bg = Vector2(0.8, 0.5)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 2, "Même image mais position différente → fade_out + fade_in")

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

# --- Matching par position (morph) ---

func test_morph_generated_when_position_similar_different_uuid():
	# Deux FGs avec UUIDs différents, images différentes, position similaire → morph
	var fg_old = _make_fg("a", "smile.png", "none", 0.5)
	fg_old.anchor_bg = Vector2(0.50, 0.60)
	var fg_new = _make_fg("b", "sad.png", "fade", 0.8)
	fg_new.anchor_bg = Vector2(0.55, 0.65)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["action"], "morph")
	assert_eq(result[0]["uuid"], "b")
	assert_eq(result[0]["old_uuid"], "a")


func test_morph_uses_new_fg_duration():
	var fg_old = _make_fg("a", "smile.png", "none", 1.0)
	fg_old.anchor_bg = Vector2(0.50, 0.60)
	var fg_new = _make_fg("b", "sad.png", "fade", 0.8)
	fg_new.anchor_bg = Vector2(0.50, 0.60)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result[0]["duration"], 0.8, "morph utilise la durée du nouveau fg")


func test_morph_independent_of_image():
	# Même image, position similaire → morph (pas d'équivalence visuelle car scale différent)
	var fg_old = _make_fg("a", "char.png", "none", 0.5)
	fg_old.anchor_bg = Vector2(0.50, 0.60)
	fg_old.scale = 1.0
	var fg_new = _make_fg("b", "char.png", "none", 0.5)
	fg_new.anchor_bg = Vector2(0.55, 0.60)
	fg_new.scale = 2.0
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["action"], "morph")


func test_morph_independent_of_transition_type():
	# transition_type=none sur les deux → morph quand même
	var fg_old = _make_fg("a", "a.png", "none", 0.5)
	fg_old.anchor_bg = Vector2(0.50, 0.60)
	var fg_new = _make_fg("b", "b.png", "none", 0.5)
	fg_new.anchor_bg = Vector2(0.50, 0.60)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["action"], "morph")


func test_no_morph_when_position_beyond_threshold():
	# Position trop éloignée (> 0.15 sur un axe) → fade_out + fade_in, pas de morph
	var fg_old = _make_fg("a", "a.png", "fade", 0.5)
	fg_old.anchor_bg = Vector2(0.20, 0.50)
	var fg_new = _make_fg("b", "b.png", "fade", 0.5)
	fg_new.anchor_bg = Vector2(0.50, 0.50)  # delta x = 0.30 > 0.15
	var result = _transition.compute_transitions([fg_old], [fg_new])
	var actions = {}
	for r in result:
		actions[r["uuid"]] = r["action"]
	assert_false(actions.values().has("morph"), "Position trop éloignée → pas de morph")
	assert_eq(actions.get("a"), "fade_out")
	assert_eq(actions.get("b"), "fade_in")


func test_morph_at_threshold_boundary():
	# Distance exactement 0.15 → morph (seuil inclusif)
	var fg_old = _make_fg("a", "a.png", "none", 0.5)
	fg_old.anchor_bg = Vector2(0.50, 0.50)
	var fg_new = _make_fg("b", "b.png", "none", 0.5)
	fg_new.anchor_bg = Vector2(0.65, 0.50)  # delta x = 0.15, delta y = 0.0
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["action"], "morph")


func test_morph_matching_is_1_to_1():
	# 2 old, 2 new → chaque ancien matche au plus un nouveau
	var old_a = _make_fg("a", "a.png", "none", 0.5)
	old_a.anchor_bg = Vector2(0.30, 0.50)
	var old_b = _make_fg("b", "b.png", "none", 0.5)
	old_b.anchor_bg = Vector2(0.70, 0.50)
	var new_c = _make_fg("c", "c.png", "none", 0.5)
	new_c.anchor_bg = Vector2(0.32, 0.50)  # proche de old_a
	var new_d = _make_fg("d", "d.png", "none", 0.5)
	new_d.anchor_bg = Vector2(0.72, 0.50)  # proche de old_b
	var result = _transition.compute_transitions([old_a, old_b], [new_c, new_d])
	assert_eq(result.size(), 2)
	var morphs = result.filter(func(r): return r["action"] == "morph")
	assert_eq(morphs.size(), 2, "Deux morphs 1:1")
	# Vérifier que chaque ancien a matché un seul nouveau
	var old_uuids = morphs.map(func(m): return m["old_uuid"])
	assert_true(old_uuids.has("a"))
	assert_true(old_uuids.has("b"))


func test_morph_1_to_1_no_double_match():
	# Un old qui est proche de deux new → seul le premier new matche
	var old_a = _make_fg("a", "a.png", "none", 0.5)
	old_a.anchor_bg = Vector2(0.50, 0.50)
	var new_b = _make_fg("b", "b.png", "none", 0.5)
	new_b.anchor_bg = Vector2(0.50, 0.50)
	var new_c = _make_fg("c", "c.png", "fade", 0.5)
	new_c.anchor_bg = Vector2(0.50, 0.50)
	var result = _transition.compute_transitions([old_a], [new_b, new_c])
	var morphs = result.filter(func(r): return r["action"] == "morph")
	assert_eq(morphs.size(), 1, "Un seul morph pour un seul old")


func test_morph_after_uuid_matching():
	# UUID match a priority : même UUID → replace_fade, pas morph
	var fg_old = _make_fg("a", "old.png", "fade", 0.5)
	fg_old.anchor_bg = Vector2(0.50, 0.50)
	var fg_new = _make_fg("a", "new.png", "fade", 0.5)
	fg_new.anchor_bg = Vector2(0.50, 0.50)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 1)
	assert_eq(result[0]["action"], "replace_fade", "UUID match → replace_fade, pas morph")


func test_morph_after_visual_equivalence():
	# Visuellement identique → pas de transition, pas de morph
	var fg_old = _make_fg("a", "img.png", "fade", 0.5)
	fg_old.anchor_bg = Vector2(0.50, 0.50)
	var fg_new = _make_fg("b", "img.png", "fade", 0.5)
	fg_new.anchor_bg = Vector2(0.50, 0.50)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result.size(), 0, "Visuellement identique → pas de transition")


func test_morph_includes_image_changed_flag():
	# Quand l'image change, le morph doit le signaler
	var fg_old = _make_fg("a", "smile.png", "none", 0.5)
	fg_old.anchor_bg = Vector2(0.50, 0.50)
	var fg_new = _make_fg("b", "sad.png", "none", 0.5)
	fg_new.anchor_bg = Vector2(0.50, 0.50)
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result[0]["action"], "morph")
	assert_true(result[0]["image_changed"])


func test_morph_image_changed_false_when_same():
	var fg_old = _make_fg("a", "char.png", "none", 0.5)
	fg_old.anchor_bg = Vector2(0.50, 0.50)
	fg_old.scale = 1.0
	var fg_new = _make_fg("b", "char.png", "none", 0.5)
	fg_new.anchor_bg = Vector2(0.55, 0.50)
	fg_new.scale = 2.0
	var result = _transition.compute_transitions([fg_old], [fg_new])
	assert_eq(result[0]["action"], "morph")
	assert_false(result[0]["image_changed"])


func test_morph_includes_old_properties():
	var fg_old = _make_fg("a", "a.png", "none", 0.5, 3)
	fg_old.anchor_bg = Vector2(0.30, 0.40)
	fg_old.scale = 1.5
	fg_old.opacity = 0.8
	fg_old.flip_h = true
	fg_old.flip_v = false
	var fg_new = _make_fg("b", "b.png", "none", 0.7, 5)
	fg_new.anchor_bg = Vector2(0.35, 0.45)
	fg_new.scale = 2.0
	fg_new.flip_h = false
	fg_new.flip_v = true
	var result = _transition.compute_transitions([fg_old], [fg_new])
	var m = result[0]
	assert_eq(m["old_anchor_bg"], Vector2(0.30, 0.40))
	assert_almost_eq(m["old_scale"], 1.5, 0.001)
	assert_almost_eq(m["old_opacity"], 0.8, 0.001)
	assert_true(m["old_flip_h"])
	assert_false(m["old_flip_v"])
	assert_eq(m["old_z_order"], 3)
	assert_eq(m["z_order"], 5)


func test_morph_no_regression_existing_transitions():
	# Cas mixte : UUID match + visuel identique + morph + fade_out + fade_in
	var fg_uuid_old = _make_fg("uuid1", "old.png", "fade", 0.5)
	var fg_uuid_new = _make_fg("uuid1", "new.png", "fade", 0.5)
	var fg_visual_old = _make_fg("v1", "decor.png", "fade", 0.5)
	var fg_visual_new = _make_fg("v2", "decor.png", "fade", 0.5)
	var fg_morph_old = _make_fg("m1", "smile.png", "none", 0.5)
	fg_morph_old.anchor_bg = Vector2(0.40, 0.50)
	var fg_morph_new = _make_fg("m2", "sad.png", "none", 0.5)
	fg_morph_new.anchor_bg = Vector2(0.42, 0.52)
	var fg_removed = _make_fg("r1", "gone.png", "none", 0.5)
	fg_removed.anchor_bg = Vector2(0.90, 0.90)
	var fg_added = _make_fg("a1", "appear.png", "fade", 0.5)
	fg_added.anchor_bg = Vector2(0.10, 0.10)
	var result = _transition.compute_transitions(
		[fg_uuid_old, fg_visual_old, fg_morph_old, fg_removed],
		[fg_uuid_new, fg_visual_new, fg_morph_new, fg_added]
	)
	var actions = {}
	for r in result:
		actions[r["uuid"]] = r["action"]
	assert_eq(actions["uuid1"], "replace_fade", "UUID match → replace_fade")
	assert_false(actions.has("v1"), "Visuel identique → pas de transition")
	assert_false(actions.has("v2"), "Visuel identique → pas de transition")
	assert_eq(actions["m2"], "morph", "Position similaire → morph")
	assert_eq(actions["r1"], "fade_out", "Pas de match → fade_out")
	assert_eq(actions["a1"], "fade_in", "Pas de match → fade_in")


# --- Helper ---

func _make_fg(uuid: String, image: String, trans_type: String, trans_dur: float, z: int = 0):
	var fg = Foreground.new()
	fg.uuid = uuid
	fg.image = image
	fg.transition_type = trans_type
	fg.transition_duration = trans_dur
	fg.z_order = z
	return fg
