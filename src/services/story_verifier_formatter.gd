# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

class_name StoryVerifierFormatter

## Formateur texte du rapport de verification d'histoire.
## Transforme un dictionnaire de rapport en texte lisible par un humain/LLM.
## Aucune dependance UI.


const _REASON_LABELS := {
	"game_over": "Game Over",
	"to_be_continued": "A suivre...",
	"the_end": "The End",
	"error": "Erreur (cible introuvable)",
	"no_ending": "Pas de terminaison",
	"loop_detected": "Boucle infinie detectee",
}


func format(report: Dictionary) -> String:
	var lines: PackedStringArray = []

	lines.append("=== RAPPORT DE VERIFICATION ===")

	var success: bool = report.get("success", false)
	lines.append("Resultat : %s" % ("Succes" if success else "Echec"))
	lines.append("Noeuds visites : %d / %d" % [
		report.get("visited_nodes", 0),
		report.get("all_nodes", 0),
	])
	lines.append("Parcours effectues : %d" % report.get("total_runs", 0))

	_append_total_timings(lines, report.get("total_timings", {}))
	_append_timings(lines, report.get("chapter_timings", []))
	_append_orphans(lines, report.get("orphan_nodes", []))
	_append_runs(lines, report.get("runs", []))

	return "\n".join(lines)


func _append_total_timings(lines: PackedStringArray, total_timings: Dictionary) -> void:
	if total_timings.is_empty():
		return
	lines.append("")
	lines.append("--- DUREE TOTALE ESTIMEE ---")
	
	var buckets = {
		"to_be_continued": "Histoire (Suite)",
		"the_end": "Histoire (The End)",
		"game_over": "Histoire (Game Over)"
	}
	
	for bucket in buckets:
		if total_timings.has(bucket):
			var label = buckets[bucket]
			var sub: Dictionary = total_timings[bucket]
			lines.append("  %s : de %s a %s" % [
				label,
				_format_duration(sub.get("min_seconds", 0.0)),
				_format_duration(sub.get("max_seconds", 0.0)),
			])
			var audio_max: float = sub.get("audio_max_seconds", 0.0)
			if audio_max > 0.0:
				lines.append("  %s audio : de %s a %s" % [
					label,
					_format_duration(sub.get("audio_min_seconds", 0.0)),
					_format_duration(sub.get("audio_max_seconds", 0.0)),
				])


func _append_timings(lines: PackedStringArray, timings: Array) -> void:
	if timings.is_empty():
		return
	lines.append("")
	lines.append("--- DUREE ESTIMEE PAR CHAPITRE ---")
	
	var buckets = {
		"to_be_continued": "Suite",
		"the_end": "The End",
		"game_over": "Game Over"
	}

	for timing in timings:
		var ch: String = timing.get("chapter_name", "")
		for bucket in buckets:
			if timing.has(bucket):
				var label = buckets[bucket]
				var sub: Dictionary = timing[bucket]
				lines.append("  %s (%s) : de %s a %s" % [
					ch,
					label,
					_format_duration(sub.get("min_seconds", 0.0)),
					_format_duration(sub.get("max_seconds", 0.0)),
				])
				var audio_max: float = sub.get("audio_max_seconds", 0.0)
				if audio_max > 0.0:
					lines.append("  %s (%s) audio : de %s a %s" % [
						ch,
						label,
						_format_duration(sub.get("audio_min_seconds", 0.0)),
						_format_duration(sub.get("audio_max_seconds", 0.0)),
					])


func _append_orphans(lines: PackedStringArray, orphans: Array) -> void:
	if orphans.is_empty():
		return
	lines.append("")
	lines.append("--- NOEUDS ORPHELINS (%d) ---" % orphans.size())
	for orphan in orphans:
		var type_str: String = "Condition" if orphan.get("type", "") == "condition" else "Sequence"
		lines.append("  [%s] %s  (%s > %s)" % [
			type_str,
			orphan.get("name", ""),
			orphan.get("chapter", ""),
			orphan.get("scene", ""),
		])


func _append_runs(lines: PackedStringArray, runs: Array) -> void:
	lines.append("")
	lines.append("--- PARCOURS ---")
	for run in runs:
		var is_valid: bool = run.get("is_valid", false)
		var reason: String = run.get("ending_reason", "unknown")
		var reason_text: String = _REASON_LABELS.get(reason, reason)
		var validity: String = "VALIDE" if is_valid else "INVALIDE"
		lines.append("Parcours #%d : %s \u2014 %s" % [
			run.get("run_index", 0) + 1,
			validity,
			reason_text,
		])
		for step in run.get("path", []):
			var step_type: String = step.get("type", "")
			var step_name: String = step.get("name", "")
			if step_type == "choice":
				lines.append("    -> %s" % step_name)
			elif step_type == "condition":
				lines.append("    [Condition] %s" % step_name)
			else:
				lines.append("    %s" % step_name)
		lines.append("")


func _format_duration(seconds: float) -> String:
	var total_sec := int(round(seconds))
	var m := total_sec / 60
	var s := total_sec % 60
	if m == 0:
		return "%d sec" % s
	if s == 0:
		return "%d min" % m
	return "%d min %d sec" % [m, s]