# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends VBoxContainer

## Panel de rapport de verification d'histoire.
## Affiche les resultats de la verification : succes/echec, noeuds orphelins, parcours.

signal close_requested

var _status_label: Label
var _summary_label: Label
var _report_content: VBoxContainer
var _scroll: ScrollContainer
var _formatter := StoryVerifierFormatter.new()
var _report: Dictionary = {}


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Header
	var header = HBoxContainer.new()
	header.name = "Header"
	add_child(header)

	var title = Label.new()
	title.text = tr("Rapport de verification")
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_status_label)

	var export_btn = Button.new()
	export_btn.name = "ExportButton"
	export_btn.text = tr("Exporter")
	export_btn.pressed.connect(_on_export_pressed)
	header.add_child(export_btn)

	var copy_btn = Button.new()
	copy_btn.name = "CopyButton"
	copy_btn.text = tr("Copier")
	copy_btn.pressed.connect(_on_copy_pressed)
	header.add_child(copy_btn)

	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = tr("Fermer")
	close_btn.pressed.connect(func(): close_requested.emit())
	header.add_child(close_btn)

	# Separator
	var sep = HSeparator.new()
	add_child(sep)

	# Scroll area
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_scroll)

	_report_content = VBoxContainer.new()
	_report_content.name = "ReportContent"
	_report_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_report_content)


func _on_export_pressed() -> void:
	var text := _formatter.format(_report)
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.txt"])
	dialog.current_file = "rapport_verification.txt"
	add_child(dialog)
	dialog.file_selected.connect(func(path: String):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text)
			f.close()
		dialog.queue_free()
	)
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered_ratio(0.6)


func _on_copy_pressed() -> void:
	var text := _formatter.format(_report)
	DisplayServer.clipboard_set(text)


func show_report(report: Dictionary) -> void:
	_report = report
	clear()

	var success: bool = report.get("success", false)
	_status_label.text = tr("SUCCES") if success else tr("ECHEC")
	_status_label.add_theme_color_override("font_color", Color.GREEN if success else Color.RED)

	# Summary panel
	var summary_panel = PanelContainer.new()
	summary_panel.name = "SummaryPanel"
	_report_content.add_child(summary_panel)

	var summary_vbox = VBoxContainer.new()
	summary_panel.add_child(summary_vbox)

	_summary_label = Label.new()
	_summary_label.name = "SummaryLabel"
	var result_text := tr("Succes") if success else tr("Echec")
	_summary_label.text = tr("Resultat : %s\nNoeuds visites : %d / %d\nParcours effectues : %d") % [
		result_text,
		report.get("visited_nodes", 0),
		report.get("all_nodes", 0),
		report.get("total_runs", 0),
	]
	summary_vbox.add_child(_summary_label)

	# Total timings
	var total_timings: Dictionary = report.get("total_timings", {})
	if not total_timings.is_empty():
		var total_title = Label.new()
		total_title.name = "TotalTimingsTitle"
		total_title.text = tr("-- Duree totale estimee --")
		total_title.add_theme_font_size_override("font_size", 15)
		total_title.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8))
		_report_content.add_child(total_title)

		var total_list = VBoxContainer.new()
		total_list.name = "TotalTimingsList"
		_report_content.add_child(total_list)

		var total_buckets = {
			"to_be_continued": {"label": tr("  Histoire (Suite)    de %s  a  %s"), "color": Color.WHITE},
			"the_end": {"label": tr("  Histoire (The End)    de %s  a  %s"), "color": Color.WHITE},
			"game_over": {"label": tr("  Histoire (Game Over)    de %s  a  %s"), "color": Color(1.0, 0.5, 0.5)}
		}

		for bucket in total_buckets:
			if total_timings.has(bucket):
				var cfg = total_buckets[bucket]
				var sub: Dictionary = total_timings[bucket]
				var item = Label.new()
				var min_str := _format_duration(sub.get("min_seconds", 0.0))
				var max_str := _format_duration(sub.get("max_seconds", 0.0))
				item.text = cfg["label"] % [min_str, max_str]
				item.add_theme_color_override("font_color", cfg["color"])
				total_list.add_child(item)
				
				var audio_max: float = sub.get("audio_max_seconds", 0.0)
				if audio_max > 0.0:
					var audio_item = Label.new()
					var audio_min_str := _format_duration(sub.get("audio_min_seconds", 0.0))
					var audio_max_str := _format_duration(sub.get("audio_max_seconds", 0.0))
					var audio_lbl_base = cfg["label"].replace("    de", " audio    de")
					audio_item.text = audio_lbl_base % [audio_min_str, audio_max_str]
					audio_item.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
					total_list.add_child(audio_item)

		_report_content.add_child(HSeparator.new())

	# Separator
	# (Chapter timings follow...)
	var chapter_timings: Array = report.get("chapter_timings", [])
	if chapter_timings.size() > 0:
		var timings_title = Label.new()
		timings_title.name = "ChapterTimingsTitle"
		timings_title.text = tr("-- Duree estimee par chapitre --")
		timings_title.add_theme_font_size_override("font_size", 15)
		timings_title.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
		_report_content.add_child(timings_title)

		var timings_list = VBoxContainer.new()
		timings_list.name = "ChapterTimingsList"
		_report_content.add_child(timings_list)

		var chapter_buckets = {
			"to_be_continued": {"label": tr("  %s  (Suite)    de %s  a  %s"), "color": Color.WHITE},
			"the_end": {"label": tr("  %s  (The End)    de %s  a  %s"), "color": Color.WHITE},
			"game_over": {"label": tr("  %s  (Game Over)    de %s  a  %s"), "color": Color(1.0, 0.5, 0.5)}
		}

		for timing in chapter_timings:
			var ch_name: String = timing.get("chapter_name", "")
			for bucket in chapter_buckets:
				if timing.has(bucket):
					var cfg = chapter_buckets[bucket]
					var sub: Dictionary = timing[bucket]
					var item = Label.new()
					var min_str := _format_duration(sub.get("min_seconds", 0.0))
					var max_str := _format_duration(sub.get("max_seconds", 0.0))
					item.text = cfg["label"] % [ch_name, min_str, max_str]
					item.add_theme_color_override("font_color", cfg["color"])
					timings_list.add_child(item)
					
					var audio_max: float = sub.get("audio_max_seconds", 0.0)
					if audio_max > 0.0:
						var audio_item = Label.new()
						var audio_min_str := _format_duration(sub.get("audio_min_seconds", 0.0))
						var audio_max_str := _format_duration(sub.get("audio_max_seconds", 0.0))
						var audio_lbl_base = cfg["label"].replace("    de", " audio    de")
						audio_item.text = audio_lbl_base % [ch_name, audio_min_str, audio_max_str]
						audio_item.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
						timings_list.add_child(audio_item)

		_report_content.add_child(HSeparator.new())

	# Orphan nodes
	var orphans: Array = report.get("orphan_nodes", [])
	if orphans.size() > 0:
		var orphan_title = Label.new()
		orphan_title.name = "OrphanTitle"
		orphan_title.text = tr("-- Noeuds orphelins (%d) --") % orphans.size()
		orphan_title.add_theme_font_size_override("font_size", 15)
		orphan_title.add_theme_color_override("font_color", Color.ORANGE)
		_report_content.add_child(orphan_title)

		var orphan_list = VBoxContainer.new()
		orphan_list.name = "OrphanList"
		_report_content.add_child(orphan_list)

		for orphan in orphans:
			var item = Label.new()
			var type_str: String = "Condition" if orphan.get("type", "") == "condition" else "Sequence"
			item.text = "  [%s] %s  (%s > %s)" % [type_str, orphan.get("name", ""), orphan.get("chapter", ""), orphan.get("scene", "")]
			item.add_theme_color_override("font_color", Color.ORANGE)
			orphan_list.add_child(item)

		_report_content.add_child(HSeparator.new())

	# Runs
	var runs: Array = report.get("runs", [])
	if runs.size() > 0:
		var runs_title = Label.new()
		runs_title.name = "RunsTitle"
		runs_title.text = tr("-- Parcours (%d) --") % runs.size()
		runs_title.add_theme_font_size_override("font_size", 15)
		_report_content.add_child(runs_title)

		var runs_list = VBoxContainer.new()
		runs_list.name = "RunsList"
		_report_content.add_child(runs_list)

		for run in runs:
			_add_run_item(runs_list, run)


