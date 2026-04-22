# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

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

	# Matcher par proximité de position (morph) — après UUID et équivalence visuelle
	var position_matched_old: Dictionary = {}
	var position_matched_new: Dictionary = {}
	for old_fg in unmatched_old:
		if visually_matched_old.has(old_fg.uuid):
			continue
		for new_fg in unmatched_new:
			if visually_matched_new.has(new_fg.uuid) or position_matched_new.has(new_fg.uuid):
				continue
			if _are_position_similar(old_fg, new_fg):
				position_matched_old[old_fg.uuid] = true
				position_matched_new[new_fg.uuid] = true
				transitions.append({
					"uuid": new_fg.uuid,
					"old_uuid": old_fg.uuid,
					"action": "morph",
					"duration": new_fg.transition_duration,
					"z_order": new_fg.get_render_z_order(),
					"old_anchor_bg": old_fg.anchor_bg,
					"old_scale": old_fg.scale,
					"old_opacity": old_fg.opacity,
					"old_flip_h": old_fg.flip_h,
					"old_flip_v": old_fg.flip_v,
					"old_z_order": old_fg.get_render_z_order(),
					"image_changed": old_fg.image != new_fg.image,
				})
				break

	# Foregrounds supprimés → fade_out (seulement si pas de match visuel ou position)
	for fg in unmatched_old:
		if not visually_matched_old.has(fg.uuid) and not position_matched_old.has(fg.uuid):
			transitions.append({
				"uuid": fg.uuid,
				"action": "fade_out",
				"duration": fg.transition_duration,
				"z_order": fg.get_render_z_order()
			})

	# Foregrounds ajoutés ou remplacés
	for fg in new_fgs:
		if not old_map.has(fg.uuid):
			# Skip si visuellement identique ou position-matché (morph)
			if visually_matched_new.has(fg.uuid) or position_matched_new.has(fg.uuid):
				continue
			# Nouveau FG sans prédécesseur — fondu uniquement à la première apparition
			if fg.transition_type != "none" and not seen_uuids.has(fg.uuid):
				transitions.append({
					"uuid": fg.uuid,
					"action": "fade_in",
					"duration": fg.transition_duration,
					"z_order": fg.get_render_z_order()
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
						"z_order": fg.get_render_z_order()
					})
				else:
					# type="none" → remplacement avec ancien qui disparaît par-dessus
					transitions.append({
						"uuid": fg.uuid,
						"action": "replace_instant",
						"duration": old_fg.transition_duration,
						"z_order": fg.get_render_z_order()
					})

	return transitions

const MORPH_THRESHOLD := 0.15

## Compare deux foregrounds par proximité de position (anchor_bg).
func _are_position_similar(a, b) -> bool:
	if absf(a.anchor_bg.x - b.anchor_bg.x) > MORPH_THRESHOLD:
		return false
	if absf(a.anchor_bg.y - b.anchor_bg.y) > MORPH_THRESHOLD:
		return false
	return true

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


## Applique une transition morph : interpole position/size/opacity et crossfade d'image.
## old_state = {position, size, modulate_a, flip_h, flip_v}
## clone = TextureRect du vieux nœud (seulement si image_changed)
func apply_morph(target: Control, old_state: Dictionary, duration: float, clone = null) -> Tween:
	var target_pos = target.position
	var target_size = target.size
	var target_alpha = target.modulate.a

	# Remettre le nœud à l'ancien état
	target.position = old_state["position"]
	target.size = old_state["size"]

	var tween = target.create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "position", target_pos, duration)
	tween.tween_property(target, "size", target_size, duration)

	# Interpolation d'opacité
	if clone:
		# Image change : ancien visible à 100%, nouveau fade in par-dessus
		target.modulate.a = 0.0
		tween.tween_property(target, "modulate:a", target_alpha, duration)
		# Le clone suit le mouvement
		clone.position = old_state["position"]
		clone.size = old_state["size"]
		tween.tween_property(clone, "position", target_pos, duration)
		tween.tween_property(clone, "size", target_size, duration)
		# Retirer le clone à la fin (chemin normal : tween complété)
		tween.chain().tween_callback(func(): if is_instance_valid(clone): clone.queue_free())
		# Si target est libéré avant la fin du tween, libérer le clone aussi
		target.tree_exiting.connect(func(): if is_instance_valid(clone): clone.queue_free(), CONNECT_ONE_SHOT)
	else:
		# Même image : interpolation linéaire d'opacité
		target.modulate.a = old_state["modulate_a"]
		tween.tween_property(target, "modulate:a", target_alpha, duration)

	# Flip à mi-parcours (seulement si pas de clone : avec clone, target fade in invisible donc déjà au bon état)
	if not clone:
		var tex = target.get_node_or_null("Texture")
		if tex:
			var old_flip_h = old_state.get("flip_h", tex.flip_h)
			var old_flip_v = old_state.get("flip_v", tex.flip_v)
			var new_flip_h = tex.flip_h
			var new_flip_v = tex.flip_v
			if old_flip_h != new_flip_h or old_flip_v != new_flip_v:
				tex.flip_h = old_flip_h
				tex.flip_v = old_flip_v
				tween.tween_callback(func():
					tex.flip_h = new_flip_h
					tex.flip_v = new_flip_v
				).set_delay(duration / 2.0)

	return tween
