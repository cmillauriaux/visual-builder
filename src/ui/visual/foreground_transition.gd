extends Node

## Gère le calcul et l'application des transitions visuelles entre foregrounds.

func compute_transitions(old_fgs: Array, new_fgs: Array, seen_uuids: Dictionary = {}) -> Array:
	var transitions: Array = []
	var old_map: Dictionary = {}
	var new_map: Dictionary = {}

	for fg in old_fgs:
		old_map[fg.uuid] = fg
	for fg in new_fgs:
		new_map[fg.uuid] = fg

	# Identifier les FGs non matchés par UUID
	var unmatched_old: Array = []
	var unmatched_new: Array = []
	for fg in old_fgs:
		if not new_map.has(fg.uuid):
			unmatched_old.append(fg)
	for fg in new_fgs:
		if not old_map.has(fg.uuid):
			unmatched_new.append(fg)

	# Matcher visuellement les FGs non matchés par UUID (même image + position)
	var visually_matched_old: Dictionary = {}
	var visually_matched_new: Dictionary = {}
	for old_fg in unmatched_old:
		for new_fg in unmatched_new:
			if visually_matched_new.has(new_fg.uuid):
				continue
			if _are_visually_equivalent(old_fg, new_fg):
				visually_matched_old[old_fg.uuid] = true
				visually_matched_new[new_fg.uuid] = true
				break

	# Foregrounds supprimés → fade_out (seulement si pas de match visuel)
	for fg in unmatched_old:
		if not visually_matched_old.has(fg.uuid):
			transitions.append({
				"uuid": fg.uuid,
				"action": "fade_out",
				"duration": fg.transition_duration,
				"z_order": fg.z_order
			})

	# Foregrounds ajoutés ou remplacés
	for fg in new_fgs:
		if not old_map.has(fg.uuid):
			# Skip si visuellement identique à un ancien FG
			if visually_matched_new.has(fg.uuid):
				continue
			# Nouveau FG sans prédécesseur — fondu uniquement à la première apparition
			if fg.transition_type != "none" and not seen_uuids.has(fg.uuid):
				transitions.append({
					"uuid": fg.uuid,
					"action": "fade_in",
					"duration": fg.transition_duration,
					"z_order": fg.z_order
				})
		else:
			# Même UUID mais image différente → remplacement
			var old_fg = old_map[fg.uuid]
			if old_fg.image != fg.image:
				if fg.transition_type == "fade":
					transitions.append({
						"uuid": fg.uuid,
						"action": "replace_fade",
						"duration": fg.transition_duration,
						"z_order": fg.z_order
					})
				else:
					# type="none" → remplacement avec ancien qui disparaît par-dessus
					transitions.append({
						"uuid": fg.uuid,
						"action": "replace_instant",
						"duration": old_fg.transition_duration,
						"z_order": fg.z_order
					})

	return transitions

## Compare deux foregrounds pour déterminer s'ils sont visuellement identiques.
func _are_visually_equivalent(a, b) -> bool:
	if a.image != b.image:
		return false
	var threshold = 0.01
	if absf(a.anchor_bg.x - b.anchor_bg.x) > threshold:
		return false
	if absf(a.anchor_bg.y - b.anchor_bg.y) > threshold:
		return false
	if absf(a.anchor_fg.x - b.anchor_fg.x) > threshold:
		return false
	if absf(a.anchor_fg.y - b.anchor_fg.y) > threshold:
		return false
	if absf(a.scale - b.scale) > threshold:
		return false
	if a.flip_h != b.flip_h or a.flip_v != b.flip_v:
		return false
	return true

func apply_instant_fade_in(target: Control) -> void:
	target.modulate.a = 1.0

func apply_instant_fade_out(target: Control) -> void:
	target.modulate.a = 0.0

func apply_tween_fade_in(target: Control, duration: float) -> Tween:
	target.modulate.a = 0.0
	var tween = target.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, duration)
	return tween

func apply_tween_fade_out(target: Control, duration: float, free_on_complete: bool = false) -> Tween:
	target.modulate.a = 1.0
	var tween = target.create_tween()
	tween.tween_property(target, "modulate:a", 0.0, duration)
	if free_on_complete:
		tween.tween_callback(target.queue_free)
	return tween
