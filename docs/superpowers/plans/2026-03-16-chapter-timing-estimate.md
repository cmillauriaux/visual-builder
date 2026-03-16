# Chapter Timing Estimate Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ajouter une estimation du temps de jeu minimum et maximum par chapitre dans le rapport du vérificateur d'histoire.

**Architecture:** Enrichir les étapes de path dans `_simulate_run` avec `chapter_name`, `word_count`, `dialogue_count`, puis calculer les timings par chapitre dans `_compute_chapter_timings`, et afficher un nouveau bloc dans `VerifierReportPanel`.

**Tech Stack:** GDScript / Godot 4.6.1, GUT 9.3.0 pour les tests.

**Spec:** `docs/superpowers/specs/2026-03-16-chapter-timing-estimate-design.md`

---

## Chunk 1: StoryVerifier — méthodes pures + enrichissement du path + timings

### Task 1: `_count_sequence_words` et `_format_duration`

**Files:**
- Modify: `src/services/story_verifier.gd`
- Test: `specs/services/test_story_verifier.gd`

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter à la fin de `specs/services/test_story_verifier.gd` :

```gdscript
# === _count_sequence_words ===

func test_count_words_no_dialogues():
	var seq = SequenceScript.new()
	assert_eq(_verifier._count_sequence_words(seq), 0)

func test_count_words_one_dialogue():
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.text = "Hello world"
	seq.dialogues.append(dlg)
	assert_eq(_verifier._count_sequence_words(seq), 2)

func test_count_words_multiple_dialogues():
	var seq = SequenceScript.new()
	var dlg1 = DialogueScript.new()
	dlg1.text = "Hello world"
	var dlg2 = DialogueScript.new()
	dlg2.text = "Goodbye"
	seq.dialogues.append(dlg1)
	seq.dialogues.append(dlg2)
	assert_eq(_verifier._count_sequence_words(seq), 3)

func test_count_words_newline_separator():
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.text = "Hello\nworld"
	seq.dialogues.append(dlg)
	assert_eq(_verifier._count_sequence_words(seq), 2)

func test_count_words_empty_text():
	var seq = SequenceScript.new()
	var dlg = DialogueScript.new()
	dlg.text = ""
	seq.dialogues.append(dlg)
	assert_eq(_verifier._count_sequence_words(seq), 0)


# === _format_duration ===

func test_format_duration_seconds_only():
	assert_eq(_verifier._format_duration(45.0), "45 sec")

func test_format_duration_exact_minutes():
	assert_eq(_verifier._format_duration(120.0), "2 min")

func test_format_duration_minutes_and_seconds():
	assert_eq(_verifier._format_duration(150.0), "2 min 30 sec")

func test_format_duration_zero():
	assert_eq(_verifier._format_duration(0.0), "0 sec")

func test_format_duration_rounds_to_nearest_minute():
	assert_eq(_verifier._format_duration(59.6), "1 min")
```

- [ ] **Step 2: Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd 2>&1 | tail -20
```

Attendu : échec sur les nouveaux tests (`_count_sequence_words`, `_format_duration` non définis).

- [ ] **Step 3: Implémenter les deux méthodes dans `src/services/story_verifier.gd`**

Ajouter les constantes juste après `const MAX_STEPS` (ligne 9) :

```gdscript
const WORDS_PER_MINUTE := 200.0
const SECONDS_PER_DIALOGUE_CLICK := 5.0
```

Ajouter les méthodes à la fin du fichier (après `_has_untried_choices`) :

```gdscript
func _count_sequence_words(seq) -> int:
	var total := 0
	for dlg in seq.dialogues:
		total += dlg.text.split_words().size()
	return total


func _format_duration(seconds: float) -> String:
	var total_sec := int(round(seconds))
	var m := total_sec / 60
	var s := total_sec % 60
	if m == 0:
		return "%d sec" % s
	if s == 0:
		return "%d min" % m
	return "%d min %d sec" % [m, s]
```

- [ ] **Step 4: Vérifier que les tests passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd 2>&1 | tail -20
```

Attendu : tous les tests passent, dont les nouveaux.

- [ ] **Step 5: Commit**

