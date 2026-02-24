extends Control

## Scène principale — orchestre tous les composants de l'éditeur de visual novel.

const StoryScript = preload("res://src/models/story.gd")
const ChapterScript = preload("res://src/models/chapter.gd")
const SceneDataScript = preload("res://src/models/scene_data.gd")
const SequenceScript = preload("res://src/models/sequence.gd")
const StorySaver = preload("res://src/persistence/story_saver.gd")
const EditorMainScript = preload("res://src/ui/editor_main.gd")
const BreadcrumbScript = preload("res://src/ui/breadcrumb.gd")
const ChapterGraphViewScript = preload("res://src/views/chapter_graph_view.gd")
const SceneGraphViewScript = preload("res://src/views/scene_graph_view.gd")
const SequenceGraphViewScript = preload("res://src/views/sequence_graph_view.gd")
const SequenceVisualEditorScript = preload("res://src/ui/sequence_visual_editor.gd")
const SequenceEditorScript = preload("res://src/ui/sequence_editor.gd")
const DialogueEditorScript = preload("res://src/ui/dialogue_editor.gd")
const DialogueListPanelScript = preload("res://src/ui/dialogue_list_panel.gd")
const EndingEditorScript = preload("res://src/ui/ending_editor.gd")
const TransitionPanelScript = preload("res://src/ui/transition_panel.gd")
const ForegroundTransitionScript = preload("res://src/ui/foreground_transition.gd")
const AIGenerateDialogScript = preload("res://src/ui/ai_generate_dialog.gd")
const ComfyUIConfigScript = preload("res://src/services/comfyui_config.gd")

var _editor_main: Control
var _breadcrumb: HBoxContainer
var _chapter_graph_view: GraphEdit
var _scene_graph_view: GraphEdit
var _sequence_graph_view: GraphEdit
var _sequence_editor_panel: VBoxContainer
var _sequence_toolbar: HBoxContainer
var _import_bg_button: Button
var _add_fg_button: Button
var _ai_generate_btn: Button
var _ai_generate_dialog: Window
var _play_button: Button
var _stop_button: Button
var _sequence_content: HSplitContainer
var _visual_editor: Control
var _dialogue_panel: VBoxContainer
var _dialogue_list_container: VBoxContainer
var _dialogue_editor: Control
var _ending_editor: Control
var _sequence_editor_ctrl: Control
var _transition_panel: VBoxContainer
var _foreground_transition: Node
var _previous_play_foregrounds: Array = []
var _back_button: Button
var _create_button: Button
var _save_button: Button
var _load_button: Button
var _content_area: Control

# Mode Play UI
var _play_overlay: PanelContainer
var _play_character_label: Label
var _play_text_label: RichTextLabel
var _typewriter_timer: Timer

