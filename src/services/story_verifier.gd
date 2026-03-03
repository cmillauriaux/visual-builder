extends RefCounted

## Verificateur d'histoire — simule plusieurs parcours pour valider
## que tous les chemins menent a une fin valide et que tous les noeuds sont atteignables.

class_name StoryVerifier

const MAX_RUNS := 100
const MAX_STEPS := 10000


func verify(story: RefCounted) -> Dictionary:
	if story == null:
		return _empty_report()

	var all_nodes := _collect_all_nodes(story)
	if all_nodes.is_empty():
		return _empty_report()

	var visited_nodes := {}  # uuid -> true
	var global_coverage := {}  # sequence_uuid -> {choice_index: true} — partage entre runs
	var fallback_counters := {}  # sequence_uuid -> int — cycle quand tous les choix sont couverts
	var runs := []

	for run_index in range(MAX_RUNS):
		var run_result := _simulate_run(story, global_coverage, fallback_counters, run_index)
		runs.append(run_result)

		# Marquer les noeuds visites
		for step in run_result["path"]:
			if step["type"] in ["sequence", "condition"]:
				visited_nodes[step["uuid"]] = true

		# Verifier si on a tout couvert
		var all_visited := true
		for node in all_nodes:
			if not visited_nodes.has(node["uuid"]):
				all_visited = false
				break

		var has_untried := _has_untried_choices(global_coverage, story)
		if all_visited and not has_untried:
			break
		if not has_untried and run_index > 0:
			break

	# Construire la liste des orphelins
	var orphans := []
	for node in all_nodes:
		if not visited_nodes.has(node["uuid"]):
			orphans.append(node)

	var all_valid := true
	for run in runs:
		if not run["is_valid"]:
			all_valid = false
			break

	return {
		"success": all_valid and orphans.is_empty(),
		"runs": runs,
		"orphan_nodes": orphans,
		"total_runs": runs.size(),
		"all_nodes": all_nodes.size(),
		"visited_nodes": visited_nodes.size(),
	}


func _empty_report() -> Dictionary:
	return {
		"success": false,
		"runs": [],
		"orphan_nodes": [],
		"total_runs": 0,
		"all_nodes": 0,
		"visited_nodes": 0,
	}


func _simulate_run(story: RefCounted, global_coverage: Dictionary, fallback_counters: Dictionary, run_index: int) -> Dictionary:
	var variables := {}
	_init_variables(story, variables)
	var path := []
	var visited_in_run := {}  # state_key -> true (detection boucle)
	var local_history := {}   # sequence_uuid -> {choice_index: true} — local a ce run
	var step_count := 0

	# Trouver le chapitre d'entree
	var chapter = _find_entry(story.chapters, story.entry_point_uuid)
	if chapter == null:
		return _make_run_result(run_index, path, "error")

	# Trouver la scene d'entree
	var scene = _find_entry(chapter.scenes, chapter.entry_point_uuid)
	if scene == null:
		return _make_run_result(run_index, path, "error")

	# Trouver le noeud d'entree
	var current_node = _find_scene_entry(scene)
	if current_node == null:
		return _make_run_result(run_index, path, "error")

	while step_count < MAX_STEPS:
		step_count += 1
		var node_uuid: String = current_node.uuid
		var is_condition: bool = current_node.get("rules") != null
		var node_name: String = current_node.condition_name if is_condition else current_node.seq_name

		path.append({
			"uuid": node_uuid,
			"name": node_name,
			"type": "condition" if is_condition else "sequence",
		})

		# Detection de boucle
		var state_key := node_uuid + "|" + _serialize_variables(variables)
		if visited_in_run.has(state_key):
			return _make_run_result(run_index, path, "loop_detected")
		visited_in_run[state_key] = true

		if is_condition:
			var consequence = current_node.evaluate(variables)
			if consequence == null:
				return _make_run_result(run_index, path, "no_ending")
			_apply_effects(consequence.effects, variables)
			var result := _resolve_consequence(consequence, story, chapter, scene)
			if result["finished"]:
				return _make_run_result(run_index, path, result["reason"])
			chapter = result["chapter"]
			scene = result["scene"]
			current_node = result["node"]
		else:
			# C'est une sequence
			if current_node.ending == null:
				return _make_run_result(run_index, path, "no_ending")

			if current_node.ending.type == "auto_redirect":
				if current_node.ending.auto_consequence == null:
					return _make_run_result(run_index, path, "no_ending")
				_apply_effects(current_node.ending.auto_consequence.effects, variables)
				var result := _resolve_consequence(current_node.ending.auto_consequence, story, chapter, scene)
				if result["finished"]:
					return _make_run_result(run_index, path, result["reason"])
				chapter = result["chapter"]
				scene = result["scene"]
				current_node = result["node"]

			elif current_node.ending.type == "choices":
				if current_node.ending.choices.size() == 0:
					return _make_run_result(run_index, path, "no_ending")
				var choice_index := _pick_choice(node_uuid, current_node.ending.choices.size(), local_history, global_coverage, fallback_counters)
				var choice = current_node.ending.choices[choice_index]
				path.append({
					"uuid": node_uuid,
					"name": "Choix: " + choice.text,
					"type": "choice",
					"choice_index": choice_index,
				})
				if choice.consequence == null:
					return _make_run_result(run_index, path, "error")
				_apply_effects(choice.effects, variables)
				_apply_effects(choice.consequence.effects, variables)
				var result := _resolve_consequence(choice.consequence, story, chapter, scene)
				if result["finished"]:
					return _make_run_result(run_index, path, result["reason"])
				chapter = result["chapter"]
				scene = result["scene"]
				current_node = result["node"]
			else:
				return _make_run_result(run_index, path, "no_ending")

	return _make_run_result(run_index, path, "loop_detected")


