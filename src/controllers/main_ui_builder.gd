# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

extends RefCounted

## Construit l'arborescence UI complète de l'éditeur principal.
## Crée tous les nœuds, les ajoute à l'arbre et stocke les références sur main.

const EditorMainScript = preload("res://src/ui/editors/editor_main.gd")
const BreadcrumbScript = preload("res://src/ui/navigation/breadcrumb.gd")
const ChapterGraphViewScript = preload("res://src/views/chapter_graph_view.gd")
const SceneGraphViewScript = preload("res://src/views/scene_graph_view.gd")
const SequenceGraphViewScript = preload("res://src/views/sequence_graph_view.gd")
const SequenceVisualEditorScript = preload("res://src/ui/sequence/sequence_visual_editor.gd")
const DialogueEditSectionScript = preload("res://src/ui/sequence/dialogue_edit_section.gd")
const ForegroundLayerPanelScript = preload("res://src/ui/sequence/foreground_layer_panel.gd")
const ForegroundPropertiesPanelScript = preload("res://src/ui/sequence/foreground_properties_panel.gd")
const DialogueTimelineScript = preload("res://src/ui/sequence/dialogue_timeline.gd")
const EndingEditorScene = preload("res://src/ui/editors/ending_editor.tscn")
const ForegroundTransitionScript = preload("res://src/ui/visual/foreground_transition.gd")
const SequenceFxPlayerScript = preload("res://src/ui/visual/sequence_fx_player.gd")
const FxPanelScript = preload("res://src/ui/sequence/fx_panel.gd")
const AudioPanelScript = preload("res://src/ui/sequence/audio_panel.gd")
const DialogueEditorScript = preload("res://src/ui/editors/dialogue_editor.gd")
const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")
const ConditionEditorScene = preload("res://src/ui/editors/condition_editor.tscn")
const VariablePanelScene = preload("res://src/ui/editors/variable_panel.tscn")
const VerifierReportPanelScript = preload("res://src/ui/editors/verifier_report_panel.gd")
const VariableSidebarScript = preload("res://src/ui/play/variable_sidebar.gd")
const VariableDetailsOverlayScript = preload("res://src/ui/play/variable_details_overlay.gd")
const StoryMapViewScript = preload("res://src/views/story_map_view.gd")

const MainTheme = preload("res://src/ui/themes/editor_main.tres")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")


static func build(main: Control) -> void:
	main.theme = MainTheme
	_build_top_bar(main)
	_build_content_area(main)
	_build_sequence_editor(main)
	_build_condition_editor(main)
	_build_verifier_panel(main)
	_build_welcome_screen(main)
	_build_play_overlay(main)
	_build_variable_display(main)
	_build_dock_zones(main)
	_build_helpers(main)


