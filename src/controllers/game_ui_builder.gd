extends RefCounted

## Construit l'arborescence UI du jeu standalone (play-only, pas d'éditeur).

const UIScale = preload("res://src/ui/themes/ui_scale.gd")
const SequenceVisualEditorScript = preload("res://src/ui/sequence/sequence_visual_editor.gd")
const ForegroundTransitionScript = preload("res://src/ui/visual/foreground_transition.gd")
const SequenceFxPlayerScript = preload("res://src/ui/visual/sequence_fx_player.gd")
const StoryPlayControllerScript = preload("res://src/ui/play/story_play_controller.gd")
const SequenceEditorScript = preload("res://src/ui/sequence/sequence_editor.gd")
const MainMenuScript = preload("res://src/ui/menu/main_menu.gd")
const EndingScreenScript = preload("res://src/ui/menu/ending_screen.gd")
const PauseMenuScript = preload("res://src/ui/menu/pause_menu.gd")
const SaveLoadMenuScript = preload("res://src/ui/menu/save_load_menu.gd")
const ChapterSceneMenuScript = preload("res://src/ui/menu/chapter_scene_menu.gd")
const GameTheme = preload("res://src/ui/themes/game_theme.gd")
const VariableSidebarScript = preload("res://src/ui/play/variable_sidebar.gd")
const VariableDetailsOverlayScript = preload("res://src/ui/play/variable_details_overlay.gd")
const MusicPlayerScript = preload("res://src/services/music_player.gd")


static func build(game: Control) -> void:
	game.theme = GameTheme.create_theme()
	_build_visual_editor(game)
	_build_play_overlay(game)
	_build_helpers(game)
	_build_story_selector(game)
	_build_main_menu(game)
	_build_ending_screens(game)
	_build_save_load_menu(game)
	_build_chapter_scene_menu(game)
	_build_pause_menu(game)
	_build_variable_display(game)
	_build_menu_button(game)
	_build_music_player(game)
	# Play buttons bar (Save, Load, Auto) — added last so it renders on top of everything
	_build_play_buttons_bar(game)
	_build_game_plugin_containers(game)
	_build_toast_overlay(game)
	_build_loading_overlay(game)
	_build_quickload_confirm(game)


static func _build_visual_editor(game: Control) -> void:
	game._visual_editor = Control.new()
	game._visual_editor.set_script(SequenceVisualEditorScript)
	game._visual_editor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.add_child(game._visual_editor)


static func _build_play_overlay(game: Control) -> void:
	var s := UIScale.get_scale()
	game._play_overlay = PanelContainer.new()
	game._play_overlay.visible = false
	game._play_overlay.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._play_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	game._play_overlay.offset_top = -roundi(150 * s)
	game._play_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var play_vbox = VBoxContainer.new()
	game._play_overlay.add_child(play_vbox)

	game._play_character_label = Label.new()
	game._play_character_label.add_theme_font_size_override("font_size", UIScale.scale(28))
	game._play_character_label.add_theme_color_override("font_color", Color("#5C3A1E"))
	play_vbox.add_child(game._play_character_label)

	game._play_text_label = RichTextLabel.new()
	game._play_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	game._play_text_label.bbcode_enabled = false
	game._play_text_label.fit_content = true
	game._play_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_vbox.add_child(game._play_text_label)

	# Boutons de jeu — créés ici, ajoutés dans _build_play_buttons_bar() à la fin
	var btn_size := Vector2(UIScale.scale(120), UIScale.scale(30))
	game._quicksave_button = Button.new()
	game._quicksave_button.text = "Save (F5)"
	game._quicksave_button.custom_minimum_size = btn_size
	game._quicksave_button.clip_text = true

	game._quickload_button = Button.new()
	game._quickload_button.text = "Load (F9)"
	game._quickload_button.custom_minimum_size = btn_size
	game._quickload_button.clip_text = true

	game._auto_play_button = Button.new()
	game._auto_play_button.text = "Auto"
	game._auto_play_button.custom_minimum_size = btn_size
	game._auto_play_button.clip_text = true

	game._skip_button = Button.new()
	game._skip_button.text = "Skip (S)"
	game._skip_button.custom_minimum_size = btn_size
	game._skip_button.clip_text = true
	game._skip_button.disabled = true

	game._history_button = Button.new()
	game._history_button.text = "Histo (H)"
	game._history_button.custom_minimum_size = btn_size
	game._history_button.clip_text = true
	game._history_button.disabled = true

	# Typewriter timer
	game._typewriter_timer = Timer.new()
	game._typewriter_timer.wait_time = 0.03
	game.add_child(game._typewriter_timer)

	# Choice overlay (centré via CenterContainer)
	game._choice_overlay = CenterContainer.new()
	game._choice_overlay.visible = false
	game._choice_overlay.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._choice_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._choice_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	game._choice_panel = PanelContainer.new()
	game._choice_panel.custom_minimum_size = Vector2(UIScale.scale(400), 0)
	game._choice_overlay.add_child(game._choice_panel)

	# --- Play Title Overlay ---
	game._play_title_overlay = CenterContainer.new()
	game._play_title_overlay.visible = false
	game._play_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game._play_title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var title_vbox = VBoxContainer.new()
	game._play_title_overlay.add_child(title_vbox)
	
	game._play_title_label = Label.new()
	game._play_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._play_title_label.add_theme_font_size_override("font_size", UIScale.scale(64))
	game._play_title_label.add_theme_color_override("font_color", Color.WHITE)
	title_vbox.add_child(game._play_title_label)

	game._play_subtitle_label = Label.new()
	game._play_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._play_subtitle_label.add_theme_font_size_override("font_size", UIScale.scale(36))
	game._play_subtitle_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	title_vbox.add_child(game._play_subtitle_label)