func _ready() -> void:
	_editor_main = Control.new()
	_editor_main.set_script(EditorMainScript)

	_sequence_editor_ctrl = Control.new()
	_sequence_editor_ctrl.set_script(SequenceEditorScript)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(PRESET_FULL_RECT)
	add_child(vbox)

	# --- Top Bar ---
	var top_bar = HBoxContainer.new()
	vbox.add_child(top_bar)

	_back_button = Button.new()
	_back_button.text = "← Retour"
	_back_button.pressed.connect(_on_back_pressed)
	top_bar.add_child(_back_button)

	_breadcrumb = HBoxContainer.new()
	_breadcrumb.set_script(BreadcrumbScript)
	_breadcrumb.level_clicked.connect(_on_breadcrumb_clicked)
	top_bar.add_child(_breadcrumb)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_create_button = Button.new()
	_create_button.pressed.connect(_on_create_pressed)
	top_bar.add_child(_create_button)

	_save_button = Button.new()
	_save_button.text = "Sauvegarder"
	_save_button.pressed.connect(_on_save_pressed)
	top_bar.add_child(_save_button)

	_load_button = Button.new()
	_load_button.text = "Charger une histoire"
	_load_button.pressed.connect(_on_load_pressed)
	top_bar.add_child(_load_button)

	var new_story_button = Button.new()
	new_story_button.text = "Nouvelle histoire"
	new_story_button.pressed.connect(_on_new_story_pressed)
	top_bar.add_child(new_story_button)

	# --- Content Area ---
	_content_area = Control.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_content_area)

	# Chapter Graph View
	_chapter_graph_view = GraphEdit.new()
	_chapter_graph_view.set_script(ChapterGraphViewScript)
	_chapter_graph_view.set_anchors_preset(PRESET_FULL_RECT)
	_chapter_graph_view.chapter_double_clicked.connect(_on_chapter_double_clicked)
	_content_area.add_child(_chapter_graph_view)

	# Scene Graph View
	_scene_graph_view = GraphEdit.new()
	_scene_graph_view.set_script(SceneGraphViewScript)
	_scene_graph_view.set_anchors_preset(PRESET_FULL_RECT)
	_scene_graph_view.scene_double_clicked.connect(_on_scene_double_clicked)
	_content_area.add_child(_scene_graph_view)

	# Sequence Graph View
	_sequence_graph_view = GraphEdit.new()
	_sequence_graph_view.set_script(SequenceGraphViewScript)
	_sequence_graph_view.set_anchors_preset(PRESET_FULL_RECT)
	_sequence_graph_view.sequence_double_clicked.connect(_on_sequence_double_clicked)
	_content_area.add_child(_sequence_graph_view)

	# --- Sequence Editor Panel (VBox: toolbar + content) ---
	_sequence_editor_panel = VBoxContainer.new()
	_sequence_editor_panel.set_anchors_preset(PRESET_FULL_RECT)
	_content_area.add_child(_sequence_editor_panel)

	# Sequence Toolbar
	_sequence_toolbar = HBoxContainer.new()
	_sequence_editor_panel.add_child(_sequence_toolbar)

	_import_bg_button = Button.new()
	_import_bg_button.text = "Importer background"
	_import_bg_button.pressed.connect(_on_import_bg_pressed)
	_sequence_toolbar.add_child(_import_bg_button)

	_add_fg_button = Button.new()
	_add_fg_button.text = "+ Foreground"
	_add_fg_button.pressed.connect(_on_add_foreground_pressed)
	_sequence_toolbar.add_child(_add_fg_button)

	_ai_generate_btn = Button.new()
	_ai_generate_btn.text = "IA Foreground"
	_ai_generate_btn.pressed.connect(_on_ai_generate_pressed)
	_sequence_toolbar.add_child(_ai_generate_btn)

	var toolbar_spacer = Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sequence_toolbar.add_child(toolbar_spacer)

	_play_button = Button.new()
	_play_button.text = "▶ Play"
	_play_button.pressed.connect(_on_play_pressed)
	_sequence_toolbar.add_child(_play_button)

	_stop_button = Button.new()
	_stop_button.text = "■ Stop"
	_stop_button.visible = false
	_stop_button.pressed.connect(_on_stop_pressed)
	_sequence_toolbar.add_child(_stop_button)

	# Sequence Content (HSplit: preview left, dialogues right)
	_sequence_content = HSplitContainer.new()
	_sequence_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sequence_editor_panel.add_child(_sequence_content)

	# Left: Visual Editor + Transition Panel (~65%)
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.85  # ~65%
	_sequence_content.add_child(left_panel)

	_visual_editor = Control.new()
	_visual_editor.set_script(SequenceVisualEditorScript)
	_visual_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(_visual_editor)

	_transition_panel = VBoxContainer.new()
	_transition_panel.set_script(TransitionPanelScript)
	left_panel.add_child(_transition_panel)

	# Right: Dialogue Panel (~35%)
	_dialogue_panel = VBoxContainer.new()
	_dialogue_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_panel.size_flags_stretch_ratio = 1.0  # ~35%
	_sequence_content.add_child(_dialogue_panel)

	# Dialogue list with drag & drop
	var dialogue_scroll = ScrollContainer.new()
	dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_panel.add_child(dialogue_scroll)

	_dialogue_list_container = VBoxContainer.new()
	_dialogue_list_container.set_script(DialogueListPanelScript)
	_dialogue_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dialogue_list_container.dialogue_delete_requested.connect(_on_delete_dialogue)
	dialogue_scroll.add_child(_dialogue_list_container)

	# Add dialogue button
	var add_dialogue_btn = Button.new()
	add_dialogue_btn.text = "+ Ajouter un dialogue"
	add_dialogue_btn.pressed.connect(_on_add_dialogue_pressed)
	_dialogue_panel.add_child(add_dialogue_btn)

	# Ending editor
	_ending_editor = Control.new()
	_ending_editor.set_script(EndingEditorScript)
	_ending_editor.custom_minimum_size.y = 150
	_dialogue_panel.add_child(_ending_editor)

	# Legacy dialogue editor (kept for API compat)
	_dialogue_editor = Control.new()
	_dialogue_editor.set_script(DialogueEditorScript)
	_dialogue_editor.visible = false
	add_child(_dialogue_editor)

	# Play overlay
	_play_overlay = PanelContainer.new()
	_play_overlay.visible = false
	_play_overlay.set_anchors_preset(PRESET_BOTTOM_WIDE)
	_play_overlay.offset_top = -150
	_play_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var play_vbox = VBoxContainer.new()
	_play_overlay.add_child(play_vbox)

	_play_character_label = Label.new()
	_play_character_label.add_theme_font_size_override("font_size", 20)
	play_vbox.add_child(_play_character_label)

	_play_text_label = RichTextLabel.new()
	_play_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_play_text_label.bbcode_enabled = false
	_play_text_label.fit_content = true
	play_vbox.add_child(_play_text_label)

	# Typewriter timer
	_typewriter_timer = Timer.new()
	_typewriter_timer.wait_time = 0.03
	_typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(_typewriter_timer)

	# Foreground Transition helper
	_foreground_transition = Node.new()
	_foreground_transition.set_script(ForegroundTransitionScript)
	add_child(_foreground_transition)

	# Signals from sequence editor controller
	_sequence_editor_ctrl.play_dialogue_changed.connect(_on_play_dialogue_changed)
	_sequence_editor_ctrl.play_stopped.connect(_on_play_stopped)
	_sequence_editor_ctrl.dialogue_selected.connect(_on_dialogue_selected)

	# Signals from visual editor for foreground selection
	_visual_editor.foreground_selected.connect(_on_foreground_selected)
	_visual_editor.foreground_deselected.connect(_on_foreground_deselected)

	_update_view()