```bash
git add specs/services/test_story_verifier.gd src/services/story_verifier.gd
git commit -m "feat(verifier): ajouter _count_sequence_words et _format_duration"
```

---

### Task 2: Enrichir les étapes de path dans `_simulate_run`

**Files:**
- Modify: `src/services/story_verifier.gd`
- Test: `specs/services/test_story_verifier.gd`

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter à `specs/services/test_story_verifier.gd` :

```gdscript
# === Enrichissement des étapes de path ===

func test_path_step_sequence_has_chapter_name():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_eq(step.get("chapter_name", "MISSING"), "Ch1")

func test_path_step_sequence_has_word_count():
	# _make_sequence ajoute 1 dialogue texte "Hello" = 1 mot
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_eq(step.get("word_count", -1), 1)

func test_path_step_sequence_has_dialogue_count():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_eq(step.get("dialogue_count", -1), 1)

func test_path_step_condition_has_chapter_name_and_zero_counts():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var cond = ConditionModelScript.new()
	cond.condition_name = "Cond"
	cond.position = Vector2(0, 0)
	var cons = ConsequenceScript.new()
	cons.type = "game_over"
	cond.default_consequence = cons
	sc.conditions.append(cond)
	sc.entry_point_uuid = cond.uuid
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_eq(step.get("chapter_name", "MISSING"), "Ch1")
	assert_eq(step.get("word_count", -1), 0)
	assert_eq(step.get("dialogue_count", -1), 0)

func test_path_step_choice_has_chapter_name_and_zero_counts():
	var story = _make_story()
	var ch = _make_chapter("Ch1")
	story.chapters.append(ch)
	var sc = _make_scene("Sc1")
	ch.scenes.append(sc)
	var seq1 = _make_sequence("Seq1", Vector2(0, 0))
	var seq2 = _make_sequence("SeqA", Vector2(200, 0))
	sc.sequences.append(seq1)
	sc.sequences.append(seq2)
	sc.entry_point_uuid = seq1.uuid
	seq1.ending = _make_ending_choices([
		{"text": "Go A", "type": "redirect_sequence", "target": seq2.uuid},
	])
	seq2.ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var choice_step = _find_choice_step(report["runs"][0]["path"])
	assert_eq(choice_step.get("chapter_name", "MISSING"), "Ch1")
	assert_eq(choice_step.get("word_count", -1), 0)
	assert_eq(choice_step.get("dialogue_count", -1), 0)

func test_path_step_chapter_name_correct_after_redirect_chapter():
	# ch1 -> redirect_chapter -> ch2 : les steps de ch2 doivent porter "Ch2"
	var story = _make_story()
	var ch1 = _make_chapter("Ch1", Vector2(0, 0))
	var ch2 = _make_chapter("Ch2", Vector2(200, 0))
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	story.entry_point_uuid = ch1.uuid
	var sc1 = _make_scene("Sc1")
	ch1.scenes.append(sc1)
	var sc2 = _make_scene("Sc2")
	ch2.scenes.append(sc2)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var seq2 = _make_sequence("Seq2")
	sc2.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_chapter", ch2.uuid)
	seq2.ending = _make_ending_auto("to_be_continued", "")
	var report = _verifier.verify(story)
	var path = report["runs"][0]["path"]
	# path[0] = seq1 dans Ch1, path[1] = seq2 dans Ch2
	assert_eq(path[0].get("chapter_name", "MISSING"), "Ch1")
	assert_eq(path[1].get("chapter_name", "MISSING"), "Ch2")
```

- [ ] **Step 2: Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd 2>&1 | tail -20
```

Attendu : les nouveaux tests échouent (champs `chapter_name`, `word_count`, `dialogue_count` absents).

- [ ] **Step 3: Modifier `_simulate_run` dans `src/services/story_verifier.gd`**

**3a — Branche condition** (actuellement lignes ~109–113) — remplacer le `path.append` de la condition :

```gdscript
# Avant (condition)
path.append({
    "uuid": node_uuid,
    "name": node_name,
    "type": "condition" if is_condition else "sequence",
})
```

Ce bloc unique doit être séparé en deux appels distincts. Trouver le `path.append` unique au début du `while` et le remplacer par deux blocs conditionnels. Le code actuel est :

```gdscript
		path.append({
			"uuid": node_uuid,
			"name": node_name,
			"type": "condition" if is_condition else "sequence",
		})
