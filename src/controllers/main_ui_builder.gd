extends RefCounted

## Construit l'arborescence UI complète de l'éditeur principal.
## Crée tous les nœuds, les ajoute à l'arbre et stocke les références sur main.

const EditorMainScript = preload("res://src/ui/editors/editor_main.gd")
const BreadcrumbScript = preload("res://src/ui/navigation/breadcrumb.gd")
const ChapterGraphViewScript = preload("res://src/views/chapter_graph_view.gd")
const SceneGraphViewScript = preload("res://src/views/scene_graph_view.gd")
const SequenceGraphViewScript = preload("res://src/views/sequence_graph_view.gd")
const SequenceVisualEditorScript = preload("res://src/ui/sequence/sequence_visual_editor.gd")
const DialogueListPanelScript = preload("res://src/ui/sequence/dialogue_list_panel.gd")
const EndingEditorScene = preload("res://src/ui/editors/ending_editor.tscn")
const TransitionPanelScript = preload("res://src/ui/sequence/transition_panel.gd")
const ForegroundTransitionScript = preload("res://src/ui/visual/foreground_transition.gd")
const SequenceFxPlayerScript = preload("res://src/ui/visual/sequence_fx_player.gd")
const FxPanelScript = preload("res://src/ui/sequence/fx_panel.gd")
const DialogueEditorScript = preload("res://src/ui/editors/dialogue_editor.gd")
const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")
const ConditionEditorScene = preload("res://src/ui/editors/condition_editor.tscn")
const VariablePanelScene = preload("res://src/ui/editors/variable_panel.tscn")
const VerifierReportPanelScript = preload("res://src/ui/editors/verifier_report_panel.gd")

const MainTheme = preload("res://src/ui/themes/editor_main.tres")


static func build(main: Control) -> void:
	main.theme = MainTheme
	_build_top_bar(main)
	_build_content_area(main)
	_build_sequence_editor(main)
	_build_condition_editor(main)
	_build_verifier_panel(main)
	_build_welcome_screen(main)
	_build_play_overlay(main)
	_build_helpers(main)


static func _build_top_bar(main: Control) -> void:
	main._vbox = VBoxContainer.new()
	main._vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._vbox.add_theme_constant_override("separation", 0)
	main.add_child(main._vbox)

	var top_panel = PanelContainer.new()
	top_panel.theme_type_variation = "TopBar"
	main._vbox.add_child(top_panel)

	main._top_bar = HBoxContainer.new()
	top_panel.add_child(main._top_bar)

	main._back_button = Button.new()
	main._back_button.text = "← Retour"
	main._top_bar.add_child(main._back_button)

	main._undo_button = Button.new()
	main._undo_button.text = "← Annuler"
	main._undo_button.disabled = true
	main._undo_button.visible = false
	main._top_bar.add_child(main._undo_button)

	main._redo_button = Button.new()
	main._redo_button.text = "Rétablir →"
	main._redo_button.disabled = true
	main._redo_button.visible = false
	main._top_bar.add_child(main._redo_button)

	main._breadcrumb = HBoxContainer.new()
	main._breadcrumb.set_script(BreadcrumbScript)
	main._top_bar.add_child(main._breadcrumb)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._top_bar.add_child(spacer)

	main._top_play_button = Button.new()
	main._top_play_button.text = "▶ Jouer"
	main._top_play_button.visible = false
	main._top_bar.add_child(main._top_play_button)

	main._top_stop_button = Button.new()
	main._top_stop_button.text = "■ Arrêter"
	main._top_stop_button.visible = false
	main._top_bar.add_child(main._top_stop_button)

	main._create_button = Button.new()
	main._top_bar.add_child(main._create_button)

	main._create_condition_button = Button.new()
	main._create_condition_button.text = "+ Nouvelle condition"
	main._top_bar.add_child(main._create_condition_button)

	main._parametres_menu = MenuButton.new()
	main._parametres_menu.text = "Paramètres"
	var parametres_popup = main._parametres_menu.get_popup()
	parametres_popup.add_item("Variables", 0)
	parametres_popup.add_item("Menu", 1)
	parametres_popup.add_item("Galerie", 2)
	parametres_popup.add_item("Notifications", 3)
	parametres_popup.add_separator()
	parametres_popup.add_item("Langues", 4)
	main._top_bar.add_child(main._parametres_menu)

	main._histoire_menu = MenuButton.new()
	main._histoire_menu.text = "Histoire"
	var histoire_popup = main._histoire_menu.get_popup()
	var cmd_ctrl = "Cmd" if OS.get_name() == "macOS" else "Ctrl"
	histoire_popup.add_item("Nouvelle histoire", 0)
	histoire_popup.add_item("Charger", 1)
	histoire_popup.add_separator()
	histoire_popup.add_item("Sauvegarder (%s+S)" % cmd_ctrl, 2)
	histoire_popup.add_item("Sauvegarder sous...", 3)
	histoire_popup.add_separator()
	histoire_popup.add_item("Exporter", 4)
	histoire_popup.add_separator()
	histoire_popup.add_item("Vérifier l'histoire", 5)
	histoire_popup.add_separator()
	histoire_popup.add_item("Traductions — Regénérer les clés", 6)
	histoire_popup.add_item("Traductions — Vérifier", 7)
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

	# Scene Graph View
	main._scene_graph_view = GraphEdit.new()
	main._scene_graph_view.set_script(SceneGraphViewScript)
	main._scene_graph_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._scene_graph_view.visible = false
	main._content_area.add_child(main._scene_graph_view)

	# Sequence Graph View
	main._sequence_graph_view = GraphEdit.new()
	main._sequence_graph_view.set_script(SequenceGraphViewScript)
	main._sequence_graph_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._sequence_graph_view.visible = false
	main._content_area.add_child(main._sequence_graph_view)