static func _build_top_bar(main: Control) -> void:
	main._vbox = VBoxContainer.new()
	main._vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._vbox.add_theme_constant_override("separation", 0)
	main.add_child(main._vbox)

	main._top_bar_panel = PanelContainer.new()
	main._top_bar_panel.theme_type_variation = "TopBar"
	main._top_bar_panel.visible = false
	main._vbox.add_child(main._top_bar_panel)

	main._top_bar = HBoxContainer.new()
	main._top_bar_panel.add_child(main._top_bar)

	main._back_button = Button.new()
	main._back_button.text = TranslationServer.translate("← Retour")
	main._back_button.visible = false
	main._top_bar.add_child(main._back_button)

	main._undo_button = Button.new()
	main._undo_button.text = TranslationServer.translate("← Annuler")
	main._undo_button.disabled = true
	main._undo_button.visible = false
	main._top_bar.add_child(main._undo_button)

	main._redo_button = Button.new()
	main._redo_button.text = TranslationServer.translate("Rétablir →")
	main._redo_button.disabled = true
	main._redo_button.visible = false
	main._top_bar.add_child(main._redo_button)

	main._breadcrumb = HBoxContainer.new()
	main._breadcrumb.set_script(BreadcrumbScript)
	main._breadcrumb.visible = false
	main._top_bar.add_child(main._breadcrumb)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._top_bar.add_child(spacer)

	main._map_button = Button.new()
	main._map_button.text = TranslationServer.translate("🗺 Map")
	main._map_button.visible = false
	main._map_button.toggle_mode = true
	main._top_bar.add_child(main._map_button)

	main._play_lang_selector = OptionButton.new()
	main._play_lang_selector.custom_minimum_size = Vector2(60, 0)
	main._play_lang_selector.tooltip_text = TranslationServer.translate("Langue de prévisualisation")
	main._play_lang_selector.visible = false
	main._top_bar.add_child(main._play_lang_selector)

	main._top_play_button = Button.new()
	main._top_play_button.text = TranslationServer.translate("▶ Jouer")
	main._top_play_button.visible = false
	main._top_bar.add_child(main._top_play_button)

	main._top_stop_button = Button.new()
	main._top_stop_button.text = TranslationServer.translate("■ Arrêter")
	main._top_stop_button.visible = false
	main._top_bar.add_child(main._top_stop_button)

	main._create_button = Button.new()
	main._create_button.visible = false
	main._top_bar.add_child(main._create_button)

	main._create_condition_button = Button.new()
	main._create_condition_button.text = TranslationServer.translate("+ Nouvelle condition")
	main._create_condition_button.visible = false
	main._top_bar.add_child(main._create_condition_button)

	main._parametres_menu = MenuButton.new()
	main._parametres_menu.text = TranslationServer.translate("Paramètres")
	main._parametres_menu.visible = false
	var parametres_popup = main._parametres_menu.get_popup()
	parametres_popup.add_item(TranslationServer.translate("Variables"), 0)
	parametres_popup.add_item(TranslationServer.translate("Configurer le jeu"), 1)
	parametres_popup.add_item(TranslationServer.translate("Galerie"), 2)
	parametres_popup.add_item(TranslationServer.translate("Notifications"), 3)
	parametres_popup.add_separator()
	parametres_popup.add_item(TranslationServer.translate("Langues"), 4)
	main._top_bar.add_child(main._parametres_menu)

	main._histoire_menu = MenuButton.new()
	main._histoire_menu.text = TranslationServer.translate("Histoire")
	main._histoire_menu.visible = false
	var histoire_popup = main._histoire_menu.get_popup()
	var cmd_ctrl = "Cmd" if OS.get_name() == "macOS" else "Ctrl"
	histoire_popup.add_item(TranslationServer.translate("Nouvelle histoire"), 0)
	histoire_popup.add_item(TranslationServer.translate("Charger"), 1)
	histoire_popup.add_separator()
	histoire_popup.add_item(TranslationServer.translate("Sauvegarder (%s+S)") % cmd_ctrl, 2)
	histoire_popup.add_item(TranslationServer.translate("Sauvegarder sous..."), 3)
	histoire_popup.add_separator()
	histoire_popup.add_item(TranslationServer.translate("Exporter"), 4)
	histoire_popup.add_separator()
	histoire_popup.add_item(TranslationServer.translate("Vérifier l'histoire"), 5)
	histoire_popup.add_separator()
	histoire_popup.add_item(TranslationServer.translate("Traductions — Regénérer les clés"), 6)
	histoire_popup.add_item(TranslationServer.translate("Traductions — Vérifier"), 7)
	main._top_bar.add_child(main._histoire_menu)

	# Variable panel popup
	main._variable_panel_popup = PopupPanel.new()
	main._variable_panel_popup.size = Vector2i(400, 350)
	main.add_child(main._variable_panel_popup)

	main._variable_panel = VariablePanelScene.instantiate()
	main._variable_panel_popup.add_child(main._variable_panel)