func _make_run_result(run_index: int, path: Array, ending_reason: String) -> Dictionary:
	return {
		"run_index": run_index,
		"path": path,
		"ending_reason": ending_reason,
		"is_valid": ending_reason in ["game_over", "to_be_continued"],
	}


# --- Resolution des consequences (synchrone) ---

func _resolve_consequence(consequence: RefCounted, story: RefCounted, chapter: RefCounted, scene: RefCounted) -> Dictionary:
	match consequence.type:
		"redirect_sequence":
			var target = scene.find_sequence(consequence.target)
			if target:
				return {"finished": false, "chapter": chapter, "scene": scene, "node": target}
			return {"finished": true, "reason": "error"}
		"redirect_condition":
			if scene.has_method("find_condition"):
				var cond = scene.find_condition(consequence.target)
				if cond:
					return {"finished": false, "chapter": chapter, "scene": scene, "node": cond}
			return {"finished": true, "reason": "error"}
		"redirect_scene":
			var target_scene = chapter.find_scene(consequence.target)
			if target_scene == null:
				return {"finished": true, "reason": "error"}
			var entry = _find_scene_entry(target_scene)
			if entry == null:
				return {"finished": true, "reason": "error"}
			return {"finished": false, "chapter": chapter, "scene": target_scene, "node": entry}
		"redirect_chapter":
			var target_ch = story.find_chapter(consequence.target)
			if target_ch == null:
				return {"finished": true, "reason": "error"}
			var target_scene = _find_entry(target_ch.scenes, target_ch.entry_point_uuid)
			if target_scene == null:
				return {"finished": true, "reason": "error"}
			var entry = _find_scene_entry(target_scene)
			if entry == null:
				return {"finished": true, "reason": "error"}
			return {"finished": false, "chapter": target_ch, "scene": target_scene, "node": entry}
		"game_over":
			return {"finished": true, "reason": "game_over"}
		"to_be_continued":
			return {"finished": true, "reason": "to_be_continued"}
		_:
			return {"finished": true, "reason": "error"}


# --- Utilitaires ---

