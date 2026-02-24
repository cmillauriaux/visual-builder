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

	# Foregrounds supprimés → fade_out
	for fg in old_fgs:
		if not new_map.has(fg.uuid):
			if fg.transition_type != "none":
				transitions.append({
					"uuid": fg.uuid,
					"action": "fade_out",
					"duration": fg.transition_duration
				})

	# Foregrounds ajoutés → fade_in / crossfade
	for fg in new_fgs:
		if not old_map.has(fg.uuid):
			if fg.transition_type != "none":
				transitions.append({
					"uuid": fg.uuid,
					"action": "fade_in",
					"duration": fg.transition_duration
				})
		else:
			# Même UUID mais image différente → transition
			var old_fg = old_map[fg.uuid]
			if old_fg.image != fg.image and fg.transition_type != "none":
				if fg.transition_type == "crossfade":
					transitions.append({
						"uuid": fg.uuid,
						"action": "crossfade",
						"old_image": old_fg.image,
						"duration": fg.transition_duration
					})
				else:
					transitions.append({
						"uuid": fg.uuid,
						"action": "fade_in",
						"duration": fg.transition_duration
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

func apply_tween_fade_out(target: Control, duration: float) -> Tween:
	target.modulate.a = 1.0
	var tween = target.create_tween()
	tween.tween_property(target, "modulate:a", 0.0, duration)
	return tween

## Crossfade : crée un clone de l'ancienne image au-dessus du target,
## puis fait disparaître le clone pendant que le target apparaît.
## old_image_path est le chemin de l'ancienne image à afficher dans le clone.
func apply_tween_crossfade(target: Control, old_image_path: String, duration: float) -> Tween:
	var parent = target.get_parent()
	if parent == null:
		return apply_tween_fade_in(target, duration)

	# Créer un nœud temporaire pour l'ancienne image
	var old_clone = TextureRect.new()
	old_clone.name = "CrossfadeClone"
	old_clone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	old_clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	old_clone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	old_clone.position = target.position
	old_clone.size = target.size

	# Charger l'ancienne texture
	var tex = _load_texture(old_image_path)
	if tex:
		old_clone.texture = tex
	parent.add_child(old_clone)

	# Nouvelle image : fade in de 0 → 1
	target.modulate.a = 0.0
	var tween = target.create_tween()
	tween.set_parallel(true)
	tween.tween_property(target, "modulate:a", 1.0, duration)
	# Ancienne image : fade out de 1 → 0
	tween.tween_property(old_clone, "modulate:a", 0.0, duration)
	# Supprimer le clone après la transition
	tween.chain().tween_callback(old_clone.queue_free)
	return tween

func _load_texture(path: String):
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path)
	if not FileAccess.file_exists(path):
		return null
	var img = Image.new()
	var err = img.load(path)
	if err != OK:
		return null
	return ImageTexture.create_from_image(img)