static func _build_content_area(main: Control) -> void:
	main._content_area = PanelContainer.new()
	main._content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._vbox.add_child(main._content_area)

	# Chapter Graph View
	main._chapter_graph_view = GraphEdit.new()
	main._chapter_graph_view.set_script(ChapterGraphViewScript)
	main._chapter_graph_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._chapter_graph_view.visible = false
	main._content_area.add_child(main._chapter_graph_view)

	# Plugin toolbar overlay for chapter view (anchored to top, hidden when empty)
	main._chapter_plugin_toolbar = HBoxContainer.new()
	main._chapter_plugin_toolbar.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	main._chapter_plugin_toolbar.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	main._chapter_plugin_toolbar.set_anchor_and_offset(SIDE_TOP, 0, 0)
	main._chapter_plugin_toolbar.set_anchor_and_offset(SIDE_BOTTOM, 0, 32)
	main._chapter_plugin_toolbar.visible = false
	main._content_area.add_child(main._chapter_plugin_toolbar)

	# Scene Graph View
	main._scene_graph_view = GraphEdit.new()
	main._scene_graph_view.set_script(SceneGraphViewScript)
	main._scene_graph_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._scene_graph_view.visible = false
	main._content_area.add_child(main._scene_graph_view)

	# Plugin toolbar overlay for scene view (anchored to top, hidden when empty)
	main._scene_plugin_toolbar = HBoxContainer.new()
	main._scene_plugin_toolbar.set_anchor_and_offset(SIDE_LEFT, 0, 0)
	main._scene_plugin_toolbar.set_anchor_and_offset(SIDE_RIGHT, 1, 0)
	main._scene_plugin_toolbar.set_anchor_and_offset(SIDE_TOP, 0, 0)
	main._scene_plugin_toolbar.set_anchor_and_offset(SIDE_BOTTOM, 0, 32)
	main._scene_plugin_toolbar.visible = false
	main._content_area.add_child(main._scene_plugin_toolbar)

	# Sequence Graph View
	main._sequence_graph_view = GraphEdit.new()
	main._sequence_graph_view.set_script(SequenceGraphViewScript)
	main._sequence_graph_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._sequence_graph_view.visible = false
	main._content_area.add_child(main._sequence_graph_view)

	# Story Map View
	main._map_view = GraphEdit.new()
	main._map_view.set_script(StoryMapViewScript)
	main._map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._map_view.visible = false
	main._content_area.add_child(main._map_view)


