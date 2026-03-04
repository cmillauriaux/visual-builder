extends Node

## Gère le calcul et l'application des transitions visuelles entre foregrounds.

func compute_transitions(old_fgs: Array, new_fgs: Array) -> Array:
	var transitions: Array = []
	var old_map: Dictionary = {}
	var new_map: Dictionary = {}

	for fg in old_fgs:
		old_map[fg.uuid] = fg
	for fg in new_fgs:
		new_map[fg.uuid] = fg

	# Foregrounds supprimés → TOUJOURS fade_out
	for fg in old_fgs:
		if not new_map.has(fg.uuid):
			transitions.append({
				"uuid": fg.uuid,
				"action": "fade_out",
				"duration": fg.transition_duration
			})

	# Foregrounds ajoutés ou remplacés
	for fg in new_fgs:
		if not old_map.has(fg.uuid):
			# Nouveau FG sans prédécesseur
			if fg.transition_type != "none":
				transitions.append({
					"uuid": fg.uuid,
					"action": "fade_in",
					"duration": fg.transition_duration
				})
		else:
			# Même UUID mais image différente → remplacement
			var old_fg = old_map[fg.uuid]
			if old_fg.image != fg.image:
				if fg.transition_type == "fade":
					transitions.append({
						"uuid": fg.uuid,
						"action": "replace_fade",
						"duration": fg.transition_duration
					})
				else:
					# type="none" → remplacement avec ancien qui disparaît par-dessus
					transitions.append({
						"uuid": fg.uuid,
						"action": "replace_instant",
						"duration": old_fg.transition_duration
					})

	return transitions

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