func _add_run_item(parent: VBoxContainer, run: Dictionary) -> void:
	var is_valid: bool = run.get("is_valid", false)
	var reason: String = run.get("ending_reason", "unknown")
	var run_index: int = run.get("run_index", 0)
	var color := Color.GREEN if is_valid else Color.RED

	var reason_labels := {
		"game_over": tr("Game Over"),
		"to_be_continued": tr("A suivre..."),
		"error": tr("Erreur (cible introuvable)"),
		"no_ending": tr("Pas de terminaison"),
		"loop_detected": tr("Boucle infinie detectee"),
	}
	var reason_text: String = reason_labels.get(reason, reason)

	# Run header
	var header = Label.new()
	header.text = tr("Parcours #%d : %s") % [run_index + 1, reason_text]
	header.add_theme_color_override("font_color", color)
	header.add_theme_font_size_override("font_size", 14)
	parent.add_child(header)

	# Path details
	var path: Array = run.get("path", [])
	for step in path:
		var step_label = Label.new()
		var step_type: String = step.get("type", "")
		var step_name: String = step.get("name", "")
		if step_type == "choice":
			step_label.text = "    -> %s" % step_name
			step_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		elif step_type == "condition":
			step_label.text = "    [Condition] %s" % step_name
			step_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		else:
			step_label.text = "    %s" % step_name
		parent.add_child(step_label)

	# Spacer between runs
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 8
	parent.add_child(spacer)


func _format_duration(seconds: float) -> String:
	var total_sec := int(round(seconds))
	var m := total_sec / 60
	var s := total_sec % 60
	if m == 0:
		return "%d sec" % s
	if s == 0:
		return "%d min" % m
	return "%d min %d sec" % [m, s]


func clear() -> void:
	for child in _report_content.get_children():
		child.queue_free()