static func _build_sequence_editor(main: Control) -> void:
	# --- Sequence Editor Panel (VBox: toolbar + HSplit + timeline) ---
	main._sequence_editor_panel = VBoxContainer.new()
	main._sequence_editor_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._sequence_editor_panel.visible = false
	main._content_area.add_child(main._sequence_editor_panel)

	# Sequence Toolbar (inchangé)
	main._sequence_toolbar = HBoxContainer.new()
	main._sequence_editor_panel.add_child(main._sequence_toolbar)

	main._import_bg_button = Button.new()
	main._import_bg_button.text = TranslationServer.translate("Importer background")
	main._sequence_toolbar.add_child(main._import_bg_button)

	main._add_fg_button = Button.new()
	main._add_fg_button.text = "+ Foreground"
	main._sequence_toolbar.add_child(main._add_fg_button)

	main._grid_toggle = Button.new()
	main._grid_toggle.text = TranslationServer.translate("Grille")
	main._grid_toggle.toggle_mode = true
	main._sequence_toolbar.add_child(main._grid_toggle)

	main._snap_toggle = Button.new()
	main._snap_toggle.text = "Snap"
	main._snap_toggle.toggle_mode = true
	main._sequence_toolbar.add_child(main._snap_toggle)

	main._normalize_fg_button = Button.new()
	main._normalize_fg_button.text = TranslationServer.translate("Normaliser")
	main._sequence_toolbar.add_child(main._normalize_fg_button)

	var toolbar_spacer = Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._sequence_toolbar.add_child(toolbar_spacer)

	main._play_button = Button.new()
	main._play_button.text = "▶ Play"
	main._sequence_toolbar.add_child(main._play_button)

	main._stop_button = Button.new()
	main._stop_button.text = "■ Stop"
	main._stop_button.visible = false
	main._sequence_toolbar.add_child(main._stop_button)

	# Main Content (HSplit: canvas left, right panel right)
	main._sequence_content = HSplitContainer.new()
	main._sequence_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._sequence_editor_panel.add_child(main._sequence_content)

	# Left: Visual Editor only (~65%)
	main._visual_editor = Control.new()
	main._visual_editor.set_script(SequenceVisualEditorScript)
	main._visual_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._visual_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._visual_editor.size_flags_stretch_ratio = 1.85
	main._sequence_content.add_child(main._visual_editor)

	# Right Panel (~35%): TabContainer pleine hauteur
	main._tab_container = TabContainer.new()
	main._tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._tab_container.size_flags_stretch_ratio = 1.0
	main._sequence_content.add_child(main._tab_container)
	main._sequence_tab_container = main._tab_container

	# Placeholder right_panel (conservé pour compat API, invisible)
	main._right_panel = VBoxContainer.new()
	main._right_panel.visible = false
	main.add_child(main._right_panel)

	# Tab 0: Texte (dialogue edit)
	var texte_tab = VBoxContainer.new()
	texte_tab.name = TranslationServer.translate("Texte")
	main._tab_container.add_child(texte_tab)

	main._dialogue_edit_section = DialogueEditSectionScript.new()
	texte_tab.add_child(main._dialogue_edit_section)

	# Tab 1: Calques (foreground layers + properties)
	var calques_tab = VBoxContainer.new()
	calques_tab.name = TranslationServer.translate("Calques")
	calques_tab.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._tab_container.add_child(calques_tab)

	main._layer_panel = ForegroundLayerPanelScript.new()
	main._layer_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	calques_tab.add_child(main._layer_panel)

	main._properties_panel = ForegroundPropertiesPanelScript.new()
	calques_tab.add_child(main._properties_panel)

	# Tab 2: Terminaison
	var terminaison_tab = VBoxContainer.new()
	terminaison_tab.name = TranslationServer.translate("Terminaison")
	main._tab_container.add_child(terminaison_tab)

	main._ending_editor = EndingEditorScene.instantiate()
	terminaison_tab.add_child(main._ending_editor)

	# Tab 3: Musique
	var musique_scroll = ScrollContainer.new()
	musique_scroll.name = TranslationServer.translate("Musique")
	musique_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._tab_container.add_child(musique_scroll)

	main._audio_panel = VBoxContainer.new()
	main._audio_panel.set_script(AudioPanelScript)
	main._audio_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	musique_scroll.add_child(main._audio_panel)

	# Tab 4: FX
	main._fx_panel = VBoxContainer.new()
	main._fx_panel.set_script(FxPanelScript)
	main._fx_panel.name = "FX"
	main._fx_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._tab_container.add_child(main._fx_panel)

	# Tab 5: Paramètres / Transitions (Séquence)
	main._sequence_transition_panel = VBoxContainer.new()
	main._sequence_transition_panel.name = TranslationServer.translate("Paramètres")
	main._tab_container.add_child(main._sequence_transition_panel)
	_build_sequence_transition_tab(main)

	# Bottom: Dialogue Timeline
	main._dialogue_timeline = DialogueTimelineScript.new()
	main._sequence_editor_panel.add_child(main._dialogue_timeline)

	# Legacy dialogue editor (kept for API compat)
	main._dialogue_editor = Control.new()
	main._dialogue_editor.set_script(DialogueEditorScript)
	main._dialogue_editor.visible = false
	main.add_child(main._dialogue_editor)