```

Remplacer par :

```gdscript
		if is_condition:
			path.append({
				"uuid": node_uuid,
				"name": node_name,
				"type": "condition",
				"chapter_name": chapter.chapter_name,
				"word_count": 0,
				"dialogue_count": 0,
			})
		else:
			var _word_count := _count_sequence_words(current_node)
			var _dialogue_count := current_node.dialogues.size()
			path.append({
				"uuid": node_uuid,
				"name": node_name,
				"type": "sequence",
				"chapter_name": chapter.chapter_name,
				"word_count": _word_count,
				"dialogue_count": _dialogue_count,
			})
```

> **Important** : `chapter.chapter_name` est lu ici, *avant* tout appel à `_resolve_consequence`.

**3b — Étape choice** (actuellement dans la branche `elif current_node.ending.type == "choices"`) — trouver le `path.append` du choix :

```gdscript
			path.append({
				"uuid": node_uuid,
				"name": "Choix: " + choice.text,
				"type": "choice",
				"choice_index": choice_index,
			})
```

Remplacer par :

```gdscript
			path.append({
				"uuid": node_uuid,
				"name": "Choix: " + choice.text,
				"type": "choice",
				"choice_index": choice_index,
				"chapter_name": chapter.chapter_name,
				"word_count": 0,
				"dialogue_count": 0,
			})
```

- [ ] **Step 4: Vérifier que les tests passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd 2>&1 | tail -20
```

Attendu : tous les tests passent.

- [ ] **Step 5: Commit**

```bash
git add specs/services/test_story_verifier.gd src/services/story_verifier.gd
git commit -m "feat(verifier): enrichir les étapes de path avec chapter_name, word_count, dialogue_count"
```

---

### Task 3: `_compute_chapter_timings`, `verify()` et `_empty_report()`

**Files:**
- Modify: `src/services/story_verifier.gd`
- Test: `specs/services/test_story_verifier.gd`

- [ ] **Step 1: Écrire les tests qui échouent**

Ajouter à `specs/services/test_story_verifier.gd` :

