extends GutTest

# Tests pour le panel de rapport de verification

var VerifierReportPanelScript = load("res://src/ui/editors/verifier_report_panel.gd")

var _panel: VBoxContainer


func before_each():
	_panel = VBoxContainer.new()
	_panel.set_script(VerifierReportPanelScript)
	add_child_autofree(_panel)


# === UI construction ===

func test_panel_builds_ui():
	assert_not_null(_panel.get_node_or_null("Header"))
	assert_not_null(_panel.get_node_or_null("Header/StatusLabel"))
	assert_not_null(_panel.get_node_or_null("Header/CloseButton"))

func test_report_content_exists():
	assert_not_null(_panel._report_content)
	assert_not_null(_panel._scroll)

func test_close_signal_exists():
	assert_has_signal(_panel, "close_requested")


# === Show report ===

func test_show_report_success():
	var report = _make_success_report()
	_panel.show_report(report)
	assert_eq(_panel._status_label.text, "SUCCES")

func test_show_report_failure():
	var report = _make_failure_report()
	_panel.show_report(report)
	assert_eq(_panel._status_label.text, "ECHEC")

func test_show_report_summary():
	var report = _make_success_report()
	_panel.show_report(report)
	var summary = _panel._report_content.get_node_or_null("SummaryPanel")
	assert_not_null(summary, "Summary panel should exist")

func test_show_orphans():
	var report = _make_failure_report()
	report["orphan_nodes"] = [
		{"uuid": "abc", "name": "OrphanSeq", "type": "sequence", "chapter": "Ch1", "scene": "Sc1"},
	]
	_panel.show_report(report)
	var orphan_title = _panel._report_content.get_node_or_null("OrphanTitle")
	assert_not_null(orphan_title, "Orphan title should exist")
	var orphan_list = _panel._report_content.get_node_or_null("OrphanList")
	assert_not_null(orphan_list, "Orphan list should exist")
	assert_eq(orphan_list.get_child_count(), 1)

func test_show_no_orphans():
	var report = _make_success_report()
	_panel.show_report(report)
	var orphan_title = _panel._report_content.get_node_or_null("OrphanTitle")
	assert_null(orphan_title, "Orphan title should not exist when no orphans")

func test_show_run_paths():
	var report = _make_success_report()
	_panel.show_report(report)
	var runs_list = _panel._report_content.get_node_or_null("RunsList")
	assert_not_null(runs_list, "Runs list should exist")
	# At least the header + path steps + spacer
	assert_true(runs_list.get_child_count() > 0)

func test_close_signal():
	watch_signals(_panel)
	var close_btn = _panel.get_node("Header/CloseButton")
	close_btn.emit_signal("pressed")
	assert_signal_emitted(_panel, "close_requested")

func test_clear():
	var report = _make_success_report()
	_panel.show_report(report)
	assert_true(_panel._report_content.get_child_count() > 0)
	_panel.clear()
	# After clear, children are queued for free
	# We wait for the next frame to validate
	await get_tree().process_frame
	assert_eq(_panel._report_content.get_child_count(), 0)


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
	# 1 chapitre avec continuation + game_over = 2 lignes
	assert_eq(timing_list.get_child_count(), 2)

func test_show_chapter_timings_continuation_label_text():
	var report = _make_success_report()
	_panel.show_report(report)
	var timing_list = _panel._report_content.get_node_or_null("ChapterTimingsList")
	assert_not_null(timing_list)
	var label: Label = timing_list.get_child(0)
	# continuation : 150 sec = 2 min 30 sec, 315 sec = 5 min 15 sec
	assert_true(label.text.contains("Chapitre 1"), "Le nom du chapitre doit apparaître")
	assert_true(label.text.contains("(Suite)"), "La ligne continuation doit avoir le label (Suite)")
	assert_true(label.text.contains("2 min 30 sec"), "Le min doit être formaté")
	assert_true(label.text.contains("5 min 15 sec"), "Le max doit être formaté")

func test_show_chapter_timings_game_over_label_text():
	var report = _make_success_report()
	_panel.show_report(report)
	var timing_list = _panel._report_content.get_node_or_null("ChapterTimingsList")
	assert_not_null(timing_list)
	var label: Label = timing_list.get_child(1)
	# game_over : 60 sec = 1 min, 120 sec = 2 min
	assert_true(label.text.contains("Chapitre 1"), "Le nom du chapitre doit apparaître")
	assert_true(label.text.contains("(Game Over)"), "La ligne game_over doit avoir le label (Game Over)")
	assert_true(label.text.contains("1 min"), "Le min doit être formaté")
	assert_true(label.text.contains("2 min"), "Le max doit être formaté")

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


# === Boutons Exporter et Copier ===

func test_export_button_exists():
	assert_not_null(_panel.get_node_or_null("Header/ExportButton"), "Bouton Exporter doit exister dans le header")

func test_copy_button_exists():
	assert_not_null(_panel.get_node_or_null("Header/CopyButton"), "Bouton Copier doit exister dans le header")

func test_copy_button_sets_clipboard_after_show_report():
	if not DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		pending("Presse-papier non disponible en headless")
		return
	var report := _make_success_report()
	_panel.show_report(report)
	var copy_btn: Button = _panel.get_node("Header/CopyButton")
	copy_btn.emit_signal("pressed")
	var clipboard := DisplayServer.clipboard_get()
	assert_true(clipboard.contains("=== RAPPORT DE VERIFICATION ==="), "Le presse-papier doit contenir le rapport")

func test_copy_button_does_not_crash_without_show_report():
	var copy_btn: Button = _panel.get_node("Header/CopyButton")
	copy_btn.emit_signal("pressed")
	assert_true(true)  # Ne doit pas crasher


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
