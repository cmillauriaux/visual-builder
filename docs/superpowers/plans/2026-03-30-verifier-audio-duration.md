# Verifier Audio Duration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real audio duration (sum of voice_files) alongside estimated reading time in the story verification report.

**Architecture:** The `StoryVerifier` gains a `story_base_path` parameter and an audio duration cache. During path simulation, each sequence step records `audio_duration` by loading voice files and calling `get_length()`. `_compute_timings()` produces parallel `audio_min_seconds`/`audio_max_seconds` fields. The report panel and text formatter display them.

**Tech Stack:** GDScript (Godot 4.6.1), GUT test framework, AudioStreamOggVorbis/AudioStreamMP3

---

### Task 1: StoryVerifier — audio duration calculation

**Files:**
- Modify: `src/services/story_verifier.gd`
- Test: `specs/services/test_story_verifier.gd`

- [ ] **Step 1: Write failing tests for `_get_audio_duration` and `_compute_sequence_audio_duration`**

Add these tests at the end of `specs/services/test_story_verifier.gd`, before the helpers section:

```gdscript
# === Audio duration ===

func test_get_audio_duration_returns_zero_for_empty_path():
	assert_almost_eq(_verifier._get_audio_duration(""), 0.0, 0.01)

func test_get_audio_duration_returns_zero_for_nonexistent_file():
	assert_almost_eq(_verifier._get_audio_duration("/tmp/nonexistent_audio_file.mp3"), 0.0, 0.01)

func test_get_audio_duration_caches_result():
	# Call twice, second call should use cache
	_verifier._get_audio_duration("/tmp/nonexistent_audio_file.mp3")
	_verifier._get_audio_duration("/tmp/nonexistent_audio_file.mp3")
	# If we got here without error, caching works
	assert_true(_verifier._audio_duration_cache.has("/tmp/nonexistent_audio_file.mp3"))

func test_compute_sequence_audio_duration_no_voice_files():
	var seq = _make_sequence("NoVoice")
	# Default dialogue has no voice_files
	var duration = _verifier._compute_sequence_audio_duration(seq, "/tmp")
	assert_almost_eq(duration, 0.0, 0.01)

func test_compute_sequence_audio_duration_with_voice_files_nonexistent():
	var seq = SequenceScript.new()
	seq.seq_name = "WithVoice"
	seq.position = Vector2(0, 0)
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	dlg.voice_files = {"fr": "assets/voices/test_fr.mp3"}
	seq.dialogues.append(dlg)
	var duration = _verifier._compute_sequence_audio_duration(seq, "/tmp")
	# File doesn't exist, so duration = 0
	assert_almost_eq(duration, 0.0, 0.01)

func test_compute_sequence_audio_duration_empty_story_base_path():
	var seq = SequenceScript.new()
	seq.seq_name = "WithVoice"
	seq.position = Vector2(0, 0)
	var dlg = DialogueScript.new()
	dlg.character = "Narrator"
	dlg.text = "Hello"
	dlg.voice_files = {"fr": "assets/voices/test_fr.mp3"}
	seq.dialogues.append(dlg)
	var duration = _verifier._compute_sequence_audio_duration(seq, "")
	assert_almost_eq(duration, 0.0, 0.01)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd`
Expected: FAIL — methods `_get_audio_duration`, `_compute_sequence_audio_duration`, and property `_audio_duration_cache` do not exist.

- [ ] **Step 3: Implement audio duration methods in StoryVerifier**

In `src/services/story_verifier.gd`, add these properties after the existing `var _word_regex`:

```gdscript
var _audio_duration_cache: Dictionary = {}  # path -> float (seconds)
var _story_base_path: String = ""
```

Change the `verify()` signature — replace line 20:

```gdscript
func verify(story: RefCounted, story_base_path: String = "") -> Dictionary:
```

Add `_story_base_path = story_base_path` and `_audio_duration_cache = {}` at the top of `verify()`, after the null check (after line 22):

```gdscript
	_story_base_path = story_base_path
	_audio_duration_cache = {}
```

Add `_get_audio_duration` after `_count_sequence_words` (after line 452):

