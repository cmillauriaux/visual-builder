# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Raccoons Studio

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
	game._play_overlay = VBoxContainer.new()
	game._play_overlay.visible = false
	game._play_overlay.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._play_overlay.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	game._play_overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN
	game._play_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	game._play_overlay.add_theme_constant_override("separation", 0)

	# Character name box — container to allow horizontal offset
	var char_container = MarginContainer.new()
	char_container.mouse_filter = Control.MOUSE_FILTER_PASS
	char_container.add_theme_constant_override("margin_left", roundi(24 * s))
	char_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	game._play_overlay.add_child(char_container)

	game._play_character_box = PanelContainer.new()
	game._play_character_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._play_character_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var btn_tex = load(GameTheme.ASSETS_PATH + "button_brown.png")
	if btn_tex:
		game._play_character_box.add_theme_stylebox_override("panel",
			GameTheme._make_button_stylebox(btn_tex, Color(1, 1, 1, 1)))
	char_container.add_child(game._play_character_box)

	game._play_character_label = Label.new()
	game._play_character_label.add_theme_font_size_override("font_size", UIScale.scale(20))
	game._play_character_label.add_theme_color_override("font_color", GameTheme.COLOR_BUTTON_TEXT)
	game._play_character_box.add_child(game._play_character_label)

	# Dialogue panel — brown background
	game._play_dialogue_panel = PanelContainer.new()
	game._play_dialogue_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	game._play_dialogue_panel.custom_minimum_size = Vector2(0, roundi(100 * s))
	game._play_overlay.add_child(game._play_dialogue_panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", roundi(16 * s))
	margin.add_theme_constant_override("margin_right", roundi(16 * s))
	margin.add_theme_constant_override("margin_top", roundi(12 * s))
	margin.add_theme_constant_override("margin_bottom", roundi(12 * s))
	game._play_dialogue_panel.add_child(margin)

	var play_vbox = VBoxContainer.new()
	margin.add_child(play_vbox)

	game._play_text_label = RichTextLabel.new()
	game._play_text_label.bbcode_enabled = false
	game._play_text_label.fit_content = true
	game._play_text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._play_text_label.custom_minimum_size = Vector2(0, roundi(24 * s))
	play_vbox.add_child(game._play_text_label)

	# Boutons de jeu — créés ici, ajoutés dans _build_play_buttons_bar() à la fin
	var btn_size := Vector2(UIScale.scale(120), UIScale.scale(30))
	var btn_font_size := UIScale.scale(16)
	game._quicksave_button = Button.new()
	game._quicksave_button.text = "Save (F)"
	game._quicksave_button.custom_minimum_size = btn_size
	game._quicksave_button.add_theme_font_size_override("font_size", btn_font_size)

	game._quickload_button = Button.new()
	game._quickload_button.text = "Load (F)"
	game._quickload_button.custom_minimum_size = btn_size
	game._quickload_button.add_theme_font_size_override("font_size", btn_font_size)

	game._auto_play_button = Button.new()
	game._auto_play_button.text = "Auto"
	game._auto_play_button.custom_minimum_size = btn_size
	game._auto_play_button.add_theme_font_size_override("font_size", btn_font_size)

	game._skip_button = Button.new()
	game._skip_button.text = "Skip (S)"
	game._skip_button.custom_minimum_size = btn_size
	game._skip_button.add_theme_font_size_override("font_size", btn_font_size)
	game._skip_button.disabled = true

	game._history_button = Button.new()
	game._history_button.text = "History"
	game._history_button.custom_minimum_size = btn_size
	game._history_button.add_theme_font_size_override("font_size", btn_font_size)
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
	game._play_title_overlay = Control.new()
	game._play_title_overlay.visible = false
	game._play_title_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	game._play_title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var title_bg = ColorRect.new()
	title_bg.name = "TitleBackgroundRect"
	title_bg.color = Color(0, 0, 0, 0)
	title_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._play_title_overlay.add_child(title_bg)

	var title_center = CenterContainer.new()
	title_center.name = "TitleCenter"
	title_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game._play_title_overlay.add_child(title_center)

	var title_vbox = VBoxContainer.new()
	title_center.add_child(title_vbox)

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

	# Toggle button — inside the dialogue area, top-right aligned
	game._toolbar_toggle_button = Button.new()
	game._toolbar_toggle_button.icon = GameTheme.create_arrow_icon(roundi(14 * s), GameTheme.COLOR_BUTTON_TEXT, true)
	game._toolbar_toggle_button.text = ""
	game._toolbar_toggle_button.visible = false
	game._toolbar_toggle_button.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._toolbar_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	game._toolbar_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	var toggle_s := roundi(24 * s)
	var pad_inside := roundi(GameTheme.PANEL_CONTENT_MARGIN * s)
	game._toolbar_toggle_button.offset_left = -toggle_s - pad_inside
	game._toolbar_toggle_button.offset_right = -pad_inside
	game.add_child(game._toolbar_toggle_button)


static func _build_toast_overlay(game: Control) -> void:
	var s := UIScale.get_scale()
	var safe := _get_safe_area_margins()
	var margin_top := maxf(8.0, safe["top"] + 4.0)
	var margin_right := maxf(8.0, safe["right"] + 4.0)
	game._toast_overlay = PanelContainer.new()
	game._toast_overlay.visible = false
	game._toast_overlay.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	game._toast_overlay.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	game._toast_overlay.grow_vertical = Control.GROW_DIRECTION_END
	game._toast_overlay.offset_top = roundi(margin_top * s)
	game._toast_overlay.offset_right = -roundi(margin_right * s)
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
	var safe := _get_safe_area_margins()
	var margin_top := maxf(10.0, safe["top"] + 4.0)
	var margin_right := maxf(10.0, safe["right"] + 4.0)
	game._menu_button = Button.new()
	game._menu_button.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._menu_button.text = "Menu"
	game._menu_button.icon = _create_hamburger_icon(roundi(16 * s), GameTheme.COLOR_BUTTON_TEXT)
	game._menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	game._menu_button.offset_left = -roundi((margin_right + 130) * s)
	game._menu_button.offset_right = -roundi(margin_right * s)
	game._menu_button.offset_top = roundi(margin_top * s)
	game._menu_button.offset_bottom = roundi((margin_top + 40) * s)
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

	game._the_end_screen = Control.new()
	game._the_end_screen.set_script(EndingScreenScript)
	game._the_end_screen.build_ui("The End")
	game.add_child(game._the_end_screen)


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

	# Container toolbar à gauche du bouton Menu (HBoxContainer, aligné à droite)
	var safe := _get_safe_area_margins()
	var margin_top := maxf(10.0, safe["top"] + 4.0)
	var margin_right := maxf(10.0, safe["right"] + 4.0)
	var menu_btn_width := 130.0
	var gap := 8.0
	game._plugin_toolbar = HBoxContainer.new()
	game._plugin_toolbar.visible = false
	game._plugin_toolbar.alignment = BoxContainer.ALIGNMENT_END
	game._plugin_toolbar.add_theme_constant_override("separation", roundi(6 * s))
	game._plugin_toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	game._plugin_toolbar.offset_right = -roundi((margin_right + menu_btn_width + gap) * s)
	game._plugin_toolbar.offset_left = -roundi((margin_right + menu_btn_width + gap + 300) * s)
	game._plugin_toolbar.offset_top = roundi(margin_top * s)
	game._plugin_toolbar.offset_bottom = roundi((margin_top + 40) * s)
	game._plugin_toolbar.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
	game._plugin_toolbar.mouse_filter = Control.MOUSE_FILTER_PASS
	game.add_child(game._plugin_toolbar)

	# Overlay gauche (VBoxContainer, bord gauche)
	game._plugin_overlay_left = VBoxContainer.new()
	game._plugin_overlay_left.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
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
	game._plugin_overlay_right.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
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
	game._plugin_overlay_top.z_index = SequenceVisualEditorScript.UI_OVERLAY_Z
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


## Returns safe area margins in viewport coordinates, accounting for stretch mode
## and pillarbox/letterbox bars. Falls back to zero on platforms without safe area.
static func _get_safe_area_margins() -> Dictionary:
	var screen_size := DisplayServer.window_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return {"top": 0.0, "right": 0.0, "bottom": 0.0, "left": 0.0}

	var safe_rect := DisplayServer.get_display_safe_area()
	var margin_top := float(safe_rect.position.y)
	var margin_right := float(screen_size.x - safe_rect.end.x)
	var margin_bottom := float(screen_size.y - safe_rect.end.y)
	var margin_left := float(safe_rect.position.x)

	var vp_w: float = ProjectSettings.get_setting("display/window/size/viewport_width", 1920)
	var vp_h: float = ProjectSettings.get_setting("display/window/size/viewport_height", 1080)
	var screen_aspect := float(screen_size.x) / float(screen_size.y)
	var vp_aspect := vp_w / vp_h

	var content_scale: float
	var bar_x := 0.0
	var bar_y := 0.0
	if screen_aspect > vp_aspect:
		# Pillarboxed (iPhone landscape — screen wider than 16:9)
		content_scale = float(screen_size.y) / vp_h
		bar_x = (float(screen_size.x) - vp_w * content_scale) / 2.0
	else:
		# Letterboxed (screen taller than 16:9)
		content_scale = float(screen_size.x) / vp_w
		bar_y = (float(screen_size.y) - vp_h * content_scale) / 2.0

	return {
		"top": maxf(0.0, margin_top - bar_y) / content_scale,
		"right": maxf(0.0, margin_right - bar_x) / content_scale,
		"bottom": maxf(0.0, margin_bottom - bar_y) / content_scale,
		"left": maxf(0.0, margin_left - bar_x) / content_scale,
	}
