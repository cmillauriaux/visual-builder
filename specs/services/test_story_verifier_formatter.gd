extends GutTest

# Tests pour StoryVerifierFormatter

var StoryVerifierFormatterScript = load("res://src/services/story_verifier_formatter.gd")
var _formatter


func before_each():
	_formatter = StoryVerifierFormatterScript.new()


# === En-tete ===

func test_header_contains_title():
	var text: String = _formatter.format({})
	assert_true(text.contains("=== RAPPORT DE VERIFICATION ==="), "L'entete doit etre present")

func test_success_report_contains_succes():
	var text: String = _formatter.format(_make_success_report())
	assert_true(text.contains("Resultat : Succes"), "Succes doit apparaitre dans l'entete")

func test_failure_report_contains_echec():
	var text: String = _formatter.format(_make_failure_report())
	assert_true(text.contains("Resultat : Echec"), "Echec doit apparaitre dans l'entete")

func test_header_contains_visited_nodes():
	var report := _make_success_report()
	var text: String = _formatter.format(report)
	assert_true(text.contains("Noeuds visites : 2 / 2"), "Les noeuds visites doivent apparaitre")

func test_header_contains_total_runs():
	var report := _make_success_report()
	var text: String = _formatter.format(report)
	assert_true(text.contains("Parcours effectues : 1"), "Le nombre de parcours doit apparaitre")

func test_empty_report_does_not_crash():
	var text: String = _formatter.format({})
	assert_true(text.contains("=== RAPPORT DE VERIFICATION ==="), "Ne doit pas crasher sur rapport vide")


# === Section timings ===

func test_timings_section_present_when_non_empty():
	var text: String = _formatter.format(_make_success_report())
	assert_true(text.contains("--- DUREE ESTIMEE PAR CHAPITRE ---"), "Section timings doit etre presente")

func test_timings_section_absent_when_empty():
	var report := _make_failure_report()  # chapter_timings: []
	var text: String = _formatter.format(report)
	assert_false(text.contains("--- DUREE ESTIMEE PAR CHAPITRE ---"), "Section timings ne doit pas etre presente si vide")

func test_timings_continuation_format():
	var text: String = _formatter.format(_make_success_report())
	# continuation : min=150s=2min30sec, max=315s=5min15sec
	assert_true(text.contains("(Suite) : de 2 min 30 sec a 5 min 15 sec"), "Format continuation incorrect")

func test_timings_game_over_format():
	var text: String = _formatter.format(_make_success_report())
	# game_over : min=60s=1min, max=120s=2min
	assert_true(text.contains("(Game Over) : de 1 min a 2 min"), "Format game_over incorrect")

func test_timings_chapter_name_present():
	var text: String = _formatter.format(_make_success_report())
	assert_true(text.contains("Chapitre 1"), "Le nom du chapitre doit apparaitre dans les timings")


# === Section orphelins ===

func test_orphans_section_present_when_non_empty():
	var report := _make_report_with_orphans()
	var text: String = _formatter.format(report)
	assert_true(text.contains("--- NOEUDS ORPHELINS (1) ---"), "Section orphelins doit etre presente")

func test_orphans_section_absent_when_empty():
	var text: String = _formatter.format(_make_success_report())
	assert_false(text.contains("NOEUDS ORPHELINS"), "Section orphelins ne doit pas etre presente si vide")

func test_orphan_sequence_format():
	var report := _make_report_with_orphans()
	var text: String = _formatter.format(report)
	assert_true(text.contains("[Sequence] Intro abandonnee  (Ch1 > Sc1)"), "Format orphelin sequence incorrect")

func test_orphan_condition_type():
	var report := _make_success_report()
	report["orphan_nodes"] = [
		{"uuid": "x", "name": "Cond orpheline", "type": "condition", "chapter": "Ch1", "scene": "Sc1"},
	]
	var text: String = _formatter.format(report)
	assert_true(text.contains("[Condition] Cond orpheline"), "Type condition doit etre affiche")


# === Section parcours ===

func test_runs_section_present():
	var text: String = _formatter.format(_make_success_report())
	assert_true(text.contains("--- PARCOURS ---"), "Section parcours doit etre presente")

