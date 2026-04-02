# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Verificateur d'histoire — simule plusieurs parcours pour valider
## que tous les chemins menent a une fin valide et que tous les noeuds sont atteignables.

class_name StoryVerifier

const MAX_RUNS := 100
const MAX_STEPS := 10000
const WORDS_PER_MINUTE := 250.0
const SECONDS_PER_DIALOGUE := 1.0
const SECONDS_PER_CHOICE := 5.0

# String.split_words() n'existe pas en Godot 4.6.1 — on utilise RegEx a la place.
# Le regex est compile une seule fois (lazy-init) pour eviter de reconstruire
# l'automate a chaque appel de _count_sequence_words.
var _word_regex: RegEx = null
var _audio_duration_cache: Dictionary = {}  # path -> float (seconds)
var _story_base_path: String = ""


func verify(story: RefCounted, story_base_path: String = "") -> Dictionary:
	if story == null:
		return _empty_report()
	_story_base_path = story_base_path
	_audio_duration_cache = {}

	var all_nodes := _collect_all_nodes(story)
	if all_nodes.is_empty():
		return _empty_report()

	var visited_nodes := {}  # uuid -> true
	var global_coverage := {}  # sequence_uuid -> {choice_index: true} — partage entre runs
	var game_over_choices := {}  # sequence_uuid -> {choice_index: true} — choix menant a game_over
	var runs := []

	for run_index in range(MAX_RUNS):
		var run_result := _simulate_run(story, global_coverage, game_over_choices, run_index)
		runs.append(run_result)

		# Enregistrer les choix menant a game_over pour les eviter dans les runs suivants
		if run_result["ending_reason"] == "game_over":
			_record_game_over_choice(run_result["path"], game_over_choices)

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

	var timings_result := _compute_timings(runs)

	return {
		"success": all_valid and orphans.is_empty(),
		"runs": runs,
		"orphan_nodes": orphans,
		"total_runs": runs.size(),
		"all_nodes": all_nodes.size(),
		"visited_nodes": visited_nodes.size(),
		"chapter_timings": timings_result["chapters"],
		"total_timings": timings_result["total"],
	}


func _empty_report() -> Dictionary:
	return {
		"success": false,
		"runs": [],
		"orphan_nodes": [],
		"total_runs": 0,
		"all_nodes": 0,
		"visited_nodes": 0,
		"chapter_timings": [],
		"total_timings": {},
	}


