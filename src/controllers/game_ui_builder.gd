extends RefCounted

## Construit l'arborescence UI du jeu standalone (play-only, pas d'éditeur).

const SequenceVisualEditorScript = preload("res://src/ui/sequence/sequence_visual_editor.gd")
const ForegroundTransitionScript = preload("res://src/ui/visual/foreground_transition.gd")
const SequenceFxPlayerScript = preload("res://src/ui/visual/sequence_fx_player.gd")
const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")
const SequenceEditorScript = preload("res://src/ui/sequence/sequence_editor.gd")
const MainMenuScript = preload("res://src/ui/menu/main_menu.gd")
const PauseMenuScript = preload("res://src/ui/menu/pause_menu.gd")
const SaveLoadMenuScript = preload("res://src/ui/menu/save_load_menu.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")


static func build(game: Control) -> void:
	game.theme = GameTheme.create_theme()
	_build_visual_editor(game)
	_build_play_overlay(game)
	_build_menu_button(game)
	_build_pause_menu(game)
	_build_helpers(game)
	_build_story_selector(game)
	_build_main_menu(game)
	_build_save_load_menu(game)


static func _build_visual_editor(game: Control) -> void:
	game._visual_editor = Control.new()
	game._visual_editor.set_script(SequenceVisualEditorScript)
	game._visual_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.add_child(game._visual_editor)


static func _build_play_overlay(game: Control) -> void:
	game._play_overlay = PanelContainer.new()
	game._play_overlay.visible = false
	game._play_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	game._play_overlay.offset_top = -150
	game._play_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var play_vbox = VBoxContainer.new()
	game._play_overlay.add_child(play_vbox)

	game._play_character_label = Label.new()
	game._play_character_label.add_theme_font_size_override("font_size", 20)
	game._play_character_label.add_theme_color_override("font_color", Color("#5C3A1E"))
	play_vbox.add_child(game._play_character_label)

	game._play_text_label = RichTextLabel.new()
	game._play_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game._play_text_label.bbcode_enabled = false
	game._play_text_label.fit_content = true
	play_vbox.add_child(game._play_text_label)

	# Typewriter timer
	game._typewriter_timer = Timer.new()
	game._typewriter_timer.wait_time = 0.03
	game.add_child(game._typewriter_timer)

	# Choice overlay
	game._choice_overlay = PanelContainer.new()
	game._choice_overlay.visible = false
	game._choice_overlay.set_anchors_preset(Control.PRESET_CENTER)
	game._choice_overlay.custom_minimum_size = Vector2(400, 0)
	game._choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# --- Play Title Overlay ---
	game._play_title_overlay = CenterContainer.new()
	game._play_title_overlay.visible = false
	game._play_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game._play_title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var title_vbox = VBoxContainer.new()
	game._play_title_overlay.add_child(title_vbox)
	
	game._play_title_label = Label.new()
	game._play_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._play_title_label.add_theme_font_size_override("font_size", 48)
	game._play_title_label.add_theme_color_override("font_color", Color.WHITE)
	title_vbox.add_child(game._play_title_label)

	game._play_subtitle_label = Label.new()
	game._play_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._play_subtitle_label.add_theme_font_size_override("font_size", 24)
	game._play_subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	title_vbox.add_child(game._play_subtitle_label)


static func _build_menu_button(game: Control) -> void:
	game._menu_button = Button.new()
	game._menu_button.text = "☰ Menu"
	game._menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	game._menu_button.offset_left = -100
	game._menu_button.offset_right = -10
	game._menu_button.offset_top = 10
	game._menu_button.offset_bottom = 40
	game._menu_button.visible = false
	game._menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game._menu_button)


static func _build_pause_menu(game: Control) -> void:
	game._pause_menu = Control.new()
	game._pause_menu.set_script(PauseMenuScript)
	game._pause_menu.build_ui()
	game.add_child(game._pause_menu)


static func _build_helpers(game: Control) -> void:
	game._sequence_editor_ctrl = Control.new()
	game._sequence_editor_ctrl.set_script(SequenceEditorScript)
	game.add_child(game._sequence_editor_ctrl)

	game._foreground_transition = Node.new()
	game._foreground_transition.set_script(ForegroundTransitionScript)
	game.add_child(game._foreground_transition)

	game._sequence_fx_player = Node.new()
	game._sequence_fx_player.set_script(SequenceFxPlayerScript)
	game.add_child(game._sequence_fx_player)

	game._story_play_ctrl = Node.new()
	game._story_play_ctrl.set_script(StoryPlayControllerScript)
	game.add_child(game._story_play_ctrl)


static func _build_story_selector(game: Control) -> void:
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.add_child(center)

	game._story_selector = PanelContainer.new()
	game._story_selector.name = "StorySelector"
	game._story_selector.custom_minimum_size = Vector2(500, 400)
	center.add_child(game._story_selector)

	var vbox = VBoxContainer.new()
	game._story_selector.add_child(vbox)

	game._story_selector_title = Label.new()
	game._story_selector_title.text = "Sélectionnez une histoire"
	game._story_selector_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._story_selector_title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(game._story_selector_title)

	var separator = HSeparator.new()
	vbox.add_child(separator)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	game._story_list = VBoxContainer.new()
	game._story_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(game._story_list)


static func _build_main_menu(game: Control) -> void:
	game._main_menu = Control.new()
	game._main_menu.set_script(MainMenuScript)
	game._main_menu.build_ui()
	game._main_menu.visible = false
	game.add_child(game._main_menu)


static func _build_save_load_menu(game: Control) -> void:
	game._save_load_menu = Control.new()
	game._save_load_menu.set_script(SaveLoadMenuScript)
	game._save_load_menu.build_ui()
	game.add_child(game._save_load_menu)