func test_run_valid_to_be_continued():
	var report := _make_report_with_run("to_be_continued", true)
	var text: String = _formatter.format(report)
	assert_true(text.contains("Parcours #1 : VALIDE \u2014 A suivre..."), "Run valide to_be_continued incorrect")

func test_run_valid_game_over():
	var report := _make_report_with_run("game_over", true)
	var text: String = _formatter.format(report)
	assert_true(text.contains("Parcours #1 : VALIDE \u2014 Game Over"), "Run valide game_over incorrect")

func test_run_invalid_loop_detected():
	var report := _make_report_with_run("loop_detected", false)
	var text: String = _formatter.format(report)
	assert_true(text.contains("Parcours #1 : INVALIDE \u2014 Boucle infinie detectee"), "Run invalide loop_detected incorrect")

func test_run_invalid_error():
	var report := _make_report_with_run("error", false)
	var text: String = _formatter.format(report)
	assert_true(text.contains("Parcours #1 : INVALIDE \u2014 Erreur (cible introuvable)"), "Run invalide error incorrect")

func test_run_invalid_no_ending():
	var report := _make_report_with_run("no_ending", false)
	var text: String = _formatter.format(report)
	assert_true(text.contains("Parcours #1 : INVALIDE \u2014 Pas de terminaison"), "Run invalide no_ending incorrect")

func test_step_sequence():
	var report := _make_report_with_steps([
		{"uuid": "s1", "name": "Intro", "type": "sequence"},
	])
	var text: String = _formatter.format(report)
	assert_true(text.contains("    Intro"), "Etape sequence incorrecte")

func test_step_choice():
	var report := _make_report_with_steps([
		{"uuid": "c1", "name": "Choix: Partir a gauche", "type": "choice"},
	])
	var text: String = _formatter.format(report)
	assert_true(text.contains("    -> Choix: Partir a gauche"), "Etape choice incorrecte")

func test_step_condition():
	var report := _make_report_with_steps([
		{"uuid": "d1", "name": "Condition courage", "type": "condition"},
	])
	var text: String = _formatter.format(report)
	assert_true(text.contains("    [Condition] Condition courage"), "Etape condition incorrecte")


# === Helpers ===

func _make_success_report() -> Dictionary:
	return {
		"success": true,
		"runs": [
			{
				"run_index": 0,
				"path": [
					{"uuid": "s1", "name": "Seq1", "type": "sequence"},
					{"uuid": "s2", "name": "Seq2", "type": "sequence"},
				],
				"ending_reason": "game_over",
				"is_valid": true,
			}
		],
		"orphan_nodes": [],
		"total_runs": 1,
		"all_nodes": 2,
		"visited_nodes": 2,
		"chapter_timings": [
			{
				"chapter_name": "Chapitre 1",
				"continuation": {"min_seconds": 150.0, "max_seconds": 315.0},
				"game_over": {"min_seconds": 60.0, "max_seconds": 120.0},
			},
		],
	}


func _make_failure_report() -> Dictionary:
	return {
		"success": false,
		"runs": [
			{
				"run_index": 0,
				"path": [{"uuid": "s1", "name": "Seq1", "type": "sequence"}],
				"ending_reason": "no_ending",
				"is_valid": false,
			}
		],
		"orphan_nodes": [],
		"total_runs": 1,
		"all_nodes": 2,
		"visited_nodes": 1,
		"chapter_timings": [],
	}


func _make_report_with_orphans() -> Dictionary:
	var r := _make_success_report()
	r["orphan_nodes"] = [
		{"uuid": "o1", "name": "Intro abandonnee", "type": "sequence", "chapter": "Ch1", "scene": "Sc1"},
	]
	return r


func _make_report_with_run(reason: String, is_valid: bool) -> Dictionary:
	var r := _make_success_report()
	r["runs"] = [
		{
			"run_index": 0,
			"path": [],
			"ending_reason": reason,
			"is_valid": is_valid,
		}
	]
	return r


func _make_report_with_steps(steps: Array) -> Dictionary:
	var r := _make_success_report()
	r["runs"] = [
		{
			"run_index": 0,
			"path": steps,
			"ending_reason": "game_over",
			"is_valid": true,
		}
	]
	return r