static func _build_play_buttons_bar(game: Control) -> void:
	var s := UIScale.get_scale()
	game._play_buttons_bar = HBoxContainer.new()
	game._play_buttons_bar.visible = false
	game._play_buttons_bar.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._play_buttons_bar.alignment = BoxContainer.ALIGNMENT_END
	game._play_buttons_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	game._play_buttons_bar.offset_top = -roundi(188 * s)
	game._play_buttons_bar.offset_bottom = -roundi(150 * s)
	game._play_buttons_bar.offset_right = -3
	game._play_buttons_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	game._play_buttons_bar.add_theme_constant_override("separation", 4)
	game._play_buttons_bar.add_child(game._quicksave_button)
	game._play_buttons_bar.add_child(game._quickload_button)
	game._play_buttons_bar.add_child(game._auto_play_button)
	game._play_buttons_bar.add_child(game._skip_button)
	game._play_buttons_bar.add_child(game._history_button)
	game.add_child(game._play_buttons_bar)

	# Toggle button — small floating overlay at bottom-right to show/hide toolbar
	game._toolbar_toggle_button = Button.new()
	game._toolbar_toggle_button.text = "≡"
	game._toolbar_toggle_button.visible = false
	game._toolbar_toggle_button.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._toolbar_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var btn_s := roundi(36 * s)
	game._toolbar_toggle_button.offset_left = -btn_s - roundi(12 * s)
	game._toolbar_toggle_button.offset_right = -roundi(12 * s)
	game._toolbar_toggle_button.offset_top = -roundi(160 * s)
	game._toolbar_toggle_button.offset_bottom = -roundi(160 * s) + btn_s
	game._toolbar_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	game.add_child(game._toolbar_toggle_button)


static func _build_toast_overlay(game: Control) -> void:
	var s := UIScale.get_scale()
	game._toast_overlay = PanelContainer.new()
	game._toast_overlay.visible = false
	game._toast_overlay.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	game._toast_overlay.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	game._toast_overlay.grow_vertical = Control.GROW_DIRECTION_END
	game._toast_overlay.offset_top = roundi(8 * s)
	game._toast_overlay.offset_right = -roundi(8 * s)
	game._toast_overlay.custom_minimum_size = Vector2(UIScale.scale(300), 0)
	game._toast_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._toast_overlay.z_index = 100
	game.add_child(game._toast_overlay)

	game._toast_label = Label.new()
	game._toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	game._toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._toast_overlay.add_child(game._toast_label)


static func _build_loading_overlay(game: Control) -> void:
	game._loading_overlay = Control.new()
	game._loading_overlay.visible = false
	game._loading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game._loading_overlay.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game.add_child(game._loading_overlay)
	game._loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := TextureRect.new()
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	game._loading_overlay_bg = bg
	game._loading_overlay.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.7)
	game._loading_overlay.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	game._loading_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	game._loading_overlay_label = Label.new()
	game._loading_overlay_label.text = "Chargement..."
	game._loading_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._loading_overlay_label.add_theme_font_size_override("font_size", UIScale.scale(40))
	game._loading_overlay_label.add_theme_color_override("font_color", Color.WHITE)
	center.add_child(game._loading_overlay_label)