```gdscript
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd`
Expected: All new tests PASS. All existing tests still PASS.

- [ ] **Step 5: Commit**

```bash
git add src/services/story_verifier.gd specs/services/test_story_verifier.gd
git commit -m "feat(verifier): add audio duration calculation methods"
```

---

### Task 2: StoryVerifier — integrate audio_duration into simulation steps and _compute_timings

**Files:**
- Modify: `src/services/story_verifier.gd`
- Test: `specs/services/test_story_verifier.gd`

- [ ] **Step 1: Write failing tests for audio_duration in steps and _compute_timings**

Add these tests in `specs/services/test_story_verifier.gd` after the audio duration tests from Task 1:

```gdscript
func test_simulate_step_includes_audio_duration_key():
	var story = _build_simple_story()
	story.chapters[0].scenes[0].sequences[0].ending = _make_ending_auto("game_over", "")
	var report = _verifier.verify(story)
	var step = report["runs"][0]["path"][0]
	assert_true(step.has("audio_duration"), "Step should have audio_duration key")
	assert_almost_eq(step["audio_duration"], 0.0, 0.01)

func test_compute_timings_includes_audio_fields():
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 10, "dialogue_count": 2, "type": "sequence", "audio_duration": 5.5},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	var ch = result["chapters"][0]
	assert_true(ch["game_over"].has("audio_min_seconds"))
	assert_true(ch["game_over"].has("audio_max_seconds"))
	assert_almost_eq(ch["game_over"]["audio_min_seconds"], 5.5, 0.01)
	assert_almost_eq(ch["game_over"]["audio_max_seconds"], 5.5, 0.01)

func test_compute_timings_audio_min_max_across_runs():
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 3.0},
			]
		},
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 10.0},
			]
		},
	]
	var result = _verifier._compute_timings(runs)
	var ch = result["chapters"][0]
	assert_almost_eq(ch["game_over"]["audio_min_seconds"], 3.0, 0.01)
	assert_almost_eq(ch["game_over"]["audio_max_seconds"], 10.0, 0.01)

func test_compute_timings_audio_in_total():
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 7.0},
				{"chapter_name": "Ch2", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 3.0},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	var total = result["total"]
	assert_true(total["game_over"].has("audio_min_seconds"))
	assert_almost_eq(total["game_over"]["audio_min_seconds"], 10.0, 0.01)
	assert_almost_eq(total["game_over"]["audio_max_seconds"], 10.0, 0.01)

func test_compute_timings_audio_zero_when_no_audio():
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 10, "dialogue_count": 1, "type": "sequence", "audio_duration": 0.0},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	var ch = result["chapters"][0]
	assert_almost_eq(ch["game_over"]["audio_min_seconds"], 0.0, 0.01)
	assert_almost_eq(ch["game_over"]["audio_max_seconds"], 0.0, 0.01)

func test_compute_timings_audio_choices_and_conditions_zero():
	# Choices and conditions should contribute 0 audio_duration
	var runs = [
		{
			"ending_reason": "game_over",
			"path": [
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "choice", "audio_duration": 0.0},
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "condition", "audio_duration": 0.0},
				{"chapter_name": "Ch1", "word_count": 0, "dialogue_count": 0, "type": "sequence", "audio_duration": 5.0},
			]
		}
	]
	var result = _verifier._compute_timings(runs)
	assert_almost_eq(result["chapters"][0]["game_over"]["audio_min_seconds"], 5.0, 0.01)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd`
Expected: FAIL — `audio_duration` key missing from steps, `audio_min_seconds` / `audio_max_seconds` missing from timings.

- [ ] **Step 3: Add audio_duration to simulation steps**

In `src/services/story_verifier.gd`, in `_simulate_run()`, modify the sequence step (around line 137-144). Replace:

```gdscript
			var _word_count: int = _count_sequence_words(current_node)
			var _dialogue_count: int = current_node.dialogues.size()
			path.append({
				"uuid": node_uuid,
				"name": node_name,
				"type": "sequence",
				"chapter_name": chapter.chapter_name,
				"word_count": _word_count,
				"dialogue_count": _dialogue_count,
			})
```