static func _build_sequence_transition_tab(main: Control) -> void:
	var container = main._sequence_transition_panel
	container.add_theme_constant_override("separation", 10)

	# --- Titre de la séquence ---
	var title_sec = Label.new()
	title_sec.text = TranslationServer.translate("Titre de séquence")
	title_sec.add_theme_font_size_override("font_size", 16)
	container.add_child(title_sec)

	var title_hbox = HBoxContainer.new()
	container.add_child(title_hbox)
	var title_label = Label.new()
	title_label.text = TranslationServer.translate("Titre :")
	title_label.custom_minimum_size = Vector2(80, 0)
	title_hbox.add_child(title_label)
	main._seq_title_edit = LineEdit.new()
	main._seq_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(main._seq_title_edit)

	var sub_hbox = HBoxContainer.new()
	container.add_child(sub_hbox)
	var sub_label = Label.new()
	sub_label.text = TranslationServer.translate("Sous-titre :")
	sub_label.custom_minimum_size = Vector2(80, 0)
	sub_hbox.add_child(sub_label)
	main._seq_subtitle_edit = LineEdit.new()
	main._seq_subtitle_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_hbox.add_child(main._seq_subtitle_edit)

	var color_hbox = HBoxContainer.new()
	container.add_child(color_hbox)
	var color_label = Label.new()
	color_label.text = TranslationServer.translate("Fond :")
	color_label.custom_minimum_size = Vector2(80, 0)
	color_hbox.add_child(color_label)
	main._seq_bg_color_picker = ColorPickerButton.new()
	main._seq_bg_color_picker.text = TranslationServer.translate("Couleur")
	main._seq_bg_color_picker.custom_minimum_size = Vector2(100, 0)
	color_hbox.add_child(main._seq_bg_color_picker)

	container.add_child(HSeparator.new())

	var in_title = Label.new()
	in_title.text = TranslationServer.translate("Transition d'entrée")
	in_title.add_theme_font_size_override("font_size", 16)
	container.add_child(in_title)

	var in_type_hbox = HBoxContainer.new()
	container.add_child(in_type_hbox)
	var in_type_label = Label.new()
	in_type_label.text = TranslationServer.translate("Type :")
	in_type_label.custom_minimum_size = Vector2(80, 0)
	in_type_hbox.add_child(in_type_label)
	main._seq_trans_in_type = OptionButton.new()
	main._seq_trans_in_type.add_item(TranslationServer.translate("Aucune"), 0)
	main._seq_trans_in_type.add_item(TranslationServer.translate("Fondu"), 1)
	main._seq_trans_in_type.add_item(TranslationServer.translate("Pixellisation"), 2)
	in_type_hbox.add_child(main._seq_trans_in_type)

	var in_dur_hbox = HBoxContainer.new()
	container.add_child(in_dur_hbox)
	var in_dur_label = Label.new()
	in_dur_label.text = TranslationServer.translate("Durée :")
	in_dur_label.custom_minimum_size = Vector2(80, 0)
	in_dur_hbox.add_child(in_dur_label)
	main._seq_trans_in_dur = SpinBox.new()
	main._seq_trans_in_dur.min_value = 0.1
	main._seq_trans_in_dur.max_value = 5.0
	main._seq_trans_in_dur.step = 0.1
	main._seq_trans_in_dur.value = 0.5
	main._seq_trans_in_dur.suffix = "s"
	in_dur_hbox.add_child(main._seq_trans_in_dur)

	container.add_child(HSeparator.new())

	var out_title = Label.new()
	out_title.text = TranslationServer.translate("Transition de sortie")
	out_title.add_theme_font_size_override("font_size", 16)
	container.add_child(out_title)

	var out_type_hbox = HBoxContainer.new()
	container.add_child(out_type_hbox)
	var out_type_label = Label.new()
	out_type_label.text = TranslationServer.translate("Type :")
	out_type_label.custom_minimum_size = Vector2(80, 0)
	out_type_hbox.add_child(out_type_label)
	main._seq_trans_out_type = OptionButton.new()
	main._seq_trans_out_type.add_item(TranslationServer.translate("Aucune"), 0)
	main._seq_trans_out_type.add_item(TranslationServer.translate("Fondu"), 1)
	main._seq_trans_out_type.add_item(TranslationServer.translate("Pixellisation"), 2)
	out_type_hbox.add_child(main._seq_trans_out_type)

	var out_dur_hbox = HBoxContainer.new()
	container.add_child(out_dur_hbox)
	var out_dur_label = Label.new()
	out_dur_label.text = TranslationServer.translate("Durée :")
	out_dur_label.custom_minimum_size = Vector2(80, 0)
	out_dur_hbox.add_child(out_dur_label)
	main._seq_trans_out_dur = SpinBox.new()
	main._seq_trans_out_dur.min_value = 0.1
	main._seq_trans_out_dur.max_value = 5.0
	main._seq_trans_out_dur.step = 0.1
	main._seq_trans_out_dur.value = 0.5
	main._seq_trans_out_dur.suffix = "s"
	out_dur_hbox.add_child(main._seq_trans_out_dur)


