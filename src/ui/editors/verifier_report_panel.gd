extends VBoxContainer

## Panel de rapport de verification d'histoire.
## Affiche les resultats de la verification : succes/echec, noeuds orphelins, parcours.

signal close_requested

var _status_label: Label
var _summary_label: Label
var _report_content: VBoxContainer
var _scroll: ScrollContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Header
	var header = HBoxContainer.new()
	header.name = "Header"
	add_child(header)

	var title = Label.new()
	title.text = "Rapport de verification"
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_status_label)

	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "Fermer"
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


func show_report(report: Dictionary) -> void:
	clear()

	var success: bool = report.get("success", false)
	_status_label.text = "SUCCES" if success else "ECHEC"
	_status_label.add_theme_color_override("font_color", Color.GREEN if success else Color.RED)

	# Summary panel
	var summary_panel = PanelContainer.new()
	summary_panel.name = "SummaryPanel"
	_report_content.add_child(summary_panel)

	var summary_vbox = VBoxContainer.new()
	summary_panel.add_child(summary_vbox)

	_summary_label = Label.new()
	_summary_label.name = "SummaryLabel"
	var result_text := "Succes" if success else "Echec"
	_summary_label.text = "Resultat : %s\nNoeuds visites : %d / %d\nParcours effectues : %d" % [
		result_text,
		report.get("visited_nodes", 0),
		report.get("all_nodes", 0),
		report.get("total_runs", 0),
	]
	summary_vbox.add_child(_summary_label)

	# Separator
	_report_content.add_child(HSeparator.new())

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
			var ch_name: String = timing.get("chapter_name", "")
			if timing.has("continuation"):
				var item = Label.new()
				var sub: Dictionary = timing["continuation"]
				var min_str := _format_duration(sub.get("min_seconds", 0.0))
				var max_str := _format_duration(sub.get("max_seconds", 0.0))
				item.text = "  %s  (Suite)    de %s  a  %s" % [ch_name, min_str, max_str]
				timings_list.add_child(item)
			if timing.has("game_over"):
				var item = Label.new()
				var sub: Dictionary = timing["game_over"]
				var min_str := _format_duration(sub.get("min_seconds", 0.0))
				var max_str := _format_duration(sub.get("max_seconds", 0.0))
				item.text = "  %s  (Game Over)    de %s  a  %s" % [ch_name, min_str, max_str]
				item.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
				timings_list.add_child(item)

		_report_content.add_child(HSeparator.new())

	# Orphan nodes
	var orphans: Array = report.get("orphan_nodes", [])
	if orphans.size() > 0:
		var orphan_title = Label.new()
		orphan_title.name = "OrphanTitle"
		orphan_title.text = "-- Noeuds orphelins (%d) --" % orphans.size()
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
		runs_title.text = "-- Parcours (%d) --" % runs.size()
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
		"game_over": "Game Over",
		"to_be_continued": "A suivre...",
		"error": "Erreur (cible introuvable)",
		"no_ending": "Pas de terminaison",
		"loop_detected": "Boucle infinie detectee",
	}
	var reason_text: String = reason_labels.get(reason, reason)

	# Run header
	var header = Label.new()
	header.text = "Parcours #%d : %s" % [run_index + 1, reason_text]
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