static func _build_sequence_editor(main: Control) -> void:
	# --- Sequence Editor Panel (VBox: toolbar + content) ---
	main._sequence_editor_panel = VBoxContainer.new()
	main._sequence_editor_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._sequence_editor_panel.visible = false
	main._content_area.add_child(main._sequence_editor_panel)

	# Sequence Toolbar
	main._sequence_toolbar = HBoxContainer.new()
	main._sequence_editor_panel.add_child(main._sequence_toolbar)

	main._import_bg_button = Button.new()
	main._import_bg_button.text = "Importer background"
	main._sequence_toolbar.add_child(main._import_bg_button)

	main._add_fg_button = Button.new()
	main._add_fg_button.text = "+ Foreground"
	main._sequence_toolbar.add_child(main._add_fg_button)

	main._grid_toggle = Button.new()
	main._grid_toggle.text = "Grille"
	main._grid_toggle.toggle_mode = true
	main._sequence_toolbar.add_child(main._grid_toggle)

	main._snap_toggle = Button.new()
	main._snap_toggle.text = "Snap"
	main._snap_toggle.toggle_mode = true
	main._sequence_toolbar.add_child(main._snap_toggle)

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

	# Sequence Content (HSplit: preview left, dialogues right)
	main._sequence_content = HSplitContainer.new()
	main._sequence_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._sequence_editor_panel.add_child(main._sequence_content)

	# Left: Visual Editor + Transition Panel (~65%)
	main._left_panel = VBoxContainer.new()
	main._left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._left_panel.size_flags_stretch_ratio = 1.85
	main._sequence_content.add_child(main._left_panel)

	main._visual_editor = Control.new()
	main._visual_editor.set_script(SequenceVisualEditorScript)
	main._visual_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._left_panel.add_child(main._visual_editor)

	main._transition_panel = VBoxContainer.new()
	main._transition_panel.set_script(TransitionPanelScript)
	main._left_panel.add_child(main._transition_panel)

	# Right: Dialogue Panel (~35%) with TabContainer
	main._dialogue_panel = VBoxContainer.new()
	main._dialogue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._dialogue_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._dialogue_panel.size_flags_stretch_ratio = 1.0
	main._sequence_content.add_child(main._dialogue_panel)

	main._tab_container = TabContainer.new()
	main._tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main._tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._dialogue_panel.add_child(main._tab_container)

	# Tab 0: Dialogues
	var dialogues_tab = VBoxContainer.new()
	dialogues_tab.name = "Dialogues"
	main._tab_container.add_child(dialogues_tab)

	var dialogue_scroll = ScrollContainer.new()
	dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogues_tab.add_child(dialogue_scroll)

	main._dialogue_list_container = VBoxContainer.new()
	main._dialogue_list_container.set_script(DialogueListPanelScript)
	main._dialogue_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_scroll.add_child(main._dialogue_list_container)

	main._add_dialogue_btn = Button.new()
	main._add_dialogue_btn.text = "+ Ajouter un dialogue"
	dialogues_tab.add_child(main._add_dialogue_btn)

	# Tab 1: Terminaison
	var terminaison_tab = VBoxContainer.new()
	terminaison_tab.name = "Terminaison"
	main._tab_container.add_child(terminaison_tab)

	main._ending_editor = EndingEditorScene.instantiate()
	terminaison_tab.add_child(main._ending_editor)

	# Tab 2: Musique (placeholder)
	var musique_tab = VBoxContainer.new()
	musique_tab.name = "Musique"
	main._tab_container.add_child(musique_tab)
	var musique_label = Label.new()
	musique_label.text = "À venir"
	musique_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	musique_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	musique_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	musique_tab.add_child(musique_label)

	# Tab 3: FX
	main._fx_panel = VBoxContainer.new()
	main._fx_panel.set_script(FxPanelScript)
	main._fx_panel.name = "FX"
	main._fx_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._tab_container.add_child(main._fx_panel)

	# Tab 4: Paramètres / Transitions (Séquence)
	main._sequence_transition_panel = VBoxContainer.new()
	main._sequence_transition_panel.name = "Paramètres"
	main._tab_container.add_child(main._sequence_transition_panel)
	_build_sequence_transition_tab(main)

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
	title_sec.text = "Titre de séquence"
	title_sec.add_theme_font_size_override("font_size", 16)
	container.add_child(title_sec)

	var title_hbox = HBoxContainer.new()
	container.add_child(title_hbox)
	var title_label = Label.new()
	title_label.text = "Titre :"
	title_label.custom_minimum_size = Vector2(80, 0)
	title_hbox.add_child(title_label)
	main._seq_title_edit = LineEdit.new()
	main._seq_title_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(main._seq_title_edit)

	var sub_hbox = HBoxContainer.new()
	container.add_child(sub_hbox)
	var sub_label = Label.new()
	sub_label.text = "Sous-titre :"
	sub_label.custom_minimum_size = Vector2(80, 0)
	sub_hbox.add_child(sub_label)
	main._seq_subtitle_edit = LineEdit.new()
	main._seq_subtitle_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sub_hbox.add_child(main._seq_subtitle_edit)

	var color_hbox = HBoxContainer.new()
	container.add_child(color_hbox)
	var color_label = Label.new()
	color_label.text = "Fond :"
	color_label.custom_minimum_size = Vector2(80, 0)
	color_hbox.add_child(color_label)
	main._seq_bg_color_picker = ColorPickerButton.new()
	main._seq_bg_color_picker.text = "Couleur"
	main._seq_bg_color_picker.custom_minimum_size = Vector2(100, 0)
	color_hbox.add_child(main._seq_bg_color_picker)

	container.add_child(HSeparator.new())

	var in_title = Label.new()
	in_title.text = "Transition d'entrée"
	in_title.add_theme_font_size_override("font_size", 16)
	container.add_child(in_title)

	var in_type_hbox = HBoxContainer.new()
	container.add_child(in_type_hbox)
	var in_type_label = Label.new()
	in_type_label.text = "Type :"
	in_type_label.custom_minimum_size = Vector2(80, 0)
	in_type_hbox.add_child(in_type_label)
	main._seq_trans_in_type = OptionButton.new()
	main._seq_trans_in_type.add_item("Aucune", 0)
	main._seq_trans_in_type.add_item("Fondu", 1)
	main._seq_trans_in_type.add_item("Pixellisation", 2)
	in_type_hbox.add_child(main._seq_trans_in_type)

	var in_dur_hbox = HBoxContainer.new()
	container.add_child(in_dur_hbox)
	var in_dur_label = Label.new()
	in_dur_label.text = "Durée :"
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
	out_title.text = "Transition de sortie"
	out_title.add_theme_font_size_override("font_size", 16)
	container.add_child(out_title)

	var out_type_hbox = HBoxContainer.new()
	container.add_child(out_type_hbox)
	var out_type_label = Label.new()
	out_type_label.text = "Type :"
	out_type_label.custom_minimum_size = Vector2(80, 0)
	out_type_hbox.add_child(out_type_label)
	main._seq_trans_out_type = OptionButton.new()
	main._seq_trans_out_type.add_item("Aucune", 0)
	main._seq_trans_out_type.add_item("Fondu", 1)
	main._seq_trans_out_type.add_item("Pixellisation", 2)
	out_type_hbox.add_child(main._seq_trans_out_type)

	var out_dur_hbox = HBoxContainer.new()
	container.add_child(out_dur_hbox)
	var out_dur_label = Label.new()
	out_dur_label.text = "Durée :"
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
	main._play_overlay = PanelContainer.new()
	main._play_overlay.visible = false
	main._play_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	main._play_overlay.offset_top = -150
	main._play_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var play_vbox = VBoxContainer.new()
	main._play_overlay.add_child(play_vbox)

	main._play_character_label = Label.new()
	# Size is now handled by theme
	play_vbox.add_child(main._play_character_label)

	main._play_text_label = RichTextLabel.new()
	main._play_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._play_text_label.bbcode_enabled = false
	main._play_text_label.fit_content = true
	play_vbox.add_child(main._play_text_label)

	# Typewriter timer
	main._typewriter_timer = Timer.new()
	main._typewriter_timer.wait_time = 0.03
	main.add_child(main._typewriter_timer)

	# Choice overlay (for story play choices)
	main._choice_overlay = PanelContainer.new()
	main._choice_overlay.visible = false
	main._choice_overlay.set_anchors_preset(Control.PRESET_CENTER)
	main._choice_overlay.custom_minimum_size = Vector2(400, 0)
	main._choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

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
	subtitle.text = "Éditeur de Visual Novel pour Godot 4"
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
	main._new_story_button.text = "Créer une nouvelle histoire"
	main._new_story_button.custom_minimum_size = Vector2(250, 40)
	btn_vbox.add_child(main._new_story_button)

	main._load_story_button = Button.new()
	main._load_story_button.text = "Charger une histoire existante"
	main._load_story_button.custom_minimum_size = Vector2(250, 40)
	btn_vbox.add_child(main._load_story_button)