```gdscript
# === _compute_chapter_timings ===

func test_compute_timings_direct_single_chapter():
	# 10 mots + 2 clics dans Ch1 : (10/200)*60 + 2*5 = 3.0 + 10.0 = 13.0 sec
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 10, "dialogue_count": 2},
			]
		}
	]
	var timings = _verifier._compute_chapter_timings(runs)
	assert_eq(timings.size(), 1)
	assert_eq(timings[0]["chapter_name"], "Ch1")
	assert_almost_eq(timings[0]["min_seconds"], 13.0, 0.01)
	assert_almost_eq(timings[0]["max_seconds"], 13.0, 0.01)

func test_compute_timings_direct_two_runs_min_max():
	# Run 1 : Ch1 = 0 mots, 1 clic -> 5.0 sec
	# Run 2 : Ch1 = 200 mots, 2 clics -> 60.0 + 10.0 = 70.0 sec
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 1}]
		},
		{
			"ending_reason": "to_be_continued",
			"path": [{"chapter_name": "Ch1", "word_count": 200, "dialogue_count": 2}]
		},
	]
	var timings = _verifier._compute_chapter_timings(runs)
	assert_eq(timings.size(), 1)
	assert_almost_eq(timings[0]["min_seconds"], 5.0, 0.01)
	assert_almost_eq(timings[0]["max_seconds"], 70.0, 0.01)

func test_compute_timings_excludes_error_runs():
	var runs = [
		{
			"ending_reason": "error",
			"path": [{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0}]
		},
		{
			"ending_reason": "game_over",
			"path": [{"chapter_name": "Ch1", "word_count": 100, "dialogue_count": 3}]
		},
	]
	var timings = _verifier._compute_chapter_timings(runs)
	# Seul le run game_over compte : (100/200)*60 + 3*5 = 30 + 15 = 45 sec
	assert_eq(timings.size(), 1)
	assert_almost_eq(timings[0]["min_seconds"], 45.0, 0.01)
	assert_almost_eq(timings[0]["max_seconds"], 45.0, 0.01)

func test_compute_timings_excludes_loop_detected_runs():
	var runs = [
		{
			"ending_reason": "loop_detected",
			"path": [{"chapter_name": "Ch1", "word_count": 50, "dialogue_count": 2}]
		},
		{
			"ending_reason": "to_be_continued",
			"path": [{"chapter_name": "Ch1", "word_count": 10, "dialogue_count": 1}]
		},
	]
	var timings = _verifier._compute_chapter_timings(runs)
	assert_eq(timings.size(), 1)
	# Seul to_be_continued compte : (10/200)*60 + 1*5 = 3.0 + 5.0 = 8.0 sec
	assert_almost_eq(timings[0]["min_seconds"], 8.0, 0.01)
	assert_almost_eq(timings[0]["max_seconds"], 8.0, 0.01)

func test_compute_timings_two_chapters_preserved_order():
	var runs = [
		{
			"ending_reason": "to_be_continued",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 1},
				{"chapter_name": "Ch2", "word_count": 0, "dialogue_count": 2},
			]
		}
	]
	var timings = _verifier._compute_chapter_timings(runs)
	assert_eq(timings.size(), 2)
	assert_eq(timings[0]["chapter_name"], "Ch1")
	assert_eq(timings[1]["chapter_name"], "Ch2")

func test_compute_timings_empty_runs():
	var timings = _verifier._compute_chapter_timings([])
	assert_eq(timings.size(), 0)


# === verify() inclut chapter_timings ===

func test_verify_includes_chapter_timings_key():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	assert_true(report.has("chapter_timings"), "chapter_timings doit être présent dans le rapport")

func test_verify_chapter_timings_one_chapter():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var timings = report["chapter_timings"]
	assert_eq(timings.size(), 1)
	assert_eq(timings[0]["chapter_name"], "Ch1")
	# _make_sequence crée 1 dialogue "Hello" = 1 mot
	# time = (1/200)*60 + 1*5 = 0.3 + 5.0 = 5.3 sec
	assert_almost_eq(timings[0]["min_seconds"], 5.3, 0.01)
	assert_almost_eq(timings[0]["max_seconds"], 5.3, 0.01)

func test_verify_chapter_timings_two_chapters():
	var story = _make_story()
	var ch1 = _make_chapter("Ch1", Vector2(0, 0))
	var ch2 = _make_chapter("Ch2", Vector2(200, 0))
	story.chapters.append(ch1)
	story.chapters.append(ch2)
	var sc1 = _make_scene("Sc1")
	ch1.scenes.append(sc1)
	var sc2 = _make_scene("Sc2")
	ch2.scenes.append(sc2)
	var seq1 = _make_sequence("Seq1")
	sc1.sequences.append(seq1)
	var seq2 = _make_sequence("Seq2")
	sc2.sequences.append(seq2)
	seq1.ending = _make_ending_auto("redirect_chapter", ch2.uuid)
	seq2.ending = _make_ending_auto("to_be_continued", "")
	var report = _verifier.verify(story)
	var timings = report["chapter_timings"]
	assert_eq(timings.size(), 2)
	assert_eq(timings[0]["chapter_name"], "Ch1")
	assert_eq(timings[1]["chapter_name"], "Ch2")


# === _empty_report inclut chapter_timings ===

func test_empty_report_has_chapter_timings():
	var report = _verifier.verify(null)
	assert_true(report.has("chapter_timings"))
	assert_eq(report["chapter_timings"], [])
```