With:

```gdscript
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
```

Also add `"audio_duration": 0.0` to the condition step dict (around line 126-133) and to the choice step dict (around line 185-193).

- [ ] **Step 4: Update `_compute_timings` to track audio durations**

In `src/services/story_verifier.gd`, modify `_compute_timings()`. The data structures need audio tracking. Replace the entire `_compute_timings` method (lines 455-516) with:

```gdscript
func _compute_timings(runs: Array) -> Dictionary:
	var chapter_data: Dictionary = {}  # chapter_name -> { "game_over": Array[float], "continuation": Array[float], "audio_game_over": Array[float], "audio_continuation": Array[float] }
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
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier.gd`
Expected: ALL tests PASS (new + existing).

- [ ] **Step 6: Commit**

```bash
git add src/services/story_verifier.gd specs/services/test_story_verifier.gd
git commit -m "feat(verifier): integrate audio_duration into steps and timings"
```

---

### Task 3: StoryVerifierFormatter — display audio timings in text report

**Files:**
- Modify: `src/services/story_verifier_formatter.gd`
- Test: `specs/services/test_story_verifier_formatter.gd`

- [ ] **Step 1: Write failing tests for audio lines in formatter**

Add these tests at the end of `specs/services/test_story_verifier_formatter.gd`, before the helpers:

```gdscript
# === Audio timings ===

func test_total_timings_audio_present_when_non_zero():
	var report := _make_success_report()
	report["total_timings"] = {
		"continuation": {"min_seconds": 600.0, "max_seconds": 1200.0, "audio_min_seconds": 300.0, "audio_max_seconds": 900.0},
	}
	var text: String = _formatter.format(report)
	assert_true(text.contains("Histoire (Suite) audio : de 5 min a 15 min"), "Audio total continuation doit apparaitre")

func test_total_timings_audio_absent_when_zero():
	var report := _make_success_report()
	report["total_timings"] = {
		"continuation": {"min_seconds": 600.0, "max_seconds": 1200.0, "audio_min_seconds": 0.0, "audio_max_seconds": 0.0},
	}
	var text: String = _formatter.format(report)
	assert_false(text.contains("audio"), "Audio total ne doit pas apparaitre si duree = 0")

func test_total_timings_game_over_audio():
	var report := _make_success_report()
	report["total_timings"] = {
		"game_over": {"min_seconds": 60.0, "max_seconds": 120.0, "audio_min_seconds": 30.0, "audio_max_seconds": 90.0},
	}
	var text: String = _formatter.format(report)
	assert_true(text.contains("Histoire (Game Over) audio : de 30 sec a 1 min 30 sec"), "Audio total game_over doit apparaitre")

func test_chapter_timings_audio_present_when_non_zero():
	var report := _make_success_report()
	report["chapter_timings"] = [
		{
			"chapter_name": "Chapitre 1",
			"continuation": {"min_seconds": 150.0, "max_seconds": 315.0, "audio_min_seconds": 60.0, "audio_max_seconds": 200.0},
		},
	]
	var text: String = _formatter.format(report)
	assert_true(text.contains("Chapitre 1 (Suite) audio : de 1 min a 3 min 20 sec"), "Audio chapitre continuation doit apparaitre")

func test_chapter_timings_audio_absent_when_zero():
	var report := _make_success_report()
	report["chapter_timings"] = [
		{
			"chapter_name": "Chapitre 1",
			"continuation": {"min_seconds": 150.0, "max_seconds": 315.0, "audio_min_seconds": 0.0, "audio_max_seconds": 0.0},
		},
	]
	var text: String = _formatter.format(report)
	assert_false(text.contains("audio"), "Audio chapitre ne doit pas apparaitre si duree = 0")

func test_chapter_timings_audio_absent_when_keys_missing():
	# Backward-compat: old reports without audio keys
	var report := _make_success_report()
	report["chapter_timings"] = [
		{
			"chapter_name": "Chapitre 1",
			"continuation": {"min_seconds": 150.0, "max_seconds": 315.0},
		},
	]
	var text: String = _formatter.format(report)
	assert_false(text.contains("audio"), "Audio ne doit pas apparaitre si les cles audio sont absentes")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier_formatter.gd`