func _collect_all_nodes(story: RefCounted) -> Array:
	var nodes := []
	for chapter in story.chapters:
		for scene in chapter.scenes:
			for seq in scene.sequences:
				nodes.append({
					"uuid": seq.uuid,
					"name": seq.seq_name,
					"type": "sequence",
					"chapter": chapter.chapter_name,
					"scene": scene.scene_name,
				})
			if scene.get("conditions") != null:
				for cond in scene.conditions:
					nodes.append({
						"uuid": cond.uuid,
						"name": cond.condition_name,
						"type": "condition",
						"chapter": chapter.chapter_name,
						"scene": scene.scene_name,
					})
	return nodes


func _init_variables(story: RefCounted, variables: Dictionary) -> void:
	if story.get("variables") == null:
		return
	for var_def in story.variables:
		variables[var_def.var_name] = var_def.initial_value


func _find_entry(items: Array, entry_uuid: String = ""):
	if items.is_empty():
		return null
	if entry_uuid != "":
		for item in items:
			if item.uuid == entry_uuid:
				return item
	# Fallback : position gauche->droite, haut->bas
	var best = items[0]
	for i in range(1, items.size()):
		var item = items[i]
		if item.position.x < best.position.x:
			best = item
		elif item.position.x == best.position.x and item.position.y < best.position.y:
			best = item
	return best


func _find_scene_entry(scene):
	var entry_uuid = scene.entry_point_uuid
	if entry_uuid != "":
		var seq = scene.find_sequence(entry_uuid)
		if seq:
			return seq
		if scene.has_method("find_condition"):
			var cond = scene.find_condition(entry_uuid)
			if cond:
				return cond
	# Fallback par position
	var all_items: Array = []
	all_items.append_array(scene.sequences)
	if scene.get("conditions") != null:
		all_items.append_array(scene.conditions)
	if all_items.is_empty():
		return null
	var best = all_items[0]
	for i in range(1, all_items.size()):
		var item = all_items[i]
		if item.position.x < best.position.x:
			best = item
		elif item.position.x == best.position.x and item.position.y < best.position.y:
			best = item
	return best


func _apply_effects(effects: Array, variables: Dictionary) -> void:
	for effect in effects:
		effect.apply(variables)


func _serialize_variables(variables: Dictionary) -> String:
	var keys := variables.keys()
	keys.sort()
	var parts := []
	for key in keys:
		parts.append(str(key) + "=" + str(variables[key]))
	return "|".join(parts)


func _pick_choice(sequence_uuid: String, num_choices: int, local_history: Dictionary, global_coverage: Dictionary, fallback_counters: Dictionary) -> int:
	if not local_history.has(sequence_uuid):
		local_history[sequence_uuid] = {}
	if not global_coverage.has(sequence_uuid):
		global_coverage[sequence_uuid] = {}
	var local_tried: Dictionary = local_history[sequence_uuid]
	var globally_covered: Dictionary = global_coverage[sequence_uuid]

	if local_tried.is_empty():
		# Premiere visite dans ce run : priorite aux choix non couverts globalement
		for i in range(num_choices):
			if not globally_covered.has(i):
				local_tried[i] = true
				globally_covered[i] = true
				return i
		# Tous les choix deja couverts globalement : cycler pour explorer les chemins imbriques
		if not fallback_counters.has(sequence_uuid):
			fallback_counters[sequence_uuid] = 0
		var fb: int = fallback_counters[sequence_uuid] % num_choices
		fallback_counters[sequence_uuid] += 1
		local_tried[fb] = true
		return fb
	else:
		# Revisite dans ce run : choisir le prochain choix non encore essaye dans ce run
		for i in range(num_choices):
			if not local_tried.has(i):
				local_tried[i] = true
				globally_covered[i] = true
				return i
		# Tous les choix tentes dans ce run → 0 (loop detection prendra le relais)
		return 0


func _has_untried_choices(choice_history: Dictionary, story: RefCounted) -> bool:
	for chapter in story.chapters:
		for scene in chapter.scenes:
			for seq in scene.sequences:
				if seq.ending == null:
					continue
				if seq.ending.type != "choices":
					continue
				var num_choices: int = seq.ending.choices.size()
				if num_choices == 0:
					continue
				if not choice_history.has(seq.uuid):
					return true
				var tried: Dictionary = choice_history[seq.uuid]
				for i in range(num_choices):
					if not tried.has(i):
						return true
	return false