static func _build_quickload_confirm(game: Control) -> void:
	game._quickload_confirm_overlay = Control.new()
	game._quickload_confirm_overlay.visible = false
	game._quickload_confirm_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._quickload_confirm_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game._quickload_confirm_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	game._quickload_confirm_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game._quickload_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(UIScale.scale(400), 0)
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", UIScale.scale(16))
	panel.add_child(vbox)

	game._quickload_confirm_label = Label.new()
	game._quickload_confirm_label.text = "Charger la sauvegarde rapide ?"
	game._quickload_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._quickload_confirm_label.add_theme_font_size_override("font_size", UIScale.scale(28))
	vbox.add_child(game._quickload_confirm_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", UIScale.scale(16))
	vbox.add_child(hbox)

	game._quickload_yes_btn = Button.new()
	game._quickload_yes_btn.text = "Oui"
	game._quickload_yes_btn.custom_minimum_size = Vector2(UIScale.scale(120), UIScale.scale(40))
	hbox.add_child(game._quickload_yes_btn)

	game._quickload_no_btn = Button.new()
	game._quickload_no_btn.text = "Non"
	game._quickload_no_btn.custom_minimum_size = Vector2(UIScale.scale(120), UIScale.scale(40))
	hbox.add_child(game._quickload_no_btn)


static func _build_menu_button(game: Control) -> void:
	var s := UIScale.get_scale()
	game._menu_button = Button.new()
	game._menu_button.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._menu_button.text = "Menu"
	game._menu_button.icon = _create_hamburger_icon(roundi(16 * s), GameTheme.COLOR_BUTTON_TEXT)
	game._menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	game._menu_button.offset_left = -roundi(100 * s)
	game._menu_button.offset_right = -roundi(10 * s)
	game._menu_button.offset_top = roundi(10 * s)
	game._menu_button.offset_bottom = roundi(40 * s)
	game._menu_button.visible = false
	game._menu_button.process_mode = Node.PROCESS_MODE_ALWAYS
	game.add_child(game._menu_button)


## Génère une icône hamburger (3 lignes horizontales) comme ImageTexture.
## Fonctionne sur toutes les plateformes sans dépendance de police.
static func _create_hamburger_icon(size: int, color: Color) -> ImageTexture:
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var line_h: int = maxi(1, roundi(size * 0.12))
	var gap: int = roundi(size * 0.22)
	var y_positions: Array[int] = [
		roundi(size * 0.18),
		roundi(size * 0.18) + line_h + gap,
		roundi(size * 0.18) + (line_h + gap) * 2,
	]
	for y_start in y_positions:
		for dy in range(line_h):
			for x in range(size):
				img.set_pixel(x, y_start + dy, color)
	return ImageTexture.create_from_image(img)


static func _build_pause_menu(game: Control) -> void:
	game._pause_menu = Control.new()
	game._pause_menu.set_script(PauseMenuScript)
	game._pause_menu.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
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
	game._story_selector.custom_minimum_size = Vector2(UIScale.scale(500), UIScale.scale(400))
	center.add_child(game._story_selector)

	var vbox = VBoxContainer.new()
	game._story_selector.add_child(vbox)

	game._story_selector_title = Label.new()
	game._story_selector_title.text = "Sélectionnez une histoire"
	game._story_selector_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game._story_selector_title.add_theme_font_size_override("font_size", UIScale.scale(36))
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


static func _build_ending_screens(game: Control) -> void:
	game._game_over_screen = Control.new()
	game._game_over_screen.set_script(EndingScreenScript)
	game._game_over_screen.build_ui("Game Over")
	game.add_child(game._game_over_screen)

	game._to_be_continued_screen = Control.new()
	game._to_be_continued_screen.set_script(EndingScreenScript)
	game._to_be_continued_screen.build_ui("À suivre...")
	game.add_child(game._to_be_continued_screen)


static func _build_save_load_menu(game: Control) -> void:
	game._save_load_menu = Control.new()
	game._save_load_menu.set_script(SaveLoadMenuScript)
	game._save_load_menu.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._save_load_menu.build_ui()
	game.add_child(game._save_load_menu)


static func _build_chapter_scene_menu(game: Control) -> void:
	game._chapter_scene_menu = Control.new()
	game._chapter_scene_menu.set_script(ChapterSceneMenuScript)
	game._chapter_scene_menu.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._chapter_scene_menu.build_ui()
	game.add_child(game._chapter_scene_menu)


static func _build_music_player(game: Control) -> void:
	game._music_player = Node.new()
	game._music_player.set_script(MusicPlayerScript)
	game.add_child(game._music_player)


static func _build_game_plugin_containers(game: Control) -> void:
	var s := UIScale.get_scale()

	# Container toolbar au-dessus du dialogue (HBoxContainer, aligné à gauche)
	game._plugin_toolbar = HBoxContainer.new()
	game._plugin_toolbar.visible = false
	game._plugin_toolbar.alignment = BoxContainer.ALIGNMENT_BEGIN
	game._plugin_toolbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	game._plugin_toolbar.offset_top = -roundi(188 * s)
	game._plugin_toolbar.offset_bottom = -roundi(150 * s)
	game._plugin_toolbar.offset_left = 3
	game._plugin_toolbar.mouse_filter = Control.MOUSE_FILTER_PASS
	game.add_child(game._plugin_toolbar)

	# Overlay gauche (VBoxContainer, bord gauche)
	game._plugin_overlay_left = VBoxContainer.new()
	game._plugin_overlay_left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	game._plugin_overlay_left.offset_left = roundi(10 * s)
	game._plugin_overlay_left.offset_right = roundi(200 * s)
	game._plugin_overlay_left.offset_top = roundi(50 * s)
	game._plugin_overlay_left.offset_bottom = -roundi(200 * s)
	game._plugin_overlay_left.visible = false
	game._plugin_overlay_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(game._plugin_overlay_left)

	# Overlay droit (VBoxContainer, bord droit)
	game._plugin_overlay_right = VBoxContainer.new()
	game._plugin_overlay_right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	game._plugin_overlay_right.offset_left = -roundi(200 * s)
	game._plugin_overlay_right.offset_right = -roundi(10 * s)
	game._plugin_overlay_right.offset_top = roundi(50 * s)
	game._plugin_overlay_right.offset_bottom = -roundi(200 * s)
	game._plugin_overlay_right.visible = false
	game._plugin_overlay_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(game._plugin_overlay_right)

	# Overlay top (HBoxContainer, sous le bouton menu)
	game._plugin_overlay_top = HBoxContainer.new()
	game._plugin_overlay_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	game._plugin_overlay_top.offset_top = roundi(50 * s)
	game._plugin_overlay_top.offset_bottom = roundi(90 * s)
	game._plugin_overlay_top.offset_left = roundi(10 * s)
	game._plugin_overlay_top.offset_right = -roundi(120 * s)
	game._plugin_overlay_top.alignment = BoxContainer.ALIGNMENT_END
	game._plugin_overlay_top.visible = false
	game._plugin_overlay_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(game._plugin_overlay_top)


static func _build_variable_display(game: Control) -> void:
	var s := UIScale.get_scale()
	# ScrollContainer sur le bord gauche (toute la hauteur avec marges)
	game._variable_sidebar_scroll = ScrollContainer.new()
	game._variable_sidebar_scroll.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	game._variable_sidebar_scroll.offset_left = roundi(10 * s)
	game._variable_sidebar_scroll.offset_right = roundi(130 * s)
	game._variable_sidebar_scroll.offset_top = roundi(50 * s)
	game._variable_sidebar_scroll.offset_bottom = -roundi(160 * s)
	game._variable_sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	game._variable_sidebar_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	game._variable_sidebar_scroll.visible = false
	game.add_child(game._variable_sidebar_scroll)

	# Sidebar gauche (cercles + valeurs) dans le scroll
	game._variable_sidebar = VBoxContainer.new()
	game._variable_sidebar.set_script(VariableSidebarScript)
	game._variable_sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game._variable_sidebar.alignment = BoxContainer.ALIGNMENT_CENTER
	game._variable_sidebar_scroll.add_child(game._variable_sidebar)

	# Overlay de détails
	game._variable_details_overlay = CenterContainer.new()
	game._variable_details_overlay.set_script(VariableDetailsOverlayScript)
	game._variable_details_overlay.build_ui()
	game.add_child(game._variable_details_overlay)