func _simulate_run(story: RefCounted, global_coverage: Dictionary, game_over_choices: Dictionary, run_index: int) -> Dictionary:
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

		if is_condition:
			path.append({
				"uuid": node_uuid,
				"name": node_name,
				"type": "condition",
				"chapter_name": chapter.chapter_name,
				"word_count": 0,
				"dialogue_count": 0,
				"audio_duration": 0.0,
			})
		else:
			var _word_count: int = _count_sequence_words(current_node)
			var _dialogue_count: int = current_node.dialogues.size()
			var _audio_dur: float = _compute_sequence_audio_duration(current_node, _story_base_path)
			path.append({
				"uuid": node_uuid,
				"name": node_name,
				"type": "sequence",
				"chapter_name": chapter.chapter_name,
				"word_count": _word_count,
				"dialogue_count": _dialogue_count,
				"audio_duration": _audio_dur,
			})

		# Detection de boucle
		var history_str = _serialize_full_history(local_history)
		var state_key = node_uuid + "|" + _serialize_variables(variables) + "|" + history_str
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
				var choice_index := _pick_choice(node_uuid, current_node.ending.choices.size(), local_history, global_coverage, game_over_choices, run_index)
				var choice = current_node.ending.choices[choice_index]
				path.append({
					"uuid": node_uuid,
					"name": "Choix: " + choice.text,
					"type": "choice",
					"choice_index": choice_index,
					"chapter_name": chapter.chapter_name,
					"word_count": 0,
					"dialogue_count": 0,
					"audio_duration": 0.0,
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
			elif current_node.ending.type in ["game_over", "to_be_continued"]:
				return _make_run_result(run_index, path, current_node.ending.type)
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


func _serialize_full_history(local_history: Dictionary) -> String:
	var keys = local_history.keys()
	keys.sort()
	var parts = []
	for key in keys:
		var tried = local_history[key].keys()
		tried.sort()
		var tried_str_arr = []
		for t in tried:
			tried_str_arr.append(str(t))
		parts.append(key + ":" + ",".join(tried_str_arr))
	return ";".join(parts)


func _pick_choice(sequence_uuid: String, num_choices: int, local_history: Dictionary, global_coverage: Dictionary, game_over_choices: Dictionary, run_index: int) -> int:
	if not local_history.has(sequence_uuid):
		local_history[sequence_uuid] = {}
	if not global_coverage.has(sequence_uuid):
		global_coverage[sequence_uuid] = {}
	var local_tried: Dictionary = local_history[sequence_uuid]
	var globally_covered: Dictionary = global_coverage[sequence_uuid]
	var go_set: Dictionary = game_over_choices.get(sequence_uuid, {})

	if local_tried.is_empty():
		# Premiere visite dans ce run : priorite aux choix non couverts globalement
		for i in range(num_choices):
			if not globally_covered.has(i):
				local_tried[i] = true
				globally_covered[i] = true
				return i
		# Tous les choix deja couverts globalement : cycler en evitant les game_over connus
		var safe_choices := []
		for i in range(num_choices):
			if not go_set.has(i):
				safe_choices.append(i)
		if safe_choices.size() > 0:
			# Distribution pseudo-aleatoire deterministe basee sur (run_index, sequence)
			# pour decorrreler les choix entre sequences ayant le meme nombre d'options.
			# Le multiplicateur de Fibonacci (2654435761) assure une bonne distribution.
			var seed_val: int = run_index * 2654435761 + abs(sequence_uuid.hash())
			var fb: int = abs(seed_val >> 8) % safe_choices.size()
			local_tried[safe_choices[fb]] = true
			return safe_choices[fb]
		# Tous les choix menent a game_over : cycler normalement
		var fb: int = run_index % num_choices
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


func _record_game_over_choice(path: Array, game_over_choices: Dictionary) -> void:
	# Trouver le dernier choix dans le parcours — c'est celui qui a engage le run vers game_over
	for i in range(path.size() - 1, -1, -1):
		if path[i]["type"] == "choice":
			var uuid: String = path[i]["uuid"]
			var ci: int = path[i]["choice_index"]
			if not game_over_choices.has(uuid):
				game_over_choices[uuid] = {}
			game_over_choices[uuid][ci] = true
			return


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


func _count_sequence_words(seq) -> int:
	if _word_regex == null:
		_word_regex = RegEx.new()
		_word_regex.compile("\\S+")
	var total := 0
	for dlg in seq.dialogues:
		total += _word_regex.search_all(dlg.text).size()
	return total


func _get_audio_duration(path: String) -> float:
	if path == "":
		return 0.0
	if _audio_duration_cache.has(path):
		return _audio_duration_cache[path]
	var duration := 0.0
	if FileAccess.file_exists(path):
		var ext = path.get_extension().to_lower()
		if ext == "ogg":
			var bytes = FileAccess.get_file_as_bytes(path)
			if not bytes.is_empty():
				var stream = AudioStreamOggVorbis.load_from_buffer(bytes)
				if stream:
					duration = stream.get_length()
		elif ext == "mp3":
			var bytes = FileAccess.get_file_as_bytes(path)
			if not bytes.is_empty():
				var stream = AudioStreamMP3.new()
				stream.data = bytes
				duration = stream.get_length()
	_audio_duration_cache[path] = duration
	return duration


func _compute_sequence_audio_duration(seq: RefCounted, story_base_path: String) -> float:
	if story_base_path == "":
		return 0.0
	var total := 0.0
	for dlg in seq.dialogues:
		if dlg.voice_files.is_empty():
			continue
		# Take the first available language
		var first_lang: String = dlg.voice_files.keys()[0]
		var rel_path: String = dlg.voice_files[first_lang]
		if rel_path == "":
			continue
		var abs_path: String = story_base_path + "/" + rel_path
		total += _get_audio_duration(abs_path)
	return total


func _compute_timings(runs: Array) -> Dictionary:
	var chapter_data: Dictionary = {}  # chapter_name -> { "game_over": [], "continuation": [], "audio_game_over": [], "audio_continuation": [] }
	var total_data: Dictionary = {"game_over": [], "continuation": [], "audio_game_over": [], "audio_continuation": []}
	var chapter_order: Array = []

	for run in runs:
		var reason: String = run.get("ending_reason", "")
		if reason in ["error", "loop_detected"]:
			continue
		var bucket: String = "game_over" if reason == "game_over" else "continuation"
		var audio_bucket: String = "audio_" + bucket

		var run_total_time := 0.0
		var run_total_audio := 0.0
		var run_totals: Dictionary = {}  # chapter_name -> seconds for this run
		var run_audio_totals: Dictionary = {}  # chapter_name -> audio seconds for this run
		for step in run.get("path", []):
			var ch: String = step.get("chapter_name", "")
			if ch == "":
				continue
			if not run_totals.has(ch):
				run_totals[ch] = 0.0
				run_audio_totals[ch] = 0.0
			var words: int = step.get("word_count", 0)
			var dialogues: int = step.get("dialogue_count", 0)
			var is_choice: bool = step.get("type", "") == "choice"
			var audio_dur: float = step.get("audio_duration", 0.0)

			var step_time := (words / WORDS_PER_MINUTE) * 60.0 + dialogues * SECONDS_PER_DIALOGUE + (SECONDS_PER_CHOICE if is_choice else 0.0)
			run_totals[ch] += step_time
			run_total_time += step_time
			run_audio_totals[ch] += audio_dur
			run_total_audio += audio_dur

		total_data[bucket].append(run_total_time)
		total_data[audio_bucket].append(run_total_audio)

		for ch in run_totals:
			if not chapter_data.has(ch):
				chapter_data[ch] = {"game_over": [], "continuation": [], "audio_game_over": [], "audio_continuation": []}
				chapter_order.append(ch)
			chapter_data[ch][bucket].append(run_totals[ch])
			chapter_data[ch][audio_bucket].append(run_audio_totals[ch])

	var result_chapters: Array = []
	for ch in chapter_order:
		var entry: Dictionary = {"chapter_name": ch}
		for bucket in ["game_over", "continuation"]:
			var times: Array = chapter_data[ch][bucket]
			if times.size() > 0:
				var sorted_t := times.duplicate()
				sorted_t.sort()
				var audio_times: Array = chapter_data[ch]["audio_" + bucket]
				var sorted_a := audio_times.duplicate()
				sorted_a.sort()
				entry[bucket] = {
					"min_seconds": sorted_t[0],
					"max_seconds": sorted_t[-1],
					"audio_min_seconds": sorted_a[0],
					"audio_max_seconds": sorted_a[-1],
				}
		result_chapters.append(entry)

	var result_total: Dictionary = {}
	for bucket in ["game_over", "continuation"]:
		var times: Array = total_data[bucket]
		if times.size() > 0:
			var sorted_times := times.duplicate()
			sorted_times.sort()
			var audio_times: Array = total_data["audio_" + bucket]
			var sorted_audio := audio_times.duplicate()
			sorted_audio.sort()
			result_total[bucket] = {
				"min_seconds": sorted_times[0],
				"max_seconds": sorted_times[-1],
				"audio_min_seconds": sorted_audio[0],
				"audio_max_seconds": sorted_audio[-1],
			}

	return {
		"chapters": result_chapters,
		"total": result_total
	}


func _format_duration(seconds: float) -> String:
	var total_sec := int(round(seconds))
	var m := total_sec / 60
	var s := total_sec % 60
	if m == 0:
		return "%d sec" % s
	if s == 0:
		return "%d min" % m
	return "%d min %d sec" % [m, s]