- [ ] **Step 2: Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd 2>&1 | tail -20
```

Attendu : les nouveaux tests échouent (`_compute_chapter_timings` non défini, `chapter_timings` absent du rapport).

- [ ] **Step 3: Implémenter `_compute_chapter_timings` dans `src/services/story_verifier.gd`**

Ajouter après `_format_duration` :

```gdscript
func _compute_chapter_timings(runs: Array) -> Array:
	var chapter_times: Dictionary = {}  # chapter_name -> Array[float]
	var chapter_order: Array = []

	for run in runs:
		var reason: String = run.get("ending_reason", "")
		if reason in ["error", "loop_detected"]:
			continue

		var run_totals: Dictionary = {}  # chapter_name -> seconds for this run
		for step in run.get("path", []):
			var ch: String = step.get("chapter_name", "")
			if ch == "":
				continue
			if not run_totals.has(ch):
				run_totals[ch] = 0.0
			var words: int = step.get("word_count", 0)
			var clicks: int = step.get("dialogue_count", 0)
			run_totals[ch] += (words / WORDS_PER_MINUTE) * 60.0 + clicks * SECONDS_PER_DIALOGUE_CLICK

		for ch in run_totals:
			if not chapter_times.has(ch):
				chapter_times[ch] = []
				chapter_order.append(ch)
			chapter_times[ch].append(run_totals[ch])

	var result: Array = []
	for ch in chapter_order:
		var times: Array = chapter_times[ch].duplicate()
		times.sort()
		result.append({
			"chapter_name": ch,
			"min_seconds": times[0],
			"max_seconds": times[-1],
		})
	return result
```

- [ ] **Step 4: Mettre à jour `verify()` et `_empty_report()` dans `src/services/story_verifier.gd`**

Dans `verify()`, remplacer le `return` final (lignes ~59–66) :

```gdscript
	return {
		"success": all_valid and orphans.is_empty(),
		"runs": runs,
		"orphan_nodes": orphans,
		"total_runs": runs.size(),
		"all_nodes": all_nodes.size(),
		"visited_nodes": visited_nodes.size(),
		"chapter_timings": _compute_chapter_timings(runs),
	}
```

Dans `_empty_report()`, ajouter `"chapter_timings": []` :

```gdscript
func _empty_report() -> Dictionary:
	return {
		"success": false,
		"runs": [],
		"orphan_nodes": [],
		"total_runs": 0,
		"all_nodes": 0,
		"visited_nodes": 0,
		"chapter_timings": [],
	}
```

- [ ] **Step 5: Vérifier que les tests passent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd 2>&1 | tail -20
```

Attendu : tous les tests passent.

- [ ] **Step 6: Commit**

```bash
git add specs/services/test_story_verifier.gd src/services/story_verifier.gd
git commit -m "feat(verifier): ajouter _compute_chapter_timings et chapter_timings dans le rapport"
```

---

## Chunk 2: VerifierReportPanel — affichage du bloc timing

### Task 4: Afficher la durée estimée par chapitre dans le panel

**Files:**
- Modify: `src/ui/editors/verifier_report_panel.gd`
- Test: `specs/ui/editors/test_verifier_report_panel.gd`

- [ ] **Step 1: Mettre à jour les helpers de test pour inclure `chapter_timings`**

Dans `specs/ui/editors/test_verifier_report_panel.gd`, mettre à jour `_make_success_report()` et `_make_failure_report()` pour inclure `chapter_timings` (les tests existants ne doivent pas casser) :

```gdscript
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
			{"chapter_name": "Chapitre 1", "min_seconds": 150.0, "max_seconds": 315.0},
		],
	}

func _make_failure_report() -> Dictionary:
	return {
		"success": false,
		"runs": [
			{
				"run_index": 0,
				"path": [
					{"uuid": "s1", "name": "Seq1", "type": "sequence"},
				],
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
```

- [ ] **Step 2: Écrire les tests qui échouent**

Ajouter à `specs/ui/editors/test_verifier_report_panel.gd` :