# --- Sequence Editor Actions ---

func _on_import_bg_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg ; JPG", "*.jpeg ; JPEG", "*.webp ; WEBP"])
	dialog.file_selected.connect(_on_bg_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_bg_file_selected(path: String) -> void:
	_sequence_editor_ctrl.set_background(path)
	_visual_editor.set_background(path)

func _on_add_foreground_pressed() -> void:
	if _sequence_editor_ctrl.get_selected_dialogue_index() < 0:
		# Aucun dialogue sélectionné — sélectionner le premier s'il existe
		var seq = _sequence_editor_ctrl.get_sequence()
		if seq and seq.dialogues.size() > 0:
			_sequence_editor_ctrl.select_dialogue(0)
		else:
			return
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg ; JPG", "*.jpeg ; JPEG", "*.webp ; WEBP"])
	dialog.file_selected.connect(_on_fg_file_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_fg_file_selected(path: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_sequence_editor_ctrl.add_foreground_to_current("", path)
	_update_preview_for_dialogue(idx)

func _on_ai_generate_pressed() -> void:
	if _sequence_editor_ctrl.get_selected_dialogue_index() < 0:
		var seq = _sequence_editor_ctrl.get_sequence()
		if seq and seq.dialogues.size() > 0:
			_sequence_editor_ctrl.select_dialogue(0)
		else:
			return

	if _ai_generate_dialog == null:
		_ai_generate_dialog = Window.new()
		_ai_generate_dialog.set_script(AIGenerateDialogScript)
		_ai_generate_dialog.foreground_accepted.connect(_on_ai_fg_accepted)
		add_child(_ai_generate_dialog)

	var config = ComfyUIConfigScript.new()
	config.load_from()

	# Pre-fill source image if a foreground is selected
	var source_path = ""
	if _visual_editor._selected_fg_uuid != "":
		var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
		if idx >= 0:
			var fgs = _sequence_editor_ctrl.get_effective_foregrounds(idx)
			for fg in fgs:
				if fg.uuid == _visual_editor._selected_fg_uuid:
					source_path = fg.image
					break

	_ai_generate_dialog.setup(config, source_path)
	if _editor_main._story:
		_ai_generate_dialog.set_story_name(_editor_main._story.title.to_lower().replace(" ", "_"))
	_ai_generate_dialog.popup_centered()

func _on_ai_fg_accepted(image_path: String) -> void:
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		return
	_sequence_editor_ctrl.add_foreground_to_current("", image_path)
	_update_preview_for_dialogue(idx)

func _on_add_dialogue_pressed() -> void:
	_sequence_editor_ctrl.add_dialogue("", "")
	_rebuild_dialogue_list()

func _on_play_pressed() -> void:
	_previous_play_foregrounds = []
	_sequence_editor_ctrl.start_play()
	if _sequence_editor_ctrl.is_playing():
		_play_button.visible = false
		_stop_button.visible = true
		_play_overlay.visible = true
		_visual_editor.add_child(_play_overlay)
		_typewriter_timer.start()

func _on_stop_pressed() -> void:
	_sequence_editor_ctrl.stop_play()

func _on_play_stopped() -> void:
	_play_button.visible = true
	_stop_button.visible = false
	_play_overlay.visible = false
	_typewriter_timer.stop()
	if _play_overlay.get_parent():
		_play_overlay.get_parent().remove_child(_play_overlay)

func _on_play_dialogue_changed(index: int) -> void:
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq == null or index < 0 or index >= seq.dialogues.size():
		return
	var dlg = seq.dialogues[index]
	_play_character_label.text = dlg.character
	_play_text_label.text = dlg.text
	_play_text_label.visible_characters = 0
	# Compute and apply foreground transitions
	var new_fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var transitions = _foreground_transition.compute_transitions(_previous_play_foregrounds, new_fgs)
	_previous_play_foregrounds = new_fgs
	# Update visual preview with effective foregrounds
	_update_preview_for_dialogue(index)
	# Apply Tween transitions on visual editor foreground nodes
	_apply_foreground_transitions(transitions)
	# Highlight in list
	_highlight_dialogue_in_list(index)

func _apply_foreground_transitions(transitions: Array) -> void:
	for t in transitions:
		var target = _visual_editor.get_foreground_node(t["uuid"]) if _visual_editor.has_method("get_foreground_node") else null
		if target == null:
			continue
		if t["action"] == "crossfade":
			_foreground_transition.apply_tween_crossfade(target, t["old_image"], t["duration"])
		elif t["action"] == "fade_in":
			_foreground_transition.apply_tween_fade_in(target, t["duration"])
		elif t["action"] == "fade_out":
			_foreground_transition.apply_tween_fade_out(target, t["duration"])

func _on_typewriter_tick() -> void:
	if not _sequence_editor_ctrl.is_playing():
		_typewriter_timer.stop()
		return
	_sequence_editor_ctrl.advance_typewriter()
	_play_text_label.visible_characters = _sequence_editor_ctrl.get_visible_characters()

func _on_dialogue_selected(index: int) -> void:
	_update_preview_for_dialogue(index)
	_highlight_dialogue_in_list(index)

func _on_foreground_selected(uuid: String) -> void:
	# Chercher le foreground dans les foregrounds effectifs du dialogue courant
	var idx = _sequence_editor_ctrl.get_selected_dialogue_index()
	if idx < 0:
		_transition_panel.hide_panel()
		return
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(idx)
	for fg in fgs:
		if fg.uuid == uuid:
			_transition_panel.show_for_foreground(fg)
			return
	_transition_panel.hide_panel()

func _on_foreground_deselected() -> void:
	_transition_panel.hide_panel()

func _update_preview_for_dialogue(index: int) -> void:
	var fgs = _sequence_editor_ctrl.get_effective_foregrounds(index)
	var seq = _sequence_editor_ctrl.get_sequence()
	if seq:
		# Temporarily replace sequence foregrounds for visual preview
		seq.foregrounds = fgs
		_visual_editor.load_sequence(seq)

func _highlight_dialogue_in_list(index: int) -> void:
	_dialogue_list_container.highlight_item(index)

func _rebuild_dialogue_list() -> void:
	_dialogue_list_container.setup(_sequence_editor_ctrl)

func _on_delete_dialogue(index: int) -> void:
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "Supprimer ce dialogue ?"
	confirm.confirmed.connect(func():
		_sequence_editor_ctrl.remove_dialogue(index)
		_rebuild_dialogue_list()
	)
	add_child(confirm)
	confirm.popup_centered()

# --- Input handling for Play mode ---

func _input(event: InputEvent) -> void:
	if not _sequence_editor_ctrl.is_playing():
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if not _sequence_editor_ctrl.is_text_fully_displayed():
			_sequence_editor_ctrl.skip_typewriter()
			_play_text_label.visible_characters = _sequence_editor_ctrl.get_visible_characters()
		else:
			_sequence_editor_ctrl.advance_play()
		get_viewport().set_input_as_handled()

# --- Original navigation handlers ---

func _on_create_pressed() -> void:
	var level = _editor_main.get_current_level()
	var item_name = _editor_main.get_next_item_name()
	if level == "chapters":
		var pos = _editor_main.compute_next_position(_editor_main._story.chapters)
		_chapter_graph_view.add_new_chapter(item_name, pos)
	elif level == "scenes":
		var pos = _editor_main.compute_next_position(_editor_main._current_chapter.scenes)
		_scene_graph_view.add_new_scene(item_name, pos)
	elif level == "sequences":
		var pos = _editor_main.compute_next_position(_editor_main._current_scene.sequences)
		_sequence_graph_view.add_new_sequence(item_name, pos)

func _on_back_pressed() -> void:
	if _sequence_editor_ctrl.is_playing():
		_sequence_editor_ctrl.stop_play()
	_editor_main.navigate_back()
	_refresh_current_view()

func _on_breadcrumb_clicked(index: int) -> void:
	var level = _editor_main.get_current_level()
	if index == 0 and level != "chapters":
		while _editor_main.get_current_level() != "chapters":
			_editor_main.navigate_back()
	elif index == 1 and (level == "sequences" or level == "sequence_edit"):
		while _editor_main.get_current_level() != "scenes":
			_editor_main.navigate_back()
	elif index == 2 and level == "sequence_edit":
		_editor_main.navigate_back()
	_refresh_current_view()

func _on_save_pressed() -> void:
	if _editor_main._story == null:
		return
	var level = _editor_main.get_current_level()
	if level == "chapters":
		_chapter_graph_view.sync_positions_to_model()
	elif level == "scenes":
		_scene_graph_view.sync_positions_to_model()
	elif level == "sequences":
		_sequence_graph_view.sync_positions_to_model()
	_editor_main._story.touch()
	StorySaver.save_story(_editor_main._story, "user://stories/" + _editor_main._story.title.to_lower().replace(" ", "_"))
	_save_button.text = "Sauvegardé !"
	_save_button.disabled = true
	get_tree().create_timer(2.0).timeout.connect(func():
		_save_button.text = "Sauvegarder"
		_save_button.disabled = false
	)

func _on_new_story_pressed() -> void:
	var story = StoryScript.new()
	story.title = "Mon Histoire"
	story.author = "Auteur"
	story.description = "Une histoire de démonstration"

	var chapter = ChapterScript.new()
	chapter.chapter_name = "Chapitre 1"
	chapter.position = Vector2(100, 100)
	story.chapters.append(chapter)

	var scene = SceneDataScript.new()
	scene.scene_name = "Scène 1"
	scene.position = Vector2(100, 100)
	chapter.scenes.append(scene)

	var seq = SequenceScript.new()
	seq.seq_name = "Séquence 1"
	seq.position = Vector2(100, 100)
	scene.sequences.append(seq)

	_editor_main.open_story(story)
	_refresh_current_view()

func _on_load_pressed() -> void:
	var dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_USERDATA
	dialog.current_dir = "user://stories/"
	dialog.dir_selected.connect(_on_load_dir_selected)
	add_child(dialog)
	dialog.popup_centered(Vector2i(800, 600))

func _on_load_dir_selected(path: String) -> void:
	var loaded_story = StorySaver.load_story(path)
	if loaded_story == null:
		var err_dialog = AcceptDialog.new()
		err_dialog.dialog_text = "Impossible de charger l'histoire : fichier story.yaml introuvable dans le dossier sélectionné."
		add_child(err_dialog)
		err_dialog.popup_centered()
		return
	_editor_main.open_story(loaded_story)
	_refresh_current_view()

func _on_chapter_double_clicked(chapter_uuid: String) -> void:
	_chapter_graph_view.sync_positions_to_model()
	_editor_main.navigate_to_chapter(chapter_uuid)
	_refresh_current_view()

func _on_scene_double_clicked(scene_uuid: String) -> void:
	_scene_graph_view.sync_positions_to_model()
	_editor_main.navigate_to_scene(scene_uuid)
	_refresh_current_view()

func _on_sequence_double_clicked(sequence_uuid: String) -> void:
	_sequence_graph_view.sync_positions_to_model()
	_editor_main.navigate_to_sequence(sequence_uuid)
	if _editor_main._current_sequence:
		_load_sequence_editors(_editor_main._current_sequence)
	_refresh_current_view()

func _load_sequence_editors(seq) -> void:
	_visual_editor.load_sequence(seq)
	_dialogue_editor.load_sequence(seq)
	_ending_editor.load_sequence(seq)
	_sequence_editor_ctrl.load_sequence(seq)
	_rebuild_dialogue_list()
	# Reset play state
	_play_button.visible = true
	_stop_button.visible = false
	_play_overlay.visible = false

func _refresh_current_view() -> void:
	var level = _editor_main.get_current_level()
	if level == "chapters":
		_chapter_graph_view.load_story(_editor_main._story)
	elif level == "scenes":
		_scene_graph_view.load_chapter(_editor_main._current_chapter)
	elif level == "sequences":
		_sequence_graph_view.load_scene(_editor_main._current_scene)
	_update_view()

func _update_view() -> void:
	var level = _editor_main.get_current_level()
	_chapter_graph_view.visible = (level == "chapters")
	_scene_graph_view.visible = (level == "scenes")
	_sequence_graph_view.visible = (level == "sequences")
	_sequence_editor_panel.visible = (level == "sequence_edit")
	_back_button.visible = (level != "chapters" and level != "none")
	_create_button.visible = _editor_main.is_create_button_visible()
	if _create_button.visible:
		_create_button.text = _editor_main.get_create_button_label()
	_breadcrumb.set_path(_editor_main.get_breadcrumb_path())