Expected: FAIL — audio lines not present in output.

- [ ] **Step 3: Add audio lines to `_append_total_timings`**

In `src/services/story_verifier_formatter.gd`, modify `_append_total_timings()`. Replace lines 38-54:

```gdscript
func _append_total_timings(lines: PackedStringArray, total_timings: Dictionary) -> void:
	if total_timings.is_empty():
		return
	lines.append("")
	lines.append("--- DUREE TOTALE ESTIMEE ---")
	if total_timings.has("continuation"):
		var sub: Dictionary = total_timings["continuation"]
		lines.append("  Histoire (Suite) : de %s a %s" % [
			_format_duration(sub.get("min_seconds", 0.0)),
			_format_duration(sub.get("max_seconds", 0.0)),
		])
		var audio_max: float = sub.get("audio_max_seconds", 0.0)
		if audio_max > 0.0:
			lines.append("  Histoire (Suite) audio : de %s a %s" % [
				_format_duration(sub.get("audio_min_seconds", 0.0)),
				_format_duration(sub.get("audio_max_seconds", 0.0)),
			])
	if total_timings.has("game_over"):
		var sub: Dictionary = total_timings["game_over"]
		lines.append("  Histoire (Game Over) : de %s a %s" % [
			_format_duration(sub.get("min_seconds", 0.0)),
			_format_duration(sub.get("max_seconds", 0.0)),
		])
		var audio_max: float = sub.get("audio_max_seconds", 0.0)
		if audio_max > 0.0:
			lines.append("  Histoire (Game Over) audio : de %s a %s" % [
				_format_duration(sub.get("audio_min_seconds", 0.0)),
				_format_duration(sub.get("audio_max_seconds", 0.0)),
			])
```

- [ ] **Step 4: Add audio lines to `_append_timings`**

In `src/services/story_verifier_formatter.gd`, modify `_append_timings()`. Replace lines 57-77:

```gdscript
func _append_timings(lines: PackedStringArray, timings: Array) -> void:
	if timings.is_empty():
		return
	lines.append("")
	lines.append("--- DUREE ESTIMEE PAR CHAPITRE ---")
	for timing in timings:
		var ch: String = timing.get("chapter_name", "")
		if timing.has("continuation"):
			var sub: Dictionary = timing["continuation"]
			lines.append("  %s (Suite) : de %s a %s" % [
				ch,
				_format_duration(sub.get("min_seconds", 0.0)),
				_format_duration(sub.get("max_seconds", 0.0)),
			])
			var audio_max: float = sub.get("audio_max_seconds", 0.0)
			if audio_max > 0.0:
				lines.append("  %s (Suite) audio : de %s a %s" % [
					ch,
					_format_duration(sub.get("audio_min_seconds", 0.0)),
					_format_duration(sub.get("audio_max_seconds", 0.0)),
				])
		if timing.has("game_over"):
			var sub: Dictionary = timing["game_over"]
			lines.append("  %s (Game Over) : de %s a %s" % [
				ch,
				_format_duration(sub.get("min_seconds", 0.0)),
				_format_duration(sub.get("max_seconds", 0.0)),
			])
			var audio_max: float = sub.get("audio_max_seconds", 0.0)
			if audio_max > 0.0:
				lines.append("  %s (Game Over) audio : de %s a %s" % [
					ch,
					_format_duration(sub.get("audio_min_seconds", 0.0)),
					_format_duration(sub.get("audio_max_seconds", 0.0)),
				])
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/services/test_story_verifier_formatter.gd`
Expected: ALL tests PASS (new + existing).

- [ ] **Step 6: Commit**

```bash
git add src/services/story_verifier_formatter.gd specs/services/test_story_verifier_formatter.gd
git commit -m "feat(verifier): add audio duration lines in text formatter"
```

---

### Task 4: VerifierReportPanel — display audio timings in UI