```gdscript
# === Chapter timings ===

func test_show_chapter_timings_block_visible():
	var report = _make_success_report()
	_panel.show_report(report)
	var timing_title = _panel._report_content.get_node_or_null("ChapterTimingsTitle")
	assert_not_null(timing_title, "Le titre de la section timing doit exister")

func test_show_chapter_timings_list_has_correct_count():
	var report = _make_success_report()
	_panel.show_report(report)
	var timing_list = _panel._report_content.get_node_or_null("ChapterTimingsList")
	assert_not_null(timing_list, "La liste des timings doit exister")
	assert_eq(timing_list.get_child_count(), 1)

func test_show_chapter_timings_label_text():
	var report = _make_success_report()
	_panel.show_report(report)
	var timing_list = _panel._report_content.get_node_or_null("ChapterTimingsList")
	assert_not_null(timing_list)
	var label: Label = timing_list.get_child(0)
	# 150 sec = 2 min 30 sec, 315 sec = 5 min 15 sec
	assert_true(label.text.contains("Chapitre 1"), "Le nom du chapitre doit apparaître")
	assert_true(label.text.contains("de "), "Le mot 'de' doit apparaître avant le min")
	assert_true(label.text.contains(" a "), "Le séparateur ' a ' doit apparaître entre min et max")
	assert_true(label.text.contains("2 min 30 sec"), "Le min doit être formaté")
	assert_true(label.text.contains("5 min 15 sec"), "Le max doit être formaté")

func test_show_chapter_timings_hidden_when_empty():
	var report = _make_failure_report()  # chapter_timings: []
	_panel.show_report(report)
	var timing_title = _panel._report_content.get_node_or_null("ChapterTimingsTitle")
	assert_null(timing_title, "Le titre timing ne doit pas exister si chapter_timings est vide")

func test_show_chapter_timings_hidden_when_key_absent():
	var report = _make_success_report()
	report.erase("chapter_timings")
	_panel.show_report(report)
	var timing_title = _panel._report_content.get_node_or_null("ChapterTimingsTitle")
	assert_null(timing_title, "Le titre timing ne doit pas exister si la clé est absente")
```

- [ ] **Step 3: Vérifier que les tests échouent**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 60 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/editors/test_verifier_report_panel.gd 2>&1 | tail -20
```

Attendu : les nouveaux tests échouent.

- [ ] **Step 4: Implémenter le bloc timing dans `src/ui/editors/verifier_report_panel.gd`**

Dans `show_report()`, insérer le bloc suivant **après** `_report_content.add_child(HSeparator.new())` (ligne ~87) et **avant** le bloc des orphelins :

```gdscript
	# Chapter timings
	var chapter_timings: Array = report.get("chapter_timings", [])
	if chapter_timings.size() > 0:
		var timings_title = Label.new()
		timings_title.name = "ChapterTimingsTitle"
		timings_title.text = "-- Duree estimee par chapitre --"
		timings_title.add_theme_font_size_override("font_size", 15)
		timings_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		_report_content.add_child(timings_title)

		var timings_list = VBoxContainer.new()
		timings_list.name = "ChapterTimingsList"
		_report_content.add_child(timings_list)

		for timing in chapter_timings:
			var item = Label.new()
			var min_str := _format_duration(timing.get("min_seconds", 0.0))
			var max_str := _format_duration(timing.get("max_seconds", 0.0))
			item.text = "  %s    de %s  a  %s" % [timing.get("chapter_name", ""), min_str, max_str]
			timings_list.add_child(item)

		_report_content.add_child(HSeparator.new())
```

Ajouter la méthode `_format_duration` dans `src/ui/editors/verifier_report_panel.gd` (à la fin du fichier, avant `clear()`) :

```gdscript
func _format_duration(seconds: float) -> String:
	var total_sec := int(round(seconds))
	var m := total_sec / 60
	var s := total_sec % 60
	if m == 0:
		return "%d sec" % s
	if s == 0:
		return "%d min" % m
	return "%d min %d sec" % [m, s]
```

> Note : `_format_duration` est dupliquée dans `StoryVerifier` et `VerifierReportPanel`. C'est intentionnel — les deux classes sont indépendantes et la méthode est triviale.

- [ ] **Step 5: Vérifier que tous les tests passent (UI + verifier)**

```bash
GODOT=${GODOT_PATH:-$(command -v godot || echo "/Applications/Godot-4.6.1.app/Contents/MacOS/Godot")}
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/editors/test_verifier_report_panel.gd 2>&1 | tail -20
```

Puis vérifier que les tests du verifier passent toujours :

```bash
timeout 120 $GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd 2>&1 | tail -20
```

Attendu : tous les tests passent.

- [ ] **Step 6: Commit**

```bash
git add specs/ui/editors/test_verifier_report_panel.gd src/ui/editors/verifier_report_panel.gd
git commit -m "feat(verifier_panel): afficher la durée estimée par chapitre"
```