static func _build_condition_editor(main: Control) -> void:
	main._condition_editor_panel = VBoxContainer.new()
	main._condition_editor_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._condition_editor_panel.visible = false
	main._content_area.add_child(main._condition_editor_panel)

	main._condition_editor = ConditionEditorScene.instantiate()
	main._condition_editor_panel.add_child(main._condition_editor)


static func _build_verifier_panel(main: Control) -> void:
	main._verifier_report_panel = VBoxContainer.new()
	main._verifier_report_panel.set_script(VerifierReportPanelScript)
	main._verifier_report_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._verifier_report_panel.visible = false
	main._content_area.add_child(main._verifier_report_panel)


static func _build_play_overlay(main: Control) -> void:
	main._play_overlay = Control.new()
	main._play_overlay.visible = false
	main._play_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	main._play_overlay.offset_top = -150
	main._play_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Dialogue panel — brown background
	main._play_dialogue_panel = PanelContainer.new()
	main._play_dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main._play_overlay.add_child(main._play_dialogue_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	main._play_dialogue_panel.add_child(margin)

	var play_vbox = VBoxContainer.new()
	margin.add_child(play_vbox)

	main._play_text_label = RichTextLabel.new()
	main._play_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._play_text_label.bbcode_enabled = false
	main._play_text_label.fit_content = true
	play_vbox.add_child(main._play_text_label)

	# Character name box — floats above the dialogue panel top border
	main._play_character_box = PanelContainer.new()
	main._play_character_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var btn_tex = load(GameTheme.ASSETS_PATH + "button_brown.png")
	if btn_tex:
		main._play_character_box.add_theme_stylebox_override("panel",
			GameTheme._make_button_stylebox(btn_tex, Color(1, 1, 1, 1)))
	main._play_character_box.anchor_left = 0
	main._play_character_box.anchor_right = 0
	main._play_character_box.anchor_top = 0
	main._play_character_box.anchor_bottom = 0
	var char_left = 24
	main._play_character_box.offset_left = char_left
	main._play_character_box.offset_right = char_left
	main._play_character_box.offset_top = -28
	main._play_character_box.offset_bottom = -28
	main._play_character_box.grow_horizontal = Control.GROW_DIRECTION_END
	main._play_character_box.grow_vertical = Control.GROW_DIRECTION_END
	main._play_overlay.add_child(main._play_character_box)

	main._play_character_label = Label.new()
	main._play_character_box.add_child(main._play_character_label)

	# Typewriter timer
	main._typewriter_timer = Timer.new()
	main._typewriter_timer.wait_time = 0.03
	main.add_child(main._typewriter_timer)

	# Choice overlay (centré via CenterContainer)
	main._choice_overlay = CenterContainer.new()
	main._choice_overlay.visible = false
	main._choice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	main._choice_panel = PanelContainer.new()
	main._choice_panel.custom_minimum_size = Vector2(400, 0)
	main._choice_overlay.add_child(main._choice_panel)

	# Toast overlay (notifications)
	main._toast_overlay = PanelContainer.new()
	main._toast_overlay.visible = false
	main._toast_overlay.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	main._toast_overlay.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	main._toast_overlay.grow_vertical = Control.GROW_DIRECTION_END
	main._toast_overlay.offset_top = 8
	main._toast_overlay.offset_right = -8
	main._toast_overlay.custom_minimum_size = Vector2(250, 0)
	main._toast_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main._toast_overlay.z_index = 100
	main.add_child(main._toast_overlay)

	main._toast_label = Label.new()
	main._toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	main._toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main._toast_overlay.add_child(main._toast_label)

	# --- Play Title Overlay ---
	main._play_title_overlay = CenterContainer.new()
	main._play_title_overlay.visible = false
	main._play_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._play_title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var title_vbox = VBoxContainer.new()
	main._play_title_overlay.add_child(title_vbox)
	
	main._play_title_label = Label.new()
	main._play_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main._play_title_label.add_theme_font_size_override("font_size", 48)
	title_vbox.add_child(main._play_title_label)
	
	main._play_subtitle_label = Label.new()
	main._play_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main._play_subtitle_label.add_theme_font_size_override("font_size", 24)
	main._play_subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	title_vbox.add_child(main._play_subtitle_label)


static func _build_variable_display(main: Control) -> void:
	# Sidebar gauche (cercles + valeurs) — ajoutée au visual editor overlay pendant le play
	main._variable_sidebar = VBoxContainer.new()
	main._variable_sidebar.set_script(VariableSidebarScript)
	main._variable_sidebar.visible = false

	# Overlay de détails
	main._variable_details_overlay = CenterContainer.new()
	main._variable_details_overlay.set_script(VariableDetailsOverlayScript)
	main._variable_details_overlay.build_ui()


static func _build_dock_zones(main: Control) -> void:
	## Plugin dock zones — hidden by default, visible when a plugin adds a panel.
	main._dock_left = PanelContainer.new()
	main._dock_left.visible = false
	main._vbox.add_child(main._dock_left)

	main._dock_right = PanelContainer.new()
	main._dock_right.visible = false
	main._vbox.add_child(main._dock_right)

	main._dock_bottom = PanelContainer.new()
	main._dock_bottom.visible = false
	main._vbox.add_child(main._dock_bottom)


static func _build_helpers(main: Control) -> void:
	# Foreground Transition helper
	main._foreground_transition = Node.new()
	main._foreground_transition.set_script(ForegroundTransitionScript)
	main.add_child(main._foreground_transition)

	# Sequence FX Player
	main._sequence_fx_player = Node.new()
	main._sequence_fx_player.set_script(SequenceFxPlayerScript)
	main.add_child(main._sequence_fx_player)

	# Story Play Controller
	main._story_play_ctrl = Node.new()
	main._story_play_ctrl.set_script(StoryPlayControllerScript)
	main._story_play_ctrl.setup(main._notification_service)
	main.add_child(main._story_play_ctrl)


static func _build_welcome_screen(main: Control) -> void:
	main._welcome_screen = VBoxContainer.new()
	main._welcome_screen.set_anchors_preset(Control.PRESET_CENTER)
	main._welcome_screen.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main._welcome_screen.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main._welcome_screen.add_theme_constant_override("separation", 20)
	main._content_area.add_child(main._welcome_screen)

	var title = Label.new()
	title.text = "Visual Builder"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	main._welcome_screen.add_child(title)

	var subtitle = Label.new()
	subtitle.text = TranslationServer.translate("Éditeur de Visual Novel pour Godot 4")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	main._welcome_screen.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	main._welcome_screen.add_child(spacer)

	var btn_vbox = VBoxContainer.new()
	btn_vbox.add_theme_constant_override("separation", 10)
	main._welcome_screen.add_child(btn_vbox)

	main._new_story_button = Button.new()
	main._new_story_button.text = TranslationServer.translate("Créer une nouvelle histoire")
	main._new_story_button.custom_minimum_size = Vector2(250, 40)
	btn_vbox.add_child(main._new_story_button)

	main._load_story_button = Button.new()
	main._load_story_button.text = TranslationServer.translate("Charger une histoire existante")
	main._load_story_button.custom_minimum_size = Vector2(250, 40)
	btn_vbox.add_child(main._load_story_button)