**Files:**
- Modify: `src/ui/editors/verifier_report_panel.gd`
- Test: `specs/ui/editors/test_verifier_report_panel.gd`

- [ ] **Step 1: Write failing tests for audio lines in UI panel**

Add these tests at the end of `specs/ui/editors/test_verifier_report_panel.gd`, before the helpers:

```gdscript
# === Audio timings UI ===

func test_show_total_audio_timings_when_non_zero():
	var report = _make_success_report()
	report["total_timings"] = {
		"continuation": {"min_seconds": 600.0, "max_seconds": 1200.0, "audio_min_seconds": 300.0, "audio_max_seconds": 900.0},
	}
	_panel.show_report(report)
	var total_list = _panel._report_content.get_node_or_null("TotalTimingsList")
	assert_not_null(total_list)
	# 2 labels: text line + audio line
	assert_eq(total_list.get_child_count(), 2)
	var audio_label: Label = total_list.get_child(1)
	assert_true(audio_label.text.contains("audio"), "Audio label doit contenir 'audio'")

func test_hide_total_audio_timings_when_zero():
	var report = _make_success_report()
	report["total_timings"] = {
		"continuation": {"min_seconds": 600.0, "max_seconds": 1200.0, "audio_min_seconds": 0.0, "audio_max_seconds": 0.0},
	}
	_panel.show_report(report)
	var total_list = _panel._report_content.get_node_or_null("TotalTimingsList")
	assert_not_null(total_list)
	# Only 1 label (text line, no audio line)
	assert_eq(total_list.get_child_count(), 1)

func test_show_chapter_audio_timings_when_non_zero():
	var report = _make_success_report()
	report["chapter_timings"] = [
		{
			"chapter_name": "Chapitre 1",
			"continuation": {"min_seconds": 150.0, "max_seconds": 315.0, "audio_min_seconds": 60.0, "audio_max_seconds": 200.0},
		},
	]
	_panel.show_report(report)
	var timing_list = _panel._report_content.get_node_or_null("ChapterTimingsList")
	assert_not_null(timing_list)
	# 2 labels: text + audio
	assert_eq(timing_list.get_child_count(), 2)
	var audio_label: Label = timing_list.get_child(1)
	assert_true(audio_label.text.contains("audio"), "Audio label doit contenir 'audio'")

func test_hide_chapter_audio_timings_when_zero():
	var report = _make_success_report()
	report["chapter_timings"] = [
		{
			"chapter_name": "Chapitre 1",
			"continuation": {"min_seconds": 150.0, "max_seconds": 315.0, "audio_min_seconds": 0.0, "audio_max_seconds": 0.0},
		},
	]
	_panel.show_report(report)
	var timing_list = _panel._report_content.get_node_or_null("ChapterTimingsList")
	assert_not_null(timing_list)
	assert_eq(timing_list.get_child_count(), 1)

func test_audio_label_color_is_light_blue():
	var report = _make_success_report()
	report["total_timings"] = {
		"continuation": {"min_seconds": 600.0, "max_seconds": 1200.0, "audio_min_seconds": 300.0, "audio_max_seconds": 900.0},
	}
	_panel.show_report(report)
	var total_list = _panel._report_content.get_node_or_null("TotalTimingsList")
	var audio_label: Label = total_list.get_child(1)
	var color = audio_label.get_theme_color("font_color")
	# Light blue: Color(0.6, 0.85, 1.0)
	assert_almost_eq(color.r, 0.6, 0.1)
	assert_almost_eq(color.b, 1.0, 0.1)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/editors/test_verifier_report_panel.gd`
Expected: FAIL — audio labels not created.

- [ ] **Step 3: Add audio labels to total timings section**

In `src/ui/editors/verifier_report_panel.gd`, in `show_report()`, after the continuation label (around line 143), add:

```gdscript
		var audio_max_cont: float = sub.get("audio_max_seconds", 0.0)
		if audio_max_cont > 0.0:
			var audio_item = Label.new()
			var audio_min_str := _format_duration(sub.get("audio_min_seconds", 0.0))
			var audio_max_str := _format_duration(sub.get("audio_max_seconds", 0.0))
			audio_item.text = tr("  Histoire (Suite) audio    de %s  a  %s") % [audio_min_str, audio_max_str]
			audio_item.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			total_list.add_child(audio_item)
```

