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
const EndingEditorScript = preload("res://src/ui/editors/ending_editor.gd")
const TransitionPanelScript = preload("res://src/ui/sequence/transition_panel.gd")
const ForegroundTransitionScript = preload("res://src/ui/visual/foreground_transition.gd")
const SequenceFxPlayerScript = preload("res://src/ui/visual/sequence_fx_player.gd")
const FxPanelScript = preload("res://src/ui/sequence/fx_panel.gd")
const DialogueEditorScript = preload("res://src/ui/editors/dialogue_editor.gd")
const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")
const ConditionEditorScript = preload("res://src/ui/editors/condition_editor.gd")
const VariablePanelScript = preload("res://src/ui/editors/variable_panel.gd")
const VerifierReportPanelScript = preload("res://src/ui/editors/verifier_report_panel.gd")


static func build(main: Control) -> void:
	_build_top_bar(main)
	_build_content_area(main)
	_build_sequence_editor(main)
	_build_condition_editor(main)
	_build_verifier_panel(main)
	_build_play_overlay(main)
	_build_helpers(main)


static func _build_top_bar(main: Control) -> void:
	main._vbox = VBoxContainer.new()
	main._vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.add_child(main._vbox)

	main._top_bar = HBoxContainer.new()
	main._vbox.add_child(main._top_bar)

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

	main._variables_button = Button.new()
	main._variables_button.text = "Variables"
	main._top_bar.add_child(main._variables_button)

	main._menu_config_button = Button.new()
	main._menu_config_button.text = "Menu"
	main._top_bar.add_child(main._menu_config_button)

	main._gallery_button = Button.new()
	main._gallery_button.text = "Galerie"
	main._top_bar.add_child(main._gallery_button)

	# Variable panel popup
	main._variable_panel_popup = PopupPanel.new()
	main._variable_panel_popup.size = Vector2i(400, 350)
	main.add_child(main._variable_panel_popup)

	main._variable_panel = VBoxContainer.new()
	main._variable_panel.set_script(VariablePanelScript)
	main._variable_panel_popup.add_child(main._variable_panel)

	main._verify_button = Button.new()
	main._verify_button.text = "Verifier l'histoire"
	main._top_bar.add_child(main._verify_button)

	main._export_button = Button.new()
	main._export_button.text = "Exporter"
	main._top_bar.add_child(main._export_button)

	main._save_button = MenuButton.new()
	main._save_button.text = "Sauvegarder"
	main._save_button.get_popup().add_item("Sauvegarder", 0)
	main._save_button.get_popup().add_item("Sauvegarder sous...", 1)
	main._top_bar.add_child(main._save_button)

	main._load_button = Button.new()
	main._load_button.text = "Charger une histoire"
	main._top_bar.add_child(main._load_button)

	main._new_story_button = Button.new()
	main._new_story_button.text = "Nouvelle histoire"
	main._top_bar.add_child(main._new_story_button)


static func _build_content_area(main: Control) -> void:
	main._content_area = Control.new()
	main._content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main._vbox.add_child(main._content_area)

	# Chapter Graph View
	main._chapter_graph_view = GraphEdit.new()
	main._chapter_graph_view.set_script(ChapterGraphViewScript)
	main._chapter_graph_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._content_area.add_child(main._chapter_graph_view)

	# Scene Graph View
	main._scene_graph_view = GraphEdit.new()
	main._scene_graph_view.set_script(SceneGraphViewScript)
	main._scene_graph_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._content_area.add_child(main._scene_graph_view)

	# Sequence Graph View
	main._sequence_graph_view = GraphEdit.new()
	main._sequence_graph_view.set_script(SequenceGraphViewScript)
	main._sequence_graph_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._content_area.add_child(main._sequence_graph_view)


static func _build_sequence_editor(main: Control) -> void:
	# --- Sequence Editor Panel (VBox: toolbar + content) ---
	main._sequence_editor_panel = VBoxContainer.new()
	main._sequence_editor_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
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

	main._ending_editor = VBoxContainer.new()
	main._ending_editor.set_script(EndingEditorScript)
	main._ending_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
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

	# Legacy dialogue editor (kept for API compat)
	main._dialogue_editor = Control.new()
	main._dialogue_editor.set_script(DialogueEditorScript)
	main._dialogue_editor.visible = false
	main.add_child(main._dialogue_editor)


static func _build_condition_editor(main: Control) -> void:
	main._condition_editor_panel = VBoxContainer.new()
	main._condition_editor_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main._condition_editor_panel.visible = false
	main._content_area.add_child(main._condition_editor_panel)

	main._condition_editor = VBoxContainer.new()
	main._condition_editor.set_script(ConditionEditorScript)
	main._condition_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
	main._play_character_label.add_theme_font_size_override("font_size", 20)
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
	main.add_child(main._story_play_ctrl)