After the game_over label (around line 151), add:

```gdscript
		var audio_max_go: float = sub.get("audio_max_seconds", 0.0)
		if audio_max_go > 0.0:
			var audio_item = Label.new()
			var audio_min_str := _format_duration(sub.get("audio_min_seconds", 0.0))
			var audio_max_str := _format_duration(sub.get("audio_max_seconds", 0.0))
			audio_item.text = tr("  Histoire (Game Over) audio    de %s  a  %s") % [audio_min_str, audio_max_str]
			audio_item.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			total_list.add_child(audio_item)
```

- [ ] **Step 4: Add audio labels to chapter timings section**

In `src/ui/editors/verifier_report_panel.gd`, in the chapter timings loop, after the continuation label (around line 178), add:

```gdscript
				var audio_max_cont: float = sub.get("audio_max_seconds", 0.0)
				if audio_max_cont > 0.0:
					var audio_item = Label.new()
					var audio_min_str := _format_duration(sub.get("audio_min_seconds", 0.0))
					var audio_max_str := _format_duration(sub.get("audio_max_seconds", 0.0))
					audio_item.text = tr("  %s  (Suite) audio    de %s  a  %s") % [ch_name, audio_min_str, audio_max_str]
					audio_item.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
					timings_list.add_child(audio_item)
```

After the game_over label (around line 187), add:

```gdscript
				var audio_max_go: float = sub.get("audio_max_seconds", 0.0)
				if audio_max_go > 0.0:
					var audio_item = Label.new()
					var audio_min_str := _format_duration(sub.get("audio_min_seconds", 0.0))
					var audio_max_str := _format_duration(sub.get("audio_max_seconds", 0.0))
					audio_item.text = tr("  %s  (Game Over) audio    de %s  a  %s") % [ch_name, audio_min_str, audio_max_str]
					audio_item.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
					timings_list.add_child(audio_item)
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `timeout 30 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://specs/ui/editors/test_verifier_report_panel.gd`
Expected: ALL tests PASS (new + existing).

- [ ] **Step 6: Commit**

```bash
git add src/ui/editors/verifier_report_panel.gd specs/ui/editors/test_verifier_report_panel.gd
git commit -m "feat(verifier): display audio duration in report panel UI"
```

---

### Task 5: Callers — pass story_base_path to verify()

**Files:**
- Modify: `src/controllers/navigation_controller.gd:534-540`
- Modify: `tools/verify_story.gd:101-102`

- [ ] **Step 1: Update navigation_controller.gd**

In `src/controllers/navigation_controller.gd`, modify `on_verify_pressed()` (line 538). Replace:

```gdscript
	var report = verifier.verify(_main._editor_main._story)
```

With:

```gdscript
	var report = verifier.verify(_main._editor_main._story, _main._get_story_base_path())
```

- [ ] **Step 2: Update tools/verify_story.gd**

In `tools/verify_story.gd`, modify `_verify_story()` (line 102). Replace:

```gdscript
	var report = verifier.verify(story)
```

With:

```gdscript
	var report = verifier.verify(story, story_path)
```

- [ ] **Step 3: Run all tests to verify nothing is broken**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd`
Expected: ALL tests PASS.

- [ ] **Step 4: Commit**

```bash
git add src/controllers/navigation_controller.gd tools/verify_story.gd
git commit -m "feat(verifier): pass story_base_path to verify() from callers"
```

---

### Task 6: Full test suite run and cleanup

- [ ] **Step 1: Run the full test suite**

Run: `timeout 120 /Applications/Godot-4.6.1.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd`
Expected: ALL tests PASS. No regressions.

- [ ] **Step 2: Fix any failing tests**

If any existing tests fail because they now receive `audio_min_seconds`/`audio_max_seconds` in timing dicts they didn't expect, update those tests to account for the new keys (the values will be 0.0 since test stories have no real audio files).
